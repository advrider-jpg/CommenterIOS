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
  backend project persistence.
- Production comment data comes from the real CommenterV3 production dataset,
  not sample fixtures.
- No user-visible save, import, export, generation, or share success state
  unless the underlying local operation really completed and was verified.
- No unresolved placeholders in generated or exported report text.
- CSV, XLSX, XLS, DOCX, backup JSON, and local iOS document workflows are MVP
  requirements, not later work.

## Current Status

This repo is currently a planning and scaffold seed. The SwiftUI/TCA project has
not yet been generated.

Start with:

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

