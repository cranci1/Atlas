//
//  RegistroView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

struct RegistroView: View {
    @EnvironmentObject var client: ArgoClient
    
    @State private var selectedSubject: String?
    @State private var selectedTeacher: String?
    @State private var selectedDate: Date?
    @State private var showFilters = false
    
    private var allEntries: [RegistroEntry] {
        (client.dashboard?.registro ?? []).sorted { $0.datGiorno > $1.datGiorno }
    }
    
    private var filteredEntries: [RegistroEntry] {
        allEntries.filter { entry in
            let subjectMatch = selectedSubject.isNilOrEmpty || entry.materia == selectedSubject
            let teacherMatch = selectedTeacher.isNilOrEmpty || entry.docente == selectedTeacher
            let dateMatch: Bool = {
                guard let selectedDate else { return true }
                return String(entry.datGiorno.prefix(10)) == AtlasDate.dayKey(from: selectedDate)
            }()
            return subjectMatch && teacherMatch && dateMatch
        }
    }
    
    private var groupedByDay: [(day: String, entries: [RegistroEntry])] {
        Dictionary(grouping: filteredEntries) { $0.datGiorno.prefix(10) }
            .sorted { $0.key > $1.key }
            .map { (
                day: String($0.key),
                entries: $0.value.sorted { Int($0.ora) > Int($1.ora) }
            )}
    }
    
    private var uniqueSubjects: [String] {
        Array(Set(allEntries.map { $0.materia })).sorted()
    }
    
    private var uniqueTeachers: [String] {
        Array(Set(allEntries.map { $0.docente })).sorted()
    }
    
    private var hasActiveFilters: Bool {
        !selectedSubject.isNilOrEmpty || !selectedTeacher.isNilOrEmpty || selectedDate != nil
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "Nessuna voce",
                        systemImage: "book.closed",
                        description: Text("Il registro è vuoto.")
                    )
                } else {
                    List {
                        ForEach(groupedByDay, id: \.day) { group in
                            Section(header: Text(formatDate(group.day))) {
                                ForEach(group.entries) { entry in
                                    RegistroRow(entry: entry)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Registro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(hasActiveFilters ? .blue : .gray)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FiltersView(
                    selectedSubject: $selectedSubject,
                    selectedTeacher: $selectedTeacher,
                    selectedDate: $selectedDate,
                    subjects: uniqueSubjects,
                    teachers: uniqueTeachers,
                    onReset: resetFilters
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func resetFilters() {
        selectedSubject = nil
        selectedTeacher = nil
        selectedDate = nil
    }
    
    private func formatDate(_ dateString: String) -> String {
        AtlasDate.italianLongDay(from: dateString)
    }
}

struct RegistroRow: View {
    let entry: RegistroEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            activityText
            homeworkSection
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { isExpanded.toggle() } }
        .contextMenu {
            Button(action: copyToClipboard) {
                Label("Copia", systemImage: "doc.on.doc")
            }
        }
    }
    
    private var headerRow: some View {
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
    }
    
    @ViewBuilder
    private var activityText: some View {
        if let attivita = entry.attivita, !attivita.isEmpty {
            Text(attivita)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : 2)
        }
    }
    
    @ViewBuilder
    private var homeworkSection: some View {
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
    
    private func copyToClipboard() {
        var lines = ["\(entry.materia) - \(entry.docente)", "\(entry.datGiorno) Ora \(entry.ora)"]
        if let attivita = entry.attivita, !attivita.isEmpty {
            lines += ["", "Attività:", attivita]
        }
        if !entry.compiti.isEmpty {
            lines += ["", "Compiti:"]
            lines += entry.compiti.map { "- \($0.compito) (Consegna: \($0.dataConsegna))" }
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }
}

struct FiltersView: View {
    @Binding var selectedSubject: String?
    @Binding var selectedTeacher: String?
    @Binding var selectedDate: Date?
    let subjects: [String]
    let teachers: [String]
    let onReset: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Materia") {
                    Picker("Seleziona materia", selection: $selectedSubject) {
                        Text("Tutte").tag(nil as String?)
                        Divider()
                        ForEach(subjects, id: \.self) { Text($0).tag($0 as String?) }
                    }
                }
                
                Section("Docente") {
                    Picker("Seleziona docente", selection: $selectedTeacher) {
                        Text("Tutti").tag(nil as String?)
                        Divider()
                        ForEach(teachers, id: \.self) { Text($0).tag($0 as String?) }
                    }
                }
                
                Section("Data") {
                    DatePicker(
                        "Seleziona data",
                        selection: Binding(
                            get: { selectedDate ?? Date() },
                            set: { selectedDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    if selectedDate != nil {
                        Button(action: { selectedDate = nil }) {
                            Label("Cancella data", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section {
                    Button(action: { onReset(); dismiss() }) {
                        HStack {
                            Spacer()
                            Label("Ripristina filtri", systemImage: "arrow.counterclockwise")
                            Spacer()
                        }
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filtri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fatto") { dismiss() }
                }
            }
        }
    }
}

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool { self?.isEmpty ?? true }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
