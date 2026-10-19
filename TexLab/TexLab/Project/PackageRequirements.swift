//
//  PackageRequirements.swift
//  TexLab
//

import Foundation

/// A package the document uses without loading, as the editor offers to add it.
nonisolated struct MissingPackage: Hashable, Sendable {
    /// The package to add, such as `amssymb`.
    var package: String
    /// What needs it, as written: `\mathbb`, or `\begin{align}`.
    var command: String
    /// Every use, in source order.
    var ranges: [NSRange]
    /// 1-based line of the first use.
    var line: Int
}

/// What the check needs to know beyond the text itself.
nonisolated struct PackageContext: Sendable {
    /// The preamble the document is typeset with: its own, or its main file's.
    var preamble: String
    /// Files whose packages count too: local packages and classes, and files the preamble
    /// inputs. A file that can't be read leaves the check quiet.
    var packageFiles: [URL] = []
    /// Commands and environments the project defines itself.
    var definedCommands: Set<String> = []
    var definedEnvironments: Set<String> = []
}

/// Which packages define which commands and environments, so the editor can notice
/// `\mathbb` used without `amssymb` and offer to add it, like Xcode's Fix-Its. The check
/// stays quiet whenever it can't be sure: with a document class it doesn't know, when
/// a file the preamble inputs can't be read, and for anything the project defines itself.
///
/// Every command and environment here is undefined in a plain `article` and defined by
/// the first package listed, as typeset with TeX Live; the other packages listed define
/// it too.
nonisolated enum PackageRequirements {
    static let commands: [String: [String]] = {
        var table: [String: [String]] = [:]
        func add(_ names: [String], _ packages: [String]) {
            for name in names {
                table[name] = packages
            }
        }
        add(["mathbb", "mathfrak"], ["amssymb", "amsfonts", "unicode-math"])
        add(["varnothing", "lesssim", "gtrsim", "leqslant", "geqslant", "nleq", "ngeq", "therefore", "because",
             "square", "blacksquare", "checkmark", "nexists", "complement", "smallsetminus", "twoheadrightarrow",
             "circlearrowleft", "circlearrowright", "curvearrowright", "curvearrowleft", "triangleq", "nsubseteq",
             "subsetneq", "supsetneq", "upharpoonright", "lll", "ggg", "ltimes", "rtimes", "Bbbk",
             "beth", "gimel", "daleth", "varkappa", "digamma", "backsim", "eqslantless", "eqslantgtr"],
            ["amssymb", "unicode-math"])
        add(["text"], ["amsmath", "amstext", "mathtools", "physics", "siunitx"])
        add(["eqref", "dfrac", "tfrac", "binom", "dbinom", "tbinom", "operatorname", "DeclareMathOperator",
             "boldsymbol", "intertext", "substack", "overset", "underset", "xrightarrow", "xleftarrow",
             "iint", "iiint", "idotsint", "cfrac", "genfrac", "numberwithin", "allowdisplaybreaks", "tag", "notag"],
            ["amsmath", "mathtools", "physics"])
        add(["coloneqq", "eqqcolon", "Coloneqq", "DeclarePairedDelimiter", "mathclap", "mathllap", "mathrlap",
             "shortintertext", "prescript"], ["mathtools"])
        add(["theoremstyle", "qedhere", "newtheoremstyle"], ["amsthm"])
        add(["mathscr"], ["mathrsfs", "unicode-math"])
        add(["bm"], ["bm"])
        add(["mathds"], ["dsfont"])
        add(["mathbbm"], ["bbm"])
        add(["includegraphics", "rotatebox", "scalebox", "resizebox", "graphicspath", "reflectbox"], ["graphicx", "graphics"])
        add(["textcolor", "color", "colorbox", "fcolorbox", "definecolor", "pagecolor"], ["xcolor", "color"])
        add(["href", "hypersetup", "autoref", "hyperlink", "hypertarget", "phantomsection", "texorpdfstring"], ["hyperref"])
        add(["url"], ["hyperref", "url", "xurl"])
        add(["nameref"], ["hyperref", "nameref"])
        add(["cref", "Cref", "crefname", "Crefname", "labelcref", "crefrange", "cpageref"], ["cleveref"])
        add(["toprule", "midrule", "bottomrule", "cmidrule", "addlinespace", "specialrule"], ["booktabs"])
        add(["multirow"], ["multirow"])
        add(["tikz", "usetikzlibrary", "tikzset"], ["tikz"])
        add(["pgfplotsset"], ["pgfplots"])
        add(["SI", "si", "num", "unit", "ang", "sisetup", "SIrange", "qtyrange", "numrange", "qtylist", "numlist", "tablenum"], ["siunitx"])
        add(["qty"], ["siunitx", "physics"])
        add(["lstinline", "lstinputlisting", "lstset", "lstdefinestyle"], ["listings"])
        add(["mintinline", "inputminted", "setminted"], ["minted"])
        add(["setlist", "newlist"], ["enumitem"])
        add(["geometry", "newgeometry", "restoregeometry"], ["geometry"])
        add(["fancyhead", "fancyfoot", "fancyhf", "fancypagestyle"], ["fancyhdr"])
        add(["subcaptionbox", "subref"], ["subcaption"])
        add(["captionof", "captionsetup"], ["caption", "subcaption"])
        add(["newcolumntype"], ["array", "tabularx"])
        add(["xspace"], ["xspace"])
        add(["lipsum"], ["lipsum"])
        add(["blindtext", "Blindtext"], ["blindtext"])
        add(["enquote", "textquote", "blockquote", "MakeOuterQuote"], ["csquotes"])
        add(["addbibresource", "printbibliography", "parencite", "Parencite", "textcite", "Textcite", "autocite",
             "Autocite", "footcite", "smartcite", "printbibheading"], ["biblatex"])
        add(["citep", "citet", "citealp", "citealt", "Citet", "Citep", "citeauthor", "citeyear"], ["natbib", "biblatex"])
        add(["todo", "missingfigure", "listoftodos"], ["todonotes"])
        add(["hl", "sethlcolor"], ["soul"])
        add(["sout", "uline", "uwave", "xout"], ["ulem"])
        add(["cancel", "bcancel", "xcancel", "cancelto"], ["cancel"])
        add(["ce"], ["mhchem"])
        add(["chemfig"], ["chemfig"])
        add(["bra", "ket", "braket"], ["braket", "physics"])
        add(["dv", "pdv", "expval"], ["physics"])
        add(["nicefrac"], ["nicefrac"])
        add(["sfrac"], ["xfrac"])
        add(["llbracket", "rrbracket"], ["stmaryrd"])
        add(["includepdf"], ["pdfpages"])
        add(["doublespacing", "onehalfspacing", "singlespacing", "setstretch"], ["setspace"])
        add(["setmainfont", "setsansfont", "setmonofont", "newfontfamily", "fontspec"], ["fontspec", "unicode-math"])
        add(["VerbatimInput"], ["fancyvrb", "fvextra"])
        add(["newglossaryentry", "gls", "Gls", "glspl", "Glspl", "printglossary", "printglossaries", "makeglossaries", "newacronym"], ["glossaries"])
        add(["nomenclature", "printnomenclature", "makenomenclature"], ["nomencl"])
        add(["printindex"], ["imakeidx", "makeidx"])
        add(["tcbset", "newtcolorbox"], ["tcolorbox"])
        add(["externaldocument"], ["xr", "xr-hyper"])
        add(["euro"], ["eurosym"])
        add(["qrcode"], ["qrcode"])
        add(["titleformat", "titlespacing"], ["titlesec"])
        add(["restylefloat", "floatstyle"], ["float"])
        return table
    }()

    static let environments: [String: [String]] = {
        var table: [String: [String]] = [:]
        func add(_ names: [String], _ packages: [String]) {
            for name in names {
                table[name] = packages
            }
        }
        add(["align", "align*", "gather", "gather*", "multline", "multline*", "flalign", "flalign*", "alignat",
             "alignat*", "split", "aligned", "gathered", "alignedat", "cases", "pmatrix", "bmatrix", "Bmatrix",
             "vmatrix", "Vmatrix", "matrix", "smallmatrix", "subequations", "equation*"],
            ["amsmath", "mathtools", "physics"])
        add(["dcases", "dcases*", "rcases", "pmatrix*", "bmatrix*", "multlined"], ["mathtools"])
        add(["proof"], ["amsthm"])
        add(["tikzpicture"], ["tikz"])
        add(["axis", "semilogxaxis", "semilogyaxis", "loglogaxis"], ["pgfplots"])
        add(["tikzcd"], ["tikz-cd"])
        add(["forest"], ["forest"])
        add(["circuitikz"], ["circuitikz"])
        add(["lstlisting"], ["listings"])
        add(["minted"], ["minted"])
        add(["subfigure", "subtable"], ["subcaption"])
        add(["wrapfigure", "wraptable"], ["wrapfig"])
        add(["tabularx"], ["tabularx"])
        add(["longtable"], ["longtable"])
        add(["multicols", "multicols*"], ["multicol"])
        add(["Verbatim", "BVerbatim"], ["fancyvrb", "fvextra"])
        add(["tcolorbox"], ["tcolorbox"])
        add(["mdframed"], ["mdframed"])
        add(["algorithm"], ["algorithm", "algorithm2e"])
        add(["algorithmic"], ["algpseudocode", "algorithmic"])
        add(["spacing", "doublespace", "onehalfspace", "singlespace"], ["setspace"])
        add(["otherlanguage"], ["babel", "polyglossia"])
        return table
    }()

    /// The packages each package loads in turn, as TeX Live's do.
    static let loads: [String: [String]] = [
        "amssymb": ["amsfonts"],
        "amsmath": ["amstext"],
        "mathtools": ["amsmath", "amstext", "graphicx"],
        "physics": ["amsmath", "amstext"],
        "tikz": ["pgf", "graphicx", "xcolor"],
        "pgfplots": ["tikz", "pgf", "graphicx", "xcolor"],
        "tikz-cd": ["tikz", "pgf", "graphicx", "xcolor"],
        "circuitikz": ["tikz", "pgf", "graphicx", "xcolor"],
        "forest": ["tikz", "pgf", "graphicx", "xcolor"],
        "todonotes": ["tikz", "pgf", "graphicx", "xcolor"],
        "tcolorbox": ["pgf", "graphicx", "xcolor"],
        "hyperref": ["url", "nameref"],
        "biblatex": ["url"],
        "subcaption": ["caption"],
        "tabularx": ["array"],
        "siunitx": ["amstext", "array", "color"],
        "unicode-math": ["fontspec"],
        "fvextra": ["fancyvrb"],
        "xr-hyper": ["xr"],
        "imakeidx": ["makeidx"],
    ]

    /// The packages each document class loads, or provides itself; nil for a class the
    /// check doesn't know, which keeps it quiet.
    static let classes: [String: [String]] = [
        "article": [], "report": [], "book": [], "letter": [], "proc": [], "slides": [], "minimal": [],
        "extarticle": [], "extreport": [], "extbook": [], "standalone": [],
        "scrartcl": [], "scrreprt": [], "scrbook": [], "scrlttr2": [],
        "memoir": ["array", "booktabs", "nameref"],
        "beamer": ["amsfonts", "amsmath", "amssymb", "amstext", "amsthm", "geometry", "graphicx", "hyperref", "nameref", "url", "xcolor"],
        "amsart": ["amsfonts", "amsmath", "amstext", "amsthm"],
        "amsbook": ["amsfonts", "amsmath", "amstext", "amsthm"],
        "amsproc": ["amsfonts", "amsmath", "amstext", "amsthm"],
        "tufte-handout": ["fancyhdr", "geometry", "hyperref", "multicol", "nameref", "natbib", "setspace", "url", "xcolor"],
        "tufte-book": ["fancyhdr", "geometry", "hyperref", "multicol", "nameref", "natbib", "setspace", "url", "xcolor"],
    ]

    // MARK: - Checking

    private static let packagePattern = try! NSRegularExpression(pattern: #"\\(?:usepackage|RequirePackage)\s*(?:\[[^\]]*\])?\s*\{([^{}]*)\}"#)
    private static let classPattern = try! NSRegularExpression(pattern: #"\\(?:documentclass|LoadClass)\s*(?:\[[^\]]*\])?\s*\{([^{}]*)\}"#)
    private static let environmentPattern = try! NSRegularExpression(pattern: #"\\begin\s*\{([A-Za-z]+\*?)\}"#)
    private static let commandPattern = try! NSRegularExpression(pattern: #"\\([A-Za-z]+)"#)

    /// Whether the backslash at `location` is itself escaped, as in `\\mathbb`.
    private static func isEscaped(_ location: Int, in string: NSString) -> Bool {
        var count = 0
        var index = location - 1
        while index >= 0 && string.character(at: index) == Char.backslash {
            count += 1
            index -= 1
        }
        return count % 2 == 1
    }

    /// The packages `text` loads with `\usepackage` or `\RequirePackage`, outside comments.
    static func packagesLoaded(by text: String) -> Set<String> {
        var packages: Set<String> = []
        for line in text.components(separatedBy: "\n") {
            let code = LaTeXText.stripComment(line)
            let string = code as NSString
            for match in packagePattern.matches(in: code, range: NSRange(location: 0, length: string.length)) {
                for name in string.substring(with: match.range(at: 1)).split(separator: ",") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        packages.insert(trimmed)
                    }
                }
            }
        }
        return packages
    }

    /// The packages `packages` load in turn, and they themselves.
    static func closure(of packages: Set<String>) -> Set<String> {
        var all = packages
        var queue = Array(packages)
        while let package = queue.popLast() {
            for loaded in loads[package] ?? [] where all.insert(loaded).inserted {
                queue.append(loaded)
            }
        }
        return all
    }

    /// The packages `text` needs but doesn't load, one entry per package, in the order of
    /// their first use; nil when the check can't be sure — a class it doesn't know, or a
    /// file the preamble relies on that can't be read.
    static func missing(in text: String, context: PackageContext) -> [MissingPackage]? {
        let preamble = context.preamble as NSString
        guard let classMatch = classPattern.firstMatch(in: context.preamble, range: NSRange(location: 0, length: preamble.length)) else { return nil }
        var documentClass = preamble.substring(with: classMatch.range(at: 1)).trimmingCharacters(in: .whitespaces)
        var loaded = packagesLoaded(by: context.preamble)
        var definedCommands = context.definedCommands
        var definedEnvironments = context.definedEnvironments
        for file in context.packageFiles {
            guard let contents = ProjectIndex.contents(of: file) else { return nil }
            loaded.formUnion(packagesLoaded(by: contents))
            if file.pathExtension.lowercased() == "cls", file.deletingPathExtension().lastPathComponent == documentClass {
                // A class of the project's own: what it loads counts, like article.
                documentClass = "article"
            }
            definedCommands.formUnion(DefinitionFinder.commandDefinitions(in: contents, file: file).map(\.name))
            definedEnvironments.formUnion(DefinitionFinder.environmentDefinitions(in: contents))
        }
        guard let classPackages = classes[documentClass] else { return nil }
        loaded = closure(of: loaded.union(classPackages))
        definedCommands.formUnion(DefinitionFinder.commandDefinitions(in: text, file: nil).map(\.name))
        definedEnvironments.formUnion(DefinitionFinder.environmentDefinitions(in: text))

        let string = text as NSString
        let whole = NSRange(location: 0, length: string.length)
        // Comments and verbatim text, in order, where nothing counts. Math does: \mathbb is
        // used there.
        let quiet = LaTeXTokenizer.scan(string, range: whole).tokens
            .filter { $0.kind == .comment || $0.kind == .verbatim }
            .map(\.range)
        func isQuiet(_ location: Int) -> Bool {
            var low = 0
            var high = quiet.count
            while low < high {
                let middle = (low + high) / 2
                if NSMaxRange(quiet[middle]) <= location {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            return low < quiet.count && NSLocationInRange(location, quiet[low])
        }

        var found: [String: MissingPackage] = [:]
        func note(_ package: String, _ command: String, _ range: NSRange) {
            if found[package] == nil {
                found[package] = MissingPackage(package: package, command: command, ranges: [], line: 0)
            }
            found[package]?.ranges.append(range)
        }

        for match in commandPattern.matches(in: text, range: whole) where !isQuiet(match.range.location) && !isEscaped(match.range.location, in: string) {
            let name = string.substring(with: match.range(at: 1))
            guard let packages = commands[name], !definedCommands.contains(name),
                  !packages.contains(where: loaded.contains), let package = packages.first else { continue }
            note(package, "\\" + name, match.range)
        }
        for match in environmentPattern.matches(in: text, range: whole) where !isQuiet(match.range.location) && !isEscaped(match.range.location, in: string) {
            let name = string.substring(with: match.range(at: 1))
            guard let packages = environments[name], !definedEnvironments.contains(name),
                  !packages.contains(where: loaded.contains), let package = packages.first else { continue }
            note(package, "\\begin{\(name)}", match.range)
        }
        return found.values
            .map { missing in
                var missing = missing
                missing.ranges.sort { $0.location < $1.location }
                if let first = missing.ranges.first {
                    missing.line = LineIndex.lineBreaks(in: string, range: NSRange(location: 0, length: first.location)).count + 1
                    // Named by its first use.
                    let firstCommand = string.substring(with: first)
                    missing.command = firstCommand.hasPrefix("\\begin") ? "\\begin{" + (firstCommand.split(separator: "{").last.map { String($0.dropLast()) } ?? "") + "}" : firstCommand
                }
                return missing
            }
            .sorted { ($0.ranges.first?.location ?? 0) < ($1.ranges.first?.location ?? 0) }
    }
}
