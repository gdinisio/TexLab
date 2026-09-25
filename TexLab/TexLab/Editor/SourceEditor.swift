//
//  SourceEditor.swift
//  TexLab
//

import AppKit
import SwiftUI

/// Hosts the AppKit source editor in SwiftUI and keeps it in sync with the document.
struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    var configuration: EditorConfiguration
    var session: DocumentSession

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let (scrollView, textView) = SourceTextView.makeScrollableEditor()
        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.lastSyncedText = text

        textView.delegate = coordinator
        textView.configuration = configuration
        textView.setText(text)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.droppedFilesFormatter = { [weak session] urls in
            session?.textForDroppedFiles(urls) ?? ""
        }
        textView.hasCompletions = { [weak coordinator] range in
            coordinator?.hasCompletions(for: range) ?? false
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
        guard let textView = coordinator.textView else { return }
        textView.configuration = configuration
        if text != coordinator.lastSyncedText {
            // The document changed outside the editor, for example by Revert To.
            coordinator.lastSyncedText = text
            textView.setText(text)
            session.sourceDidChange(text)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditor
        weak var textView: SourceTextView?
        var lastSyncedText: String

        init(parent: SourceEditor) {
            self.parent = parent
            lastSyncedText = parent.text
        }

        private var completionProvider: CompletionProvider {
            CompletionProvider(documentDirectory: parent.session.documentDirectory)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let text = textView.string
            lastSyncedText = text
            parent.text = text
            parent.session.sourceDidChange(text)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            parent.session.selectionDidChange()
        }

        func textView(
            _ textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            guard let storage = textView.textStorage else { return words }
            return completionProvider.completions(for: charRange, in: storage.mutableString, defaultWords: words)
        }

        func hasCompletions(for range: NSRange) -> Bool {
            guard let storage = textView?.textStorage else { return false }
            return !completionProvider.completions(for: range, in: storage.mutableString, defaultWords: []).isEmpty
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
