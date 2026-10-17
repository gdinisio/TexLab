//
//  DocumentSession+Files.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// The files of a window, like Xcode's: the project navigator, search results, issues,
/// SyncTeX and Jump to Definition show any text file of the project in this window's
/// editor, keeping each file's place, and the preview keeps showing the whole document.
extension DocumentSession {
    /// The window's own document.
    var windowFile: EditorFile? {
        openFiles.first(where: \.isWindowDocument)
    }

    /// Whether the editor shows a file other than the window's document.
    var isShowingOtherFile: Bool {
        currentFile.map { !$0.isWindowDocument } ?? false
    }

    /// The window's subtitle: the shown file when it isn't the window's document, and how
    /// typesetting went.
    var windowSubtitle: String {
        let summary = status.summary
        guard let file = currentFile, !file.isWindowDocument else { return summary }
        return summary.isEmpty ? file.name : "\(file.name) — \(summary)"
    }

    // MARK: - Showing files

    /// Shows a line of a file: here if the editor shows it, as a file of this window if it
    /// belongs to the project, or in a window of its own otherwise.
    func open(_ url: URL, line: Int?) {
        if let fileURL, SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(url) {
            if let line {
                editor.revealLine(line)
            }
            return
        }
        if showFile(url, line: line) {
            return
        }
        SourceNavigator.open(url, line: line)
    }

    /// Shows a text file of the project in the editor, opening it beside the window's
    /// document if it isn't open yet. A file another window has open is shown there.
    /// Returns false for files that belong in a window of their own.
    @discardableResult
    func showFile(_ url: URL, line: Int? = nil) -> Bool {
        if let file = openFiles.first(where: { $0.matches(url) }) {
            show(file, line: line)
            return true
        }
        let path = SourceMap.canonicalPath(url)
        if let owner = EditorFileRegistry.shared.owner(of: path, besides: self) {
            owner.editor.textView?.window?.makeKeyAndOrderFront(nil)
            owner.open(url, line: line)
            return true
        }
        guard canShowInWindow(url) else { return false }
        do {
            let file = try EditorFile.load(url)
            openFiles.append(file)
            EditorFileRegistry.shared.register(file.id, for: self)
            show(file, line: line)
        } catch {
            presentError(error)
        }
        return true
    }

    /// Whether `url` is a text file of this window's project, which the editor can show.
    func canShowInWindow(_ url: URL) -> Bool {
        guard ProjectFileKind(url: url, isDirectory: false).opensInTexLab,
              FileManager.default.fileExists(atPath: url.filePath) else { return false }
        let folders = [project?.folder, windowFile?.url?.deletingLastPathComponent()].compactMap { $0 }
        return folders.contains { folder in
            SourceMap.relativePath(of: url, inside: folder) != nil
        }
    }

    /// Puts `file` in the editor, where it was last time, and brings everything that
    /// follows the editor — outline, live preview, live issues, gutter — up to date.
    func show(_ file: EditorFile, line: Int? = nil, recordsHistory: Bool = true) {
        guard file !== currentFile else {
            if let line {
                editor.revealLine(line)
            }
            return
        }
        if let current = currentFile {
            captureEditorState(into: current)
            if current.hasUnsavedChanges {
                save(current)
            }
        }
        currentFile = file
        fileURL = file.url
        text = file.text
        encoding = file.encoding
        hasScannedFolds = file.hasAppliedOpeningFolds
        liveIssues = []
        editor.show(text: file.text, selection: file.selection, scrollOrigin: line == nil ? file.scrollOrigin : nil, folds: file.folds)
        if let line {
            editor.revealLine(line)
        }
        if recordsHistory {
            recordInHistory(file)
        }
        analyze()
        // The project's labels and outline now come from the file just left, too.
        refreshProject()
        updateIssueMarkers()
        selectionDidChange()
    }

    private func captureEditorState(into file: EditorFile) {
        let state = editor.currentState()
        file.selection = state.selection
        file.scrollOrigin = state.scrollOrigin
        file.folds = state.folds
        file.hasAppliedOpeningFolds = hasScannedFolds
        file.text = text
    }

    /// Shows the project's main file, from a chapter.
    func showMainFile() {
        guard let main = project?.mainFile, showFile(main) else {
            NSSound.beep()
            return
        }
    }

    // MARK: - History

    var canGoBack: Bool {
        fileHistoryIndex > 0
    }

    var canGoForward: Bool {
        fileHistoryIndex >= 0 && fileHistoryIndex < fileHistory.count - 1
    }

