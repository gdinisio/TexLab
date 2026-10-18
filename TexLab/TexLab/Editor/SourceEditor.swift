//
//  SourceEditor.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// Hosts the AppKit source editor in SwiftUI. The session decides which of the window's
/// documents the editor shows and receives every change; this reports edits and supplies
/// each document's undo history.
struct SourceEditor: NSViewRepresentable {
    var configuration: EditorConfiguration
    var session: DocumentSession

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = SourceTextView.makeScrollableEditor()
        let coordinator = context.coordinator
        coordinator.textView = textView

        textView.delegate = coordinator
        textView.configuration = configuration
        textView.setText(session.currentDocument?.text ?? "")
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.droppedFilesFormatter = { [weak session] urls in
            session?.textForDroppedFiles(urls) ?? ""
        }
        textView.completionSources = { [weak session] in
            session?.completionSources() ?? CompletionSources()
        }
        textView.jumpToDefinition = { [weak session] location in
            session?.jumpToDefinition(at: location) ?? false
        }
        session.editor.attach(textView)

        // Start typing straight away in a new window.
        DispatchQueue.main.async { [weak textView] in
            guard let textView, let window = textView.window else { return }
            if !(window.firstResponder is NSTextView) {
                window.makeFirstResponder(textView)
            }
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.textView?.configuration = configuration
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditor
        weak var textView: SourceTextView?

        init(parent: SourceEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.session.sourceDidChange(textView.string)
        }

        /// Each document has its own undo history, so undoing never changes a file that isn't
        /// on screen, and the document knows from it whether it has unsaved changes.
        func undoManager(for view: NSTextView) -> UndoManager? {
            parent.session.currentDocument?.undoManager ?? view.window?.undoManager
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.session.selectionDidChange()
        }

        /// Adds Jump to Definition to the editor's context menu when the click is on a
        /// reference, a citation, a file, a defined command or an environment, and Show in
        /// PDF once there is a preview to show.
        func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            guard let sourceView = view as? SourceTextView else { return menu }
            var items: [NSMenuItem] = []
            if charIndex >= 0, let definition = parent.session.definition(at: charIndex) {
                let item = NSMenuItem(title: definition.target.menuTitle, action: #selector(jumpToDefinition(_:)), keyEquivalent: "")
                item.target = self
                item.tag = charIndex
                item.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: nil)
                items.append(item)
            }
            if parent.session.canSynchronize {
                let item = NSMenuItem(title: String(localized: "Show in PDF"), action: #selector(showInPDF(_:)), keyEquivalent: "")
                item.target = self
                item.tag = sourceView.lineIndex.lineNumber(at: max(charIndex, 0))
                item.image = NSImage(systemSymbolName: "doc.richtext", accessibilityDescription: nil)
                items.append(item)
            }
            guard !items.isEmpty else { return menu }
            for (index, item) in items.enumerated() {
                menu.insertItem(item, at: index)
            }
            menu.insertItem(.separator(), at: items.count)
            return menu
        }

        @objc private func jumpToDefinition(_ sender: NSMenuItem) {
            parent.session.jumpToDefinition(at: sender.tag)
        }

        @objc private func showInPDF(_ sender: NSMenuItem) {
            parent.session.revealInPreview(line: sender.tag)
        }

        /// Keeps spelling checks to prose: commands, math, keys and verbatim text aren't
        /// marked as misspelled. Comments are still checked.
        func textView(_ textView: NSTextView, shouldSetSpellingState value: Int, range affectedCharRange: NSRange) -> Int {
            guard value != 0, let storage = textView.textStorage, affectedCharRange.location < storage.length else {
                return value
            }
            guard let raw = storage.attribute(.texLabSyntax, at: affectedCharRange.location, effectiveRange: nil) as? Int,
                  raw != SyntaxKind.comment.rawValue else {
                return value
            }
            return 0
        }
    }
}
