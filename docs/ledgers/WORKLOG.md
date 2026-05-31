# Worklog

Append material work history here. Keep entries short, dated, and factual.

## 2026-05-31 - OSS dependency policy guardrail

- Added `docs/OSS_DEPENDENCY_POLICY.md` as the binding OSS/native-first package
  list and custom-code limit.
- Updated `AGENTS.md`, core rules, MVP plan, architecture decision, handoff, and
  decision ledger to force dependency-policy review before generic
  infrastructure work.
- Preserved worker-current package choices where possible:
  `swift-composable-architecture`, `CodableCSV`, `CoreXLSX`, and `OLEKit`.

## 2026-05-30 - Planning repo seeded

- Created `C:\CommenterIOS`.
- Initialized git on `main`.
- Added README, chat handoff, production MVP plan, scaffold decision, source
  truth map, initial backlog, and `.gitignore`.
- Committed `ab754be` (`Seed native iOS planning repo`).
- Added `.gitattributes` to pin line endings.
- Committed `461d7fd` (`Add line ending policy`).

## 2026-05-30 - Guardrails and ledgers added

- Added `AGENTS.md`.
- Added `docs/ledgers/CORE_RULES.md`.
- Added `docs/ledgers/PROJECT_LEDGER.md`.
- Added `docs/ledgers/DATA_LEDGER.md`.
- Added `docs/ledgers/DECISIONS_LEDGER.md`.
- Added `docs/ledgers/VALIDATION_LEDGER.md`.
- Added `docs/ledgers/WORKLOG.md`.
- Established strict no-fake-state, source-truth, line-ending, and ledger update
  discipline before app scaffolding.

## 2026-05-31 - Initial SwiftUI/TCA scaffold slice

- Created `codex/ios-mvp-scaffold`.
- Added Swift package targets for domain, comment engine, persistence,
  import/export, design system, app feature, app entry, and test support.
- Added a root SwiftUI/TCA app surface that loads the bundled production
  dataset and visibly disables unimplemented project/import/export workflows.
- Copied production `comment-engine.json` from live `C:\Commenterv3` into
  `Sources/CommentEngine/Resources/`.
- Added dataset validation/hash code, placeholder-resolution helpers, domain
  models/rules, initial tests, privacy manifest, and macOS CI skeleton.
- Added backup envelope and project fingerprint foundation from live
  CommenterV3 `backup.ts` and `persistence-fingerprint.ts`.
- Tightened Support dataset status wording to avoid overclaiming full dataset
  contract validation before parity work is complete.
- Ported the CommenterV3 dataset validation diagnostics contract from
  `comment-engine-contract.ts`, including rejection counts, uniqueness rules,
  and placeholder counts.
- Ported subject mapping and aggregate-subject focus requirements from
  `subject-mapping.ts`.
- Added the file-backed project store foundation with canonical JSON writes,
  SQLite project metadata index, revision conflicts, read-after-write
  verification, fingerprints, and recovery snapshots based on live CommenterV3
  persistence sources.
- Added `CommenterPersistence` to the `CommenterImportExport` target dependency
  list because backup envelope code imports persistence fingerprint support.
- Added a core comment-generation slice from live CommenterV3 `generator.ts`,
  `result-fingerprint.ts`, and readiness sources: subject resolution,
  achievement-level blocking, placeholder blocking, uniqueness-aware variant
  selection, component assembly fallback, usage snapshots, and generation
  fingerprints.
- Added report-readiness and language-lint gates from live CommenterV3
  `report-readiness.ts` and `report-language-lint.ts` so missing reports,
  unresolved placeholders, stale fingerprints, aggregate subject focus gaps,
  and blocking language issues are not reported as export-ready.
- Added a strict CSV parser foundation from live CommenterV3 `csv.ts`,
  including header normalization/lookup, duplicate and blank header rejection,
  row-count and row-width checks, escaped quotes, unterminated quote errors,
  and formula-safe CSV serialization helpers.
- Added CSV roster/results import validation from live CommenterV3
  `import-validation.ts`, including all-or-nothing row rejection, roster
  duplicate checks, safe ID generation checks, aggregate-subject focus
  validation, selected-subject matching, duplicate result blocking, text/context
  validation, and focus-library canonicalization.
- Added CSV template helpers from live CommenterV3 `csv-templates.ts` for
  teacher-facing roster/results template rows and CSV-only document metadata;
  XLSX/XLS template export remains explicitly unsupported in this helper layer.
