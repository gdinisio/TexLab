//
//  ReferencePickers.swift
//  TexLab
//

import Foundation
import SwiftUI

/// Picks bibliography entries to cite. Several can be selected; double-click or Return
/// inserts them as one citation.
struct CitationPicker: View {
    var session: DocumentSession
    var onDone: () -> Void

    @State private var search = ""
    @State private var selection: Set<BibEntry.ID> = []
    @State private var command = "cite"

    static let commands = ["cite", "citep", "citet", "parencite", "textcite", "autocite", "footcite", "nocite"]

    var body: some View {
        let entries = Self.unique(session.allBibEntries)
        let shown = filtered(entries)
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search by key, author, title or year", text: $search)
                    .textFieldStyle(.roundedBorder)
                Picker("Command", selection: $command) {
                    ForEach(Self.commands, id: \.self) { name in
                        Text(verbatim: "\\" + name).tag(name)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(10)
            Divider()
            if entries.isEmpty {
                ContentUnavailableView {
                    Label("No Bibliography", systemImage: "books.vertical")
                } description: {
                    Text("Add a bibliography with File ▸ New File in Project, or \\bibitem entries to the document.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(shown, selection: $selection) { entry in
                    BibEntryRow(entry: entry)
                        .tag(entry.id)
                }
                .contextMenu(forSelectionType: BibEntry.ID.self) { _ in
                    EmptyView()
                } primaryAction: { ids in
                    insert(ids, from: entries)
                }
            }
            Divider()
            HStack {
                Text(selection.isEmpty ? "Select one or more entries" : "\(selection.count) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel, action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Insert") {
                    insert(selection, from: entries)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 480, height: 420)
        .onAppear {
            if session.text.contains("biblatex") {
                command = "autocite"
            }
        }
    }

    private func filtered(_ entries: [BibEntry]) -> [BibEntry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter { entry in
            [entry.key, entry.authors, entry.title, entry.year].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func insert(_ ids: Set<BibEntry.ID>, from entries: [BibEntry]) {
        let keys = entries.filter { ids.contains($0.id) }.map(\.key)
        guard !keys.isEmpty else { return }
        var seen = Set<String>()
        session.insertCitation(keys: keys.filter { seen.insert($0).inserted }, command: command)
        onDone()
    }

    /// One row per entry, even if a database lists a key twice.
    static func unique(_ entries: [BibEntry]) -> [BibEntry] {
        var seen = Set<BibEntry.ID>()
        return entries.filter { seen.insert($0.id).inserted }
    }
}

/// A bibliography entry: key, short citation and title.
struct BibEntryRow: View {
    var entry: BibEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Label {
                    Text(verbatim: entry.key)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: entry.systemImage)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(verbatim: entry.shortCitation)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !entry.title.isEmpty {
                Text(verbatim: entry.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// How a cross-reference is written.
nonisolated enum ReferenceStyle: String, CaseIterable, Identifiable {
    /// `\eqref` for equations, `\ref` for everything else.
    case automatic
    case ref, eqref, pageref, autoref, cref

    var id: String { rawValue }

    var title: String {
        self == .automatic ? String(localized: "Automatic") : "\\" + rawValue
    }

    func command(for label: LabelDefinition) -> String {
        self == .automatic ? label.preferredReferenceCommand : rawValue
    }
}

/// Picks a label to refer to, grouped by what it labels.
struct ReferencePicker: View {
    var session: DocumentSession
    var onDone: () -> Void

    @State private var search = ""
    @State private var selection: LabelDefinition.ID?
    @State private var style: ReferenceStyle = .automatic

    var body: some View {
        let labels = session.allLabels
        let groups = Self.groups(filtered(labels))
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search labels", text: $search)
                    .textFieldStyle(.roundedBorder)
                Picker("Style", selection: $style) {
                    ForEach(ReferenceStyle.allCases) { style in
                        Text(verbatim: style.title).tag(style)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(10)
            Divider()
            if labels.isEmpty {
                ContentUnavailableView {
                    Label("No Labels", systemImage: "tag")
                } description: {
                    Text("Add \\label{…} to a section, figure, table or equation to refer to it.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: $selection) {
                    ForEach(groups, id: \.title) { group in
                        Section(group.title) {
                            ForEach(group.labels) { label in
                                LabelRow(label: label)
                                    .tag(label.id)
                            }
                        }
                    }
                }
                .contextMenu(forSelectionType: LabelDefinition.ID.self) { _ in
                    EmptyView()
                } primaryAction: { ids in
                    if let id = ids.first {
                        insert(id, from: labels)
                    }
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onDone)
                    .keyboardShortcut(.cancelAction)
                Button("Insert") {
                    if let selection {
                        insert(selection, from: labels)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
            .padding(10)
        }
        .frame(width: 440, height: 420)
    }

    private func filtered(_ labels: [LabelDefinition]) -> [LabelDefinition] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return labels }
        return labels.filter { $0.key.localizedCaseInsensitiveContains(query) }
    }

    private func insert(_ id: LabelDefinition.ID, from labels: [LabelDefinition]) {
        guard let label = labels.first(where: { $0.id == id }) else { return }
        session.insertCrossReference(to: label, command: style.command(for: label))
        onDone()
    }

    /// Labels grouped by kind, in reading order within each group.
    static func groups(_ labels: [LabelDefinition]) -> [(title: String, labels: [LabelDefinition])] {
        let order: [LabelDefinition.Kind] = [.chapter, .section, .figure, .table, .equation, .theorem, .listing, .item, .other]
        var seen = Set<LabelDefinition.ID>()
        let unique = labels.filter { seen.insert($0.id).inserted }
        return order.compactMap { kind in
            let matching = unique.filter { $0.kind == kind }
            return matching.isEmpty ? nil : (kind.title, matching)
        }
    }
}

/// A label: its key, and where it's defined.
struct LabelRow: View {
    var label: LabelDefinition

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(verbatim: label.key)
            } icon: {
                Image(systemName: label.kind.systemImage)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(verbatim: location)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var location: String {
        let file = label.file?.lastPathComponent ?? String(localized: "This document")
        return "\(file):\(label.line)"
    }
}
