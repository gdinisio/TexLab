//
//  ProjectModel.swift
//  TexLab
//

import Darwin
import Foundation

/// What a file in a project is, for its icon and what opening it does.
nonisolated enum ProjectFileKind: Sendable, Equatable {
    case folder
    case latex
    case bibliography
    case package
    case image
    case pdf
    case text
    case other

    init(url: URL, isDirectory: Bool) {
        if isDirectory {
            self = .folder
            return
        }
        switch url.pathExtension.lowercased() {
        case "tex", "ltx", "latex": self = .latex
        case "bib": self = .bibliography
        case "sty", "cls", "bst", "bbx", "cbx", "def": self = .package
        case "png", "jpg", "jpeg", "gif", "tif", "tiff", "eps", "svg", "heic": self = .image
        case "pdf": self = .pdf
        case "txt", "md", "csv", "dat", "cfg": self = .text
        default: self = .other
        }
    }

    var systemImage: String {
        switch self {
        case .folder: "folder"
        case .latex: "doc.text"
        case .bibliography: "books.vertical"
        case .package: "gearshape"
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .text: "doc.plaintext"
        case .other: "doc"
        }
    }

    /// Files TexLab edits in its own windows; others open in their default app.
    var opensInTexLab: Bool {
        switch self {
        case .latex, .bibliography, .package, .text: true
        default: false
        }
    }
}