    func recordInHistory(_ file: EditorFile) {
        if fileHistoryIndex >= 0, fileHistoryIndex < fileHistory.count, fileHistory[fileHistoryIndex] == file.id {
            return
        }
        if fileHistoryIndex < fileHistory.count - 1 {
            fileHistory.removeSubrange((fileHistoryIndex + 1)...)
        }
        fileHistory.removeAll { $0 == file.id }
        fileHistory.append(file.id)
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
            if let file = openFiles.first(where: { $0.id == fileHistory[index] }) {
                fileHistoryIndex = index
                show(file, recordsHistory: false)
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

    // MARK: - Closing

    /// Closes a file opened beside the window's document, saving it first.
    func closeFile(_ file: EditorFile) {
        guard !file.isWindowDocument else { return }
        if file.hasUnsavedChanges {
            guard save(file) else { return }
        }
        if file === currentFile, let windowFile {
            show(windowFile)
        }
        openFiles.removeAll { $0 === file }
        if let index = fileHistory.firstIndex(of: file.id) {
            fileHistory.remove(at: index)
            if index <= fileHistoryIndex {
                fileHistoryIndex -= 1
            }
        }
        fileHistoryIndex = min(max(fileHistoryIndex, fileHistory.isEmpty ? -1 : 0), fileHistory.count - 1)
        EditorFileRegistry.shared.unregister(file.id, for: self)
    }

    /// Saves and forgets every file when the window closes.
    func closeOpenFiles() {
        autosaveTask?.cancel()
        saveOpenFiles()
        for file in openFiles {
            EditorFileRegistry.shared.unregister(file.id, for: self)
        }
        for observer in fileObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        fileObservers = []
    }

    /// Another window opened this file as its own document; this window lets it go so the
    /// file is edited in one place.
    func relinquishFile(at path: String) {
        guard let file = openFiles.first(where: { $0.id == path }), !file.isWindowDocument else { return }
        closeFile(file)
    }

    /// Registers the window's document, taking it from a window that had it open beside
    /// its own.
    func claimWindowDocument() {
        guard let file = windowFile, file.url != nil else { return }
        EditorFileRegistry.shared.owner(of: file.id, besides: self)?.relinquishFile(at: file.id)
        EditorFileRegistry.shared.register(file.id, for: self)
    }

    // MARK: - Saving

    /// Saves the files opened beside the window's document soon after the last change.
    func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveOpenFiles()
        }
    }

    /// Writes every file opened beside the window's document that has unsaved changes.
    func saveOpenFiles() {
        for file in openFiles where !file.isWindowDocument && file.hasUnsavedChanges {
            save(file)
        }
    }

    @discardableResult
    func save(_ file: EditorFile) -> Bool {
        guard !file.isWindowDocument, file.hasUnsavedChanges else { return true }
        do {
            try file.save()
            file.hasReportedSaveError = false
            return true
        } catch {
            // Say so once, not after every pause in typing.
            if !file.hasReportedSaveError {
                file.hasReportedSaveError = true
                presentError(error)
            }
            return false
        }
    }

    /// Marks the window's document as changed, so it is saved like any Mac document. Its
    /// edits use the file's own undo history, which the document doesn't watch.
    func markWindowDocumentEdited() {
        (editor.textView?.window?.windowController?.document as? NSDocument)?.updateChangeCount(.changeDone)
    }

    // MARK: - Changes from elsewhere

