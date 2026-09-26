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

    /// Opens a project folder at its main file, offering to create one if it has none.
    static func openProject(at folder: URL, preferredMainFile: URL? = nil) {
        if let preferredMainFile, FileManager.default.fileExists(atPath: preferredMainFile.filePath) {
            RecentProjects.shared.record(folder: folder, mainFile: preferredMainFile, isFolderProject: true)
            openDocument(preferredMainFile)
            return
        }
        if let main = mainFile(in: folder) {
            RecentProjects.shared.record(folder: folder, mainFile: main, isFolderProject: true)
            openDocument(main)
            return
        }
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

    static func openDocument(_ url: URL) {
        Task {
            do {
                _ = try await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// A folder's main file: main.tex, the only complete document, the most recently
    /// changed complete document, or any LaTeX file.
    static func mainFile(in folder: URL) -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let latex = files.filter { ProjectFileKind(url: $0, isDirectory: false) == .latex }
        if let main = latex.first(where: { $0.deletingPathExtension().lastPathComponent.lowercased() == "main" }) {
            return main
        }
        let documents = latex.filter { ProjectIndex.contents(of: $0).map(ProjectIndex.isMainDocument) ?? false }
        if documents.count == 1 {
            return documents[0]
        }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return documents.max { modified($0) < modified($1) } ?? latex.first
    }
}
