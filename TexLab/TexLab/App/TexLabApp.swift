//
//  TexLabApp.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import Foundation
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
            TexLabCommands()
        }

        Settings {
            SettingsView()
        }
    }
}
