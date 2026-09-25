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
                self?.refreshProject()
            }
        })
        projectObservers.append(center.addObserver(forName: ProjectEvents.addReferenceNotification, object: nil, queue: .main) { [weak self] notification in
            let main = notification.userInfo?[ProjectEvents.mainPathKey] as? String
            let file = notification.userInfo?[ProjectEvents.fileKey] as? URL
            let kind = (notification.userInfo?[ProjectEvents.kindKey] as? String).flatMap(NewFileKind.init(rawValue:))
            MainActor.assumeIsolated {
                self?.handleAddReference(mainPath: main, file: file, kind: kind)
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
        projectRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let snapshot = await Task.detached(priority: .utility) {
                ProjectIndex.snapshot(for: fileURL, text: text)
            }.value
            guard !Task.isCancelled, let self else { return }
            if snapshot != self.project {
                self.project = snapshot
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

    /// Opens a project file: text files in a TexLab tab beside this window, others in the
    /// app that normally opens them.
    func openProjectFile(_ url: URL, inNewWindow: Bool = false) {
        guard ProjectFileKind(url: url, isDirectory: false).opensInTexLab else {
            NSWorkspace.shared.open(url)
            return
        }
        let window = editor.textView?.window
        Task {
            guard let opened = try? await NSDocumentController.shared.openDocument(withContentsOf: url, display: true) else {
                NSSound.beep()
                return
            }
            let (document, wasOpen) = opened
            guard !wasOpen, !inNewWindow, let window else { return }
            // SwiftUI creates the new window shortly after the document opens.
            for _ in 0..<40 {
                if let newWindow = document.windowControllers.first?.window
                    ?? NSApp.windows.first(where: { $0.representedURL?.standardizedFileURL == url.standardizedFileURL }),
                   newWindow !== window {
                    if newWindow.tabGroup !== window.tabGroup {
                        window.addTabbedWindow(newWindow, ordered: .above)
                    }
                    newWindow.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
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
        refreshProject()
    }

    func moveToTrash(_ urls: [URL]) {
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

    /// Makes the main file use a new file, in whichever window has it open, or on disk.
    private func addReferenceInMainFile(to file: URL, kind: NewFileKind) {
        guard let main = project?.mainFile ?? fileURL else { return }
        if let fileURL, SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(main) {
            applyReference(to: file, kind: kind)
        } else if NSDocumentController.shared.document(for: main) != nil {
            NotificationCenter.default.post(name: ProjectEvents.addReferenceNotification, object: nil, userInfo: [
                ProjectEvents.mainPathKey: SourceMap.canonicalPath(main),
                ProjectEvents.fileKey: file,
                ProjectEvents.kindKey: kind.rawValue,
            ])
        } else if let data = try? Data(contentsOf: main), let decoded = try? TextDecoding.decode(data),
                  let insertion = ProjectReferences.insertion(for: file, kind: kind, in: decoded.text, mainFolder: main.deletingLastPathComponent()) {
            let updated = (decoded.text as NSString).replacingCharacters(in: insertion.range, with: insertion.text)
            try? (updated.data(using: decoded.encoding) ?? Data(updated.utf8)).write(to: main, options: .atomic)
        }
    }

    private func handleAddReference(mainPath: String?, file: URL?, kind: NewFileKind?) {
        guard let mainPath, let file, let kind, let fileURL, SourceMap.canonicalPath(fileURL) == mainPath else { return }
        applyReference(to: file, kind: kind)
    }

    /// Adds the reference to this window's document, as an undoable edit.
    private func applyReference(to file: URL, kind: NewFileKind) {
        guard let folder = documentDirectory,
              let insertion = ProjectReferences.insertion(for: file, kind: kind, in: text, mainFolder: folder) else { return }
        editor.replace(insertion.range, with: insertion.text, actionName: String(localized: "Add Reference"))
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

/// Messages between the windows of a project.
nonisolated enum ProjectEvents {
    /// Asks the window showing a main file to reference a new file.
    static let addReferenceNotification = Notification.Name("TexLabAddProjectReference")
    static let mainPathKey = "main"
    static let fileKey = "file"
    static let kindKey = "kind"
}
