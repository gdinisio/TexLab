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
        var sources: [(file: URL?, name: String, text: String?)] = [(nil, displayName, text)]
        if let fileURL, let project {
            let current = SourceMap.canonicalPath(fileURL)
            for file in project.tree.files where file.kind == .latex || file.kind == .bibliography || file.kind == .package || file.kind == .text {
                guard SourceMap.canonicalPath(file.url) != current else { continue }
                sources.append((file.url, PathUtilities.relativePath(of: file.url, from: project.folder), nil))
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

    /// Shows a search result: in this editor, or in the file's own window.
    func reveal(_ match: SearchMatch) {
        if let file = match.file {
            openProjectFile(file, line: match.line)
        } else {
            editor.reveal(location: match.location, length: match.length)
        }
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

    /// Opens a project file and moves its editor to `line`.
    func openProjectFile(_ url: URL, line: Int) {
        SourceNavigator.requestReveal(of: line, in: url)
        openProjectFile(url)
    }
}
