//
//  DocumentSession+Navigators.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The Find and References navigators.
extension DocumentSession {
    /// Shows a sidebar navigator, opening the sidebar if it's hidden.
    func showNavigator(_ tab: SidebarTab) {
        sidebarTab = tab
        if columnVisibility == .detailOnly {
            columnVisibility = .all
        }
    }

    /// Edit ▸ Find ▸ Find in Project: the Find navigator with its search field ready.
    func showFindInProject() {
        showNavigator(.find)
        let selection = editor.selectedRange
        if selection.length > 0, selection.length < 200 {
            findQuery = (text as NSString).substring(with: selection)
        }
        findFieldFocusRequest += 1
    }

    // MARK: - Search

    /// Searches every text file of the project, using the unsaved text of this document.
    func searchProject() {
        findTask?.cancel()
        let query = findQuery
        let options = findOptions
        guard !query.isEmpty else {
            findResults = []
            isSearchingProject = false
            return
        }
        // The shown file is named, so its results still lead to it after switching files.
        let shownName = fileURL.map { url in
            project.map { ProjectFileKind.displayPath(of: url, from: $0.folder) } ?? ProjectFileKind.displayName(of: url)
        } ?? displayName
        var sources: [(file: URL?, name: String, text: String?)] = [(fileURL, shownName, text)]
        if let fileURL, let project {
            let current = SourceMap.canonicalPath(fileURL)
            // Files open in this window are searched as they are, unsaved changes included.
            let openTexts = openFileTexts
            for file in project.tree.files where file.kind == .latex || file.kind == .bibliography || file.kind == .package || file.kind == .text {
                let path = SourceMap.canonicalPath(file.url)
                guard path != current else { continue }
                sources.append((file.url, ProjectFileKind.displayPath(of: file.url, from: project.folder), openTexts[path]))
            }
        }
        isSearchingProject = true
        findTask = Task { [weak self] in
            let results = await Task.detached(priority: .userInitiated) {
                ProjectSearch.run(query, options: options, sources: sources)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.findResults = results
            self.isSearchingProject = false
        }
    }

    /// Shows a search result: in this editor, or in the file's own window. The match itself
    /// is selected when the file is on screen here and the text there hasn't changed.
    func reveal(_ match: SearchMatch) {
        guard let file = match.file else {
            editor.reveal(location: match.location, length: match.length)
            return
        }
        open(file, line: match.line)
        guard let fileURL, SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(file) else { return }
        let range = NSRange(location: match.location, length: match.length)
        let string = text as NSString
        guard NSMaxRange(range) <= string.length,
              string.substring(with: range).compare(findQuery, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else { return }
        editor.reveal(location: match.location, length: match.length)
    }

    /// Shows where a label is defined.
    func reveal(_ label: LabelDefinition) {
        if let file = label.file {
            openProjectFile(file, line: label.line)
        } else {
            editor.revealLine(label.line)
        }
    }

    /// Shows a bibliography entry in its database.
    func reveal(_ entry: BibEntry) {
        if let file = entry.file {
            openProjectFile(file, line: entry.line)
        } else if let range = text.range(of: "\\bibitem{\(entry.key)}") {
            let location = NSRange(range, in: text).location
            editor.reveal(location: location, length: 0)
        }
    }

    /// Shows a line of a project file, in this window's editor.
    func openProjectFile(_ url: URL, line: Int) {
        open(url, line: line)
    }
}
