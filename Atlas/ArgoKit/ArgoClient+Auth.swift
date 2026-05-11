//
//  ArgoClient+Auth.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import Foundation

extension ArgoClient {
    func refreshToken() async throws {
        guard let token else {
            return try await getToken()
        }
        
        guard token.expireDate <= Date() else { return }
        
        let now = Date()
        let scopeList = "[" + token.scope.split(separator: " ").joined(separator: ", ") + "]"
        
        let bodyDict: [String: String?] = [
            "r-token": token.refresh_token,
            "client-id": argoClientId,
            "scopes": scopeList,
            "old-bearer": token.access_token,
            "primo-accesso": "false",
            "ripeti-login": "false",
            "exp-bearer": argoFormatDate(token.expireDate),
            "ts-app": argoFormatDate(now),
            "proc": "initState_global_random_12345",
            "username": loginData?.username,
        ]
        
        let (data, response) = try await apiRequestRaw(
            "auth/refresh-token",
            jsonBody: bodyDict.compactMapValues { $0 }
        )
        var expireDate = parseHTTPDate((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "date")) ?? now
        
        if let error = try? argoJSONDecoder.decode(TokenError.self, from: data) {
            throw ArgoError.tokenError("\(error.error): \(error.error_description)")
        }
        
        let partial = try argoJSONDecoder.decode(TokenPartial.self, from: data)
        expireDate.addTimeInterval(TimeInterval(partial.expires_in))
        
        self.token = Token(
            access_token: partial.access_token,
            expires_in: partial.expires_in,
            id_token: partial.id_token ?? token.id_token,
            refresh_token: partial.refresh_token ?? token.refresh_token,
            scope: partial.scope ?? token.scope,
            token_type: partial.token_type ?? token.token_type,
            expireDate: expireDate
        )
    }
    
    func getToken() async throws {
        let result = try await getCode()
        let token = try await exchangeCodeForToken(code: result.code, codeVerifier: result.codeVerifier)
        self.token = token
    }
    
