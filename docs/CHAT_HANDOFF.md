# Chat Handoff

This file preserves the important context from the planning thread that created
`C:\CommenterIOS`.

## User Intent

The user wants a new native iPhone-first iOS app, not a web wrapper. The new app
should be built in a fresh repo and duplicate/port the relevant parts of
CommenterV3.

The desired stack and posture:

- SwiftUI
- The Composable Architecture
- native SwiftUI/HIG
- reusable components
- OSS scaffolding where useful
- the binding package/custom-code policy in `docs/OSS_DEPENDENCY_POLICY.md`
- owned design system
- production-ready MVP, not a thin beta

The user explicitly rejected deferral:

> Nothing is deferred.

Therefore CSV, XLSX, legacy XLS, DOCX, backup JSON, import/export parity,
deterministic generation, local persistence, privacy, TestFlight, and App Store
readiness are all MVP work.

## Source App Summary

CommenterV3 is an offline/browser-persistent teacher report-writing app.
Teachers create class projects, enter rosters, select subjects, enter
achievement results, generate draft report comments, save locally, export
backups, and export finished reports.

Important current behavior:

- Production comment data is `C:\Commenterv3\client\public\data\comment-engine.json`.
- Browser persistence currently uses IndexedDB.
- Saves use revision metadata, read-after-write validation, and fingerprints.
- Backups are JSON envelopes.
- Imports support CSV, XLSX, and legacy XLS.
- Report exports support DOCX, XLSX, and legacy XLS.
- Generated/exported text must not contain unresolved placeholders.
- Unsupported, incomplete, failed, pending, and unavailable paths must be surfaced
  honestly.

## Subagent Findings

Six subagents contributed planning lanes:

- Architecture: use a fresh native SwiftUI/TCA repo; use dependency clients for
  generation, persistence, import, export, share, storage health, file system,
  clock, and UUID; use local JSON plus indexed persistence; do not bring cloud
  or analytics infrastructure.
- UX/HIG: iPhone-first project-centered navigation, not a shrunken dashboard;
  stable tabs for Projects, Worklist, and Support; create/import/export are
  actions, not tabs.
- Data/import/export: preserve production dataset, backup compatibility, CSV,
  XLSX, XLS, DOCX, fingerprints, revision checks, and all-or-nothing imports.
- QA/release: production MVP requires CI, golden parity tests, simulator/device
  matrix, privacy manifest, App Store metadata, TestFlight validation, and no
  fake success states.
- OSS risk: use SwiftUI-TCA-Template and Point-Free TCA; use SwiftUIX and
  SwiftUI Introspect only behind wrappers; avoid Firebase/auth/paywall/VIPER
  starters.
- Dependency posture: use the packages listed in
  `docs/OSS_DEPENDENCY_POLICY.md`; preserve worker-added packages where possible;
  do not hand-roll generic infrastructure unless that policy or a later decision
  ledger entry grants a specific exception.
- Sequencing: critical path is source audit, domain, generation parity,
  persistence, import/export, iPhone workflow, release validation.

## Key Decisions

1. Create a fresh repo rather than modifying `C:\Commenterv3`.
2. Use the current CommenterV3 repo as source of truth.
3. Start from a TCA-oriented scaffold, then replace sample app behavior with
   Commenter-specific modules.
4. Use production Swift packages/modules:
   - `CommenterDomain`
   - `CommentEngine`
   - `CommenterPersistence`
   - `CommenterImportExport`
   - `DesignSystem`
   - `AppFeature`
   - feature packages for projects, roster, subjects, results, generation,
     review/export, import, and support
5. Treat all import/export formats as MVP requirements.
6. Do not allow unsupported paths to masquerade as working paths.
7. Use no telemetry for MVP.
8. Use OSS/native APIs first and keep custom code limited to Commenter-specific
   logic or small adapters.

## Current Repo State

This repo now contains planning and handoff files, an initial Swift package
scaffold for the SwiftUI/TCA app, and a minimal `CommenterIOS.xcodeproj` app
host with a shared `CommenterIOS` scheme.

The next implementation step is to continue from the scaffold into source-truth
parity slices: full dataset validation, generation parity, durable local
persistence, import/export, and XcodeBuildMCP build/run validation on a machine
with Xcode and simulator support.
