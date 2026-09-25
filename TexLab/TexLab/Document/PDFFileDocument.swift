//
//  PDFFileDocument.swift
//  TexLab
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A typeset PDF being exported with the standard Save panel.
nonisolated struct PDFFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
