//
//  ArgoClient+Network.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import Foundation

extension ArgoClient {
    func applyCookies(_ request: inout URLRequest) {
        guard let url = request.url else { return }
        
        let cookies = cookieStorage.cookies(for: url) ?? []
        if !cookies.isEmpty {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let host = url.host?.lowercased(), let hostCookies = cookieHeaderForHost(host), !hostCookies.isEmpty {
            let existing = request.value(forHTTPHeaderField: "Cookie")
            if let existing, !existing.isEmpty {
                request.setValue(existing + "; " + hostCookies, forHTTPHeaderField: "Cookie")
            } else {
                request.setValue(hostCookies, forHTTPHeaderField: "Cookie")
            }
        }
    }
    
    func storeCookies(from response: URLResponse, fallbackURL: URL?) {
        guard let http = response as? HTTPURLResponse else { return }
        guard let url = response.url ?? fallbackURL else { return }
        
        var headerFields: [String: String] = [:]
        for (rawKey, rawValue) in http.allHeaderFields {
            guard let key = rawKey as? String, let value = rawValue as? String else { continue }
            headerFields[key] = value
        }
        
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            cookieStorage.setCookie(cookie)
        }
        
        if let host = url.host?.lowercased() {
            let setCookieLines = extractSetCookieLines(from: http)
            for line in setCookieLines {
                storeManualCookie(setCookieLine: line, host: host)
            }
        }
    }
    
    func extractSetCookieLines(from response: HTTPURLResponse) -> [String] {
        guard let raw = response.value(forHTTPHeaderField: "Set-Cookie"), !raw.isEmpty else {
            return []
        }
        return splitCombinedSetCookieHeader(raw)
    }
    
    func splitCombinedSetCookieHeader(_ raw: String) -> [String] {
        var lines: [String] = []
        var current = ""
        let chars = Array(raw)
        var index = 0
        
        while index < chars.count {
            let ch = chars[index]
            
            if ch == "," {
                var probe = index + 1
                while probe < chars.count && chars[probe].isWhitespace { probe += 1 }
                
                var cursor = probe
                var sawEquals = false
                var hitTerminator = false
                while cursor < chars.count {
                    if chars[cursor] == "=" {
                        sawEquals = true
                        break
                    }
                    if chars[cursor] == ";" || chars[cursor] == "," || chars[cursor].isWhitespace {
                        hitTerminator = true
                        break
                    }
                    cursor += 1
                }
                
                if sawEquals && !hitTerminator {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { lines.append(trimmed) }
                    current = ""
                    index += 1
                    continue
                }
            }
            
            current.append(ch)
            index += 1
        }
        
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { lines.append(tail) }
        return lines
    }
    
