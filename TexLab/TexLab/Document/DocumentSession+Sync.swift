//
//  DocumentSession+Sync.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

extension DocumentSession {
    /// Whether the latest PDF can be linked to the source.
    var canSynchronize: Bool {
        synctex != nil && pdfDocument != nil
    }

    /// Shows the PDF text produced by the line with the insertion point (forward search).
    func revealSelectionInPreview() {
        revealInPreview(line: editor.caretPosition.line)
    }

    /// Shows the PDF text produced by `line` of the file the editor shows.
    func revealInPreview(line: Int) {
        guard let synctex, let sourceMap else {
            NSSound.beep()
            return
        }
        let paths = fileURL.map(sourceMap.texPaths(forFileAt:)) ?? sourceMap.texPaths(for: .currentDocument)
        guard let location = synctex.location(forLine: line, inFileAt: paths) else {
            NSSound.beep()
            return
        }
        isPreviewVisible = true
        preview.reveal(location)
    }

    /// Shows the source line that produced a point in the PDF (inverse search), opening
    /// another file of the project if that's where it came from.
    func revealSource(pageIndex: Int, point: CGPoint) {
        guard let synctex, let sourceMap, let hit = synctex.sourcePoint(pageIndex: pageIndex, point: point) else {
            NSSound.beep()
            return
        }
        switch sourceMap.resolve(hit.path) {
        case .currentDocument:
            // The file that was shown when the document was typeset.
            if let url = sourceMap.currentDocumentURL {
                open(url, line: hit.line)
            } else {
                editor.revealLine(hit.line)
            }
        case .file(let url):
            open(url, line: hit.line)
        }
    }
}
