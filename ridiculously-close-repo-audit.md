# Ridiculously Close Repository Audit

## 1. Executive Summary

CommenterIOS is not a fake scaffold. The repository contains a serious native SwiftUI/TCA implementation of a local-only teacher report-writing app: domain models, deterministic generation, bundled production comment data, local JSON persistence, SQLite indexing, recovery snapshots, CSV/XLSX/XLS import, DOCX/XLSX/XLS export preparation, backup JSON import/export, App Intents, support diagnostics, and guarded Apple Foundation Models AI workflows.

That said: it is **not ready** for release. The top problems are not ordinary polish nits. Several paths can produce truthful-looking success or review states while important supporting state is stale, best-effort, unverified, or tied to the wrong draft. Release materials also over-project readiness: validators pass while TODO public metadata remains, App Store assets are explicitly draft, `Package.resolved` is absent, privacy lint is skipped locally, and custom Office-format infrastructure still lacks enough target-app validation evidence.

The biggest risks:

| Rank | Risk | Evidence |
| ---: | --- | --- |
| 1 | SQLite index update/delete/init failures are swallowed after verified project JSON save/delete. | `Sources/CommenterPersistence/ProjectStore.swift:250`, `:272`, `:365` |
| 2 | Backup import replacement can bypass revision conflict checks after preview. | `Sources/AppFeature/Features/FileWorkflowFeature.swift:92`, `:127`, `:197`; `ProjectStore.swift:216` |
| 3 | AI critique completion can attach stale validation to changed report text. | `Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift:604`, `:614`; `Sources/CommentEngine/ReportReadiness.swift:220` |
| 4 | Release validator passes with TODO public URLs and skipped privacy lint. | `scripts/validate_app_store_release_package.py:187`, `:254`; `fastlane/metadata/en-AU/*.txt:1` |
| 5 | `Package.resolved` is missing despite docs requiring it before public submission. | `docs/dependencies/DEPENDENCY_AUDIT.md:16`; `rg --files -g Package.resolved` returned none |
| 6 | Custom DOCX/XLSX/XLS generation/import is a release-proof and dependency-policy risk. | `docs/dependencies/DEPENDENCY_AUDIT.md:56-60`; `ReportDocumentFile.swift:86`; `ReviewWorkbookFile.swift:204`; `LegacyXLSWorkbookWriter.swift:32` |
| 7 | Main iPhone workflow is too dense for real classroom-scale use. | `Sources/AppFeature/Views/WorklistRootView.swift:94`; `WorklistSections.swift:575` |
| 8 | Local Windows environment cannot run Swift/Xcode/simulator validation. | `swift`, `xcodebuild`, `xcrun` unavailable |
| 9 | Foundation Models implementation is guarded behind SDK availability and likely not compiled by current CI. | `Sources/CommenterAI/AIClient.swift:33`; `FoundationModelReportGenerator.swift:5`, `:8` |
| 10 | One tracked file has CRLF in the working tree despite LF policy. | `.agents/skills/audit-xcode-security-settings/scripts/filter_build_settings.py` |

Release-readiness verdict: **Not ready**.

The repo is in a strong engineering-in-progress state, and latest hosted iOS CI on `main` was green on 2026-06-12. But release readiness requires more than green SwiftPM tests and a simulator build. It requires final public metadata, locked dependencies, privacy lint/archive evidence, target-app open validation, physical-device/native file workflow proof, and repair of the truthfulness defects above.

## 2. Product Reality

### What the app appears to do

CommenterIOS is a native iPhone-first SwiftUI/TCA port of CommenterV3. In-app branding is mostly `Report Writer`; App Store material uses `Report Comment Writer`. The product helps Australian Year 5/6 teachers produce school report comment drafts from local roster, subject, achievement, evidence, next-step, and teacher-note data.

The app's stated posture is unusually strict:

- offline-first;
- local-only private teacher/student data;
- production comment-engine dataset only;
- deterministic generation;
- no unresolved placeholders in generated/exported text;
- no fake save/import/export/share/generation success;
- optional on-device Apple Foundation Models only as a local teacher-reviewed layer;
- no remote AI.

### Who the user appears to be

The intended user is an Australian primary teacher preparing student report comments on an iPhone. A secondary user is the developer/support operator who needs diagnostic data when the teacher reports a storage, export, or readiness problem.

### Main user journeys

1. Create/open a local project.
2. Add or import a roster.
3. Select report subjects.
4. Enter achievement, focus, evidence, next steps, and comment constraints.
5. Generate deterministic draft comments from the bundled production dataset.
6. Review/edit/approve report drafts.
7. Optionally request local on-device AI previews, then accept/reject or approve after validation.
8. Prepare verified DOCX/XLSX/XLS exports.
9. Save/share prepared files through native iOS file/share flows.
10. Export/import backup JSON, including encrypted backup support.
11. Use Support diagnostics and privacy policy surfaces.

### Core entities and data models

Core entities are implemented in `Sources/CommenterDomain/Models.swift`, including:

- `Project`
- `ProjectMetadata`
- `ProjectSummary`
- `Student`
- `AchievementResult`
- `GeneratedReport`
- `ReportReviewState`
- `ProjectAISettings`
- `ReportWarningReviewRecord`
- backup/import/export workflow types in import/export modules

Persistence centers on canonical project JSON files plus a SQLite metadata/index sidecar in `Sources/CommenterPersistence/ProjectStore.swift` and `SQLiteProjectIndex.swift`.

### Main screens/routes

`Sources/AppFeature/AppView.swift:24-38` and `:150-158` show a three-tab app:

| Screen | Purpose | Implementation status |
| --- | --- | --- |
| Projects | Storage readiness, create/import/open/delete projects | Implemented |
| Work list | Project metadata, roster, subjects, results, reports, AI, exports, backup/import preview, prepared file actions | Implemented but too dense |
| Support | Storage/dataset/privacy/readiness diagnostics and redacted diagnostic copy | Implemented |
| Project creation sheet | Create a local project | Implemented |
| Delete confirmation alert | Confirm project deletion | Implemented |
| Encrypted backup password alert | Password flow for encrypted import | Implemented |
| Native importer/exporter/share sheet | iOS file workflows | Source-present, not locally simulator-verified |

### What the repo claims is implemented

`README.md:33-45` claims a broad MVP source surface:

- SwiftUI/TCA app host;
- production dataset validation and deterministic generation;
- local project persistence and recovery;
- CSV/XLSX/XLS import;
- DOCX/XLSX/XLS export;
- backup JSON;
- support diagnostics;
- Apple Foundation Models wiring;
- App Intents;
- screenshot/release package work.

`docs/PRODUCTION_MVP_PLAN.md` and `docs/ledgers/CORE_RULES.md` define a stricter release bar: CI, simulator, physical-device, archive, TestFlight, privacy, App Store metadata, import/export, no-network, dependency, and target-app open validation.

### What appears actually implemented

Most source surfaces exist. The implementation is not just decorative:

- `Sources/CommentEngine/ReportGenerator.swift` implements deterministic report generation.
- `Sources/CommentEngine/Resources/comment-engine.json` bundles the production dataset.
- `Sources/CommenterPersistence/ProjectStore.swift` implements save/load/delete/recovery/fingerprint logic.
- `Sources/CommenterImportExport/SpreadsheetImportFile.swift`, `ReportDocumentFile.swift`, `ReviewWorkbookFile.swift`, `BackupEnvelope.swift`, and related files implement import/export/backup paths.
- `Sources/AppFeature/Features/*.swift` implement TCA workflows.
- `Tests/**` contains meaningful SwiftPM unit/reducer coverage.
- `UITests/CommenterIOSScreenshotTests/CommenterIOSScreenshotTests.swift` drives a long screenshot journey.

### What appears fake, placeholder, incomplete, or aspirational

| Area | Reality |
| --- | --- |
| App Store readiness | Draft-only. Public URLs, owner/contact/copyright/pricing/territories/final screenshots/final privacy check remain TODO. |
| Release validator | Allows TODO URL values and skips privacy lint when `plutil` is unavailable. A pass is not submission readiness. |
| Docs saying scaffold/minimal | Stale. `AGENTS.md:38-39`, `:60` and `docs/CHAT_HANDOFF.md:99-103` still describe an initial scaffold/minimal host. |
| Initial backlog | Very stale. Many implemented items remain unchecked. |
| Custom Office files | Implemented, but release-proof is incomplete without target-app open validation and dependency-policy decisions. |
| AI availability | Source-present, but Foundation Models code is guarded and needs Xcode/iOS 26 SDK validation. |
| Local verification | Swift/Xcode unavailable here, so local build/test/simulator verification could not run. |

## 3. Verification Log

