# Production MVP Plan

## Objective

Build a releasable, production-ready native iPhone-first iOS MVP of CommenterV3.

This is not a web wrapper and not a partial prototype. The MVP must preserve the
real teacher workflows and data guarantees from CommenterV3 while translating
the UI and architecture into native SwiftUI and TCA.

## MVP Includes

- Create project.
- Save project locally.
- Reopen project after app kill/relaunch.
- Edit project metadata.
- Add, edit, and delete students manually.
- Import roster from CSV, XLSX, and XLS.
- Select supported subjects.
- Preserve aggregate subject mappings.
- Enter achievement results manually.
- Import achievement results from CSV, XLSX, and XLS.
- Generate deterministic draft comments.
- Validate no unresolved placeholders.
- Edit report text manually.
- Lock reports against regeneration.
- Detect stale reports using result fingerprints.
- Export DOCX reports.
- Export XLSX review workbook.
- Export XLS review workbook.
- Export project backup JSON.
- Import web-created backup JSON.
- Import iOS-created backup JSON.
- Create recovery snapshots before destructive replace/delete.
- Provide support/diagnostics screen.
- Provide privacy and backup guidance.
- Work in airplane mode.
- Pass TestFlight and App Store release gates.

## Explicit Non-Goals

These are not deferred. They are intentionally excluded from this product shape:

- Accounts.
- Cloud sync.
- Collaboration.
- Remote AI.
- Analytics.
- Paywalls.
- Subscription management.
- Web backend.
- Remote config.
- Parent delivery workflow.

## Architecture

Use SwiftUI and The Composable Architecture.

Use `docs/OSS_DEPENDENCY_POLICY.md` as the binding dependency and custom-code
policy. The MVP should use mature OSS packages and Apple-native APIs for
generic infrastructure. Custom code is a last resort for Commenter-specific
behavior or small adapters around approved dependencies.

The root feature tree should be:

```text
AppFeature
  ProjectsFeature
    ProjectCreateFeature
  WorklistFeature
  ProjectFeature
    RosterFeature
    SubjectSetupFeature
    ResultsFeature
    GenerationFeature
    ReviewExportFeature
    BackupFeature
  ImportFeature
  SupportFeature
    DataStatusFeature
    StorageStatusFeature
    PrivacyFeature
    DiagnosticsFeature
```

Every external operation must be behind a TCA dependency client:

- `DatasetClient`
- `CommentEngineClient`
- `ProjectStoreClient`
- `BackupClient`
- `SpreadsheetClient`
- `DocumentExportClient`
- `FileImportClient`
- `ShareClient`
- `StorageHealthClient`
- `ClockClient`
- `UUIDClient`
- `FileSystemClient`

Reducers express intent and handle results. Reducers must not directly call file
IO, generation, document picker, or share APIs.

## Package Boundaries

`CommenterDomain`

Pure value models and validation types. No SwiftUI, no file IO, no TCA.

`CommentEngine`

Production dataset loading/validation, subject mapping, generation,
placeholder resolution, readiness diagnostics, and parity tests.

`CommenterPersistence`

Local project storage, revision conflicts, read-after-write verification,
fingerprints, recovery snapshots, draft autosave, and metadata index. SQLite
metadata/index work must use GRDB once dependency migration begins; direct
`sqlite3` code is not the default architecture.

`CommenterImportExport`

CSV/XLSX/XLS import, backup JSON import/export, DOCX/XLSX/XLS export, and file
payload construction. Generic CSV, XLSX, XLS/OLE, DOCX, ZIP/OOXML, and workbook
handling must use the approved dependencies in `docs/OSS_DEPENDENCY_POLICY.md`
unless a decision-ledger exception is recorded.

`DesignSystem`

Owned SwiftUI components. Native HIG by default. OSS visual helpers only behind
owned wrappers. Do not hand-roll generic UI primitives when native SwiftUI,
SwiftUIX, or SwiftUI-Introspect can cover the need.

`CommenterTestSupport`

Fixtures, golden-output helpers, dependency mocks, generated test data, and
cross-platform parity fixtures.

## Persistence

Use canonical JSON project files plus a SQLite metadata/index layer.

Canonical storage layout:

```text
Application Support/
  projects/
    index.sqlite
    <project-id>/
      project.json
      recovery/
        <snapshot-id>.json
  datasets/
    comment-engine-cache.json
  exports-temp/
```

Save must follow this sequence:

1. Validate project shape.
2. Normalize project for persistence.
3. Check expected revision.
4. Create recovery snapshot if needed.
5. Write temp JSON.
6. Atomic replace.
7. Update SQLite index in transaction.
8. Read back canonical JSON.
9. Recompute fingerprint.
10. Compare fingerprint.
11. Only then emit save success.