/// A file or folder in the project navigator.
nonisolated struct ProjectFile: Identifiable, Hashable, Sendable {
    var url: URL
    var kind: ProjectFileKind
    /// The contents of a folder, sorted folders first; nil for files.
    var children: [ProjectFile]?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isFolder: Bool { kind == .folder }

    static func == (lhs: ProjectFile, rhs: ProjectFile) -> Bool {
        lhs.url == rhs.url && lhs.kind == rhs.kind && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    /// Every folder in the tree, including this one if it's a folder.
    var folders: [ProjectFile] {
        guard isFolder else { return [] }
        return [self] + (children ?? []).flatMap(\.folders)
    }

    /// Every file in the tree.
    var files: [ProjectFile] {
        isFolder ? (children ?? []).flatMap(\.files) : [self]
    }
}

/// Lists a project folder.
nonisolated enum ProjectScanner {
    /// Build products and editor leftovers that would only clutter the navigator. TexLab
    /// typesets in its own build folder, but other editors write these next to the source.
    static let hiddenExtensions: Set<String> = [
        "aux", "log", "out", "toc", "lof", "lot", "fls", "fdb_latexmk", "synctex", "gz", "bbl", "blg",
        "bcf", "xml", "nav", "snm", "vrb", "idx", "ilg", "ind", "glo", "gls", "glg", "ist", "xdv", "dvi",
        "run", "loa", "thm", "spl",
    ]
    static let hiddenNames: Set<String> = [".DS_Store", ".git", ".svn", "_minted", "__pycache__", ".texpadtmp"]

    private static let maximumDepth = 5
    private static let maximumEntries = 3000

    static func scan(_ folder: URL) -> ProjectFile {
        var budget = maximumEntries
        return ProjectFile(url: folder, kind: .folder, children: contents(of: folder, depth: 0, budget: &budget))
    }

    private static func contents(of folder: URL, depth: Int, budget: inout Int) -> [ProjectFile] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        guard depth < maximumDepth, budget > 0,
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        var files: [ProjectFile] = []
        for url in urls {
            guard budget > 0 else { break }
            let name = url.lastPathComponent
            guard !hiddenNames.contains(name), !hiddenExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            let isDirectory = values?.isDirectory == true && values?.isPackage != true
            budget -= 1
            if isDirectory {
                files.append(ProjectFile(url: url, kind: .folder, children: contents(of: url, depth: depth + 1, budget: &budget)))
            } else {
                files.append(ProjectFile(url: url, kind: ProjectFileKind(url: url, isDirectory: false)))
            }
        }
        return files.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

/// What TexLab knows about a document's project: its folder, its main file, and the labels
/// and citation keys defined in its other files.
nonisolated struct ProjectSnapshot: Sendable, Equatable {
    /// The folder the project lives in: the main file's folder.
    var folder: URL
    var tree: ProjectFile
    /// The file that is typeset: the document itself, or the file that includes it.
    var mainFile: URL?
    /// Whether the main file was found by looking for the file that includes the document,
    /// rather than named with `% !TEX root`.
    var mainFileIsDetected = false
    /// `\label`s defined in the project's other LaTeX files.
    var labels: [LabelDefinition] = []
    /// The entries of the project's bibliographies.
    var bibEntries: [BibEntry] = []

    var labelKeys: [String] {
        labels.map(\.key)
    }

    var citationKeys: [String] {
        bibEntries.map(\.key)
    }
}

/// Finds a document's project and main file.
nonisolated enum ProjectIndex {
    private static let documentClassPattern = try! NSRegularExpression(pattern: #"^[^%\n]*\\documentclass"#, options: [.anchorsMatchLines])
    private static let inclusionPattern = try! NSRegularExpression(
        pattern: #"\\(?:input|include|subfile|includeonly)\s*\{([^{}]+)\}|\\(?:sub)?import\*?\s*\{([^{}]*)\}\s*\{([^{}]+)\}"#
    )
    private static let maximumFileSize = 2_000_000

    /// Whether `text` is a complete document rather than a part of one.
    static func isMainDocument(_ text: String) -> Bool {
        documentClassPattern.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// The document's project, given where it is and what it says.
    static func snapshot(for documentURL: URL, text: String) -> ProjectSnapshot {
        let directory = documentURL.deletingLastPathComponent()
        var mainFile: URL?
        var detected = false
        if let root = MagicComments(text: text).root {
            mainFile = directory.appending(path: root).standardizedFileURL
        } else if isMainDocument(text) {
            mainFile = documentURL.standardizedFileURL
        } else if let including = fileIncluding(documentURL) {
            mainFile = including
            detected = true
        }
        let folder = mainFile?.deletingLastPathComponent() ?? directory
        let tree = ProjectScanner.scan(folder)

        var labels: [LabelDefinition] = []
        var entries: [BibEntry] = []
        let current = SourceMap.canonicalPath(documentURL)
        for file in tree.files {
            switch file.kind {
            case .latex where SourceMap.canonicalPath(file.url) != current:
                if let other = contents(of: file.url) {
                    labels += ReferenceScanner.labels(in: other, file: file.url)
                }
            case .bibliography:
                if let database = contents(of: file.url) {
                    entries += ReferenceScanner.bibEntries(in: database, file: file.url)
                }
            default:
                break
            }
        }
        if mainFile == nil, let candidate = defaultMainFile(in: tree) {
            mainFile = candidate
        }
        return ProjectSnapshot(
            folder: folder,
            tree: tree,
            mainFile: mainFile,
            mainFileIsDetected: detected,
            labels: labels.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending },
            bibEntries: entries.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        )
    }

    /// A complete document in the folder or its parents that includes `url` with `\input`,
    /// `\include`, `\subfile` or `\import`.
    static func fileIncluding(_ url: URL) -> URL? {
        let target = url.standardizedFileURL.deletingPathExtension().path(percentEncoded: false)
        var folder = url.deletingLastPathComponent()
        for _ in 0..<3 {
            let candidates = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for candidate in candidates.prefix(300) where ProjectFileKind(url: candidate, isDirectory: false) == .latex {
                guard SourceMap.canonicalPath(candidate) != SourceMap.canonicalPath(url),
                      let text = contents(of: candidate), isMainDocument(text) else { continue }
                if includedPaths(in: text, relativeTo: folder).contains(target) {
                    return candidate.standardizedFileURL
                }
            }
            let parent = folder.deletingLastPathComponent()
            guard parent.path(percentEncoded: false) != folder.path(percentEncoded: false),
                  folder.path(percentEncoded: false) != FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false) else { break }
            folder = parent
        }
        return nil
    }

    /// The files `text` includes, as absolute paths without extension.
    private static func includedPaths(in text: String, relativeTo folder: URL) -> Set<String> {
        let string = text as NSString
        var paths: Set<String> = []
        for match in inclusionPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            var relative: String
            if match.range(at: 1).location != NSNotFound {
                relative = string.substring(with: match.range(at: 1))
            } else {
                let directory = string.substring(with: match.range(at: 2))
                relative = (directory.isEmpty ? "" : directory.hasSuffix("/") ? directory : directory + "/") + string.substring(with: match.range(at: 3))
            }
            for part in relative.split(separator: ",") {
                var path = part.trimmingCharacters(in: .whitespaces)
                if path.lowercased().hasSuffix(".tex") {
                    path = String(path.dropLast(4))
                }
                guard !path.isEmpty else { continue }
                paths.insert(folder.appending(path: path).standardizedFileURL.path(percentEncoded: false))
            }
        }
        return paths
    }

    /// The likeliest main file of a folder: main.tex, or the only complete document.
    private static func defaultMainFile(in tree: ProjectFile) -> URL? {
        let documents = (tree.children ?? []).filter { $0.kind == .latex }.filter { file in
            contents(of: file.url).map(isMainDocument) ?? false
        }
        return documents.first { $0.url.deletingPathExtension().lastPathComponent.lowercased() == "main" }?.url
            ?? (documents.count == 1 ? documents.first?.url : nil)
    }

    static func contents(of url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              (values.fileSize ?? 0) <= maximumFileSize,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? TextDecoding.decode(data).text
    }
}

/// Calls back when the entries of a folder change, so the navigator stays current.
nonisolated final class DirectoryWatcher: @unchecked Sendable {
    private let source: DispatchSourceFileSystemObject

    init?(url: URL, handler: @escaping @Sendable () -> Void) {
        let descriptor = Darwin.open(url.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .link],
            queue: .main
        )
        source.setEventHandler(handler: handler)
        source.setCancelHandler {
            Darwin.close(descriptor)
        }
        source.resume()
    }

    func cancel() {
        source.cancel()
    }

    deinit {
        source.cancel()
    }
}
