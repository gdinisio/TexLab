# Changelog

All notable changes to TexLab are recorded here, grouped by version. Each version
corresponds to a commit labelled `vX.Y - "…"`.

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
