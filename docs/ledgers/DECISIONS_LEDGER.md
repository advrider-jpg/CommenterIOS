# Decisions Ledger

Append durable architectural, product, data, testing, and process decisions
here. Do not rewrite history; supersede entries with dated notes.

## 2026-05-31 - Supersede OLEKit removal; fix Data slice crash

Decision:
Keep `OLEKit` in the Swift package manifest as the approved OLE container
fallback for legacy `.xls` import. Supersede the earlier same-day removal
decision: the CI signal-5 root cause was the local compound-file reader indexing
a `Data.SubSequence` as though it were zero-based, not a proven OLEKit runtime
crash.

Rationale:
The signal-5 failure persisted after OLEKit was removed, proving the dependency
was not the root cause. The importer and writer validation now reset directory
slices to zero-based `Data` before walking 128-byte OLE directory entries.
Maintaining OLEKit keeps the repo aligned with the dependency policy while the
local BIFF layer remains fixture-limited.

Evidence:
PR CI runs on 2026-05-31 continued to fail with signal code 5 after the
temporary OLEKit removal. `SpreadsheetImportFile.swift` and
`LegacyXLSWorkbookWriter.swift` both sliced compound-file directory sectors and
then indexed them from zero. The current fix wraps those slices in `Data(...)`.

Impact:
Legacy `.xls` import keeps the approved OLEKit fallback plus the local
fixture-backed BIFF decoder. Full XLS parity still requires a proven mature
parser such as an iOS-compatible `libxls` integration before broader release
claims.

## 2026-05-31 - Remove OLEKit after CI crash and fail closed for legacy XLS

Decision:
Remove `OLEKit` from the Swift package manifest and legacy XLS import path.
Keep the smallest fixture-limited local OLE compound-file extractor plus narrow
BIFF decoder for current `.xls` MVP fixtures, and report unsupported or
unreadable compound files as import failures rather than falling through to a
process-level dependency crash.

Rationale:
GitHub Actions repeatedly exited Swift package tests with signal code 5 when
the legacy XLS import fixture reached the OLEKit-linked path. A crash is less
truthful than an explicit unreadable-workbook failure. Full `.xls` parity still
requires a proven iOS-compatible `libxls` or equivalent parser before release
claims expand beyond fixture-backed support.

Evidence:
PR CI runs on 2026-05-31 failed during
`ProjectImportCommitTests.testResultsImportPreviewParsesNarrowLegacyXLSFixture`
with no XCTest assertion failure and `error: Exited with unexpected signal code
5`; `Package.swift`; `SpreadsheetImportFile.swift`;
`docs/OSS_DEPENDENCY_POLICY.md`.

Impact:
Legacy `.xls` support remains real only for the locally decoded fixture-backed
OLE/BIFF subset. Unsupported files fail visibly as unreadable. Future work must
evaluate `libxls` or another mature iOS-compatible parser before claiming broad
legacy XLS parity.

## 2026-05-31 - OSS/native-first dependency policy is binding

Decision:
Use `docs/OSS_DEPENDENCY_POLICY.md` as the binding dependency list and
custom-code limit for generic infrastructure. Preserve the worker-added
packages where possible (`swift-composable-architecture`, `CodableCSV`,
`CoreXLSX`, and `OLEKit`) and require approved native/OSS options before custom
CSV, XLSX, XLS/OLE, DOCX/OOXML, SQLite, file-flow, or reusable UI
infrastructure.

Rationale:
The user explicitly wants barely any custom code. The previous implementation
pass drifted toward custom parsers and oversized bespoke app files. A concrete
dependency policy is now required so future agents use mature packages/native
APIs first and only write Commenter-specific logic or small adapters.

Evidence:
Explicit user instruction; `docs/OSS_DEPENDENCY_POLICY.md`;
`docs/decisions/0001-native-swiftui-tca.md`; `docs/CHAT_HANDOFF.md`.

Impact:
Future work must audit dependency fit before implementing generic
infrastructure. Violations are release blockers unless a later decision ledger
entry records a specific exception.

## 2026-05-30 - Start a new native iOS repo

Decision:
Create `C:\CommenterIOS` as a fresh repo for the native iPhone-first port of
CommenterV3.

