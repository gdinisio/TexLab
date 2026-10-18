//
//  DocumentSession+Files.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// The documents of a window, like the files of an Xcode project window: the project
/// navigator, search results, issues, SyncTeX and Jump to Definition show any text file of
/// the project in this window's editor, each where it was left, and the preview keeps
/// showing the whole document. Each file is a document of its own, which saves itself.
extension DocumentSession {
    /// The window's subtitle: the project, and how typesetting went.
    var windowSubtitle: String {
        let summary = status.summary
        guard let folder = project?.folder ?? (fileURL == nil ? nil : documentDirectory) else { return summary }
        let name = folder.lastPathComponent
        return summary.isEmpty ? name : "\(name) — \(summary)"
    }

    /// The name of the document the editor shows.
    var currentName: String {
        currentDocument?.state.name ?? displayName
    }

    /// Whether the editor shows `url`.
    func isShowing(_ url: URL) -> Bool {
        currentDocument?.matches(url) ?? false
    }

    // MARK: - Showing documents

    /// Shows a line of a file: here if the editor shows it, as a document of this window if
    /// it belongs to the project, or in its project's window otherwise.
    func open(_ url: URL, line: Int?) {
        if isShowing(url) {
            if let line {
                editor.revealLine(line)
            }
            return
        }
        if showFile(url, line: line) {
            return
        }
        TeXDocumentController.open(url, line: line)
    }

    /// Shows a text file of the project in the editor, opening it as a document of this
    /// window if it isn't open yet. A file another window has open is shown there. Returns
    /// false for files that belong in a window of their own.
    @discardableResult
    func showFile(_ url: URL, line: Int? = nil) -> Bool {
        if let document = documents.first(where: { $0.matches(url) }) {
            show(document, line: line)
            return true
        }
        if let document = NSDocumentController.shared.document(for: url) as? TeXDocument,
           let owner = document.projectWindow, owner !== windowController {
            owner.display(document, line: line)
            owner.showWindow(nil)
            return true
        }
        guard canShowInWindow(url) else { return false }
        Task { [weak self] in
            do {
                let document = try await TeXDocumentController.openForProject(url)
                guard let self else { return }
                if let owner = document.projectWindow, owner !== self.windowController {
                    owner.display(document, line: line)
                    owner.showWindow(nil)
                } else {
                    self.show(document, line: line)
                }
            } catch {
                self?.presentError(error)
            }
        }
        return true
    }

    /// Whether `url` is a text file of this window's project, which the editor can show.
    func canShowInWindow(_ url: URL) -> Bool {
        guard ProjectFileKind(url: url, isDirectory: false).opensInTexLab,
              FileManager.default.fileExists(atPath: url.filePath) else { return false }
        let folders = [project?.folder, windowController?.projectFolder].compactMap { $0 }
        return folders.contains { folder in
            SourceMap.relativePath(of: url, inside: folder) != nil
        }
    }

    /// Puts `document` in the editor, where it was last time, and brings everything that
    /// follows the editor — outline, live preview, live issues, gutter — up to date. The
    /// window becomes the document's window.
    func show(_ document: TeXDocument, line: Int? = nil, recordsHistory: Bool = true) {
        guard document !== currentDocument else {
            if let line {
                editor.revealLine(line)
            }
            return
        }
        add(document)
        if let current = currentDocument {
            captureEditorState(into: current)
        }
        windowController?.associate(document)
        currentDocument = document
        fileURL = document.fileURL
        text = document.text
        encoding = document.encoding
        hasScannedFolds = document.hasAppliedOpeningFolds
        liveIssues = []
        editor.show(text: document.text, selection: document.selection, scrollOrigin: line == nil ? document.scrollOrigin : nil, folds: document.folds)
        if let line {
            editor.revealLine(line)
        }
        if recordsHistory {
            recordInHistory(document)
        }
        analyze()
        // The project's labels and outline now come from the file just left, too.
        refreshProject()
        updateIssueMarkers()
        selectionDidChange()
    }

    /// Adds a document to the window without showing it.
    func add(_ document: TeXDocument) {
        if !documents.contains(where: { $0 === document }) {
            documents.append(document)
        }
    }

