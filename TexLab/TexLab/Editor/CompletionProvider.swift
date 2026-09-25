//
//  CompletionProvider.swift
//  TexLab
//

import Foundation

/// Works out what a completion is for from the text around the insertion point.
nonisolated enum CompletionContext {
    /// Characters that belong to the word being completed. Inside an argument, keys and
    /// file names may also contain `: - _ . / *`.
    static func isWordCharacter(_ character: unichar, inArgument: Bool) -> Bool {
        if Char.isCommandLetter(character) || (character >= 0x30 && character <= 0x39) {
            return true
        }
        if character >= 0x80, let scalar = Unicode.Scalar(character) {
            return CharacterSet.letters.contains(scalar)
        }
        guard inArgument else { return false }
        switch character {
        case 0x3A, 0x2D, Char.underscore, 0x2E, 0x2F, Char.star:
            return true
        default:
            return false
        }
    }

    /// The command whose braced argument contains `location`, such as `ref` in
    /// `\ref{fig:|`. Optional arguments and a star before the brace are skipped.
    static func argumentCommand(at location: Int, in text: NSString) -> String? {
        var position = location - 1
        while position >= 0 {
            let character = text.character(at: position)
            if character == Char.openBrace {
                break
            }
            if character == Char.closeBrace || character == Char.backslash || character == Char.newline {
                return nil
            }
            position -= 1
        }
        guard position >= 0 else { return nil }

        var cursor = position - 1
        while cursor >= 0 {
            let character = text.character(at: cursor)
            if character == Char.closeBracket {
                while cursor >= 0 && text.character(at: cursor) != Char.openBracket {
                    cursor -= 1
                }
                cursor -= 1
            } else if character == Char.star || character == Char.space {
                cursor -= 1
            } else {
                break
            }
        }
        let nameEnd = cursor + 1
        while cursor >= 0 && Char.isCommandLetter(text.character(at: cursor)) {
            cursor -= 1
        }
        guard cursor >= 0, text.character(at: cursor) == Char.backslash, nameEnd - cursor > 1 else {
            return nil
        }
        return text.substring(with: NSRange(location: cursor + 1, length: nameEnd - cursor - 1))
    }

    /// Arguments where TexLab offers completions as soon as `{` is typed.
    static func suggestsAutomatically(forArgumentOf command: String) -> Bool {
        command == "begin"
            || LaTeXLanguage.labelReferenceCommands.contains(command)
            || LaTeXLanguage.citationCommands.contains(command)
            || ["usepackage", "RequirePackage", "documentclass", "input", "include",
                "includegraphics", "bibliography", "addbibresource"].contains(command)
    }
}

/// Produces completions for the source editor: LaTeX commands and environments, labels
/// and macros defined in the document, citation keys from its bibliography, packages,
/// document classes and files next to the document.
struct CompletionProvider {
    /// The folder containing the document, used to find bibliographies and files.
    var documentDirectory: URL?

    func completions(for partialRange: NSRange, in text: NSString, defaultWords: [String]) -> [String] {
        let partial = text.substring(with: partialRange)
        if partial.hasPrefix("\\") {
            let names = Set(LaTeXCatalog.allCommands).union(matches(of: Self.definedCommandPattern, in: text))
            return rank(Array(names), matching: String(partial.dropFirst())).map { "\\" + $0 }
        }
        guard let command = CompletionContext.argumentCommand(at: partialRange.location, in: text) else {
            return defaultWords
        }

        let candidates: [String]
        switch command {
        case "begin", "end":
            candidates = LaTeXCatalog.environments + matches(of: Self.definedEnvironmentPattern, in: text)
        case let name where LaTeXLanguage.labelReferenceCommands.contains(name):
            candidates = matches(of: Self.labelPattern, in: text)
        case let name where LaTeXLanguage.citationCommands.contains(name):
            candidates = citationKeys(in: text)
        case "usepackage", "RequirePackage":
            candidates = LaTeXCatalog.packages
        case "documentclass", "LoadClass":
            candidates = LaTeXCatalog.documentClasses
        case "input", "include":
            candidates = files(withExtensions: ["tex"], keepingExtension: false)
        case "includegraphics":
            candidates = files(withExtensions: ["pdf", "png", "jpg", "jpeg", "eps"], keepingExtension: true)
        case "bibliography":
            candidates = files(withExtensions: ["bib"], keepingExtension: false)
        case "addbibresource":
            candidates = files(withExtensions: ["bib"], keepingExtension: true)
        default:
            return []
        }
        return rank(Array(Set(candidates)), matching: partial)
    }

