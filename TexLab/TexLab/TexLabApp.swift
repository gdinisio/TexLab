//
//  TexLabApp.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI

@main
struct TexLabApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TexLabDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
