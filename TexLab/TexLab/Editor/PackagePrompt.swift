//
//  PackagePrompt.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// Asks whether to load the package a command just typed needs: "\mathbb needs the amssymb
/// package. Add amssymb · Not Now", on a small bar of Liquid Glass just above the line,
/// like an Xcode Fix-It. Typing carries on underneath; nothing is added without a click.
struct PackagePrompt: View {
    var command: String
    var package: String
    var add: () -> Void
    var dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("\(Text(verbatim: command).font(.body.monospaced())) needs the \(Text(verbatim: package).fontWeight(.semibold)) package.")
                .lineLimit(1)
            Button {
                add()
            } label: {
                Text("Add \(package)")
            }
            .buttonStyle(.glassProminent)
            .help("Add \\usepackage{\(package)} to the preamble")
            Button("Not Now") {
                dismiss()
            }
            .buttonStyle(.glass)
            .help("Don’t ask about this package again while the window is open")
        }
        .controlSize(.small)
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .fixedSize()
    }
}

/// The prompt in the editor: shown above the line of the command it's about, it moves
/// with the text and the scrolling, and goes once the insertion point leaves the line.
extension SourceTextView {
    func showPackagePrompt(command: String, package: String, at range: NSRange, add: @escaping () -> Void, dismiss: @escaping () -> Void) {
        let prompt = PackagePrompt(command: command, package: package, add: add, dismiss: dismiss)
        let host: NSHostingView<PackagePrompt>
        if let existing = packagePrompt as? NSHostingView<PackagePrompt> {
            host = existing
            host.rootView = prompt
        } else {
            host = NSHostingView(rootView: prompt)
            addSubview(host)
            packagePrompt = host
        }
        host.setFrameSize(host.fittingSize)
        let wasHidden = host.isHidden || packagePromptRange == nil
        packagePromptRange = range
        host.isHidden = false
        positionPackagePrompt()
        if wasHidden {
            host.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                host.animator().alphaValue = 1
            }
        }
    }

    func hidePackagePrompt() {
        packagePromptRange = nil
        packagePrompt?.isHidden = true
    }

    /// The command the prompt is about, kept in step with edits before it.
    func packagePromptTextWillChange(editedRange: NSRange, changeInLength delta: Int) {
        guard let range = packagePromptRange else { return }
        if editedRange.location >= NSMaxRange(range) {
            return
        }
        if NSMaxRange(editedRange) - delta <= range.location {
            packagePromptRange?.location += delta
        } else {
            // The command itself changed: the next check decides.
            hidePackagePrompt()
        }
    }

    /// Above the line, or below it at the top of the editor.
    func positionPackagePrompt() {
        guard let host = packagePrompt, !host.isHidden, let range = packagePromptRange,
              let layoutManager, let textContainer, let storage = textStorage, NSMaxRange(range) <= storage.length else { return }
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var line = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        line.origin.x += textContainerOrigin.x
        line.origin.y += textContainerOrigin.y
        let size = host.frame.size
        let visible = visibleRect
        let margin: CGFloat = 8
        var y = line.minY - 6 - size.height
        if y < visible.minY + 4 {
            y = line.maxY + 6
        }
        let x = min(max(line.minX - 12, visible.minX + margin), max(visible.maxX - size.width - margin, visible.minX + margin))
        host.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }
}
