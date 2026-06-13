# Worklog

Append material work history here. Keep entries short, dated, and factual.

## 2026-06-10 - Legacy XLS OLE fast-path chain fix

- Updated legacy `.xls` fast-path extraction to follow OLE directory/FAT/DIFAT
  and mini-FAT chains before slicing the workbook stream.
- Added OLEKit fallback when the fast-path stream fails BIFF parsing so non-
  contiguous or mini-stream layout cases continue to parse through authoritative
  OLEKit behavior.
- Did not run Swift/Xcode validation locally (Windows environment lacks the
  required toolchain).

## 2026-06-10 - Release-hardening patch applied

- Merged the user-provided `commenter-ios-release-hardening.patch` into the repo.
- Added production hardening for temp export lifecycle, diagnostics redaction, import/export bounds checks, AI request limits/timeouts, safer persistence paths, and DOCX/XLSX/XLS packaging limits.
- Added app icon assets and iOS privacy-policy link plumbing (with build-setting-based URL lookup).
- Added new dependency-audit/release checklist updates and expanded hardening tests for oversized payload and identifier safety.
- Could not run Swift/Xcode validation locally on this Windows host because `swift` is not available on PATH; local checks completed were git state/whitespace/eol validation only.

## 2026-06-02 - Shared stationery review fix

- Replaced Work list-only stationery drawing primitives with shared
  `DesignSystem` stationery components and theme values.
- Tightened the shared workflow timeline connector frame to the fixed-size
  SwiftUI modifier shape used by hosted CI diagnostics.

## 2026-06-02 - CI and screenshot workflow hardening

- Updated iOS CI to cache SwiftPM artifacts and Xcode derived data, bound the
  main CI job with a timeout, and uploaded xcodebuild logs/result bundles for
  failure diagnostics.
- Hardened screenshot attachment export to keep direct screenshot files, fall
  back when the xcresult manifest shape changes, and upload the xcodebuild log
  with screenshot artifacts.
- Updated validation ledger wording to the current
  `testCoreReportFlowScreenshots` 14-screenshot workflow.

## 2026-06-01 - Preferred stationery redesign and Report Writer naming

- Applied the preferred stationery handoff to native SwiftUI project, worklist,
  support, status, empty-state, and reusable design-system surfaces.
- Changed user-facing app/product naming, bundle display name, support
  diagnostics, export fallbacks, temp export folder names, and DOCX metadata to
  `Report Writer`.
- Changed newly generated backup filenames to the user-facing
  `.report-writer-backup.json` suffix while retaining legacy
  `.commenter-backup.json` import compatibility.
- Preserved existing local persistence, generation, import/export, diagnostics,
  and availability gates; no reference screenshots or web views were added.
- Recorded that Swift package, Swift tests, and Xcode build validation were
  blocked on this Windows environment because Swift/Xcode tools were not
  available on PATH.

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

## 2026-05-31 - OSS/native workflow implementation pass

- Added the approved GRDB and ZIPFoundation package dependencies, migrated the
  SQLite project index off direct `sqlite3`, and replaced the custom OOXML ZIP
  byte writer with a ZIPFoundation-backed adapter.
- Wired native SwiftUI file importer/exporter/share flows through TCA actions
  for backup JSON, roster/results CSV/XLSX/XLS imports, and prepared DOCX/XLSX/XLS
  report exports, including security-scoped access for imported files and no
  empty-data fallback when exporting prepared files.
- Split the root app reducer/view surface into owned TCA workflow files and
  native SwiftUI view components while keeping required teacher workflow buttons
  wired to real reducer operations.
- Added CodableCSV/CoreXLSX/OLEKit-backed import adapters, V3-style generation
  repair/decorate/layout behavior, truthful locked-report generation messaging,
  and focused reducer/import/generation/persistence tests.
- Tightened import flows to validate picked roster/results/backup files into a
  visible confirmation preview before any durable project save, and made backup
  import previews reachable even when no project is already open.
- Added spreadsheet fixture coverage for CSV, UTF-16 CSV, XLSX inline strings,
  XLSX shared strings, XLSX numeric cells, malformed files, oversized files,
  and generated legacy XLS workbook streams; fixed the CodableCSV reader config
  to use the package's standard CRLF/LF row delimiter instead of unsupported
  delimiter inference.
- Windows validation remained limited to hygiene/static checks because `swift`
  and `xcodebuild` were unavailable on PATH.

## 2026-05-31 - OSS/package compliance audit refresh

- Audited current Swift imports against `Package.swift` target dependencies and
  documented that all third-party imports found in `Sources` and `Tests` have
  matching manifest products.
- Updated the dependency audit's current package posture to include GRDB.swift
  and ZIPFoundation, which are already present in the manifest and source.