## Production Dataset

The app must bundle the real production `comment-engine.json`.

On launch:

1. Load the bundled dataset.
2. Validate the schema and production data.
3. Compute a dataset hash.
4. Expose diagnostics in Support.
5. Block generation if the dataset is missing or invalid.

Sample fixtures are test-only and must never be wired into the production app.

## Import

CSV, XLSX, and XLS imports are required.

Import behavior:

- Parse locally.
- Enforce file size limits.
- Enforce row limits.
- Normalize headers and aliases.
- Reject duplicate headers.
- Validate every row.
- Show preview and errors before mutation.
- Commit all-or-nothing only after user confirmation.
- Save and verify after commit.
- Only then show import success.

Invalid import files must leave the project unchanged.

## Export

DOCX, XLSX, and XLS exports are required.

Export behavior:

1. Run readiness validation.
2. Block missing generated reports, missing results, stale results, and
   placeholders.
3. Generate a local file.
4. Verify file exists and size is greater than zero.
5. Present native iOS share/file export.
6. Distinguish prepared, saved, shared, cancelled, and failed.
7. Never report cancellation as success.

DOCX must open in Word and Pages. XLSX and XLS must open in target spreadsheet
apps. Review exports must omit private notes, internal IDs, raw variant data,
and persistence fingerprints.

## UX

Top-level tabs:

1. Projects
2. Worklist
3. Support

Create, import, export, and backup are actions, not tabs.

The app should be project-centered:

```text
Projects -> Project Home -> focused task screens
```

Primary project sections:

- Roster
- Subjects
- Results
- Draft comments
- Export
- Backups
- Settings

The iPhone workflow should avoid dense table editing. Use searchable lists,
focused editors, previews, filters, next-item navigation, and clear save states.

## Accessibility

Required:

- Dynamic Type through accessibility sizes.
- VoiceOver labels for icon-only controls.
- Minimum 44 point targets.
- No color-only readiness signals.
- Clear form focus order.
- Reduced Motion support.
- High contrast checks.
- Long names wrap without hiding critical information.
- Import/export progress and cancellation states are announced.

## QA and Release Gates

Required CI:

- format check
- Swift compile
- `swift test`
- `xcodebuild test`
- TCA reducer tests
- fixture parity tests
- import/export tests
- no-network static scan
- dependency/license audit
- OSS dependency policy audit
- privacy manifest validation

Required release checks:

- full simulator matrix
- physical device matrix
- archive build
- TestFlight upload
- App Store metadata review
- privacy review
- export-open verification

Release blockers:

- fake save/import/export/generation success
- unresolved placeholder in generated/exported report
- sample data fallback
- network transmission of student/project/report data
- App Store privacy mismatch
- unsupported XLS path pretending to work
- DOCX that does not open in Word/Pages
- XLSX/XLS that does not open in target apps
- backup import data loss
- destructive replace without recovery snapshot
- save failure after app relaunch
- crash in core workflows
- small-iPhone unusability
- inaccessible primary controls
- CI red in release lane

## Implementation Milestones

1. Source audit and golden fixtures.
2. New repo bootstrap.
3. Domain model port.
4. Production dataset loader and validator.
5. Comment engine port.
6. Persistence foundation.
7. App shell and navigation.
8. Core teacher workflow UI.
9. Spreadsheet import parity.
10. Backup compatibility.
11. Report export parity.
12. Design system and iPhone polish.
13. QA, CI, and release gates.
14. TestFlight and App Store package.

## First Ten Implementation Days

Day 1:

- Scaffold SwiftUI/TCA app.
- Strip sample code.
- Add local package skeleton.
- Add CI skeleton.

Day 2:

- Add domain models.
- Add fixture loader.
- Add web backup fixture.
- Build first model tests.

Day 3:

- Bundle production dataset.
- Decode and validate basic structure.
- Add dataset diagnostics.

Day 4:

- Port subject mapping.
- Port placeholder detection.
- Add parity tests.

Day 5:

- Port minimal generator slice.
- Generate one known report.
- Compare to web fixture.

Day 6:

- Implement canonical JSON project store.
- Add atomic write, readback, and fingerprint verification.

Day 7:

- Add Projects shell.
- Add create project.
- Save and reopen manually in simulator.

Day 8:

- Add roster manual entry.
- Add subject selection.
- Add result entry.

Day 9:

- Build CSV import path.
- Add all-or-nothing import preview.

Day 10:

- Prove XLSX, XLS, and DOCX implementation choices with fixtures.
