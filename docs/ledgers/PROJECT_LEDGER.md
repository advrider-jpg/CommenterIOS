# Project Ledger

Append durable project posture, scope, deliverables, major components, and open
questions here. Do not use this as a task list.

## Current Posture

CommenterIOS is a native iPhone-first SwiftUI/TCA port of CommenterV3 with the
MVP teacher workflow source surface present in package targets and an iOS app
host. The checkout includes bundled production dataset loading, deterministic
generation, local verified project persistence, recovery snapshots, CSV/XLSX/XLS
import, DOCX/XLSX/XLS export, backup JSON import/export, support diagnostics,
and native iOS import/export/share presentation wiring.

The remaining release constraint is validation environment availability: Swift
package dependency resolution, Xcode build/test, simulator/device validation,
signing, TestFlight, and App Store archive checks must run on a macOS Apple
toolchain with network access to package dependencies before release claims are
made.

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

- Exact Xcode signing team, provisioning, and app identifier values.
- Final app name, bundle identifier, icon, and App Store metadata.
- Whether iPad is explicitly supported or only compatibility-tested.
- Final TestFlight tester set, release notes, and App Store privacy-form entries.
