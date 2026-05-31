# Validation Ledger

Append durable validation commands, gates, last known evidence, release
criteria, and validation gaps here.

## Current Validation Status

The repo currently contains planning and guardrail documents only. No Swift/Xcode
project has been scaffolded yet.

## Current Commands

Document hygiene:

```powershell
git status --short
git diff --check
git diff --cached --check
git ls-files --eol
```

## Last Known Evidence

2026-05-30:

- `git diff --check` was clean before initial planning commit.
- `git diff --cached --check` was clean before line-ending policy commit.
- `git ls-files --eol` showed LF-pinned tracked docs after `.gitattributes`.
- CommenterV3 ProjectStatus dashboard was updated for the planning repo
  creation task.

## Future Required Gates

After the SwiftUI/TCA scaffold exists, add real commands for:

- Swift package tests
- Xcode build
- Xcode unit tests
- TCA reducer tests
- import/export tests
- golden parity tests
- no-network/privacy scan
- simulator UI tests
- archive validation

Do not claim these gates exist until they are implemented.

## Release Criteria

Release requires all gates listed in `docs/PRODUCTION_MVP_PLAN.md`, including
device validation, TestFlight readiness, privacy manifest accuracy, and App
Store package readiness.
