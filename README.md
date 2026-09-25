# TexLab

TexLab is a native LaTeX editor for macOS. It is a document-based SwiftUI app built on
the Mac text system and PDFKit: every window is a `.tex` document with the standard File
menu (New, Open Recent, Save, Duplicate, Rename, Move To, Revert To and versions,
autosave), window tabs and full screen. You write on the left, the typeset PDF updates on
the right, and the two are linked both ways with SyncTeX.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Features

**Writing**

- **Source editor** on the Mac text system: Find and Replace, spelling, dictation,
  services, Look Up and undo behave as in every Mac app.
- **LaTeX syntax colouring** in Xcode's light and dark palettes: commands, environments,
  math, comments, keys and verbatim text; section titles in bold. Spelling ignores markup
  and checks prose and comments only.
- **Line numbers** with the current line emphasised and issue markers; click a number to
  select the line. A subtle current line highlight.
- **Smart editing** — automatic indentation; Return after `\begin{itemize}` closes the
  environment and starts an `\item`; Return continues a list and an empty item leaves it
  (Option-Return inserts a plain line break); brackets and `$` pair automatically, and
  typing an opening bracket with a selection wraps it; Tab and Shift-Tab indent lines;
  ⌘/ comments lines.
- **Rendered math in the source** — formulas (`$…$`, `\(…\)`, `\[…\]`, `$$…$$` and
  math environments such as `equation` and `align`) are shown typeset right in the
  editor, with the document's own macros, until the insertion point enters them; then
  their source appears for editing. Click a formula to edit it. Display math is centred
  on its line like in the PDF. Formulas are drawn in the text colour, so they follow Dark
  Mode (colour set with `\color` inside a formula isn't shown). Turn it off with View ▸
  Render Math (⌃⌘M).
- **Code folding** — collapse any environment of two or more lines with the chevron
  beside its line number, or View ▸ Code Folding. A collapsed figure or table shows its
  caption, line count and a thumbnail of its image; click it to expand it again. Fold
  Figures and Tables tidies a long document in one step, and Settings can do this for
  every document you open. Folding never changes the text: moving the insertion point
  into a collapsed environment, or deleting next to it, expands it.
- **Completion** — press Esc for commands, environments, labels, citation keys (from
  `.bib` files and `\bibitem`), macros defined in the document, packages, document classes
  and files beside the document. Completions appear automatically after `\begin{`,
  `\ref{`, `\cite{`, `\usepackage{`, `\includegraphics{` and similar.
- **Insert menu and toolbar** — headings, lists, figures (from an image file), tables of
  any size, math, references, environments, spacing and breaks, fitted to the current
  indentation.
- **Format menu** — ⌘B, ⌘I and ⌘U wrap the selection in `\textbf`, `\textit` and
  `\underline` (and unwrap it again), plus emphasis, monospace, small caps and sans serif.
- **Symbols palette** — searchable Greek letters, relations, operators, arrows and text
  symbols; math symbols get `$…$` when inserted outside math.
- **Drag and drop** — drop images, `.tex` or `.bib` files onto the editor to insert
  `\includegraphics`, `\input` or `\bibliography` with a path relative to the document.
- **Templates** — File ▸ New from Template: Article, Report, Book, Presentation (Beamer),
  Letter and Blank.

**Typesetting and preview**

- **Typeset** with ⌘R, or automatically after a pause in typing. Unsaved changes are
  included, and auxiliary files stay out of your folders.
- **Engines** — pdfLaTeX, XeLaTeX or LuaLaTeX, chosen per document with Typeset ▸ Engine
  (which writes a `% !TEX program` comment other editors understand) or by default in
  Settings. latexmk is used when installed; otherwise TexLab runs BibTeX/Biber, makeindex
  and repeated passes itself.
- **Multi-file projects** — add `% !TEX root = main.tex` to a chapter and typesetting it
  typesets the whole project, including the chapter's unsaved text.
- **Live preview** that keeps its place and zoom as the document changes.
- **SyncTeX** — ⌘-click the PDF (or Show in Source) to jump to the source line, even in
  another file; ⇧⌘J (or Show in PDF) highlights the text a line produced.
- **Issues** — errors, warnings and bad boxes with file and line in the sidebar and the
  gutter; ⌘' moves through them. The full log is one click away.
- **Outline** — a sidebar tree of parts, chapters, sections, Beamer frames, figures and
  tables that follows the insertion point.
- **Share, export and print** the PDF, named after the document.
- **Encodings** — UTF-8, UTF-16, Windows-1252, Latin-1 and Mac OS Roman files are opened
  and saved in their own encoding.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Typeset / Stop | ⌘R / ⌘. |
| Show in PDF (forward search) | ⇧⌘J |
| Show in Source (inverse search) | ⌘-click in the PDF |
| Next / Previous Issue | ⌘' / ⇧⌘' |
| Show Log | ⇧⌘L |
| Clean Build Files | ⇧⌘K |
| Bold / Italic / Underline | ⌘B / ⌘I / ⌘U |
| Comment Selection | ⌘/ |
| Shift Right / Left | ⌘] / ⌘[ or Tab / ⇧Tab |
| Complete | Esc |
| Go to Line (`line` or `line:column`) | ⌘L |
| Render Math in the editor | ⌃⌘M |
| Fold / Unfold | ⌥⌘← / ⌥⌘→ |
| Fold Figures and Tables / Unfold All | ⌃⌥⌘← / ⌃⌥⌘→ |
| Bigger / Smaller Text | ⌘+ (or ⌘=) / ⌘- |
| Show/Hide Preview | ⌥⌘P |
| Show/Hide Sidebar | ⌃⌘S |
| PDF Zoom In / Out / Actual Size / Fit | ⌘> / ⌘< / ⌘0 / ⌘9 |
| Export PDF / Print | ⇧⌘E / ⌘P |

## Requirements

- macOS 27 or later, Xcode 27 or later.
- A TeX distribution — [MacTeX](https://tug.org/mactex/) is recommended; BasicTeX,
  TeX Live, Homebrew and MacPorts installations are found too.

## Getting started

1. Open `TexLab/TexLab.xcodeproj` in Xcode.
2. Choose your team under **Signing & Capabilities** for the TexLab target.
3. **Remove the App Sandbox capability** (see below).
4. Build and run (⌘R).

### Manual steps in Xcode

These are left to you on purpose, because Xcode owns them:

- **App Sandbox (required).** TexLab typesets with the TeX distribution installed on
  your Mac, like TeXShop and TeXstudio. A sandboxed app can't run programs from
  `/Library/TeX` or `/usr/local/texlive`, and anything it runs inherits the sandbox, so TeX
  couldn't read the chapters, images and bibliographies next to your documents either.
  Select the **TexLab** target ▸ **Signing & Capabilities** ▸ **App Sandbox** ▸ click the
  trash button. Hardened Runtime can stay on. If the sandbox is left on, TexLab still runs
  and explains in the preview and in Settings that TeX is blocked.
- **App icon (recommended).** `Assets.xcassets/AppIcon` is still empty; add your artwork
  there (or with Icon Composer).
- **Localization (optional).** All user-facing text uses `String(localized:)` or SwiftUI
  string keys. Add a String Catalog (File ▸ New ▸ File ▸ String Catalog) and Xcode will
  collect every string at build time.
- **Tests (optional).** The project has no test target yet. The parsers
  (`LaTeXTokenizer`, `LaTeXLogParser`, `SyncTeXData`, `OutlineParser`, `MagicComments`,
  `WordCounter`) are pure, `nonisolated` code designed to be unit-tested once a test
  target is added in Xcode.

## Architecture

The Xcode project uses a synchronized folder group, so every Swift file under
`TexLab/TexLab/` belongs to the app target automatically — no project file edits needed.

```
TexLab/TexLab/
├── App/            App entry point and menu commands
├── Document/       FileDocument, templates, per-window session, outline
├── Editor/         Source editor (AppKit text system), syntax, completion, snippets
├── Typesetting/    TeX discovery, typesetting pipeline, log parsing, SyncTeX
├── Preview/        PDF preview and navigation
├── Views/          Window layout, sidebar, toolbar, sheets, Settings
└── Support/        Settings keys and defaults, paths, text statistics
```

- **Document** — `TexLabDocument` is a `FileDocument` holding the text and its encoding.
  File types are imported UTIs in `Info.plist` (`org.tug.tex`, `.bib`, `.sty`, `.cls`),
  the identifiers other Mac TeX editors use, so TexLab cooperates rather than claiming
  ownership.
- **Session** — `DocumentSession` (`@Observable`) is the per-window model: editor and
  preview controllers, caret position, word count, outline, typesetting state and issues.
  Extensions add typesetting (`+Typesetting`) and SyncTeX navigation (`+Sync`). Menu
  commands reach the focused window's session through `FocusedValues.documentSession`.
- **Editor** — `SourceTextView` is a TextKit 1 `NSTextView` subclass hosted by
  `SourceEditor` (`NSViewRepresentable`) inside `EditorScrollView`, which sizes the text
  view to the visible area on every layout. TextKit 1 gives precise line geometry for the
  gutter (`LineNumberRulerView`) and current line highlight. `LaTeXTokenizer` is a
  single-pass scanner shared by colouring, spelling suppression and the word count;
  `SyntaxHighlighter` re-colours only the paragraph block around an edit (TeX resets math
  mode at blank lines) from the text storage's `willProcessEditing`, so fonts are fixed
  up afterwards. `LineIndex` maps offsets to lines incrementally.
- **Live preview in the editor** — `MathScanner` and `FoldScanner` (in
  `Editor/Presentation/`) find formulas and foldable environments after each pause in
  typing. `PresentationLayoutManager` shows a range as a drawing without touching the
  text, with the standard TextKit 1 technique: its first character becomes a control
  glyph as wide as the drawing, the rest get null glyphs, line breaks inside get zero
  advancement, and the line grows to fit. `MathRenderer` typesets every new formula in
  one TeX run with the `preview` package, whose `auctex` option reports each formula's
  depth so it sits on the baseline; the session (`+Math`) caches images per formula and
  preamble and renders in the background.
- **Typesetting** — `TeXDistribution` finds TeX without relying on the shell `PATH`.
  `Typesetter` writes the editor text to a build folder in
  `~/Library/Caches/com.gdinisio.TexLab/Typeset` and runs TeX in the document's folder
  through `ProcessRunner` (async `Process` wrapper with cancellation, a time limit and
  file-based output so pipes can't stall). `LaTeXLogParser` turns the log into issues;
  `SourceMap` maps the paths TeX reports (build copy, overlay, relative paths) back to the
  files you edit; `SyncTeXData` parses uncompressed SyncTeX with a byte-level parser.
- **Preview** — `SyncPDFView` (`PDFView` subclass) restores the scroll position when a
  new PDF arrives, handles ⌘-click and highlights forward-search results.
- **Imports** — the target enables `MemberImportVisibility`, so each file imports every
  framework whose members it uses (Foundation, CoreGraphics, AppKit, PDFKit, SwiftUI,
  UniformTypeIdentifiers); re-exports from another framework don't count.
- **Concurrency** — the project builds with Swift's default `MainActor` isolation. Code
  that runs off the main thread (decoding, typesetting, parsing) is explicitly
  `nonisolated` and `Sendable`; typesetting runs in a detached task and results are
  applied on the main actor.

## Implementation notes

- The log parser and SyncTeX search were validated against real TeX Live 2023 output
  (pdfTeX, XeTeX, LuaTeX logs; `synctex` command-line results).
- Typesetting uses `-interaction=nonstopmode -file-line-error -synctex=-1` and sets
  `max_print_line=10000` so log lines aren't wrapped.
- `% !TEX root` projects: the edited file's unsaved text is written to an overlay folder
  that TeX searches first (`TEXINPUTS`). Paths written as `./chapter` bypass TeX's search
  path, so for those the saved file is used.
- An untitled document is typeset in its build folder, so files it references by
  relative path are found once the document is saved.
- Rendered formulas are typeset at 10 pt in `article` with the document's preamble (the
  root file's for `% !TEX root` chapters) and scaled to the editor font. If that preamble
  doesn't typeset on its own, `amsmath` and `amssymb` are used instead. This needs the
  `preview` package, which MacTeX includes; Settings ▸ Editor says when it's missing.
- Shell escape is off by default and can be enabled in Settings for packages such as
  minted.

## License

Copyright © 2026 Giovanni Di Nisio. All rights reserved.
