//
//  DocumentSession+Project.swift
//  TexLab
//

import AppKit
import Foundation

/// Projects, the way LaTeX has them: a folder of files typeset through one main file.
/// The navigator lists the folder, new files are created and referenced from the main file,
/// and a chapter without `\documentclass` is typeset through the file that includes it.
extension DocumentSession {
    /// The folder TeX resolves relative paths against: the main file's folder.
    var projectFolder: URL? {
        project?.folder ?? documentDirectory
    }

    /// Whether this window's document is the one that is typeset.
    var isMainFile: Bool {
        guard let fileURL, let main = project?.mainFile else { return true }
        return SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(main)
    }

    // MARK: - Keeping the project current

    func startProject() {
        guard projectObservers.isEmpty else { return }
        let center = NotificationCenter.default
        projectObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                // Figures may have been changed in another app.
                self?.editor.forgetThumbnails()
                self?.refreshProject()
            }
        })
        refreshProject()
    }

    func stopProject() {
        projectRefreshTask?.cancel()
        projectWatchers.forEach { $0.cancel() }
        projectWatchers = []
        for observer in projectObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        projectObservers = []
    }

    /// Rescans the project in the background, soon after the last request.
    func refreshProject() {
        projectRefreshTask?.cancel()
        guard let fileURL else {
            project = nil
            return
        }
        let text = text
        // Files open in this window are read as they are here, unsaved changes included.
        let openTexts = openFileTexts
        // Another file of the window belongs to the project the window already has.
        let knownMainFile = isShowingOtherFile ? project?.mainFile : nil
        projectRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let snapshot = await Task.detached(priority: .utility) {
                ProjectIndex.snapshot(for: fileURL, text: text, openTexts: openTexts, knownMainFile: knownMainFile)
            }.value
            guard !Task.isCancelled, let self else { return }
            if snapshot != self.project {
                if snapshot.tree != self.project?.tree {
                    // A figure that was missing may be there now.
                    self.editor.forgetThumbnails()
                }
                self.project = snapshot
                // Labels and bibliography entries elsewhere in the project may have changed.
                self.checkLiveIssues()
            }
            // Remember the project for the Welcome window, once per project.
            let recentID = "\(snapshot.folder.path(percentEncoded: false))|\(snapshot.mainFile?.path(percentEncoded: false) ?? "")"
            if recentID != self.recordedProjectID {
                self.recordedProjectID = recentID
                RecentProjects.shared.record(snapshot)
            }
            self.watch(snapshot.tree)
        }
    }

    /// Watches the project folder and its subfolders for files being added or removed.
    private func watch(_ tree: ProjectFile) {
        let folders = tree.folders.map(\.url)
        guard folders != watchedFolders else { return }
        projectWatchers.forEach { $0.cancel() }
        watchedFolders = folders
        projectWatchers = folders.prefix(64).compactMap { folder in
            DirectoryWatcher(url: folder) { [weak self] in
                MainActor.assumeIsolated {
                    self?.refreshProject()
                }
            }
        }
    }

    // MARK: - Opening files

    /// Opens a project file: text files in this window's editor, beside its document (or
    /// in a window of their own if asked), others in the app that normally opens them.
    func openProjectFile(_ url: URL, inNewWindow: Bool = false) {
        guard ProjectFileKind(url: url, isDirectory: false).opensInTexLab else {
            NSWorkspace.shared.open(url)
            return
        }
        if !inNewWindow, showFile(url) {
            return
        }
        // A file is edited in one place only, so this window lets it go first.
        if let file = openFiles.first(where: { $0.matches(url) }), !file.isWindowDocument {
            closeFile(file)
        }
        Task {
            if (try? await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)) == nil {
                NSSound.beep()
            }
        }
    }

    func showInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    // MARK: - Changing the project

    /// Creates a file in the project, adds a reference to it in the main file if asked, and
    /// opens it.
    @discardableResult
    func createProjectFile(kind: NewFileKind, name: String, in folder: URL, addsReference: Bool) throws -> URL {
        let url = folder.appending(path: name).appendingPathExtension(kind.fileExtension)
        guard !FileManager.default.fileExists(atPath: url.filePath) else {
            throw ProjectError.fileExists(url.lastPathComponent)
        }
        let rootPath = project?.mainFile.map { PathUtilities.relativePath(of: $0, from: folder) }
        try Data(kind.contents(name: name, rootPath: kind == .chapter ? rootPath : nil).utf8).write(to: url, options: .withoutOverwriting)
        if addsReference, kind.canBeReferenced {
            addReferenceInMainFile(to: url, kind: kind)
        }
        refreshProject()
        openProjectFile(url)
        return url
    }

    func createFolder(named name: String, in folder: URL) throws {
        let url = folder.appending(path: name, directoryHint: .isDirectory)
        guard !FileManager.default.fileExists(atPath: url.filePath) else {
            throw ProjectError.fileExists(name)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        refreshProject()
    }

    /// Renames a file or folder. Open documents follow the file; references to it in other
    /// files aren't changed.
    func renameProjectFile(_ url: URL, to name: String) throws {
        let destination = url.deletingLastPathComponent().appending(path: name)
        guard !FileManager.default.fileExists(atPath: destination.filePath) else {
            throw ProjectError.fileExists(name)
        }
        try FileManager.default.moveItem(at: url, to: destination)
        openFilesDidMove(from: url, to: destination)
        refreshProject()
    }

    func moveToTrash(_ urls: [URL]) {
        // Open copies close without being saved back, which would bring the files back.
        openFilesWereRemoved(urls)
        NSWorkspace.shared.recycle(urls) { [weak self] _, _ in
            // Not necessarily called on the main thread.
            Task { @MainActor in
                self?.refreshProject()
            }
        }
    }

    // MARK: - References

    /// Inserts the command that uses `url` at the insertion point: `\input`, `\bibliography`,
    /// `\usepackage` or `\includegraphics`, with a path relative to the main file.
    func insertReference(to url: URL) {
        guard let folder = projectFolder, let reference = ProjectReferences.reference(to: url, from: folder) else {
            NSSound.beep()
            return
        }
        editor.insertText(reference, actionName: String(localized: "Insert Reference"))
    }

    /// Makes the main file use a new file: in the editor if it's shown, in whichever window
    /// has it open, or on disk.
    private func addReferenceInMainFile(to file: URL, kind: NewFileKind) {
        guard let main = project?.mainFile ?? fileURL else { return }
        let folder = main.deletingLastPathComponent()
        modifyFile(at: main, actionName: String(localized: "Add Reference")) { text in
            ProjectReferences.insertion(for: file, kind: kind, in: text, mainFolder: folder)
        }
    }

    /// Makes `url` the main file of this document with a `% !TEX root` comment.
    func useAsMainFile(_ url: URL) {
        guard let directory = documentDirectory else { return }
        let line = MagicComments.rootLine(for: PathUtilities.relativePath(of: url, from: directory))
        let magic = MagicComments(text: text)
        let actionName = String(localized: "Set Main File")
        if let range = magic.rootLineRange {
            editor.replace(range, with: line, actionName: actionName)
        } else {
            editor.replace(NSRange(location: 0, length: 0), with: line, actionName: actionName)
        }
        refreshProject()
    }
}

/// Errors from changing project files, worded for alerts.
nonisolated enum ProjectError: LocalizedError {
    case fileExists(String)

    var errorDescription: String? {
        switch self {
        case .fileExists(let name): String(localized: "“\(name)” already exists in this folder.")
        }
    }

    var recoverySuggestion: String? {
        String(localized: "Choose a different name.")
    }
}
