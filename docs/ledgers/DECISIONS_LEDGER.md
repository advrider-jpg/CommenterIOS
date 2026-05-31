# Decisions Ledger

Append durable architectural, product, data, testing, and process decisions
here. Do not rewrite history; supersede entries with dated notes.

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
