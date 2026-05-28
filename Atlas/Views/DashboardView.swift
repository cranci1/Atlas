//
//  MainTabView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var client: ArgoClient
    @State private var isRefreshing = false
    @State private var showHomeworkSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if let profile = client.profile {
                        StudentHeaderCard(profile: profile)
                    }
                    
                    if let db = client.dashboard {
                        StatsRow(
                            dashboard: db,
                            tomorrowHomeworkCount: tomorrowHomeworkCount,
                            onHomeworkTap: { showHomeworkSheet = true }
                        )
                        
                        HorizontalSection(
                            title: "Bacheca",
                            icon: "megaphone.fill",
                            items: Array(db.bacheca.prefix(5)),
                            id: \.pk
                        ) { item in
                            CommunicationCard(
                                title: item.autore,
                                subtitle: item.categoria.isEmpty ? "Comunicazione" : item.categoria,
                                message: item.messaggio,
                                dateText: item.data.prefix(10),
                                unread: !item.isPresaVisione,
                                accentColor: .teal
                            )
                            .frame(width: 300)
                        }
                        
                        HorizontalSection(
                            title: "Promemoria",
                            icon: "bell.fill",
                            items: Array(upcomingPromemoria(from: db.promemoria).prefix(5)),
                            id: \.pk
                        ) { item in
                            CommunicationCard(
                                title: item.docente,
                                subtitle: "Promemoria",
                                message: item.desAnnotazioni,
                                dateText: item.datGiorno.prefix(10),
                                unread: false,
                                accentColor: .orange
                            )
                            .frame(width: 300)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable { await refresh() }
            .sheet(isPresented: $showHomeworkSheet) {
                HomeworkSheetView(items: tomorrowHomeworkItems)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func refresh() async {
        isRefreshing = true
        try? await client.fetchDashboard()
        isRefreshing = false
    }
}

struct HorizontalSection<Item, ID: Hashable, Content: View>: View {
    let title: String
    let icon: String
    let items: [Item]
    let id: KeyPath<Item, ID>
    @ViewBuilder let content: (Item) -> Content
    
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title, icon: icon)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items, id: id) { item in
                            content(item)
                        }
                    }
                }
            }
        }
    }
}

struct StudentHeaderCard: View {
    let profile: Profilo
    
    private var initials: String {
        let parts = profile.alunno.nominativo.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(.systemTeal), Color(.systemCyan)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    Text(initials)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bentornato")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.alunno.nominativo)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(profile.scheda.classe.desDenominazione)\(profile.scheda.classe.desSezione) · \(profile.scheda.scuola.descrizione)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .applyLiquidGlassBackground(cornerRadius: 24)
    }
}

struct StatsRow: View {
    let dashboard: DashboardDati
    let tomorrowHomeworkCount: Int
    let onHomeworkTap: () -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            StatCard(title: "Media", value: String(format: "%.1f", dashboard.mediaGenerale), icon: "chart.bar.fill", color: .blue)
            Button(action: onHomeworkTap) {
                StatCard(title: "Compiti", value: "\(tomorrowHomeworkCount)", icon: "backpack", color: .orange)
            }
            .buttonStyle(.plain)
            StatCard(title: "Eventi", value: "\(dashboard.appello.count)", icon: "calendar.badge.minus", color: .red)
        }
    }
}

struct HomeworkSheetView: View {
    let items: [HomeworkItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nessun compito",
                        systemImage: "backpack",
                        description: Text("Non risultano compiti in scadenza per domani.")
                    )
                } else {
                    List(items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.subject)
                                        .font(.headline)
                                    Text(item.teacher)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Text(item.dueDate)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.text)
                                .font(.body)
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Compiti di domani")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

struct HomeworkItem: Identifiable {
    let id: String
    let subject: String
    let teacher: String
    let dueDate: String
    let text: String
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.teal)
                .padding(8)
                .background(Color.teal.opacity(0.12), in: Circle())
            Text(title)
                .font(.headline)
        }
    }
}

private extension DashboardView {
    var tomorrowHomeworkCount: Int {
        tomorrowHomeworkItems.count
    }

    var tomorrowHomeworkItems: [HomeworkItem] {
        guard let registro = client.dashboard?.registro else { return [] }

        let tomorrowKey = AtlasDate.dayKey(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())

        return registro.flatMap { entry in
            entry.compiti.enumerated().compactMap { index, compito in
                guard compito.dataConsegna.prefix(10) == tomorrowKey else { return nil }
                return HomeworkItem(
                    id: "\(entry.pk)-\(index)-\(compito.dataConsegna)",
                    subject: entry.materia,
                    teacher: entry.docente,
                    dueDate: String(compito.dataConsegna.prefix(10)),
                    text: compito.compito
                )
            }
        }
        .sorted {
            if $0.dueDate == $1.dueDate { return $0.id < $1.id }
            return $0.dueDate < $1.dueDate
        }
    }
    
    func reminderDate(for item: Promemoria) -> Date? {
        AtlasDate.parseSchoolDateTime(day: item.datGiorno, time: item.oraInizio)
    }
    
    func upcomingPromemoria(from items: [Promemoria]) -> [Promemoria] {
        let now = Date()
        let upcoming = items.filter { (reminderDate(for: $0) ?? .distantPast) >= now }
        let source = upcoming.isEmpty ? items : upcoming
        
        return source.sorted {
            let leftDate = reminderDate(for: $0) ?? .distantFuture
            let rightDate = reminderDate(for: $1) ?? .distantFuture
            if leftDate == rightDate { return $0.pk < $1.pk }
            return leftDate < rightDate
        }
    }
}
