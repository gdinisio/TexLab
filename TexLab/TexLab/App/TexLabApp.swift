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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(SettingsKey.showsWelcomeAtLaunch) private var showsWelcomeAtLaunch = AppSettings.showsWelcomeAtLaunch

    init() {
        AppSettings.registerDefaults()
    }

    var body: some Scene {
        Window("Welcome to TexLab", id: WelcomeWindow.id) {
            WelcomeView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(showsWelcomeAtLaunch ? .presented : .suppressed)
        .keyboardShortcut("1", modifiers: [.command, .shift])

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