    /// Case-insensitive prefix matches, exact-case matches first.
    private func rank(_ candidates: [String], matching prefix: String) -> [String] {
        let lowercasedPrefix = prefix.lowercased()
        let matching = candidates.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
        let sorted = matching.sorted { lhs, rhs in
            let lhsExact = lhs.hasPrefix(prefix)
            let rhsExact = rhs.hasPrefix(prefix)
            if lhsExact != rhsExact {
                return lhsExact
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return Array(sorted.prefix(300))
    }

    // MARK: - Document contents

    private static let labelPattern = try! NSRegularExpression(pattern: #"\\label\{([^{}]+)\}"#)
    private static let definedCommandPattern = try! NSRegularExpression(
        pattern: #"\\(?:(?:re)?newcommand|providecommand|DeclareMathOperator|def|let)\*?\s*\{?\\([A-Za-z@]+)"#
    )
    private static let definedEnvironmentPattern = try! NSRegularExpression(
        pattern: #"\\(?:newenvironment|newtheorem)\*?\{([^{}]+)\}"#
    )
    private static let bibItemPattern = try! NSRegularExpression(pattern: #"\\bibitem(?:\[[^\]]*\])?\{([^{}]+)\}"#)
    private static let bibliographyPattern = try! NSRegularExpression(pattern: #"\\(?:bibliography|addbibresource)(?:\[[^\]]*\])?\{([^{}]+)\}"#)

    private func matches(of pattern: NSRegularExpression, in text: NSString) -> [String] {
        pattern.matches(in: text as String, range: NSRange(location: 0, length: text.length)).map {
            text.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
    }

    private func citationKeys(in text: NSString) -> [String] {
        var keys = matches(of: Self.bibItemPattern, in: text)
        guard let documentDirectory else { return keys }
        let resources = matches(of: Self.bibliographyPattern, in: text)
            .flatMap { $0.split(separator: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        for resource in resources where !resource.isEmpty {
            let name = resource.hasSuffix(".bib") ? resource : resource + ".bib"
            keys += BibliographyScanner.keys(inFileAt: documentDirectory.appending(path: name))
        }
        return keys
    }

    /// Files under the document's folder, as paths relative to it.
    private func files(withExtensions extensions: Set<String>, keepingExtension: Bool) -> [String] {
        guard let documentDirectory,
              let enumerator = FileManager.default.enumerator(
                at: documentDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else { return [] }
        let basePath = documentDirectory.standardizedFileURL.path(percentEncoded: false)
        var results: [String] = []
        for case let url as URL in enumerator {
            if enumerator.level > 3 {
                enumerator.skipDescendants()
                continue
            }
            guard extensions.contains(url.pathExtension.lowercased()) else { continue }
            var path = url.standardizedFileURL.path(percentEncoded: false)
            guard path.hasPrefix(basePath) else { continue }
            path.removeFirst(basePath.count)
            if path.hasPrefix("/") {
                path.removeFirst()
            }
            results.append(keepingExtension ? path : String(path.dropLast(url.pathExtension.count + 1)))
            if results.count >= 500 {
                break
            }
        }
        return results
    }
}

/// Reads entry keys from BibTeX and BibLaTeX databases.
nonisolated enum BibliographyScanner {
    private static let entryPattern = try! NSRegularExpression(pattern: #"@\s*([A-Za-z]+)\s*[{(]\s*([^,\s{}()]+)\s*,"#)

    static func keys(inFileAt url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let text = (try? TextDecoding.decode(data))?.text else { return [] }
        return keys(in: text)
    }

    static func keys(in text: String) -> [String] {
        let string = text as NSString
        return entryPattern.matches(in: text, range: NSRange(location: 0, length: string.length)).compactMap { match in
            let type = string.substring(with: match.range(at: 1)).lowercased()
            guard type != "comment", type != "string", type != "preamble" else { return nil }
            return string.substring(with: match.range(at: 2))
        }
    }
}
