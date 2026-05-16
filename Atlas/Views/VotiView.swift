//
//  VotiView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import Charts
import SwiftUI

func averageColor(_ avg: Double) -> Color {
    switch avg {
    case 6...: .green
    case 5..<6: .orange
    default: .red
    }
}

func calculateAverage(_ grades: [Voto]) -> Double {
    let counting = grades.filter { $0.faMenoMedia != "S" }
    guard !counting.isEmpty else { return 0 }
    return counting.map(\.valore).reduce(0, +) / Double(counting.count)
}

struct VoteStats {
    let votes: [Voto]
    
    var average: Double {
        calculateAverage(votes)
    }
    
    var minVote: Double {
        let counting = votes.filter { $0.faMenoMedia != "S" }
        return counting.map(\.valore).min() ?? 0
    }
    
    var maxVote: Double {
        let counting = votes.filter { $0.faMenoMedia != "S" }
        return counting.map(\.valore).max() ?? 0
    }
}

struct VotiView: View {
    @EnvironmentObject var client: ArgoClient
    
    private var voti: [Voto] { client.dashboard?.voti ?? [] }
    private var periodi: [Periodo] {
        let list = client.dashboard?.listaPeriodi ?? []
        return list.sorted { lhs, rhs in
            periodoOrder(lhs.codPeriodo) < periodoOrder(rhs.codPeriodo)
        }
    }
    @State private var selectedPeriodoIndex: Int = 0
    
    private func computeDefaultPeriodoIndex() {
        guard !periodi.isEmpty else { selectedPeriodoIndex = 0; return }
        let today = Date()
        if let idx = periodi.firstIndex(where: { periodo in
            guard periodo.codPeriodo != "*" else { return false }
            let startString = periodo.datInizio ?? periodo.dataInizio
            let endString = periodo.datFine ?? periodo.dataFine
            guard let start = AtlasDate.parseSchoolDate(startString), let end = AtlasDate.parseSchoolDate(endString) else { return false }
            return (start...end).contains(today)
        }) {
            selectedPeriodoIndex = idx
        } else if let fullIdx = periodi.firstIndex(where: { $0.codPeriodo == "*" }) {
            selectedPeriodoIndex = fullIdx
        } else {
            selectedPeriodoIndex = 0
        }
    }
    
    private var periodiFiltrati: [Voto] {
        guard !periodi.isEmpty else { return voti }
        let safeIndex = min(selectedPeriodoIndex, periodi.count - 1)
        let selectedPeriodo = periodi[safeIndex]
        if selectedPeriodo.codPeriodo == "*" { return voti }
        let startString = selectedPeriodo.datInizio ?? selectedPeriodo.dataInizio
        let endString = selectedPeriodo.datFine ?? selectedPeriodo.dataFine
        
        return voti.filter { voto in
            guard let votoDate = AtlasDate.parseISODate(voto.datGiorno),
                  let initDate = AtlasDate.parseSchoolDate(startString),
                  let endDate = AtlasDate.parseSchoolDate(endString) else {
                return false
            }
            return votoDate >= initDate && votoDate <= endDate
        }
    }
    
    private func periodoOrder(_ code: String) -> Int {
        switch code {
        case "1Q": return 0
        case "SF", "2Q": return 1
        case "*": return 2
        default: return 3
        }
    }
    
