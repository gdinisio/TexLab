//
//  DocumentStructure.swift
//  TexLab
//

import Foundation

/// A file of the document, in the order the main file reads it.
nonisolated struct DocumentPart: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: Sendable {
        case main
        /// Read with `\input`, `\include`, `\subfile` or `\import`.
        case included
        case bibliography
    }

    /// Its place in reading order, which also identifies it: a file included twice
    /// appears twice.
    var order: Int
    var url: URL
    var kind: Kind
    /// How deeply it is included: 0 for the main file, 1 for a chapter it inputs.
    var depth: Int
    /// The first heading in the file, or the document's title for the main file.
    var title: String?

    var id: Int { order }

    var systemImage: String {
        switch kind {
        // The main file is a LaTeX file like the others, with a Main badge.
        case .main: "doc.text"
        case .included: "doc.text"
        case .bibliography: "books.vertical"
        }
    }
}

/// A heading, frame or float of the whole document, with the file it is in.
nonisolated struct DocumentOutlineEntry: Hashable, Sendable {
    var file: URL
    var kind: OutlineItem.Kind
    var title: String
    var line: Int
    var location: Int
}

/// The outline of the whole document as a tree, for the Outline navigator.
nonisolated struct DocumentOutlineNode: Identifiable, Hashable, Sendable {
    var entry: DocumentOutlineEntry
    var children: [DocumentOutlineNode]?

    var id: String { "\(entry.file.path(percentEncoded: false))#\(entry.location)" }
}