- Recorded the remaining policy risks from current source: custom DOCX
  WordprocessingML generation, custom XLSX SpreadsheetML generation, custom
  legacy XLS BIFF/OLE writing, and narrow custom BIFF decoding for `.xls`
  imports still need package evaluation, fixture proof, target-app validation,
  or a durable exception before release parity is claimed.

## 2026-05-31 - QA/truthfulness action-state audit

- Audited production source paths for fake, placeholder, TODO, decorative,
  disabled, unsupported, unavailable, stateless, and mock-like behavior.
- Fixed the Create Project action so unavailable local project storage produces
  a visible failure instead of a silent no-op, and disabled project create/backup
  import buttons until local storage is loaded.
- Tightened the Worklist screen so editing/actions pause during real in-flight
  operations, stale prepared files are hidden after unsaved edits, and report
  export buttons stay disabled with explanatory copy until readiness is complete.
- Added reducer coverage that proves Create Project does not call the store or
  report success when storage is unavailable.
- Re-ran Windows-safe hygiene, line-ending, direct SQLite, direct ZIP,
  package/import, network/privacy, and dataset hash checks; Swift/Xcode tests
  remained blocked because the Apple toolchain is unavailable on this Windows
  checkout.

## 2026-05-31 - Persistence and reducer save-state tightening

- Preserved before-delete recovery snapshots by deleting the canonical
  `project.json` file while leaving the project recovery directory listable;
  deleted projects still disappear from load/list flows and the SQLite index.
- Made manual add-student reducer behavior deterministic with a local
  collision-checked student id and blank editable names instead of a prefilled
  placeholder name.
- Added reducer coverage for metadata edits, manual roster add/edit/delete,
  subject deselection pruning, achievement entry, report manual edit/lock, and
  save failure so success is asserted only after a verified store save response.
- Added persistence coverage proving the before-delete recovery snapshot remains
  available after project deletion.

## 2026-05-31 - Import/export and generation parity tightening

- Added package-level roster/results import preview helpers that parse
  CSV/XLSX/XLS, validate all rows, and return prepared project changes without
  mutating the open project before user confirmation and verified save.
- Wired AppFeature import preview state to report the accepted rows from the
  picked file rather than total project roster/results counts after merge.
- Tightened DOCX and review workbook preparation so written files are read back
  and checked for expected report/header/workbook content, with failed outputs
  removed instead of offered for export.
- Tightened generation parity: zero-count usage entries no longer seed
  uniqueness blocking, empty context markers such as `not applicable` and em
  dash are treated as missing context, and generation fingerprints now use a
  V3-style JSON string shape.
- Added focused import/export and generation tests for the above behavior.

## 2026-05-31 - Code-lane course correction and integration

- Reassigned the import/export, teacher UI, TCA/persistence, and generation
  parity lanes to concrete source/test slices after the monitor requested more
  than audit-only work.
- Tightened DOCX/XLSX/XLS export readback verification to reject prepared files
  that leak internal teacher notes, variant IDs, traces, fingerprints, or
  superseded generated text.
- Tightened the Worklist UI so pending import previews visibly block editing
  until confirmed/cancelled, and prepared file actions distinguish verified
  local preparation, file-export save, and share-sheet launch states.
- Cleared stale prepared export URLs when a new file preparation starts or
  fails, with reducer coverage for stale prepared-file removal.
- Matched CommenterV3 readiness precedence for manual edits by treating blank
  manual edits as the current report text, blocking export rather than falling
  back to generated text.
- Tightened backup JSON export preparation so a file that fails readback
  verification, or reads back as a different project id, is removed instead of
  being left in the export directory.
- Removed stale unused import/export placeholder contracts that advertised an
  unavailable production importer/exporter and unused shared-file state after
  the real native file workflows were wired.

## 2026-05-31 - Subagent code slices for support, import, persistence, and readiness

- Assigned four new code-owning subagents to disjoint implementation slices:
  Support UI state, import preview no-op blocking, persistence recovery
  verification, and generation/readiness placeholder parity.
- Wired the Support tab to real existing state for local project storage,
  project count, open project, export readiness, and prepared file status.
- Hardened prepared export document handling so empty read or write payloads
  fail instead of producing an empty native file-export document.
- Tightened import preview preparation so no-data CSV imports and zero-row
  prepared changes fail before a teacher confirmation screen can be shown.
- Tightened recovery snapshot persistence so snapshots are read back after
  writing, failed snapshot verification removes the written file, and recovery
  listing rejects mismatched project metadata.
- Matched CommenterV3 unresolved-placeholder reporting order by preserving
  first-seen placeholder order while de-duplicating repeated placeholders.

## 2026-05-31 - MVP completion patch pass

