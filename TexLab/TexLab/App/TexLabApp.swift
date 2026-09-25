//
//  TexLabApp.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI

@main
struct TexLabApp: App {
    init() {
        AppSettings.registerDefaults()
    }

    var body: some Scene {
        DocumentGroup(newDocument: TexLabDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                NewFromTemplateMenu()
            }
        }
    }
}

/// File ▸ New from Template, listing every built-in template.
struct NewFromTemplateMenu: View {
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Menu("New from Template") {
            ForEach(DocumentTemplate.allCases) { template in
                Button(template.title, systemImage: template.systemImage) {
                    newDocument(TexLabDocument(text: template.text))
                }
            }
        }
    }
}
