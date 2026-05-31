# Core Rules

This file records only foundational invariants for CommenterIOS. It is not a
roadmap, task list, preference list, issue tracker, validation report, or
speculative rule catalog.

A rule belongs here only if all or nearly all of the following are true:

1. It is foundational to the intended product.
2. It is repo-wide or architecture-defining, not merely a current implementation
   detail.
3. Violating it would materially change what the project is.
4. It is supported by clear repo evidence, source CommenterV3 behavior, or
   explicit user instruction.
5. It should constrain future agents even when the user gives a broad
   implementation request.

If uncertain, do not include the rule.

## C001 - Native iPhone-first SwiftUI/TCA app

Rule:
CommenterIOS is a fresh native iPhone-first SwiftUI app using The Composable
Architecture. It is not a production web wrapper and not a generic boilerplate
demo with placeholder product behavior.

Why it matters:
The purpose of this repo is to build a real native iOS port with testable state,
native iOS workflows, and reusable components.

Evidence:
`docs/CHAT_HANDOFF.md`; `docs/PRODUCTION_MVP_PLAN.md`;
`docs/decisions/0001-native-swiftui-tca.md`.

Validation:
Future validation must include Swift/Xcode build and TCA reducer tests after
the app is scaffolded.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes
the product direction.

## C002 - Offline local-first privacy posture

Rule:
Core project, roster, result, draft, report, backup, recovery, import, export,
and generation workflows must remain local to the device and must not require
accounts, cloud sync, backend persistence, remote AI, analytics, telemetry, or
network services.

Why it matters:
The app handles private teacher/student data and exists to preserve the
CommenterV3 offline/local product promise.

Evidence:
`docs/PRODUCTION_MVP_PLAN.md`; `docs/CHAT_HANDOFF.md`; source CommenterV3
`docs/ledgers/CORE_RULES.md`.

Validation:
Future validation must include no-network checks, privacy manifest review, and
airplane-mode workflow testing.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes
the privacy/product posture.

## C003 - Production data source

Rule:
Production report-comment data must come from the real CommenterV3 production
dataset, currently `C:\Commenterv3\client\public\data\comment-engine.json`.
Runtime code must not silently substitute fixtures, samples, archived
prototypes, generated test data, or placeholder datasets as production comment
data.

Why it matters:
Generated teacher reports depend on the production comment-engine dataset.
Silent fallback to sample data would make output untrustworthy.

Evidence:
`docs/source-truth/commenterv3-source-map.md`; `docs/PRODUCTION_MVP_PLAN.md`;
source CommenterV3 `HARDENING_NOTES.md`.

Validation:
Future validation must include production dataset loading/validation tests and
fixture isolation checks.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes
the production dataset contract.

## C004 - Truthful implementation only

Rule:
The app must not present saved state, generated reports, imported data,
exported files, shared files, backups, recovery operations, or unavailable
functionality as successful unless the underlying local operation really
completed and was verified. Generated and exported report text must not contain
unresolved placeholders.

Why it matters:
This is a teacher report-writing tool. Fake success states or unresolved
template text directly corrupt teacher-facing output and user trust.

Evidence:
Explicit user instruction; `AGENTS.md`; `docs/PRODUCTION_MVP_PLAN.md`; source
CommenterV3 `docs/ledgers/CORE_RULES.md`.

Validation:
Future validation must cover save read-after-write verification, generation
parity, placeholder blocking, all-or-nothing import, export file existence,
native share/export cancellation, and backup roundtrips.

Release impact:
Violation of this rule is a release blocker.

## C005 - Full MVP parity for required formats

Rule:
CSV, XLSX, legacy XLS, DOCX, and backup JSON support are production MVP
requirements. They must be implemented truthfully or the MVP is not complete.

Why it matters:
The user explicitly rejected deferral. The native app must preserve the
teacher workflow formats that matter to CommenterV3.

Evidence:
`docs/CHAT_HANDOFF.md`; `docs/PRODUCTION_MVP_PLAN.md`; source CommenterV3
README and export/import implementation.

Validation:
Future validation must include import/export fixtures and target-app open
checks for DOCX, XLSX, and XLS.

Release impact:
Violation of this rule is a release blocker unless the user explicitly changes
the MVP scope.

## C006 - Source truth before porting

Rule:
Before porting behavior from CommenterV3, inspect the current live source files
listed in `docs/source-truth/commenterv3-source-map.md`. Do not implement from
memory, stale summaries, or planning docs alone when live source is available.

Why it matters:
The source app may evolve. The native port must preserve current real behavior,
not a stale recollection.

Evidence:
`AGENTS.md`; `docs/source-truth/commenterv3-source-map.md`.

Validation:
Worklog and implementation PRs should name the source files inspected for each
ported behavior.

Release impact:
Failure to reconcile against live source is a process blocker for porting work.
