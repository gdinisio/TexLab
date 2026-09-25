//
//  StatusBar.swift
//  TexLab
//

import Foundation
import SwiftUI

/// A Finder-style status bar under the editor: where the insertion point is, how long the
/// document is, and how many issues the latest typesetting found.
struct StatusBar: View {
    var session: DocumentSession

    var body: some View {
        HStack(spacing: 12) {
            Text(positionDescription)
                .monospacedDigit()
                .accessibilityLabel(accessibilityPosition)

            Spacer(minLength: 12)

            Text("^[\(session.wordCount) word](inflect: true)")
                .monospacedDigit()

            if session.errorCount > 0 || session.warningCount > 0 {
                Button {
                    session.showIssues()
                } label: {
                    HStack(spacing: 8) {
                        if session.errorCount > 0 {
                            Label("\(session.errorCount)", systemImage: "xmark.octagon.fill")
                        }
                        if session.warningCount > 0 {
                            Label("\(session.warningCount)", systemImage: "exclamationmark.triangle.fill")
                        }
                    }
                    .symbolRenderingMode(.multicolor)
                    .monospacedDigit()
                }
                .buttonStyle(.borderless)
                .help("Show issues")
                .accessibilityLabel(issuesAccessibilityLabel)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var positionDescription: String {
        if session.selectionLength > 0 {
            return String(localized: "Line \(session.caretLine), Column \(session.caretColumn) · \(session.selectionLength) selected")
        }
        return String(localized: "Line \(session.caretLine), Column \(session.caretColumn)")
    }

    private var accessibilityPosition: String {
        String(localized: "Insertion point at line \(session.caretLine), column \(session.caretColumn)")
    }

    private var issuesAccessibilityLabel: String {
        String(localized: "\(session.errorCount) errors and \(session.warningCount) warnings. Show issues.")
    }
}
