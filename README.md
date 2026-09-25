# TexLab

TexLab is a native LaTeX editor for macOS. It is a document-based SwiftUI app that feels
like it belongs on the Mac: every window is a `.tex` document with the standard File menu
(New, Open Recent, Save, Duplicate, Rename, Revert To, versions and autosave), tabs, full
screen, and the system text system for editing, spelling and Find.

> Status: in active development. See [CHANGELOG.md](CHANGELOG.md) for what has landed.

## Features

- **LaTeX documents** — opens and saves `.tex`, `.ltx`, `.bib`, `.sty`, `.cls` and plain
  text files. The original text encoding (UTF-8, UTF-16, Windows-1252, Latin-1 or
  Mac OS Roman) is detected on open and preserved on save.
- **Templates** — File ▸ New from Template offers Article, Report, Book, Presentation
  (Beamer), Letter and Blank documents. New documents start from the Article template.
- **Source editor** — built on the Mac text system, with LaTeX syntax colouring (Xcode's
  light and dark palettes), line numbers, current line highlight, spelling that ignores
  markup, Find and Replace, and a status bar with line, column and word count.
- **Smart editing** — automatic indentation; Return after `\begin{itemize}` closes the
  environment and starts an `\item`; Return continues a list and an empty item leaves it
  (Option-Return inserts a plain line break); brackets and `$` pair automatically and
  typing an opening bracket with a selection wraps it; Tab and Shift-Tab indent lines.
- **Completion** — press Esc for commands, environments, labels, citation keys, packages,
  classes and files. Completions appear automatically after `\begin{`, `\ref{`,
  `\cite{`, `\usepackage{`, `\includegraphics{` and similar.
- **Typesetting** — ⌘R typesets with pdfLaTeX, XeLaTeX or LuaLaTeX (`% !TEX program`
  magic comment or the default engine), through latexmk when available. Typesetting also
  runs automatically after a pause in typing. Unsaved changes are included, and
  auxiliary files stay out of your folders. Multi-file projects work from any file with
  `% !TEX root = main.tex`.
- **Issue markers** — errors and warnings are marked in the editor's gutter.
- **Outline** — a sidebar tree of parts, chapters, sections, Beamer frames, figures and
  tables that follows the insertion point; select an item to jump to it.
- **Issues** — a sidebar list of errors, warnings and bad boxes; click to see the source.
- **Insert and Symbols** — toolbar menus for headings, lists, figures (from an image
  file), tables (any size), math, references and environments, plus a searchable symbol
  palette that adds `$…$` when needed.
- **Share** — share the typeset PDF, named after the document.
- **Live preview** — the PDF appears beside the editor and keeps its place as you type.
- **SyncTeX** — ⌘-click the PDF (or Show in Source) to jump to the source line, even in
  another file of the project; Show in PDF in the editor highlights the matching text.
- **Drag and drop** — drop images, `.tex` or `.bib` files on the editor to insert
  `\includegraphics`, `\input` or `\bibliography` with a path relative to the document.

- **Export and print** — File ▸ Export PDF saves the PDF anywhere; ⌘P prints it.
- **Settings** — editor appearance and behaviour, automatic typesetting, TeX location,
  default engine, latexmk, shell escape and build files.

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
| Go to Line | ⌘L |
| Bigger / Smaller Text | ⌘+ (or ⌘=) / ⌘- |
| Show/Hide Preview | ⌥⌘P |
| Show/Hide Sidebar | ⌃⌘S |
| PDF Zoom In / Out / Actual Size / Fit | ⌘> / ⌘< / ⌘0 / ⌘9 |
| Export PDF / Print | ⇧⌘E / ⌘P |

## Requirements

