//
//  NewProjectView.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import SwiftUI

/// The New Project window, like Xcode's template chooser: pick a template from a gallery,
/// fill in the title and author, choose the paper, size and engine, then where to save.
struct NewProjectView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var setup = ProjectSetup.lastUsed
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                gallery
                Divider()
                options
                    .frame(width: 320)
            }
            Divider()
            footer
        }
        .frame(width: 800, height: 500)
        .onAppear {
            isNameFocused = true
        }
    }

    // MARK: - Templates

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a template for your new project")
                .font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 134, maximum: 160), spacing: 12)], spacing: 12) {
                ForEach(DocumentTemplate.allCases) { template in
                    TemplateCard(template: template, isSelected: setup.template == template)
                        .onTapGesture(count: 2) {
                            setup.template = template
                            create()
                        }
                        .onTapGesture {
                            setup.template = template
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(setup.template == template ? .isSelected : [])
                        .accessibilityAction {
                            setup.template = template
                        }
                }
            }
            Spacer(minLength: 0)
            Label(setup.template.summary, systemImage: setup.template.systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Options

    private var options: some View {
        Form {
            Section {
                TextField("Project Name", text: $setup.name, prompt: Text("Required"))
                    .focused($isNameFocused)
                if setup.hasTitle {
                    TextField("Title", text: $setup.title, prompt: Text(verbatim: setup.trimmedName.isEmpty ? String(localized: "Same as the project") : setup.trimmedName))
                }
                TextField(setup.template == .letter ? String(localized: "Your Name") : String(localized: "Author"), text: $setup.author)
            }
            Section {
                if setup.hasPageSetup {
                    Picker("Paper", selection: $setup.paper) {
                        ForEach(PaperSize.allCases) { paper in
                            Text(paper.title).tag(paper)
                        }
                    }
                    Picker("Font Size", selection: $setup.fontSize) {
                        ForEach(ProjectSetup.fontSizes, id: \.self) { size in
                            Text("\(size) pt").tag(size)
                        }
                    }
                } else {
                    Picker("Slides", selection: $setup.isWidescreen) {
                        Text("Widescreen (16:9)").tag(true)
                        Text("Standard (4:3)").tag(false)
                    }
                }
            }
            Section {
                Picker("Engine", selection: $setup.engine) {
                    ForEach(TypesettingEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }
                if setup.supportsBibliography {
                    Toggle("Bibliography (references.bib)", isOn: $setup.includesBibliography)
                }
            } footer: {
                Text(engineDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var engineDescription: String {
        switch setup.engine {
        case .pdfLaTeX:
            String(localized: "pdfLaTeX is the most widely used engine, and the fastest.")
        case .xeLaTeX, .luaLaTeX:
            String(localized: "\(setup.engine.displayName) can use any font installed on your Mac, with fontspec.")
        }
    }

    // MARK: - Creating

    private var footer: some View {
        HStack {
            Text("Next, choose where to save the project folder.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") {
                dismissWindow(id: NewProjectWindow.id)
            }
            .keyboardShortcut(.cancelAction)
            Button("Create…") {
                create()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(setup.trimmedName.isEmpty)
        }
        .padding(16)
    }

    private func create() {
        guard !setup.trimmedName.isEmpty else {
            NSSound.beep()
            isNameFocused = true
            return
        }
        let chosen = setup
        ProjectCreator.chooseLocation(for: chosen, attachedTo: NSApp.keyWindow) { created in
            guard created else { return }
            chosen.remember()
            dismissWindow(id: NewProjectWindow.id)
            dismissWindow(id: WelcomeWindow.id)
        }
    }
}

/// Opening the New Project window.
enum NewProjectWindow {
    static let id = "new-project"
}

extension ProjectSetup {
    private static let defaultsKey = "newProjectSetup"

    /// The choices made for the previous project, so the next one starts the same way;
    /// the default engine from Settings and the user's name otherwise.
    static var lastUsed: ProjectSetup {
        var setup = ProjectSetup()
        let defaults = UserDefaults.standard
        setup.engine = TypesettingEngine(rawValue: defaults.string(forKey: SettingsKey.defaultEngine) ?? "") ?? .pdfLaTeX
        setup.author = NSFullUserName()
        guard let saved = defaults.dictionary(forKey: defaultsKey) else { return setup }
        if let raw = saved["template"] as? String, let template = DocumentTemplate(rawValue: raw) {
            setup.template = template
        }
        if let raw = saved["paper"] as? String, let paper = PaperSize(rawValue: raw) {
            setup.paper = paper
        }
        if let size = saved["fontSize"] as? Int, fontSizes.contains(size) {
            setup.fontSize = size
        }
        if let widescreen = saved["widescreen"] as? Bool {
            setup.isWidescreen = widescreen
        }
        if let raw = saved["engine"] as? String, let engine = TypesettingEngine(rawValue: raw) {
            setup.engine = engine
        }
        if let bibliography = saved["bibliography"] as? Bool {
            setup.includesBibliography = bibliography
        }
        if let author = saved["author"] as? String {
            setup.author = author
        }
        return setup
    }

    /// Remembers these choices for the next project.
    func remember() {
        UserDefaults.standard.set([
            "template": template.rawValue,
            "paper": paper.rawValue,
            "fontSize": fontSize,
            "widescreen": isWidescreen,
            "engine": engine.rawValue,
            "bibliography": includesBibliography,
            "author": author,
        ] as [String: Any], forKey: Self.defaultsKey)
    }
}

/// A template in the gallery: a sketch of its first page and its name.
private struct TemplateCard: View {
    var template: DocumentTemplate
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            TemplatePreview(template: template)
                .frame(width: 100, height: 104)
            Text(template.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.14)) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(template.title)
        .accessibilityHint(template.summary)
    }
}

/// A sketch of a template's first page — title, headings and lines of text — drawn
/// rather than loaded, so it suits every appearance and needs no artwork.
struct TemplatePreview: View {
    var template: DocumentTemplate

    var body: some View {
        let size = template == .presentation ? CGSize(width: 100, height: 75) : CGSize(width: 76, height: 100)
        let marks = TemplateSketch.marks(for: template)
        Canvas { context, canvasSize in
            for mark in marks {
                let rect = CGRect(
                    x: mark.rect.minX * canvasSize.width,
                    y: mark.rect.minY * canvasSize.height,
                    width: mark.rect.width * canvasSize.width,
                    height: mark.rect.height * canvasSize.height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: min(rect.height / 2, 1.5)), with: .color(Color.black.opacity(mark.opacity)))
            }
        }
        .frame(width: size.width, height: size.height)
        // Paper is white in Dark Mode too.
        .background(Color.white, in: RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

/// The marks on a template's sketch, in fractions of the page.
nonisolated enum TemplateSketch {
    struct Mark {
        var rect: CGRect
        var opacity: Double
    }

    static func marks(for template: DocumentTemplate) -> [Mark] {
        var marks: [Mark] = []
        func mark(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ opacity: Double) {
            marks.append(Mark(rect: CGRect(x: x, y: y, width: width, height: height), opacity: opacity))
        }
        func text(from top: CGFloat, lines: Int, x: CGFloat = 0.12, width: CGFloat = 0.76) {
            for line in 0..<lines {
                let isLast = line == lines - 1
                mark(x, top + CGFloat(line) * 0.055, isLast ? width * 0.6 : width, 0.02, 0.22)
            }
        }
        switch template {
        case .article:
            mark(0.25, 0.09, 0.50, 0.045, 0.8)
            mark(0.35, 0.165, 0.30, 0.025, 0.45)
            mark(0.40, 0.21, 0.20, 0.02, 0.3)
            mark(0.12, 0.30, 0.38, 0.035, 0.7)
            text(from: 0.38, lines: 6)
            mark(0.12, 0.74, 0.30, 0.035, 0.7)
            text(from: 0.82, lines: 2)
        case .report:
            mark(0.12, 0.10, 0.20, 0.025, 0.45)
            mark(0.12, 0.16, 0.58, 0.065, 0.85)
            mark(0.12, 0.31, 0.36, 0.035, 0.65)
            text(from: 0.39, lines: 5)
            mark(0.12, 0.70, 0.30, 0.035, 0.65)
            text(from: 0.78, lines: 3)
        case .book:
            mark(0.16, 0.26, 0.68, 0.07, 0.85)
            mark(0.27, 0.37, 0.46, 0.03, 0.45)
            mark(0.33, 0.60, 0.34, 0.03, 0.55)
            mark(0.38, 0.86, 0.24, 0.022, 0.3)
        case .presentation:
            mark(0.18, 0.32, 0.64, 0.09, 0.85)
            mark(0.28, 0.48, 0.44, 0.05, 0.45)
            mark(0.34, 0.60, 0.32, 0.04, 0.35)
            mark(0.74, 0.88, 0.18, 0.03, 0.18)
        case .letter:
            mark(0.60, 0.07, 0.28, 0.02, 0.35)
            mark(0.60, 0.11, 0.24, 0.02, 0.35)
            mark(0.60, 0.15, 0.20, 0.02, 0.35)
            mark(0.12, 0.25, 0.30, 0.02, 0.35)
            mark(0.12, 0.29, 0.26, 0.02, 0.35)
            mark(0.12, 0.33, 0.22, 0.02, 0.35)
            mark(0.60, 0.40, 0.22, 0.02, 0.3)
            mark(0.12, 0.47, 0.30, 0.025, 0.6)
            text(from: 0.54, lines: 4)
            mark(0.12, 0.80, 0.28, 0.025, 0.5)
            mark(0.12, 0.88, 0.22, 0.025, 0.6)
        case .minimal:
            // An empty page with an insertion point, ready to type.
            mark(0.12, 0.09, 0.012, 0.05, 0.7)
        }
        return marks
    }
}
