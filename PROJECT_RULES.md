# CommenterIOS project rules

Install as `PROJECT_RULES.md` at the repository root. Read with `AGENTS.md`. These are product requirements, not a record of past tasks. No exceptions to the shared core rules are granted here.

## Product and privacy

- CommenterIOS is the native iPhone-first SwiftUI app, built with The Composable Architecture, that ports the offline teacher report-writing app CommenterV3. It is not a web wrapper and not a boilerplate demo with placeholder product behavior. Breaking this is a release blocker unless the owner changes the product direction.
- Project, roster, result, draft, report, backup, recovery, import, export and generation workflows stay on the device. Do not require or add accounts, cloud sync, backend persistence, remote AI, analytics, telemetry, paywalls, subscriptions or other network services. Teacher and student data is private and local only.
- The app is fully AI-enabled, unlike CommenterV3 (owner decision, 2026-11-15). AI is built into the teacher workflow, not limited to an optional writing aid. Use only Apple's on-device Foundation Models: name the on-device system model explicitly, and never use Private Cloud Compute, partner or third-party models, or any remote AI. Do not port CommenterV3's "No AI in the app" rule. Gate AI on the device's real availability; deterministic generation stays the fallback on devices without Apple Intelligence. System Writing Tools, which can send text to Apple's servers, must not edit comment text; offer equivalent help through the app's own on-device AI.
- The production MVP includes CSV, XLSX, legacy XLS, DOCX and backup JSON, deterministic generation, local persistence, native iOS document picker, export and share workflows, privacy, TestFlight and App Store readiness. None of these is deferred; the MVP is not complete until each works truthfully.

## Source truth and production data

- The live `C:\Commenterv3` checkout is the source of truth for unported or disputed behavior. Before porting a behavior, inspect the current CommenterV3 files listed in [the source map](docs/source-truth/commenterv3-source-map.md). Do not port from memory, prior summaries or planning documents alone. If live source disagrees with a planning document, report the conflict and follow the live source unless the owner changes the product contract.
- Production comment wording comes only from the real CommenterV3 dataset (`C:\Commenterv3\client\public\data\comment-engine.json`), bundled as `Sources/CommentEngine/Resources/comment-engine.json`. The only approved copy transform is in [DATASET_SOURCE_TRANSFORM.md](docs/validation/DATASET_SOURCE_TRANSFORM.md). Runtime code must never substitute fixtures, samples, prototypes, generated test data or placeholder datasets as production wording.

## Truthful output

- Every success shown to the teacher must match a real completed operation: a durable local save, a verified generation result, a verified local file, or a native iOS completion or cancellation result.
- Generated and exported report text must not contain unresolved placeholders.
- AI-generated or AI-revised report text is not export-ready until the app validates it and the teacher approves the current text. AI output arrives as a preview: it does not change the comment, mark it Done, save, export or share until the teacher accepts it. Bulk AI produces one preview per comment, can be cancelled, and leaves cancelled or queued comments untouched. App Shortcuts may only open the relevant screen; they never generate, approve, export or share.

## Dependencies

- Before changing `Package.swift`, import/export, persistence, file workflows, reusable UI components or other generic infrastructure, read [OSS_DEPENDENCY_POLICY.md](docs/OSS_DEPENDENCY_POLICY.md).
- Use Apple-native APIs and the approved open-source packages first. Custom code is for Commenter-specific product logic and small adapters around native or open-source APIs. Do not hand-roll CSV, XLSX, XLS/OLE, DOCX/OOXML, SQLite, file-picker/share, navigation or design-system infrastructure unless the dependency policy or a recorded owner decision allows that specific exception. Dependency discipline does not permit deferring or disabling a required MVP workflow.

## Platform, verification and line endings

- Target platform (owner decision, 2026-08-08): iOS 27 minimum, iPhone only, Swift 6 language mode with complete concurrency checking, built with Xcode 27. Use native Liquid Glass for system chrome (tabs, navigation bars, sheets, controls); keep the paper look only for report and editor content.
- Swift package tests, the iOS app build, simulators and devices need macOS with Xcode. On a Windows host, checks are limited to Git and document hygiene and the dataset-copy check; say so instead of claiming Apple-platform behavior works. Use only commands that exist (see [README](README.md#development)).
- Use XcodeBuildMCP for discovery, build, run and test whenever the host has the project plus Xcode and simulator support. Prefer it over handwritten `xcodebuild`, `xcrun` or `simctl` unless its logs are incomplete. UI changes need simulator or device verification where possible.
- When CI fails, first inspect the exact failing job logs with `gh-fix-ci`. Do not infer the failure from file names or recent edits. Identify the project, scheme, destination simulator and failing target, reproduce locally through XcodeBuildMCP, apply the smallest correct fix for the observed failure, and rerun the narrowest failing build or test first. For SwiftUI correctness, use the SwiftUI agent skills listed in [IOS_CI_SKILL_RECOMMENDATIONS.md](docs/IOS_CI_SKILL_RECOMMENDATIONS.md), which also has the install commands.
- `.gitattributes` pins text line endings. Avoid line-ending churn: before staging, run `git diff --check` and `git ls-files --eol`; after staging, inspect the staged diff and run `git diff --cached --check`.