- Tightened generation fingerprint normalization toward live CommenterV3
  `result-fingerprint.ts` and `report-context-fields.ts`, including stable
  selected-subject ordering for Swift dictionaries and source-style trailing
  punctuation handling.
- Tightened stored project validation toward live CommenterV3
  `project-validation.ts` for duplicate result/report keys, selected subject
  entries, and report context fields while keeping draft content validation in
  readiness/export gates rather than raw persistence shape.
- Recorded that local Swift/Xcode validation is unavailable on this Windows
  checkout because the Apple toolchain and Xcode project/workspace are absent.
- Added a backup JSON file workflow helper that writes backup envelopes
  atomically, verifies a non-empty local file, reads the file back, and parses
  the checksum before returning a prepared backup file.
- Tightened backup import parsing to validate the raw decoded project before
  persistence reconciliation so invalid web backups are rejected rather than
  silently cleaned up before verification.
- Re-ran the import/export manifest guardrail: `CommenterImportExport` imports
  `CommenterDomain`, `CommentEngine`, and `CommenterPersistence`, and
  `Package.swift` declares all three target dependencies.
- Rechecked Support dataset copy; loaded-state wording remains
  "Bundled dataset loaded" and "Basic structural checks passed" rather than
  claiming full user-visible dataset validity.
- Added report export preparation helpers from live CommenterV3 `export.ts`
  and `spreadsheet.ts`: export-readiness gating, unresolved-placeholder
  blocking, DOCX packet payload preparation, privacy-safe review workbook rows,
  spreadsheet formula guarding, paragraph splitting, student filtering, and
  source-style report export filenames. This is not yet a DOCX/XLSX/XLS writer
  surface.
- Added pure project import commit helpers based on live CommenterV3 import UI
  behavior: roster imports prepare an appended project, result imports merge by
  student and subject, empty/invalid imports are rejected, existing invalid
  projects are rejected before applying import data, and no save success is
  claimed before the persistence layer can save and verify.
- Wired the app shell to real local project storage through a TCA
  `ProjectStoreClient`: the Projects tab now loads verified local project
  summaries, enables Create Project only after storage loads, saves a minimal
  valid project through `FileProjectStore`, and reports success only after the
  read-after-write verified save returns.
- Added AppFeature reducer tests for dataset/project summary loading, verified
  create-project success after the store response, and create failure without
  appending a project; local Swift execution remains blocked on this Windows
  checkout.
- Added a real XLSX review workbook preparation helper: it writes an OOXML ZIP
  package with a `Reports` sheet from export-ready review rows, verifies
  required package entries after writing, keeps formula guarding and privacy-safe
  row omission, and explicitly rejects `.xls`/`.docx` rather than renaming XLSX
  bytes as another format.
- Added a real DOCX report document preparation helper: it writes a
  WordprocessingML OOXML ZIP package from export-ready report packets, includes
  title/student/subject/achievement text, page breaks, header/footer/page field
  parts, verifies required package entries and core document XML after writing,
  and explicitly rejects non-DOCX formats rather than routing them through this
  helper.
- Re-ran the import/export manifest dependency guardrail after the monitor
  report: `CommenterImportExport` source imports are covered by
  `Package.swift`, including `CommenterPersistence` for backup fingerprint
  verification, and available hygiene/dataset checks remained clean while local
  Swift execution stayed blocked by the missing Swift toolchain.
- Added a narrow legacy XLS review workbook preparation helper for the report
  review export path. It writes an OLE compound file with a BIFF workbook stream
  for the `Reports` sheet, verifies the Workbook stream and expected header
  labels after writing, and tests that `.xls` output is not a renamed OOXML ZIP
  file. This is not yet target-app open validation or full XLS import/export
  release parity.
- Added a minimal native iOS app host project, `CommenterIOS.xcodeproj`, with a
  shared `CommenterIOS` scheme. The app target compiles the SwiftUI app entry
  and links the local `AppFeature` package product; XcodeBuildMCP discovery now
  finds the project, while scheme/build/test validation still requires
  `xcodebuild` on macOS.

## 2026-05-31 - Dependency audit posture recorded

- Added `docs/dependencies/DEPENDENCY_AUDIT.md` documenting the minimal
  OSS/native posture, current package/license roles, and why TCA, CodableCSV,
  CoreXLSX, and OLEKit fit offline/local-first use.
- Recorded the decision not to add SwiftUIX or SwiftUI Introspect yet because no
  native SwiftUI/HIG wrapper need has been proven.
- Recorded the remaining legacy `.xls` BIFF decoding/writing risk without
  claiming production parity is complete.