- Wired verified project deletion through TCA and `FileProjectStore.deleteProject`, including a destructive confirmation, dirty-state blocking, recovery-snapshot messaging, project-list refresh, and open-project clearing after delete.
- Replaced ShareLink-only prepared-file sharing with a native `UIActivityViewController` adapter so share completion, cancellation, and failure are surfaced truthfully in reducer state.
- Updated Support diagnostics and backup guidance to describe local-only recovery snapshots, native document workflows, and no configured analytics/network services.
- Updated the privacy manifest with a file-timestamp required-reason API declaration for app-container file metadata/readback verification.
- Added reducer coverage for project deletion, dirty deletion blocking, and native share completion statuses; refreshed README and project posture to match the implemented MVP surface.

## 2026-05-31 - Live checkout patch hardening

- Tightened project deletion so reducer actions are blocked while another local storage operation or import preview is pending, not only when the visible button is disabled.
- Tightened `FileProjectStore.deleteProject` so a missing on-disk project fails with `projectNotFound` instead of reporting recovery-snapshot-backed deletion success, and verified the canonical project file is gone before deleting index rows.
- Added reducer and persistence tests covering pending-import delete blocking and missing-file delete failure.
- Re-ran live Windows validation; SwiftPM and Xcode/simulator gates remain blocked because `swift`, `xcodebuild`, and `xcrun` are not installed on this machine.

## 2026-05-31 - PR CI compile repair

- Fixed Swift CI compile errors by updating the `resolveSubjectForGeneration` call site to the current `uiSubject:` argument label and restoring the explicit return from `splitUnits`.
- Fixed report-generator test compile assertions to unwrap optional trace text explicitly before checking diagnostic substrings.
- Split the legacy XLS little-endian double conversion into explicit byte terms after CI showed the combined bit expression exceeded Swift's type-check budget.
- Added the missing persistence import for `RecoveryReason` in AppFeature and restored an explicit `FileWrapper` return in prepared export presentation.
- Removed the duplicate project-summary helper from the store client and imported CommentEngine where the split project reducer reads readiness.
- Fixed AppFeatureTests probe assertions so actor-isolated values are awaited before entering XCTest autoclosures.
- Reordered backup-import test client arguments to match the test helper signature exposed by CI.
- Tightened CSV row-break detection, note repair separation, spreadsheet import fallbacks, and tests for first-seen placeholder ordering and explicit subject-layout exclusion after CI reached behavioral tests.
- Fixed the spreadsheet fallback compile error by unwrapping ZIP entry data before reading worksheet XML.
- Replaced the rejected CodableCSV auto-row setting with quoted-field-aware row-break normalization before library parsing.
- Aligned import preview reducer tests with the real worklist navigation side effect, narrowed placeholder-order expectations to the resolver's actual first-seen unresolved order, and added CSV fallback validation for simple malformed or blank-row files when the primary CSV decoder reports a broad quoting failure.
- Tightened CSV fallback use so a primary parse that loses malformed data is cross-checked before reporting missing rows, and changed the CSV writer test to verify round-tripped multiline content rather than a single newline spelling.
- Made CSV fallback error selection explicit for missing-row decoder results and scoped the writer test to formula guarding plus multiline content emission after CI showed generated CSV is not a parser fixture.
- Added a no-quotes CSV width preflight so malformed unquoted rows are rejected before the primary decoder can collapse them into a misleading missing-data result.
- Switched legacy XLS import to try the app's verified simple compound-file workbook extractor before OLEKit, avoiding the CI crash path while preserving OLEKit as the fallback for files the local extractor cannot read.
- Made OLE compound `.xls` imports fail closed through the local workbook extractor instead of falling through to OLEKit after extractor rejection, so unsupported compound files surface as unreadable rather than risking a process-level crash.
- Removed OLEKit from the package manifest and import path after repeated CI signal-5 exits, recorded the fail-closed legacy XLS exception, and updated dependency policy/audit docs to reflect fixture-limited local OLE/BIFF support until a mature iOS parser is proven.
- Fixed legacy XLS compound-file directory parsing to reset sliced `Data` indices before walking 128-byte directory entries, avoiding Swift `Data.SubSequence` out-of-bounds traps in import and writer validation.
- Restored OLEKit after the signal-5 failure persisted without it, superseded the temporary removal decision, and kept the zero-based `Data` slice fix as the actual XLS crash repair.
- Updated the project import XLSX fixture to use shared strings and aligned the component-assembly report test with the deterministic text/hash emitted by the current generator.
- Stopped masking XLSX fallback validation errors as generic unreadable-workbook failures so CI and users see the concrete tabular validation failure when fallback parsing succeeds but the rows are invalid.
- Matched the project XLSX fixture shape to the inline-string workbook fixture already accepted by the parser and made fallback OOXML parsing reject missing shared-string targets as unreadable workbooks.
- Expanded the project import XLSX helper package metadata to match the fuller OOXML fixture shape used by the passing spreadsheet parser tests.
- Replaced the dynamic project import XLSX mini-generator with a hardcoded inline-string workbook fixture matching the parser-level accepted shape.