    /// The window's document changed outside the editor: Revert To, or an undo made through
    /// the document.
    func windowDocumentTextDidChange(_ newText: String) {
        guard let file = windowFile, newText != file.text else { return }
        file.text = newText
        if file === currentFile {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentFile === file, file.text == newText else { return }
                self.editor.applyExternalText(newText)
                self.text = newText
                self.analyze()
            }
        } else {
            file.textChangedElsewhere()
        }
    }

    /// The window's document was saved somewhere else, renamed or moved.
    func windowDocumentDidMove(to newURL: URL?) {
        guard let file = windowFile else { return }
        let oldID = file.id
        EditorFileRegistry.shared.unregister(oldID, for: self)
        file.move(to: newURL)
        if file.url != nil {
            EditorFileRegistry.shared.register(file.id, for: self)
        }
        replaceInHistory(oldID, with: file.id)
        if file === currentFile {
            fileURL = newURL
        }
        refreshProject()
    }

    /// Files and folders renamed or moved in the navigator: open files follow them.
    func openFilesDidMove(from oldURL: URL, to newURL: URL) {
        let oldPath = SourceMap.canonicalPath(oldURL)
        let newPath = SourceMap.canonicalPath(newURL)
        for file in openFiles where !file.isWindowDocument {
            guard let url = file.url else { continue }
            let path = url.standardizedFileURL.filePath
            let standardizedOld = oldURL.standardizedFileURL.filePath
            let suffix: String
            if file.id == oldPath || path == standardizedOld {
                suffix = ""
            } else if file.id.hasPrefix(oldPath + "/") {
                suffix = String(file.id.dropFirst(oldPath.count))
            } else {
                continue
            }
            let moved = URL(filePath: newPath + suffix)
            let oldID = file.id
            EditorFileRegistry.shared.unregister(oldID, for: self)
            file.move(to: moved)
            EditorFileRegistry.shared.register(file.id, for: self)
            replaceInHistory(oldID, with: file.id)
            if file === currentFile {
                fileURL = moved
            }
        }
    }

    /// Files moved to the Trash: open copies close without being saved back.
    func openFilesWereRemoved(_ urls: [URL]) {
        let paths = urls.map(SourceMap.canonicalPath)
        for file in openFiles where !file.isWindowDocument {
            guard paths.contains(where: { file.id == $0 || file.id.hasPrefix($0 + "/") }) else { continue }
            file.hasUnsavedChanges = false
            closeFile(file)
        }
    }

    /// Picks up changes other apps made to open files, such as a `git pull`, when TexLab
    /// becomes active again. Files with changes of their own keep them.
    func reloadFilesChangedOnDisk() {
        for file in openFiles where !file.isWindowDocument && !file.hasUnsavedChanges {
            guard let url = file.url else { continue }
            guard FileManager.default.fileExists(atPath: url.filePath) else {
                closeFile(file)
                continue
            }
            let date = EditorFile.modificationDate(of: url)
            guard date != file.modificationDate else { continue }
            file.modificationDate = date
            guard let reloaded = try? EditorFile.load(url), reloaded.text != file.text else { continue }
            file.text = reloaded.text
            file.encoding = reloaded.encoding
            file.textChangedElsewhere()
            if file === currentFile {
                editor.applyExternalText(reloaded.text)
                text = reloaded.text
                analyze()
            }
        }
    }

    private func replaceInHistory(_ oldID: String, with newID: String) {
        fileHistory = fileHistory.map { $0 == oldID ? newID : $0 }
    }

    func observeFileEvents() {
        guard fileObservers.isEmpty else { return }
        let center = NotificationCenter.default
        fileObservers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveOpenFiles()
            }
        })
        fileObservers.append(center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.saveOpenFiles()
            }
        })
        fileObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reloadFilesChangedOnDisk()
            }
        })
    }

    // MARK: - Editing files that aren't shown

    /// The text of a file as this window has it, unsaved changes included, or nil if it
    /// isn't open here.
    func textOfOpenFile(_ url: URL) -> String? {
        guard let file = openFiles.first(where: { $0.matches(url) }) else { return nil }
        return file === currentFile ? text : file.text
    }

    /// A file's text: as open in this window, or as saved.
    func textOfFile(_ url: URL) -> String? {
        textOfOpenFile(url) ?? ProjectIndex.contents(of: url)
    }

    /// The text of every file open here, by canonical path, for the project index.
    var openFileTexts: [String: String] {
        var texts: [String: String] = [:]
        for file in openFiles where file.url != nil {
            texts[file.id] = file === currentFile ? text : file.text
        }
        return texts
    }

    /// Changes a file open in this window — in the editor as an undoable edit if it's
    /// shown. Returns false if the file isn't open here.
    @discardableResult
    func modifyOpenFile(at url: URL, actionName: String, _ change: (String) -> (range: NSRange, text: String)?) -> Bool {
        guard let file = openFiles.first(where: { $0.matches(url) }) else { return false }
        if file === currentFile {
            if let edit = change(text) {
                editor.replace(edit.range, with: edit.text, actionName: actionName)
            }
            return true
        }
        guard let edit = change(file.text) else { return true }
        file.text = (file.text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        file.textChangedElsewhere()
        if file.isWindowDocument {
            writeDocumentText?(file.text)
            markWindowDocumentEdited()
        } else {
            file.hasUnsavedChanges = true
            save(file)
        }
        return true
    }

    /// Changes a file wherever it is: open in this window or another, or only on disk.
    func modifyFile(at url: URL, actionName: String, _ change: (String) -> (range: NSRange, text: String)?) {
        if modifyOpenFile(at: url, actionName: actionName, change) {
            return
        }
        if let owner = EditorFileRegistry.shared.owner(of: SourceMap.canonicalPath(url), besides: self) {
            owner.modifyOpenFile(at: url, actionName: actionName, change)
            return
        }
        guard let data = try? Data(contentsOf: url), let decoded = try? TextDecoding.decode(data),
              let edit = change(decoded.text) else { return }
        let updated = (decoded.text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        try? (updated.data(using: decoded.encoding) ?? Data(updated.utf8)).write(to: url, options: .atomic)
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        if let window = editor.textView?.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