    func storeManualCookie(setCookieLine: String, host: String) {
        let firstPart = setCookieLine.split(separator: ";", maxSplits: 1).first.map(String.init) ?? setCookieLine
        guard let eqIndex = firstPart.firstIndex(of: "=") else { return }
        
        let name = String(firstPart[..<eqIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(firstPart[firstPart.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        var hostMap = manualCookieJar[host] ?? [:]
        hostMap[name] = value
        manualCookieJar[host] = hostMap
    }
    
    func cookieHeaderForHost(_ host: String) -> String? {
        var pairs = Set<String>()
        
        if let exact = manualCookieJar[host] {
            for (name, value) in exact {
                pairs.insert("\(name)=\(value)")
            }
        }
        
        for (storedHost, cookies) in manualCookieJar where host.hasSuffix("." + storedHost) {
            for (name, value) in cookies {
                pairs.insert("\(name)=\(value)")
            }
        }
        
        if pairs.isEmpty { return nil }
        return Array(pairs).joined(separator: "; ")
    }
    
    func apiRequest<T: Decodable>(
        _ path: String,
        method: String? = nil,
        jsonBody: (some Encodable)? = nil as String?
    ) async throws -> T {
        let (data, _) = try await apiRequestRaw(path, method: method, jsonBody: jsonBody)
        do {
            return try argoJSONDecoder.decode(T.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ArgoError.invalidResponse(
                "Decode error for \(path): \(error)\nRaw response: \(raw.prefix(400))"
            )
        }
    }
    
    func apiRequestRaw(
        _ path: String,
        method: String? = nil,
        jsonBody: (some Encodable)? = nil as String?
    ) async throws -> (Data, URLResponse) {
        let hasBody = jsonBody != nil
        let httpMethod = method ?? (hasBody ? "POST" : "GET")
        guard let url = URL(string: "\(argoBaseURL)/appfamiglia/api/rest/\(path)") else {
            throw ArgoError.invalidLoginURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(version, forHTTPHeaderField: "argo-client-version")
        request.setValue("Bearer \(token?.access_token ?? "")", forHTTPHeaderField: "authorization")
        
        if let loginData {
            request.setValue(loginData.token, forHTTPHeaderField: "x-auth-token")
            request.setValue(loginData.codMin, forHTTPHeaderField: "x-cod-min")
        }
        if let token {
            request.setValue(argoFormatDate(token.expireDate), forHTTPHeaderField: "x-date-exp-auth")
        }
        if hasBody, let body = jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = try argoJSONEncoder.encode(body)
        }
        
        return try await session.data(for: request)
    }
    
    func fetchLoginData() async throws {
        let body: [String: String] = [
            "lista-opzioni-notifiche": "{}",
            "lista-x-auth-token": "[]",
            "clientID": argoRandomString(163),
        ]
        let response: LoginResponse = try await apiRequest("login", jsonBody: body)
        guard response.success, let first = response.data.first else {
            throw ArgoError.apiError(response.msg ?? "Errore nel recupero dati di login")
        }
        loginData = first
    }
    
    func fetchProfilo() async throws {
        let response: ProfiloResponse = try await apiRequest("profilo")
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore profilo") }
        profile = response.data
    }
    
    func fetchDashboard() async throws {
        guard let prof = profile else { return }
        
        let since = dashboard.map { argoFormatDate($0.dataAggiornamento) } ?? "\(prof.anno.dataInizio) 00:00:00.000"
        let opzioniStr = try currentOptionsJSONString() ?? "{}"
        
        let body: [String: String] = [
            "dataultimoaggiornamento": since,
            "opzioni": opzioniStr,
        ]
        
        let (data, response) = try await apiRequestRaw("dashboard/dashboard", jsonBody: body)
        let serverDate = parseHTTPDate((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "date")) ?? Date()
        let decoded = try argoJSONDecoder.decode(DashboardResponse.self, from: data)
        guard decoded.success, let raw = decoded.data.dati.first else {
            throw ArgoError.apiError(decoded.msg ?? "Errore dashboard")
        }
        
        let previous = raw.rimuoviDatiLocali ?? false ? nil : dashboard
        
        dashboard = DashboardDati(
            fuoriClasse: handleOperation(raw.fuoriClasse ?? [], old: previous?.fuoriClasse),
            msg: raw.msg ?? "",
            opzioni: raw.opzioni ?? [],
            mediaGenerale: raw.mediaGenerale ?? 0,
            listaMaterie: raw.listaMaterie ?? [],
            rimuoviDatiLocali: raw.rimuoviDatiLocali ?? false,
            listaPeriodi: raw.listaPeriodi,
            promemoria: handleOperation(raw.promemoria ?? [], old: previous?.promemoria),
            bacheca: handleOperation(raw.bacheca ?? [], old: previous?.bacheca),
            voti: handleOperation(raw.voti ?? [], old: previous?.voti),
            bachecaAlunno: handleOperation(raw.bachecaAlunno ?? [], old: previous?.bachecaAlunno),
            registro: handleOperation(raw.registro ?? [], old: previous?.registro),
            appello: handleOperation(raw.appello ?? [], old: previous?.appello),
            prenotazioniAlunni: handleOperationCustomPK(
                raw.prenotazioniAlunni ?? [],
                old: previous?.prenotazioniAlunni,
                pk: { $0.prenotazione.pk }
            ),
            listaDocentiClasse: raw.listaDocentiClasse ?? [],
            mediaMaterie: raw.mediaMaterie ?? [:],
            mediaPerPeriodo: raw.mediaPerPeriodo,
            ricaricaDati: raw.ricaricaDati ?? false,
            profiloDisabilitato: raw.profiloDisabilitato ?? false,
            classiExtra: raw.classiExtra ?? false,
            pk: raw.pk ?? "",
            dataAggiornamento: serverDate
        )
    }
    
    func fetchWhat(lastUpdate: String) async throws -> WhatDati {
        let authToken = "[\"\(loginData?.token ?? "")\"]"
        let opzioniStr = try currentOptionsJSONString(allowNil: true)
        
        var body: [String: String] = [
            "dataultimoaggiornamento": lastUpdate,
            "lista-x-auth-token": authToken,
            "lista-x-auth-token-account": authToken,
        ]
        if let opzioniStr {
            body["opzioni"] = opzioniStr
        }
        
        let response: WhatResponse = try await apiRequest("dashboard/what", jsonBody: body)
        guard response.success, let first = response.data.dati.first else {
            throw ArgoError.apiError(response.msg ?? "Errore what")
        }
        return first
    }
    
    func aggiornaData() async throws {
        let body = ["dataultimoaggiornamento": argoFormatDate(Date())]
        let response: GenericResponse = try await apiRequest("dashboard/aggiornadata", jsonBody: body)
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore aggiornadata") }
    }
    
    func rimuoviProfilo() async throws {
        let response: GenericResponse = try await apiRequest("rimuoviprofilo", jsonBody: [:] as [String: String])
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore logout") }
    }
    
    func logToken(oldToken: Token, isWhat: Bool) async throws {
        var body: [String: String] = [
            "bearerOld": oldToken.access_token,
            "dateExpOld": argoFormatDate(oldToken.expireDate),
            "refreshOld": oldToken.refresh_token,
            "isWhat": isWhat ? "true" : "false",
            "isRefreshed": token?.access_token == oldToken.access_token ? "true" : "false",
            "proc": "initState_global_random_12345",
        ]
        if let token {
            body["bearerNew"] = token.access_token
            body["dateExpNew"] = argoFormatDate(token.expireDate)
            body["refreshNew"] = token.refresh_token
        }
        let response: GenericResponse = try await apiRequest("logtoken", jsonBody: body)
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore logtoken") }
    }
    
    private func currentOptionsJSONString(allowNil: Bool = false) throws -> String? {
        let opzioniArray = dashboard?.opzioni ?? loginData?.opzioni ?? []
        guard !opzioniArray.isEmpty else { return allowNil ? nil : "{}" }
        let opzioniDict = Dictionary(uniqueKeysWithValues: opzioniArray.map { ($0.chiave, $0.valore) })
        let data = try argoJSONEncoder.encode(opzioniDict)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
