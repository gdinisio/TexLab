//
//  NewProjectFiles.swift
//  TexLab
//

import Foundation

/// The kinds of file New File in Project makes, in the order the sheet lists them.
nonisolated enum NewFileKind: String, CaseIterable, Identifiable, Sendable {
    case chapter
    case empty
    case figure
    case table
    case drawing
    case image
    case document
    case bibliography
    case package

    var id: String { rawValue }

    /// The sections of the sheet's list.
    nonisolated enum Group: String, CaseIterable, Identifiable, Sendable {
        case text
        case floats
        case mac
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text: String(localized: "Text")
            case .floats: String(localized: "Figures and Tables")
            case .mac: String(localized: "From Your Mac")
            case .other: String(localized: "Other")
            }
        }
    }

    var group: Group {
        switch self {
        case .chapter, .empty: .text
        case .figure, .table, .drawing: .floats
        case .image: .mac
        case .document, .bibliography, .package: .other
        }
    }

    var title: String {
        switch self {
        case .chapter: String(localized: "Section or Chapter")
        case .empty: String(localized: "Empty File")
        case .figure: String(localized: "Figure")
        case .table: String(localized: "Table")
        case .drawing: String(localized: "TikZ Drawing")
        case .image: String(localized: "Images")
        case .document: String(localized: "Document from Template")
        case .bibliography: String(localized: "Bibliography")
        case .package: String(localized: "Package")
        }
    }

    /// What the file is for, shown in the sheet.
    var summary: String {
        switch self {
        case .chapter:
            String(localized: "A part of the document, starting with the heading its class uses — a chapter in a report or thesis, a section in an article — added to the main file after the other parts.")
        case .empty:
            String(localized: "A file with nothing in it. Without an extension it's a LaTeX file; give it one, such as .txt or .cfg, for anything else.")
        case .figure:
            String(localized: "A figure in a file of its own: a picture from your Mac, which goes in the project, centred with a caption and a label for \\ref.")
        case .table:
            String(localized: "A table in a file of its own, with the rules of booktabs, a caption and a label for \\ref.")
        case .drawing:
            String(localized: "A figure drawn with TikZ, in a file of its own, with a caption and a label for \\ref.")
        case .image:
            String(localized: "Pictures or PDFs from your Mac, copied into the project, each in a figure with a caption and a label.")
        case .document:
            String(localized: "A complete document of its own, from one of the templates.")
        case .bibliography:
            String(localized: "A BibTeX database, added to the main file.")
        case .package:
            String(localized: "Macros the project shares, in a .sty file the main file uses.")
        }
    }

    var systemImage: String {
        switch self {
        case .chapter: "doc.text"
        case .empty: "doc"
        case .figure: "photo"
        case .table: "tablecells"
        case .drawing: "scribble.variable"
        case .image: "photo.on.rectangle.angled"
        case .document: "doc.richtext"
        case .bibliography: "books.vertical"
        case .package: "gearshape"
        }
    }

    /// The extension the file gets. An empty file can have any.
    var fileExtension: String {
        switch self {
        case .bibliography: "bib"
        case .package: "sty"
        case .image: ""
        default: "tex"
        }
    }

    var defaultName: String {
        switch self {
        case .chapter: "chapter"
        case .empty: "untitled"
        case .figure: "figure"
        case .table: "table"
        case .drawing: "drawing"
        case .image: ""
        case .document: "document"
        case .bibliography: "references"
        case .package: "macros"
        }
    }

    /// Where a new file is used from.
    nonisolated enum Reference: Sendable {
        /// The main file inputs it, uses it as a bibliography or loads it as a package.
        case mainFile
        /// It goes in where you are writing, as a figure or table does.
        case insertionPoint
        case none
    }

    var reference: Reference {
        switch self {
        case .chapter, .empty, .bibliography, .package: .mainFile
        case .figure, .table, .drawing, .image: .insertionPoint
        case .document: .none
        }
    }

    /// The packages a file of this kind needs the document to load.
    var packages: [String] {
        switch self {
        case .figure, .image: ["graphicx"]
        case .table: ["booktabs"]
        case .drawing: ["tikz"]
        default: []
        }
    }

    /// Whether the sheet asks for a caption.
    var hasCaption: Bool {
        [.figure, .table, .drawing].contains(self)
    }

    /// What using the file does, described for the sheet.
    func referenceDescription(mainFileName: String, shownFileName: String) -> String {
        switch self {
        case .chapter, .empty: String(localized: "Add \\input to \(mainFileName)")
        case .bibliography: String(localized: "Add the bibliography to \(mainFileName)")
        case .package: String(localized: "Add \\usepackage to \(mainFileName)")
        case .figure, .table, .drawing: String(localized: "Add \\input at the insertion point in \(shownFileName)")
        case .image: String(localized: "Insert a figure for each at the insertion point in \(shownFileName)")
        case .document: ""
        }
    }

    // MARK: - Contents

    /// The new file's text.
    func contents(_ options: NewFileOptions) -> String {
        // Typed as a file name, so written as it reads.
        let title = LaTeXEscaping.escape(Self.title(for: options.name))
        let key = Self.labelKey(for: options.name)
        let label = key.isEmpty ? defaultName : key
        let root = options.rootPath.map { "% !TEX root = \($0)\n\n" } ?? ""
        let caption = options.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title + "."
            : options.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .chapter:
            // The heading the main file's class uses for its parts.
            switch options.mainText.map(Self.documentClass(of:)) ?? "" {
            case "report", "book", "memoir", "scrreprt", "scrbook":
                return root + "\\chapter{\(title)}\n\\label{ch:\(label)}\n\n"
            case "beamer":
                return root + "\\section{\(title)}\n\n\\begin{frame}{\(title)}\n\n\\end{frame}\n"
            default:
                return root + "\\section{\(title)}\n\\label{sec:\(label)}\n\n"
            }
        case .empty:
            return ""
        case .figure:
            return root + Self.figureText(imagePath: options.imagePath, caption: caption, label: label)
        case .table:
            return root + Self.tableText(rows: options.rows, columns: options.columns, caption: caption, label: label)
        case .drawing:
            return root + #"""
            \begin{figure}[htbp]
              \centering
              \begin{tikzpicture}
                \draw[->] (0, 0) -- (4, 0) node[right] {$x$};
                \draw[->] (0, 0) -- (0, 2.5) node[above] {$y$};
                \draw[thick, blue] (0, 0.5) .. controls (1.5, 2.5) and (2.5, -0.5) .. (4, 1.8);
              \end{tikzpicture}
              \caption{\#(caption)}
              \label{fig:\#(label)}
            \end{figure}

            """#
        case .image:
            return ""
        case .document:
            return options.template.text
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
            \\ProvidesPackage{\(options.name)}

            % Macros shared by the project, for example:
            % \\newcommand{\\R}{\\mathbb{R}}

            \\endinput

            """
        }
    }

    /// A figure with a picture, or a frame to put one in until there is one.
    static func figureText(imagePath: String?, caption: String, label: String) -> String {
        let content: String
        if let imagePath {
            content = "  \\includegraphics[width=0.8\\linewidth]{\(imagePath)}"
        } else {
            content = """
              % Put the picture in the project and include it here, for example
              % \\includegraphics[width=0.8\\linewidth]{Figures/\(label).pdf}
              \\fbox{\\parbox[c][4cm][c]{0.6\\linewidth}{\\centering Figure}}
            """
        }
        return """
        \\begin{figure}[htbp]
          \\centering
        \(content)
          \\caption{\(caption)}
          \\label{fig:\(label)}
        \\end{figure}

        """
    }

    /// A table of `rows` rows below a heading row, with the caption above it, as tables
    /// usually have.
    static func tableText(rows: Int, columns: Int, caption: String, label: String) -> String {
        let columns = max(columns, 1)
        let heading = Array(repeating: "Heading", count: columns).joined(separator: " & ")
        // Empty cells, to fill in.
        let row = "    " + String(repeating: "& ", count: columns - 1) + "\\\\"
        let body = Array(repeating: row, count: max(rows, 1)).joined(separator: "\n")
        return """
        \\begin{table}[htbp]
          \\centering
          \\caption{\(caption)}
          \\label{tab:\(label)}
          \\begin{tabular}{\(String(repeating: "l", count: columns))}
            \\toprule
            \(heading) \\\\
            \\midrule
        \(body)
            \\bottomrule
          \\end{tabular}
        \\end{table}

        """
    }

    /// "results_2026" → "Results 2026", for a heading or caption.
    static func title(for name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    /// "Results 2026" → "results-2026", for a label.
    static func labelKey(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let words = name.lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return String(String.UnicodeScalarView(words.unicodeScalars.filter { allowed.contains($0) }))
    }

    private static let documentClassPattern = try! NSRegularExpression(pattern: #"^[^%\n]*\\documentclass\s*(?:\[[^\]]*\])?\s*\{([^}]*)\}"#, options: [.anchorsMatchLines])

    /// The class a document is typeset with, such as `article`.
    static func documentClass(of text: String) -> String {
        let string = text as NSString
        guard let match = documentClassPattern.firstMatch(in: text, range: NSRange(location: 0, length: string.length)) else { return "" }
        return string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }
}

/// The choices that shape a new file.
nonisolated struct NewFileOptions: Sendable {
    var name: String
    /// The main file's path from the new file's folder, for `% !TEX root`.
    var rootPath: String?
    /// The main file's text, for the heading its class uses.
    var mainText: String?
    var caption = ""
    /// A figure's picture, as TeX finds it from the main file's folder.
    var imagePath: String?
    var rows = 3
    var columns = 3
    var template: DocumentTemplate = .article
}