    private func captureEditorState(into document: TeXDocument) {
        let state = editor.currentState()
        document.selection = state.selection
        document.scrollOrigin = state.scrollOrigin
        document.folds = state.folds
        document.hasAppliedOpeningFolds = hasScannedFolds
        document.text = text
    }

    /// Shows the project's main file, from a chapter.
    func showMainFile() {
        guard let main = project?.mainFile, showFile(main) else {
            NSSound.beep()
            return
        }
    }

    /// Opens a project file in a window of its own, out of this one.
    func openInNewWindow(_ url: URL) {
        if let document = documents.first(where: { $0.matches(url) }) {
            guard documents.count > 1 else { return }
            if document === currentDocument, let other = documentToShow(insteadOf: document) {
                show(other)
            }
            forget(document)
            document.projectWindow = nil
            ProjectWindowController.openSeparately(document)
            return
        }
        Task { [weak self] in
            do {
                let document = try await TeXDocumentController.openForProject(url)
                if let owner = document.projectWindow {
                    owner.display(document)
                    owner.showWindow(nil)
                } else {
                    ProjectWindowController.openSeparately(document)
                }
            } catch {
                self?.presentError(error)
            }
        }
    }

    // MARK: - History

    var canGoBack: Bool {
        fileHistoryIndex > 0
    }

    var canGoForward: Bool {
        fileHistoryIndex >= 0 && fileHistoryIndex < fileHistory.count - 1
    }

    func recordInHistory(_ document: TeXDocument) {
        let id = ObjectIdentifier(document)
        if fileHistoryIndex >= 0, fileHistoryIndex < fileHistory.count, fileHistory[fileHistoryIndex] == id {
            return
        }
        if fileHistoryIndex < fileHistory.count - 1 {
            fileHistory.removeSubrange((fileHistoryIndex + 1)...)
        }
        fileHistory.removeAll { $0 == id }
        fileHistory.append(id)
        if fileHistory.count > 50 {
            fileHistory.removeFirst(fileHistory.count - 50)
        }
        fileHistoryIndex = fileHistory.count - 1
    }

    /// Go Back: the file shown before this one.
    func goBack() {
        moveInHistory(by: -1)
    }

    /// Go Forward: the file shown after this one, after going back.
    func goForward() {
        moveInHistory(by: 1)
    }

    private func moveInHistory(by step: Int) {
        var index = fileHistoryIndex + step
        while fileHistory.indices.contains(index) {
            if let document = documents.first(where: { ObjectIdentifier($0) == fileHistory[index] }) {
                fileHistoryIndex = index
                show(document, recordsHistory: false)
                return
            }
            fileHistory.remove(at: index)
            if step < 0 {
                index -= 1
                fileHistoryIndex -= 1
            }
        }
        NSSound.beep()
    }

    /// The document to show when `document` goes: the one shown before it, or else the
    /// project's main file or the first one opened.
    func documentToShow(insteadOf document: TeXDocument) -> TeXDocument? {
        let others = documents.filter { $0 !== document }
        for id in fileHistory.reversed() where id != ObjectIdentifier(document) {
            if let previous = others.first(where: { ObjectIdentifier($0) == id }) {
                return previous
            }
        }
        if let main = project?.mainFile, let mainDocument = others.first(where: { $0.matches(main) }) {
            return mainDocument
        }
        return others.first
    }

    // MARK: - Closing

    /// Closes a document of this window; it saves itself first. The last one closes the
    /// window.
    func closeDocument(_ document: TeXDocument) {
        windowController?.close(document)
    }

    /// Forgets a document that has closed or moved to another window.
    func forget(_ document: TeXDocument) {
        documents.removeAll { $0 === document }
        let id = ObjectIdentifier(document)
        if let index = fileHistory.firstIndex(of: id) {
            fileHistory.remove(at: index)
            if index <= fileHistoryIndex {
                fileHistoryIndex -= 1
            }
        }
        fileHistoryIndex = min(max(fileHistoryIndex, fileHistory.isEmpty ? -1 : 0), fileHistory.count - 1)
        if currentDocument === document {
            currentDocument = nil
        }
    }

