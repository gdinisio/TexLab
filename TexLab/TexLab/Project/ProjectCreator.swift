//
//  ProjectCreator.swift
//  TexLab
//

import AppKit
import Foundation

/// Paper sizes offered for new documents.
nonisolated enum PaperSize: String, CaseIterable, Identifiable, Sendable {
    case a4 = "a4paper"
    case letter = "letterpaper"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .a4: String(localized: "A4")
        case .letter: String(localized: "US Letter")
        }
    }

    /// The paper used where the Mac is set up: US Letter in the Americas that use it,
    /// A4 elsewhere.
    static var regional: PaperSize {
        let letterRegions: Set<String> = ["US", "CA", "MX", "CL", "CO", "CR", "DO", "GT", "PA", "PH", "PR", "SV", "VE"]
        return letterRegions.contains(Locale.current.region?.identifier ?? "") ? .letter : .a4
    }
}

/// The language a new document is written in, for hyphenation, quotation marks and the
/// names of parts such as "Contents" and "References".
nonisolated enum DocumentLanguage: String, CaseIterable, Identifiable, Sendable {
    case british
    case american
    case italian
    case french
    case german
    case spanish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .british: String(localized: "English (UK)")
        case .american: String(localized: "English (US)")
        case .italian: "Italiano"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        }
    }

    /// The `babel` option. Spanish's shorthands are off: they take over `<` and `>`, which
    /// Beamer needs for overlays.
    var babelOptions: String {
        switch self {
        case .british: "british"
        case .american: "american"
        case .italian: "italian"
        case .french: "french"
        case .german: "ngerman"
        case .spanish: "spanish, es-noshorthands"
        }
    }

    /// The locale dates are written in.
    var locale: Locale {
        switch self {
        case .british: Locale(identifier: "en_GB")
        case .american: Locale(identifier: "en_US")
        case .italian: Locale(identifier: "it_IT")
        case .french: Locale(identifier: "fr_FR")
        case .german: Locale(identifier: "de_DE")
        case .spanish: Locale(identifier: "es_ES")
        }
    }

    /// The language the Mac is set to, or English as written where the Mac is.
    static var regional: DocumentLanguage {
        switch Locale.current.language.languageCode?.identifier {
        case "it": .italian
        case "fr": .french
        case "de": .german
        case "es": .spanish
        default: Locale.current.region?.identifier == "US" ? .american : .british
        }
    }
}

/// What New Project creates: the template, its title, author and affiliation, the
/// language, the page set-up, the engine and whether to add a bibliography.
nonisolated struct ProjectSetup: Equatable, Sendable {
    var template: DocumentTemplate = .article
    /// The project folder's name.
    var name = ""
    /// The document's title; the project's name when left empty.
    var title = ""
    var author = ""
    var affiliation = ""
    var language: DocumentLanguage = .regional
    var paper: PaperSize = .regional
    var fontSize = 11
    var isWidescreen = true
    var engine: TypesettingEngine = .pdfLaTeX
    var includesBibliography = true
    /// When the document is dated: now, unless set for a preview.
    var date = Date()

    static let fontSizes = [10, 11, 12]

    /// Templates with a bibliography to add.
    var supportsBibliography: Bool {
        template.supportsBibliography
    }

    /// Whether the new project gets a bibliography.
    var usesBibliography: Bool {
        includesBibliography && supportsBibliography
    }

    /// Whether the template has a title page or title block.
    var hasTitle: Bool {
        template.hasTitle
    }

    /// Whether the template is laid out on paper, rather than as slides.
    var hasPageSetup: Bool {
        template != .presentation
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Files

    /// The project's files, its main file first, with the choices filled in.
    func files() -> [(path: String, text: String)] {
        template.projectFiles
            .filter { !$0.onlyWithBibliography || usesBibliography }
            .map { file in
                var text = fill(file.text)
                if file.path == "main.tex", engine != .pdfLaTeX {
                    // The choice travels with the file, and other TeX editors understand it too.
                    text = MagicComments.programLine(for: engine) + text
                }
                return (file.path, text)
            }
    }

    /// The text of the project's main.tex.
    func mainText() -> String {
        files().first?.text ?? ""
    }

    /// A template's text with the placeholders replaced and the lines for other choices
    /// left out.
    private func fill(_ template: String) -> String {
        var lines: [String] = []
        for line in template.components(separatedBy: "\n") {
            guard let condition = Self.conditions.first(where: { line.hasSuffix($0.marker) }) else {
                lines.append(line)
                continue
            }
            guard condition.applies(self) else { continue }
            var kept = String(line.dropLast(condition.marker.count))
            while kept.last == " " {
                kept.removeLast()
            }
            lines.append(kept)
        }
        var text = lines.joined(separator: "\n")
        for (placeholder, value) in placeholderValues {
            text = text.replacingOccurrences(of: placeholder, with: value)
        }
        // Lines left out can leave two blank lines together.
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text
    }

    /// A line marker, and when lines with it are kept.
    nonisolated private struct Condition: Sendable {
        var marker: String
        var applies: @Sendable (ProjectSetup) -> Bool
    }

    private static let conditions = [
        Condition(marker: "⟨bib⟩") { $0.usesBibliography },
        Condition(marker: "⟨nobib⟩") { !$0.usesBibliography },
        Condition(marker: "⟨pdf⟩") { $0.engine == .pdfLaTeX },
        Condition(marker: "⟨unicode⟩") { $0.engine != .pdfLaTeX },
    ]

    private var placeholderValues: [(String, String)] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentTitle = trimmedTitle.isEmpty ? trimmedName : trimmedTitle
        let monthAndYear = DateFormatter()
        monthAndYear.locale = language.locale
        monthAndYear.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        return [
            ("⟨title⟩", LaTeXEscaping.escape(documentTitle.isEmpty ? String(localized: "Untitled") : documentTitle)),
            ("⟨author⟩", LaTeXEscaping.escape(author.trimmingCharacters(in: .whitespacesAndNewlines))),
            ("⟨affiliation⟩", LaTeXEscaping.escape(affiliation.trimmingCharacters(in: .whitespacesAndNewlines))),
            ("⟨date⟩", LaTeXEscaping.escape(monthAndYear.string(from: date))),
            ("⟨year⟩", String(year)),
            ("⟨size⟩", "\(fontSize)pt"),
            ("⟨paper⟩", paper.rawValue),
            ("⟨language⟩", language.babelOptions),
            ("⟨slides⟩", isWidescreen ? "[aspectratio=169]" : ""),
        ]
    }

    // MARK: - One document

    /// A template as one self-contained document, for File ▸ New from Template: each
    /// `\input` of the main file replaced by the part it reads, without a bibliography,
    /// which needs a file of its own.
    static func standaloneText(for template: DocumentTemplate) -> String {
        var setup = ProjectSetup()
        setup.template = template
        setup.includesBibliography = false
        setup.author = NSFullUserName()
        let files = setup.files()
        guard let main = files.first?.text else { return "" }
        var parts: [String: String] = [:]
        for file in files.dropFirst() where file.path.hasSuffix(".tex") {
            parts[String(file.path.dropLast(4))] = file.text
                .components(separatedBy: "\n")
                .filter { !$0.hasPrefix("% !TEX root") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .newlines)
        }
        let lines = main.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\\input{"), let close = trimmed.firstIndex(of: "}") else { return line }
            let path = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 7)..<close])
            guard let part = parts[path] else { return line }
            let indent = String(line.prefix { $0 == " " })
            return part.components(separatedBy: "\n").map { $0.isEmpty ? $0 : indent + $0 }.joined(separator: "\n")
        }
        return lines.joined(separator: "\n")
    }
}

