# CommenterIOS

Native iPhone-first SwiftUI/TCA rewrite of CommenterV3.

This repository starts from the production plan and source-truth handoff for
porting the offline teacher report-writing app from `C:\Commenterv3` into a
native iOS app.

## Product Contract

CommenterIOS must preserve the core CommenterV3 contract:

- Offline-first operation.
- Local-only project, roster, result, draft, report, backup, and recovery data.
- No account system, cloud sync, analytics SDK, telemetry SDK, remote AI, or
  backend project persistence. Apple Foundation Models on-device AI may be used
  only as a local/offline, teacher-reviewed writing layer when the runtime
  truthfully reports availability.
- Production comment data comes from the real CommenterV3 production dataset,
  not sample fixtures.
- Deterministic generation remains the baseline and fallback even when
  on-device AI is available.
- No user-visible save, import, export, generation, or share success state
  unless the underlying local operation really completed and was verified.
- No unresolved placeholders in generated or exported report text.
- AI-generated or AI-revised report text must pass validation and explicit
  teacher approval before export readiness can be claimed.
- CSV, XLSX, XLS, DOCX, backup JSON, and local iOS document workflows are MVP
  requirements, not later work.

## Current Status

This repo contains the native SwiftUI/TCA MVP source surface for the offline
teacher workflow: bundled production dataset loading, deterministic generation,
local verified project persistence, recovery snapshots, CSV/XLSX/XLS imports,
DOCX/XLSX/XLS report exports, backup JSON import/export, support diagnostics,
and native iOS document workflows for import, export, and share completion. The
AI foundation includes on-device availability checks, project AI defaults with
do-not-mention and required-mention constraints, report-specific AI overrides
for those constraints, Foundation Models revision/draft/critique wiring behind
compile/runtime gates, report-level AI preview accept/reject flow, an AI review
queue, cancellable bulk AI preview queueing, evidence-draft previews, local
safety checks, validation/evaluation fixtures, safe App Intents entry points,
validation metadata, and teacher approval gates before any AI text can become
export-ready.

`CommenterIOS.xcodeproj` is present. Local Swift package and Xcode app-target
validation still require dependency resolution plus an Apple toolchain and iOS
simulator on macOS.

Start with:

- [iOS CI and workflow recommendations](docs/IOS_CI_SKILL_RECOMMENDATIONS.md)
- [Chat handoff](docs/CHAT_HANDOFF.md)
- [Production MVP plan](docs/PRODUCTION_MVP_PLAN.md)
- [Scaffold decision](docs/decisions/0001-native-swiftui-tca.md)
- [Source truth map](docs/source-truth/commenterv3-source-map.md)
- [Initial backlog](docs/backlog/INITIAL_BACKLOG.md)

## Intended Stack

- SwiftUI
- The Composable Architecture
- iPhone-first native HIG UI
- Local Swift packages for domain, generation, persistence, import/export, and
  design system
- File-backed canonical project JSON plus SQLite metadata/index storage
- Native iOS document picker/share/file export flows

## Source Repository

The current production source of truth is:

`C:\Commenterv3`

Do not port behavior from memory alone. Inspect the live source before
implementing each feature.
