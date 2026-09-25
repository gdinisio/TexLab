//
//  SourceTextView+Presentation.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// Live preview in the editor: formulas are shown rendered until the insertion point
/// enters them, and environments can be collapsed. The text is never changed; only its
/// layout is, through `PresentationLayoutManager`.
extension SourceTextView {
    var presentationLayoutManager: PresentationLayoutManager? {
        layoutManager as? PresentationLayoutManager
    }

    // MARK: - Updating

    /// Recomputes what is shown rendered or collapsed. Cheap when nothing changed.
    func updatePresentation() {
        guard let manager = presentationLayoutManager, let storage = textStorage else { return }
        if !storage.editedMask.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.updatePresentation()
            }
            return
        }

        let length = storage.length
        let font = highlighter.theme.font
        let lineHeight = manager.defaultLineHeight(for: font) * (highlighter.theme.paragraphStyle.lineHeightMultiple > 0 ? highlighter.theme.paragraphStyle.lineHeightMultiple : 1)
        var replacements: [Replacement] = []

        for fold in folds where NSMaxRange(fold.range) <= length {
            let thumbnail = fold.imagePath.flatMap { thumbnail(for: $0) }
            let size = FoldChip.size(for: fold, thumbnail: thumbnail, font: font, lineHeight: lineHeight)
            // Centre the chip on the text of the line.
            let textMiddle = (font.ascender + font.descender) / 2
            let descent = max(size.height / 2 - textMiddle, -font.descender)
            replacements.append(Replacement(
                range: fold.range,
                kind: .fold(fold, thumbnail: thumbnail),
                size: size,
                descent: descent,
                fillsLine: false,
                identity: "fold:\(fold.summary):\(thumbnail != nil):\(font.pointSize)"
            ))
        }

        let revealedSpans = formattedSpansTouchingSelection()
        revealedFormatting = revealedSpans
        if configuration.stylesFormatting {
            for span in formattedSpans where NSMaxRange(span.range) <= length && !revealedSpans.contains(span.range.location) {
                for markup in [span.openingRange, span.closingRange] where markup.length > 0 {
                    replacements.append(Replacement(range: markup, kind: .hidden, size: .zero, descent: 0, fillsLine: false, identity: "hidden"))
                }
            }
        }

        let revealed = mathRegionsTouchingSelection()
        revealedMath = revealed
        if configuration.rendersMath {
            // Formulas are typeset at 10 pt; scale them to the editor's text.
            let scale = font.pointSize / 10
            for region in mathRegions where NSMaxRange(region.range) <= length && !revealed.contains(region.range.location) {
                guard let math = renderedMath[region.key],
                      !folds.contains(where: { NSIntersectionRange($0.range, region.range).length > 0 }) else { continue }
                replacements.append(Replacement(
                    range: region.range,
                    kind: .math(math, region: region),
                    size: CGSize(width: ceil(math.size.width * scale), height: ceil(math.size.height * scale)),
                    descent: math.depth * scale,
                    fillsLine: region.standsAlone,
                    identity: "math:\(region.key):\(scale)"
                ))
            }
        }

        manager.setReplacements(replacements)
        lineNumberRuler?.needsDisplay = true
    }

    /// Reveals the source of a formula when the insertion point moves into it, and expands
    /// a collapsed environment when the selection moves inside it.
    func selectionDidChangeForPresentation() {
        let selection = selectedRange()
        if let fold = folds.first(where: { contains($0.range, strictly: selection.location) || contains($0.range, strictly: NSMaxRange(selection)) }) {
            DispatchQueue.main.async { [weak self] in
                self?.unfold(fold)
            }
            return
        }
        let mathChanged = configuration.rendersMath && !mathRegions.isEmpty && mathRegionsTouchingSelection() != revealedMath
        let formattingChanged = configuration.stylesFormatting && !formattedSpans.isEmpty && formattedSpansTouchingSelection() != revealedFormatting
        if mathChanged || formattingChanged {
            updatePresentation()
        }
    }

    /// Styled spans the selection touches, which show their markup for editing.
    private func formattedSpansTouchingSelection() -> Set<Int> {
        let selection = selectedRange()
        var touching: Set<Int> = []
        for span in formattedSpans where selection.location <= NSMaxRange(span.range) && NSMaxRange(selection) >= span.range.location {
            touching.insert(span.range.location)
        }
        return touching
    }

    private func contains(_ range: NSRange, strictly location: Int) -> Bool {
        location > range.location && location < NSMaxRange(range)
    }

    /// Formulas the selection touches, including one the insertion point sits just beside,
    /// so a formula being typed stays visible as source.
    private func mathRegionsTouchingSelection() -> Set<Int> {
        let selection = selectedRange()
        var touching: Set<Int> = []
        for region in mathRegions where selection.location <= NSMaxRange(region.range) && NSMaxRange(selection) >= region.range.location {
            touching.insert(region.range.location)
        }
        return touching
    }

    /// Keeps regions and folds in step with an edit, while the text storage processes it.
    func presentationTextWillChange(editedRange: NSRange, changeInLength delta: Int) {
        presentationLayoutManager?.textWillChange(editedRange: editedRange, changeInLength: delta)
        let oldEnd = NSMaxRange(editedRange) - delta

        func survives(_ range: NSRange) -> Int? {
            if NSMaxRange(range) <= editedRange.location {
                return 0
            }
            if range.location >= oldEnd {
                return delta
            }
            return nil
        }
        // Display math drawn alone on its line stops being alone when that line is edited.
        let editedLines = textStorage.map { storage in
            storage.mutableString.lineRange(for: NSRange(location: min(editedRange.location, storage.length), length: min(editedRange.length, storage.length - min(editedRange.location, storage.length))))
        }
        mathRegions = mathRegions.compactMap { region in
            guard let shift = survives(region.range) else { return nil }
            let shifted = region.shifted(by: shift)
            if shifted.standsAlone, let editedLines, NSIntersectionRange(editedLines, shifted.range).length > 0 || NSMaxRange(shifted.range) == editedLines.location {
                return nil
            }
            return shifted
        }
        formattedSpans = formattedSpans.compactMap { span in survives(span.range).map { span.shifted(by: $0) } }
        foldableRegions = foldableRegions.compactMap { region in survives(region.range).map { region.shifted(by: $0) } }
        folds = folds.compactMap { region in survives(region.range).map { region.shifted(by: $0) } }
    }

    // MARK: - Content

    /// Updates the formulas found in the source.
    func setMathRegions(_ regions: [MathRegion]) {
        guard regions != mathRegions else { return }
        mathRegions = regions
        updatePresentation()
    }

    /// Updates the styled spans found in the source.
    func setFormattedSpans(_ spans: [FormattedSpan]) {
        guard spans != formattedSpans else { return }
        formattedSpans = spans
        updatePresentation()
    }

    /// Updates the rendered formulas available to draw.
    func setRenderedMath(_ images: [String: MathImage]) {
        renderedMath = images
        updatePresentation()
    }

    func setFoldableRegions(_ regions: [FoldableRegion]) {
        foldableRegions = regions
        lineNumberRuler?.needsDisplay = true
    }

    private func thumbnail(for path: String) -> NSImage? {
        if let cached = thumbnails[path] {
            return cached
        }
        guard !missingThumbnails.contains(path), let url = resolveImageURL?(path), let image = NSImage(contentsOf: url) else {
            missingThumbnails.insert(path)
            return nil
        }
        thumbnails[path] = image
        return image
    }

    // MARK: - Folding

    /// The innermost foldable environment containing `location`.
    func foldableRegion(containing location: Int) -> FoldableRegion? {
        foldableRegions
            .filter { NSLocationInRange(location, $0.range) || location == NSMaxRange($0.range) }
            .min { $0.range.length < $1.range.length }
    }

    func fold(_ region: FoldableRegion) {
        guard !folds.contains(where: { NSEqualRanges(NSUnionRange($0.range, region.range), $0.range) }) else { return }
        // A fold replaces any folds inside it.
        folds.removeAll { NSEqualRanges(NSUnionRange($0.range, region.range), region.range) }
        folds.append(region)
        folds.sort { $0.range.location < $1.range.location }
        let selection = selectedRange()
        if contains(region.range, strictly: selection.location) || contains(region.range, strictly: NSMaxRange(selection)) {
            setSelectedRange(NSRange(location: region.range.location, length: 0))
        }
        updatePresentation()
    }

    func unfold(_ region: FoldableRegion) {
        folds.removeAll { NSEqualRanges($0.range, region.range) }
        updatePresentation()
    }

    func isFolded(_ region: FoldableRegion) -> Bool {
        folds.contains { NSEqualRanges($0.range, region.range) }
    }

    func toggleFold(_ region: FoldableRegion) {
        if isFolded(region) {
            unfold(region)
        } else {
            fold(region)
        }
    }

    /// Folds the environment containing the insertion point.
    func foldAtSelection() {
        guard let region = foldableRegion(containing: selectedRange().location) else {
            NSSound.beep()
            return
        }
        fold(region)
    }

    /// Unfolds the fold at or around the insertion point.
    func unfoldAtSelection() {
        let location = selectedRange().location
        guard let fold = folds.first(where: { NSLocationInRange(location, $0.range) || location == NSMaxRange($0.range) }) else {
            NSSound.beep()
            return
        }
        unfold(fold)
    }

    /// Collapses every figure and table, outermost first.
    func foldFloats() {
        for region in foldableRegions where region.isFloat {
            fold(region)
        }
    }

    /// Collapses the preamble, leaving the document body in view.
    func foldPreamble(beepsIfMissing: Bool = true) {
        guard let preamble = foldableRegions.first(where: { $0.kind == .preamble }) else {
            if beepsIfMissing {
                NSSound.beep()
            }
            return
        }
        fold(preamble)
    }

    /// Collapses every section's body, leaving the headings as an outline.
    func foldSections() {
        let sections = foldableRegions.filter(\.isSection)
        guard !sections.isEmpty else {
            NSSound.beep()
            return
        }
        // Outermost first, so each fold replaces the ones inside it.
        for region in sections.sorted(by: { $0.range.length > $1.range.length }) {
            fold(region)
        }
    }

    func unfoldAll() {
        guard !folds.isEmpty else { return }
        folds.removeAll()
        updatePresentation()
    }
}
