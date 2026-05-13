//
//  BachecaView.swift
//  Atlas
//
//  Created by Francesco on 13/05/26.
//

import SwiftUI

struct BachecaView: View {
    @EnvironmentObject var client: ArgoClient
    
    struct CommunicationDisplayItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let message: String
        let dateText: Substring
        let isUnread: Bool
        let accentColor: Color
    }
    
    private var items: [CommunicationDisplayItem] {
        let schoolItems = (client.dashboard?.bacheca ?? []).map { item in
            CommunicationDisplayItem(
                id: "bacheca-\(item.pk)",
                title: item.autore.isEmpty ? "Comunicazione" : item.autore,
                subtitle: item.categoria.isEmpty ? "Bacheca scuola" : item.categoria,
                message: item.messaggio,
                dateText: item.data.prefix(10),
                isUnread: !item.isPresaVisione,
                accentColor: .teal
            )
        }
        let studentItems = (client.dashboard?.bachecaAlunno ?? []).map { item in
            CommunicationDisplayItem(
                id: "bacheca-alunno-\(item.pk)",
                title: item.nomeFile.isEmpty ? "Comunicazione" : item.nomeFile,
                subtitle: "Bacheca alunno",
                message: item.messaggio,
                dateText: item.data.prefix(10),
                isUnread: !item.isPresaVisione,
                accentColor: .green
            )
        }
        return (schoolItems + studentItems).sorted { $0.dateText > $1.dateText }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if items.isEmpty {
                        ContentUnavailableView(
                            "Nessuna comunicazione",
                            systemImage: "tray",
                            description: Text("Quando la scuola pubblica avvisi o materiali, appariranno qui.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(items) { item in
                            CommunicationCard(
                                title: item.title,
                                subtitle: item.subtitle,
                                message: item.message,
                                dateText: item.dateText,
                                unread: item.isUnread,
                                accentColor: item.accentColor
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bacheca")
        }
    }
}