| Command | Result | What it showed |
| --- | --- | --- |
| `git status --short --branch` | Pass | Clean `main...origin/main` before report creation. |
| `rg --files` | Pass | Inventoried source, docs, tests, release package, workflows, Fastlane, scripts. |
| `git diff --check` | Pass | No unstaged whitespace errors. |
| `git diff --cached --check` | Pass | No staged whitespace errors. |
| `git ls-files --eol` | Warning | Mostly LF; one tracked working-tree CRLF file: `.agents/skills/audit-xcode-security-settings/scripts/filter_build_settings.py`. |
| `Get-Command swift,xcodebuild,xcrun,node,npm,gh` | Partial | Node/npm/gh present; Swift/Xcode tools absent. |
| `swift package resolve` | Fail | `swift` not recognized. Environment blocker. |
| `swift test` | Fail | `swift` not recognized. Environment blocker. |
| `xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` | Fail | `xcodebuild` not recognized. Environment blocker. |
| XcodeBuildMCP `session_show_defaults` | Pass/no defaults | No project/scheme/simulator defaults configured. |
| XcodeBuildMCP `discover_projs` | Pass | Found `C:\CommenterIOS\CommenterIOS.xcodeproj`. |
| XcodeBuildMCP `list_sims enabled:true` | Fail | `spawn xcrun ENOENT`. |
| XcodeBuildMCP `list_schemes` | Fail | `spawn xcodebuild ENOENT`. |
| `python --version` | Pass | Python 3.14.2. |
| `python scripts/validate_app_store_release_package.py` | Pass with warning | `Validation passed`, but `plutil unavailable; privacy manifest lint skipped`. |
| `python docs/release/app-store/05_assets/_generation_scripts/validate_release_assets.py` | Pass | Release assets validated. |
| `rg --files -g Package.resolved` | Fail/none | `Package.resolved` absent. |
| Secret/network scan with `rg` | Pass/no secrets | No obvious committed tokens or production remote telemetry paths found. |
| TODO/fake scan excluding dataset/assets | Warning | Release TODOs and draft metadata remain. |
| Dataset parity Node check | Pass | Bundled dataset equals `C:\Commenterv3\client\public\data\comment-engine.json` after LF normalization; 56,564 components, 5 recipes, 4,340 variants, 2 uniqueness guards. |
| `Get-FileHash` source/bundle dataset | Informational | Raw source SHA256 `65E37D45...B0EF`; bundled normalized SHA256 `C6D7F90C...48F3`. |
| `gh workflow list --repo advrider-jpg/CommenterIOS` | Pass | `iOS CI` and `iOS Screenshots` active. |
| `gh run list --limit 5` | Pass | Latest `main` iOS CI succeeded; prior failures exist. |
| `gh run view 27435465645 --json ...` | Pass | On 2026-06-12, `main` run succeeded for Swift package tests, app build, and screenshot capture. |

Hosted CI evidence matters: the latest `iOS CI` run on `main` completed successfully at `2026-06-12T19:00:27Z` for commit `20556a1c0dc71591273484dee6516cd427bd696e`. Jobs: `Swift package tests`, `Build iOS app target`, and `Capture core app screenshots`. This is real positive evidence, but it is not the same as archive/TestFlight/physical-device/privacy-report/target-app export validation.

## 4. Feature Claim Matrix

| Feature / claim | Claimed or implied by | Implementation evidence | Status | Missing proof or gap |
| --- | --- | --- | --- | --- |
| Native SwiftUI/TCA iPhone app | `README.md:33-37` | `Package.swift:72-83`; `AppView.swift:24-158`; Xcode project | Mostly implemented | Local build unavailable here; hosted CI green. |
| Offline/local-only posture | `README.md:13-18`; `CORE_RULES.md:43-64` | No production `URLSession`/Firebase/analytics scan hits; privacy manifest no collection | Mostly implemented | Final binary privacy report and archive proof missing. |
| Production dataset | `DATA_LEDGER.md:8-30` | `Sources/CommentEngine/Resources/comment-engine.json` | Implemented | Raw source hash differs due normalization; transform should be documented/tested. |
| Deterministic generation | `README.md:33-35` | `ReportGenerator.swift`; `CommentEngineTests` | Implemented | Local `swift test` unavailable. |
| Placeholder blocking | `CORE_RULES.md:99-103` | `ReportSafetyValidator.swift`; `PlaceholderResolver.swift`; tests | Implemented | Need export/AI stale validation edge tests. |
| Local project save/load | `README.md:35` | `ProjectStore.swift:198-250` | Mostly implemented | SQLite index failure is swallowed after JSON save success. |
| Recovery snapshots | `PRODUCTION_MVP_PLAN.md:118` | `ProjectStore.swift:280-312` | Implemented | More failure-injection tests needed. |
| SQLite metadata/index | `PRODUCTION_MVP_PLAN.md:118` | `SQLiteProjectIndex.swift`; `ProjectStore.swift:250` | Partially reliable | Index update/init/delete errors swallowed. |
| CSV import | README/import claims | `SpreadsheetImportFile.swift`; `CSVParser.swift` | Implemented | Local test unavailable; malformed-file UI coverage missing. |
| XLSX import | README/import claims | CoreXLSX path plus fallback in `SpreadsheetImportFile.swift:74-99` | Implemented with risk | Fallback can mask CoreXLSX errors; target app fixture matrix needed. |
| Legacy XLS import | README/import claims | `SpreadsheetImportFile.swift:101-126`, custom BIFF/OLE subset | Partially release-proven | Custom parser policy risk; fuzz/real app validation needed. |
| DOCX export | README/export claims | `ReportDocumentFile.swift` | Implemented with risk | Custom OOXML writer; Word/Pages open validation needed. |
| XLSX export | README/export claims | `ReviewWorkbookFile.swift` | Implemented with risk | Custom SpreadsheetML; Excel/Numbers/LibreOffice open validation needed. |
| Legacy XLS export | README/export claims | `LegacyXLSWorkbookWriter.swift` | Implemented with high risk | Custom BIFF/OLE writer; target-app validation required. |
| Backup JSON import/export | README/export claims | `BackupEnvelope.swift`; `BackupFileWorkflow.swift` | Mostly implemented | Revision-conflict bypass on backup replace; weak legacy encryption floor. |
| Encrypted backups | `BackupEnvelope.swift` and UI alert | `BackupEnvelope.swift:15-19`, password alert in `AppView.swift` | Mostly implemented | Low KDF iterations accepted by lower-level path; large-file cancellation needed. |
| Native share/save flow | UI labels and `FileWorkflowFeature` | `AppView.swift:164-180`; `FileWorkflowFeature.swift` | Source-present | Simulator/device cancellation/save/share proof needed. |
| AI preview/review | `README.md:38-45` | `ProjectAIWorkflowFeature.swift`; `CommenterAI` | Mostly implemented | Stale critique bug; Foundation Models compile/runtime proof missing. |
| App Intents | README claims | `Sources/CommenterAppIntents` | Source-present | Runtime validation not run here. |
| Support diagnostics | `SupportRootView.swift` | `SupportDiagnostics.swift`; `SupportRootView.swift` | Implemented | On-screen raw project name/ID; redaction hashes deterministic. |
| Privacy policy URL | `AppPrivacyPolicy.swift` | Reads `REPORT_WRITER_PRIVACY_POLICY_URL` from Info | UI supports it | Xcode setting is unresolved `$(REPORT_WRITER_PRIVACY_POLICY_URL)`; Fastlane URL TODO. |
| App Store release package | `docs/release/app-store` | Draft docs/assets/scripts | Draft only | TODOs, final screenshots, final privacy, signing, archive, TestFlight missing. |
| Fastlane metadata | `fastlane/metadata` | Text files exist | Draft only | support/privacy/marketing URL files are `TODO`. |
| CI Swift tests/build/screenshots | `.github/workflows/ios-ci.yml` | Hosted green run 27435465645 | Implemented | Release gates narrower than MVP plan. |
| Standalone screenshot workflow | `.github/workflows/ios-screenshots.yml` | Active workflow | Stale/risky | Recent standalone runs were failing; screenshot requirements duplicated. |
| Dependency discipline | `OSS_DEPENDENCY_POLICY.md` | Exact pins in `Package.swift` | Partially implemented | No `Package.resolved`; docs drift from manifest; custom writers unresolved. |

## 5. Major User Journey Audit

| Journey | Entry point | Expected path | Actual path | Status | Defects |
| --- | --- | --- | --- | --- | --- |
| Create a project | Projects tab | Tap Create, enter metadata, land in project editor | `ProjectsRootView` -> `ProjectCreationSheet` -> Work list | Mostly complete but rough | Blank name only disables Create; no visible validation. Landing into huge Work list gives little orientation. |
| Open an existing project | Projects tab | Select project, load verified local data | Project cards send open action; status says verified local storage | Mostly complete | Save/index errors can leave metadata/index stale. |
| Delete a project | Project card or Work list | Confirm destructive delete, create recovery snapshot, remove file/index | Confirmation exists in `AppView.swift:207-226` | Mostly complete | Index delete failure swallowed at `ProjectStore.swift:272`. |
| Add roster manually | Work list | Add student, edit details, save | Roster section and student editor | Complete but dense | Edits mark dirty elsewhere; no local save affordance in student detail. |
| Import roster/results | Projects/Work list file importer | Choose file, preview, confirm all-or-nothing commit | `fileImporter`, pending import section | Mostly complete | Backup replace can bypass stale revision checks; importer error states need device QA. |
| Select subjects | Work list | Toggle subjects | Custom `SubjectSelectionButton` | Complete but custom | Button mimics checkbox instead of native toggle semantics. |
| Enter results | Work list | For each student/subject, enter achievement/evidence/context | Nested `ForEach(project.roster)` x subjects at `WorklistSections.swift:575` | Partially production-ready | 30 students x 6 subjects creates about 180 cards. Not realistic on iPhone. |
| Generate reports | Work list | Generate deterministic drafts, see readiness | Reports section | Mostly complete | Generation reparses 20MB dataset each call. |
| Review/edit/approve report | Reports section | Edit draft, validate, approve | `ReportEditorView` | Mostly complete | Warning-review semantics unclear; stale validation can affect readiness. |
| AI preview/review | Report editor | Request local AI preview, accept/reject, teacher approves | AI Studio section | Partially production-ready | Stale AI critique completion can attach validation to changed text; runtime Foundation Models proof missing. |
| Prepare exports | Report exports section | Prepare verified DOCX/XLSX/XLS | `ReportExportsSection` | Implemented with release risk | Custom writer open-validation required; wording "Prepare" vs save/share confusing. |
| Save/share prepared file | Prepared file panel | Native save/share, distinguish cancel/success/fail | `ActivityShareSheet` and file exporter | Source-present | Temp file cleanup is best-effort but UI can imply removal. Device QA missing. |
| Backup export | Backup section | Require saved state, prepare JSON, save/share | `FileWorkflowFeature.swift:261-279` | Mostly complete | Temp cleanup and encrypted KDF edge cases. |
| Support diagnostics | Support tab | Copy redacted diagnostics, show storage/privacy info | `SupportRootView` | Implemented | Too developer-dense; raw project name/ID shown on screen. |

