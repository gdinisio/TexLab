//
//  LaTeXSyntax.swift
//  TexLab
//

import Foundation

/// The syntactic categories TexLab distinguishes in LaTeX source.
nonisolated enum SyntaxKind: Int, Sendable {
    case command = 1
    case environment
    case math
    case comment
    case reference
    case special
    case verbatim
    /// The argument of a sectioning command, drawn in bold.
    case sectionTitle
}

/// A range of source text and its syntactic category.
nonisolated struct SyntaxSpan: Sendable, Equatable {
    var range: NSRange
    var kind: SyntaxKind
}

/// The spans found in a range of source text.
nonisolated struct SyntaxScan: Sendable {
    /// Math regions. Apply these first so tokens inside them, such as comments, win.
    var regions: [SyntaxSpan] = []
    /// Individual tokens, in source order.
    var tokens: [SyntaxSpan] = []
}

/// Vocabulary shared by the tokenizer, the editor and the outline.
nonisolated enum LaTeXLanguage {
    static let mathEnvironments: Set<String> = [
        "equation", "equation*", "align", "align*", "alignat", "alignat*",
        "flalign", "flalign*", "gather", "gather*", "multline", "multline*",
        "eqnarray", "eqnarray*", "math", "displaymath", "dmath", "dmath*",
    ]

    static let verbatimEnvironments: Set<String> = [
        "verbatim", "verbatim*", "Verbatim", "Verbatim*", "BVerbatim", "LVerbatim",
        "lstlisting", "minted", "comment",
    ]

    static let listEnvironments: Set<String> = ["itemize", "enumerate", "description"]

    static let sectioningCommands: Set<String> = [
        "part", "chapter", "section", "subsection", "subsubsection",
        "paragraph", "subparagraph", "frametitle",
    ]

    /// Commands whose braced argument is a key, label, file or package name.
    static let referenceCommands: Set<String> = [
        "label", "ref", "eqref", "pageref", "autoref", "nameref", "cref", "Cref",
        "cite", "citep", "citet", "citealp", "citealt", "citeauthor", "citeyear",
        "parencite", "textcite", "autocite", "footcite", "fullcite", "smartcite", "nocite",
        "input", "include", "includeonly", "includegraphics", "includepdf", "lstinputlisting",
        "usepackage", "RequirePackage", "documentclass", "LoadClass",
        "bibliography", "bibliographystyle", "addbibresource", "url",
    ]

    static let labelReferenceCommands: Set<String> = [
        "ref", "eqref", "pageref", "autoref", "nameref", "cref", "Cref", "vref",
    ]

    static let citationCommands: Set<String> = [
        "cite", "citep", "citet", "citealp", "citealt", "citeauthor", "citeyear",
        "parencite", "textcite", "autocite", "footcite", "fullcite", "smartcite", "nocite",
        "Cite", "Parencite", "Textcite", "Autocite",
    ]
}