Rationale:
The user wants a new app/repo that ports relevant behavior rather than modifying
the browser app in place.

Evidence:
Initial commits `ab754be` and `461d7fd`.

## 2026-05-30 - Use SwiftUI/TCA as the architecture direction

Decision:
Use SwiftUI and The Composable Architecture for the production MVP.

Rationale:
TCA gives explicit state/effect modeling and reducer tests, which matches the
repo's no-fake-success requirements for save, import, export, generation, and
share flows.

Evidence:
`docs/decisions/0001-native-swiftui-tca.md`.

## 2026-05-30 - No deferral of required parity formats

Decision:
CSV, XLSX, legacy XLS, DOCX, and backup JSON support are MVP requirements, not
post-MVP work.

Rationale:
The user explicitly rejected deferral. The plan must treat these as release
requirements.

Evidence:
`docs/CHAT_HANDOFF.md`; `docs/PRODUCTION_MVP_PLAN.md`.

## 2026-05-30 - Add repo guardrails and ledgers

Decision:
Add `AGENTS.md`, ledger files, strict core rules, line-ending discipline, and
worklog discipline before scaffolding app code.

Rationale:
The user asked whether the new repo had the same strict setup as other repos.
The planning seed did not, so the guardrail harness was added before further
implementation.

## 2026-05-31 - Host the Swift package in a native Xcode app target

Decision:
Add `CommenterIOS.xcodeproj` as a minimal native iOS app host that compiles the
SwiftUI app entry and links the local `AppFeature` Swift package product.

Rationale:
SwiftPM package tests are useful for module validation, but TestFlight,
simulator, archive, privacy-manifest, signing, and App Store release gates need
a real iOS app target and shared scheme. The app target should host package
modules rather than duplicating product behavior outside the TCA/package seams.

Evidence:
`CommenterIOS.xcodeproj`; `Sources/AppFeature/AppEntryView.swift`;
`Sources/CommenterIOSApp/CommenterIOSApp.swift`.

## 2026-05-31 - Keep dependency posture minimal and native

Decision:
Use native Apple APIs and focused OSS packages for generic infrastructure, with
custom code reserved for Commenter domain/product logic, deterministic
generation, truthful local persistence, validation, and small adapters around
native or OSS APIs.

Rationale:
This keeps the port local-first and production-oriented without taking ownership
of broad generic infrastructure that mature packages already provide.

Evidence:
`Package.swift`; `docs/dependencies/DEPENDENCY_AUDIT.md`.

## 2026-05-31 - Do not add SwiftUIX or SwiftUI Introspect yet

Decision:
Do not add SwiftUIX or SwiftUI Introspect while the current UI can use native
SwiftUI/HIG controls and no owned wrapper need has been proven.

Rationale:
Extra UI dependencies should be justified by a real native UX need. If either is
added later, it should sit behind owned wrappers with tests or simulator
evidence for the behavior being unlocked.

Evidence:
`docs/dependencies/DEPENDENCY_AUDIT.md`.

## 2026-05-31 - Keep legacy XLS parity risk open

Decision:
Do not treat legacy `.xls` parity as complete until full BIFF cell
decoding/writing is backed by mature `libxls`/`libxlsxwriter` integration or a
documented production-grade compatibility reason with real fixtures.

Rationale:
OLE container support alone does not prove complete legacy Excel cell semantics
or target-app compatibility.

Evidence:
`docs/dependencies/DEPENDENCY_AUDIT.md`.

## 2026-05-31 - Document package suitability for DOCX, ZIP, XLSX, and XLS

Decision:
Use the package suitability matrix in
`docs/dependencies/DEPENDENCY_AUDIT.md` as the current decision record for
document/workbook dependency work:

- `ZIPFoundation` is suitable generic ZIP/OOXML infrastructure and should
  replace custom ZIP assembly where a higher-level package does not own the
  package layer.
- `SwiftDocX` must be evaluated before further custom DOCX writer work, but it
  remains proof-gated because the upstream project is young.
- Direct `jmcnamara/libxlsxwriter` is the preferred XLSX writer candidate over
  `damuellen/xlsxwriter.swift` unless the wrapper proves a pinned iOS SwiftPM
  release with no manual native dependency setup.
