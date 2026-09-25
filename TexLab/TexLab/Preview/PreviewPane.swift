//
//  PreviewPane.swift
//  TexLab
//

import SwiftUI

/// The preview column: the typeset PDF, or an explanation of why there isn't one yet and
/// what to do about it.
struct PreviewPane: View {
    var session: DocumentSession

    @AppStorage(SettingsKey.previewShowsTwoPages) private var showsTwoPages = AppSettings.previewShowsTwoPages

    var body: some View {
        if let document = session.pdfDocument {
            PDFPreview(document: document, session: session, showsTwoPages: showsTwoPages)
        } else {
            placeholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch session.status {
        case .running:
            ProgressView("Typesetting…")
                .controlSize(.small)
        case .texNotFound(let sandboxed):
            ContentUnavailableView {
                Label("TeX Not Found", systemImage: "exclamationmark.triangle")
            } description: {
                if sandboxed {
                    Text("TexLab is running in App Sandbox, which blocks access to your TeX installation. Remove the App Sandbox capability from the TexLab target, as described in the README.")
                } else {
                    Text("TexLab typesets with the TeX distribution installed on your Mac. Install MacTeX, or choose where TeX is installed in Settings.")
                }
            } actions: {
                if !sandboxed {
                    Link("Get MacTeX", destination: URL(string: "https://tug.org/mactex/")!)
                    SettingsLink {
                        Text("Open Settings…")
                    }
                }
            }
        case .couldNotStart(let message):
            ContentUnavailableView {
                Label("Couldn’t Typeset", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                SettingsLink {
                    Text("Open Settings…")
                }
            }
        case .failed, .timedOut:
            ContentUnavailableView {
                Label("No Preview", systemImage: "xmark.octagon")
            } description: {
                Text("TeX couldn’t produce a PDF. Fix the errors listed in Issues, then typeset again.")
            } actions: {
                Button("Show Log") {
                    session.isShowingLog = true
                }
            }
        case .idle, .cancelled, .succeeded:
            ContentUnavailableView {
                Label("No Preview Yet", systemImage: "doc.richtext")
            } description: {
                Text("Typeset the document to see it here.")
            } actions: {
                Button("Typeset") {
                    session.typeset()
                }
            }
        }
    }
}
