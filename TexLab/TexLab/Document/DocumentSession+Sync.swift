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

    /// Shows the PDF text produced by `line` of this document.
    func revealInPreview(line: Int) {
        guard let synctex, let sourceMap,
              let location = synctex.location(forLine: line, inFileAt: sourceMap.texPaths(for: .currentDocument)) else {
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
            editor.revealLine(hit.line)
        case .file(let url):
            SourceNavigator.open(url, line: hit.line)
        }
    }
}
