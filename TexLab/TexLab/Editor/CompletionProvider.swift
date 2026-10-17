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
