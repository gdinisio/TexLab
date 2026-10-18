//
//  DocumentTemplate.swift
//  TexLab
//

import Foundation

/// Starting points for New Project and File ▸ New from Template.
///
/// A template is a project: a main file and, for longer documents, a folder of parts it
/// inputs, figures and a bibliography (`ProjectTemplates.swift`). New from Template makes
/// the same document as one file. Every template typesets with a standard TeX
/// distribution, so a new document shows a preview straight away and the user can learn
/// by editing something that already works.
nonisolated enum DocumentTemplate: String, CaseIterable, Identifiable {
    case article
    case report
    case thesis
    case notes
    case assignment
    case presentation
    case letter
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .article: String(localized: "Article")
        case .report: String(localized: "Report")
        case .thesis: String(localized: "Thesis")
        case .notes: String(localized: "Lecture Notes")
        case .assignment: String(localized: "Assignment")
        case .presentation: String(localized: "Presentation")
        case .letter: String(localized: "Letter")
        case .minimal: String(localized: "Blank")
        }
    }

    /// What the template is for, shown in the New Project window.
    var summary: String {
        switch self {
        case .article:
            String(localized: "A paper with a title page — title, author, affiliation, abstract and copyright — then its sections, one file each, and the references on a page of their own.")
        case .report:
            String(localized: "A report with a title page, an abstract and contents, and a chapter per file.")
        case .thesis:
            String(localized: "A thesis: title page, abstract, acknowledgements and lists of contents, figures and tables, then chapters, appendices and references.")
        case .notes:
            String(localized: "Course notes with numbered theorems, definitions and exercises, and a file per lecture.")
        case .assignment:
            String(localized: "Problems and solutions, with the course and your name at the top of every page.")
        case .presentation:
            String(localized: "Beamer slides, with a file for each part of the talk.")
        case .letter:
            String(localized: "A formal letter with addresses, opening and closing.")
        case .minimal:
            String(localized: "An empty document, to start from scratch.")
        }
    }

    var systemImage: String {
        switch self {
        case .article: "doc.text"
        case .report: "doc.richtext"
        case .thesis: "graduationcap"
        case .notes: "book.pages"
        case .assignment: "checklist"
        case .presentation: "play.rectangle"
        case .letter: "envelope"
        case .minimal: "doc"
        }
    }

    /// Whether the template can have a bibliography.
    var supportsBibliography: Bool {
        projectFiles.contains { $0.onlyWithBibliography }
    }

    /// Whether the template has a title page or title block.
    var hasTitle: Bool {
        ![.letter, .minimal].contains(self)
    }

    /// What the template calls the affiliation field, or nil if it has none.
    var affiliationLabel: String? {
        switch self {
        case .article, .report: String(localized: "Affiliation")
        case .thesis: String(localized: "University")
        case .notes: String(localized: "Institution")
        case .assignment: String(localized: "Course")
        case .presentation: String(localized: "Institute")
        case .letter, .minimal: nil
        }
    }

    /// The template as one document, for File ▸ New from Template and new documents.
    var text: String {
        ProjectSetup.standaloneText(for: self)
    }
}
