//
//  ContentView.swift
//  Atlas
//
//  Created by Francesco on 11/05/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var client: ArgoClient
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            VotiView()
                .tabItem {
                    Label("Voti", systemImage: "star.fill")
                }
                .tag(1)

            RegistroView()
                .tabItem {
                    Label("Registro", systemImage: "book.fill")
                }
                .tag(2)

            BachecaView()
                .tabItem {
                    Label("Bacheca", systemImage: "megaphone.fill")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profilo", systemImage: "person.fill")
                }
                .tag(4)
        }
        .tint(Color(.systemTeal))
    }
}