## 6. Screen-by-Screen UX Audit

### Projects

Evidence: `Sources/AppFeature/Views/ProjectsRootView.swift:16-66`, `:172-182`, `:216-250`.

Purpose is clear: manage local projects, create projects, import backups, and see storage readiness. Empty states and storage unavailable states exist. The screen is credible, not fake.

Problems:

- `ProjectsRootView.swift:19` uses "Your reporting companion", which is soft marketing copy where the screen should be utilitarian: "Local report projects" would be clearer.
- Create/Import buttons are disabled when storage is unavailable, which is good, but the screen should more aggressively direct the user to the exact storage error and support action.
- Delete exists through contextual UI and a confirmation alert, but index cleanup failure can be hidden.

Status: mostly complete but needs product-copy tightening and stronger storage/error surfacing.

### Project Creation Sheet

Evidence: `Sources/AppFeature/AppView.swift:335-421`.

The sheet captures class name, term, year level, and first-name-only setting. It uses a disabled Create button for invalid blank class name.

Problems:

- Blank name has no explicit inline validation, only a disabled toolbar button.
- The sheet is honest about local project creation, but it does not state what happens after creation or when save occurs.

Status: complete but slightly opaque.

### Work List Root

Evidence: `Sources/AppFeature/Views/WorklistRootView.swift:94-258`.

This is the app's biggest UX problem. It is a single `List` containing project metadata, import preview, roster, subjects, results, reports, exports, backup, and prepared-file state. It is truthful, but the shape is not production ergonomic for iPhone.

Problems:

- `WorklistRootView.swift:94` begins a huge all-in-one editing surface.
- Real-world result entry scales badly because `WorklistSections.swift:575-576` nests roster by selected subjects.
- `WorklistRootView.swift:256-258` adds a decorative `DeskEdgeDecoration` safe-area inset; screenshot tests include tap-zone workarounds, suggesting layout/tap complexity.
- Too many callbacks/state values flow into `WorklistRootView`, increasing re-render and maintenance risk.

Status: partially production-ready. It needs focused routes or a task hub.

### Roster And Student Editor

Evidence: `WorklistSections.swift:157-306`, `:318-398`.

Roster has empty states and row navigation. Student editor captures core student fields and internal notes.

Problems:

- Student detail edits do not have an obvious save action on the detail surface. Dirty-state truth may exist elsewhere, but a teacher can miss it.
- Student deletion is available via row/list affordances rather than a visible destructive action inside the detail context.
- Custom form rows have fixed label widths (`WorklistSections.swift:2632-2639`), fragile under Dynamic Type.

Status: functional, but needs iPhone usability and accessibility work.

### Subjects

Evidence: `WorklistSections.swift:410-482`.

Subject selection is implemented and clear enough visually.

Problems:

- `SubjectSelectionButton` is a custom button with a drawn check/circle. This should be a native `Toggle` or a component with explicit accessibility role/value/hint.
- Custom checkbox styling adds maintenance burden for a basic control.

Status: complete, but custom implementation is weaker than native.

### Results

Evidence: `WorklistSections.swift:518-981`.

The Results section is detailed and domain-rich. It captures achievement level, focus, evidence, text type, learning context, emphasis note, constraints, and flags.

Problems:

- `WorklistSections.swift:575-576` renders every student x selected subject. For a class of 30 and 6 subjects, this becomes about 180 dense cards.
- Inline form controls, custom pill buttons, and long text fields in one vertical list will be punishing on iPhone.
- No strong filter, stepper, or focus mode exists for "one student" or "one subject at a time."

Status: source-complete but not classroom-scale UX-ready.

### Reports And AI Studio

Evidence: `WorklistSections.swift:1011-2178`; `ProjectAIWorkflowFeature.swift`.

The trust posture is strong: AI previews are repeatedly framed as teacher-reviewed and not automatically applied/exported. `WorklistSections.swift:1506` and related copy are good anti-fake evidence.

Problems:

- AI Studio is too dense: local validation, AI availability, tone controls, per-draft overrides, preview diff, critique, warnings, approval, and draft-from-evidence are crowded together.
- `ProjectAIWorkflowFeature.swift:604-619` can store stale critique validation if the draft changes during the async request.
- Warning-review model exists but approval/export semantics do not clearly require or record warning review.

Status: mostly implemented, not release-ready for AI trust without stale-state fixes and runtime proof.

### Export, Backup, Prepared File

Evidence: `WorklistSections.swift:2244-2390`; `FileWorkflowFeature.swift:256-389`; `AppView.swift:164-180`.

The flow truthfully separates prepare from native save/share. It blocks exports/backups when unsaved changes would make the file unverified.

Problems:

- Labels "Prepare DOCX Reports", "Save Prepared File Copy", and "Share Prepared File" are truthful but teacher-unfriendly. Users may not understand why a second action is required.
- Temp prepared-file discard returns `Void` and uses `try?`; UI can imply cleanup even if deletion failed.
- Target-app open validation is not in the repo evidence.

Status: implemented with release and trust gaps.

### Support

Evidence: `SupportRootView.swift:14-197`; `SupportDiagnostics.swift`.

The Support screen is unusually honest: it surfaces storage, dataset, readiness, privacy, and diagnostic details. It states analytics/telemetry are not configured (`SupportRootView.swift:72`) and accounts/cloud sync/remote AI are not configured (`SupportRootView.swift:197`).

Problems:

- It is dense and support-operator oriented.
- It shows full project name and ID on-screen around `SupportRootView.swift:122`.
- Redaction hashes are deterministic and short, making dictionary matching plausible for low-entropy names.

Status: implemented, but needs privacy and teacher-facing polish.

## 7. Anti-Fake and Product Trust Audit

Strong positives:

- I found no production remote telemetry or remote AI paths in source scans.
- Many UI/status strings explicitly distinguish saved, cancelled, failed, unavailable, and prepared states.
- `FileWorkflowFeature.swift:261-311` blocks backup/export if unsaved changes would make output unverified.
- AI UI says previews do not overwrite/approve/save/export automatically.
- Export helpers read back generated files and remove failed outputs.

Trust-damaging issues:

| Severity | Issue | Evidence | Why it damages trust | Fix |
| --- | --- | --- | --- | --- |
| Critical | Release validation can pass while public metadata is still TODO. | `scripts/validate_app_store_release_package.py:187`; `fastlane/metadata/en-AU/support_url.txt:1`; `privacy_url.txt:1`; `marketing_url.txt:1` | A green validation message can be mistaken for submission readiness. | Add release-mode validator that fails all TODOs. |
| High | SQLite index errors are hidden after save/delete. | `ProjectStore.swift:250`, `:272`, `:365` | User sees verified local operation while local index/support metadata may be stale. | Make index part of contract or surface degraded save/delete. |
| High | Temp file cleanup is best-effort but success/cancel/failure copy can imply cleanup. | `ProjectStoreClient.swift:249-251`; `FileWorkflowFeature.swift:335-372` | Private exports may remain in temp storage while UI implies removal. | Return cleanup result and verify absence. |
| High | Stale AI critique can validate the wrong text. | `ProjectAIWorkflowFeature.swift:604-619` | Teacher may trust review state for text that was not reviewed. | Carry request fingerprint and reject stale completions. |
| High | Backup import can overwrite newer project revision after stale preview. | `FileWorkflowFeature.swift:92`, `:127`, `:197`; `ProjectStore.swift:216` | A "confirmed" import can silently replace newer local data. | Capture expected revision and re-check at confirmation. |
| Medium | Warning-review UI/model may be decorative. | `Models.swift:812`; `ProjectEditingFeature.swift:181-202`; `ReportReadiness.swift:232` | If warnings do not gate approval/export or get recorded during approval, the review record is unclear. | Define one warning-review contract and test it. |
| Medium | App Store screenshots/assets are drafts. | `docs/release/app-store/README.md:13-19`; `screenshot_plan.md` | Marketing assets can look final while docs admit final screenshots from actual UI are TODO. | Gate final submission on actual app screenshots. |
| Medium | Public support draft says "Use fake sample data". | `docs/release/app-store/06_support_site_drafts/support.html:18` | "Fake sample data" sounds unprofessional and trust-eroding. | Use "sample or non-identifying data". |
| Medium | Docs still call app an initial scaffold. | `AGENTS.md:38-39`, `:60`; `docs/CHAT_HANDOFF.md:99-103` | Future agents may make scaffold-level assumptions. | Update current-state docs. |

