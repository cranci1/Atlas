//
//  RegistroView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

struct RegistroView: View {
    @EnvironmentObject var client: ArgoClient
    
    private var registro: [RegistroEntry] {
        (client.dashboard?.registro ?? []).sorted { $0.datGiorno > $1.datGiorno }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if registro.isEmpty {
                    ContentUnavailableView("Nessuna voce", systemImage: "book.closed", description: Text("Il registro è vuoto."))
                } else {
                    List(registro) { entry in
                        RegistroRow(entry: entry)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Registro")
        }
    }
}

struct RegistroRow: View {
    let entry: RegistroEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.materia)
                            .font(.subheadline.bold())
                        if !entry.isFirmato {
                            Image(systemName: "pencil.slash")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(entry.docente)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(entry.datGiorno.prefix(10))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Ora \(entry.ora)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let attivita = entry.attivita, !attivita.isEmpty {
                Text(attivita)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            
            if !entry.compiti.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Compiti", systemImage: "pencil.and.list.clipboard")
                        .font(.caption.bold())
                        .foregroundStyle(Color(.systemTeal))
                    ForEach(entry.compiti, id: \.dataConsegna) { compito in
                        HStack(alignment: .top, spacing: 6) {
                            Text(compito.compito)
                                .font(.caption)
                            Spacer()
                            Text(compito.dataConsegna.prefix(10))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemTeal).opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { isExpanded.toggle() } }
    }
}
