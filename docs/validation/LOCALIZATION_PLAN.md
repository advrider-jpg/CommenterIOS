# Localization Plan

`Package.swift` declares `defaultLocalization: "en"`, so English is the source
language for the current release.

Release policy:

- User-facing copy may remain English-only for the first release.
- New durable UI text must be written so it can move into String Catalogs
  without changing state or persistence behavior.
- Do not ship pseudolocalized or translated UI until a macOS/Xcode build proves
  the generated resources compile and the main flows still fit at large Dynamic
  Type.
- Do not claim localization readiness beyond English until translated String
  Catalogs and simulator screenshots exist.

Required proof before adding another locale:

- Add String Catalog resources for the affected package target or app target.
- Run a pseudolocalized simulator build.
- Capture screenshots for project list, worklist, report editor, export, backup,
  and support screens at default and large Dynamic Type.
- Record the evidence in `docs/ledgers/VALIDATION_LEDGER.md`.

Current release status: English-only, with a recorded localization plan and no
translated-locale claim. This is a no translated-locale claim release posture.
