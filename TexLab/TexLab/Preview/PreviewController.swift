//
//  PreviewController.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import PDFKit
import SwiftUI

/// The interface menu commands and the editor use to work with a window's PDF preview.
final class PreviewController {
    private(set) weak var pdfView: SyncPDFView?
    /// A location to reveal once the preview is on screen.
    private var pendingLocation: SyncTeXLocation?

    func attach(_ pdfView: SyncPDFView) {
        self.pdfView = pdfView
        revealPendingLocation()
    }

    /// Call after the preview shows a new document.
    func documentDidChange() {
        revealPendingLocation()
    }

    /// Scrolls to and highlights `location`, as soon as the preview can show it.
    func reveal(_ location: SyncTeXLocation) {
        pendingLocation = location
        revealPendingLocation()
    }

    private func revealPendingLocation() {
        guard let location = pendingLocation, let pdfView, pdfView.document != nil else { return }
        pendingLocation = nil
        // Let a newly shown preview finish its layout first.
        DispatchQueue.main.async { [weak pdfView] in
            pdfView?.reveal(location)
        }
    }

    // MARK: - Zoom

    func zoomIn() {
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.zoomOut(nil)
    }

    func zoomToActualSize() {
        guard let pdfView else { return }
        pdfView.autoScales = false
        pdfView.scaleFactor = 1
    }

    func zoomToFit() {
        pdfView?.autoScales = true
    }

    // MARK: - Layout

    func setShowsTwoPages(_ showsTwoPages: Bool) {
        pdfView?.displayMode = showsTwoPages ? .twoUpContinuous : .singlePageContinuous
        pdfView?.autoScales = true
    }

    // MARK: - Printing

    /// Prints the PDF, attached to `window` as a sheet when there is one.
    static func print(_ document: PDFDocument, jobTitle: String, window: NSWindow?) {
        guard let operation = document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: true) else {
            NSSound.beep()
            return
        }
        operation.jobTitle = jobTitle
        if let window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}

/// Hosts the PDF preview in SwiftUI.
struct PDFPreview: NSViewRepresentable {
    var document: PDFDocument
    var session: DocumentSession
    var showsTwoPages: Bool

    func makeNSView(context: Context) -> SyncPDFView {
        let view = SyncPDFView()
        view.autoScales = true
        view.displayMode = showsTwoPages ? .twoUpContinuous : .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .underPageBackgroundColor
        view.setAccessibilityLabel(String(localized: "PDF preview"))
        view.inverseSearchHandler = { [weak session] pageIndex, point in
            session?.revealSource(pageIndex: pageIndex, point: point)
        }
        view.document = document
        session.preview.attach(view)
        return view
    }

    func updateNSView(_ view: SyncPDFView, context: Context) {
        let mode: PDFDisplayMode = showsTwoPages ? .twoUpContinuous : .singlePageContinuous
        if view.displayMode != mode {
            view.displayMode = mode
            view.autoScales = true
        }
        if view.document !== document {
            view.showDocument(document)
            session.preview.documentDidChange()
        }
    }
}
