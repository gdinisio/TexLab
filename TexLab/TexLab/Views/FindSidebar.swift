//
//  FindSidebar.swift
//  TexLab
//

import Foundation
import SwiftUI

/// The Find navigator: searches every text file of the project, including changes to this
/// document that aren't saved yet. Selecting a result shows it in the editor.
struct FindSidebar: View {
    @Bindable var session: DocumentSession
    @FocusState private var isSearchFieldFocused: Bool
    @State private var selection: SearchMatch.ID?

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            results
        }
        .onChange(of: session.findFieldFocusRequest, initial: true) {
            isSearchFieldFocused = true
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find in Project", text: $session.findQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        session.searchProject()
                    }
                if !session.findQuery.isEmpty {
                    Button {
                        session.findQuery = ""
                        session.searchProject()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")
                }
                Menu {
                    Toggle("Match Case", isOn: $session.findOptions.matchesCase)
                    Toggle("Whole Words", isOn: $session.findOptions.wholeWords)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Search options")
            }
            .padding(6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            if let summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onChange(of: session.findOptions) {
            session.searchProject()
        }
        .task(id: session.findQuery) {
            // Search as you type, after a short pause.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            session.searchProject()
        }
    }

    @ViewBuilder
    private var results: some View {
        if session.findQuery.isEmpty {
            ContentUnavailableView {
                Label("Find in Project", systemImage: "magnifyingglass")
            } description: {
                Text("Search every LaTeX file, bibliography and package in the project. ⇧⌘F starts a search from anywhere.")
            }
        } else if session.findResults.isEmpty && !session.isSearchingProject {
            ContentUnavailableView.search(text: session.findQuery)
        } else {
            List(selection: $selection) {
                ForEach(session.findResults) { file in
                    Section {
                        ForEach(file.matches) { match in
                            SearchMatchRow(match: match)
                                .tag(match.id)
                        }
                    } header: {
                        Label(file.name, systemImage: file.file.map { ProjectFileKind(url: $0, isDirectory: false).systemImage } ?? "doc.text")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selection) { _, newValue in
                guard let newValue, let match = session.findResults.lazy.flatMap(\.matches).first(where: { $0.id == newValue }) else { return }
                session.reveal(match)
            }
        }
    }

    private var summary: String? {
        guard !session.findQuery.isEmpty, !session.isSearchingProject else { return nil }
        let count = session.findResults.reduce(0) { $0 + $1.matches.count }
        guard count > 0 else { return nil }
        let files = session.findResults.count
        if count >= ProjectSearch.maximumMatches {
            return String(localized: "The first \(count) results in \(files) files")
        }
        return files == 1
            ? String(localized: "\(count) results in 1 file")
            : String(localized: "\(count) results in \(files) files")
    }
}

/// A result: the line number and the line, with the match in bold.
private struct SearchMatchRow: View {
    var match: SearchMatch

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(verbatim: "\(match.line)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            Text(preview)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .help(match.preview)
    }

    private var preview: AttributedString {
        var text = AttributedString(match.preview)
        if let lower = AttributedString.Index(match.previewMatch.lowerBound, within: text),
           let upper = AttributedString.Index(match.previewMatch.upperBound, within: text) {
            text[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            text[lower..<upper].backgroundColor = Color.yellow.opacity(0.35)
        }
        return text
    }
}
