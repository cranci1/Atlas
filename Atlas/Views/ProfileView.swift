//
//  ProfileView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var client: ArgoClient
    @State private var dettagli: DettagliProfilo?
    @State private var isLoading = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                if let profile = client.profile {
                    Section {
                        ProfileHeaderRow(profile: profile)
                    }
                    
                    Section("Scuola") {
                        LabeledRow(label: "Istituto", value: profile.scheda.scuola.descrizione)
                        LabeledRow(label: "Classe",   value: "\(profile.scheda.classe.desDenominazione)\(profile.scheda.classe.desSezione)")
                        LabeledRow(label: "Corso",    value: profile.scheda.corso.descrizione)
                        LabeledRow(label: "Sede",     value: profile.scheda.sede.descrizione)
                        LabeledRow(label: "Anno",     value: profile.anno.anno)
                    }
                }
                
                Section {
                    if let d = dettagli {
                        LabeledRow(label: "Email genitore", value: d.genitore.desEMail)
                        LabeledRow(label: "Email alunno",   value: d.alunno.desEMail ?? "—")
                        LabeledRow(label: "Codice Fiscale", value: d.alunno.desCf)
                        LabeledRow(label: "Nascita",        value: d.alunno.datNascita.prefix(10).description)
                        LabeledRow(label: "Comune",         value: d.alunno.desComuneResidenza)
                        LabeledRow(label: "Cittadinanza",   value: d.alunno.cittadinanza)
                    } else {
                        Button {
                            Task { await loadDetails() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.text.rectangle")
                                }
                                Text("Carica dati dettagliati")
                            }
                        }
                        .foregroundStyle(Color(.systemTeal))
                    }
                } header: {
                    Text("Dettagli")
                }
                
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Esci")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profilo")
            .alert("Esci dall'account?", isPresented: $showLogoutAlert) {
                Button("Esci", role: .destructive) {
                    Task {
                        try? await client.logOut()
                    }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Dovrai effettuare di nuovo il login.")
            }
        }
    }
    
    private func loadDetails() async {
        isLoading = true
        defer { isLoading = false }
        dettagli = try? await client.getDettagliProfilo()
    }
}

struct ProfileHeaderRow: View {
    let profile: Profilo
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(.systemTeal), Color(.systemCyan)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Text(initials)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.alunno.nominativo)
                    .font(.headline)
                Text(profile.genitore.nominativo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(profile.genitore.desEMail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var initials: String {
        let parts = profile.alunno.nominativo.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}
