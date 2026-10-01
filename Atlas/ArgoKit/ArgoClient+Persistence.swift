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
    
    private static let stateDirectoryName = "Atlas"
    private static let legacyStateDirectoryName = "Orion"
    private static let stateFileName = "client-state.json"
    
    static func makeStateFileURL() -> URL {
        let fileManager = FileManager.default
        let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        
        let appDirectory = baseDirectory.appendingPathComponent(
            stateDirectoryName,
            isDirectory: true
        )
        
        do {
            try fileManager.createDirectory(
                at: appDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: appDirectory.path
            )
        } catch { }
        
        return appDirectory.appendingPathComponent(stateFileName)
    }
    
    private static func legacyStateFileURL() -> URL? {
        let fileManager = FileManager.default
        guard let baseDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        return baseDirectory
            .appendingPathComponent(legacyStateDirectoryName, isDirectory: true)
            .appendingPathComponent(stateFileName)
    }
    
    func restorePersistedState() {
        let urls = [stateFileURL, Self.legacyStateFileURL()].compactMap { $0 }
        
        for url in urls {
            guard
                let data = try? Data(contentsOf: url),
                !data.isEmpty,
                let snapshot = try? argoJSONDecoder.decode(PersistedState.self, from: data)
            else {
                continue
            }
            
            isRestoringState = true
            token = snapshot.token
            loginData = snapshot.loginData
            profile = snapshot.profile
            dashboard = snapshot.dashboard
            isReady = snapshot.token != nil && snapshot.loginData != nil
            isRestoringState = false
            
            if url != stateFileURL {
                persistState()
                try? FileManager.default.removeItem(at: url)
            }
            
            return
        }
    }
    
    func persistState() {
        guard !isRestoringState else { return }
        
        let snapshot = PersistedState(
            token: token,
            loginData: loginData,
            profile: profile,
            dashboard: dashboard
        )
        
        if snapshot.token == nil &&
            snapshot.loginData == nil &&
            snapshot.profile == nil &&
            snapshot.dashboard == nil {
            clearPersistedState()
            return
        }
        
        do {
            let data = try argoJSONEncoder.encode(snapshot)
            try data.write(
                to: stateFileURL,
                options: [.atomic, .completeFileProtection]
            )
        } catch { }
    }
    
    func clearPersistedState() {
        try? FileManager.default.removeItem(at: stateFileURL)
    }
}
