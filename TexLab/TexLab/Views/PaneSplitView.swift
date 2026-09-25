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

        let leadingHost = NSHostingView(rootView: AnyView(leading()))
        let trailingHost = NSHostingView(rootView: AnyView(trailing()))
        for host in [leadingHost, trailingHost] {
            host.sizingOptions = []
        }
        context.coordinator.leadingHost = leadingHost
        context.coordinator.trailingHost = trailingHost
        splitView.addArrangedSubview(leadingHost)
        splitView.addArrangedSubview(trailingHost)
        splitView.setHoldingPriority(.defaultLow - 1, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)
        splitView.autosaveName = autosaveName
        trailingHost.isHidden = !showsTrailing
        // Without a remembered position, give the editor a little more than half.
        let key = "NSSplitView Subview Frames \(autosaveName)"
        if UserDefaults.standard.object(forKey: key) == nil {
            DispatchQueue.main.async { [weak splitView] in
                guard let splitView, splitView.bounds.width > 0, !trailingHost.isHidden else { return }
                splitView.setPosition((splitView.bounds.width * 0.52).rounded(), ofDividerAt: 0)
            }
        }
        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        let coordinator = context.coordinator
        coordinator.leadingHost?.rootView = AnyView(leading())
        coordinator.trailingHost?.rootView = AnyView(trailing())
        guard let trailingHost = coordinator.trailingHost, trailingHost.isHidden == showsTrailing else { return }
        if showsTrailing {
            trailingHost.isHidden = false
            // Restore the width it had, or split the window evenly the first time.
            let width = coordinator.trailingWidth ?? splitView.bounds.width / 2
            splitView.adjustSubviews()
            splitView.setPosition(max(splitView.bounds.width - width - splitView.dividerThickness, Coordinator.minimumLeadingWidth), ofDividerAt: 0)
        } else {
            coordinator.trailingWidth = trailingHost.frame.width
            trailingHost.isHidden = true
            splitView.adjustSubviews()
        }
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        static var minimumLeadingWidth: CGFloat { 320 }
        static var minimumTrailingWidth: CGFloat { 280 }

        var leadingHost: NSHostingView<AnyView>?
        var trailingHost: NSHostingView<AnyView>?
        var trailingWidth: CGFloat?

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
    }
}

/// A split view whose divider wins the pointer over the views beside it, so the resize
/// cursor appears reliably across the whole grab area.
final class WideDividerSplitView: NSSplitView {
    private var dividerRects: [NSRect] {
        guard let delegate, arrangedSubviews.count > 1 else { return [] }
        var rects: [NSRect] = []
        for index in 0..<(arrangedSubviews.count - 1) where !arrangedSubviews[index + 1].isHidden {
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

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }
}
