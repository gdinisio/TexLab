//
//  SourceTextView+Completion.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// Completion as you type, like Xcode's: `\` and a letter lists commands, `\ref{` the
/// project's labels with their captions, `\cite{` its bibliography by key, author, title or
/// year, `\input{` and `\includegraphics{` its files, `\begin{` environments, and
/// `\usepackage{` packages. The list refines as you type; Return or Tab accepts, Esc
/// dismisses, and Esc shows it whenever you want it.
extension SourceTextView {
    /// Shows, refines or hides the completion list for the text at the insertion point.
    /// `explicit` is for Esc, which shows the list wherever there's something to complete;
    /// otherwise it opens by itself only where it helps — after `\` and a letter, after
    /// `{` or `,` in an argument it completes — and stays open while it matches.
    func updateCompletion(explicit: Bool, typed: String?) {
        guard let storage = textStorage, let window, !hasMarkedText() else {
            hideCompletion()
            return
        }
        let selection = selectedRange()
        guard selection.length == 0, let query = CompletionEngine.query(at: selection.location, in: storage.mutableString) else {
            hideCompletion()
            if explicit {
                NSSound.beep()
            }
            return
        }
        if !completionPopup.isVisible && !explicit {
            guard configuration.suggestsCompletions, Self.opensCompletion(for: query, afterTyping: typed) else { return }
        }
        if !completionPopup.isVisible || cachedCompletionSources == nil {
            cachedCompletionSources = completionSources?() ?? CompletionSources()
        }
        let items = CompletionEngine.items(for: query, in: storage.mutableString, sources: cachedCompletionSources ?? CompletionSources())
        // Nothing to offer beyond what's typed.
        let typedText = query.mode == .command ? "\\" + query.partial : query.partial
        if items.isEmpty || (!explicit && items.count == 1 && items[0].insertion == typedText) {
            hideCompletion()
            if explicit && items.isEmpty {
                NSSound.beep()
            }
            return
        }
        let rect = firstRect(forCharacterRange: NSRange(location: query.range.location, length: 0), actualRange: nil)
        completionPopup.onAccept = { [weak self] item in
            self?.acceptCompletion(item)
        }
        completionPopup.show(items, below: rect, in: window)
    }

    /// Whether typing `typed` should open the list by itself.
    static func opensCompletion(for query: CompletionQuery, afterTyping typed: String?) -> Bool {
        guard let typed, typed.count == 1, let character = typed.first else { return false }
        switch query.mode {
        case .command:
            return character.isLetter && !query.partial.isEmpty
        case .argument:
            return character == "{" || character == "," || character.isLetter || character.isNumber
        }
    }

    /// Refines the list once the current change is done.
    func scheduleCompletionUpdate() {
        guard !isCompletionUpdateScheduled else { return }
        isCompletionUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isCompletionUpdateScheduled = false
            guard self.completionPopup.isVisible else { return }
            self.updateCompletion(explicit: false, typed: nil)
        }
    }

    func hideCompletion() {
        completionPopup.hide()
        cachedCompletionSources = nil
    }

    /// The keys the open list handles. Returns false for the ones the text should have.
    func handleCompletionCommand(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            completionPopup.moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)):
            completionPopup.moveSelection(by: 1)
        case #selector(NSResponder.scrollPageUp(_:)), #selector(NSResponder.pageUp(_:)):
            completionPopup.moveSelection(by: -8)
        case #selector(NSResponder.scrollPageDown(_:)), #selector(NSResponder.pageDown(_:)):
            completionPopup.moveSelection(by: 8)
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
            acceptCompletion(nil)
        case #selector(NSResponder.cancelOperation(_:)):
            hideCompletion()
        default:
            return false
        }
        return true
    }

    /// Puts `chosen` (or the selected item) in place of what was typed, then finishes the
    /// job: a command gets its braces — and the list again if its argument completes too —
    /// an environment is closed, and the insertion point moves past a reference's brace.
    func acceptCompletion(_ chosen: CompletionItem?) {
        guard let storage = textStorage, let item = chosen ?? completionPopup.selectedItem,
              let query = CompletionEngine.query(at: selectedRange().location, in: storage.mutableString) else {
            hideCompletion()
            return
        }
        hideCompletion()
        isAcceptingCompletion = true
        defer {
            isAcceptingCompletion = false
        }
        insertText(item.insertion, replacementRange: query.range)
        let text = storage.mutableString
        let end = selectedRange().location

        switch query.mode {
        case .command:
            let hasBrace = end < text.length && text.character(at: end) == Char.openBrace
            guard item.argumentCount > 0, !hasBrace else { return }
            let count = item.argumentCount
            guard replaceCharacters(in: NSRange(location: end, length: 0), with: String(repeating: "{}", count: count), selecting: NSRange(location: end + 1, length: 0), actionName: nil) else { return }
            if count > 1 {
                // Tab moves on to the other arguments.
                var stops: [Int] = (0..<count).map { end + 1 + 2 * $0 }
                stops.append(end + 2 * count)
                beginPlaceholders(stops, in: NSRange(location: end, length: 2 * count))
            }
            // \ref{ lists the labels straight away, \begin{ the environments.
            if CompletionEngine.argumentCommands.contains(String(item.insertion.dropFirst())) {
                DispatchQueue.main.async { [weak self] in
                    self?.updateCompletion(explicit: false, typed: "{")
                }
            }
        case .argument("begin"):
            var after = end
            if after < text.length && text.character(at: after) == Char.closeBrace {
                after += 1
            } else {
                replaceCharacters(in: NSRange(location: after, length: 0), with: "}", selecting: nil, actionName: nil)
                after += 1
            }
            setSelectedRange(NSRange(location: after, length: 0))
            if configuration.autoClosesEnvironments {
                // Return after \begin{…} closes the environment and indents its body.
                insertNewline(nil)
            }
        case .argument(let command) where LaTeXLanguage.citationCommands.contains(command) || command.lowercased() == "cref":
            // The insertion point stays, for another key after a comma.
            break
        case .argument:
            if end < text.length && text.character(at: end) == Char.closeBrace {
                setSelectedRange(NSRange(location: end + 1, length: 0))
            }
        }
    }

    /// Keeps the list beside the text when the editor scrolls, for example while typing at
    /// the bottom of the window, and hides it when another window becomes active.
    func followScrollingForCompletion() {
        if let completionWindowObserver {
            NotificationCenter.default.removeObserver(completionWindowObserver)
            self.completionWindowObserver = nil
        }
        if let window {
            completionWindowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.hideCompletion()
                }
            }
        }
        guard completionScrollObserver == nil, let clipView = enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        completionScrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.completionPopup.isVisible else { return }
                self.scheduleCompletionUpdate()
            }
        }
    }
}
