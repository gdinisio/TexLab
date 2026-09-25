//
//  StatusBar.swift
//  TexLab
//

import SwiftUI

/// A Finder-style status bar under the editor showing where the insertion point is and
/// how long the document is.
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
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(height: 24)
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
}
