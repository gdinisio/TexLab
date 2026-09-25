# Changelog

All notable changes to TexLab are recorded here, grouped by version. Each version
corresponds to a commit labelled `vX.Y - "…"`.

## v0.3 — Typesetting

- Typeset with ⌘R (toolbar button for now; menus arrive in a later version). The window
  subtitle shows progress and the result ("Typeset · 3 pages", "Typeset with 2 errors").
- Typesetting runs off the main thread from a copy of the editor text in a private build
  folder (`~/Library/Caches/com.gdinisio.TexLab/Typeset`), so unsaved changes are
  included, untitled documents can be typeset, and auxiliary files never clutter the
  document's folder. TeX runs in the document's folder, so relative `\input`,
  `\includegraphics` and bibliography paths work.
- Uses latexmk (`-f`, reruns only when needed) when available, otherwise runs the engine,
  BibTeX or Biber, makeindex and repeated passes directly — so BasicTeX works too.
- Engines: pdfLaTeX, XeLaTeX and LuaLaTeX, chosen with a `% !TEX program = …` magic
  comment or the default engine setting.
- `% !TEX root = main.tex` typesets a multi-file project from any of its files, using the
  unsaved text of the file being edited (placed in an overlay folder TeX searches first).
- Finds MacTeX, BasicTeX, TeX Live, Homebrew and MacPorts installations even though
  Finder-launched apps don't inherit the shell `PATH`.
- Log parser extracts errors (with file, line and the undefined command's name),
  warnings (including multi-line package warnings) and bad boxes; noise such as rerun
  notices and summaries is dropped. Validated against real pdfTeX, XeTeX and LuaTeX logs.
- Issue markers appear in the editor gutter after typesetting.
- Uncompressed SyncTeX output is parsed by a byte-level parser with a sorted line index,
  ready for source ↔ PDF navigation (validated against the `synctex` tool).
- Automatic typesetting after a pause in typing (on by default), with runs queued rather
  than overlapping, cancellation, and a five-minute safety limit per tool.

## v0.2 — Native source editor

- New source editor built on the Mac text system (TextKit 1 `NSTextView`), so Find and
  Replace, spelling, dictation, services, Look Up and undo all work as in other Mac apps.
- LaTeX syntax colouring for commands, environments, math, comments, keys and verbatim
  text, using Xcode's default light and dark palettes. Section titles appear in bold.
  Colouring is incremental — only the edited paragraph block is re-scanned.
- Spelling is checked in prose and comments only; commands, math, labels and keys are
  never marked as misspelled.
- Line number gutter with the current line emphasised, issue markers, and click-to-select.
- Subtle current line highlight.
- Smart editing: automatic indentation, `\begin{…}` + Return closes the environment
  (adding `\item` for lists), Return continues `\item` lists and leaves them on an empty
  item, bracket and `$` pairing with step-over, wrap-selection when typing an opening
  bracket, soft tabs with indent-aware delete, Tab/Shift-Tab to indent selected lines.
- Completion (Esc, or automatically after `{`) for commands, environments, labels,
  citation keys from `.bib` files and `\bibitem`s, macros defined in the document,
  packages, document classes, and files next to the document.
- Drag image, `.tex` or `.bib` files onto the editor to insert `\includegraphics`,
  `\input` or `\bibliography` with a relative path.
- Status bar showing line, column, selection length and a word count of the document
  body (commands, math and the preamble are excluded).
- Command-= also makes the editor text bigger.

## v0.1 — Document model, LaTeX file types and templates

- `TexLabDocument` now opens and saves LaTeX (`.tex`, `.ltx`, `.latex`), BibTeX (`.bib`),
  package (`.sty`), class (`.cls`) and plain text files.
- Text encoding is detected on open (UTF-8, UTF-16 with BOM, Windows-1252, Latin-1,
  Mac OS Roman) and preserved on save; text that no longer fits the original encoding is
  saved as UTF-8 instead of losing characters.
- Declared the TeX file types in `Info.plist` as imported types (`org.tug.*`) with proper
  names, so Finder and the Open panel describe them correctly. Removed the template's
  placeholder `com.example.plain-text` type.
- Added File ▸ New from Template with Article, Report, Book, Presentation, Letter and
  Blank templates. New documents start from the Article template instead of
  "Hello, world!".
- Added `SettingsKey`/`AppSettings` for settings keys and defaults, and
  `TypesettingEngine` (pdfLaTeX, XeLaTeX, LuaLaTeX).
- Organised sources into feature folders and added a `.gitignore`; Finder metadata and
  Xcode per-user state are no longer tracked.

## v0.0 — Xcode template

- Xcode macOS document app template.
