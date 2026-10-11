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

/// What New Project creates: the template, its title and author, the page set-up, the
/// engine and whether to add a bibliography.
nonisolated struct ProjectSetup: Equatable, Sendable {
    var template: DocumentTemplate = .article
    /// The project folder's name.
    var name = ""
    /// The document's title; the project's name when left empty.
    var title = ""
    var author = ""
    var paper: PaperSize = .regional
    var fontSize = 11
    var isWidescreen = true
    var engine: TypesettingEngine = .pdfLaTeX
    var includesBibliography = true

    static let fontSizes = [10, 11, 12]

    /// Templates with a bibliography section to add one to.
    var supportsBibliography: Bool {
        [.article, .report, .book].contains(template)
    }

    /// Whether the template has a title page or title block.
    var hasTitle: Bool {
        ![.letter, .minimal].contains(template)
    }

    /// Whether the template is laid out on paper, rather than as slides.
    var hasPageSetup: Bool {
        template != .presentation
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The text of the project's main.tex.
    func mainText() -> String {
        let title = self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmedName : self.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = self.author.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = template.text.components(separatedBy: "\n")
        for index in lines.indices {
            let line = lines[index]
            if line.hasPrefix("\\documentclass") {
                lines[index] = documentClassLine(replacing: line)
            } else if line.hasPrefix("\\title{"), !title.isEmpty {
                lines[index] = "\\title{\(LaTeXEscaping.escape(title))}"
            } else if line.hasPrefix("\\author{"), !author.isEmpty {
                lines[index] = "\\author{\(LaTeXEscaping.escape(author))}"
            } else if line.hasPrefix("\\signature{"), !author.isEmpty {
                lines[index] = "\\signature{\(LaTeXEscaping.escape(author))}"
            } else if line == "\\usepackage[T1]{fontenc}", engine != .pdfLaTeX {
                // XeLaTeX and LuaLaTeX use the Mac's own fonts, through fontspec.
                lines[index] = "\\usepackage{fontspec}"
            }
        }
        var text = lines.joined(separator: "\n")
        if includesBibliography && supportsBibliography {
            let end = (text as NSString).range(of: "\\end{document}", options: .backwards)
            if end.location != NSNotFound {
                let block = """
                \\nocite{*} % Lists every entry; remove it once you cite with \\cite{key}.
                \\bibliographystyle{plain}
                \\bibliography{references}


                """
                text = (text as NSString).replacingCharacters(in: NSRange(location: end.location, length: 0), with: block)
            }
        }
        if engine != .pdfLaTeX {
            // The choice travels with the file, and other TeX editors understand it too.
            text = MagicComments.programLine(for: engine) + text
        }
        return text
    }

    /// `\documentclass` with the chosen size and paper, or slide shape.
    private func documentClassLine(replacing line: String) -> String {
        guard let open = line.firstIndex(of: "{"),
              let close = line[open...].firstIndex(of: "}") else { return line }
        let documentClass = line[line.index(after: open)..<close]
        var options: [String] = []
        if hasPageSetup {
            options = ["\(fontSize)pt", paper.rawValue]
        } else if isWidescreen {
            options = ["aspectratio=169"]
        }
        return options.isEmpty
            ? "\\documentclass{\(documentClass)}"
            : "\\documentclass[\(options.joined(separator: ", "))]{\(documentClass)}"
    }

    /// A first entry for references.bib, so the bibliography typesets straight away.
    static let bibliography = """
    % Bibliography database. Cite entries with \\cite{key}.

    @book{lamport1994latex,
      author    = {Leslie Lamport},
      title     = {{\\LaTeX}: A Document Preparation System},
      edition   = {2nd},
      publisher = {Addison-Wesley},
      year      = {1994},
    }

    """
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

/// File ▸ New Project: a folder with a main file, and a bibliography if you want one,
/// ready to grow with chapters from the project navigator. The New Project window
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
            if setup.includesBibliography && setup.supportsBibliography {
                try Data(ProjectSetup.bibliography.utf8).write(to: folder.appending(path: "references.bib"), options: .withoutOverwriting)
            }
            let mainURL = folder.appending(path: "main.tex")
            try Data(setup.mainText().utf8).write(to: mainURL, options: .withoutOverwriting)
            RecentProjects.shared.record(folder: folder, mainFile: mainURL, isFolderProject: true)
            ProjectOpener.openDocument(mainURL)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }
}