- macOS 27 or later, Xcode 27 or later.
- A TeX distribution for typesetting, such as [MacTeX](https://tug.org/mactex/).

## Getting started

1. Open `TexLab/TexLab.xcodeproj` in Xcode.
2. Select the **TexLab** scheme and a signing team (Signing & Capabilities).
3. **Turn off App Sandbox** for the TexLab target (see below).
4. Build and run (⌘R).

### Why App Sandbox must be off

TexLab typesets with the TeX distribution installed on your Mac, like TeXShop and
TeXstudio. A sandboxed app can't run programs from `/Library/TeX` or
`/usr/local/texlive`, and anything it runs inherits the sandbox, so TeX couldn't read the
chapters, images and bibliographies next to your document either. The Xcode template
enables the sandbox, so disable it once, by hand:

> Xcode ▸ select the **TexLab** project ▸ **TexLab** target ▸ **Signing & Capabilities** ▸
> **App Sandbox** ▸ click the trash button to remove the capability.

Hardened Runtime can stay on. If the sandbox is left on, TexLab still runs and explains in
the preview that TeX is unavailable.

### TeX distribution

Install [MacTeX](https://tug.org/mactex/) (recommended) or BasicTeX. TexLab looks in
`/Library/TeX/texbin`, `/usr/local/texlive/*/bin/*`, Homebrew and MacPorts locations; a
custom folder can be chosen in Settings. latexmk is used when it is installed (it is part
of MacTeX); otherwise TexLab runs the engine, BibTeX/Biber and makeindex itself.

## Architecture

The Xcode project uses a synchronized folder group, so any Swift file added under
`TexLab/TexLab/` is part of the app target automatically — no project file edits needed.

```
TexLab/TexLab/
├── App/            App entry point and menu commands
├── Document/       FileDocument model, file types, templates
├── Support/        Settings keys and defaults, shared helpers
├── Views/          SwiftUI window content
├── Editor/         Source editor (AppKit text system)
├── Typesetting/    TeX distribution discovery, typesetting pipeline, log parsing
└── Preview/        PDF preview and SyncTeX
```

- `TexLabDocument` is a `FileDocument` value type holding the source text and its
  encoding. File types are declared as imported UTIs in `Info.plist`
  (`org.tug.tex`, `org.tug.bib`, `org.tug.sty`, `org.tug.cls`), the identifiers shared by
  other TeX editors on macOS, so TexLab cooperates with them instead of claiming ownership.
- Settings live in `UserDefaults`. `SettingsKey` names every key and `AppSettings` holds
  the defaults, registered at launch so AppKit code and `@AppStorage` agree.
- The editor (`Editor/`) is an `NSTextView` subclass, `SourceTextView`, hosted in SwiftUI
  by `SourceEditor`. It uses TextKit 1 explicitly for precise line geometry (gutter and
  current line highlight). `LaTeXTokenizer` is a single-pass scanner shared by syntax
  colouring, spelling suppression and the word count; `SyntaxHighlighter` re-colours only
  the paragraph block around an edit, since TeX resets math mode at blank lines.
  `LineIndex` maps offsets to line numbers and is updated incrementally on every edit.
- `DocumentSession` is the per-window model (`@Observable`): editor controller, caret
  position and statistics. It grows with typesetting and preview state.
- Typesetting (`Typesetting/`): `TeXDistribution` finds TeX; `Typesetter` writes the
  editor text to a private build folder and runs latexmk or the engine directly through
  `ProcessRunner` (async `Process` wrapper with cancellation and a time limit, output
  written to a file so pipes can't stall); `LaTeXLogParser` turns the log into
  `LogEntry` values; `SourceMap` maps the paths TeX reports (build copy, overlay,
  relative paths) back to the files the user edits; `SyncTeXData` parses SyncTeX.
  `MagicComments` reads `% !TEX program` and `% !TEX root`.
- Preview (`Preview/`): `SyncPDFView` is a `PDFView` subclass that restores the clip
  view origin when a new document arrives, handles ⌘-click inverse search and highlights
  forward-search results; `PDFPreview` hosts it; `PreviewController` exposes zoom,
  layout, reveal and printing to commands. `DocumentSession+Sync` converts between
  editor lines and PDF positions through `SyncTeXData` and `SourceMap`.
- Window (`Views/`): `ContentView` arranges a `NavigationSplitView` (sidebar: outline or
  issues) whose detail is an `HSplitView` of editor and preview, with a customizable
  toolbar (`DocumentToolbar.swift`). `OutlineParser` builds the outline tree;
  `SnippetCatalog`, `SymbolCatalog` and `FormatCommand` define insertable text.
- Menus (`App/TexLabCommands.swift`) reach the focused window's `DocumentSession`
  through `FocusedValues.documentSession`; each window publishes its session with
  `focusedSceneValue`. Settings (`Views/SettingsView.swift`) are `@AppStorage` forms.
- `DocumentSession+Typesetting` queues runs, applies results, maps issues to files and
  schedules automatic typesetting. `SourceNavigator` opens other files at a line.
- The project builds with Swift's default `MainActor` isolation. Types that run off the
  main thread (file decoding, typesetting, parsing) are explicitly `nonisolated`.

## License

Copyright © 2026 Giovanni Di Nisio. All rights reserved.
