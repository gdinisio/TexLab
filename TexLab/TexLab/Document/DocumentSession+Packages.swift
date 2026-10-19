//
//  DocumentSession+Packages.swift
//  TexLab
//

import AppKit
import Foundation

/// Packages a document uses without loading: found with the live issues, each one listed
/// with an Add button, and offered just above a command as soon as it's typed — `\mathbb`
/// without amssymb, `\begin{align}` without amsmath. Nothing is added without a click.
extension DocumentSession {
    /// What the check needs: the preamble the shown file is typeset with, the project's
    /// own packages and the files the preamble inputs, and what the project defines.
    var packageContext: PackageContext? {
        var preamble = Self.preambleText(of: text)
        var mainFolder = documentDirectory
        if preamble == nil, let main = project?.mainFile, let mainText = textOfFile(main) {
            // A part of a project: its main file's preamble.
            preamble = Self.preambleText(of: mainText)
            mainFolder = main.deletingLastPathComponent()
        }
        guard let preamble else { return nil }
        var context = PackageContext(preamble: preamble)
        if let project {
            let loaded = PackageRequirements.packagesLoaded(by: preamble)
            let documentClass = NewFileKind.documentClass(of: preamble)
            context.packageFiles = project.tree.files.map(\.url).filter { url in
                let name = url.deletingPathExtension().lastPathComponent
                switch url.pathExtension.lowercased() {
                case "sty": return loaded.contains(name)
                case "cls": return name == documentClass
                default: return false
                }
            }
            context.definedCommands = Set(project.commands.map(\.name))
            context.definedEnvironments = project.environments
        }
        if let mainFolder {
            // Files of the project the preamble inputs, such as preamble.tex.
            let string = preamble as NSString
            for match in Self.preambleInputPattern.matches(in: preamble, range: NSRange(location: 0, length: string.length)) {
                let path = string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                let base = mainFolder.appending(path: path)
                let candidates = base.pathExtension.isEmpty ? [base.appendingPathExtension("tex"), base] : [base]
                if let file = candidates.first(where: { FileManager.default.fileExists(atPath: $0.filePath) }) {
                    context.packageFiles.append(file)
                }
            }
        }
        return context
    }

    private static let preambleInputPattern = try! NSRegularExpression(pattern: #"^[^%\n]*\\(?:input|include)\s*\{([^{}]+)\}"#, options: [.anchorsMatchLines])

    private static func preambleText(of text: String) -> String? {
        let string = text as NSString
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return nil }
        return string.substring(to: begin.location)
    }

    // MARK: - The prompt

    /// Offers the package a command needs when it's on the line being written, before the
    /// insertion point, as a check that has just run finds it; otherwise keeps the offer
    /// only while the insertion point stays on its line.
    func updatePackagePrompt(afterTyping: Bool = false) {
        let selection = editor.selectedRange
        let string = text as NSString
        guard selection.length == 0, selection.location <= string.length else {
            editor.hidePackagePrompt()
            return
        }
        let line = string.lineRange(for: NSRange(location: selection.location, length: 0))
        guard afterTyping else {
            if let range = editor.packagePromptRange, !NSLocationInRange(range.location, line) {
                editor.hidePackagePrompt()
            }
            return
        }
        let candidates = missingPackages
            .filter { !declinedPackages.contains($0.package) }
            .flatMap { missing in missing.ranges.map { (missing: missing, range: $0) } }
            .filter { NSLocationInRange($0.range.location, line) && NSMaxRange($0.range) <= selection.location }
        guard let nearest = candidates.max(by: { $0.range.location < $1.range.location }) else {
            editor.hidePackagePrompt()
            return
        }
        let package = nearest.missing.package
        editor.showPackagePrompt(command: string.substring(with: nearest.range), package: package, at: nearest.range) { [weak self] in
            self?.addMissingPackage(package)
        } dismiss: { [weak self] in
            self?.declinedPackages.insert(package)
            self?.editor.hidePackagePrompt()
            self?.editor.focus()
        }
    }

    /// Loads a package the document uses, in its preamble or its main file's.
    func addMissingPackage(_ package: String) {
        editor.hidePackagePrompt()
        missingPackages.removeAll { $0.package == package }
        ensurePackages([package])
        editor.focus()
        // A part's main file changed, not the text on screen.
        checkLiveIssues()
    }

    func apply(_ fix: IssueFix) {
        switch fix {
        case .addPackage(let package):
            addMissingPackage(package)
        }
    }

    /// The missing package of the command at `location`, for the editor's context menu.
    func missingPackage(at location: Int) -> MissingPackage? {
        missingPackages.first { missing in
            missing.ranges.contains { NSLocationInRange(location, $0) || NSMaxRange($0) == location }
        }
    }
}
