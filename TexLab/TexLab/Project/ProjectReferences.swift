//
//  ProjectReferences.swift
//  TexLab
//

import Foundation

/// The kinds of file New File creates.
nonisolated enum NewFileKind: String, CaseIterable, Identifiable, Sendable {
    case chapter
    case bibliography
    case package
    case document

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chapter: String(localized: "LaTeX Section or Chapter")
        case .bibliography: String(localized: "BibTeX Bibliography")
        case .package: String(localized: "LaTeX Package")
        case .document: String(localized: "LaTeX Document")
        }
    }

    var systemImage: String {
        switch self {
        case .chapter: "doc.text"
        case .bibliography: "books.vertical"
        case .package: "gearshape"
        case .document: "doc.richtext"
        }
    }

    var fileExtension: String {
        switch self {
        case .chapter, .document: "tex"
        case .bibliography: "bib"
        case .package: "sty"
        }
    }

    var defaultName: String {
        switch self {
        case .chapter: "chapter"
        case .bibliography: "references"
        case .package: "macros"
        case .document: "document"
        }
    }

    /// Whether the main file can reference a file of this kind.
    var canBeReferenced: Bool {
        self != .document
    }

    /// What the main file gains, described for the New File sheet.
    func referenceDescription(mainFileName: String) -> String {
        switch self {
        case .chapter: String(localized: "Add \\input to \(mainFileName)")
        case .bibliography: String(localized: "Add the bibliography to \(mainFileName)")
        case .package: String(localized: "Add \\usepackage to \(mainFileName)")
        case .document: ""
        }
    }

    /// The new file's text.
    func contents(name: String, rootPath: String?) -> String {
        let title = name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
        switch self {
        case .chapter:
            var text = ""
            if let rootPath {
                // Typesetting this file typesets the whole project.
                text += "% !TEX root = \(rootPath)\n\n"
            }
            return text + "\\section{\(title)}\n\n"
        case .bibliography:
            return """
            % Bibliography database. Cite entries with \\cite{key}.
            %
            % @article{key,
            %   author  = {Last, First and Other, Author},
            %   title   = {Title of the Article},
            %   journal = {Journal},
            %   year    = {2026},
            % }

            """
        case .package:
            return """
            \\NeedsTeXFormat{LaTeX2e}
            \\ProvidesPackage{\(name)}

            % Macros shared by the project, for example:
            % \\newcommand{\\R}{\\mathbb{R}}

            \\endinput

            """
        case .document:
            return DocumentTemplate.article.text
        }
    }
}

/// Edits that make one file of a project use another.
nonisolated enum ProjectReferences {
    /// The command that uses `file` from a document in `folder`, as typed at the insertion
    /// point, or nil for files LaTeX doesn't reference.
    static func reference(to file: URL, from folder: URL) -> String? {
        let path = PathUtilities.relativePath(of: file, from: folder)
        let withoutExtension = String(path.dropLast(file.pathExtension.isEmpty ? 0 : file.pathExtension.count + 1))
        switch ProjectFileKind(url: file, isDirectory: false) {
        case .latex: return "\\input{\(withoutExtension)}"
        case .bibliography: return "\\bibliography{\(withoutExtension)}"
        case .package where file.pathExtension.lowercased() == "sty": return "\\usepackage{\(withoutExtension)}"
        case .image, .pdf: return "\\includegraphics[width=\\linewidth]{\(path)}"
        default: return nil
        }
    }

    /// Where and what to insert in the main file's `text` so it uses `file`, or nil if it
    /// already does.
    static func insertion(for file: URL, kind: NewFileKind, in text: String, mainFolder: URL) -> (range: NSRange, text: String)? {
        let string = text as NSString
        let path = PathUtilities.relativePath(of: file, from: mainFolder)
        let withoutExtension = String(path.dropLast(file.pathExtension.count + 1))
        switch kind {
        case .chapter:
            let command = "\\input{\(withoutExtension)}"
            guard !text.contains(command) else { return nil }
            return (lineStart(before: "\\end{document}", in: string), command + "\n")
        case .package:
            let command = "\\usepackage{\(withoutExtension)}"
            guard !text.contains(command) else { return nil }
            return (lineStart(before: "\\begin{document}", in: string), command + "\n")
        case .bibliography:
            if text.contains("biblatex") || text.contains("\\addbibresource") {
                let command = "\\addbibresource{\(path)}"
                guard !text.contains(command) else { return nil }
                return (lineStart(before: "\\begin{document}", in: string), command + "\n")
            }
            let existing = string.range(of: "\\bibliography{")
            if existing.location != NSNotFound {
                // Add to the list of databases.
                let close = string.range(of: "}", range: NSRange(location: NSMaxRange(existing), length: string.length - NSMaxRange(existing)))
                guard close.location != NSNotFound else { return nil }
                let list = string.substring(with: NSRange(location: NSMaxRange(existing), length: close.location - NSMaxRange(existing)))
                let names = list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard !names.contains(withoutExtension) else { return nil }
                return (NSRange(location: close.location, length: 0), names.isEmpty ? withoutExtension : "," + withoutExtension)
            }
            return (lineStart(before: "\\end{document}", in: string), "\\bibliographystyle{plain}\n\\bibliography{\(withoutExtension)}\n")
        case .document:
            return nil
        }
    }

    /// The start of the line containing `marker`, or the end of the text.
    private static func lineStart(before marker: String, in string: NSString) -> NSRange {
        let found = string.range(of: marker, options: .backwards)
        guard found.location != NSNotFound else {
            return NSRange(location: string.length, length: 0)
        }
        return NSRange(location: string.lineRange(for: NSRange(location: found.location, length: 0)).location, length: 0)
    }
}
