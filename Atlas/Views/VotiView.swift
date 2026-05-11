//
//  VotiView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import Charts
import SwiftUI

func averageColor(_ avg: Double) -> Color {
    if avg >= 6 { return .green }
    if avg >= 5 { return .orange }
    return .red
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
    
    var body: some View {
        NavigationStack {
            Group {
                if voti.isEmpty {
                    ContentUnavailableView("Nessun voto", systemImage: "star.slash", description: Text("Non ci sono voti disponibili."))
                } else {
                    SubjectsListView(voti: voti)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGroupedBackground))
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
    
    private var sortedVotes: [Voto] {
        votes.sorted { $0.datGiorno < $1.datGiorno }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private var stats: VoteStats {
        VoteStats(votes: sortedVotes)
    }
    
    private var minChartVoto: Double {
        max(stats.minVote - 0.15, 0)
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
                            let date = dateFormatter.date(from: voto.datGiorno) ?? Date()
                            
                            LineMark(
                                x: .value("Data", date),
                                y: .value("Voto", voto.valore)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .foregroundStyle(.teal.opacity(0.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 250)
                    .chartYScale(domain: minChartVoto...10)
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
                    VotoRow(voto: voto, hideSubject: true)
                }
            } header: {
                Text("Voti")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subject)
        .navigationBarTitleDisplayMode(.inline)
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
                Text(formatGradeValue(voto.valore))
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
    
    private func formatGradeValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private var gradeColor: Color { averageColor(voto.valore) }
}