/// Writes text into LaTeX so it typesets as typed.
nonisolated enum LaTeXEscaping {
    static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            switch character {
            case "\\": result += "\\textbackslash{}"
            case "{", "}", "%", "$", "#", "&", "_": result += "\\" + String(character)
            case "~": result += "\\textasciitilde{}"
            case "^": result += "\\textasciicircum{}"
            default: result.append(character)
            }
        }
        return result
    }
}

/// File ▸ New Project: a folder with a main file, the parts it inputs, a Figures folder and
/// a bibliography if you want one, ready to grow with chapters from the project navigator. The New Project window
/// gathers the choices; this asks where to put the folder and creates it.
enum ProjectCreator {
    /// Asks where to create the project, as a sheet on `window` if there is one, then
    /// creates it and opens its main file. `completion` says whether it was created.
    static func chooseLocation(for setup: ProjectSetup, attachedTo window: NSWindow?, completion: @escaping (Bool) -> Void) {
        let panel = NSSavePanel()
        panel.title = String(localized: "New Project")
        panel.message = String(localized: "TexLab creates a folder for the project, with main.tex inside.")
        panel.prompt = String(localized: "Create")
        panel.nameFieldLabel = String(localized: "Project:")
        panel.nameFieldStringValue = setup.trimmedName.isEmpty ? String(localized: "Untitled Project") : setup.trimmedName
        panel.canCreateDirectories = true
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }
            MainActor.assumeIsolated {
                completion(create(setup, at: url))
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    /// Creates the project folder and opens its main file. Returns false, after saying
    /// why, if it couldn't.
    @discardableResult
    static func create(_ setup: ProjectSetup, at folder: URL) -> Bool {
        do {
            guard !FileManager.default.fileExists(atPath: folder.filePath) else {
                throw ProjectError.fileExists(folder.lastPathComponent)
            }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            for subfolder in setup.template.projectFolders {
                try FileManager.default.createDirectory(at: folder.appending(path: subfolder, directoryHint: .isDirectory), withIntermediateDirectories: true)
            }
            for file in setup.files() {
                let url = folder.appending(path: file.path)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(file.text.utf8).write(to: url, options: .withoutOverwriting)
            }
            let mainURL = folder.appending(path: "main.tex")
            RecentProjects.shared.record(folder: folder, mainFile: mainURL, isFolderProject: true)
            ProjectOpener.openDocument(mainURL)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }
}