    func getCode() async throws -> (codeVerifier: String, code: String) {
        guard !credentials.schoolCode.isEmpty,
              !credentials.username.isEmpty,
              !credentials.password.isEmpty
        else { throw ArgoError.missingCredentials }
        
        let codeVerifier = argoRandomString(43)
        let challenge = pkceChallengeFromVerifier(codeVerifier)
        let state = argoRandomString(22)
        let nonce = argoRandomString(22)
        let scopes = ["openid", "offline", "profile", "user.roles", "argo"]
        let scopeStr = scopes.joined(separator: " ")
        
        let redirectEnc = argoRedirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? argoRedirectURI
        let scopeEnc = scopeStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopeStr
        
        let authURLString =
        "\(argoAuthURL)/oauth2/auth" +
        "?redirect_uri=\(redirectEnc)" +
        "&client_id=\(argoClientId)" +
        "&response_type=code" +
        "&prompt=login" +
        "&state=\(state)" +
        "&nonce=\(nonce)" +
        "&scope=\(scopeEnc)" +
        "&code_challenge=\(challenge)" +
        "&code_challenge_method=S256"
        
        guard let authURL = URL(string: authURLString) else { throw ArgoError.invalidLoginURL }
        
        var request = URLRequest(url: authURL)
        request.httpMethod = "GET"
        applyBrowserHeaders(&request)
        request.setValue("https://www.portaleargo.it/", forHTTPHeaderField: "Referer")
        applyCookies(&request)
        let (_, response) = try await session.data(for: request)
        storeCookies(from: response, fallbackURL: request.url)
        let loginResponseURL = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location").flatMap { resolveRedirectURL($0, baseURL: response.url) }
        
        var loginChallenge = loginResponseURL.flatMap { queryValue("login_challenge", in: $0) }
        if loginChallenge == nil, let startURL = loginResponseURL ?? response.url {
            loginChallenge = try await followRedirects(from: startURL, param: "login_challenge")
        }
        guard let loginChallenge else { throw ArgoError.invalidLoginChallenge }
        
        if let startURL = loginResponseURL ?? response.url {
            try await primeAuthSession(from: startURL)
        }
        
        if let loginPageURL = URL(string: "https://www.portaleargo.it/auth/sso/login/?login_challenge=\(loginChallenge)") {
            var loginPageRequest = URLRequest(url: loginPageURL)
            loginPageRequest.httpMethod = "GET"
            applyBrowserHeaders(&loginPageRequest)
            loginPageRequest.setValue("https://www.portaleargo.it/", forHTTPHeaderField: "Referer")
            applyCookies(&loginPageRequest)
            let (_, loginPageResponse) = try await session.data(for: loginPageRequest)
            storeCookies(from: loginPageResponse, fallbackURL: loginPageRequest.url)
        }
        
        guard let ssoURL = URL(string: argoSSOLoginURL) else { throw ArgoError.invalidLoginURL }
        var loginRequest = URLRequest(url: ssoURL)
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        applyBrowserHeaders(&loginRequest, secFetchSite: "same-origin")
        loginRequest.setValue("https://www.portaleargo.it", forHTTPHeaderField: "Origin")
        loginRequest.setValue("https://www.portaleargo.it/auth/sso/login/?login_challenge=\(loginChallenge)", forHTTPHeaderField: "Referer")
        loginRequest.httpBody = formEncode([
            ("challenge", loginChallenge),
            ("client_id", argoClientId),
            ("prefill", "false"),
            ("remember_me", "false"),
            ("famiglia_customer_code", credentials.schoolCode),
            ("login", "true"),
            ("password", credentials.password),
            ("username", credentials.username),
        ])
        applyCookies(&loginRequest)
        
        let (_, loginResponse) = try await session.data(for: loginRequest)
        storeCookies(from: loginResponse, fallbackURL: loginRequest.url)
        let callbackURL = (loginResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "Location").flatMap { resolveRedirectURL($0, baseURL: loginResponse.url) }
        
        var code = callbackURL.flatMap { queryValue("code", in: $0) }
        if code == nil, let startURL = callbackURL ?? loginResponse.url {
            code = try await completeConsentChainAndExtractCode(from: startURL)
        }
        if code == nil, let startURL = callbackURL ?? loginResponse.url {
            code = try await followRedirects(from: startURL, param: "code")
        }
        guard let code else { throw ArgoError.invalidLoginCode }
        
        return (codeVerifier: codeVerifier, code: code)
    }
    
