//
//  LogView.swift
//  TexLab
//

import AppKit
import SwiftUI

/// The full TeX log and tool output, for problems the Issues list can't explain.
struct LogView: View {
    var session: DocumentSession

    @Environment(\.dismiss) private var dismiss
    @State private var showsConsole = false

    private var text: String {
        showsConsole ? session.console : session.log
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Output", selection: $showsConsole) {
                Text("TeX Log").tag(false)
                Text("Console Output").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(12)

            Divider()

            if text.isEmpty {
                ContentUnavailableView("No Output", systemImage: "doc.plaintext", description: Text("Typeset the document to see TeX’s output here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ReadOnlyTextView(text: text)
            }

            Divider()

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .disabled(text.isEmpty)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 420, idealHeight: 560)
    }
}

/// A scrollable, selectable, searchable plain-text view for long output.
struct ReadOnlyTextView: NSViewRepresentable {
    var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        if let textView = scrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.isSelectable = true
            textView.usesFindBar = true
            textView.isIncrementalSearchingEnabled = true
            textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            textView.textContainerInset = NSSize(width: 8, height: 8)
            textView.string = text
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
        textView.scrollToEndOfDocument(nil)
    }
}
