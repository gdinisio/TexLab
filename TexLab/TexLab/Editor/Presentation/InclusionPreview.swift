//
//  InclusionPreview.swift
//  TexLab
//

import Foundation

/// What the Visual editor shows for an `\input` or `\include`: a chip naming the part it
/// includes, like a reference's, or the figure, drawing or table the included file holds.
nonisolated struct InclusionPreview: Sendable, Equatable {
    /// The chip's text: the part's first heading, the figure's caption, or the file's name.
    var title: String
    var systemImage: String
    /// The picture of an included figure, as `\includegraphics` names it.
    var imagePath: String?
    /// The drawing or table of an included file, typeset like a formula.
    var block: MathRegion?
    /// The caption of an included figure or table, shown beneath its preview.
    var caption: String?

    /// A file `\input` names that isn't there.
    static func missing(_ path: String) -> InclusionPreview {
        InclusionPreview(title: path, systemImage: "exclamationmark.triangle")
    }

    private static let graphicsPattern = try! NSRegularExpression(pattern: #"\\includegraphics\*?\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#)

    /// The preview of an included file, from its text. `path` is the file as `\input`
    /// names it, for a file with nothing better to show.
    static func make(for text: String, path: String) -> InclusionPreview {
        let items = OutlineParser.flatten(OutlineParser.parse(text))
        // A part of the document: its first heading, or its first slide's title.
        if let heading = items.first(where: { $0.kind.canContainItems }), !heading.title.isEmpty {
            return InclusionPreview(title: heading.title, systemImage: "doc.text")
        }

        let string = text as NSString
        let whole = NSRange(location: 0, length: string.length)
        let scan = LaTeXTokenizer.scan(string, range: whole)
        let comments = scan.tokens.filter { $0.kind == .comment || $0.kind == .verbatim }.map(\.range)
        let float = items.first { $0.kind == .figure || $0.kind == .table }
        let caption = float.map(\.title).flatMap { $0.isEmpty ? nil : $0 }
        let name = (path as NSString).lastPathComponent

        // A figure: its picture.
        let picture = graphicsPattern.matches(in: text, range: whole).first { match in
            !comments.contains { NSIntersectionRange($0, match.range).length > 0 }
        }
        if let picture {
            let imagePath = string.substring(with: picture.range(at: 1)).trimmingCharacters(in: .whitespaces)
            return InclusionPreview(title: caption ?? name, systemImage: "photo", imagePath: imagePath, caption: caption ?? name)
        }

        // A drawing or a table, typeset.
        if let block = MathScanner.blocks(in: string, range: whole, excluding: comments + scan.regions.map(\.range)).first {
            let isTable = block.snippet.hasPrefix("\\begin{tab")
            return InclusionPreview(
                title: caption ?? name,
                systemImage: isTable ? "tablecells" : "scribble.variable",
                block: block,
                caption: caption ?? name
            )
        }

        if let float {
            return InclusionPreview(title: caption ?? name, systemImage: float.kind == .table ? "tablecells" : "photo")
        }
        return InclusionPreview(title: name, systemImage: "doc.text")
    }
}
