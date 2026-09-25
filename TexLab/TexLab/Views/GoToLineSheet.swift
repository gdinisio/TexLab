//
//  GoToLineSheet.swift
//  TexLab
//

import AppKit
import SwiftUI

/// Edit ▸ Go to Line…: jumps to a line number, optionally with a column (`12:5`).
struct GoToLineSheet: View {
    var session: DocumentSession

    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @FocusState private var isFieldFocused: Bool

    private var lineCount: Int {
        session.editor.lineCount
    }

    /// The requested line and column, if the line exists.
    private var target: (line: Int, column: Int)? {
        let parts = input.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first, let line = Int(first), (1...max(lineCount, 1)).contains(line) else {
            return nil
        }
        let column = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
        return (line, max(column, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Line")
                .font(.headline)
            TextField("Line", text: $input, prompt: Text("1–\(lineCount)"))
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit(go)
            Text("The document has \(lineCount) lines.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Go", action: go)
                    .keyboardShortcut(.defaultAction)
                    .disabled(target == nil)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            input = String(session.caretLine)
            isFieldFocused = true
        }
    }

    private func go() {
        guard let target else {
            NSSound.beep()
            return
        }
        dismiss()
        session.editor.revealLine(target.line, column: target.column)
    }
}