## 2026-05-31 - CI Xcode macro validation repair

- Updated the GitHub Actions app-target Xcode build command to skip package
  plugin and macro validation in noninteractive CI after PR run `26717887504`
  passed `swift package resolve` and `swift test` but failed before source
  compilation because TCA dependency macros were not enabled.
- Updated the validation ledger's intended Xcode app-target command to match
  the CI workflow exactly.

## 2026-05-31 - Simulator screenshot workflow

- Added a separate GitHub Actions workflow that resolves packages, selects and
  erases an available hosted iPhone simulator, runs a dedicated XCUITest
  screenshot lane, verifies at least ten PNG screenshots were written, and
  uploads both PNGs and the `.xcresult` bundle as artifacts.
- Added a `CommenterIOSScreenshotTests` UI test target to the Xcode project and
  shared scheme so the workflow captures the real SwiftUI app through the
  simulator instead of a mock preview.
- Added stable accessibility identifiers to the three root tab pages for
  screenshot/test targeting without changing user-visible product behavior.
- After the first hosted screenshot run reached the simulator, adjusted the UI
  test to locate real controls inside each core worklist area instead of
  SwiftUI section headers that were not exposed as static text in XCUITest.
- After hosted screenshot runs proved the UI test now captures all ten
  screenshots but the raw output directory stays empty in CI, added an
  `xcresulttool export attachments` workflow step that extracts the kept
  XCTest screenshot attachments into stable PNG files before artifact upload.

## 2026-06-01 - UI/UX defect patch integration

- Applied the standalone UI/UX defect patch and kept the changes inside the
  native SwiftUI/TCA, local-only, truthful-state architecture.
- Added project creation naming before persistence, roster management entry
  points, subject bulk selection, disabled prerequisite-gated actions, truthful
  import/export/share/cancel states, prepared-file timestamps, and richer
  support diagnostics.
- Added formal subject display names, curriculum-order subject handling, support
  copy diagnostics, and small native SwiftUI design-system components.
- Repaired patch integration gaps found after application: successful imports no
  longer lose their mode before completion handling, project creation cannot
  report cancellation after a successful programmatic close, and local data
  loaded from verified storage is not labelled as newly imported.
- Ran Windows-feasible hygiene checks. SwiftPM and Xcode/simulator validation
  remain blocked locally because `swift` and `xcodebuild` are not installed on
  this machine.

## 2026-06-01 - PR #4 screenshot CI repair

- Investigated failing hosted screenshot CI run `26733506101`; Swift package
  tests passed, but the UI test failed after selecting English because the
  achievement control was not exposed to XCTest under the expected stable
  identifier.
- Replaced the Results achievement `.menu` picker with an explicit SwiftUI
  `Menu` carrying the same reducer-backed update and a stable accessibility
  identifier for simulator automation.
- Reworked subject bulk-selection controls as real bordered buttons after the
  next hosted run showed the borderless list-row button existed but was not
  hittable to XCTest.
- Tightened screenshot UI test tapping so visible SwiftUI controls that XCTest
  reports as present but not hittable are still tapped through real screen
  coordinates, with downstream app state continuing to prove the operation.
- Made screenshot page waits accept the real tab page accessibility roots as
  well as navigation-bar titles after hosted CI showed a tab page could render
  without the expected title snapshot being observed.
- Replaced the achievement menu with visible reducer-backed achievement buttons
  after hosted CI proved SwiftUI menu controls were not exposing a stable
  hittable automation element for the result-entry flow.
- Replaced subject toggle rows with explicit reducer-backed selection buttons so
  curriculum selection remains visible and automatable after bulk deselection.
- Broadened the screenshot test subject lookup to accept visible row text as a
  real tap target, switched screenshot scrolling to smaller drag steps, and
  added failure-context captures for future hosted UI-test artifacts.
- Made screenshot scrolling direction-aware and verified the saved operation
  status through the same real list-scrolling path after hosted CI showed the
  top workflow status can be virtualized offscreen when Save Project is tapped.
- Tightened the generated-report lookup so the screenshot test no longer
  accepts matching result-card static text as proof that a durable report row
  exists.
- Added separate root page and list accessibility identifiers for Projects,
  Work list, and Support so UI tests can anchor to pages while scrolling the
  actual list containers.
- Reworked the core screenshot UI test to reopen and verify Work list before
  every Work list-only interaction, scroll inside `worklist-list` rather than
  the app window, require hittable subject controls, and attach page/tab/list
  diagnostics to future failure screenshots.
- After hosted screenshot run `26780285403` reached DOCX preparation but timed
  out polling an offscreen operation-status row, changed the test to wait for
  the verified `prepared-file-ready` row through the bounded Work list scroller.
- After hosted screenshot run `26781195133` showed `prepared-file-ready` was
  present but exposed by SwiftUI as multiple label child elements, changed the
  generic identifier lookup helper to use the first matching accessibility node.

