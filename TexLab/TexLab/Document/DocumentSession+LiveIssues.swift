//
//  DocumentSession+LiveIssues.swift
//  TexLab
//

import Foundation

/// Live issues: problems found while typing, before typesetting, like Xcode's.
extension DocumentSession {
    /// Identifies live issues apart from TeX's, whose identifiers count from zero.
    private static let liveIssueIDBase = 1_000_000

    /// Checks the text again in the background, after a pause in typing or when the
    /// project changes.
    func checkLiveIssues() {
        liveIssuesTask?.cancel()
        guard UserDefaults.standard.bool(forKey: SettingsKey.showsLiveIssues), supportsVisualEditor else {
            if !liveIssues.isEmpty {
                liveIssues = []
                updateIssueMarkers()
            }
            return
        }
        let text = text
        let context = liveCheckContext
        let checkedDocument = currentDocument
        let source: SourceFile = fileURL.map { SourceFile.file($0) } ?? .currentDocument
        liveIssuesTask = Task { [weak self] in
            let found = await Task.detached(priority: .utility) {
                LiveChecker.check(text, context: context)
            }.value
            // The editor may show another file by now.
            guard !Task.isCancelled, let self, self.currentDocument === checkedDocument else { return }
            let issues = found.enumerated().map { index, issue in
                Issue(
                    id: Self.liveIssueIDBase + index,
                    severity: issue.severity,
                    message: issue.message,
                    source: source,
                    line: issue.line,
                    isLive: true
                )
            }
            if issues != self.liveIssues {
                self.liveIssues = issues
                self.updateIssueMarkers()
            }
        }
    }

    /// What the checks know about the rest of the project.
    private var liveCheckContext: LiveCheckContext {
        var context = LiveCheckContext()
        context.folder = projectFolder
        guard let project else {
            // An untitled document stands alone, so all its labels are in it.
            context.knowsAllLabels = fileURL == nil
            return context
        }
        context.knowsAllLabels = true
        context.otherLabels = Set(project.labels.map(\.key))
        context.verbatimEnvironments = project.verbatimEnvironments
        context.bibliographyKeys = Set(project.bibEntries.map(\.key))
        context.bibliographyFiles = Set(project.tree.files.filter { $0.kind == .bibliography }.map { SourceMap.canonicalPath($0.url) })
        return context
    }
}
