//
//  DocumentSession.swift
//  TexLab
//

import Foundation
import Observation

/// The state of one document window: the editor, cursor position and statistics.
///
/// Each window owns a session. Views observe it, and menu commands reach the focused
/// window's session through `FocusedValues`.
@Observable
final class DocumentSession {
    let editor = EditorController()

    /// The document's location on disk, or nil while it is untitled.
    var fileURL: URL?

    private(set) var caretLine = 1
    private(set) var caretColumn = 1
    private(set) var selectionLength = 0
    private(set) var wordCount = 0

    /// The latest source text.
    @ObservationIgnored private(set) var text = ""
    @ObservationIgnored private var analysisTask: Task<Void, Never>?

    var documentDirectory: URL? {
        fileURL?.deletingLastPathComponent()
    }

    /// The document's name without its extension, as shown in the title bar.
    var displayName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Untitled")
    }

    // MARK: - Lifecycle

    /// Called when the window appears with the document's initial contents.
    func start(text: String, fileURL: URL?) {
        self.text = text
        self.fileURL = fileURL
        analyze()
    }

    /// Called when the window closes.
    func stop() {
        analysisTask?.cancel()
    }

    // MARK: - Editing

    func sourceDidChange(_ text: String) {
        self.text = text
        scheduleAnalysis()
    }

    func selectionDidChange() {
        let position = editor.caretPosition
        caretLine = position.line
        caretColumn = position.column
        selectionLength = editor.selectedRange.length
    }

    /// Text inserted when files are dropped on the editor: graphics become
    /// `\includegraphics`, sources `\input` and bibliographies `\bibliography`.
    func textForDroppedFiles(_ urls: [URL]) -> String {
        urls.map { url in
            let path = documentDirectory.map { PathUtilities.relativePath(of: url, from: $0) } ?? url.filePath
            let pathWithoutExtension = String(path.dropLast(url.pathExtension.isEmpty ? 0 : url.pathExtension.count + 1))
            switch url.pathExtension.lowercased() {
            case "pdf", "png", "jpg", "jpeg", "eps":
                return "\\includegraphics[width=\\linewidth]{\(path)}"
            case "tex":
                return "\\input{\(pathWithoutExtension)}"
            case "bib":
                return "\\bibliography{\(pathWithoutExtension)}"
            default:
                return path
            }
        }
        .joined(separator: "\n")
    }

    // MARK: - Analysis

    private func scheduleAnalysis() {
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.analyze()
        }
    }

    private func analyze() {
        wordCount = WordCounter.count(in: text)
    }
}
