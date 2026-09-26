//
//  VisualScanner.swift
//  TexLab
//

import Foundation

/// How a text-style command shows its argument in the live preview.
nonisolated struct TextStyle: OptionSet, Sendable, Hashable {
    let rawValue: Int

    static let bold = TextStyle(rawValue: 1 << 0)
    static let italic = TextStyle(rawValue: 1 << 1)
    static let monospace = TextStyle(rawValue: 1 << 2)
    static let smallCaps = TextStyle(rawValue: 1 << 3)
    static let sansSerif = TextStyle(rawValue: 1 << 4)
    static let serif = TextStyle(rawValue: 1 << 5)
    static let underline = TextStyle(rawValue: 1 << 6)
    static let strikethrough = TextStyle(rawValue: 1 << 7)
    /// Clears italic, as `\textup` and `\textnormal` do.
    static let upright = TextStyle(rawValue: 1 << 8)
    /// Clears bold, as `\textmd` and `\textnormal` do.
    static let medium = TextStyle(rawValue: 1 << 9)
}

/// What the text of a visual element represents, which decides its font and colour.
nonisolated enum VisualRole: Sendable, Equatable {
    case plain
    /// A sectioning command; 0 is `\part`, 2 is `\section`.
    case heading(level: Int)
    case title
    case author
    case link
    case footnote
}

/// Source shown as a drawing in the visual preview: a bullet, a reference chip, an
/// environment's heading, the title block or a figure.
nonisolated struct VisualLabel: Sendable, Equatable {
    nonisolated enum Kind: Sendable, Equatable {
        /// Text in the flow of the line: bullets, list numbers, dashes and quotes.
        case inline(bold: Bool)
        /// A rounded chip for `\ref`, `\cite` and `\label`.
        case chip(systemImage: String)
        /// The heading of an environment, such as Abstract or Theorem.
        case environment(centred: Bool, italic: Bool)
        /// What `\maketitle` produces.
        case titleBlock(author: String?)
        /// An `\includegraphics` image, drawn in place.
        case picture(path: String)
    }

    var range: NSRange
    var text: String
    var kind: Kind

    var fillsLine: Bool {
        switch kind {
        case .environment(let centred, _): centred
        case .titleBlock, .picture: true
        case .inline, .chip: false
        }
    }
}

/// A piece of LaTeX markup the visual preview shows as it will look: some ranges are
/// hidden, one may be replaced by a drawing, and the content is styled. The markup comes
/// back while the insertion point is in `range`.
nonisolated struct VisualElement: Sendable, Equatable {
    /// Where the insertion point reveals the markup.
    var range: NSRange
    /// The text shown styled, if any.
    var contentRange: NSRange?
    var style: TextStyle = []
    var role: VisualRole = .plain
    /// Markup hidden while the element is shown.
    var hidden: [NSRange] = []
    var label: VisualLabel?

    func shifted(by delta: Int) -> VisualElement {
        var copy = self
        copy.range.location += delta
        copy.contentRange?.location += delta
        copy.hidden = hidden.map { NSRange(location: $0.location + delta, length: $0.length) }
        copy.label?.range.location += delta
        return copy
    }
}