## 8. Code Correctness Defects

### CC-01: SQLite index failures are swallowed after save/delete/init

- Severity: High
- Category: Persistence / truthfulness
- Affected files: `Sources/CommenterPersistence/ProjectStore.swift`
- Evidence: `ProjectStore.swift:250`, `:272`, `:365`
- What the code says: canonical JSON is saved/deleted and readback verified, then SQLite index is updated/deleted/initialized.
- What actually happens: `try?` ignores SQLite failure.
- Why this matters: a user-visible success can coexist with stale or missing local metadata/index.
- Reproduce/verify: make `index.sqlite` unwritable or create a directory at the index path; call save/delete.
- Recommended fix: make index update/delete/init fail the operation or return degraded status.
- Suggested tests: `testSaveFailsWhenSQLiteIndexCannotBeUpdated`, `testDeleteReportsSQLiteIndexCleanupFailure`.
- Deeper design problem: the repo has not decided whether the SQLite index is required persistence state or optional support metadata.

### CC-02: Backup import replacement bypasses revision conflicts

- Severity: High
- Category: Data loss / import
- Affected files: `Sources/AppFeature/Features/FileWorkflowFeature.swift`, `Sources/CommenterPersistence/ProjectStore.swift`
- Evidence: `FileWorkflowFeature.swift:92`, `:127`, `:197`; `ProjectStore.swift:216`
- What the code says: pending import carries `expectedRevision`.
- What actually happens: backup preview paths set `expectedRevision: nil`; save conflict checks only run when expected revision is non-nil.
- Why this matters: a stale preview can overwrite a newer local project.
- Reproduce/verify: preview backup for existing project, mutate/save project, confirm backup import.
- Recommended fix: capture current revision for colliding projects and re-check at confirm.
- Suggested test: `AppFeatureTests.testBackupImportReplaceFailsWhenExistingProjectRevisionChangesAfterPreview`.
- Deeper design problem: import preview/commit is not fully transactional across time.

### CC-03: AI critique can attach validation to the wrong draft text

- Severity: High
- Category: Async state / AI safety
- Affected files: `Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift`, `Sources/CommentEngine/ReportReadiness.swift`
- Evidence: `ProjectAIWorkflowFeature.swift:604-619`; `ReportReadiness.swift:220`
- What happens: critique request captures text; completion writes validation without checking current text still matches.
- Why this matters: report readiness can be blocked or trusted based on stale AI validation.
- Reproduce/verify: start critique, edit text, deliver completion.
- Recommended fix: carry request fingerprint through action and reject stale completion.
- Suggested tests: `testAICritiqueResultIsDiscardedWhenDraftChangesBeforeCompletion`, `testStaleValidationFingerprintDoesNotDriveReadiness`.
- Deeper design problem: async AI actions need a shared freshness contract.

### CC-04: Warning review semantics are incomplete

- Severity: Medium/High
- Category: AI review / export gate
- Affected files: `Sources/CommenterDomain/Models.swift`, `Sources/AppFeature/Features/ProjectEditingFeature.swift`, `Sources/CommentEngine/ReportReadiness.swift`
- Evidence: `Models.swift:812`; `ProjectEditingFeature.swift:181-202`; `ReportReadiness.swift:232`
- What happens: warning-review state exists, but approval/export can proceed through approved fingerprint without separately requiring or recording warning review.
- Why this matters: review UI risks becoming decorative.
- Recommended fix: either approval records warning review, or export requires current warning review.
- Suggested test: `testAIApprovalRequiresOrRecordsWarningReview`.

### CC-05: Report freshness fingerprint over-invalidates reports

- Severity: Medium
- Category: Domain logic
- Affected files: `Sources/CommentEngine/ReportGenerator.swift`, `Sources/CommentEngine/ReportReadiness.swift`
- Evidence: `ReportGenerator.swift:675`, `:688`; `ReportReadiness.swift:249`
- What happens: project name, term, and global subject order can mark a report stale even if its text inputs did not change.
- Why this matters: teachers can be forced into unnecessary regeneration.
- Recommended fix: separate text-generation fingerprint from export-package metadata fingerprint.
- Suggested tests: `testProjectNameChangeDoesNotMakeReportStale`, `testUnrelatedSubjectSelectionDoesNotInvalidateExistingReport`.

### CC-06: Export privacy checks ignore private strings shorter than four characters

- Severity: Medium
- Category: Privacy / export verification
- Affected files: `Sources/CommenterImportExport/ReportDocumentFile.swift`, `Sources/CommenterImportExport/ReviewWorkbookFile.swift`
- Evidence: `ReportDocumentFile.swift:222`; `ReviewWorkbookFile.swift:199`
- What happens: forbidden strings are filtered with `trimmed.count >= 4`.
- Why this matters: short sensitive terms like `IEP`, `504`, initials, or internal codes are not verified absent.
- Recommended fix: field-aware forbidden-string collection; check private fields even when short.
- Suggested tests: `testShortPrivateInternalNoteIsForbiddenFromDOCX`, `testShortPrivateInternalNoteIsForbiddenFromXLSXAndXLS`.

### CC-07: XLSX import fallback can mask parser errors

- Severity: Medium
- Category: Import correctness
- Affected file: `Sources/CommenterImportExport/SpreadsheetImportFile.swift`
- Evidence: `SpreadsheetImportFile.swift:74-99`
- What happens: CoreXLSX parse failure falls back to custom OOXML parsing.
- Why this matters: malformed files can be interpreted by a weaker parser instead of failing clearly.
- Recommended fix: classify fallback only for known supported failure modes and record fallback evidence in import preview.
- Suggested test: malformed XLSX where CoreXLSX fails must not silently import unless fallback is explicitly expected.

### CC-08: Foundation Models path is not proven compiled in current CI

- Severity: High for AI claims
- Category: Build matrix / platform API
- Affected files: `Sources/CommenterAI/AIClient.swift`, `Sources/CommenterAI/FoundationModelReportGenerator.swift`
- Evidence: `AIClient.swift:33`; `FoundationModelReportGenerator.swift:5`, `:8`
- What happens: live AI code is behind `#if canImport(FoundationModels)` and iOS/macOS 26 availability.
- Why this matters: current CI can be green while excluding the most platform-sensitive AI implementation.
- Recommended fix: add Xcode/iOS 26 SDK compile lane and runtime unavailable/available/timeout tests.
- Suggested test: `testFoundationModelsCompileOnXcode26`.

## 9. Performance and Efficiency Defects

| Severity | Finding | Evidence | User impact | Fix |
| --- | --- | --- | --- | --- |
| Medium | Generation reparses about 20MB bundled JSON per generation call. | `Sources/AppFeature/CommentEngineClient.swift:28`; `ProductionCommentDataset.loadBundled()` | Repeated generate cycles can feel slow on phone. | Cache validated dataset in an actor/dependency. |
| High | Results screen renders every student x selected subject. | `WorklistSections.swift:575-576` | Large classes create hundreds of controls in one list. | Add student/subject filters and focused routes. |
| Medium | `WorklistSections.swift` is 2,800+ lines with many inline closures and computed filters/sorts. | `WorklistSections.swift:1`, many `Binding(get:)`, `.filter`, `.sorted` hits | Harder SwiftUI invalidation and slower rendering. | Split views; introduce focused view state. |
| Medium | `WorklistRootView` takes whole `Project` and many closures. | `WorklistRootView.swift:7`, `:94` | Parent state changes can reevaluate too much UI. | Use feature-scoped state/store slices. |
| Medium | Screenshot workflow has long fragile UI path and duplicated required names. | `.github/workflows/ios-ci.yml`, `.github/workflows/ios-screenshots.yml`; `UITests/...` | CI maintenance pain and flaky screenshots. | Centralize screenshot validation script. |
| Low | Large release images and 20MB dataset live in repo. | file-size scan | Clone/build footprint is acceptable but noticeable. | Keep dataset intentional; avoid adding more large generated assets without policy. |

## 10. Architecture and File Organization Defects

The architecture has real modular intent: `CommenterDomain`, `CommentEngine`, `CommenterPersistence`, `CommenterImportExport`, `CommenterReportSafety`, `CommenterAI`, `DesignSystem`, `AppFeature`, and app host are separate. That is good.

The bad news: several files are doing too much.