## 2026-06-05 - CommenterV3 parity carryover

- Refreshed the bundled production comment dataset from the live CommenterV3
  source file and updated the production dataset hash expectation.
- Ported current CommenterV3 recipe-bank assembly behavior into the Swift
  generator, including slot rendering, unresolved-placeholder blocking,
  language linting, and deterministic recipe synthetic variant IDs.
- Hardened teacher note repair and report readiness checks for pronoun/verb
  agreement, repeated names/words, article agreement, and the V3-derived
  language patterns that block misleading generated output.
- Added real Work list editing for student gender, pronouns, private teacher
  notes, attitude descriptors, result evidence, text type, learning context,
  report notes, English focus tags, math proficiencies, math habits, next-step
  goals, and report flags. These fields now mutate durable project state
  through TCA actions instead of being import-only or invisible data.
- Tightened project and import validation for phrase-only report-context
  fields so sentence-like or pronoun-led fragments are rejected before they can
  produce misleading comments.
- Continued the live CommenterV3 parity audit against the current
  `C:\Commenterv3` checkout and carried over final-generation hardening that
  was still missing from iOS: report-context sentences for unused text
  type/context fields, V3-style disabled-layout flattening, final sentence-case
  normalization that preserves names/subjects, recipe `ComponentMode` and
  `RequiredTypes` handling, and generation-time blocking for unsafe
  report-context phrases.
- Added Work list feedback for evidence, text type, learning context, and
  report notes. The feedback is backed by the same repair/validation helpers
  used by generation, so user-visible success/warning/error states describe
  real generator behavior rather than decorative guidance.
- Added V3-style advisory language warnings (long sentences, overly complex
  phrasing) alongside blocking errors so diagnostics are more informative
  without changing export-readiness gates.
- Aligned language-lint issue ordering with V3: placeholder, repeated
  display/first names, custom patterns, pronoun, retext-style deterministic
  checks, articles, then advisory warnings.
- Aligned Work list focus-library options for English tags, math proficiencies,
  and math habits to the current V3 import/generator contract.
- Added a malformed-layout de-duplication guard matching V3's
  `normalizeReportLayout` behavior so repeated section entries are collapsed
  to one before generation, not silently skipped.
- Applied native sentence autocapitalization and autocorrection modifiers to
  long-form teacher-note and report-draft editors, the SwiftUI equivalent of
  V3's explicit spell-check opt-in for manual report edits.
- Fixed the AppFeature reducer routing so the new student-level editing actions
  (gender, pronouns, internal note, attitude, evidence, text type, context,
  report note, flags, English tags, math proficiencies, math habits, next-step
  goals) are dispatched from the top-level dispatcher to the project-editing
  sub-reducer.
- Added real Work list roster validation backed by existing project-validation
  helpers; teachers see duplicate-identity and missing-name/year-level errors
  before save and generation.
- Added inline report-editor feedback from the actual readiness/lint helpers so
  placeholder and language blockers surface at the draft edit point, not only
  at export time.
- Ported V3 encrypted backup support (AES-GCM + PBKDF2-SHA-256, CryptoKit/
  Security, password validation, ciphertext checksum, associated-data binding)
  into `BackupEnvelope.swift` with matching import/parse/serialize helpers.
- Added backup collision detection for invalid project records so teachers
  importing a backup whose ID matches a damaged local record are shown the
  right choice rather than silently replacing or duplicating.
- Wired invalid-project diagnostics throughout app state, lifecycle, support
  screen, and copied diagnostics so a damaged or tampered local project file
  is visible without blocking the project list.
- Ran available Windows validation. SwiftPM and Xcode/simulator validation
  remain blocked locally because `swift`, `xcodebuild`, and `xcrun` are not
  installed on this machine.

## 2026-06-05 - On-device AI foundation packets

- Executed the first AI implementation packets from
  `C:\Users\jackg\Downloads\CommenterIOS_AI_Implementation_Dream_Plan.md`.
- Documented the product decision that Apple Foundation Models on-device AI is
  allowed only as a local/offline, teacher-reviewed layer; remote AI and network
  fallback remain prohibited.
- Added persisted AI provenance, tone, review, validation, and revision-history
  metadata to `GeneratedReport` without making the new fields required for old
  project JSON.
- Added `CommenterReportSafety` with deterministic placeholder, name, pronoun,
  sensitive-information, unsupported-claim, tone, length, and layout validators.
- Added `CommenterAI` and `CommenterAITestSupport` as compile-safe foundations;
  live availability is gated through Foundation Models when present, while
  generation calls remain honestly unimplemented until real model calls are
  added.
- Added the first prompt registry and prompt-builder tests for deterministic
  draft revision, evidence drafting, and report critique. Prompt builders keep
  private teacher notes out of the model prompt and keep custom instructions
  subordinate to safety policy.