    func followRedirects(from startURL: URL, param: String, maxHops: Int = 6) async throws -> String? {
        var nextURL: URL? = startURL
        
        for _ in 0..<maxHops {
            guard let url = nextURL else { break }
            if let scheme = url.scheme, scheme != "http" && scheme != "https" {
                return queryValue(param, in: url)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyBrowserHeaders(&request)
            applyCookies(&request)
            
            let (_, response) = try await session.data(for: request)
            storeCookies(from: response, fallbackURL: request.url)
            if let value = queryValue(param, in: response.url ?? url) {
                return value
            }
            
            guard
                let http = response as? HTTPURLResponse,
                let location = http.value(forHTTPHeaderField: "Location"),
                let resolved = resolveRedirectURL(location, baseURL: response.url)
            else { return nil }
            
            if let value = queryValue(param, in: resolved) {
                return value
            }
            
            nextURL = resolved
        }
        return nil
    }
    
    func completeConsentChainAndExtractCode(from startURL: URL) async throws -> String? {
        if let directCode = queryValue("code", in: startURL) { return directCode }
        
        var authRequest = URLRequest(url: startURL)
        authRequest.httpMethod = "GET"
        applyBrowserHeaders(&authRequest, secFetchSite: "same-site")
        authRequest.setValue("https://www.portaleargo.it/", forHTTPHeaderField: "Referer")
        applyCookies(&authRequest)
        let (_, authResponse) = try await session.data(for: authRequest)
        storeCookies(from: authResponse, fallbackURL: authRequest.url)
        
        guard
            let authHTTP = authResponse as? HTTPURLResponse,
            let authLocation = authHTTP.value(forHTTPHeaderField: "Location"),
            let authLocationURL = resolveRedirectURL(authLocation, baseURL: authResponse.url)
        else { return nil }
        
        if let code = queryValue("code", in: authLocationURL) { return code }
        
        var consentRequest = URLRequest(url: authLocationURL)
        consentRequest.httpMethod = "GET"
        applyBrowserHeaders(&consentRequest, secFetchSite: "same-site")
        consentRequest.setValue("https://www.portaleargo.it/", forHTTPHeaderField: "Referer")
        applyCookies(&consentRequest)
        let (_, consentResponse) = try await session.data(for: consentRequest)
        storeCookies(from: consentResponse, fallbackURL: consentRequest.url)
        
        guard
            let consentHTTP = consentResponse as? HTTPURLResponse,
            let consentLocation = consentHTTP.value(forHTTPHeaderField: "Location"),
            let consentLocationURL = resolveRedirectURL(consentLocation, baseURL: consentResponse.url)
        else { return nil }
        
        if let code = queryValue("code", in: consentLocationURL) { return code }
        
        var finalRequest = URLRequest(url: consentLocationURL)
        finalRequest.httpMethod = "GET"
        applyBrowserHeaders(&finalRequest, secFetchSite: "same-site")
        finalRequest.setValue("https://www.portaleargo.it/", forHTTPHeaderField: "Referer")
        applyCookies(&finalRequest)
        let (_, finalResponse) = try await session.data(for: finalRequest)
        storeCookies(from: finalResponse, fallbackURL: finalRequest.url)
        
        if let code = queryValue("code", in: finalResponse.url ?? consentLocationURL) { return code }
        
        guard
            let finalHTTP = finalResponse as? HTTPURLResponse,
            let finalLocation = finalHTTP.value(forHTTPHeaderField: "Location"),
            let callbackURL = resolveRedirectURL(finalLocation, baseURL: finalResponse.url)
        else { return nil }
        
        return queryValue("code", in: callbackURL)
    }
    
    func primeAuthSession(from startURL: URL, maxHops: Int = 6) async throws {
        var nextURL: URL? = startURL
        
        for _ in 0..<maxHops {
            guard let url = nextURL else { break }
            if let scheme = url.scheme, scheme != "http" && scheme != "https" {
                break
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            applyBrowserHeaders(&request)
            applyCookies(&request)
            let (_, response) = try await session.data(for: request)
            storeCookies(from: response, fallbackURL: request.url)
            guard
                let http = response as? HTTPURLResponse,
                let location = http.value(forHTTPHeaderField: "Location"),
                let resolved = resolveRedirectURL(location, baseURL: response.url)
            else { break }
            
            nextURL = resolved
        }
    }
    
    func exchangeCodeForToken(code: String, codeVerifier: String) async throws -> Token {
        let now = Date()
        guard let tokenURL = URL(string: "\(argoAuthURL)/oauth2/token") else {
            throw ArgoError.invalidLoginURL
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "content-type")
        applyAppHeaders(&request)
        request.httpBody = formEncode([
            ("code", code),
            ("grant_type", "authorization_code"),
            ("redirect_uri", argoRedirectURI),
            ("code_verifier", codeVerifier),
            ("client_id", argoClientId),
        ])
        applyCookies(&request)
        
        let (data, response) = try await session.data(for: request)
        storeCookies(from: response, fallbackURL: request.url)
        var expireDate = parseHTTPDate((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "date")) ?? now
        
        if let error = try? argoJSONDecoder.decode(TokenError.self, from: data) {
            throw ArgoError.tokenError("\(error.error): \(error.error_description)")
        }
        
        let partial = try argoJSONDecoder.decode(TokenPartial.self, from: data)
        expireDate.addTimeInterval(TimeInterval(partial.expires_in))
        
        return Token(
            access_token: partial.access_token,
            expires_in: partial.expires_in,
            id_token: partial.id_token ?? "",
            refresh_token: partial.refresh_token ?? "",
            scope: partial.scope ?? "",
            token_type: partial.token_type ?? "Bearer",
            expireDate: expireDate
        )
    }
}