    private func periodoDisplayName(_ periodo: Periodo) -> String {
        switch periodo.codPeriodo {
        case "1Q":
            return "Primo Q"
        case "SF", "2Q":
            return "Secondo Q"
        case "*":
            return "Intero anno"
        default:
            return periodo.descrizione.capitalized
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if voti.isEmpty {
                    ContentUnavailableView("Nessun voto", systemImage: "star.slash", description: Text("Non ci sono voti disponibili."))
                } else {
                    VStack(spacing: 0) {
                        if !periodi.isEmpty {
                            Picker("Periodo", selection: $selectedPeriodoIndex) {
                                ForEach(periodi.indices, id: \.self) { index in
                                    Text(periodoDisplayName(periodi[index]))
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            .onAppear { computeDefaultPeriodoIndex() }
                        }
                        
                        SubjectsListView(voti: periodiFiltrati)
                            .scrollContentBackground(.hidden)
                            .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .navigationTitle("Voti")
        }
    }
}

struct SubjectsListView: View {
    let voti: [Voto]
    
    private var subjects: [(String, [Voto])] {
        Dictionary(grouping: voti, by: \.desMateria)
            .map { ($0.key, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        List {
            ForEach(subjects, id: \.0) { materia, grades in
                NavigationLink {
                    SubjectDetailView(subject: materia, votes: grades)
                } label: {
                    HStack(spacing: 12) {
                        let avg = calculateAverage(grades)
                        ZStack {
                            Circle()
                                .fill(averageColor(avg).opacity(0.15))
                                .frame(width: 48, height: 48)
                            
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(averageColor(avg))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(materia)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("\(grades.count) voti")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SubjectDetailView: View {
    let subject: String
    let votes: [Voto]
    @State private var selectedVote: Voto? = nil
    
    private var sortedVotes: [Voto] {
        votes.sorted { $0.datGiorno > $1.datGiorno }
    }
    
    private var stats: VoteStats {
        VoteStats(votes: sortedVotes)
    }
    
    private var minChartVoto: Double {
        max(stats.minVote - 0.15, 0)
    }
    
    private var maxChartVoto: Double {
        min(stats.maxVote + 0.15, 10)
    }
    
    var body: some View {
        List {
            Section {
                if sortedVotes.isEmpty {
                    Text("Nessun voto disponibile")
                        .foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(sortedVotes, id: \.pk) { voto in
                            let date = AtlasDate.parseISODate(voto.datGiorno) ?? Date()
                            
                            LineMark(
                                x: .value("Data", date),
                                y: .value("Voto", voto.valore)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .foregroundStyle(.teal.opacity(0.5))
                            .interpolationMethod(.monotone)
                        }
                        
                        RuleMark(y: .value("Media", stats.average))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(averageColor(stats.average).opacity(0.8))
                            .annotation(position: .trailing, alignment: .center) {
                                Text(String(format: "%.1f", stats.average))
                                    .font(.caption2.bold())
                                    .foregroundStyle(averageColor(stats.average))
                            }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: minChartVoto...maxChartVoto)
                    .padding(.vertical)
                }
            }
            
            Section {
                HStack {
                    Label("Media", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(String(format: "%.1f", stats.average))
                        .font(.headline)
                        .foregroundStyle(averageColor(stats.average))
                }
                HStack {
                    Label("Massimo", systemImage: "arrow.up")
                    Spacer()
                    Text(String(format: "%.1f", stats.maxVote))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                HStack {
                    Label("Minimo", systemImage: "arrow.down")
                    Spacer()
                    Text(String(format: "%.1f", stats.minVote))
                        .font(.headline)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Statistiche")
            }
            
            Section {
                ForEach(sortedVotes) { voto in
                    Button {
                        selectedVote = voto
                    } label: {
                        VotoRow(voto: voto, hideSubject: true)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Voti")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subject)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedVote) { voto in
            VoteDetailView(voto: voto)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
    }
}

struct VoteDetailView: View {
    let voto: Voto
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(voto.desMateria)
                                    .font(.headline)
                                Text(voto.docente)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(voto.codCodice)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(averageColor(voto.valore))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(averageColor(voto.valore).opacity(0.15), in: Capsule())
                        }
                        
                        Text(voto.descrizioneProva.isEmpty ? "" : voto.descrizioneProva)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if !voto.desCommento.isEmpty {
                            VoteInfoRow(title: "Commento", value: voto.desCommento)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Dettaglio voto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

struct VoteInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
    }
}

struct VotoRow: View {
    let voto: Voto
    var hideSubject: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(gradeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(voto.codCodice)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if !hideSubject {
                    Text(voto.desMateria)
                        .font(.caption.bold())
                        .lineLimit(1)
                }
                Text(voto.docente)
                    .font(.caption)
                
                if !voto.descrizioneProva.isEmpty {
                    Text(voto.descrizioneProva)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(voto.datGiorno.prefix(10))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
    
    private var gradeColor: Color { averageColor(voto.valore) }
}