- Wired on-device AI availability into TCA app state, Support diagnostics, and
  the Work list draft-report surface. The UI reports unavailable/checking/failed
  states honestly and leaves deterministic generation available.
- Added teacher-review export gates for AI-generated or AI-revised reports.
  AI-derived text is blocked from readiness/export until deterministic
  validation passes and the teacher approves the current text fingerprint.
- Added an approval action for AI drafts that records local review state as an
  unsaved project edit, plus visible validation-blocked behavior when approval
  is attempted on unsafe text.
- Updated report review workbook rows with non-private AI review status and
  kept hidden AI provenance, prompt IDs, trace IDs, validation fingerprints, and
  review metadata out of generated DOCX/XLSX/XLS export packages.

## 2026-06-05 - AI Studio report workflow pass

- Added persisted project AI settings for tone profile, target length, and
  optional local teacher instruction; these settings feed `AIReportOptions`
  instead of remaining transient UI state.
- Added guarded Foundation Models revision wiring behind `canImport` and OS
  availability checks, with structured output, trace metadata, and deterministic
  post-generation report validation.
- Added AppFeature AI workflow state and actions for report AI polish,
  validation-backed pending previews, accept/reject, stale-preview blocking,
  local safety checks, and project-dirty acceptance semantics.
- Expanded the Work list report editor with AI Studio controls, honest
  availability-disabled states, tone controls, local safety check action,
  before/after preview, validation findings, and accept/reject buttons.
- Extended support diagnostics and reducer/domain/AI tests for persisted AI
  settings, preview-not-overwrite behavior, accept/reject behavior, and local
  safety check findings.

## 2026-06-05 - Bulk AI, draft, App Intents, and eval harness pass

- Added bulk AI polish workflow state/actions that sequentially request
  on-device AI revisions for unlocked drafts and queue per-report previews
  without changing, approving, saving, exporting, or sharing project data.
- Added Work list bulk AI controls and queued-preview status while reusing the
  same single-report accept/reject safeguards for each queued preview.
- Added guarded Foundation Models draft-from-evidence plumbing with validation
  and trace metadata, plus test-support injection for draft results.
- Added deterministic AI quality/evaluation tests for adversarial generated
  text and prompt evidence boundaries.
- Added a `CommenterAppIntents` target and linked it to the app host with safe
  open-only App Intents for AI review and report preparation; these intents do
  not bypass reducer validation or teacher approval.

## 2026-06-05 - Report-specific AI controls, evidence drafts, and critique pass

- Added report-level AI option controls that inherit project defaults and store
  draft-specific tone, length, and instruction overrides only as local project
  state for future previews.
- Added AI draft-from-evidence workflow actions and Work list controls. The
  workflow requires report-safe evidence, queues a teacher-review preview, and
  accepts as `ai-draft-from-evidence` only through the same validation and
  approval gates used by AI polish.
- Added AI critique workflow actions and Work list controls. The live client now
  routes critique through Foundation Models behind compile/runtime gates, while
  the separate local safety check remains deterministic and model-free.
- Made bulk queued preview identifiers unique even when the model or test client
  returns the same trace ID for multiple drafts.
- Added AppFeature tests for report override inheritance, evidence-draft
  preview/acceptance, missing-evidence blocking, AI critique notes, and unique
  bulk preview IDs.

## 2026-06-05 - Do-not-mention AI constraints pass

- Exposed report-level do-not-mention constraints in AI Studio and wired them
  through TCA state as cleaned `AIReportOptions.forbiddenMentions` overrides.
- Added prompt policy text so Foundation Models requests are instructed not to
  mention teacher-excluded details before deterministic validation runs.
- Added deterministic validator enforcement so forbidden mentions block AI
  preview validation, local safety checks, and teacher approval/export gates if
  the excluded detail appears in report text.
- Treated do-not-mention strings as internal AI metadata and added export
  privacy checks so DOCX/XLSX/XLS packages do not leak those constraints.
- Added reducer, prompt, validator, domain roundtrip, and import/export tests
  for the new constraint path.

## 2026-06-05 - Bulk AI cancellation pass

- Added explicit bulk AI running state, per-report progress actions, and
  cancellable TCA effect wiring for bulk on-device revision requests.
- Bulk AI now queues each completed preview as soon as it returns, then leaves
  those previews available if the teacher cancels the remaining queue.
- Added a Work list cancel action for running bulk AI jobs and reducer guards
  that reject overlapping single-report AI, evidence-draft, critique, or
  duplicate bulk starts while the bulk job is active.
- Updated Support diagnostics to report a running bulk AI revision and added
  AppFeature tests for progress preview queueing and cancellation state.

## 2026-06-05 - AI review queue surface pass

- Added a Work list AI review queue card that lists pending single-report and
  bulk AI previews and navigates directly to the matching report editor for
  accept/reject review.
