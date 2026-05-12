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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    if let profile = client.profile {
                        StudentHeaderCard(profile: profile)
                    }
                    
                    if let db = client.dashboard {
                        StatsRow(dashboard: db, tomorrowHomeworkCount: tomorrowHomeworkCount)
                        
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
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
            StatCard(title: "Media", value: String(format: "%.1f", dashboard.mediaGenerale), icon: "chart.bar.fill", color: .blue)
            StatCard(title: "Compiti", value: "\(tomorrowHomeworkCount)", icon: "calendar.badge.clock", color: .orange)
            StatCard(title: "Eventi", value: "\(dashboard.appello.count)", icon: "calendar.badge.minus", color: .red)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .applyLiquidGlassBackground(cornerRadius: 20)
    }
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

struct CommunicationCard: View {
    let title: String
    let subtitle: String
    let message: String
    let dateText: Substring
    let unread: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .applyLiquidGlassBackground(cornerRadius: 18)
    }
}

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

private extension DashboardView {
    var tomorrowHomeworkCount: Int {
        guard let registro = client.dashboard?.registro else { return 0 }
        
        let tomorrowKey = Self.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        
        return registro.reduce(into: 0) { total, entry in
            total += entry.compiti.filter { $0.dataConsegna.prefix(10) == tomorrowKey }.count
        }
    }
    
    func reminderDate(for item: Promemoria) -> Date? {
        Self.dateTimeFormatter.date(from: "\(item.datGiorno) \(item.oraInizio)") ?? Self.dayFormatter.date(from: item.datGiorno)
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
    
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