/// UTF-16 code units the tokenizer recognises.
nonisolated enum Char {
    static let tab: unichar = 0x09
    static let newline: unichar = 0x0A
    static let carriageReturn: unichar = 0x0D
    static let space: unichar = 0x20
    static let hash: unichar = 0x23
    static let dollar: unichar = 0x24
    static let percent: unichar = 0x25
    static let ampersand: unichar = 0x26
    static let openParen: unichar = 0x28
    static let closeParen: unichar = 0x29
    static let star: unichar = 0x2A
    static let comma: unichar = 0x2C
    static let at: unichar = 0x40
    static let openBracket: unichar = 0x5B
    static let backslash: unichar = 0x5C
    static let closeBracket: unichar = 0x5D
    static let caret: unichar = 0x5E
    static let underscore: unichar = 0x5F
    static let openBrace: unichar = 0x7B
    static let closeBrace: unichar = 0x7D
    static let tilde: unichar = 0x7E

    /// Letters allowed in a control word (`\name`); `@` is a letter in packages and classes.
    static func isCommandLetter(_ c: unichar) -> Bool {
        (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == at
    }

    static func isWhitespace(_ c: unichar) -> Bool {
        c == space || c == tab || c == newline || c == carriageReturn
    }
}

/// A single-pass LaTeX tokenizer.
///
/// It is deliberately forgiving: it recognises commands, environments, math, comments and
/// verbatim text well enough to colour source and to tell prose from markup, without
/// expanding macros. Scanning always starts in text mode, so callers begin at a paragraph
/// boundary, where TeX itself resets math mode.
nonisolated enum LaTeXTokenizer {
    static func scan(_ string: NSString, range: NSRange) -> SyntaxScan {
        guard range.length > 0 else { return SyntaxScan() }
        var characters = [unichar](repeating: 0, count: range.length)
        string.getCharacters(&characters, range: range)
        var scanner = TokenScanner(characters: characters, base: range.location)
        scanner.run()
        return scanner.result
    }
}

nonisolated private struct TokenScanner {
    private nonisolated enum MathMode: Equatable {
        case dollar
        case doubleDollar
        case bracket
        case paren
        case environment(String)
    }

    let characters: [unichar]
    let base: Int
    private(set) var result = SyntaxScan()

    private var index = 0
    private var mathMode: MathMode?
    private var mathStart = 0
    /// The kind given to the next braced argument, set after `\section` or `\ref`.
    private var pendingArgument: SyntaxKind?

    init(characters: [unichar], base: Int) {
        self.characters = characters
        self.base = base
    }

    mutating func run() {
        let count = characters.count
        while index < count {
            let c = characters[index]
            switch c {
            case Char.percent:
                scanComment()
            case Char.backslash:
                scanBackslash()
            case Char.dollar:
                scanDollar()
            case Char.openBrace:
                scanOpenBrace()
            case Char.openBracket:
                scanOpenBracket()
            case Char.newline:
                scanNewline()
            case Char.space, Char.tab, Char.carriageReturn:
                index += 1
            case Char.ampersand, Char.tilde, Char.caret, Char.underscore, Char.hash:
                if mathMode == nil {
                    add(.special, from: index, length: 1)
                }
                pendingArgument = nil
                index += 1
            default:
                pendingArgument = nil
                index += 1
            }
        }
        if mathMode != nil {
            // Unterminated math runs to the end of the scanned text, which also shows the
            // writer that a closing delimiter is missing.
            addRegion(from: mathStart, to: count)
        }
    }

    // MARK: - Tokens

    private mutating func scanComment() {
        var end = index + 1
        while end < characters.count && characters[end] != Char.newline {
            end += 1
        }
        add(.comment, from: index, length: end - index)
        index = end
    }

    private mutating func scanBackslash() {
        let start = index
        let count = characters.count
        guard start + 1 < count else {
            if mathMode == nil {
                add(.command, from: start, length: 1)
            }
            index += 1
            return
        }

        let next = characters[start + 1]
        guard Char.isCommandLetter(next) else {
            scanControlSymbol(start: start, symbol: next)
            return
        }

        var nameEnd = start + 1
        while nameEnd < count && Char.isCommandLetter(characters[nameEnd]) {
            nameEnd += 1
        }
        let name = String(decoding: characters[(start + 1)..<nameEnd], as: UTF16.self)
        var end = nameEnd
        if end < count && characters[end] == Char.star {
            end += 1
        }
        index = end

        if name == "begin" || name == "end" {
            scanEnvironment(isBegin: name == "begin", commandStart: start, commandEnd: end)
            return
        }
        guard mathMode == nil else {
            // Commands inside math take the math colour.
            return
        }
        add(.command, from: start, length: end - start)

        if name == "verb" {
            scanInlineVerbatim()
        } else if LaTeXLanguage.sectioningCommands.contains(name) {
            pendingArgument = .sectionTitle
        } else if LaTeXLanguage.referenceCommands.contains(name) {
            pendingArgument = .reference
        } else {
            pendingArgument = nil
        }
    }

    private mutating func scanControlSymbol(start: Int, symbol: unichar) {
        index = start + 2
        pendingArgument = nil
        switch symbol {
        case Char.openBracket where mathMode == nil:
            mathMode = .bracket
            mathStart = start
        case Char.closeBracket where mathMode == .bracket:
            addRegion(from: mathStart, to: index)
            mathMode = nil
        case Char.openParen where mathMode == nil:
            mathMode = .paren
            mathStart = start
        case Char.closeParen where mathMode == .paren:
            addRegion(from: mathStart, to: index)
            mathMode = nil
        case Char.newline:
            // A control space at the end of a line: colour only the backslash so the
            // newline is still seen by the paragraph logic.
            index = start + 1
            if mathMode == nil {
                add(.command, from: start, length: 1)
            }
        default:
            if mathMode == nil {
                add(.command, from: start, length: 2)
            }
        }
    }

    private mutating func scanEnvironment(isBegin: Bool, commandStart: Int, commandEnd: Int) {
        let count = characters.count
        var open = commandEnd
        while open < count && (characters[open] == Char.space || characters[open] == Char.tab) {
            open += 1
        }
        var close = open + 1
        if open < count && characters[open] == Char.openBrace {
            while close < count,
                  characters[close] != Char.closeBrace,
                  characters[close] != Char.openBrace,
                  characters[close] != Char.newline {
                close += 1
            }
        }
        guard open < count, characters[open] == Char.openBrace,
              close < count, characters[close] == Char.closeBrace else {
            if mathMode == nil {
                add(.command, from: commandStart, length: commandEnd - commandStart)
            }
            return
        }

        let name = String(decoding: characters[(open + 1)..<close], as: UTF16.self)
        let afterName = close + 1

        if let mode = mathMode {
            // Inside math only the matching \end closes it; anything else is math content.
            if !isBegin && mode == .environment(name) {
                addRegion(from: mathStart, to: commandStart)
                mathMode = nil
                add(.command, from: commandStart, length: commandEnd - commandStart)
                add(.environment, from: open + 1, length: close - open - 1)
            }
            index = afterName
            return
        }

        add(.command, from: commandStart, length: commandEnd - commandStart)
        add(.environment, from: open + 1, length: close - open - 1)
        index = afterName
        pendingArgument = nil

        guard isBegin else { return }
        if LaTeXLanguage.mathEnvironments.contains(name) {
            mathMode = .environment(name)
            mathStart = afterName
        } else if LaTeXLanguage.verbatimEnvironments.contains(name) {
            scanVerbatimBody(environment: name)
        }
    }

    private mutating func scanVerbatimBody(environment name: String) {
        let terminator = Array("\\end{\(name)}".utf16)
        let count = characters.count
        let start = index
        var end = start
        var found = false
        while end + terminator.count <= count {
            if characters[end] == Char.backslash && matches(terminator, at: end) {
                found = true
                break
            }
            end += 1
        }
        if !found {
            end = count
        }
        add(name == "comment" ? .comment : .verbatim, from: start, length: end - start)
        // The closing \end{…} is tokenized normally on the next pass through the loop.
        index = end
    }

    private mutating func scanInlineVerbatim() {
        let count = characters.count
        guard index < count else { return }
        let delimiter = characters[index]
        guard !Char.isCommandLetter(delimiter), !Char.isWhitespace(delimiter) else { return }
        var end = index + 1
        while end < count && characters[end] != delimiter && characters[end] != Char.newline {
            end += 1
        }
        if end < count && characters[end] == delimiter {
            end += 1
        }
        add(.verbatim, from: index, length: end - index)
        index = end
    }

    private mutating func scanDollar() {
        let isDouble = index + 1 < characters.count && characters[index + 1] == Char.dollar
        pendingArgument = nil
        switch mathMode {
        case nil:
            mathMode = isDouble ? .doubleDollar : .dollar
            mathStart = index
            index += isDouble ? 2 : 1
        case .dollar?:
            index += 1
            addRegion(from: mathStart, to: index)
            mathMode = nil
        case .doubleDollar?:
            index += isDouble ? 2 : 1
            addRegion(from: mathStart, to: index)
            mathMode = nil
        default:
            // A stray dollar inside \[ … \] or a math environment.
            index += 1
        }
    }

    private mutating func scanOpenBrace() {
        guard let argument = pendingArgument, mathMode == nil else {
            index += 1
            return
        }
        pendingArgument = nil
        let close = matchingClose(from: index, open: Char.openBrace, close: Char.closeBrace)
        let contentStart = index + 1
        let contentEnd = close ?? lineEnd(from: index)
        add(argument, from: contentStart, length: contentEnd - contentStart)
        if argument == .reference {
            index = close.map { $0 + 1 } ?? contentEnd
        } else {
            // Keep scanning inside titles so commands within them are coloured too.
            index += 1
        }
    }

    private mutating func scanOpenBracket() {
        // Optional arguments before a reference or title keep the pending argument alive.
        if pendingArgument != nil, mathMode == nil,
           let close = matchingClose(from: index, open: Char.openBracket, close: Char.closeBracket) {
            index = close + 1
            return
        }
        index += 1
    }

    private mutating func scanNewline() {
        index += 1
        // A blank line ends the paragraph, and TeX doesn't allow inline or display math
        // to continue past it.
        guard let mode = mathMode, isBlankLine(at: index) else { return }
        if case .environment = mode { return }
        addRegion(from: mathStart, to: index)
        mathMode = nil
    }

    // MARK: - Helpers

    private func matches(_ pattern: [unichar], at position: Int) -> Bool {
        guard position + pattern.count <= characters.count else { return false }
        for offset in 0..<pattern.count where characters[position + offset] != pattern[offset] {
            return false
        }
        return true
    }

    /// The index of the delimiter closing the group opened at `start`, on the same line.
    private func matchingClose(from start: Int, open: unichar, close: unichar) -> Int? {
        var depth = 0
        var position = start
        while position < characters.count {
            let c = characters[position]
            if c == Char.newline {
                return nil
            } else if c == Char.backslash {
                position += 2
                continue
            } else if c == open {
                depth += 1
            } else if c == close {
                depth -= 1
                if depth == 0 {
                    return position
                }
            }
            position += 1
        }
        return nil
    }

    private func lineEnd(from start: Int) -> Int {
        var position = start
        while position < characters.count && characters[position] != Char.newline {
            position += 1
        }
        return position
    }

    private func isBlankLine(at start: Int) -> Bool {
        var position = start
        while position < characters.count {
            let c = characters[position]
            if c == Char.newline {
                return true
            }
            if c != Char.space && c != Char.tab && c != Char.carriageReturn {
                return false
            }
            position += 1
        }
        return false
    }

    private mutating func add(_ kind: SyntaxKind, from start: Int, length: Int) {
        guard length > 0 else { return }
        result.tokens.append(SyntaxSpan(range: NSRange(location: base + start, length: length), kind: kind))
    }

    private mutating func addRegion(from start: Int, to end: Int) {
        guard end > start else { return }
        result.regions.append(SyntaxSpan(range: NSRange(location: base + start, length: end - start), kind: .math))
    }
}