/// Follows a document from its main file through the files it includes, in the order TeX
/// reads them, for the project navigator's Document section and the outline of the whole
/// document.
nonisolated enum DocumentStructure {
    private static let inclusionPattern = try! NSRegularExpression(
        pattern: #"\\(?:input|include|subfile)\s*\{([^{}]+)\}|\\(sub)?import\*?\s*\{([^{}]*)\}\s*\{([^{}]+)\}"#
    )
    private static let bibliographyPattern = try! NSRegularExpression(
        pattern: #"\\(bibliography|addbibresource|addglobalbib)\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#
    )
    private static let maximumParts = 300
    private static let maximumDepth = 8

    /// The main file and every file it includes, depth first, followed by the
    /// bibliographies it uses, and the outline of all of them in reading order.
    static func build(main: URL, read: @escaping (URL) -> String?) -> (parts: [DocumentPart], outline: [DocumentOutlineEntry]) {
        var parts: [DocumentPart] = []
        var outline: [DocumentOutlineEntry] = []
        var visited: Set<String> = []
        var bibliographies: [URL] = []
        let mainFolder = main.deletingLastPathComponent()

        func walk(_ url: URL, depth: Int) {
            let path = SourceMap.canonicalPath(url)
            guard parts.count < maximumParts, !visited.contains(path), let text = read(url) else { return }
            visited.insert(path)
            let items = OutlineParser.flatten(OutlineParser.parse(text))
            let title = depth == 0
                ? ProjectIndex.title(in: text)
                : items.first(where: { $0.kind.canContainItems })?.title
            parts.append(DocumentPart(order: parts.count, url: url, kind: depth == 0 ? .main : .included, depth: depth, title: title))
            bibliographies += self.bibliographies(in: text, mainFolder: mainFolder)

            // Headings in reading order, with each included file's headings where it is read.
            var itemIndex = 0
            for inclusion in inclusions(in: text, of: url, mainFolder: mainFolder) {
                while itemIndex < items.count && items[itemIndex].location < inclusion.location {
                    outline.append(entry(items[itemIndex], in: url))
                    itemIndex += 1
                }
                if depth < maximumDepth {
                    walk(inclusion.url, depth: depth + 1)
                }
            }
            while itemIndex < items.count {
                outline.append(entry(items[itemIndex], in: url))
                itemIndex += 1
            }
        }

        walk(main, depth: 0)
        var seenBibliographies: Set<String> = []
        for bibliography in bibliographies where parts.count < maximumParts {
            guard seenBibliographies.insert(SourceMap.canonicalPath(bibliography)).inserted else { continue }
            parts.append(DocumentPart(order: parts.count, url: bibliography, kind: .bibliography, depth: 1, title: nil))
        }
        return (parts, outline)
    }

    private static func entry(_ item: OutlineItem, in file: URL) -> DocumentOutlineEntry {
        DocumentOutlineEntry(file: file, kind: item.kind, title: item.title, line: item.line, location: item.location)
    }

    /// The files `text` includes, with where, outside comments. Paths are relative to the
    /// main file's folder, where TeX runs, except for `\subimport`.
    static func inclusions(in text: String, of file: URL, mainFolder: URL) -> [(location: Int, url: URL)] {
        let string = text as NSString
        var results: [(location: Int, url: URL)] = []
        for match in inclusionPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            guard !DefinitionFinder.isInComment(match.range.location, in: string) else { continue }
            let path: String
            var folder = mainFolder
            if match.range(at: 1).location != NSNotFound {
                path = string.substring(with: match.range(at: 1))
            } else {
                if match.range(at: 2).location != NSNotFound {
                    folder = file.deletingLastPathComponent()
                }
                let directory = string.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                folder = directory.isEmpty ? folder : folder.appending(path: directory, directoryHint: .isDirectory)
                path = string.substring(with: match.range(at: 4))
            }
            if let url = resolve(path.trimmingCharacters(in: .whitespaces), in: folder, extensions: ["tex"]) {
                results.append((match.range.location, url))
            }
        }
        return results
    }

    /// The bibliography databases `text` names that exist.
    private static func bibliographies(in text: String, mainFolder: URL) -> [URL] {
        let string = text as NSString
        var results: [URL] = []
        for match in bibliographyPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            guard !DefinitionFinder.isInComment(match.range.location, in: string) else { continue }
            for name in string.substring(with: match.range(at: 2)).split(separator: ",") {
                if let url = resolve(name.trimmingCharacters(in: .whitespaces), in: mainFolder, extensions: ["bib"]) {
                    results.append(url)
                }
            }
        }
        return results
    }

    /// A path as TeX finds it: as written, or with one of `extensions` added.
    private static func resolve(_ path: String, in folder: URL, extensions: [String]) -> URL? {
        guard !path.isEmpty, !path.contains("\\") else { return nil }
        let base = path.hasPrefix("/") ? URL(filePath: path) : folder.appending(path: path)
        var candidates = extensions.map { base.appendingPathExtension($0) }
        if extensions.contains(base.pathExtension.lowercased()) {
            candidates.insert(base, at: 0)
        } else {
            candidates.append(base)
        }
        return candidates.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.filePath, isDirectory: &isDirectory) && !isDirectory.boolValue
        }?.standardizedFileURL
    }

    /// Nests outline entries under the nearest preceding entry of a shallower level, as in
    /// a single file's outline.
    static func tree(from entries: [DocumentOutlineEntry]) -> [DocumentOutlineNode] {
        var parents: [Int?] = []
        var stack: [Int] = []
        for (index, entry) in entries.enumerated() {
            while let last = stack.last, entries[last].kind.level >= entry.kind.level {
                stack.removeLast()
            }
            parents.append(stack.last)
            if entry.kind.canContainItems {
                stack.append(index)
            }
        }
        var childIndices: [Int: [Int]] = [:]
        var rootIndices: [Int] = []
        for (index, parent) in parents.enumerated() {
            if let parent {
                childIndices[parent, default: []].append(index)
            } else {
                rootIndices.append(index)
            }
        }
        func build(_ index: Int) -> DocumentOutlineNode {
            let children = (childIndices[index] ?? []).map(build)
            return DocumentOutlineNode(entry: entries[index], children: children.isEmpty ? nil : children)
        }
        return rootIndices.map(build)
    }
}
