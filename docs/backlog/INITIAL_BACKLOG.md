# Initial Backlog

## Epic 0 - Repo Bootstrap

- [ ] Scaffold SwiftUI/TCA app.
- [ ] Preserve all planning docs in the scaffolded app repo.
- [ ] Remove sample flows from the template.
- [ ] Add local Swift package structure.
- [ ] Add initial CI.
- [ ] Add `PrivacyInfo.xcprivacy`.
- [ ] Add dependency/license audit script.

## Epic 1 - Source Audit and Fixtures

- [ ] Extract golden project fixtures from CommenterV3.
- [ ] Extract valid roster CSV/XLSX/XLS fixtures.
- [ ] Extract invalid roster CSV/XLSX/XLS fixtures.
- [ ] Extract valid results CSV/XLSX/XLS fixtures.
- [ ] Extract invalid results CSV/XLSX/XLS fixtures.
- [ ] Extract backup v1 and v2 fixtures.
- [ ] Extract expected generated report outputs.
- [ ] Extract expected DOCX/XLSX/XLS export content.

## Epic 2 - Domain

- [ ] Port project model.
- [ ] Port student model.
- [ ] Port achievement result model.
- [ ] Port generated report model.
- [ ] Port backup envelope model.
- [ ] Port validation issue model.
- [ ] Port project limits.
- [ ] Add Codable round-trip tests.

## Epic 3 - Dataset and Engine

- [ ] Bundle production comment-engine JSON.
- [ ] Decode dataset.
- [ ] Validate dataset.
- [ ] Compute dataset hash.
- [ ] Port subject mapping.
- [ ] Port placeholder detection.
- [ ] Port deterministic generation.
- [ ] Add golden parity tests.

## Epic 4 - Persistence

- [ ] Implement canonical JSON project store.
- [ ] Implement SQLite metadata index.
- [ ] Implement atomic write.
- [ ] Implement read-after-write verification.
- [ ] Implement fingerprints.
- [ ] Implement revision conflicts.
- [ ] Implement recovery snapshots.
- [ ] Add failure injection tests.

## Epic 5 - App Shell

- [ ] Add Projects tab.
- [ ] Add Worklist tab.
- [ ] Add Support tab.
- [ ] Add project creation flow.
- [ ] Add project home.
- [ ] Add save status UI.
- [ ] Add storage warning UI.

## Epic 6 - Teacher Workflow

- [ ] Manual roster entry.
- [ ] Subject selection.
- [ ] Manual results entry.
- [ ] Draft generation.
- [ ] Report editor.
- [ ] Report locking.
- [ ] Readiness blockers.
- [ ] Project backup screen.

## Epic 7 - Import

- [ ] CSV roster import.
- [ ] XLSX roster import.
- [ ] XLS roster import.
- [ ] CSV results import.
- [ ] XLSX results import.
- [ ] XLS results import.
- [ ] Import preview UI.
- [ ] All-or-nothing import commit.

## Epic 8 - Export

- [ ] Backup JSON export.
- [ ] Backup JSON import.
- [ ] DOCX report export.
- [ ] XLSX report export.
- [ ] XLS report export.
- [ ] Share/file export state machine.
- [ ] Cancellation handling.
- [ ] Target-app open verification.

## Epic 9 - QA and Release

- [ ] Unit test suite.
- [ ] TCA reducer tests.
- [ ] Integration tests.
- [ ] UI smoke tests.
- [ ] Simulator matrix.
- [ ] Physical device matrix.
- [ ] No-network privacy checks.
- [ ] App Store metadata.
- [ ] TestFlight upload.
- [ ] Release checklist.

