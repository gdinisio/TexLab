//
//  PaneSplitView.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import SwiftUI

/// The editor beside the preview, in a native split view.
///
/// SwiftUI's `HSplitView` only responds on its one-point divider, which the text and PDF
/// views beside it compete with for the pointer. This uses `NSSplitView` with the thin
/// divider Apple's apps use and a grab area a few points wider on each side, like Xcode,
/// and remembers where you put the divider.
struct PaneSplitView<Leading: View, Trailing: View>: NSViewRepresentable {
    var showsTrailing: Bool
    var autosaveName: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = WideDividerSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let coordinator = context.coordinator
        let leadingHost = NSHostingView(rootView: AnyView(leading()))
        let trailingHost = NSHostingView(rootView: AnyView(trailing()))
        for host in [leadingHost, trailingHost] {
            host.sizingOptions = []
        }
        coordinator.splitView = splitView
        coordinator.leadingHost = leadingHost
        coordinator.trailingHost = trailingHost
        splitView.addArrangedSubview(leadingHost)
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)
        if showsTrailing {
            splitView.addArrangedSubview(trailingHost)
            splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        }
        splitView.autosaveName = autosaveName
        // Without a remembered position, give the editor a little more than half.
        let key = "NSSplitView Subview Frames \(autosaveName)"
        if showsTrailing, UserDefaults.standard.object(forKey: key) == nil {
            coordinator.placeDivider(atFraction: 0.52)
        }
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        let coordinator = context.coordinator
        // Replacing the panes' content is deferred until after the current layout pass:
        // SwiftUI can update this view while laying out the window, and changing a hosting
        // view's content then would ask for layout again, over and over.
        coordinator.pendingContent = (AnyView(leading()), AnyView(trailing()))
        coordinator.scheduleContentUpdate()
        coordinator.setTrailingVisible(showsTrailing)
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        static var minimumLeadingWidth: CGFloat { 320 }
        static var minimumTrailingWidth: CGFloat { 280 }

        weak var splitView: NSSplitView?
        var leadingHost: NSHostingView<AnyView>?
        var trailingHost: NSHostingView<AnyView>?
        var pendingContent: (AnyView, AnyView)?
        private var isContentUpdateScheduled = false
        /// The preview's width when it was hidden, to restore it.
        private var trailingWidth: CGFloat?

        func scheduleContentUpdate() {
            guard !isContentUpdateScheduled else { return }
            isContentUpdateScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isContentUpdateScheduled = false
                guard let content = self.pendingContent else { return }
                self.pendingContent = nil
                self.leadingHost?.rootView = content.0
                self.trailingHost?.rootView = content.1
            }
        }

        /// Shows or hides the preview. A hidden preview is taken out of the split view, so
        /// no divider is left at the edge of the editor.
        func setTrailingVisible(_ visible: Bool) {
            guard let splitView, let trailingHost else { return }
            let isShown = splitView.arrangedSubviews.contains(trailingHost)
            guard visible != isShown else { return }
            if visible {
                splitView.addArrangedSubview(trailingHost)
                splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
                let width = trailingWidth
                DispatchQueue.main.async { [weak self, weak splitView] in
                    guard let self, let splitView, splitView.bounds.width > 0 else { return }
                    let trailing = width ?? splitView.bounds.width * 0.48
                    let position = splitView.bounds.width - trailing - splitView.dividerThickness
                    splitView.setPosition(max(position, Self.minimumLeadingWidth), ofDividerAt: 0)
                    self.refreshCursorRects()
                }
            } else {
                trailingWidth = trailingHost.frame.width > 0 ? trailingHost.frame.width : nil
                splitView.removeArrangedSubview(trailingHost)
                trailingHost.removeFromSuperview()
                refreshCursorRects()
            }
        }

        func placeDivider(atFraction fraction: CGFloat) {
            DispatchQueue.main.async { [weak splitView] in
                guard let splitView, splitView.bounds.width > 0, splitView.arrangedSubviews.count > 1 else { return }
                splitView.setPosition((splitView.bounds.width * fraction).rounded(), ofDividerAt: 0)
            }
        }

        private func refreshCursorRects() {
            DispatchQueue.main.async { [weak splitView] in
                guard let splitView else { return }
                splitView.window?.invalidateCursorRects(for: splitView)
            }
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            max(proposedMinimumPosition, Self.minimumLeadingWidth)
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            min(proposedMaximumPosition, splitView.bounds.width - Self.minimumTrailingWidth - splitView.dividerThickness)
        }

        /// A grab area 4 points either side of the visible one-point divider.
        func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
            drawnRect.insetBy(dx: -4, dy: 0)
        }

        func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
            // When the window resizes, the editor takes up the change.
            view === leadingHost
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            refreshCursorRects()
        }
    }
}

/// A split view whose divider wins the pointer over the views beside it, so the resize
/// cursor appears reliably across the whole grab area.
final class WideDividerSplitView: NSSplitView {
    private var dividerRects: [NSRect] {
        guard let delegate, arrangedSubviews.count > 1 else { return [] }
        var rects: [NSRect] = []
        for index in 0..<(arrangedSubviews.count - 1) {
            let leading = arrangedSubviews[index].frame
            let drawn = NSRect(x: leading.maxX, y: 0, width: dividerThickness, height: bounds.height)
            let effective = delegate.splitView?(self, effectiveRect: drawn, forDrawnRect: drawn, ofDividerAt: index) ?? drawn
            rects.append(effective)
        }
        return rects
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if dividerRects.contains(where: { $0.contains(local) }) {
            return self
        }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for rect in dividerRects {
            addCursorRect(rect, cursor: .resizeLeftRight)
        }
    }
}
