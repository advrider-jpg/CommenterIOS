# AGENTS.md

Required for any AI agent operating in this repository.

## First Read

Use the live checkout as the source of truth. Inspect current files before
editing, and reconcile outside prompts, prior chat history, or memory against
this repository.

Before substantial work, read `docs/ledgers/CORE_RULES.md`. Core rules are
binding project invariants. Do not weaken, bypass, delete, or silently
reinterpret a core rule without explicit user instruction. If a requested change
conflicts with a core rule, stop and report the conflict.

Use the other ledgers only when relevant:

- `docs/ledgers/PROJECT_LEDGER.md`: project purpose, durable posture, major
  components, non-goals, and open questions.
- `docs/ledgers/DATA_LEDGER.md`: source data, generated artifacts, fixture
  boundaries, provenance, and schema/data assumptions.
- `docs/ledgers/DECISIONS_LEDGER.md`: append-only architectural, product, data,
  testing, and process decisions.
- `docs/ledgers/VALIDATION_LEDGER.md`: validation commands, gates, last known
  evidence, and validation gaps.
- `docs/ledgers/WORKLOG.md`: append-only material work history.

Also read:

- `docs/CHAT_HANDOFF.md`
- `docs/PRODUCTION_MVP_PLAN.md`
- `docs/OSS_DEPENDENCY_POLICY.md`
- `docs/source-truth/commenterv3-source-map.md`

## Repository Snapshot

CommenterIOS is the fresh native iPhone-first SwiftUI/TCA port of CommenterV3.
The repo currently starts as a planning/scaffold seed. The production source of
truth for behavior is still the live `C:\Commenterv3` checkout.

CommenterIOS must preserve CommenterV3's core product posture:

- offline-first operation
- local-only private teacher/student data
- production comment-engine data only
- deterministic generation
- truthful persistence, import, export, share, and generation states
- no unresolved placeholders in generated or exported report text

The production MVP includes CSV, XLSX, legacy XLS, DOCX, backup JSON,
deterministic generation, local persistence, native iOS file workflows,
privacy, TestFlight, and App Store readiness. These are not deferred.

## Commands

No Swift/Xcode project has been generated yet. Until then, repository-level
checks are limited to git/document hygiene:

- Check status: `git status --short`
- Check whitespace: `git diff --check`
- Check staged whitespace: `git diff --cached --check`
- Check line endings: `git ls-files --eol`

After the SwiftUI/TCA project is scaffolded, update `docs/ledgers/VALIDATION_LEDGER.md`
with real commands. Do not invent commands that do not exist.

## Truthfulness Prime Directive

Never introduce stateless fake behavior, mocked persistence, placeholder logic
dressed up as working functionality, decorative UI that claims unsupported
functionality works, or success states that are not backed by a real completed
operation.

Every user-visible success state must correspond to a real completed operation,
durable local state change, verified generation result, verified local file, or
native iOS completion/cancellation result.

Every incomplete, unavailable, pending, errored, cancelled, or unsupported path
must be surfaced honestly. If something cannot be implemented correctly, fail
openly and visibly with a clear error or disabled path rather than silently
pretending it works.

If you encounter fake state, placeholder behavior, misleading UI, silent
failure, or stateless implementation while working in this codebase, fix it
completely or stop and report why it cannot be fixed in the current scope.

## OSS/Native-First Dependency Discipline

Before changing `Package.swift`, import/export code, persistence code, file
workflows, reusable UI components, or any generic infrastructure, read
`docs/OSS_DEPENDENCY_POLICY.md`.

The default posture is barely any custom generic code. Use Apple-native APIs and
the approved OSS dependency list first. Custom code is acceptable for
Commenter-specific product logic and small adapters around native/OSS APIs.

Do not hand-roll CSV, XLSX, XLS/OLE, DOCX/OOXML, SQLite, file-picker/share, or
design-system infrastructure unless `docs/OSS_DEPENDENCY_POLICY.md` or a later
decision-ledger entry explicitly allows the exception. Required MVP workflows
must still be completed; dependency discipline is not permission to defer or
disable them.

## Source Truth Discipline

When porting from CommenterV3, inspect the live file listed in
`docs/source-truth/commenterv3-source-map.md` before implementing behavior.

Do not port from memory or prior summaries alone. If the current CommenterV3
source disagrees with a planning doc, report the conflict and use the live
source unless the user explicitly changes the product contract.

## Ledger Update Discipline

Do not update every ledger after every task.

For routine material changes, append a short `WORKLOG.md` entry.

Update `CORE_RULES.md` only when a foundational project invariant is added,
changed, superseded, or removed by explicit user instruction.

Update `PROJECT_LEDGER.md` only when phase status, scope, deliverables, or
durable project posture changes.

Update `DATA_LEDGER.md` only when source packages, schemas, datasets,
migrations, generated artifacts, counts, or provenance assumptions change.

Update `DECISIONS_LEDGER.md` only when an architectural, product, data, testing,
or process decision is made, changed, or superseded.

Update `VALIDATION_LEDGER.md` only when validation gates, test commands, test
evidence, release criteria, or known validation status changes.

If no durable repo state changed, do not update ledgers.

Do not build an automatic next-step system and do not create `NEXT_STEP.md`.
Use `docs/backlog/INITIAL_BACKLOG.md`, ledger entries, and issue trackers for
planned work.

## Line Ending Discipline

This repo pins text line endings in `.gitattributes`. Avoid line-ending churn.
Before staging or committing, run:

```powershell
git diff --check
git ls-files --eol
```

When staging, inspect the staged diff and run:

```powershell
git diff --cached --check
```

## Definition of Done

A task is done only when:

- the requested implementation or documentation change is complete
- relevant real checks have been run
- UI/simulator/device verification has been completed for UI changes where
  possible
- ledgers are updated only when durable state changed
- the final response lists changed files, commands run, inferred facts,
  unresolved risks/unknowns, and whether production behavior changed
