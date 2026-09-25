//
//  MagicComments.swift
//  TexLab
//

import Foundation

/// TeXShop-style magic comments at the top of a document, understood by most Mac and
/// cross-platform TeX editors:
///
///     % !TEX program = xelatex
///     % !TEX root = ../thesis.tex
nonisolated struct MagicComments: Sendable {
    /// The engine requested with `% !TEX program`.
    var program: TypesettingEngine?
    /// The main file requested with `% !TEX root`, as written.
    var root: String?
    /// The range of the `% !TEX program` line, including its line break.
    var programLineRange: NSRange?

    private static let programPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*%[ \t]*![ \t]*TEX[ \t]+(?:TS-)?program[ \t]*=[ \t]*([^\s]+)[^\n]*\n?"#,
        options: [.caseInsensitive, .anchorsMatchLines]
    )
    private static let rootPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*%[ \t]*![ \t]*TEX[ \t]+root[ \t]*=[ \t]*(.+?)[ \t]*$"#,
        options: [.caseInsensitive, .anchorsMatchLines]
    )

    /// Reads magic comments from the start of `text`, where editors expect them.
    init(text: String) {
        let head = String(text.prefix(4000)) as NSString
        let range = NSRange(location: 0, length: head.length)
        if let match = Self.programPattern.firstMatch(in: head as String, range: range) {
            program = TypesettingEngine(magicCommentValue: head.substring(with: match.range(at: 1)))
            programLineRange = match.range
        }
        if let match = Self.rootPattern.firstMatch(in: head as String, range: range) {
            let value = head.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            root = value.isEmpty ? nil : value
        }
    }

    /// The `% !TEX program` line for `engine`.
    static func programLine(for engine: TypesettingEngine) -> String {
        "% !TEX program = \(engine.rawValue)\n"
    }
}
