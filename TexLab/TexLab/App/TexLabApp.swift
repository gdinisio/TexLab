//
//  TexLabApp.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import Foundation
import SwiftUI

/// TexLab: an AppKit document app with SwiftUI views. Each text file is an NSDocument
/// (`TeXDocument`), shown in its project's window (`ProjectWindowController`), as files
/// are in Xcode. SwiftUI provides the Welcome, New Project and Settings windows and the
/// menu bar.
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
        // The menu bar's commands, for every window.
        .commands {
            TexLabCommands()
        }

        Window("New Project", id: NewProjectWindow.id) {
            NewProjectView()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        // File ▸ New Project opens it; it doesn't belong in the Window menu.
        .commandsRemoved()

        Settings {
            SettingsView()
        }
    }
}
