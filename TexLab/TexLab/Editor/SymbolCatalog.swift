//
//  SymbolCatalog.swift
//  TexLab
//

import Foundation

/// A symbol in the palette: how it looks, the LaTeX that produces it, and a searchable name.
nonisolated struct LaTeXSymbol: Identifiable, Hashable, Sendable {
    var id: String { command }
    let glyph: String
    let command: String
    let name: String
    /// Whether the command only works in math mode.
    let isMath: Bool
    /// A package the command needs, if any.
    let package: String?

    init(_ glyph: String, _ command: String, _ name: String, isMath: Bool = true, package: String? = nil) {
        self.glyph = glyph
        self.command = command
        self.name = name
        self.isMath = isMath
        self.package = package
    }
}

nonisolated struct SymbolCategory: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let symbols: [LaTeXSymbol]
}

nonisolated enum SymbolCatalog {
    static let categories: [SymbolCategory] = [
        SymbolCategory(title: "Greek", symbols: [
            LaTeXSymbol("α", "\\alpha", "alpha"), LaTeXSymbol("β", "\\beta", "beta"),
            LaTeXSymbol("γ", "\\gamma", "gamma"), LaTeXSymbol("δ", "\\delta", "delta"),
            LaTeXSymbol("ϵ", "\\epsilon", "epsilon"), LaTeXSymbol("ε", "\\varepsilon", "varepsilon"),
            LaTeXSymbol("ζ", "\\zeta", "zeta"), LaTeXSymbol("η", "\\eta", "eta"),
            LaTeXSymbol("θ", "\\theta", "theta"), LaTeXSymbol("ϑ", "\\vartheta", "vartheta"),
            LaTeXSymbol("ι", "\\iota", "iota"), LaTeXSymbol("κ", "\\kappa", "kappa"),
            LaTeXSymbol("λ", "\\lambda", "lambda"), LaTeXSymbol("μ", "\\mu", "mu"),
            LaTeXSymbol("ν", "\\nu", "nu"), LaTeXSymbol("ξ", "\\xi", "xi"),
            LaTeXSymbol("π", "\\pi", "pi"), LaTeXSymbol("ϖ", "\\varpi", "varpi"),
            LaTeXSymbol("ρ", "\\rho", "rho"), LaTeXSymbol("ϱ", "\\varrho", "varrho"),
            LaTeXSymbol("σ", "\\sigma", "sigma"), LaTeXSymbol("ς", "\\varsigma", "varsigma"),
            LaTeXSymbol("τ", "\\tau", "tau"), LaTeXSymbol("υ", "\\upsilon", "upsilon"),
            LaTeXSymbol("ϕ", "\\phi", "phi"), LaTeXSymbol("φ", "\\varphi", "varphi"),
            LaTeXSymbol("χ", "\\chi", "chi"), LaTeXSymbol("ψ", "\\psi", "psi"),
            LaTeXSymbol("ω", "\\omega", "omega"),
            LaTeXSymbol("Γ", "\\Gamma", "capital gamma"), LaTeXSymbol("Δ", "\\Delta", "capital delta"),
            LaTeXSymbol("Θ", "\\Theta", "capital theta"), LaTeXSymbol("Λ", "\\Lambda", "capital lambda"),
            LaTeXSymbol("Ξ", "\\Xi", "capital xi"), LaTeXSymbol("Π", "\\Pi", "capital pi"),
            LaTeXSymbol("Σ", "\\Sigma", "capital sigma"), LaTeXSymbol("Υ", "\\Upsilon", "capital upsilon"),
            LaTeXSymbol("Φ", "\\Phi", "capital phi"), LaTeXSymbol("Ψ", "\\Psi", "capital psi"),
            LaTeXSymbol("Ω", "\\Omega", "capital omega"),
        ]),
        SymbolCategory(title: "Relations", symbols: [
            LaTeXSymbol("≤", "\\leq", "less than or equal"), LaTeXSymbol("≥", "\\geq", "greater than or equal"),
            LaTeXSymbol("≠", "\\neq", "not equal"), LaTeXSymbol("≈", "\\approx", "approximately"),
            LaTeXSymbol("≡", "\\equiv", "equivalent"), LaTeXSymbol("∼", "\\sim", "similar"),
            LaTeXSymbol("≃", "\\simeq", "similar or equal"), LaTeXSymbol("≅", "\\cong", "congruent"),
            LaTeXSymbol("∝", "\\propto", "proportional"), LaTeXSymbol("≪", "\\ll", "much less than"),
            LaTeXSymbol("≫", "\\gg", "much greater than"), LaTeXSymbol("∈", "\\in", "element of"),
            LaTeXSymbol("∉", "\\notin", "not element of"), LaTeXSymbol("∋", "\\ni", "contains"),
            LaTeXSymbol("⊂", "\\subset", "subset"), LaTeXSymbol("⊃", "\\supset", "superset"),
            LaTeXSymbol("⊆", "\\subseteq", "subset or equal"), LaTeXSymbol("⊇", "\\supseteq", "superset or equal"),
            LaTeXSymbol("⊥", "\\perp", "perpendicular"), LaTeXSymbol("∥", "\\parallel", "parallel"),
            LaTeXSymbol("∣", "\\mid", "divides"), LaTeXSymbol("⊢", "\\vdash", "proves"),
            LaTeXSymbol("⊨", "\\models", "models"), LaTeXSymbol("≺", "\\prec", "precedes"),
            LaTeXSymbol("≻", "\\succ", "succeeds"), LaTeXSymbol("≐", "\\doteq", "approaches the limit"),
        ]),
        SymbolCategory(title: "Operators", symbols: [
            LaTeXSymbol("±", "\\pm", "plus or minus"), LaTeXSymbol("∓", "\\mp", "minus or plus"),
            LaTeXSymbol("×", "\\times", "times"), LaTeXSymbol("÷", "\\div", "divide"),
            LaTeXSymbol("·", "\\cdot", "dot"), LaTeXSymbol("∘", "\\circ", "compose"),
            LaTeXSymbol("∗", "\\ast", "asterisk"), LaTeXSymbol("⊕", "\\oplus", "direct sum"),
            LaTeXSymbol("⊗", "\\otimes", "tensor product"), LaTeXSymbol("∩", "\\cap", "intersection"),
            LaTeXSymbol("∪", "\\cup", "union"), LaTeXSymbol("∧", "\\wedge", "and"),
            LaTeXSymbol("∨", "\\vee", "or"), LaTeXSymbol("∖", "\\setminus", "set minus"),
            LaTeXSymbol("∑", "\\sum", "sum"), LaTeXSymbol("∏", "\\prod", "product"),
            LaTeXSymbol("∐", "\\coprod", "coproduct"), LaTeXSymbol("∫", "\\int", "integral"),
            LaTeXSymbol("∬", "\\iint", "double integral", package: "amsmath"), LaTeXSymbol("∮", "\\oint", "contour integral"),
            LaTeXSymbol("⋃", "\\bigcup", "big union"), LaTeXSymbol("⋂", "\\bigcap", "big intersection"),
            LaTeXSymbol("∂", "\\partial", "partial"), LaTeXSymbol("∇", "\\nabla", "nabla"),
            LaTeXSymbol("√", "\\sqrt{}", "square root"),
        ]),
        SymbolCategory(title: "Arrows", symbols: [
            LaTeXSymbol("→", "\\to", "to"), LaTeXSymbol("←", "\\leftarrow", "left arrow"),
            LaTeXSymbol("↔", "\\leftrightarrow", "left right arrow"), LaTeXSymbol("⇒", "\\Rightarrow", "implies"),
            LaTeXSymbol("⇐", "\\Leftarrow", "implied by"), LaTeXSymbol("⇔", "\\Leftrightarrow", "if and only if"),
            LaTeXSymbol("↦", "\\mapsto", "maps to"), LaTeXSymbol("⟶", "\\longrightarrow", "long right arrow"),
            LaTeXSymbol("⟹", "\\Longrightarrow", "long implies"), LaTeXSymbol("⟺", "\\iff", "iff"),
            LaTeXSymbol("↑", "\\uparrow", "up arrow"), LaTeXSymbol("↓", "\\downarrow", "down arrow"),
            LaTeXSymbol("↗", "\\nearrow", "north east arrow"), LaTeXSymbol("↘", "\\searrow", "south east arrow"),
            LaTeXSymbol("↪", "\\hookrightarrow", "hook right arrow"), LaTeXSymbol("⇝", "\\leadsto", "leads to", package: "amssymb"),
        ]),
        SymbolCategory(title: "Miscellaneous", symbols: [
            LaTeXSymbol("∞", "\\infty", "infinity"), LaTeXSymbol("∀", "\\forall", "for all"),
            LaTeXSymbol("∃", "\\exists", "exists"), LaTeXSymbol("∄", "\\nexists", "does not exist", package: "amssymb"),
            LaTeXSymbol("∅", "\\emptyset", "empty set"), LaTeXSymbol("¬", "\\neg", "not"),
            LaTeXSymbol("ℕ", "\\mathbb{N}", "natural numbers", package: "amssymb"),
            LaTeXSymbol("ℤ", "\\mathbb{Z}", "integers", package: "amssymb"),
            LaTeXSymbol("ℚ", "\\mathbb{Q}", "rational numbers", package: "amssymb"),
            LaTeXSymbol("ℝ", "\\mathbb{R}", "real numbers", package: "amssymb"),
            LaTeXSymbol("ℂ", "\\mathbb{C}", "complex numbers", package: "amssymb"),
            LaTeXSymbol("ℓ", "\\ell", "ell"), LaTeXSymbol("ℏ", "\\hbar", "h bar"),
            LaTeXSymbol("ℜ", "\\Re", "real part"), LaTeXSymbol("ℑ", "\\Im", "imaginary part"),
            LaTeXSymbol("ℵ", "\\aleph", "aleph"), LaTeXSymbol("…", "\\ldots", "ellipsis", isMath: false),
            LaTeXSymbol("⋯", "\\cdots", "centered ellipsis"), LaTeXSymbol("⋮", "\\vdots", "vertical ellipsis"),
            LaTeXSymbol("⋱", "\\ddots", "diagonal ellipsis"), LaTeXSymbol("′", "\\prime", "prime"),
            LaTeXSymbol("∠", "\\angle", "angle"), LaTeXSymbol("△", "\\triangle", "triangle"),
            LaTeXSymbol("□", "\\square", "square", package: "amssymb"), LaTeXSymbol("∴", "\\therefore", "therefore", package: "amssymb"),
            LaTeXSymbol("⟨", "\\langle", "left angle bracket"), LaTeXSymbol("⟩", "\\rangle", "right angle bracket"),
        ]),
        SymbolCategory(title: "Text", symbols: [
            LaTeXSymbol("§", "\\S", "section sign", isMath: false), LaTeXSymbol("¶", "\\P", "pilcrow", isMath: false),
            LaTeXSymbol("©", "\\copyright", "copyright", isMath: false),
            LaTeXSymbol("®", "\\textregistered", "registered", isMath: false),
            LaTeXSymbol("™", "\\texttrademark", "trademark", isMath: false),
            LaTeXSymbol("†", "\\dag", "dagger", isMath: false), LaTeXSymbol("‡", "\\ddag", "double dagger", isMath: false),
            LaTeXSymbol("•", "\\textbullet", "bullet", isMath: false),
            LaTeXSymbol("–", "--", "en dash", isMath: false), LaTeXSymbol("—", "---", "em dash", isMath: false),
            LaTeXSymbol("“", "``", "opening quotes", isMath: false), LaTeXSymbol("”", "''", "closing quotes", isMath: false),
            LaTeXSymbol("€", "\\texteuro", "euro", isMath: false), LaTeXSymbol("£", "\\pounds", "pound", isMath: false),
            LaTeXSymbol("°", "\\textdegree", "degree", isMath: false),
        ]),
    ]
}
