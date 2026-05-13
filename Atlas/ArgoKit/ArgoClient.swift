//
//  ArgoClient.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import Combine
import Foundation

@MainActor
public final class ArgoClient: ObservableObject {
    @Published public var token: Token? { didSet { persistState() } }
    @Published public var loginData: LoginData? { didSet { persistState() } }
    @Published public var profile: Profilo? { didSet { persistState() } }
    @Published public var dashboard: DashboardDati? { didSet { persistState() } }
    @Published public var isReady = false
    @Published public var isLoading = false
    
    public var credentials: Credentials
    public let version: String
    public let cookieStorage: HTTPCookieStorage
    public var manualCookieJar: [String: [String: String]] = [:]
    public let session: URLSession
    public let stateFileURL: URL
    public var isRestoringState = false
    
    public init(
        credentials: Credentials = Credentials(schoolCode: "", username: "", password: ""),
        version: String = argoDefaultVersion
    ) {
        self.credentials = credentials
        self.version = version
        self.stateFileURL = ArgoClient.makeStateFileURL()
        
        let configuration = URLSessionConfiguration.default
        let cookieStorage = HTTPCookieStorage()
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        self.cookieStorage = cookieStorage
        self.session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
        
        restorePersistedState()
        
        if token != nil, loginData != nil {
            isReady = true
            Task { [weak self] in
                guard let self else { return }
                try? await self.login()
            }
        }
    }
    
    private func requireReady() throws {
        guard isReady else { throw ArgoError.notLoggedIn }
    }
    
    public func login() async throws {
        isLoading = true
        defer { isLoading = false }
        
        let oldToken = token
        try await refreshToken()
        
        if loginData == nil {
            try await fetchLoginData()
        }
        
        if let oldToken, let profile {
            Task { try? await logToken(oldToken: oldToken, isWhat: true) }
            let lastUpdate = dashboard.map { argoFormatDate($0.dataAggiornamento) } ?? profile.anno.dataInizio
            let whatData = try await fetchWhat(lastUpdate: lastUpdate)
            if whatData.isModificato || whatData.differenzaSchede {
                try await fetchProfilo()
            }
            isReady = true
            if whatData.mostraPallino || dashboard == nil {
                try await fetchDashboard()
            }
            Task { try? await aggiornaData() }
            return
        }
        
        if profile == nil {
            try await fetchProfilo()
        }
        
        isReady = true
        try await fetchDashboard()
    }
    
    public func logOut() async throws {
        guard token != nil, loginData != nil else { throw ArgoError.notLoggedIn }
        try await rimuoviProfilo()
        clearPersistedState()
        token = nil
        loginData = nil
        profile = nil
        dashboard = nil
        isReady = false
    }
    
    public func getDettagliProfilo() async throws -> DettagliProfilo {
        try requireReady()
        let response: DettagliProfiloResponse = try await apiRequest("dettaglioprofilo", method: "POST")
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data
    }
    
    public func getOrarioGiornaliero(date: Date = Date()) async throws -> [OraLezione] {
        try requireReady()
        let response: OrarioGiornalieroResponse = try await apiRequest(
            "orario-giorno",
            jsonBody: ["datGiorno": argoFormatDate(date)]
        )
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data.dati.values.flatMap { $0 }
    }
    
    public func getLinkAllegato(uid: String) async throws -> String {
        try requireReady()
        let response: DownloadAllegatoResponse = try await apiRequest(
            "downloadallegatobacheca",
            jsonBody: ["uid": uid]
        )
        guard response.success, let url = response.url else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return url
    }
    
    public func getLinkAllegatoStudente(uid: String, pkScheda: String? = nil) async throws -> String {
        try requireReady()
        let pk = pkScheda ?? profile?.scheda.pk ?? ""
        let response: DownloadAllegatoResponse = try await apiRequest(
            "downloadallegatobachecaalunno",
            jsonBody: ["uid": uid, "pkScheda": pk]
        )
        guard response.success, let url = response.url else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return url
    }
    
    public func getVotiScrutinio() async throws -> [PeriodoScrutinio]? {
        try requireReady()
        let response: VotiScrutinioResponse = try await apiRequest(
            "votiscrutinio",
            jsonBody: [:] as [String: String]
        )
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data.votiScrutinio.first?.periodi
    }
    
    public func getRicevimenti() async throws -> RicevimentiData {
        try requireReady()
        let response: RicevimentiResponse = try await apiRequest(
            "ricevimento",
            jsonBody: [:] as [String: String]
        )
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data
    }
    
    public func getTasse(pkScheda: String? = nil) async throws -> [Tassa] {
        try requireReady()
        let pk = pkScheda ?? profile?.scheda.pk ?? ""
        let response: TasseResponse = try await apiRequest("listatassealunni", jsonBody: ["pkScheda": pk])
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data
    }
    
    public func getCurriculum(pkScheda: String? = nil) async throws -> [CurriculumEntry] {
        try requireReady()
        let pk = pkScheda ?? profile?.scheda.pk ?? ""
        let response: CurriculumResponse = try await apiRequest("curriculumalunno", jsonBody: ["pkScheda": pk])
        guard response.success else { throw ArgoError.apiError(response.msg ?? "Errore") }
        return response.data.curriculum
    }
}