| Severity | File | Problem | Recommended split |
| --- | --- | --- | --- |
| High | `Sources/AppFeature/Views/WorklistSections.swift` | Giant multi-feature SwiftUI surface: metadata, import preview, roster, student editor, subjects, results, reports, AI, exports, backup, shared components. | Split into `ProjectMetadataSection.swift`, `RosterSection.swift`, `StudentEditorView.swift`, `SubjectsSection.swift`, `ResultsSection.swift`, `ReportsSection.swift`, `AIStudioSection.swift`, `ExportSections.swift`, `WorklistPrimitives.swift`. |
| High | `Tests/AppFeatureTests/AppFeatureTests.swift` | 2,700+ line reducer test god file. | Split by workflow: project lifecycle, import/export, reports, AI, backup, support. |
| Medium | `Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift` | AI workflow has many concerns: bulk queue, single preview, tone, critique, evidence drafts, warning review. | Split into AI request freshness, bulk queue, single-report AI, evidence draft, warning review helpers. |
| Medium | `Sources/CommenterImportExport/SpreadsheetImportFile.swift` | CSV/XLSX/XLS parsing and custom OOXML/BIFF fallback in one file. | Split CSV adapter, XLSX CoreXLSX adapter, XLSX fallback parser, XLS OLE/BIFF adapter. |
| Medium | `Sources/CommenterDomain/Models.swift` | Broad domain model registry. | Split project/student/results/reports/AI/import-export metadata if API stability allows. |
| Medium | `Sources/DesignSystem/CommenterStationeryDesignSystem.swift` | Many decorative and functional primitives mixed. | Split tokens, cards, rows, status, decorative-only components. |
| Medium | `Sources/CommentEngine/ReportGenerator.swift` | Generation, fingerprinting, formatting, selection logic. | Split generator, fingerprint builder, variant selection, text assembly. |
| Medium | `docs/ledgers/WORKLOG.md` | Long append-only history, hard to extract current state. | Keep append-only but add current status index. |
| Medium | `docs/ledgers/VALIDATION_LEDGER.md` | Repeated historic validation entries obscure current gate reality. | Add current gate matrix at top. |

## 11. Custom CSS and Component Audit

This is a SwiftUI app, so there is no CSS audit surface. The equivalent risk is custom SwiftUI controls and custom design-system primitives.

Custom components found:

- custom tabs through `TabView` wrappers in `AppView`;
- custom storage/status cards;
- custom stationery page/card/tape/texture/footer/doodle components in `CommenterStationeryDesignSystem.swift`;
- custom checkbox-like subject buttons in `WorklistSections.swift:474-482`;
- custom achievement selector/buttons in `WorklistSections.swift:706-806`;
- custom option pill buttons and toggle groups in `WorklistSections.swift:874-981`;
- custom status chips/action rows/empty cards/form rows in `WorklistSections.swift:2553-2815`;
- custom support diagnostic rows/hash blocks in `SupportRootView.swift:396-464`;
- native wrapper `ActivityShareSheet`.

Assessment:

| Component area | Acceptability | Problem | Recommendation |
| --- | --- | --- | --- |
| Native file importer/exporter/share | Good | Uses native APIs; needs device QA. | Keep. |
| Stationery visual system | Mixed | Distinctive but too decorative for dense teacher work. | Reduce decorative chrome on editing screens. |
| Custom checkbox/toggles | Weak | Native semantics are better. | Use `Toggle` or explicit accessibility traits/hints. |
| Custom form rows | Weak for accessibility | Fixed label widths and custom layout. | Prefer `Form`, `LabeledContent`, `Grid`, `ViewThatFits`. |
| Custom AI cards/diff | Acceptable | Product-specific and trust-sensitive. | Keep but split and simplify. |
| Custom export/backup panels | Acceptable | Product-specific state copy. | Improve labels and cleanup truth. |

Design-system cleanup:

1. Define which components are decorative and which are functional.
2. Move dense editing workflows toward native `Form`/`List` patterns.
3. Keep brand accents in headers/empty states, not around every control.
4. Add Dynamic Type and high-contrast screenshots.
5. Make every custom button/toggle pass VoiceOver role/value checks.

## 12. Test Coverage Audit

Frameworks:

- SwiftPM XCTest unit/reducer tests via `Package.swift:99-136`.
- TCA `TestStore` style tests in `Tests/AppFeatureTests/AppFeatureTests.swift`.
- XCUITest screenshot tests in `UITests/CommenterIOSScreenshotTests`.
- Hosted GitHub Actions runs Swift package tests, app build, and screenshot capture.

Current test strengths:

- deterministic generation and dataset validation;
- placeholder/report safety;
- import validation;
- export package structure and privacy checks;
- persistence save/load/revision/recovery/tamper tests;
- many AppFeature reducer workflows;
- screenshot journey captures many screens.

Current test weaknesses:

- cannot be run locally in this Windows environment;
- no coverage measurement command found/run;
- release validators do not fail TODO metadata;
- no lockfile enforcement test;
- no privacy-manifest lint in this local environment;
- no archive/TestFlight/physical-device proof;
- target-app open validation is not automated;
- stale AI critique and stale backup preview conflicts missing;
- custom XLS/DOCX/XLSX compatibility relies on internal package checks, not external app evidence;
- Dynamic Type/accessibility UI coverage is weak.

Missing-test matrix is in Appendix B.

## 13. Documentation Audit

| Severity | Doc | Problem | Evidence | Fix |
| --- | --- | --- | --- | --- |
| High | `AGENTS.md` | Says initial scaffold/minimal host, stale vs actual code. | `AGENTS.md:38-39`, `:60` | Update repository snapshot. |
| High | `docs/CHAT_HANDOFF.md` | Says repo contains planning/handoff files, initial Swift scaffold, minimal Xcode host; next step source-truth parity slices. | `docs/CHAT_HANDOFF.md:99-103` | Replace with current product/source map. |
| High | `docs/backlog/INITIAL_BACKLOG.md` | Implemented features remain unchecked. | deterministic generation, persistence, UI, import/export, tests sections | Archive as historical or update with evidence. |
| High | `docs/release/app-store/**` | Draft release package has TODOs but validators pass. | `remaining_inputs.md:2-23`, `todo_placeholders_to_replace.txt:1-22` | Add submission-ready validator and current release status. |
| Medium | `docs/dependencies/DEPENDENCY_AUDIT.md` | ZIPFoundation version drift. | says `0.9.0`; `Package.swift:30` is `0.9.11` | Sync docs with manifest. |
| Medium | `docs/OSS_DEPENDENCY_POLICY.md` | Uses `from`/`.upToNextMinor` examples while manifest uses exact pins. | `OSS_DEPENDENCY_POLICY.md:44-50`; `Package.swift:27-32` | Distinguish approved minimums vs actual pins. |
| Medium | `docs/ledgers/DATA_LEDGER.md` | "Current Generated Artifacts" is stale scaffold-era list. | `DATA_LEDGER.md:72-79` | Rename or update. |
| Medium | `docs/ledgers/VALIDATION_LEDGER.md` | Too historical; current status hard to extract. | repeated unavailable tool entries; `Future Required Gates` | Add current gate matrix. |
| Medium | `docs/release/app-store/06_support_site_drafts/support.html` | TODO email and "fake sample data" wording. | `support.html:18` | Rewrite before publication. |
| Low | `docs/source-truth/commenterv3-source-map.md` | Absolute `C:\Commenterv3` source paths are machine-specific. | source map header | Mark as local-only or add mirrored checksums. |

## 14. Agent Instructions Audit

Strong parts:

- The truthfulness prime directive is excellent and matches the repo's real risk profile.
- It explicitly forbids fake persistence, placeholder logic, and misleading UI.
- It requires source-truth inspection before porting.
- It warns about line endings and staged whitespace.
- It tells agents to use ledgers selectively rather than churn every doc.

Problems:

| Severity | Instruction problem | Evidence | Impact | Fix |
| --- | --- | --- | --- | --- |
| High | Repository snapshot is stale. | `AGENTS.md:38-39`, `:60` | Agents may treat real code as scaffold. | Update snapshot to current broad MVP source surface. |
| Medium | Install/debug recommendations are too platform-mixed and volatile. | `AGENTS.md:198-214` | Windows agents may run irrelevant install commands; stars/releases age. | Move optional install guidance to separate doc. |
| Medium | Instructions say fix any encountered fake state completely while working. | `AGENTS.md:97-99` | For audit-only tasks this conflicts with no-patch scope. | Add explicit exception: report fake state during audit-only work. |
| Medium | `.agents/skills` is tracked without clear repo policy. | file inventory | Blurs product repo and agent tooling. | Document vendoring/update policy or remove in cleanup. |
| Low | Definition of Done assumes implementation tasks. | `AGENTS.md` DoD | Audit-only deliverables need a different DoD. | Add audit-only DoD. |

Recommended stronger structure:

1. Current product snapshot.
2. Binding core rules.
3. Audit-only vs implementation-mode behavior.
4. Source-truth discipline.
5. Dependency policy.
6. Verification matrix by environment.
7. Line-ending/staging rules.
8. Release-gate rules.
9. Ledger update rules.

## 15. Work Log, Changelog, and Register Audit

The repo uses append-only ledgers heavily:

- `docs/ledgers/CORE_RULES.md`
- `PROJECT_LEDGER.md`
- `DATA_LEDGER.md`
- `DECISIONS_LEDGER.md`
- `VALIDATION_LEDGER.md`
- `WORKLOG.md`
- `docs/backlog/INITIAL_BACKLOG.md`

Strengths:

- The ledgers capture decisions and prior work evidence.
- The project has a strong no-fake-state culture.
- The validation ledger records environment limits honestly.

Problems:

| Severity | Tracker | Problem | Fix |
| --- | --- | --- | --- |
| High | `INITIAL_BACKLOG.md` | Stale checkboxes contradict source reality. | Convert to historical backlog or update with evidence/date. |
| Medium | `VALIDATION_LEDGER.md` | Too long and repetitive; current gate status not obvious. | Add current gate matrix at top. |
| Medium | `WORKLOG.md` | Append-only but not indexed; hard to find release blockers. | Add dated summary index or link to current status doc. |
| Medium | Release TODO files | Real TODOs exist, but validators allow them. | Keep TODO list but fail final submission validator. |
| Low | Multiple release docs | Same TODOs repeated across `remaining_inputs`, central TODO list, Fastlane, copy-paste docs. | Keep one source of truth and generate/check the rest. |

Recommended future tracking:

- `docs/CURRENT_RELEASE_STATUS.md`: one page, current only.
- `docs/release/SUBMISSION_BLOCKERS.md`: owner/date/status/evidence.
- Keep ledgers append-only for history.
- Archive `INITIAL_BACKLOG.md` once reconciled.

## 16. Build, Deployment, and Environment Audit

| Area | Status | Evidence | Risk |
| --- | --- | --- | --- |
| Swift package manifest | Present | `Package.swift` | Good, but no lockfile. |
| Direct dependency pins | Exact | `Package.swift:27-32` | Good for direct deps; transitive resolution still needs `Package.resolved`. |
| `Package.resolved` | Missing | `rg --files -g Package.resolved` none | Release reproducibility blocker. |
| Xcode project | Present | `CommenterIOS.xcodeproj` found by XcodeBuildMCP | Local build unavailable. |
| Local Swift/Xcode | Missing | `swift`, `xcodebuild`, `xcrun` not recognized | Local verification blocked. |
| Hosted CI | Latest main green | `gh run view 27435465645` | Positive but narrower than release gates. |
| Archive/TestFlight | Not automated/proven | CI uses simulator build with `CODE_SIGNING_ALLOWED=NO` | App Store readiness unproven. |
| Signing/team | Not configured in repo | project settings have empty `DEVELOPMENT_TEAM` | Expected maybe, but release blocker. |
| Privacy lint | Skipped locally | validator warning | Need macOS `plutil`/archive privacy report. |
| Fastlane | Draft metadata | root `fastlane/metadata/en-AU/*.txt` TODO | Not submission-ready. |
| Release assets | Validator passes | asset validation command | Assets still draft by docs. |

## 17. Security, Privacy, and Data Safety Audit

Confirmed clean:

- No obvious committed API tokens/secrets from regex scan.
- No production `URLSession`, Firebase, analytics, telemetry, OpenAI, Anthropic, or Gemini source path found.
- `PrivacyInfo.xcprivacy` declares no tracking and no collected data.
- Public docs avoid the strongest false claim "student data never leaves your phone" and mention native share/export destinations.

Confirmed risks:

| Severity | Risk | Evidence | Fix |
| --- | --- | --- | --- |
| High | SQLite index stale after hidden failure. | `ProjectStore.swift:250`, `:272`, `:365` | Fail/surface degraded state. |
| High | Temp export deletion can silently fail. | `ProjectStoreClient.swift:249-251` | Return cleanup result. |
| Medium | File protection uses `.completeUntilFirstUserAuthentication`. | `ProjectStore.swift:442`; `ProjectStoreClient.swift:276`; `ProtectedFileWrites.swift:17` | Use `.complete` unless background access is required. |
| Medium | Support screen shows raw project name/ID. | `SupportRootView.swift:122` | Redact by default with reveal. |
| Medium | Redaction hashes are deterministic and short. | `SupportDiagnostics.swift:216`; `TextFingerprint.swift:3` | Salt/session labels for copied diagnostics. |
| Medium | Export leak verifier ignores short private strings. | `ReportDocumentFile.swift:222`; `ReviewWorkbookFile.swift:199` | Field-aware checks. |
| Medium | Weak backup KDF iterations accepted by lower-level path. | `BackupEnvelope.swift:15`, `:290` | Enforce minimum or flag legacy weak encryption. |
| Low | Raw `localizedDescription` may expose paths/details. | `AppView.swift:286`; `ProjectWorkflowFeature.swift:242`; `SQLiteProjectIndex.swift:103` | Sanitize errors. |
| Low | CI uploads logs/result bundles/screenshots. | `.github/workflows/ios-ci.yml` | Keep fixture policy and artifact scan. |

## 18. Accessibility Audit

Accessibility could not be verified in simulator locally. Source-level risks:

| Severity | Issue | Evidence | Fix |
| --- | --- | --- | --- |
| High | Main editing workflow requires long scrolling through dense sections. | `WorklistRootView.swift:94`; `WorklistSections.swift` | Focused routes and task hub. |
| Medium | Custom checkbox buttons lack native toggle semantics. | `SubjectSelectionButton` at `WorklistSections.swift:474-482` | Use `Toggle` or accessibility traits/hints. |
| Medium | Fixed label widths break Dynamic Type. | `WorklistSections.swift:2632-2639` | Use native form rows / adaptive layout. |
| Medium | Decorative footer may interfere with tappability. | `WorklistRootView.swift:256`; screenshot safe-tap logic | Remove from editing screens or ensure no tap interference. |
| Medium | AI/report editor density is high. | `WorklistSections.swift:1475+` | Collapse advanced controls, separate configure/review. |
| Low | Hardcoded literal UI strings despite `defaultLocalization`. | `Package.swift:7`; many `Text` literals | Add localization/String Catalog plan. |
| Low | Screen reader wording for diagnostics may be too technical. | `SupportRootView.swift` | Add teacher-friendly labels and details disclosure. |

Suggested accessibility tests:

- Dynamic Type screenshot suite.
- VoiceOver role/value checks for subject/achievement/custom toggles.
- Keyboard/external keyboard navigation sanity.
- High contrast/dark mode screenshots.
- Tap tests for bottom safe-area actions.

## 19. Dependency and OSS Audit

Manifest dependencies:

| Package | Version in `Package.swift` | Use |
| --- | --- | --- |
| CoreXLSX | exact `0.14.1` | XLSX import |
| OLEKit | exact `0.2.0` | XLS/OLE support |
| GRDB | exact `7.10.0` | SQLite index |
| ZIPFoundation | exact `0.9.11` | OOXML ZIP packaging |
| CodableCSV | exact `0.6.7` | CSV |
| TCA | exact `1.17.0` | App architecture |

Problems:

- `Package.resolved` is absent.
- `docs/dependencies/DEPENDENCY_AUDIT.md:25` says ZIPFoundation exact `0.9.0`, but `Package.swift:30` uses `0.9.11`.
- `docs/OSS_DEPENDENCY_POLICY.md:44-50` shows `from`/up-to-next-minor style examples, while the manifest uses exact pins.
- SwiftDocX is policy-required to evaluate before custom DOCX writer changes, but it is absent.
- Custom XLSX/XLS/DOCX writing remains a policy/release risk, not because custom code is automatically bad, but because these are complex file formats with target-app compatibility requirements.

Dependency verdict: acceptable engineering direction, incomplete release discipline.

## 20. Prioritized Defect Register

