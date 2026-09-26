//
//  ProjectCreator.swift
//  TexLab
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// Choices for File ▸ New Project, shown below the save panel's name field.
@Observable
final class NewProjectOptions {
    var template: DocumentTemplate = .article
    var includesBibliography = true

    /// Templates with a bibliography section to add one to.
    var supportsBibliography: Bool {
        [.article, .report, .book].contains(template)
    }
}

/// File ▸ New Project: a folder with a main file, and a bibliography if you want one,
/// ready to grow with chapters from the project navigator.
enum ProjectCreator {
    static func createProject() {
        let options = NewProjectOptions()
        let panel = NSSavePanel()
        panel.title = String(localized: "New Project")
        panel.message = String(localized: "TexLab creates a folder for the project, with main.tex inside.")
        panel.prompt = String(localized: "Create")
        panel.nameFieldLabel = String(localized: "Project:")
        panel.nameFieldStringValue = String(localized: "Untitled Project")
        panel.canCreateDirectories = true
        let accessory = NSHostingView(rootView: NewProjectAccessory(options: options))
        accessory.frame.size = accessory.fittingSize
        panel.accessoryView = accessory
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                create(at: url, options: options)
            }
        }
    }

    private static func create(at folder: URL, options: NewProjectOptions) {
        do {
            guard !FileManager.default.fileExists(atPath: folder.filePath) else {
                throw ProjectError.fileExists(folder.lastPathComponent)
            }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            var main = options.template.text
            if options.includesBibliography && options.supportsBibliography {
                try Data(bibliography.utf8).write(to: folder.appending(path: "references.bib"), options: .withoutOverwriting)
                let end = (main as NSString).range(of: "\\end{document}", options: .backwards)
                if end.location != NSNotFound {
                    let block = """
                    \\nocite{*} % Lists every entry; remove it once you cite with \\cite{key}.
                    \\bibliographystyle{plain}
                    \\bibliography{references}


                    """
                    main = (main as NSString).replacingCharacters(in: NSRange(location: end.location, length: 0), with: block)
                }
            }
            let mainURL = folder.appending(path: "main.tex")
            try Data(main.utf8).write(to: mainURL, options: .withoutOverwriting)
            RecentProjects.shared.record(folder: folder, mainFile: mainURL, isFolderProject: true)
            Task {
                _ = try? await NSDocumentController.shared.openDocument(withContentsOf: mainURL, display: true)
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static let bibliography = """
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

private struct NewProjectAccessory: View {
    @Bindable var options: NewProjectOptions

    var body: some View {
        Form {
            Picker("Template:", selection: $options.template) {
                ForEach(DocumentTemplate.allCases) { template in
                    Label(template.title, systemImage: template.systemImage).tag(template)
                }
            }
            .fixedSize()
            Toggle("Add a bibliography (references.bib)", isOn: $options.includesBibliography)
                .disabled(!options.supportsBibliography)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
