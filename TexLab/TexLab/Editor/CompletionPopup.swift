//
//  CompletionPopup.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// The completion list under the insertion point, like Xcode's: a small window that floats
/// above the editor without taking the keyboard, which stays with the text. The editor
/// moves the selection, accepts and dismisses; a click on an item accepts it.
final class CompletionPopup {
    private let model = CompletionListModel()
    private var panel: CompletionPanel?

    static let width: CGFloat = 460
    private static let rowHeight: CGFloat = 24
    private static let visibleRows = 9
    private static let footerHeight: CGFloat = 38

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    var items: [CompletionItem] {
        model.items
    }

    var selectedItem: CompletionItem? {
        model.items.indices.contains(model.selectedIndex) ? model.items[model.selectedIndex] : nil
    }

    /// Called with an item clicked in the list.
    var onAccept: ((CompletionItem) -> Void)? {
        get { model.onAccept }
        set { model.onAccept = newValue }
    }

    /// Shows `items` below the screen rectangle of the text being completed, keeping the
    /// selected item if it's still there.
    func show(_ items: [CompletionItem], below textRect: NSRect, in window: NSWindow) {
        let previous = selectedItem?.id
        model.items = items
        model.selectedIndex = previous.flatMap { id in items.firstIndex { $0.id == id } } ?? 0

        let panel = self.panel ?? makePanel()
        let rows = CGFloat(min(items.count, Self.visibleRows))
        let hasFooter = items.contains { $0.detail != nil }
        let size = NSSize(width: Self.width, height: rows * Self.rowHeight + 8 + (hasFooter ? Self.footerHeight : 0))
        model.showsFooter = hasFooter

        // The names line up with the typed text; above it if there's no room below.
        var origin = NSPoint(x: textRect.minX - 34, y: textRect.minY - size.height - 3)
        if let screen = (window.screen ?? NSScreen.main)?.visibleFrame {
            if origin.y < screen.minY {
                origin.y = textRect.maxY + 3
            }
            origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - size.width - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        model.items = []
    }

    /// Moves the selection, stopping at the ends of the list.
    func moveSelection(by step: Int) {
        guard !model.items.isEmpty else { return }
        model.selectedIndex = min(max(model.selectedIndex + step, 0), model.items.count - 1)
    }

    private func makePanel() -> CompletionPanel {
        let panel = CompletionPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.contentView = CompletionHostingView(rootView: CompletionListView(model: model))
        self.panel = panel
        return panel
    }
}

/// What the list shows, observed by its view.
@Observable
final class CompletionListModel {
    var items: [CompletionItem] = []
    var selectedIndex = 0
    var showsFooter = false
    @ObservationIgnored var onAccept: ((CompletionItem) -> Void)?
}

/// A window that floats above the editor without becoming key, so typing continues in
/// the text.
final class CompletionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes the first click, so an item can be chosen without the list's window activating.
final class CompletionHostingView: NSHostingView<CompletionListView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

struct CompletionListView: View {
    var model: CompletionListModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.items.indices, id: \.self) { index in
                            CompletionRow(item: model.items[index], isSelected: index == model.selectedIndex)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.onAccept?(model.items[index])
                                }
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.automatic)
                .onChange(of: model.selectedIndex) { _, newValue in
                    proxy.scrollTo(newValue)
                }
            }
            if model.showsFooter {
                Divider()
                footer
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator)
        }
    }

    /// More about the selected item: a citation's authors and title, a label's caption.
    private var footer: some View {
        let item = model.items.indices.contains(model.selectedIndex) ? model.items[model.selectedIndex] : nil
        return HStack(spacing: 6) {
            Text(verbatim: item?.detail ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let source = item?.source {
                Text(verbatim: source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 37)
    }
}

private struct CompletionRow: View {
    var item: CompletionItem
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(tint))
                .frame(width: 18)
            Text(verbatim: item.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .layoutPriority(1)
            if let detail = item.detail {
                Text(verbatim: detail)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.85)) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 4)
            if let source = item.source {
                Text(verbatim: source)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.75)) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Each kind in its own colour, like Xcode's symbol icons.
    private var tint: Color {
        switch item.kind {
        case .command: .purple
        case .environment: .blue
        case .label: .green
        case .citation: .orange
        case .file: .teal
        case .package, .documentClass: .brown
        }
    }
}
