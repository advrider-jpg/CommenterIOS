# Initial Backlog

## Epic 0 - Repo Bootstrap

- [x] Scaffold initial SwiftUI/TCA Swift package app.
- [x] Preserve all planning docs in the scaffolded app repo.
- [x] Remove sample flows from the template.
- [x] Add local Swift package structure.
- [x] Add minimal native iOS Xcode app host project.
- [x] Add initial CI.
- [x] Add `PrivacyInfo.xcprivacy`.
- [ ] Add dependency/license audit script.

## Epic 1 - Source Audit and Fixtures

- [ ] Extract golden project fixtures from CommenterV3.
- [ ] Extract valid roster CSV/XLSX/XLS fixtures.
- [ ] Extract invalid roster CSV/XLSX/XLS fixtures.
- [ ] Extract valid results CSV/XLSX/XLS fixtures.
- [ ] Extract invalid results CSV/XLSX/XLS fixtures.
- [x] Extract backup v1 and v2 fixtures.
- [x] Extract expected generated report outputs.
- [ ] Extract expected DOCX/XLSX/XLS export content.

## Epic 2 - Domain

- [x] Port project model.
- [x] Port student model.
- [x] Port achievement result model.
- [x] Port generated report model.
- [x] Port backup envelope model.
- [x] Port validation issue model.
- [x] Port project limits.
- [x] Add Codable round-trip tests.

## Epic 3 - Dataset and Engine

- [x] Bundle production comment-engine JSON.
- [x] Decode dataset.
- [x] Validate full dataset contract.
- [x] Compute dataset hash.
- [x] Port subject mapping.
- [x] Port placeholder detection.
- [x] Port deterministic generation.
- [x] Add golden parity tests.

## Epic 4 - Persistence

- [x] Implement canonical JSON project store.
- [x] Implement SQLite metadata index.
- [x] Implement atomic write.
- [x] Implement read-after-write verification.
- [x] Implement fingerprints.
- [x] Implement revision conflicts.
- [x] Implement recovery snapshots.
- [x] Add failure injection tests.

## Epic 5 - App Shell

- [x] Add Projects tab.
- [x] Add Worklist tab.
- [x] Add Support tab.
- [x] Add project creation flow.
- [x] Add project home.
- [x] Add save status UI.
- [x] Add storage warning UI.

## Epic 6 - Teacher Workflow

- [x] Manual roster entry.
- [x] Subject selection.
- [x] Manual results entry.
- [x] Draft generation.
- [x] Report editor.
- [x] Report locking.
- [x] Readiness blockers.
- [x] Project backup screen.

## Epic 7 - Import

- [x] CSV roster import.
- [x] XLSX roster import.
- [x] XLS roster import.
- [x] CSV results import.
- [x] XLSX results import.
- [x] XLS results import.
- [x] Import preview UI.
- [x] All-or-nothing import commit.

## Epic 8 - Export

- [x] Backup JSON export.
- [x] Backup JSON import.
- [x] DOCX report export.
- [x] XLSX report export.
- [x] XLS report export.
- [x] Share/file export state machine.
- [x] Cancellation handling.
- [ ] Target-app open verification.

## Epic 9 - QA and Release

- [x] Unit test suite.
- [x] TCA reducer tests.
- [x] Integration tests.
- [x] UI smoke tests.
- [ ] Simulator matrix.
- [ ] Physical device matrix.
- [ ] No-network privacy checks.
- [x] App Store metadata.
- [ ] TestFlight upload.
- [x] Release checklist.