    // MARK: - Changes from elsewhere

    /// A document was read again from its file: Revert To, or a change another app made,
    /// such as a `git pull`.
    func documentDidRevert(_ document: TeXDocument) {
        guard document === currentDocument else { return }
        editor.applyExternalText(document.text)
        text = document.text
        encoding = document.encoding
        analyze()
        refreshProject()
    }

    /// A document was renamed, moved, or saved for the first time.
    func documentDidMove(_ document: TeXDocument) {
        if document === currentDocument {
            fileURL = document.fileURL
            if fileURL != nil, sidebarTab == .outline, project == nil {
                // A newly saved document has a project now.
                sidebarTab = .project
            }
        }
        refreshProject()
    }

    /// Picks up changes other apps made to documents without unsaved changes, such as a
    /// `git pull`, when TexLab becomes active again. Files that are gone close.
    func reloadDocumentsChangedOnDisk() {
        for document in documents where !document.isDocumentEdited {
            guard let url = document.fileURL else { continue }
            guard FileManager.default.fileExists(atPath: url.filePath) else {
                if documents.count > 1 {
                    closeDocument(document)
                }
                continue
            }
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let date, let known = document.fileModificationDate, date > known else { continue }
            try? document.revert(toContentsOf: url, ofType: document.fileType ?? UTType.plainText.identifier)
        }
    }

    func observeFileEvents() {
        guard fileObservers.isEmpty else { return }
        fileObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadDocumentsChangedOnDisk()
            }
        })
    }

    func stopObservingFileEvents() {
        for observer in fileObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        fileObservers = []
    }

    // MARK: - Editing files that aren't shown

    /// The text of a file as this window has it, unsaved changes included, or nil if it
    /// isn't open here.
    func textOfOpenFile(_ url: URL) -> String? {
        guard let document = documents.first(where: { $0.matches(url) }) else { return nil }
        return document === currentDocument ? text : document.text
    }

    /// A file's text: as open in this window, or as saved.
    func textOfFile(_ url: URL) -> String? {
        textOfOpenFile(url) ?? ProjectIndex.contents(of: url)
    }

    /// The text of every document open here, by canonical path, for the project index.
    var openFileTexts: [String: String] {
        var texts: [String: String] = [:]
        for document in documents {
            guard let path = document.path else { continue }
            texts[path] = document === currentDocument ? text : document.text
        }
        return texts
    }

    /// Changes a document open in this window — in the editor as an undoable edit if it's
    /// shown. Returns false if the file isn't open here.
    @discardableResult
    func modifyOpenFile(at url: URL, actionName: String, _ change: (String) -> (range: NSRange, text: String)?) -> Bool {
        guard let document = documents.first(where: { $0.matches(url) }) else { return false }
        if document === currentDocument {
            if let edit = change(text) {
                editor.replace(edit.range, with: edit.text, actionName: actionName)
            }
            return true
        }
        guard let edit = change(document.text) else { return true }
        document.text = (document.text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        // Its undo history describes the text before this change.
        document.textChangedElsewhere()
        document.updateChangeCount(.changeDone)
        return true
    }

    /// Changes a file wherever it is: open in this window or another, or only on disk.
    func modifyFile(at url: URL, actionName: String, _ change: (String) -> (range: NSRange, text: String)?) {
        if modifyOpenFile(at: url, actionName: actionName, change) {
            return
        }
        if let document = NSDocumentController.shared.document(for: url) as? TeXDocument,
           let owner = document.projectWindow, owner !== windowController {
            owner.session.modifyOpenFile(at: url, actionName: actionName, change)
            return
        }
        guard let data = try? Data(contentsOf: url), let decoded = try? TextDecoding.decode(data),
              let edit = change(decoded.text) else { return }
        let updated = (decoded.text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        try? (updated.data(using: decoded.encoding) ?? Data(updated.utf8)).write(to: url, options: .atomic)
    }

    func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window = editor.textView?.window ?? windowController?.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
