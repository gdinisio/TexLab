//
//  ReferencesSidebar.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The References navigator: every label and bibliography entry in the project.
/// Double-click one to refer to it at the insertion point, drag it into the text, or use
/// the context menu to go to its definition.
struct ReferencesSidebar: View {
    var session: DocumentSession

    private enum Kind: String, CaseIterable, Identifiable {
        case labels, bibliography
        var id: String { rawValue }
    }

    @State private var kind: Kind = .labels
    @State private var search = ""
    @State private var labelSelection: LabelDefinition.ID?
    @State private var entrySelection: BibEntry.ID?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("Show", selection: $kind) {
                    Text("Labels").tag(Kind.labels)
                    Text("Bibliography").tag(Kind.bibliography)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                TextField(kind == .labels ? "Filter labels" : "Filter by key, author, title or year", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Divider()
            switch kind {
            case .labels:
                labels
            case .bibliography:
                bibliography
            }
        }
    }

    // MARK: - Labels

    @ViewBuilder
    private var labels: some View {
        let all = session.allLabels
        let groups = ReferencePicker.groups(all.filter { search.isEmpty || $0.key.localizedCaseInsensitiveContains(search) })
        if all.isEmpty {
            ContentUnavailableView {
                Label("No Labels", systemImage: "tag")
            } description: {
                Text("Labels you add with \\label{…} appear here, from every file of the project.")
            }
        } else {
            List(selection: $labelSelection) {
                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.labels) { label in
                            LabelRow(label: label)
                                .tag(label.id)
                                .draggable("\\\(label.preferredReferenceCommand){\(label.key)}")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .contextMenu(forSelectionType: LabelDefinition.ID.self) { ids in
                if let label = all.first(where: { ids.contains($0.id) }) {
                    labelMenu(label)
                }
            } primaryAction: { ids in
                if let label = all.first(where: { ids.contains($0.id) }) {
                    session.insertCrossReference(to: label)
                }
            }
        }
    }

    @ViewBuilder
    private func labelMenu(_ label: LabelDefinition) -> some View {
        ForEach(ReferenceStyle.allCases.filter { $0 != .automatic }) { style in
            Button("Insert \\\(style.rawValue){\(label.key)}") {
                session.insertCrossReference(to: label, command: style.rawValue)
            }
        }
        Divider()
        Button("Show Definition") {
            session.reveal(label)
        }
        Button("Copy Label") {
            Pasteboard.copy(label.key)
        }
    }

    // MARK: - Bibliography

    @ViewBuilder
    private var bibliography: some View {
        let all = CitationPicker.unique(session.allBibEntries)
        let shown = all.filter { entry in
            search.isEmpty || [entry.key, entry.authors, entry.title, entry.year].contains { $0.localizedCaseInsensitiveContains(search) }
        }
        if all.isEmpty {
            ContentUnavailableView {
                Label("No Bibliography", systemImage: "books.vertical")
            } description: {
                Text("Entries from the project’s .bib files appear here. Add one with File ▸ New File in Project.")
            }
        } else {
            List(shown, selection: $entrySelection) { entry in
                BibEntryRow(entry: entry)
                    .tag(entry.id)
                    .draggable("\\cite{\(entry.key)}")
            }
            .listStyle(.sidebar)
            .contextMenu(forSelectionType: BibEntry.ID.self) { ids in
                if let entry = all.first(where: { ids.contains($0.id) }) {
                    entryMenu(entry)
                }
            } primaryAction: { ids in
                let keys = all.filter { ids.contains($0.id) }.map(\.key)
                session.insertCitation(keys: keys)
            }
        }
    }

    @ViewBuilder
    private func entryMenu(_ entry: BibEntry) -> some View {
        ForEach(["cite", "citep", "citet", "autocite"], id: \.self) { command in
            Button("Insert \\\(command){\(entry.key)}") {
                session.insertCitation(keys: [entry.key], command: command)
            }
        }
        Divider()
        Button("Show in Bibliography") {
            session.reveal(entry)
        }
        Button("Copy Key") {
            Pasteboard.copy(entry.key)
        }
    }
}

/// Copies text to the general pasteboard.
enum Pasteboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
