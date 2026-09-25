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

## Requirements

- macOS 27 or later, Xcode 27 or later.
- A TeX distribution for typesetting, such as [MacTeX](https://tug.org/mactex/).

## Getting started

1. Open `TexLab/TexLab.xcodeproj` in Xcode.
2. Select the **TexLab** scheme and a signing team (Signing & Capabilities).
3. Build and run (⌘R).

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
- The project builds with Swift's default `MainActor` isolation. Types that run off the
  main thread (file decoding, typesetting, parsing) are explicitly `nonisolated`.

## License

Copyright © 2026 Giovanni Di Nisio. All rights reserved.