| ID | Severity | Category | Title | Evidence | Impact | Recommended Fix | Suggested Test | Priority Order |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: |
| DEF-001 | High | Persistence | SQLite index failures swallowed after save/delete/init | `ProjectStore.swift:250`, `:272`, `:365` | Verified operation can leave stale index | Remove `try?`; fail or degraded status | `testSaveFailsWhenSQLiteIndexCannotBeUpdated` | 1 |
| DEF-002 | High | Data safety | Backup import replacement bypasses revision conflict | `FileWorkflowFeature.swift:92`, `:127`, `:197`; `ProjectStore.swift:216` | Stale preview can overwrite newer local project | Capture/recheck expected revision | `testBackupImportReplaceFailsWhenExistingProjectRevisionChangesAfterPreview` | 2 |
| DEF-003 | High | AI correctness | AI critique can attach stale validation | `ProjectAIWorkflowFeature.swift:604-619` | Teacher may trust wrong validation | Carry request fingerprint and discard stale completion | `testAICritiqueResultIsDiscardedWhenDraftChangesBeforeCompletion` | 3 |
| DEF-004 | High | Release trust | Release validator allows TODO URLs | `validate_app_store_release_package.py:187`; Fastlane TODOs | False submission confidence | Add strict submission validator | `testReleaseSubmissionValidatorFailsTODOs` | 4 |
| DEF-005 | High | Release | `Package.resolved` missing | no file; `DEPENDENCY_AUDIT.md:16` | Non-reproducible release resolution | Resolve and commit lockfile | `testPackageResolvedCommitted` | 5 |
| DEF-006 | High | Build matrix | Foundation Models path not proven compiled | `AIClient.swift:33`; `FoundationModelReportGenerator.swift:5` | AI claims can outrun compiled reality | Xcode/iOS 26 lane | `testFoundationModelsCompileOnXcode26` | 6 |
| DEF-007 | High | UX | Work list is an all-in-one mega screen | `WorklistRootView.swift:94` | Teachers must hunt through long scroll | Task hub/focused routes | UI journey per task | 7 |
| DEF-008 | High | UX scalability | Results renders roster x subjects | `WorklistSections.swift:575-576` | Large classes become unusable | Filter/stepper/focused editing | 25-student UI test | 8 |
| DEF-009 | High | Deployment | No archive/TestFlight release lane | CI simulator build only; empty `DEVELOPMENT_TEAM` | App Store readiness unproven | Protected manual release workflow | `xcodebuild archive` gate | 9 |
| DEF-010 | Medium/High | AI review | Warning review semantics unclear | `Models.swift:812`; `ProjectEditingFeature.swift:181-202` | Warning review may be decorative | Require or record review | `testAIApprovalRequiresOrRecordsWarningReview` | 10 |
| DEF-011 | Medium | Privacy | Temp prepared-file cleanup best-effort | `ProjectStoreClient.swift:249-251` | Private file may remain after UI implies cleanup | Return cleanup result | failed-discard UI test | 11 |
| DEF-012 | Medium | Export privacy | Short private strings ignored | `ReportDocumentFile.swift:222`; `ReviewWorkbookFile.swift:199` | Short sensitive codes not checked | Field-aware forbidden checks | short private field export tests | 12 |
| DEF-013 | Medium | Domain logic | Report freshness over-includes metadata | `ReportGenerator.swift:675`, `:688` | Unnecessary regeneration | Split fingerprints | report-staleness tests | 13 |
| DEF-014 | Medium | Performance | Dataset reparsed on each generation | `CommentEngineClient.swift:28` | Slow repeated generation | Cache validated dataset | load-counter test | 14 |
| DEF-015 | Medium | Dependency | Custom DOCX/XLSX/XLS release risk | dependency audit; writer files | Compatibility risk | Target-app validation or library decision | open-validation matrix | 15 |
| DEF-016 | Medium | Docs | AGENTS/CHAT_HANDOFF call repo scaffold | `AGENTS.md:38-39`; `CHAT_HANDOFF.md:99-103` | Misleads agents | Update snapshot | docs consistency check | 16 |
| DEF-017 | Medium | Docs | Backlog stale | `INITIAL_BACKLOG.md` | Agents chase done work | Archive/update | backlog/source matrix check | 17 |
| DEF-018 | Medium | CI | Privacy lint skipped locally | validator `:254` | Invalid privacy manifest could pass local checks | macOS plutil job | `plutil -lint` CI | 18 |
| DEF-019 | Medium | Repo hygiene | CRLF tracked worktree file | `git ls-files --eol` | Line-ending churn risk | Normalize file | no CRLF check | 19 |
| DEF-020 | Medium | CI maintainability | Screenshot requirements duplicated | workflows | Drift/flaky validation | Shared script | screenshot names match test | 20 |
| DEF-021 | Medium | Accessibility | Custom checkbox/toggle controls | `SubjectSelectionButton` | Weak semantics | Native Toggle/traits | VoiceOver role test | 21 |
| DEF-022 | Medium | Accessibility | Fixed label width | `WorklistSections.swift:2632-2639` | Dynamic Type breakage | Adaptive rows | Dynamic Type screenshot | 22 |
| DEF-023 | Medium | Privacy | Support diagnostics show raw project ID/name | `SupportRootView.swift:122` | Sensitive data visible | Redact by default | support redaction test | 23 |
| DEF-024 | Medium | Backup crypto | Low KDF iterations accepted by serializer/import path | `BackupEnvelope.swift:15`, `:290` | Weak legacy encrypted backups | Minimum floor/warning | weak-KDF import test | 24 |
| DEF-025 | Medium | Import | XLSX fallback can mask parser errors | `SpreadsheetImportFile.swift:74-99` | Bad files may import unexpectedly | Narrow fallback policy | malformed XLSX test | 25 |
| DEF-026 | Medium | Release docs | App Store package has many TODOs | `remaining_inputs.md:2-23` | Not submission-ready | Single blocker register | release docs check | 26 |
| DEF-027 | Medium | Dependency docs | ZIPFoundation version drift | `Package.swift:30`; `DEPENDENCY_AUDIT.md:25` | Agents may "fix" wrong way | Sync docs | dependency-doc comparison | 27 |
| DEF-028 | Medium | Test orchestration | Xcode scheme only includes UI test bundle | `.xcscheme`; `Package.swift:99-136` | Misleading `xcodebuild test` assumptions | Document/add test plan | scheme scope test | 28 |
| DEF-029 | Low | Error privacy | Raw localized errors may expose paths | `AppView.swift:286`; `ProjectWorkflowFeature.swift:242` | Support screenshots may leak paths | Sanitize errors | path-error UI test | 29 |
| DEF-030 | Low | Localization | Hardcoded UI strings | `Package.swift:7`; source literals | App Store/i18n future pain | String Catalog plan | pseudolocalization build | 30 |
| DEF-031 | Low | Copy | "Your reporting companion" is soft | `ProjectsRootView.swift:19` | Weak professional clarity | More concrete screen title | screenshot copy review | 31 |
| DEF-032 | Low | Release copy | Support draft says "fake sample data" | `support.html:18` | Public trust damage | "sample/non-identifying data" | release copy lint | 32 |
| DEF-033 | Low | CI artifact privacy | Screenshots/logs uploaded | workflows | Future real data leak if fixtures drift | Fixture policy/artifact scan | artifact name scan | 33 |
| DEF-034 | Low | Design | Decorative stationery overused | `CommenterStationeryDesignSystem.swift` | Editing screens feel less native | Reduce decorative chrome | visual QA | 34 |
| DEF-035 | Low | Source truth | Dataset transform not documented enough | raw vs normalized hashes | Provenance requires manual inference | Document hash chain/script | transform test | 35 |

## 21. Recommended Fix Plan

### Phase 0: stop-the-line issues

1. Add strict release-mode validator that fails TODO public metadata, missing URLs, missing owner/contact details, and missing final screenshot/privacy proof.
2. Commit `Package.resolved` from a macOS Swift toolchain.
3. Normalize the tracked CRLF `.agents` file and add a no-CRLF check.
4. Add current release status doc that says "not ready" and lists blockers.

### Phase 1: correctness and data safety

1. Make SQLite index update/delete/init failures visible or fatal to the operation.
2. Fix backup import replacement revision checks.
3. Fix stale AI critique validation using request fingerprints.
4. Resolve warning-review semantics.
5. Make prepared-file discard verifiable and user-visible on failure.
6. Strengthen export private-string checks.

### Phase 2: user flow and UX clarity

1. Replace the Work list mega-screen with a project task hub and focused flows.
2. Redesign result entry around student/subject filters.
3. Clarify prepare/save/share export labels.
4. Simplify AI Studio into configure, preview, and review areas.
5. Remove or reduce decorative footer/chrome on editing-heavy screens.

### Phase 3: test coverage

1. Add missing reducer/domain tests listed in Appendix B.
2. Add Dynamic Type, accessibility, and large-class UI tests.
3. Add strict release validator tests.
4. Add privacy manifest lint in macOS CI.
5. Add target-app open validation records for DOCX/XLSX/XLS.

### Phase 4: documentation and repo hygiene

1. Update `AGENTS.md`, `CHAT_HANDOFF.md`, `DATA_LEDGER.md`, `PROJECT_LEDGER.md`, `VALIDATION_LEDGER.md`.
2. Archive or reconcile `INITIAL_BACKLOG.md`.
3. Sync dependency audit and OSS policy with `Package.swift`.
4. Decide/document `.agents/skills` vendoring policy.

### Phase 5: refactors and performance

1. Split `WorklistSections.swift`.
2. Split `AppFeatureTests.swift`.
3. Split custom import/export adapters by format.
4. Cache the validated comment dataset.
5. De-duplicate screenshot workflow logic.

### Phase 6: polish and release readiness

1. Run macOS Swift/Xcode local or hosted validation.
2. Run archive/TestFlight validation.
3. Run physical-device file import/export/share/cancel tests.
4. Finalize public support/privacy/marketing URLs.
5. Replace draft screenshots with actual app UI screenshots.
6. Re-run privacy and dependency/license audits.

## 22. Appendix A: Largest Files and Split Recommendations

| File | Approx size | Problem | Split recommendation |
| --- | ---: | --- | --- |
| `Sources/CommentEngine/Resources/comment-engine.json` | 20.3 MB | Intentional production dataset; large but required. | Keep, but document source hash/normalization. |
| `Tests/AppFeatureTests/AppFeatureTests.swift` | 139 KB / 2700+ lines | God test file. | Split by feature workflow. |
| `Sources/AppFeature/Views/WorklistSections.swift` | 122.6 KB / 2800+ lines | God SwiftUI file. | Split by section and shared primitives. |
| `Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift` | 46.6 KB | Too many AI concerns. | Split freshness, queue, critique, evidence draft, warning review. |
| `Sources/CommenterImportExport/SpreadsheetImportFile.swift` | 33.7 KB | Multiple parsers/fallbacks. | Split CSV/XLSX/XLS adapters. |
| `Sources/CommenterDomain/Models.swift` | 30.4 KB | Broad model dump. | Split domain areas if API stability allows. |
| `Sources/DesignSystem/CommenterStationeryDesignSystem.swift` | 29.1 KB | Decorative + functional primitives mixed. | Split tokens, rows/cards/status/decorations. |
| `Sources/CommentEngine/ReportGenerator.swift` | 37.6 KB | Generation/fingerprints/text assembly mixed. | Split generator/fingerprint/variant selection. |
| `UITests/CommenterIOSScreenshotTests/CommenterIOSScreenshotTests.swift` | 31.7 KB | Long scripted journey. | Split helpers and journeys. |
| `docs/ledgers/WORKLOG.md` | 50 KB | Hard to extract current state. | Add index/current status. |
| `docs/ledgers/VALIDATION_LEDGER.md` | 45.2 KB | Historic repetition. | Add current gate matrix. |

