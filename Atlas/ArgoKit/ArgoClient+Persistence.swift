//
//  ArgoClient+Persistence.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import Foundation

extension ArgoClient {
    private struct PersistedState: Codable {
        let token: Token?
        let loginData: LoginData?
        let profile: Profilo?
        let dashboard: DashboardDati?
    }
    
    static func makeStateFileURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let appDirectory = baseDirectory.appendingPathComponent("Orion", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory.appendingPathComponent("client-state.json")
    }
    
    func restorePersistedState() {
        guard let data = try? Data(contentsOf: stateFileURL), !data.isEmpty else { return }
        guard let snapshot = try? argoJSONDecoder.decode(PersistedState.self, from: data) else { return }
        
        isRestoringState = true
        token = snapshot.token
        loginData = snapshot.loginData
        profile = snapshot.profile
        dashboard = snapshot.dashboard
        isReady = snapshot.token != nil && snapshot.loginData != nil
        isRestoringState = false
    }
    
    func persistState() {
        guard !isRestoringState else { return }
        
        let snapshot = PersistedState(
            token: token,
            loginData: loginData,
            profile: profile,
            dashboard: dashboard
        )
        
        if snapshot.token == nil && snapshot.loginData == nil && snapshot.profile == nil && snapshot.dashboard == nil {
            clearPersistedState()
            return
        }
        
        guard let data = try? argoJSONEncoder.encode(snapshot) else { return }
        try? data.write(to: stateFileURL, options: [.atomic])
    }
    
    func clearPersistedState() {
        try? FileManager.default.removeItem(at: stateFileURL)
    }
}
