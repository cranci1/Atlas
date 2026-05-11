//
//  AtlasApp.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import SwiftUI

@main
struct AtlasApp: App {
    @StateObject private var client = ArgoClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(client)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var client: ArgoClient

    var body: some View {
        Group {
            if client.isReady {
                ContentView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal:   .move(edge: .leading)
                    ).combined(with: .opacity))
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal:   .move(edge: .trailing)
                    ).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: client.isReady)
    }
}