## 23. Appendix B: Missing Test Matrix

| Test name | Type | Target | Scenario | Why it matters |
| --- | --- | --- | --- | --- |
| `testSaveFailsWhenSQLiteIndexCannotBeUpdated` | Unit | `FileProjectStoreTests` | Index path unwritable during save | Prevents false verified save. |
| `testDeleteReportsSQLiteIndexCleanupFailure` | Unit | `FileProjectStoreTests` | Delete project when index delete fails | Prevents stale index after success. |
| `testStorageLayoutReportsIndexInitializationFailure` | Unit | `ProjectStore` | Index initialize fails | Prevents hidden degraded storage. |
| `testBackupImportReplaceFailsWhenExistingProjectRevisionChangesAfterPreview` | Reducer | `AppFeatureTests` | Existing project changes after backup preview | Prevents silent overwrite. |
| `testAICritiqueResultIsDiscardedWhenDraftChangesBeforeCompletion` | Reducer | `AppFeatureTests` | Edit draft while critique request in flight | Prevents stale AI validation. |
| `testStaleValidationFingerprintDoesNotDriveReadiness` | Domain | `ReportReadinessTests` | Validation fingerprint differs from current text | Prevents wrong readiness state. |
| `testAIApprovalRequiresOrRecordsWarningReview` | Reducer/domain | `AppFeatureTests` | `passedWithWarnings` AI validation | Resolves warning-review contract. |
| `testProjectNameChangeDoesNotMakeReportStale` | Domain | `ReportReadinessTests` | Rename project only | Avoids false stale report. |
| `testUnrelatedSubjectSelectionDoesNotInvalidateExistingReport` | Domain | `ReportReadinessTests` | Toggle unrelated subject | Avoids false stale report. |
| `testBundledDatasetMatchesDocumentedSourceTruthTransform` | Dataset/script | `ProductionCommentDatasetTests` | Derive bundled dataset from source hash | Auditable provenance. |
| `testCommentEngineDatasetLoadsOnceAcrossMultipleGenerations` | Unit | `CommentEngineClient` | Generate twice | Prevents repeated 20MB parse. |
| `testShortPrivateInternalNoteIsForbiddenFromDOCX` | Unit | `ReportDocumentFileTests` | Internal note `IEP` | Privacy safety net. |
| `testShortPrivateInternalNoteIsForbiddenFromXLSXAndXLS` | Unit | `ReviewWorkbookFileTests` | Internal note `504` | Privacy safety net. |
| `testPreparedFileDiscardFailureShowsCleanupWarning` | Reducer/UI | `FileWorkflowFeature` | Mock discard failure | Honest temp cleanup. |
| `testReleaseSubmissionValidatorFailsTODOs` | Script | release validator | TODO URLs remain | Stops false release pass. |
| `testPackageResolvedCommitted` | CI | root | No `Package.resolved` | Release reproducibility. |
| `testNoCRLFWorktreeFiles` | CI | repo | `w/crlf` present | Line-ending discipline. |
| `testPrivacyManifestPlutilLint` | macOS CI | `PrivacyInfo.xcprivacy` | Run `plutil -lint` | App Store privacy readiness. |
| `testDependencyAuditMatchesPackageSwift` | Script | docs + manifest | ZIPFoundation/version drift | Dependency docs truth. |
| `testScreenshotNamesMatchWorkflowRequirements` | Script | workflows + UI tests | Required name lists drift | CI stability. |
| `testArchiveBuildReleaseConfiguration` | Release CI | Xcode project | Signed archive | App Store readiness. |
| `testExportedDOCXOpensInWordOrPages` | Manual/device | export workflow | Open generated DOCX | Custom writer proof. |
| `testExportedXLSXOpensInExcelNumbersLibreOffice` | Manual/device | export workflow | Open generated XLSX | Custom writer proof. |
| `testExportedXLSOpensInTargetApps` | Manual/device | legacy XLS | Open generated XLS | Highest format risk. |
| `testFoundationModelsCompileOnXcode26` | SDK CI | `CommenterAI` | Compile with FoundationModels available | AI claim proof. |
| `testAIAvailableRuntimeOnDevice` | Device | AI workflow | Available/unavailable/timeout | Runtime AI proof. |
| `testLargeClassResultsUsability` | UI | Work list | 25+ students, 6 subjects | Real teacher scale. |
| `testDynamicTypeWorklistScreens` | UI/accessibility | Work list | Accessibility text sizes | Accessibility readiness. |
| `testSubjectSelectionVoiceOverSemantics` | UI/accessibility | Subjects | VoiceOver role/value | Custom control semantics. |
| `testSupportDiagnosticsRedactedByDefault` | Unit/UI | Support | Raw project ID/name absent | Privacy. |

## 24. Appendix C: Documentation Rewrite Checklist

| File | Required update |
| --- | --- |
| `AGENTS.md` | Replace scaffold/minimal-host snapshot with current broad MVP source surface; add audit-only behavior exception; clarify environment-specific validation. |
| `docs/CHAT_HANDOFF.md` | Replace stale scaffold handoff with current architecture, implemented surfaces, and release blockers. |
| `docs/backlog/INITIAL_BACKLOG.md` | Archive as historical or reconcile every checkbox with source/test evidence and date. |
| `docs/ledgers/PROJECT_LEDGER.md` | Split "source-present" from "release-ready"; list current blockers explicitly. |
| `docs/ledgers/DATA_LEDGER.md` | Document raw source hash, normalized bundle hash, transform process, and current generated/release artifacts. |
| `docs/ledgers/VALIDATION_LEDGER.md` | Add current gate matrix at top; keep history below. |
| `docs/ledgers/WORKLOG.md` | Add index/current status pointer; keep append-only history. |
| `docs/OSS_DEPENDENCY_POLICY.md` | Sync manifest constraint style and actual versions; clarify custom writer exceptions. |
| `docs/dependencies/DEPENDENCY_AUDIT.md` | Fix ZIPFoundation version; add `Package.resolved` status; clarify SwiftDocX/libxlsxwriter decisions. |
| `docs/release/app-store/01_app_store_connect/remaining_inputs.md` | Keep as blocker list but connect to strict validator. |
| `docs/release/app-store/08_after_you_add_contact_details/todo_placeholders_to_replace.txt` | Keep single source of TODO truth or generate from release status. |
| `docs/release/app-store/01_app_store_connect/app_store_metadata.json` | Replace TODOs only when real URLs/owner exist; do not submit as-is. |
| `fastlane/metadata/en-AU/support_url.txt` | Replace TODO with real HTTPS support URL before release. |
| `fastlane/metadata/en-AU/privacy_url.txt` | Replace TODO with real HTTPS privacy URL before release. |
| `fastlane/metadata/en-AU/marketing_url.txt` | Replace TODO with real HTTPS URL or document blank/omitted behavior. |
| `docs/release/app-store/06_support_site_drafts/support.html` | Replace TODO email and "fake sample data" wording. |
| `docs/release/APP_STORE_RELEASE_CHECKLIST.md` | Add exact proof requirements for AI states, target-app open validation, privacy report, archive/TestFlight. |
| `.github/workflows/*` | Move screenshot required-name logic into shared script and document current workflow roles. |
| `.agents/skills` policy doc | Decide whether vendored agent skills belong in repo and how to update/normalize them. |

## 25. Appendix D: Open Questions

1. Should SQLite index update/delete/init failure fail the whole operation, or should the product expose a degraded "project file saved, index repair needed" state?
2. Is approval intended to count as warning review for AI validations with warnings, or must warning review be separate before approval/export?
3. What exact transform produced the bundled normalized `comment-engine.json` from the live CommenterV3 source file, and should that transform be scripted in-repo?
4. Are custom DOCX/XLSX/XLS writers intended as temporary bridges, or is the project prepared to record a formal exception to the OSS/native-first policy after target-app validation?
5. What is the intended final public support URL, privacy policy URL, seller/developer name, and copyright owner?
6. Should `.completeUntilFirstUserAuthentication` remain the file-protection policy for student data, or should sensitive project/export files use `.complete`?
7. Are `.agents/skills/**` intentionally vendored product-repo content or accidental agent tooling leakage?
8. What macOS/Xcode/iOS 26 environment will be the release authority for Foundation Models, App Intents, archive, privacy report, and physical-device validation?
9. Should the app remain primarily a single Work list, or should the production UX move to focused task screens as the MVP plan implies?
10. Are App Store draft screenshots intended to be replaced entirely by real simulator screenshots, or are the generated marketing masters part of the final submission strategy?
