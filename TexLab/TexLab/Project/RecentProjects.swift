//
//  RecentProjects.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import Observation
import PDFKit

/// A project or document opened recently, for the Welcome window.
nonisolated struct RecentProject: Codable, Identifiable, Hashable, Sendable {
    /// The project folder.
    var folderPath: String
    /// The main file, if known.
    var mainFilePath: String?
    /// Whether this is a folder of several files rather than a single document.
    var isFolderProject: Bool
    var lastOpened: Date
    /// The main file's `\title`. Optional, like `pinned`, so lists saved by earlier
    /// versions still load.
    var title: String?
    /// Kept at the top of the Welcome window.
    var pinned: Bool?

    var id: String { folderPath + "|" + (mainFilePath ?? "") }

    var isPinned: Bool { pinned == true }

    var folder: URL { URL(filePath: folderPath, directoryHint: .isDirectory) }
    var mainFile: URL? { mainFilePath.map { URL(filePath: $0) } }

    /// The folder's name for a project, the document's for a single file.
    var name: String {
        if !isFolderProject, let mainFile {
            return mainFile.deletingPathExtension().lastPathComponent
        }
        return folder.lastPathComponent
    }

    /// The file or folder the project is, on disk.
    var url: URL {
        isFolderProject ? folder : (mainFile ?? folder)
    }

    /// Where it is, with the home folder as ~.
    var location: String {
        (url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// The PDF TexLab last typeset from the main file, in its build folder, for the
    /// Welcome window's thumbnail.
    var typesetPDF: URL? {
        guard let mainFile else { return nil }
        let build = BuildNaming.buildRoot.appending(path: BuildNaming.buildKey(for: SourceMap.canonicalPath(mainFile)), directoryHint: .isDirectory)
        return build.appending(path: BuildNaming.jobName(for: mainFile.deletingPathExtension().lastPathComponent) + ".pdf")
    }

    /// Whether `query` matches its name, title or location.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [name, title ?? "", location].contains { $0.localizedStandardContains(query) }
    }
}

/// The recently opened projects, newest first, kept in the user's defaults.
@Observable
final class RecentProjects {
    static let shared = RecentProjects()

    private(set) var items: [RecentProject] = []

    private static let key = "recentProjects"
    /// How many unpinned projects are kept.
    private static let limit = 24

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) {
            items = decoded
        }
    }

    var pinned: [RecentProject] {
        items.filter(\.isPinned)
    }

    var unpinned: [RecentProject] {
        items.filter { !$0.isPinned }
    }

    /// Remembers a project, moving it to the top and keeping whether it was pinned.
    func record(folder: URL, mainFile: URL?, isFolderProject: Bool, title: String? = nil) {
        let folderPath = folder.standardizedFileURL.path(percentEncoded: false)
        let mainPath = mainFile?.standardizedFileURL.path(percentEncoded: false)
        var recent = RecentProject(folderPath: folderPath, mainFilePath: mainPath, isFolderProject: isFolderProject, lastOpened: Date(), title: title)
        // A folder project appears once, whichever file of it was opened.
        func isSame(_ item: RecentProject) -> Bool {
            isFolderProject || item.isFolderProject ? item.folderPath == folderPath : item.id == recent.id
        }
        if let previous = items.first(where: isSame) {
            recent.pinned = previous.pinned
            recent.title = title ?? previous.title
            // A folder stays a project once it has been one, even if opened at a single file.
            recent.isFolderProject = isFolderProject || previous.isFolderProject
        }
        var updated = items.filter { !isSame($0) }
        updated.insert(recent, at: 0)
        items = trimmed(updated)
        save()
    }

    func record(_ snapshot: ProjectSnapshot) {
        let related = snapshot.tree.files.filter { $0.kind == .latex || $0.kind == .bibliography }.count
        record(folder: snapshot.folder, mainFile: snapshot.mainFile, isFolderProject: related > 1, title: snapshot.title)
    }

    func setPinned(_ isPinned: Bool, for project: RecentProject) {
        update(project) { $0.pinned = isPinned ? true : nil }
    }

    /// Points a project that was moved or renamed at its new place.
    func relocate(_ project: RecentProject, to url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) else { return }
        update(project) { item in
            if isDirectory.boolValue {
                let oldFolder = item.folderPath
                item.folderPath = url.standardizedFileURL.path(percentEncoded: false)
                item.isFolderProject = true
                // Keep the main file at the same place within the folder.
                if let main = item.mainFilePath, main.hasPrefix(oldFolder) {
                    let relative = String(main.dropFirst(oldFolder.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let moved = url.appending(path: relative).standardizedFileURL.path(percentEncoded: false)
                    item.mainFilePath = FileManager.default.fileExists(atPath: moved) ? moved : nil
                }
            } else {
                item.folderPath = url.deletingLastPathComponent().standardizedFileURL.path(percentEncoded: false)
                item.mainFilePath = url.standardizedFileURL.path(percentEncoded: false)
            }
        }
    }

    func remove(_ project: RecentProject) {
        items.removeAll { $0.id == project.id }
        save()
    }

    /// Forgets projects that can no longer be found.
    func removeMissing() {
        items.removeAll { !$0.exists }
        save()
    }

    /// Forgets every project that isn't pinned.
    func clear() {
        items.removeAll { !$0.isPinned }
        save()
    }

    private func update(_ project: RecentProject, _ change: (inout RecentProject) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == project.id }) else { return }
        change(&items[index])
        // Two entries may now describe the same project; keep the first.
        var seen: Set<String> = []
        items = items.filter { seen.insert($0.id).inserted }
        save()
    }

    /// Pinned projects are always kept; the rest are limited to the newest.
    private func trimmed(_ list: [RecentProject]) -> [RecentProject] {
        var unpinnedCount = 0
        return list.filter { item in
            guard !item.isPinned else { return true }
            unpinnedCount += 1
            return unpinnedCount <= Self.limit
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// First-page thumbnails of the PDFs TexLab typeset, for the Welcome window. Rendered in
/// the background, and redrawn only when the PDF changes.
final class ProjectThumbnails {
    static let shared = ProjectThumbnails()

    private var cache: [String: NSImage] = [:]

    func thumbnail(for project: RecentProject) async -> NSImage? {
        guard let pdf = project.typesetPDF else { return nil }
        let path = pdf.path(percentEncoded: false)
        guard let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date else { return nil }
        let key = "\(path)|\(modified.timeIntervalSinceReferenceDate)"
        if let cached = cache[key] {
            return cached
        }
        let rendered = await Task.detached(priority: .utility) { () -> CGImage? in
            guard let document = PDFDocument(url: pdf), let page = document.page(at: 0) else { return nil }
            return page.thumbnail(of: CGSize(width: 96, height: 128), for: .cropBox)
                .cgImage(forProposedRect: nil, context: nil, hints: nil)
        }.value
        guard let rendered else { return nil }
        let image = NSImage(cgImage: rendered, size: .zero)
        cache[key] = image
        return image
    }
}