/// Finds the markup the visual preview presents like the typeset document, in the spirit
/// of Overleaf's Visual Editor.
nonisolated enum VisualScanner {
    // MARK: - Tables

    static let styles: [String: TextStyle] = [
        "emph": .italic, "textit": .italic, "textsl": .italic, "textbf": .bold,
        "texttt": .monospace, "textsc": .smallCaps, "textsf": .sansSerif, "textrm": .serif,
        "textup": .upright, "textmd": .medium, "textnormal": [.upright, .medium],
        "underline": .underline, "uline": .underline, "sout": .strikethrough,
    ]

    static let theoremEnvironments: Set<String> = [
        "theorem", "lemma", "corollary", "proposition", "definition", "remark", "example",
        "conjecture", "claim", "fact", "note", "exercise", "problem", "solution", "notation", "assumption",
    ]
    static let listEnvironments: Set<String> = ["itemize", "enumerate", "description"]
    /// Environments whose markers are simply hidden.
    static let plainEnvironments: Set<String> = ["quote", "quotation", "verse", "center", "flushleft", "flushright"]

    private static let styleNames = "emph|textit|textsl|textbf|texttt|textsc|textsf|textrm|textup|textmd|textnormal|underline|uline|sout"
    private static let stylePattern = regex(#"\\("# + styleNames + #")\s*\{"#)
    private static let headingPattern = regex(#"\\(part|chapter|section|subsection|subsubsection|paragraph|subparagraph)\*?\s*(?:\[[^\]\n]*\])?\s*\{"#)
    private static let titlePattern = regex(#"\\(title|author|date)\s*(?:\[[^\]\n]*\])?\s*\{"#)
    private static let urlPattern = regex(#"\\url\s*\{"#)
    private static let hrefPattern = regex(#"\\href\s*\{"#)
    private static let footnotePattern = regex(#"\\footnote\s*(?:\[[^\]\n]*\])?\s*\{"#)
    private static let referencePattern = regex(
        #"\\(ref|eqref|autoref|cref|Cref|pageref|nameref|cite|citep|citet|parencite|textcite|autocite|footcite|citeauthor|citeyear|label)\*?\s*(?:\[[^\]\n]*\]\s*){0,2}\{"#
    )
    private static let structurePattern = regex(#"\\(begin|end)\s*\{([^{}\n]+)\}|\\item\b"#)
    private static let escapePattern = regex(#"\\[&%$#_{}]"#)
    private static let typographyPattern = regex(#"---|--|``|''|\\(?:ldots|dots|textendash|textemdash|LaTeX|TeX)(?![A-Za-z])(?:\{\})?"#)
    private static let graphicsPattern = regex(#"\\includegraphics\*?\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#)
    private static let maketitlePattern = regex(#"\\maketitle(?![A-Za-z])"#)
    private static let markerPattern = regex(
        #"\\(tableofcontents|listoffigures|listoftables|newpage|clearpage|cleardoublepage|pagebreak|appendix|printbibliography)(?![A-Za-z])\*?(?:\[[^\]\n]*\])?"#
    )
    private static let bibliographyPattern = regex(#"\\(bibliography|bibliographystyle)\s*\{[^{}\n]*\}"#)

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    /// Where the document body starts: after `\begin{document}`, or at the start of a file
    /// without one (a chapter included into a larger project).
    static func bodyStart(in string: NSString) -> Int {
        let begin = string.range(of: "\\begin{document}")
        return begin.location == NSNotFound ? 0 : NSMaxRange(begin)
    }

    // MARK: - Scanning

    /// The visual elements in `range`. Only the title, author and date are looked for in
    /// the preamble. Anything overlapping `excluded` (math, comments, verbatim) is left as
    /// source. With `stylesOnly`, only elements that style text are returned, which is all
    /// the syntax colouring needs.
    static func scan(_ string: NSString, range: NSRange, excluding excluded: [NSRange], stylesOnly: Bool = false) -> [VisualElement] {
        let exclusions = Exclusions(excluded)
        let bodyStart = bodyStart(in: string)
        let body = NSIntersectionRange(range, NSRange(location: bodyStart, length: string.length - bodyStart))
        var elements: [VisualElement] = []

        // Only the markup must be outside math and comments; the content may contain math,
        // as in \section{The case $n = 1$}.
        func add(_ element: VisualElement) {
            let markup = element.hidden + (element.label.map { [$0.range] } ?? [])
            guard !markup.contains(where: exclusions.overlaps) else { return }
            elements.append(element)
        }

        // Title, author and date, anywhere.
        for match in titlePattern.matches(in: string as String, range: range) {
            guard let content = argument(after: match.range, in: string) else { continue }
            let role: VisualRole = string.substring(with: match.range(at: 1)) == "title" ? .title : .author
            add(wrapped(match.range, content: content, role: role))
        }

        if body.length > 0 {
            for match in stylePattern.matches(in: string as String, range: body) where !isEscaped(match.range.location, in: string) {
                guard let style = styles[string.substring(with: match.range(at: 1))],
                      let content = argument(after: match.range, in: string) else { continue }
                var element = wrapped(match.range, content: content, role: .plain)
                element.style = style
                add(element)
            }
            for match in headingPattern.matches(in: string as String, range: body) where !isEscaped(match.range.location, in: string) {
                guard let level = FoldScanner.sectionLevels[string.substring(with: match.range(at: 1))],
                      let content = argument(after: match.range, in: string) else { continue }
                add(wrapped(match.range, content: content, role: .heading(level: level)))
            }
            for match in urlPattern.matches(in: string as String, range: body) {
                guard let content = argument(after: match.range, in: string) else { continue }
                add(wrapped(match.range, content: content, role: .link))
            }
            for match in hrefPattern.matches(in: string as String, range: body) {
                // \href{url}{text}: hide everything but the text.
                guard let url = argument(after: match.range, in: string) else { continue }
                var next = NSMaxRange(url) + 1
                while next < string.length, Char.isWhitespace(string.character(at: next)) { next += 1 }
                guard next < string.length, string.character(at: next) == Char.openBrace,
                      let text = argument(after: NSRange(location: next, length: 1), in: string) else { continue }
                let opening = NSRange(location: match.range.location, length: text.location - match.range.location)
                add(VisualElement(
                    range: NSRange(location: match.range.location, length: NSMaxRange(text) + 1 - match.range.location),
                    contentRange: text,
                    role: .link,
                    hidden: [opening, NSRange(location: NSMaxRange(text), length: 1)]
                ))
            }
            for match in footnotePattern.matches(in: string as String, range: body) {
                guard let content = argument(after: match.range, in: string) else { continue }
                add(wrapped(match.range, content: content, role: .footnote))
            }
        }

        if !stylesOnly && body.length > 0 {
            elements += documentMarkers(in: string, range: body, bodyStart: bodyStart, exclusions: exclusions)
            elements += references(in: string, range: body, exclusions: exclusions)
            elements += structure(in: string, range: body, exclusions: exclusions)
            elements += symbols(in: string, range: body, exclusions: exclusions)
            for match in graphicsPattern.matches(in: string as String, range: body) where !exclusions.overlaps(match.range) {
                let path = string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let label = VisualLabel(range: match.range, text: path, kind: .picture(path: path))
                elements.append(VisualElement(range: match.range, label: label))
            }
            if let title = titleBlock(in: string) {
                for match in maketitlePattern.matches(in: string as String, range: body) where !exclusions.overlaps(match.range) {
                    let label = VisualLabel(range: match.range, text: title.title, kind: .titleBlock(author: title.author))
                    elements.append(VisualElement(range: match.range, label: label))
                }
            }
        }
        return elements.sorted {
            $0.range.location != $1.range.location ? $0.range.location < $1.range.location : $0.range.length > $1.range.length
        }
    }

    /// `\command{content}` with the command and braces hidden.
    private static func wrapped(_ opening: NSRange, content: NSRange, role: VisualRole) -> VisualElement {
        let whole = NSRange(location: opening.location, length: NSMaxRange(content) + 1 - opening.location)
        return VisualElement(
            range: whole,
            contentRange: content,
            role: role,
            hidden: [
                NSRange(location: opening.location, length: content.location - opening.location),
                NSRange(location: NSMaxRange(content), length: 1),
            ]
        )
    }

    // MARK: Document markers

    /// `\begin{document}`, tables of contents, page breaks and the bibliography, shown the
    /// way the typeset document shows them.
    private static func documentMarkers(in string: NSString, range: NSRange, bodyStart: Int, exclusions: Exclusions) -> [VisualElement] {
        var elements: [VisualElement] = []
        let begin = string.range(of: "\\begin{document}")
        if begin.location != NSNotFound, NSMaxRange(begin) == bodyStart, !exclusions.overlaps(begin) {
            elements.append(hiddenLine(for: begin, in: string))
        }
        for match in markerPattern.matches(in: string as String, range: range) where !exclusions.overlaps(match.range) && !isEscaped(match.range.location, in: string) {
            let label: VisualLabel
            switch string.substring(with: match.range(at: 1)) {
            case "tableofcontents":
                label = VisualLabel(range: match.range, text: String(localized: "Contents"), kind: .environment(centred: false, italic: false))
            case "listoffigures":
                label = VisualLabel(range: match.range, text: String(localized: "List of Figures"), kind: .environment(centred: false, italic: false))
            case "listoftables":
                label = VisualLabel(range: match.range, text: String(localized: "List of Tables"), kind: .environment(centred: false, italic: false))
            case "printbibliography":
                label = VisualLabel(range: match.range, text: String(localized: "References"), kind: .environment(centred: false, italic: false))
            case "appendix":
                label = VisualLabel(range: match.range, text: String(localized: "Appendix"), kind: .chip(systemImage: "paperclip"))
            default:
                label = VisualLabel(range: match.range, text: String(localized: "Page Break"), kind: .chip(systemImage: "arrow.down.to.line"))
            }
            elements.append(VisualElement(range: match.range, label: label))
        }
        for match in bibliographyPattern.matches(in: string as String, range: range) where !exclusions.overlaps(match.range) && !isEscaped(match.range.location, in: string) {
            if string.substring(with: match.range(at: 1)) == "bibliography" {
                let label = VisualLabel(range: match.range, text: String(localized: "References"), kind: .environment(centred: false, italic: false))
                elements.append(VisualElement(range: match.range, label: label))
            } else {
                // The style only matters to BibTeX.
                elements.append(hiddenLine(for: match.range, in: string))
            }
        }
        return elements
    }

    // MARK: References

    private static func references(in string: NSString, range: NSRange, exclusions: Exclusions) -> [VisualElement] {
        var elements: [VisualElement] = []
        for match in referencePattern.matches(in: string as String, range: range) where !isEscaped(match.range.location, in: string) {
            guard let keys = argument(after: match.range, in: string), keys.length > 0 else { continue }
            let whole = NSRange(location: match.range.location, length: NSMaxRange(keys) + 1 - match.range.location)
            guard !exclusions.overlaps(whole) else { continue }
            let command = string.substring(with: match.range(at: 1))
            let list = string.substring(with: keys)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: ", ")
            let text: String
            let image: String
            switch command {
            case "label":
                text = list
                image = "tag"
            case "eqref":
                text = "(\(list))"
                image = "link"
            case _ where command.hasPrefix("cite") || command.hasSuffix("cite"):
                text = list
                image = "quote.opening"
            default:
                text = list
                image = "link"
            }
            let label = VisualLabel(range: whole, text: text, kind: .chip(systemImage: image))
            elements.append(VisualElement(range: whole, label: label))
        }
        return elements
    }

    // MARK: Environments and lists

    private struct OpenList {
        var name: String
        var itemCount = 0
    }

    private static func structure(in string: NSString, range: NSRange, exclusions: Exclusions) -> [VisualElement] {
        var elements: [VisualElement] = []
        var lists: [OpenList] = []

        for match in structurePattern.matches(in: string as String, range: range) {
            let command = match.range
            guard !exclusions.overlaps(command), !isEscaped(command.location, in: string) else { continue }

            // \item
            guard match.range(at: 1).location != NSNotFound else {
                guard !lists.isEmpty else { continue }
                lists[lists.count - 1].itemCount += 1
                let list = lists[lists.count - 1]
                var labelRange = command
                var custom: String?
                if let optional = optionalArgument(at: NSMaxRange(command), in: string) {
                    custom = OutlineParser.cleanTitle(string.substring(with: NSRange(location: optional.location + 1, length: optional.length - 2)))
                    labelRange = NSRange(location: command.location, length: NSMaxRange(optional) - command.location)
                }
                let depth = lists.filter { $0.name == list.name }.count
                let text: String
                switch list.name {
                case "enumerate": text = custom ?? enumerationLabel(list.itemCount, depth: depth)
                case "description": text = custom ?? ""
                default: text = custom ?? bullet(depth: depth)
                }
                guard !text.isEmpty else { continue }
                let label = VisualLabel(range: labelRange, text: text, kind: .inline(bold: list.name == "description"))
                elements.append(VisualElement(range: labelRange, label: label))
                continue
            }

            let isBegin = string.substring(with: match.range(at: 1)) == "begin"
            let name = string.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            let base = name.hasSuffix("*") ? String(name.dropLast()) : name

            if base == "document" {
                // \end{document}: the document simply ends.
                elements.append(hiddenLine(for: command, in: string))
            } else if listEnvironments.contains(base) {
                if isBegin {
                    lists.append(OpenList(name: base))
                } else if let index = lists.lastIndex(where: { $0.name == base }) {
                    lists.removeSubrange(index...)
                }
                elements.append(hiddenLine(for: command, in: string))
            } else if plainEnvironments.contains(base) {
                elements.append(hiddenLine(for: command, in: string))
            } else if base == "abstract" {
                if isBegin {
                    let label = VisualLabel(range: command, text: String(localized: "Abstract"), kind: .environment(centred: true, italic: false))
                    elements.append(VisualElement(range: command, label: label))
                } else {
                    elements.append(hiddenLine(for: command, in: string))
                }
            } else if base == "proof" {
                if isBegin {
                    var labelRange = command
                    var text = String(localized: "Proof.")
                    if let optional = optionalArgument(at: NSMaxRange(command), in: string) {
                        text = OutlineParser.cleanTitle(string.substring(with: NSRange(location: optional.location + 1, length: optional.length - 2))) + "."
                        labelRange = NSRange(location: command.location, length: NSMaxRange(optional) - command.location)
                    }
                    let label = VisualLabel(range: labelRange, text: text, kind: .environment(centred: false, italic: true))
                    elements.append(VisualElement(range: labelRange, label: label))
                } else {
                    let label = VisualLabel(range: command, text: "∎", kind: .inline(bold: false))
                    elements.append(VisualElement(range: command, label: label))
                }
            } else if theoremEnvironments.contains(base) {
                if isBegin {
                    var labelRange = command
                    var text = base.prefix(1).uppercased() + base.dropFirst()
                    if let optional = optionalArgument(at: NSMaxRange(command), in: string) {
                        let title = OutlineParser.cleanTitle(string.substring(with: NSRange(location: optional.location + 1, length: optional.length - 2)))
                        text += " (\(title))"
                        labelRange = NSRange(location: command.location, length: NSMaxRange(optional) - command.location)
                    }
                    let label = VisualLabel(range: labelRange, text: text + ".", kind: .environment(centred: false, italic: false))
                    elements.append(VisualElement(range: labelRange, label: label))
                } else {
                    elements.append(hiddenLine(for: command, in: string))
                }
            }
        }
        return elements
    }

    /// Hides a `\begin{…}` or `\end{…}` marker. When it's alone on its line the whole line
    /// goes, so lists and quotes read without gaps.
    private static func hiddenLine(for command: NSRange, in string: NSString) -> VisualElement {
        let line = string.lineRange(for: NSRange(location: command.location, length: 0))
        let before = string.substring(with: NSRange(location: line.location, length: command.location - line.location))
        let afterStart = NSMaxRange(command)
        let after = string.substring(with: NSRange(location: afterStart, length: NSMaxRange(line) - afterStart))
        if before.trimmingCharacters(in: .whitespaces).isEmpty && after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && NSMaxRange(line) < string.length {
            // The line break is hidden too, but moving to the start of the next line
            // shouldn't bring the marker back.
            return VisualElement(range: NSRange(location: line.location, length: line.length - 1), hidden: [line])
        }
        return VisualElement(range: command, hidden: [command])
    }

    private static func bullet(depth: Int) -> String {
        ["•", "–", "∗", "·"][max(min(depth, 4), 1) - 1]
    }

    /// LaTeX's default numbering: 1. (a) i. A.
    private static func enumerationLabel(_ number: Int, depth: Int) -> String {
        switch depth {
        case 2:
            return "(\(letters(number, uppercase: false)))"
        case 3:
            return roman(number) + "."
        case 4:
            return letters(number, uppercase: true) + "."
        default:
            return "\(number)."
        }
    }

    private static func letters(_ number: Int, uppercase: Bool) -> String {
        let scalar = Unicode.Scalar(UInt8((uppercase ? 64 : 96) + min(max(number, 1), 26)))
        return String(Character(scalar))
    }

    private static func roman(_ number: Int) -> String {
        let values: [(Int, String)] = [(10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var remaining = min(max(number, 1), 39)
        var result = ""
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }

    // MARK: Symbols

    private static func symbols(in string: NSString, range: NSRange, exclusions: Exclusions) -> [VisualElement] {
        var elements: [VisualElement] = []
        for match in escapePattern.matches(in: string as String, range: range) where !isEscaped(match.range.location, in: string) {
            guard !exclusions.overlaps(match.range) else { continue }
            // \& shows as &: hide the backslash.
            elements.append(VisualElement(range: match.range, hidden: [NSRange(location: match.range.location, length: 1)]))
        }
        for match in typographyPattern.matches(in: string as String, range: range) where !exclusions.overlaps(match.range) {
            let source = string.substring(with: match.range)
            if source.hasPrefix("\\") && isEscaped(match.range.location, in: string) { continue }
            let text: String
            if source == "---" || source.hasPrefix("\\textemdash") {
                text = "—"
            } else if source == "--" || source.hasPrefix("\\textendash") {
                text = "–"
            } else if source == "``" {
                text = "“"
            } else if source == "''" {
                text = "”"
            } else if source.hasPrefix("\\LaTeX") {
                text = "LaTeX"
            } else if source.hasPrefix("\\TeX") {
                text = "TeX"
            } else {
                text = "…"
            }
            let label = VisualLabel(range: match.range, text: text, kind: .inline(bold: false))
            elements.append(VisualElement(range: match.range, label: label))
        }
        return elements
    }

    // MARK: Title block

    /// The plain title and author for `\maketitle`.
    static func titleBlock(in string: NSString) -> (title: String, author: String?)? {
        let whole = NSRange(location: 0, length: string.length)
        var title: String?
        var author: String?
        for match in titlePattern.matches(in: string as String, range: whole) where !isCommentedOut(match.range.location, in: string) {
            guard let content = argument(after: match.range, in: string) else { continue }
            let raw = string.substring(with: content)
                .replacingOccurrences(of: "\\and", with: ", ")
                .replacingOccurrences(of: "\\\\", with: " ")
            let text = OutlineParser.cleanTitle(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            switch string.substring(with: match.range(at: 1)) {
            case "title": title = text
            case "author": author = text.isEmpty ? nil : text
            default: break
            }
        }
        guard let title, !title.isEmpty else { return nil }
        return (title, author)
    }

    // MARK: - Helpers

    /// The balanced argument after an opening that ends with `{`. Arguments can't contain
    /// a blank line, as in TeX.
    static func argument(after opening: NSRange, in string: NSString) -> NSRange? {
        let start = NSMaxRange(opening)
        var depth = 1
        var index = start
        var previousWasNewline = false
        while index < string.length {
            let character = string.character(at: index)
            switch character {
            case Char.backslash:
                index += 2
                previousWasNewline = false
                continue
            case Char.percent:
                while index < string.length && string.character(at: index) != Char.newline {
                    index += 1
                }
                continue
            case Char.newline:
                if previousWasNewline { return nil }
                previousWasNewline = true
            case Char.openBrace:
                depth += 1
                previousWasNewline = false
            case Char.closeBrace:
                depth -= 1
                if depth == 0 {
                    return NSRange(location: start, length: index - start)
                }
                previousWasNewline = false
            case Char.space, Char.tab:
                break
            default:
                previousWasNewline = false
            }
            index += 1
        }
        return nil
    }

    /// A `[…]` argument starting at `location`, including the brackets.
    private static func optionalArgument(at location: Int, in string: NSString) -> NSRange? {
        guard location < string.length, string.character(at: location) == Char.openBracket else { return nil }
        var depth = 0
        var index = location
        while index < string.length {
            let character = string.character(at: index)
            if character == Char.newline { return nil }
            if character == Char.openBrace { depth += 1 }
            if character == Char.closeBrace { depth -= 1 }
            if character == Char.closeBracket && depth == 0 {
                return NSRange(location: location, length: index + 1 - location)
            }
            index += 1
        }
        return nil
    }

    /// Whether the backslash at `location` is itself escaped, as in `\\emph`.
    private static func isEscaped(_ location: Int, in string: NSString) -> Bool {
        var count = 0
        var index = location - 1
        while index >= 0 && string.character(at: index) == Char.backslash {
            count += 1
            index -= 1
        }
        return count % 2 == 1
    }

    private static func isCommentedOut(_ location: Int, in string: NSString) -> Bool {
        let lineStart = string.lineRange(for: NSRange(location: location, length: 0)).location
        guard location > lineStart else { return false }
        let prefix = string.substring(with: NSRange(location: lineStart, length: location - lineStart))
        return LaTeXText.stripComment(prefix) != prefix
    }
}

/// Ranges to leave as source, merged and sorted for fast overlap tests.
nonisolated private struct Exclusions {
    private var ranges: [NSRange] = []

    init(_ excluded: [NSRange]) {
        for range in excluded.sorted(by: { $0.location < $1.location }) where range.length > 0 {
            if let last = ranges.last, range.location <= NSMaxRange(last) {
                ranges[ranges.count - 1] = NSUnionRange(last, range)
            } else {
                ranges.append(range)
            }
        }
    }

    func overlaps(_ range: NSRange) -> Bool {
        // The last excluded range starting before the end of `range`.
        var low = 0
        var high = ranges.count
        while low < high {
            let middle = (low + high) / 2
            if ranges[middle].location < NSMaxRange(range) {
                low = middle + 1
            } else {
                high = middle
            }
        }
        guard low > 0 else { return false }
        return NSMaxRange(ranges[low - 1]) > range.location
    }
}