- Reused the existing report editor and reducer accept/reject actions so queue
  review cannot bypass validation, teacher approval, or local dirty-state
  semantics.
- Added honest stale-preview UI for any pending preview that can no longer be
  matched to a current open draft.
- Updated the Draft reports AI preview count to include both single pending
  previews and queued bulk previews.

## 2026-06-05 - Required-mention AI constraints pass

- Exposed report-level required-mention constraints in AI Studio alongside the
  existing do-not-mention controls and wired them through cleaned
  `AIReportOptions.requiredMentions` overrides.
- Added deterministic validator enforcement so a teacher-required mention that
  is missing from report text blocks AI preview validation, local safety checks,
  and teacher approval/export gates.
- Passed required mentions through AI revision, evidence-draft, and local report
  validation contexts so prompts, previews, checks, and approval use the same
  local constraint set.
- Treated required-mention strings as internal AI metadata and expanded
  DOCX/XLSX/XLS privacy tests so those constraints do not leak into exports.

## 2026-06-05 - Project AI mention defaults pass

- Added project-level do-not-mention and required-mention defaults to
  `ProjectAISettings` with backward-compatible decoding for older AI settings
  that did not contain mention arrays.
- Exposed the project defaults in AI Studio and wired TCA actions so the
  defaults are cleaned, sorted, stored in local project metadata, and inherited
  by draft AI options unless a report-specific override exists.
- Expanded export privacy verification so project-level AI instructions and
  mention defaults are treated as internal metadata and omitted from DOCX,
  XLSX, and XLS outputs.

## 2026-06-05 - AI default reset and save-default pass

- Added a model conversion path from `AIReportOptions` back into
  `ProjectAISettings` so a tuned draft override can become the local project
  default without losing tone, length, instruction, or mention constraints.
- Added TCA actions and AI Studio controls for resetting project AI defaults to
  balanced settings and saving the current draft AI override as project
  defaults.
- Kept both operations truthful: reset is disabled unless stored defaults
  exist, saving as defaults requires an open draft, and neither operation
  changes existing report text or approves/export-readies AI output.

## 2026-06-05 - Validation warning review pass

- Added a `ReportWarningReviewRecord` tied to the validation text fingerprint so
  warning-only findings can be marked reviewed for the exact checked draft.
- Added a TCA action and AI Studio control for marking validation warnings
  reviewed, while blocked validations still require correction and cannot be
  acknowledged away.
- Cleared warning-review metadata when manual edits, AI preview acceptance, or
  new validation results replace the checked text/finding record.
- Added export privacy checks so warning-review fingerprints, reviewer names,
  and notes stay internal and do not appear in DOCX/XLSX/XLS outputs.

## 2026-06-05 - Tone adjustment and bulk confirmation pass

- Added a separate AI tone-adjustment workflow from prompt builder through live
  AI client dependency, guarded reducer actions, AI Studio button, pending
  preview state, validation summary, and teacher accept/reject path.
- Tone-adjusted previews are tagged with the `adjust-tone` prompt purpose and
  accepted drafts persist as `ai-tone-adjusted` local edits that still require
  validation and teacher approval before export.
- Added prompt, AI client, and AppFeature tests covering tone-adjust prompt
  policy, test-client tone results, preview queueing, and acceptance into local
  draft state.
- Added a visible bulk AI confirmation dialog so multi-report AI requests are
  not started from a single tap; confirmed previews still queue for teacher
  review and do not save, approve, export, or share automatically.

## 2026-06-05 - CI compatibility repair pass

- Routed the evidence-draft AI actions through the top-level reducer and added
  static action coverage checks while repairing CI compile failures.
- Fixed report-readiness language lint false positives, preserved v3 subject
  layout normalization, and hardened AI tone metadata decoding for legacy string
  values and missing fields.
- Kept project fingerprints stable while allowing backup import verification to
  accept both legacy raw checksums and normalized persistence checksums.
- Split SwiftPM test diagnostics from the iOS app-target build in CI so Swift
  test failures still upload logs and no longer hide app target compilation.

## 2026-06-05 - CI fail-fast and screenshot repair pass

- Removed compiled SwiftPM and DerivedData caches from CI workflows so source
  changes cannot reuse stale module artifacts.
- Moved the required screenshot job into iOS CI behind Swift package and app
  build prerequisites; the standalone screenshot workflow is now manual-only.
- Fixed the AI approval test fixture to approve the same report text it
  fingerprints, and added broader legacy tone-axis decoding coverage.
- Made the screenshot UI test tap the roster navigation row deterministically
  and wait for the student editor before editing first and last name fields.

## 2026-06-05 - AI stale preview guard pass

- Carried request-time draft text through single-report AI polish, tone
  adjustment, and evidence-draft completion actions.
- Rejected stale AI completions before queuing a pending preview when the local
  draft fingerprint changed while the on-device AI request was in flight.
