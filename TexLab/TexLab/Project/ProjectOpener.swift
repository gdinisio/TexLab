//
//  ProjectOpener.swift
//  TexLab
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Opens projects — folders — as well as single documents: File ▸ Open Project and the
/// Welcome window.
enum ProjectOpener {
    /// Asks for a project folder or a document, and opens it.
    static func chooseAndOpen() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Open Project")
        panel.message = String(localized: "Choose a project folder, or a LaTeX document.")
        panel.prompt = String(localized: "Open")
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.folder, .latexSource, .bibTeXDatabase, .latexPackage, .latexClass, .plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                open(url)
            }
        }
    }

    /// Opens a folder as a project, or a file as a document.
    static func open(_ url: URL) {
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: url.filePath, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            openProject(at: url)
        } else {
            openDocument(url)
        }
    }

    /// Opens a recent project, at the main file it had if that still exists.
    static func open(_ recent: RecentProject) {
        if recent.isFolderProject {
            openProject(at: recent.folder, preferredMainFile: recent.mainFile)
        } else if let mainFile = recent.mainFile {
            openDocument(mainFile)
        }
    }

    /// Opens a project folder at its main file. If the folder has several complete
    /// documents, asks which one is the main file; if it has none, offers to create one.
    static func openProject(at folder: URL, preferredMainFile: URL? = nil) {
        if let preferredMainFile, FileManager.default.fileExists(atPath: preferredMainFile.filePath) {
            RecentProjects.shared.record(folder: folder, mainFile: preferredMainFile, isFolderProject: true)
            openDocument(preferredMainFile)
            return
        }
        switch mainFileChoice(in: folder) {
        case .found(let main):
            RecentProjects.shared.record(folder: folder, mainFile: main, isFolderProject: true)
            openDocument(main)
        case .several(let documents):
            guard let main = askForMainFile(among: documents, in: folder) else { return }
            RecentProjects.shared.record(folder: folder, mainFile: main, isFolderProject: true)
            openDocument(main)
        case .noDocuments:
            offerToCreateMainFile(in: folder)
        }
    }

    private static func offerToCreateMainFile(in folder: URL) {
        let alert = NSAlert()
        alert.messageText = String(localized: "“\(folder.lastPathComponent)” has no LaTeX document")
        alert.informativeText = String(localized: "Create main.tex from the Article template to start a project in this folder?")
        alert.addButton(withTitle: String(localized: "Create main.tex"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let main = folder.appending(path: "main.tex")
        do {
            try Data(DocumentTemplate.article.text.utf8).write(to: main, options: .withoutOverwriting)
            RecentProjects.shared.record(folder: folder, mainFile: main, isFolderProject: true)
            openDocument(main)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Asks which of a folder's complete documents is its main file, listing each with its
    /// title. The most recently changed one is chosen to begin with.
    private static func askForMainFile(among documents: [URL], in folder: URL) -> URL? {
        let alert = NSAlert()
        alert.messageText = String(localized: "Which document is the main file of “\(folder.lastPathComponent)”?")
        alert.informativeText = String(localized: "The folder has several complete LaTeX documents. TexLab typesets the project through its main file, and remembers your choice.")
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 340, height: 26), pullsDown: false)
        for document in documents {
            var title = document.lastPathComponent
            if let documentTitle = ProjectIndex.contents(of: document).flatMap(ProjectIndex.title(in:)) {
                title += " — " + (documentTitle.count > 50 ? String(documentTitle.prefix(49)) + "…" : documentTitle)
            }
            popUp.menu?.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        }
        popUp.selectItem(at: 0)
        alert.accessoryView = popUp
        alert.addButton(withTitle: String(localized: "Open"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn, documents.indices.contains(popUp.indexOfSelectedItem) else { return nil }
        return documents[popUp.indexOfSelectedItem]
    }

    static func openDocument(_ url: URL) {
        Task {
            do {
                _ = try await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// What a folder's main file is.
    enum MainFileChoice {
        /// main.tex, the only complete document, or the only LaTeX file.
        case found(URL)
        /// Several complete documents, most recently changed first.
        case several([URL])
        /// No LaTeX files at all.
        case noDocuments
    }

    /// A folder's main file: main.tex, or its only complete document. Several complete
    /// documents are for the user to choose between; without any, the first LaTeX file
    /// (a part of a project whose main file is elsewhere) will do.
    static func mainFileChoice(in folder: URL) -> MainFileChoice {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let latex = files
            .filter { ProjectFileKind(url: $0, isDirectory: false) == .latex }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        if let main = latex.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == "main" }) {
            return .found(main)
        }
        let documents = latex.filter { ProjectIndex.contents(of: $0).map(ProjectIndex.isMainDocument) ?? false }
        if documents.count == 1 {
            return .found(documents[0])
        }
        if documents.count > 1 {
            func modified(_ url: URL) -> Date {
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            }
            return .several(documents.sorted { modified($0) > modified($1) })
        }
        guard let first = latex.first else { return .noDocuments }
        return .found(first)
    }
}
