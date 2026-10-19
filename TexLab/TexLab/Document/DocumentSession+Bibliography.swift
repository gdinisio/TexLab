//
//  DocumentSession+Bibliography.swift
//  TexLab
//

import AppKit
import Foundation

/// Bibliographies in the Visual editor: the BibTeX shown as a table of entries and their
/// fields, like Xcode's Info editor, and every change made there written into the text as
/// an undoable edit, so the Code editor and the file always have the BibTeX itself.
extension DocumentSession {
    /// Whether the shown file is a BibTeX database.
    var isBibliography: Bool {
        fileURL?.pathExtension.lowercased() == "bib"
    }

    /// Whether the editor shows the bibliography as a table rather than as BibTeX.
    var showsBibliographyEditor: Bool {
        isBibliography && editorMode == .visual
    }

    /// Whether Code | Visual applies to the shown file: a LaTeX document or a bibliography.
    var hasVisualEditor: Bool {
        supportsVisualEditor || isBibliography
    }

    /// The mode Code | Visual shows as chosen for the shown file.
    var displayedEditorMode: EditorMode {
        showsBibliographyEditor ? .visual : effectiveEditorMode
    }

    /// Writes a change made in the bibliography table into the text.
    func applyBibliographyEdit(_ edit: BibliographyEdit, actionName: String) {
        editor.replace(edit.range, with: edit.text, actionName: actionName)
    }

    func undoBibliographyEdit() {
        guard let undoManager = currentDocument?.undoManager, undoManager.canUndo else {
            NSSound.beep()
            return
        }
        undoManager.undo()
    }

    func redoBibliographyEdit() {
        guard let undoManager = currentDocument?.undoManager, undoManager.canRedo else {
            NSSound.beep()
            return
        }
        undoManager.redo()
    }

    /// Shows the BibTeX of an entry in the Code editor, for what the table doesn't edit.
    func showBibliographySource(at range: NSRange) {
        setEditorMode(.code)
        DispatchQueue.main.async { [weak self] in
            self?.editor.focus()
            self?.editor.reveal(location: range.location, length: range.length)
        }
    }
}
