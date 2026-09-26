//
//  DocumentSession+Insert.swift
//  TexLab
//

import AppKit
import Foundation

/// What an imported image becomes.
nonisolated enum ImageImportPurpose: Sendable {
    /// A figure environment with a caption and label.
    case figure
    /// Just `\includegraphics`.
    case graphic
}

/// Theorem-like environments offered by the toolbar and Insert menu.
nonisolated enum TheoremKind: String, CaseIterable, Identifiable, Sendable {
    case theorem, lemma, corollary, proposition, definition, remark, example, proof

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theorem: String(localized: "Theorem")
        case .lemma: String(localized: "Lemma")
        case .corollary: String(localized: "Corollary")
        case .proposition: String(localized: "Proposition")
        case .definition: String(localized: "Definition")
        case .remark: String(localized: "Remark")
        case .example: String(localized: "Example")
        case .proof: String(localized: "Proof")
        }
    }

    /// The heading LaTeX prints, as written in `\newtheorem`.
    var heading: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var snippet: Snippet {
        Snippet(title, before: "\\begin{\(rawValue)}\n\t", after: "\n\\end{\(rawValue)}")
    }
}

/// Inserting LaTeX that works: tools add the packages and definitions they rely on to the
/// preamble, so a document keeps typesetting after using them.
extension DocumentSession {
    // MARK: - References

    /// Labels defined in this document and the rest of its project.
    var allLabels: [LabelDefinition] {
        ReferenceScanner.labels(in: text, file: nil) + (project?.labels ?? [])
    }

    /// Bibliography entries from the project's databases and this document's `\bibitem`s.
    var allBibEntries: [BibEntry] {
        (project?.bibEntries ?? []) + ReferenceScanner.bibItems(in: text)
    }

    /// Inserts `\cite{a,b}` (or another citation command) at the insertion point.
    func insertCitation(keys: [String], command: String = "cite") {
        guard !keys.isEmpty else { return }
        editor.insertText("\\\(command){\(keys.joined(separator: ","))}", actionName: String(localized: "Insert Citation"))
    }

    /// Inserts a reference to `label`, with the command that suits it unless one is given.
    func insertCrossReference(to label: LabelDefinition, command: String? = nil) {
        let command = command ?? label.preferredReferenceCommand
        switch command {
        case "cref", "Cref": ensurePackages(["cleveref"])
        case "autoref": ensurePackages(["hyperref"])
        case "eqref": ensurePackages(["amsmath"])
        default: break
        }
        editor.insertText("\\\(command){\(label.key)}", actionName: String(localized: "Insert Reference"))
    }

    // MARK: - Snippets with requirements

    /// Inserts `snippet`, first loading `packages` if the preamble doesn't.
    func insert(_ snippet: Snippet, requiring packages: [String]) {
        ensurePackages(packages)
        editor.insert(snippet)
    }

    /// Inserts a theorem-like environment, defining it with `\newtheorem` (and loading
    /// amsthm) if the preamble doesn't yet.
    func insertTheorem(_ kind: TheoremKind) {
        ensurePackages(["amsthm"])
        if kind != .proof {
            ensureTheoremDefinition(kind)
        }
        editor.insert(kind.snippet)
    }

    /// Asks for an image, then inserts it as a figure or a plain `\includegraphics`.
    func importImage(as purpose: ImageImportPurpose) {
        imageImportPurpose = purpose
        isImportingImage = true
    }

    func insertImportedImage(_ url: URL) {
        switch imageImportPurpose {
        case .figure:
            insertFigure(for: url)
        case .graphic:
            ensurePackages(["graphicx"])
            let path = projectFolder.map { PathUtilities.relativePath(of: url, from: $0) } ?? url.filePath
            editor.insertText("\\includegraphics[width=\\linewidth]{\(path)}", actionName: String(localized: "Insert Image"))
        }
    }

    // MARK: - Preamble

    /// Adds `\usepackage` lines for `packages` the document doesn't load, after its last
    /// `\usepackage`. Only a document with its own preamble is changed; a part of a project
    /// relies on its main file.
    func ensurePackages(_ packages: [String]) {
        guard !packages.isEmpty else { return }
        let string = text as NSString
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return }
        let preamble = string.substring(to: begin.location)
        let loaded = Self.loadedPackages(in: preamble)
        let missing = packages.filter { !loaded.contains($0) }
        guard !missing.isEmpty else { return }
        let insertion = missing.map { "\\usepackage{\($0)}\n" }.joined()
        editor.replace(NSRange(location: preambleInsertionPoint(before: begin.location), length: 0), with: insertion, actionName: String(localized: "Add Package"))
    }

    private func ensureTheoremDefinition(_ kind: TheoremKind) {
        let string = text as NSString
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return }
        let preamble = string.substring(to: begin.location)
        guard !preamble.contains("\\newtheorem{\(kind.rawValue)}"), !preamble.contains("\\newtheorem*{\(kind.rawValue)}") else { return }
        let definition = "\\newtheorem{\(kind.rawValue)}{\(kind.heading)}\n"
        let location = preambleInsertionPoint(before: begin.location, after: ["\\usepackage", "\\newtheorem"])
        editor.replace(NSRange(location: location, length: 0), with: definition, actionName: String(localized: "Define \(kind.title)"))
    }

    /// Where a line goes in the preamble: after the last line containing one of `markers`,
    /// or at the start of the `\begin{document}` line. Packages go after the last
    /// `\usepackage`, and theorem definitions after the last `\newtheorem` or `\usepackage`,
    /// so each follows what it depends on.
    private func preambleInsertionPoint(before beginLocation: Int, after markers: [String] = ["\\usepackage"]) -> Int {
        let string = text as NSString
        let preambleRange = NSRange(location: 0, length: beginLocation)
        var location: Int?
        for marker in markers {
            let found = string.range(of: marker, options: .backwards, range: preambleRange)
            if found.location != NSNotFound {
                location = max(location ?? 0, NSMaxRange(string.lineRange(for: found)))
            }
        }
        return location ?? string.lineRange(for: NSRange(location: beginLocation, length: 0)).location
    }

    private static let packagePattern = try! NSRegularExpression(
        pattern: #"\\(?:usepackage|RequirePackage)\s*(?:\[[^\]]*\])?\s*\{([^{}]*)\}"#
    )

    /// The packages a preamble loads, outside comments.
    static func loadedPackages(in preamble: String) -> Set<String> {
        let string = preamble as NSString
        var packages: Set<String> = []
        for match in packagePattern.matches(in: preamble, range: NSRange(location: 0, length: string.length)) {
            let lineStart = string.lineRange(for: NSRange(location: match.range.location, length: 0)).location
            let prefix = string.substring(with: NSRange(location: lineStart, length: match.range.location - lineStart))
            guard LaTeXText.stripComment(prefix) == prefix else { continue }
            for name in string.substring(with: match.range(at: 1)).split(separator: ",") {
                packages.insert(name.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return packages
    }
}