- `libxls` is a parser candidate for legacy `.xls` import only. It does not
  solve legacy `.xls` export.
- A narrow custom legacy `.xls` writer exception remains temporarily justified
  because no mature iOS SwiftPM BIFF writer was identified, but the exception is
  not release-complete without fixtures and target-app open validation.

Rationale:
The app must keep CSV, XLSX, legacy XLS, DOCX, and backup JSON as real MVP
formats while avoiding ownership of broad generic infrastructure. The current
audit separates suitable generic packages from areas where package support is
not yet proven enough for truthful production behavior.

Evidence:
`docs/OSS_DEPENDENCY_POLICY.md`; `docs/dependencies/DEPENDENCY_AUDIT.md`;
upstream package documentation linked in the audit.

## 2026-06-05 - Permit local Apple Foundation Models AI only behind review gates

Decision:
Apple Foundation Models on-device AI is permitted as an optional local writing
assistance layer. Remote AI, network fallback, cloud persistence, telemetry,
and analytics remain prohibited. Deterministic generation remains the baseline
and fallback, and AI-generated or AI-revised report text must be validated and
teacher-approved before export readiness can be claimed.

Rationale:
The product contract is local/offline and teacher-trust oriented. On-device
Foundation Models can support revision and critique without sending private
student data off-device, but only if availability is truthfully gated and AI
output cannot bypass deterministic validation or teacher review.

Evidence:
`AGENTS.md`; `README.md`; `docs/ledgers/CORE_RULES.md`;
`C:\Users\jackg\Downloads\CommenterIOS_AI_Implementation_Dream_Plan.md`.

## 2026-06-05 - Treat AI revisions as preview artifacts until accepted and approved

Decision:
AI polish results enter app state as pending teacher-review previews. They do
not overwrite report text, mark a report reviewed, save the project, prepare
exports, or share files. The teacher must explicitly accept a preview before it
becomes the current local draft, and that accepted AI-derived draft is still
blocked from export until validation passes and the current text fingerprint is
approved.

Rationale:
This preserves the truthfulness prime directive and prevents model output from
silently changing durable report text or bypassing export readiness. The same
rule must apply to future bulk AI, draft-from-evidence, App Intents, and any
review queue automation.

Evidence:
`Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift`;
`Sources/AppFeature/Views/WorklistSections.swift`;
`Tests/AppFeatureTests/AppFeatureTests.swift`.

## 2026-06-05 - Bulk AI and App Intents cannot bypass in-app review

Decision:
Bulk AI may request model revisions for eligible unlocked drafts, but the only
allowed result is a queue of per-report previews. Bulk AI must be cancellable:
completed model calls may remain as reviewable previews, while queued or
cancelled drafts remain untouched. App Intents may open safe review or
preparation entry points, but they must not generate AI text, approve reports,
prepare exports, or share files invisibly.

Rationale:
Bulk and system-surface actions are higher-risk than single-report buttons
because they can imply background automation. Keeping them preview/open-only
and cancellable preserves local teacher control, review fingerprints,
validation gates, and truthful success states.

Evidence:
`Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift`;
`Sources/CommenterAppIntents/ReviewIntents.swift`;
`CommenterIOS.xcodeproj/project.pbxproj`;
`Tests/AppFeatureTests/AppFeatureTests.swift`.

## 2026-06-05 - Evidence drafts and AI critique remain teacher-review artifacts

Decision:
Report-specific AI settings may override project defaults for future previews,
including teacher-provided do-not-mention constraints. AI draft-from-evidence
may create a pending preview only when report-safe evidence exists, and AI
critique may store validation/review notes only. Neither workflow may overwrite
text, approve a report, save a project, prepare exports, or share files without
the existing explicit teacher actions.

Rationale:
Evidence drafting and critique are useful only if they stay grounded in supplied
facts, obey teacher-provided exclusions, and remain visibly reviewable. Treating
them as preview/check artifacts preserves the local-first truthfulness rule and
prevents report text or export readiness from changing invisibly.

Evidence:
`Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift`;
`Sources/AppFeature/Views/WorklistSections.swift`;
`Sources/CommenterAI/FoundationModelReportGenerator.swift`;
`Tests/AppFeatureTests/AppFeatureTests.swift`.
