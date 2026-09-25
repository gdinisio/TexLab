//
//  TexLabDocument.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A LaTeX source file (`.tex`, `.ltx`, `.latex`).
    nonisolated static let latexSource = UTType(importedAs: "org.tug.tex", conformingTo: .plainText)

    /// A BibTeX bibliography database (`.bib`).
    nonisolated static let bibTeXDatabase = UTType(importedAs: "org.tug.bib", conformingTo: .plainText)

    /// A LaTeX package (`.sty`).
    nonisolated static let latexPackage = UTType(importedAs: "org.tug.sty", conformingTo: .plainText)

    /// A LaTeX document class (`.cls`).
    nonisolated static let latexClass = UTType(importedAs: "org.tug.cls", conformingTo: .plainText)
}

/// A TexLab document: a plain-text LaTeX source file.
///
/// The document keeps the text encoding it was opened with, so older sources written in
/// Latin-1 or Mac OS Roman are saved back exactly as they were found.
nonisolated struct TexLabDocument: FileDocument {
    var text: String
    var encoding: String.Encoding

    init(text: String = DocumentTemplate.article.text, encoding: String.Encoding = .utf8) {
        self.text = text
        self.encoding = encoding
    }

    static let readableContentTypes: [UTType] = [
        .latexSource,
        .bibTeXDatabase,
        .latexPackage,
        .latexClass,
        .plainText,
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoded = try TextDecoding.decode(data)
        text = decoded.text
        encoding = decoded.encoding
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Text that can no longer be represented in the original encoding (for example an
        // emoji typed into a Latin-1 file) is saved as UTF-8 rather than losing characters.
        let data = text.data(using: encoding) ?? Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// Decodes text files whose encoding isn't declared, preferring UTF-8.
nonisolated enum TextDecoding {
    nonisolated struct Result {
        var text: String
        var encoding: String.Encoding
    }

    static func decode(_ data: Data) throws -> Result {
        if let text = String(data: data, encoding: .utf8) {
            return Result(text: text, encoding: .utf8)
        }
        let hasUTF16ByteOrderMark = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        if hasUTF16ByteOrderMark, let text = String(data: data, encoding: .utf16) {
            return Result(text: text, encoding: .utf16)
        }
        // Legacy 8-bit encodings commonly used by LaTeX sources, most specific first.
        let fallbacks: [String.Encoding] = [.windowsCP1252, .isoLatin1, .macOSRoman]
        for encoding in fallbacks {
            if let text = String(data: data, encoding: encoding) {
                return Result(text: text, encoding: encoding)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}
