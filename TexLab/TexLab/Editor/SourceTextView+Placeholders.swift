//
//  SourceTextView+Placeholders.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// Placeholders in an inserted snippet: the empty caption of a figure, the name of its
/// label, the second half of a fraction. Tab moves to the next one and Shift-Tab to the
/// previous one, and each still to fill in shows as a faint insertion point. They are only
/// remembered positions — the text has nothing extra in it — and they end when the
/// insertion point leaves the snippet or Tab moves past the last one.
extension SourceTextView {
    /// Starts placeholders at `stops`, ordered in the text, for the snippet in `span`.
    func beginPlaceholders(_ stops: [Int], in span: NSRange) {
        let ordered = Array(Set(stops)).sorted()
        guard ordered.count > 1 else {
            endPlaceholders()
            return
        }
        placeholderStops = ordered
        placeholderSpan = span
        needsDisplay = true
    }

    func endPlaceholders() {
        guard placeholderSpan != nil else { return }
        placeholderStops = []
        placeholderSpan = nil
        needsDisplay = true
    }

    /// Moves to the next or previous placeholder. Returns false when the key should do what
    /// it usually does instead.
    func moveToPlaceholder(forward: Bool) -> Bool {
        guard placeholderSpan != nil else { return false }
        let selection = selectedRange()
        guard isInsidePlaceholderSpan(selection) else {
            endPlaceholders()
            return false
        }
        let target = forward
            ? placeholderStops.first(where: { $0 > NSMaxRange(selection) })
            : placeholderStops.last(where: { $0 < selection.location })
        guard let target else {
            if forward {
                endPlaceholders()
                return false
            }
            NSSound.beep()
            return true
        }
        let leavesSnippet = forward && target == placeholderStops.last
        setSelectedRange(NSRange(location: target, length: 0))
        scrollRangeToVisible(NSRange(location: target, length: 0))
        if leavesSnippet {
            endPlaceholders()
        }
        return true
    }

    /// Ends the placeholders once the selection is outside the snippet.
    func placeholdersSelectionDidChange() {
        guard placeholderSpan != nil else { return }
        if isInsidePlaceholderSpan(selectedRange()) {
            // The faint insertion point moves from the placeholder being filled in.
            needsDisplay = true
        } else {
            endPlaceholders()
        }
    }

    private func isInsidePlaceholderSpan(_ selection: NSRange) -> Bool {
        guard let span = placeholderSpan else { return false }
        return selection.location >= span.location && NSMaxRange(selection) <= NSMaxRange(span)
    }

    /// Keeps the placeholders in step with an edit, while the text storage processes it.
    /// Text typed at a placeholder goes before it, so it stays just after what was typed.
    func placeholdersTextWillChange(editedRange: NSRange, changeInLength delta: Int) {
        guard let span = placeholderSpan else { return }
        let start = editedRange.location
        let newEnd = NSMaxRange(editedRange)
        let oldEnd = newEnd - delta

        func mapped(_ position: Int) -> Int {
            if position < start {
                return position
            }
            if position <= oldEnd {
                return newEnd
            }
            return position + delta
        }
        // The snippet's start stays before text typed there, so the snippet takes it in.
        let spanStart = span.location <= start ? span.location : span.location < oldEnd ? start : span.location + delta
        let spanEnd = max(mapped(NSMaxRange(span)), spanStart)
        let stops = Array(Set(placeholderStops.map(mapped))).sorted()
        guard stops.count > 1 else {
            endPlaceholders()
            return
        }
        placeholderStops = stops
        placeholderSpan = NSRange(location: spanStart, length: spanEnd - spanStart)
        needsDisplay = true
    }

    /// Draws a faint insertion point at each placeholder still to fill in, apart from the
    /// end of the snippet and the one being filled in.
    func drawPlaceholders(in rect: NSRect) {
        guard placeholderSpan != nil, let layoutManager, let storage = textStorage else { return }
        let selection = selectedRange()
        let font = highlighter.theme.font
        let origin = textContainerOrigin
        NSColor.controlAccentColor.withAlphaComponent(0.55).setFill()
        for stop in placeholderStops.dropLast() where stop < storage.length {
            if selection.length == 0 && stop == selection.location {
                continue
            }
            let glyph = layoutManager.glyphIndexForCharacter(at: stop)
            guard glyph < layoutManager.numberOfGlyphs else { continue }
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            // The glyph's location is its baseline, within its line fragment.
            let location = layoutManager.location(forGlyphAt: glyph)
            let baseline = origin.y + lineRect.minY + location.y
            let marker = NSRect(
                x: origin.x + lineRect.minX + location.x - 1,
                y: baseline - font.ascender,
                width: 2,
                height: font.ascender - font.descender
            )
            guard marker.intersects(rect) else { continue }
            NSBezierPath(roundedRect: marker, xRadius: 1, yRadius: 1).fill()
        }
    }
}
