//
//  TextStatistics.swift
//  TexLab
//

import Foundation

/// Counts the words a reader would see: prose in the document body, not commands,
/// environment names, math, comments, keys or the preamble.
nonisolated enum WordCounter {
    static func count(in text: String) -> Int {
        let string = text as NSString
        var start = 0
        var end = string.length
        let beginDocument = string.range(of: "\\begin{document}")
        if beginDocument.location != NSNotFound {
            start = NSMaxRange(beginDocument)
        }
        let endDocument = string.range(of: "\\end{document}", options: .backwards)
        if endDocument.location != NSNotFound, endDocument.location >= start {
            end = endDocument.location
        }
        let body = NSRange(location: start, length: end - start)
        guard body.length > 0 else { return 0 }

        // Mark everything that isn't prose.
        var excluded = [Bool](repeating: false, count: body.length)
        let scan = LaTeXTokenizer.scan(string, range: body)
        for span in scan.regions + scan.tokens where span.kind != .sectionTitle {
            let lower = max(span.range.location - start, 0)
            let upper = min(NSMaxRange(span.range) - start, body.length)
            if lower < upper {
                for index in lower..<upper {
                    excluded[index] = true
                }
            }
        }

        var characters = [unichar](repeating: 0, count: body.length)
        string.getCharacters(&characters, range: body)
        var words = 0
        var inWord = false
        for index in 0..<characters.count {
            let isWordCharacter = !excluded[index] && isWordCharacter(characters[index])
            if isWordCharacter && !inWord {
                words += 1
            }
            inWord = isWordCharacter
        }
        return words
    }

    private static func isWordCharacter(_ character: unichar) -> Bool {
        switch character {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:
            return true
        case 0x27, 0x2019:
            // Apostrophes join contractions such as "don't".
            return true
        case 0xD800...0xDFFF:
            // Surrogate halves of characters outside the Basic Multilingual Plane.
            return true
        case 0x80...:
            guard let scalar = Unicode.Scalar(character) else { return false }
            return CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        default:
            return false
        }
    }
}
