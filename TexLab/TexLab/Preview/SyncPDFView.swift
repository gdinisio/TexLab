//
//  SyncPDFView.swift
//  TexLab
//

import AppKit
import PDFKit

/// The PDF preview.
///
/// A `PDFView` that keeps its place when a new version of the document arrives, jumps to
/// the source on Command-click (or Show in Source in the context menu), and highlights the
/// text produced by a source line.
final class SyncPDFView: PDFView {
    /// Called with a 0-based page index and a point in SyncTeX coordinates (PDF points
    /// from the page's top-left corner).
    var inverseSearchHandler: ((Int, CGPoint) -> Void)?

    private var contextMenuLocation: (pageIndex: Int, point: CGPoint)?
    private var highlightAnnotation: (annotation: PDFAnnotation, page: PDFPage)?

    // MARK: - Updating

    /// Shows `newDocument`, keeping the scroll position and zoom so typesetting while
    /// writing doesn't make the preview jump.
    func showDocument(_ newDocument: PDFDocument?) {
        guard document !== newDocument else { return }
        guard let newDocument, document != nil, let scrollView = documentView?.enclosingScrollView else {
            document = newDocument
            return
        }
        let clipView = scrollView.contentView
        let origin = clipView.bounds.origin
        let keepsAutoScale = autoScales
        let scale = scaleFactor

        removeHighlight()
        document = newDocument
        if keepsAutoScale {
            autoScales = true
        } else {
            scaleFactor = scale
        }
        layoutDocumentView()

        let target = clipView.constrainBoundsRect(NSRect(origin: origin, size: clipView.bounds.size)).origin
        clipView.scroll(to: target)
        scrollView.reflectScrolledClipView(clipView)
    }

    // MARK: - Forward search

    /// Scrolls to and highlights `location`.
    func reveal(_ location: SyncTeXLocation) {
        guard let document, let page = document.page(at: location.pageIndex) else { return }
        let bounds = page.bounds(for: .mediaBox)
        let rect = CGRect(
            x: bounds.minX + location.rect.minX,
            y: bounds.maxY - location.rect.maxY,
            width: max(location.rect.width, 1),
            height: max(location.rect.height, 1)
        )
        go(to: rect.insetBy(dx: 0, dy: -60), on: page)

        if let selection = page.selection(for: rect.insetBy(dx: -0.5, dy: -0.5)),
           let string = selection.string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setCurrentSelection(selection, animate: true)
        } else {
            flashHighlight(rect, on: page)
        }
    }

    /// Outlines a region without text, such as a figure, for a moment.
    private func flashHighlight(_ rect: CGRect, on page: PDFPage) {
        removeHighlight()
        let annotation = PDFAnnotation(bounds: rect.insetBy(dx: -3, dy: -3), forType: .square, withProperties: nil)
        annotation.color = NSColor.controlAccentColor
        annotation.interiorColor = NSColor.controlAccentColor.withAlphaComponent(0.12)
        let border = PDFBorder()
        border.lineWidth = 2
        annotation.border = border
        page.addAnnotation(annotation)
        highlightAnnotation = (annotation, page)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.highlightAnnotation?.annotation === annotation else { return }
            self.removeHighlight()
        }
    }

    private func removeHighlight() {
        if let highlightAnnotation {
            highlightAnnotation.page.removeAnnotation(highlightAnnotation.annotation)
        }
        highlightAnnotation = nil
    }

    // MARK: - Inverse search

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, let location = syncLocation(for: event), let inverseSearchHandler {
            inverseSearchHandler(location.pageIndex, location.point)
            return
        }
        super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard inverseSearchHandler != nil, let location = syncLocation(for: event) else { return menu }
        contextMenuLocation = location
        let item = NSMenuItem(title: String(localized: "Show in Source"), action: #selector(showInSource(_:)), keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: nil)
        menu.insertItem(item, at: 0)
        menu.insertItem(.separator(), at: 1)
        return menu
    }

    @objc private func showInSource(_ sender: Any?) {
        guard let location = contextMenuLocation else { return }
        contextMenuLocation = nil
        inverseSearchHandler?(location.pageIndex, location.point)
    }

    /// The page and SyncTeX position under the mouse.
    private func syncLocation(for event: NSEvent) -> (pageIndex: Int, point: CGPoint)? {
        let viewPoint = convert(event.locationInWindow, from: nil)
        guard let document, let page = page(for: viewPoint, nearest: true) else { return nil }
        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else { return nil }
        let pagePoint = convert(viewPoint, to: page)
        let bounds = page.bounds(for: .mediaBox)
        return (pageIndex, CGPoint(x: pagePoint.x - bounds.minX, y: bounds.maxY - pagePoint.y))
    }
}
