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
        let attachments: [Allegato]
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
                accentColor: .teal,
                attachments: item.listaAllegati
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
                accentColor: .green,
                attachments: []
            )
        }
        return (schoolItems + studentItems).sorted { $0.dateText > $1.dateText }
    }
    
    @State private var selectedItem: CommunicationDisplayItem? = nil
    
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
                            Button(action: { selectedItem = item }) {
                                CommunicationCard(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    message: item.message,
                                    dateText: item.dateText,
                                    unread: item.isUnread,
                                    accentColor: item.accentColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Bacheca")
            .sheet(item: $selectedItem) { item in
                CommunicationDetailView(
                    title: item.title,
                    subtitle: item.subtitle,
                    dateText: item.dateText,
                    message: item.message,
                    attachments: item.attachments
                )
                .environmentObject(client)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct CommunicationDetailView: View {
    let title: String
    let subtitle: String
    let dateText: Substring
    let message: String
    let attachments: [Allegato]
    
    @EnvironmentObject var client: ArgoClient
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack() {
                            Text(title)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(String(dateText))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if !attachments.isEmpty {
                        Divider()
                        Text("Allegati")
                            .font(.subheadline.bold())
                        VStack(spacing: 12) {
                            ForEach(attachments, id: \.pk) { allegato in
                                Button(action: {
                                    openAttachment(allegato)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "paperclip")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading) {
                                            Text(allegato.nomeFile)
                                                .foregroundStyle(.primary)
                                            if let descr = allegato.descrizioneFile, !descr.isEmpty {
                                                Text(descr)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right.square")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    private func openAttachment(_ allegato: Allegato) {
        if let url = URL(string: allegato.url), let scheme = url.scheme, scheme.starts(with: "http") {
            UIApplication.shared.open(url)
            return
        }
        
        Task {
            do {
                let link = try await client.getLinkAllegato(uid: allegato.pk)
                if let url = URL(string: link) {
                    await UIApplication.shared.open(url)
                }
            }
        }
    }
}
