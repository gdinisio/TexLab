//
//  FileKindTint.swift
//  TexLab
//

import AppKit
import SwiftUI

extension ProjectFileKind {
    /// The colour of the kind's icon, as Xcode colours its file icons: with names shown
    /// without their extensions, a chapter, a bibliography, a package and a figure are told
    /// apart at a glance. Folders take the accent colour, as in the Finder's sidebar.
    var tint: NSColor {
        switch self {
        case .folder: .controlAccentColor
        case .latex: .systemGreen
        case .bibliography: .systemOrange
        case .package: .systemPurple
        case .image: .systemTeal
        case .pdf: .systemRed
        case .text, .other: .secondaryLabelColor
        }
    }

    /// The tint as a SwiftUI colour.
    var tintColor: Color {
        Color(nsColor: tint)
    }
}
