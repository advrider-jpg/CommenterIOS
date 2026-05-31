# Project Ledger

Append durable project posture, scope, deliverables, major components, and open
questions here. Do not use this as a task list.

## Current Posture

CommenterIOS is a fresh native iPhone-first SwiftUI/TCA port of CommenterV3.
The repo currently contains planning, guardrails, source-truth maps, and initial
backlog artifacts. The SwiftUI/TCA app has not yet been scaffolded.

## Product Purpose

Build a production-ready native iOS MVP for teachers to create report-writing
projects, manage rosters, enter achievement results, generate deterministic
draft comments, save locally, import/export files, and prepare final reports
without uploading private student data.

## Durable Scope

MVP scope includes:

- native SwiftUI/TCA app shell
- local-only persistence
- production dataset loading and validation
- deterministic comment generation
- CSV, XLSX, and XLS import
- DOCX, XLSX, and XLS export
- backup JSON import/export
- recovery snapshots
- iPhone-first teacher workflow
- support/diagnostics/privacy surfaces
- TestFlight and App Store readiness

## Non-Goals

- accounts
- cloud sync
- backend project persistence
- remote AI generation
- analytics
- telemetry
- paywalls
- subscriptions
- generic scaffold demo flows

## Major Components

- `CommenterDomain`
- `CommentEngine`
- `CommenterPersistence`
- `CommenterImportExport`
- `DesignSystem`
- TCA feature packages
- test support and golden fixtures

## Open Questions

- Exact Swift package or owned implementation for XLSX parsing/writing.
- Exact Swift package or owned implementation for legacy XLS parsing/writing.
- Exact DOCX OpenXML implementation strategy.
- Final app name, bundle identifier, icon, and App Store metadata.
- Whether iPad is explicitly supported or only compatibility-tested.
