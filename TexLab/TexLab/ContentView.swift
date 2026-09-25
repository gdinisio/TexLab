//
//  ContentView.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: TexLabDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(TexLabDocument()))
}
