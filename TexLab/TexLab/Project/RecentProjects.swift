//
//  RecentProjects.swift
//  TexLab
//

import AppKit
import Foundation
import Observation

/// A project or document opened recently, for the Welcome window.
nonisolated struct RecentProject: Codable, Identifiable, Hashable, Sendable {
    /// The project folder.
    var folderPath: String
    /// The main file, if known.
    var mainFilePath: String?
    /// Whether this is a folder of several files rather than a single document.
    var isFolderProject: Bool
    var lastOpened: Date

    var id: String { folderPath + "|" + (mainFilePath ?? "") }

    var folder: URL { URL(filePath: folderPath, directoryHint: .isDirectory) }
    var mainFile: URL? { mainFilePath.map { URL(filePath: $0) } }

    /// The folder's name for a project, the document's for a single file.
    var name: String {
        if !isFolderProject, let mainFile {
            return mainFile.deletingPathExtension().lastPathComponent
        }
        return folder.lastPathComponent
    }

    /// Where it is, with the home folder as ~.
    var location: String {
        ((isFolderProject ? folderPath : (mainFilePath ?? folderPath)) as NSString).abbreviatingWithTildeInPath
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: isFolderProject ? folderPath : (mainFilePath ?? folderPath))
    }
}

/// The recently opened projects, newest first, kept in the user's defaults.
@Observable
final class RecentProjects {
    static let shared = RecentProjects()

    private(set) var items: [RecentProject] = []

    private static let key = "recentProjects"
    private static let limit = 20

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) {
            items = decoded
        }
    }

    /// Remembers a project, moving it to the top.
    func record(folder: URL, mainFile: URL?, isFolderProject: Bool) {
        let folderPath = folder.standardizedFileURL.path(percentEncoded: false)
        let mainPath = mainFile?.standardizedFileURL.path(percentEncoded: false)
        let recent = RecentProject(folderPath: folderPath, mainFilePath: mainPath, isFolderProject: isFolderProject, lastOpened: Date())
        var updated = items.filter { item in
            // A folder project appears once, whichever file of it was opened.
            isFolderProject ? item.folderPath != folderPath : item.id != recent.id
        }
        updated.insert(recent, at: 0)
        items = Array(updated.prefix(Self.limit))
        save()
    }

    func record(_ snapshot: ProjectSnapshot) {
        let related = snapshot.tree.files.filter { $0.kind == .latex || $0.kind == .bibliography }.count
        record(folder: snapshot.folder, mainFile: snapshot.mainFile, isFolderProject: related > 1)
    }

    func remove(_ project: RecentProject) {
        items.removeAll { $0.id == project.id }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