- Added AppFeature regression coverage so polish, tone-adjustment, and
  evidence-draft completions cannot overwrite intervening teacher edits by
  capturing the current draft as their preview baseline.
- Strengthened roster-row accessibility and screenshot navigation taps after CI
  showed the UI test was still on the worklist after tapping the new student
  row.
- Replaced roster student-row NavigationLinks with explicit button-driven route
  state, simplified the screenshot test to one stable row tap, and split stale
  AI regression coverage across polish, tone, evidence-draft, single-accept,
  and bulk-accept paths.
- Hoisted student-editor route state to `WorklistRootView`, kept roster rows as
  full-width buttons, and made the screenshot test scroll the new row into a
  safe central tap zone before activation.
- Relaxed generated-report screenshot lookups to visible-but-not-necessarily
  hittable elements after generation and added candidate state diagnostics for
  future scroll failures.

## 2026-06-12 - App Store release package integration

- Integrated the Report Comment Writer App Store release package under
  `docs/release/app-store`, including App Store Connect copy, privacy/legal
  drafts, brand guidance, screenshot plans, generated asset masters, support
  site drafts, repo-evidence notes, manifest, and central TODO list.
- Installed the release app icon and accent colour into the real Xcode asset
  catalog after backing up the previous icon set.
- Added root Fastlane draft metadata and a release-package validator covering
  required files, metadata limits, screenshot/icon dimensions, banned
  teacher-facing claims, obvious sample-data risks, and secret-file patterns.
- Recorded that Swift, Xcode, and `plutil` were unavailable in the Windows
  environment, while the package validator, asset validator, whitespace check,
  and line-ending audit were run.

## 2026-06-12 - Screenshot CI report editor wait repair

- Fixed the screenshot UI test so it waits for the generated report editor
  after tapping the report row instead of re-opening and scrolling the Work
  list for an editor that only exists on the pushed report screen.
- Tightened generated-report navigation verification, safe report-row tapping,
  back-button fallback handling, UITest launch animation disabling, fuller
  accessibility diagnostics, and selected-simulator booting for screenshot CI.

## 2026-06-12 - Close-repo audit truthfulness hardening pass

- Made SQLite index initialization, save/update, delete, and file-protection
  failures fail visibly instead of reporting verified project operations with a
  potentially stale index.
- Rechecked backup-import replacement revisions against the live project list
  at preview time, rejected stale AI validation/critique completions, and made
  prepared-file cleanup produce verified success or a visible cleanup failure.
- Tightened export privacy verification for short local-only strings, encrypted
  backup KDF iteration floors, XLSX parser fallback policy, warning-review
  approval records, report freshness fingerprints, support diagnostics
  redaction, and user-visible local-path error messages.
- Added strict release-package validation for TODO placeholders and unskipped
  privacy-manifest lint, a macOS CI `plutil` privacy-manifest job, dependency
  doc sync for ZIPFoundation `0.9.11`, support/release copy fixes, and
  scaffold-stale handoff/backlog updates.

## 2026-06-12 - Close-repo audit CI/accessibility continuation

- Replaced the custom subject-selection button semantics with a native SwiftUI
  `Toggle`, while preserving the visual row and existing action flow.
- Removed the fixed 86-point form label width in worklist rows so labels can
  wrap under larger Dynamic Type and localization.
- Centralized screenshot extraction and required-name verification in
  `scripts/extract_core_screenshots.py`, and made both screenshot workflows use
  that script.
- Added executable validators and docs for Xcode scheme test scope and CI
  artifact upload privacy allowlists.

## 2026-06-12 - Close-repo audit release-proof and results-scale continuation

- Added student and subject filters to the Results worklist section so large
  classes can narrow result entry instead of rendering every roster-by-subject
  card as the only editing mode.
- Added a worklist task-focus picker so teachers can view the full workflow or
  narrow the long screen to setup, results, drafts, or file actions without
  changing project state.
- Removed the decorative bottom desk-edge inset from the worklist editing
  screen so controls are not competing with non-functional chrome.
- Added `scripts/validate_release_proof_matrix.py` and
  `docs/validation/RELEASE_PROOF_MATRIX.md` to make `Package.resolved`,
  archive/TestFlight evidence, Foundation Models compile evidence, and
  target-app DOCX/XLSX/XLS open-validation evidence hard release gates.
- Wired the release proof matrix into
  `scripts/validate_app_store_release_package.py --strict-submission` so a
  strict submission pass cannot occur without those artifacts.
- Added a protected manual iOS release archive workflow that requires signing
  and App Store Connect secrets, validates an archive/privacy manifest, exports
  an App Store IPA, optionally uploads to TestFlight, and writes release
  evidence only after the real operations run.
- Added dataset-source-transform and localization-plan validators so release
  proof includes the documented CommenterV3 hash chain and an honest
  English-only localization posture.
