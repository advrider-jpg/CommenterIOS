# Build, dependencies, tests, CI/release and documentation review

## Summary
The project setup works today only for the old target. Every version marker (swift-tools 5.10, Swift 5 language mode, iOS 17 / macOS 14, `LastUpgradeCheck 1540`, `objectVersion 56`, `macos-15` runner with Xcode 16.4) is two toolchain generations behind the owner's iOS 27 / Swift 6 / Xcode 27 decision. That decision is not recorded in any ledger. TCA 1.17.0 predates TCA's "Xcode 27 support" fix (1.26.0), so the dependency upgrade comes first.

Main has been red since 2026-08-08. PR #13 was merged 10 seconds after it was opened, before its checks finished, because `main` has no branch protection and no rulesets (checked with `gh api`).

Of the 25 failing tests (31 assertion failures; "31" in the CI summary counts assertions, not tests), 22 are stale tests: the product changed on purpose and the fixtures were not updated. One is a real product regression (a header-only CSV is now reported as "malformed"). Two are unclear, but they show that XLSX template download fails deterministically. The same new XLSX verifier also guards XLSX report exports, and no passing test exercises it.

Other serious problems:
- The release workflow cannot succeed as written: it calls `xcodebuild -validate-app`, which does not exist, and its evidence file says "passed" based only on a file existing. It has never been dispatched.
- The in-app privacy policy link can never appear, because of a custom `INFOPLIST_KEY_` setting that Xcode ignores.
- CI uses Xcode 16.4, so the Foundation Models code is compiled out of every CI build.
- The bundled comment dataset no longer matches the live CommenterV3 dataset. V3 rebuilt its engine on ACARA v9 in Oct–Nov 2026. The repo's own validator now fails.

Solid and worth keeping:
- The package split of pure logic: Domain, CommentEngine, ReportSafety, Persistence.
- The breadth of behavioural tests around truthful states.
- The dataset hash validator.
- The `Package.resolved` lockfile check in CI.
- A clean privacy manifest.
- The release workflow's fail-open secret check.

## Failing tests

Source: `C:\Users\jackg\AppData\Local\Temp\ci14.log` (run of 2026-10-06, Xcode 16.4, Swift 6.1.2), ending in "Executed 356 tests, with 31 failures" (log line 2957). There are 25 distinct failing tests. Some report two or more assertion failures, which brings the count to 31.

Classification: (a) the test is stale and the product is right; (b) product bug; (c) unclear.

| # | Group / tests | Class | Evidence | Fix direction |
|---|---|---|---|---|
| G1 | AppFeatureTests: `testAIReportApprovalBlocksMissingRequiredMentionConstraint` (AppFeatureTests.swift:1549), `testAIReportApprovalFailureStaysVisibleAndDoesNotApprove` (:1465), `testLocalSafetyCheckPersistsRealValidationFindings` (:2715). 3 tests, 3 failures | a | d98e862 removed the "skip soft checks once a blocker is found" guard (`ReportSafetyValidator.swift:50-56` in the d98e862 diff). The length check at `ReportSafetyValidator.swift:297-305` now adds the warning "The report is very short." beside the blocker. The log shows only that extra finding and the extra note text (log lines 1576-1585, 2030-2045). Running every check is the more truthful behaviour. | Update the expected `notes`/`findings`/`reviewNotes`, or use fixture text of 8 or more words so the length warning does not fire. Better: assert on the blocker finding only, not the whole state (see F11). |
| G2 | CommentEngineTests.ReportReadinessTests: `testBlocksMissingReportAndUnresolvedPlaceholders` (:26-27), `testUnresolvedPlaceholderOrderMatchesDraftText` (:43-44). 2 tests, 4 failures | a (plus a minor V3 divergence, F22) | d98e862 moved the stale-fingerprint check ahead of the placeholder check (`ReportReadiness.swift:186-202`). The test reports (`ReportReadinessTests.swift:21-23, 32-38`) are built without `resultFingerprint`, so they are stale and return `.staleReport` with no placeholders. V3 also puts stale first (`C:\Commenterv3\client\src\lib\report-readiness.ts:300-329`; V3 test `report-readiness.test.ts:118` asserts that stale wins). | Give the fixture report a matching `buildGenerationFingerprint(...)`. |
| G3 | CommenterImportExportTests.CSVParserTests: `testRejectsMissingDataRowsAndRowsBeyondConfiguredImportLimit` (:103). 1 failure | b | d98e862 deleted the fallback parser (`parseFallbackRowsOrThrow`). The input `"First Name,Last Name\n\n"` now goes straight to `CSVReader.decode` (`CSVParser.swift:91-101`). CodableCSV rejects the blank line because its field count (1) differs from the header's (2). That error is mapped to the generic `.malformed`, and `parseTabularRows`' `.missingDataRows` check (:134-136) is never reached. `unquotedRowWidthMismatch` (:266-286) skips blank rows, so it does not catch this first. A teacher whose spreadsheet export ends in a blank line now gets "The CSV file is malformed" instead of "has no data rows". | Drop blank lines before decoding (the same filter `parseTabularRows` already applies at :108-110), or map CodableCSV's field-count error to row-level errors. Confidence Medium: CodableCSV's behaviour was inferred, not run. |
| G4 | CSVTemplatesTests: `testPreparedImportTemplatesCoverBothKindsAndAllLiveFormats`, `testPreparedImportTemplatesNeverOverwriteAnExistingDownload`. 2 tests, 2 failures | c (the failure is a product failure; the root cause is unconfirmed) | Both throw `verificationFailed(... report_writer_class_list_template.xlsx)` from the catch-all at `CSVTemplates.swift:313-320`, which throws away the real error. In the first test the CSV case passed and the first XLSX case failed. The verifier `verifyTabularWorkbookData` (`ReviewWorkbookFile.swift:150-183`) was rewritten in d98e862: it now requires exact `Set(entries.keys)` equality and exact equality of a regex extraction of every `<t>` value (`inlineStringValues`, :206-221). The old version used `contains` checks. The production call path has no test-only input, so XLSX template download fails for teachers too. | On a Mac, surface the swallowed error, then fix the verifier or the writer. Do not loosen the test. Treat XLSX/XLS report export as unproven (F6). |
| G5 | ReportDocumentFileTests (6), ReportExportPreparationTests (5), ReviewWorkbookFileTests (6). 17 tests, 21 failures | a | d98e862 added the `needsTeacherCheck` gate (`ReportReadiness.swift`, "This draft passes the app checks. Read it and mark it Done before export."). It blocks export while `reviewedAt` is nil, and `ReportExportPreparation.swift:296-304` throws `notReady`. The `readyReport` fixture helpers (`ReportDocumentFileTests.swift:267-296`, `ReportExportPreparationTests.swift:247+`, `ReviewWorkbookFileTests.swift:315+`) never set `reviewedAt`. This matches V3, which also skips `needs-teacher-check` reports (`generator-validation-export.test.ts:910`). Two tests also assert old messages:<br>• `testPreparationBlocksAIReportsUntilApproved` expects "AI draft needs teacher review". The product now says "...must be validated and teacher-reviewed in its current form" and requires a `lastValidation` with a matching text fingerprint. This is stricter and correct under C004.<br>• `testPreparationBlocksTextThatCannotBeRepresentedInOOXML` expects "control character" in `localizedDescription`. The readiness issue now comes first in the list, and `errorDescription` shows only the first issue (`ReportExportPreparation.swift:13-21`). | Set `reviewedAt` in the three `readyReport` helpers. Add `lastValidation` and fingerprints in the AI approval test. Assert on `notReady(issues).contains(...)` rather than on the first-issue description. |

Counts: (a) 22 tests (G1 3 + G2 2 + G5 17); (b) 1 test (G3); (c) 2 tests (G4).

Process cause: the WORKLOG entry for d98e862 says "No validation commands were run by request" (`docs/ledgers/WORKLOG.md:885-887`). The PR was merged at 17:06:18, ten seconds after it was created, while "Swift package tests" finished FAILURE at 17:11:25 (`gh pr view 13`).

## Findings

### F1: Dependencies are far behind; TCA 1.17 predates Xcode 27 support
- Severity: Critical
- Kind: outdated-version
- Where: `Package.swift:27-32`, `Package.resolved`, `.github/workflows/*.yml` (`actions/checkout@v4`, `actions/upload-artifact@v4`)
- What it does now: `exact:` pins on TCA 1.17.0, GRDB 7.10.0, ZIPFoundation 0.9.11, CoreXLSX 0.14.1, OLEKit 0.2.0 and CodableCSV 0.6.7. Transitive pins include swift-syntax 600.0.1 and swift-dependencies 1.6.1.
- Why it is like this: ZIPFoundation was raised from 0.9.0 to exactly 0.9.11 only to satisfy CoreXLSX resolution (commit 26d42b1). CoreXLSX actually accepts `.upToNextMinor(from: "0.9.11")` (CoreXLSX 0.14.1/0.14.2 Package.swift, checked with `gh api`), so 0.9.20 resolves fine. The other pins have no recorded reason. The policy table says `from:` (`docs/OSS_DEPENDENCY_POLICY.md:44-50`) while the manifest says `exact:`. No Dependabot or Renovate config exists.
- Why it matters, and what each upgrade involves:
  - **TCA 1.17.0 → 1.26.2.** 1.26.0 "Fixed: Xcode 27 Beta 1 Support" and Xcode 26 archive failures (https://github.com/pointfreeco/swift-composable-architecture/releases/tag/1.26.0), so 1.17 cannot be assumed to build on the target toolchain. Changes along the way:
    - 1.18: `TestStore` requires `State: Equatable`.
    - 1.24 hard-deprecated `ViewStore`/`WithViewStore` and Swift <6.1 (https://github.com/pointfreeco/swift-composable-architecture/releases/tag/1.24.0).
    - 1.25 trait-deprecated `Effect<Action>` in favour of `EffectOf`, and deprecated `Reducer.reduce`, Combine effects and `$store.scope(state:)` (migration guide: https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Documentation.docc/Articles/MigrationGuides/MigratingTo1.25.md).
    - Repo impact: `WithViewStore(store, observe: { $0 })` at `Sources/AppFeature/AppView.swift:29`, five `ViewStore<...>` parameters (`AppView.swift:358-446`), `viewStore.binding(...)` (:30), and 8 `-> Effect<Action>` reducer helpers (e.g. `Features/AppFeatureReducer.swift:4`). These must move to `@Bindable var store` / `$store.x.sending(\.y)` and `EffectOf<Self>`. `@ObservableState` is already in use (`AppFeature.swift:11`), so this is mechanical. No `TaskResult`, `@BindingState` or `AnyCasePath` usage was found.
  - **GRDB 7.10 → 7.12.** Bug fixes only: quadratic statement compilation, WAL snapshot ordering, `SharedValueObservation` deadlock (https://github.com/groue/GRDB.swift/releases/tag/v7.12.0). No API changes affect this repo.
  - **ZIPFoundation 0.9.11 → 0.9.20.**
    - Adds the bundled privacy manifest (0.9.17), throwing `Archive` initialisers (0.9.17) and a path-escape vulnerability fix (0.9.18). 0.9.20 fixes resource/memory leaks (https://github.com/weichsel/ZIPFoundation/releases).
    - `OOXMLZipWriter.swift:39,98` uses the failable `Archive(data:accessMode:)`, which becomes deprecated. Switch to `try Archive(data:accessMode:)`.
    - ZIPFoundation is not on Apple's required-manifest SDK list (https://developer.apple.com/support/third-party-SDK-requirements/), so this is hygiene, not a rejection risk.
  - **CoreXLSX, OLEKit, CodableCSV.** Effectively unmaintained (see CONTEXT facts). OLEKit 0.2.0 → 0.3.1 is a minor bump. Upgrading these does not remove the maintenance risk; that is a replacement question for the import/export reviewer.
  - **Actions v4 → v7.** checkout v7.0.1 and upload-artifact v7.0.2. They run on newer Node, and upload-artifact v4+ artifacts are immutable per name, which the current per-job unique names already satisfy. Note that `scripts/validate_ci_artifact_privacy.py:35` only matches `upload-artifact@v4` and would silently pass on v7 (F15).
- Recommended replacement: First defect: bump TCA to 1.26.2, GRDB to 7.12.0 and ZIPFoundation to 0.9.20, then let swift-syntax float to whatever TCA 1.26 resolves. Switch to `.upToNextMinor` ranges with `Package.resolved` as the lock, which is already enforced by `git diff --exit-code Package.resolved` in CI. Add `.github/dependabot.yml` with `swift` and `github-actions` ecosystems. Migrate the `ViewStore`/`Effect` call sites in the same change.
- Effort: M
- Confidence: High

### F2: Platform, language mode and Xcode project settings contradict the iOS 27 decision
- Severity: Critical
- Kind: outdated-version
- Where:
  - `Package.swift:1` (`swift-tools-version: 5.10`), `:9-10` (`.iOS(.v17)`, `.macOS(.v14)`)
  - `CommenterIOS.xcodeproj/project.pbxproj:6` (`objectVersion = 56`), `:136-137` (`LastSwiftUpdateCheck/LastUpgradeCheck = 1540`), `:266,320,347,380,403,427` (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`), `:358,391,414,438` (`SWIFT_VERSION = 5.10`)
  - `CommenterIOS.xcscheme:3` (`LastUpgradeVersion = "1540"`)
- What it does now: The package builds in Swift 5 mode with minimal concurrency checking. The app target targets iOS 17. The package also declares macOS 14, only so `swift test` can run on a macOS host (F9). The project format is Xcode 14-era and hand-authored (the object IDs are `1A2B3C4D5E6F7000000000xx`).
- Why it is like this: The owner decided on 2026-08-08 to cut over hard to iOS 27, Swift 6 and Xcode 27. Only the WORKLOG records it (`WORKLOG.md:889-897`). There is no DECISIONS_LEDGER entry and no change to PROJECT_LEDGER or CORE_RULES (F18).
- Why it matters:
  - Swift 6 mode has never been compiled. There is 1 `@unchecked Sendable` and there are 10 `static var` declarations to audit, and nothing sets `swiftSettings`.
  - The iOS 26 availability gates (`CommenterAI/AIClient.swift:33-74`, `FoundationModelReportGenerator.swift:5-8`) become dead code at iOS 27.
  - The macOS platform lets macOS-only test runs hide iOS-only problems.
- Recommended replacement:
  - `swift-tools-version: 6.2` or later, with `.iOS(.v27)` only. Drop `.macOS` once tests run on the simulator (F9).
  - Let the tools version select Swift 6 language mode; consider `.defaultIsolation(MainActor.self)` for `AppFeature`/`DesignSystem` only.
  - Set Xcode `SWIFT_VERSION = 6.0`, `IPHONEOS_DEPLOYMENT_TARGET = 27.0` and `SWIFT_STRICT_CONCURRENCY = complete`.
  - Open in Xcode 27, accept "Update to recommended settings" (raises `LastUpgradeCheck`), and convert to `objectVersion 77` with folder-synchronised groups.
  - Delete the `#available(iOS 26…)`/`canImport(FoundationModels)` branches.
- Effort: M (L if Swift 6 errors cascade)
- Confidence: High

### F3: Main has been red since August; nothing stops merging on red
- Severity: Critical
- Kind: best-practice
- Where: GitHub settings. `gh api repos/advrider-jpg/CommenterIOS/branches/main/protection` returns 404 "Branch not protected"; `.../rulesets` returns `[]`; `.github/workflows/ios-ci.yml`
- What it does now: Any PR can be merged instantly. PR #13 was created at 17:06:08 and merged at 17:06:18, and its "Swift package tests" check failed at 17:11:25. Every main run since has failed or been cancelled (`gh run list`). The screenshot job is skipped, so there is no UI evidence after June.
- Why it is like this: No recorded reason. The worklog says tests were not run "by request" (`WORKLOG.md:887`).
- Why it matters: The 25 failing tests hide a real CSV regression and a broken XLSX template/export path (G3, G4). Any later regression is invisible in a permanently red suite.
- Recommended replacement: Add a ruleset on `main` with required status checks "Swift package tests" and "Build iOS app target" (plus the screenshot job once it is stable), "require branches up to date", and no bypass for admins. The repo is public, so rulesets are free. Fix the 25 tests first (table above). Note: the local branch `codex/ios-27-migration` is one commit behind `origin/main` (f73931e added the `concurrency:` block).
- Effort: S
- Confidence: High

### F4: The bundled comment dataset no longer matches the live CommenterV3 source
- Severity: Critical
- Kind: doc-stale (data / source-truth drift)
- Where: `Sources/CommentEngine/Resources/comment-engine.json` (last changed 2026-06-04, commit 566435d), `scripts/validate_dataset_source_transform.py:17-24`, `docs/validation/DATASET_SOURCE_TRANSFORM.md`, `docs/ledgers/DATA_LEDGER.md`
- What it does now: Running the repo's own validator (read-only) prints "ERROR: source SHA-256 changed: 70150DEB…" and "bundled dataset does not exactly match LF-normalized source dataset". The V3 file now has only a `ComponentBank` key, with 12,052 entries. The iOS copy has `ComponentBank` (56,564), `RecipeBank` (5), `AssembledVariants` (4,340) and `UniquenessGuard` (2). V3 rebuilt generation on the Australian Curriculum v9 (V3 commits 56cf329 on 2026-10-12, 3b1d7b2 on 2026-11-11 and 5c9da40 on 2026-11-14).
- Why it is like this: The iOS port was frozen against the June engine. Under C003/C006 the live V3 checkout is the source of truth.
- Why it matters: The iOS app generates comments from a superseded engine and data model, so it now diverges from the product it is supposed to port. The DATA_LEDGER and validation docs still claim parity, and no CI step runs the validator.
- Recommended replacement: Owner decision (see Open questions). If parity is required, re-port the V3 engine and dataset loader, update the hashes, and run the dataset validator in CI against a committed source hash rather than a `C:\` path.
- Effort: L
- Confidence: High

### F5: The release archive workflow cannot pass, and its evidence is not truthful
- Severity: High
- Kind: correctness-bug
- Where: `.github/workflows/ios-release.yml:140` (`xcodebuild -archivePath "$ARCHIVE_PATH" -validate-app`), `:125-135` (`CODE_SIGN_STYLE=Manual` with no `PROVISIONING_PROFILE_SPECIFIER`/`CODE_SIGN_IDENTITY`), `:161-162` (`uploadBitcode`), `:182` (`xcrun altool --upload-app`), `:213` (`"archive_validation": "passed" if pathlib.Path(...ARCHIVE_PATH).exists()`)
- What it does now:
  - `xcodebuild` has no `-validate-app` action, so the step fails.
  - Manual signing without a profile specifier normally fails when archiving.
  - The evidence JSON reports "passed" when the archive directory exists, even if validation failed, because it is written under `if: always()`.
  - `uploadBitcode` has been obsolete since Xcode 14.
  - `gh run list --workflow ios-release.yml` shows no `workflow_dispatch` run ever. The 06-13 "success" runs are the push-only registration echo job.
- Why it is like this: It was written on Windows without a Mac. VALIDATION_LEDGER says archive and TestFlight "remain unrun".
- Why it matters: The "TestFlight lane" exists only on paper, and its evidence file would mislead (C004 spirit).
- Recommended replacement: Either:
  - **Xcode Cloud.** Archive, cloud-managed signing and TestFlight distribution, with 25 free compute hours a month (https://developer.apple.com/xcode-cloud/). Delete `ios-release.yml` and the keychain/profile secrets.
  - **Plain xcodebuild.** `xcodebuild archive` with automatic signing plus `-allowProvisioningUpdates -authenticationKeyPath/-ID/-IssuerID` (App Store Connect API key), then `-exportArchive` with `method=app-store-connect` and `destination=upload`, which validates and uploads in one step. Drop altool, bitcode and the hand-made evidence JSON; the xcresult and the App Store Connect build are the evidence.
- Effort: S–M
- Confidence: High (that `-validate-app` is invalid); Medium (that manual signing fails)

### F6: XLSX workbook verification fails, which blocks template download and leaves XLSX report export unproven
- Severity: High
- Kind: correctness-bug
- Where: `Sources/CommenterImportExport/ReviewWorkbookFile.swift:150-183, 206-221`; `CSVTemplates.swift:293-321`
- What it does now: See G4. Since d98e862, every XLSX written by `buildTabularXLSX` must pass a stricter verifier. CI shows it failing for the class-list template. The review-workbook XLSX/XLS export tests stop earlier at the "mark it Done" gate (G5), so the same verifier has never run green on an export since August. The catch-all at `CSVTemplates.swift:313-320` turns the real error into `verificationFailed`, which is why the cause is invisible.
- Why it is like this: The verifier was rewritten in the same untested August commit.
- Why it matters: A teacher tapping "XLSX template", and possibly "Export XLSX/XLS review workbook", gets a failure. C005 requires all these formats.
- Recommended replacement: Fix G5's fixtures first so the export tests reach the verifier, reproduce on a Mac, and preserve underlying errors (`generationFailed(error.localizedDescription)`-style) instead of discarding them. Longer term, the writer itself is hand-written OOXML (the import/export reviewer's scope).
- Effort: S–M
- Confidence: Medium on the root cause; High that the path currently fails for templates

### F7: The in-app privacy policy link can never work
- Severity: High
- Kind: correctness-bug
- Where: `project.pbxproj:342,375` (`INFOPLIST_KEY_REPORT_WRITER_PRIVACY_POLICY_URL = "$(REPORT_WRITER_PRIVACY_POLICY_URL)"`); `Sources/AppFeature/AppPrivacyPolicy.swift:5`; `docs/release/APP_STORE_RELEASE_CHECKLIST.md:9`
- What it does now: With `GENERATE_INFOPLIST_FILE = YES`, Xcode emits only the `INFOPLIST_KEY_*` keys it recognises. A custom key is ignored, so it never reaches Info.plist (Apple DTS guidance summarised in https://developer.apple.com/forums/thread/709902 and https://developer.apple.com/tutorials/data/documentation/bundleresources/managing-your-app-s-information-property-list.md). The underlying `REPORT_WRITER_PRIVACY_POLICY_URL` build setting is also defined nowhere. `AppPrivacyPolicy.url()` therefore always returns nil.
- Why it is like this: No recorded reason. The June audit noticed only that the value was unresolved (`ridiculously-close-repo-audit.md:196`).
- Why it matters: App Review Guideline 5.1.1(i) requires an accessible privacy policy link inside the app as well as in App Store Connect.
- Recommended replacement: Put the HTTPS URL as a Swift constant in `AppPrivacyPolicy` (it is public, not a secret), or add a real Info.plist entry under Custom Target Properties. Remove the build-setting indirection and the checklist step.
- Effort: S
- Confidence: High

### F8: CI never compiles the on-device AI code or builds with an iOS 26+ SDK
- Severity: High
- Kind: test-gap
- Where: `.github/workflows/ios-ci.yml:12,24,64,117` (`runs-on: macos-15`); CI log lines 115-117 ("Apple Swift version 6.1.2", "Xcode 16.4"); `Sources/CommenterAI/FoundationModelReportGenerator.swift:5` (`#if canImport(FoundationModels)`)
- What it does now: Xcode 16.4 has no FoundationModels SDK, so all 196 lines of the Foundation Models generator and every gated `AIClient` branch compile out. Tests exercise only the `configuredForTests` stub (`Sources/CommenterAITestSupport/ConfiguredAIClient.swift`).
- Why it is like this: The runner image was never updated; the GA `xcode-27` image exists (CONTEXT).
- Why it matters: The AI feature the README advertises has never been compiled by anyone. `validate_release_proof_matrix.py` correctly fails on missing "foundation-models-compile-evidence.json".
- Recommended replacement: `runs-on: xcode-27` (or `macos-26` plus `xcode-select` to Xcode 27.1) for all macOS jobs. Then drop the `canImport` gates (F2).
- Effort: S
- Confidence: High

### F9: Unit tests run only on macOS, and the Xcode scheme runs no unit tests
- Severity: Medium
- Kind: test-gap
- Where: `.github/workflows/ios-ci.yml:42-46` (`swift test`); `Package.swift:10` (`.macOS(.v14)`); `CommenterIOS.xcscheme` (TestAction holds only `CommenterIOSScreenshotTests`); `docs/validation/XCODE_SCHEME_SCOPE.md`; `scripts/validate_xcode_scheme_scope.py:29`
- What it does now: All 356 package tests run as a macOS process. Pressing Cmd-U in Xcode runs only the screenshot UI test. A validator enforces that split.
- Why it is like this: It was the only option on macOS-15 runners without a simulator-pinned scheme. It is recorded in `XCODE_SCHEME_SCOPE.md`.
- Why it matters: The app is iPhone-only, yet the code that matters (file protection, `UIKit`, the AI availability path, App Intents) is never tested on iOS. The macOS platform declaration exists only to make this possible.
- Recommended replacement: Add an `.xctestplan` with all package test targets plus the UI test (UI test disabled by default). Run `xcodebuild test -scheme CommenterIOS -testPlan Unit -destination 'platform=iOS Simulator,name=iPhone 17'` on the `xcode-27` runner, then remove `.macOS`, `swift test`, `validate_xcode_scheme_scope.py` and `XCODE_SCHEME_SCOPE.md`.
- Effort: S
- Confidence: High

### F10: Two app entry points: the package's executable target duplicates the Xcode app target
- Severity: Medium
- Kind: architecture
- Where: `Package.swift:24,95-99` (`.executable(name: "CommenterIOSApp")`, `.executableTarget(... resources: [.process("Resources")])`); `project.pbxproj:9-11,26-28` (the app target compiles `Sources/CommenterIOSApp/CommenterIOSApp.swift` and bundles the same `PrivacyInfo.xcprivacy` and `Assets.xcassets` directly)
- What it does now: The same `@main` file and resources belong to both a SwiftPM executable and the Xcode app. `swift build` produces a macOS executable that nobody ships.
- Why it is like this: The 2026-05-31 decision added the xcodeproj as host (`DECISIONS_LEDGER.md:138-152`) but did not remove the executable target.
- Why it matters: It causes confusion about which target is real, makes `swift build` compile the app for macOS, and duplicates resources.
- Recommended replacement: Current best practice is a local package of library modules plus a thin Xcode app target, which is what the xcodeproj already is. Delete the `.executable` product and `.executableTarget`. Move `Sources/CommenterIOSApp` to an `App/` folder outside `Sources/`, referenced only by the xcodeproj. Remove the `CommenterTestSupport`/`CommenterAITestSupport` library products, since test-support targets need no product (F13). Keep the dual Package.swift + .xcodeproj arrangement itself: it is standard and the shape Tuist and Apple's own templates use.
- Effort: S
- Confidence: High

### F11: The single root reducer produces a 3,500-line test file that breaks on unrelated changes
- Severity: Medium
- Kind: architecture
- Where: `Sources/AppFeature/AppFeature.swift:9` (the only `@Reducer`); `Features/*.swift` (each is an `extension AppFeature`, despite "Feature" file names); `Tests/AppFeatureTests/AppFeatureTests.swift` (3,500 lines, 92 tests, 82 `TestStore`s, exhaustive full-state assertions)
- What it does now: Every feature test asserts the entire `AppFeature.State`, including validation finding IDs and notes. Adding one soft validation warning broke three unrelated AI-approval tests (G1).
- Why it is like this: It contradicts the planned feature tree (`docs/PRODUCTION_MVP_PLAN.md:64-85`) and the OSS policy ban on "giant root features bypassing a TCA feature tree" (CONTEXT C007). No exception is recorded in DECISIONS_LEDGER.
- Why it matters: The tests are brittle and slow to read, and each change to a validator or engine ripples into AppFeatureTests.
- Recommended replacement: Split into child `@Reducer`s (Projects, Roster, Results, Generation, ReviewExport, Backup, AI, Support) composed with `Scope`, and move each feature's tests into its own file. Where a test is about one outcome, use `store.exhaustivity = .off(showSkippedAssertions: false)` (TCA non-exhaustive testing) or assert only the relevant sub-state. Coordinate with the architecture reviewer.
- Effort: L
- Confidence: High

### F12: All tests use XCTest; none use Swift Testing
- Severity: Low
- Kind: best-practice
- Where: `Tests/**` (`grep "import Testing"` finds nothing); `.agents/skills/test-modernizer/SKILL.md` exists but has not been applied
- What it does now: There are 25 XCTest files. Many tests loop over cases inside one method (e.g. `CSVTemplatesTests.swift:99-125`, six format/kind cases in one test), so the first failure hides the rest. That is exactly what happened in G4: the XLS cases never ran.
- Why it is like this: No recorded reason. XCTest is the older default.
- Why it matters: Swift Testing is Apple's current framework. It offers parameterised `@Test(arguments:)`, `#expect`/`#require` with value diffs, tags, and parallelism by default. TCA's `TestStore` works under Swift Testing (TCA 1.17+ supports it via swift-issue-reporting).
- Recommended replacement: Migrate the unit tests incrementally to Swift Testing, starting with the parameterised format tests (templates, workbooks, CSV). Keep XCTest/XCUIAutomation for the UI test, which Swift Testing does not cover.
- Effort: M
- Confidence: High

### F13: Test fixtures are copied into 11 files; the shared test-support target is dead
- Severity: Low
- Kind: test-gap
- Where:
  - Private `fixtureProject()` in `ReportReadinessTests.swift:323`, `ProjectRulesTests.swift:130`, `ProjectValidationTests.swift:169`, `BackupEnvelopeTests.swift:332`, `BackupFileWorkflowTests.swift:248`, `ProjectImportCommitTests.swift:247`, `ReportDocumentFileTests.swift:234`, `ReportExportPreparationTests.swift:230`, `ReviewWorkbookFileTests.swift:282`, `FileProjectStoreTests.swift:478`
  - Private `readyReport()` in 4 files
  - `Sources/CommenterTestSupport/TestFixtures.swift` (8 lines; imported by no file, though `CommentEngineTests` depends on it, `Package.swift:106`)
- What it does now: When readiness gained the "mark Done" rule, three separate `readyReport` helpers each had to change, and none did (G5).
- Why it is like this: The plan intended `CommenterTestSupport` for "fixtures, golden-output helpers, dependency mocks" (`PRODUCTION_MVP_PLAN.md:134-137`), but nobody used it.
- Why it matters: One product rule change means N fixture edits, and the fixtures drift.
- Recommended replacement: Move one `Project.fixture(...)` and one `GeneratedReport.exportReady(project:result:text:)` (fingerprint, `reviewedAt` and validation set correctly) into `CommenterTestSupport` and delete the copies. Drop both test-support library products.
- Effort: S
- Confidence: High

### F14: The screenshot UI test is one 800-line coordinate-tapping script
- Severity: Medium
- Kind: best-practice
- Where: `UITests/CommenterIOSScreenshotTests/CommenterIOSScreenshotTests.swift:24` (a single `testCoreReportFlowScreenshots`), `:499-560, 627-660` (`coordinate(withNormalizedOffset:)` taps and drags); `.github/workflows/ios-screenshots.yml` (a verbatim copy of the CI screenshot job); `ios-ci.yml:115-131` (`if: always()` plus a deliberate `exit 1` when prerequisites failed); `scripts/extract_core_screenshots.py` (120 lines)
- What it does now: One test walks the whole teacher flow by normalised-coordinate taps and swipes, then attaches screenshots that Python pulls out of the xcresult. When unit tests fail, the screenshot job reports a second, artificial failure.
- Why it is like this: Commit history shows repeated fixes for screenshot flakiness ("Fix screenshot UI test report editor wait", "Tighten screenshot test report navigation", "Stabilize generated report screenshots").
- Why it matters: Coordinate taps break with Liquid Glass chrome changes in iOS 27 and with Dynamic Type. A single test gives no granularity. The duplicate workflow doubles maintenance.
- Recommended replacement: Drive state through a launch argument that seeds a fixture project, which already half-exists via `-UITestMode`. Add one short test per screen using accessibility identifiers only, with screenshots attached via `XCTAttachment` and `lifetime = .keepAlways`. Delete `ios-screenshots.yml` (use `workflow_dispatch` on the CI workflow) and the `exit 1` step (use `needs:` without `always()`). `xcrun xcresulttool export attachments` already names files, so the extractor can shrink. Fastlane `snapshot` is an option only if App Store screenshots are to be automated (F17).
- Effort: M
- Confidence: Medium

### F15: Most of the 811 lines of Python validators are ceremony; keep two
- Severity: Medium
- Kind: best-practice
- Where: `scripts/*.py`, totalling 811 lines (extract_core_screenshots 120, validate_app_store_release_package 326, validate_ci_artifact_privacy 71, validate_dataset_source_transform 93, validate_localization_plan 42, validate_release_proof_matrix 105, validate_xcode_scheme_scope 54); also `docs/release/app-store/05_assets/_generation_scripts/*.py` (171 lines)
- What it does now:
  - Only `extract_core_screenshots.py` runs in CI. The rest are run by hand by agents and recorded in VALIDATION_LEDGER.
  - Several check prose rather than behaviour. `validate_localization_plan.py:21-27` requires the plan document to contain phrases such as "English-only" and "large Dynamic Type". `validate_xcode_scheme_scope.py` checks that the YAML contains strings.
  - `validate_ci_artifact_privacy.py:35` regex-matches only `upload-artifact@v4`, so it would pass vacuously after the v7 upgrade.
  - `validate_release_proof_matrix.py` checks for hand-written JSON evidence files that do not exist.
- Why it is like this: Each was added after an AI-generated audit to "prove" a gate. The docs under `docs/validation/` exist mainly so the validators have something to check.
- Why it matters: This is maintenance without protection. Prose checks pass while the product is broken: main is red, yet these validators "passed" per the ledger.
- Recommended replacement:
  - **Keep `validate_dataset_source_transform.py`.** It caught F4. Run it in CI against a committed expected hash.
  - **Keep `extract_core_screenshots.py`** until F14 is done.
  - **Delete the other five validators and their `docs/validation/*.md` companions.** Real gates replace them: required status checks (F3); Xcode archive validation and App Store Connect processing (F5); `plutil -lint` folded into the build job; a String Catalog with Xcode's missing-localisation warnings (F21).
- Effort: S
- Confidence: High

### F16: CI wastes macOS minutes and lacks basic hardening
- Severity: Low
- Kind: best-practice
- Where: `ios-ci.yml:10-20` (a whole macOS job just for `plutil -lint`); no `actions/cache` for `.build`/SourcePackages/DerivedData; no `permissions:` block; actions pinned by mutable tag; toolchain-printing boilerplate repeated in 4 jobs
- What it does now: Each job resolves and compiles TCA and swift-syntax from scratch on a 10x-billed macOS runner.
- Why it is like this: No recorded reason. PR #14 added `concurrency` to cut minutes.
- Why it matters: Cost and wall time grow with every push.
- Recommended replacement: Merge the privacy lint into the build job. Cache `~/Library/Caches/org.swift.swiftpm` and `build/SourcePackages` keyed on the `Package.resolved` hash. Add `permissions: contents: read`. Pin actions by commit SHA with Dependabot updates (F1).
- Effort: S
- Confidence: High

### F17: Fastlane is present in name only; metadata is duplicated and still TODO
- Severity: Low
- Kind: best-practice
- Where: `fastlane/README.md` ("This repo does not need a Fastfile just to store metadata"); `fastlane/metadata/en-AU/*.txt`, which `diff -r` shows is identical to `docs/release/app-store/fastlane/metadata/en-AU/*.txt`; `privacy_url.txt`, `support_url.txt` and `marketing_url.txt` all contain "TODO"
- What it does now: There is no Fastfile, no `deliver`/`snapshot` and no match. These are two copies of draft metadata.
- Why it is like this: An App Store package was generated in June (PR #9).
- Why it matters: Duplicate sources of truth; the URLs are unfinished.
- Recommended replacement: For a solo, offline app in 2026, Xcode Cloud (signing and TestFlight) plus App Store Connect for metadata is the lowest-maintenance path. Plain `xcodebuild` with an App Store Connect API key is the fallback (F5). Fastlane earns its keep only if metadata and screenshots are to be pushed from git. If not, delete both metadata trees and keep the copy text in one markdown file.
- Effort: S
- Confidence: Medium

### F18: Core docs are stale or contradict the code
- Severity: Medium
- Kind: doc-stale
- Where:
  - `docs/CHAT_HANDOFF.md:79-86` lists "feature packages for projects, roster, subjects, results, generation, review/export, import, and support". None exist; there is one reducer.
  - `CHAT_HANDOFF.md:104-113` says "remaining release work is ... validation and hardening", while main is red and the iOS 27 migration has not started.
  - `docs/PRODUCTION_MVP_PLAN.md:64-102` describes a feature tree and 12 dependency clients (`BackupClient`, `SpreadsheetClient`, `DocumentExportClient`, `ShareClient`, `FileSystemClient`, …). The code has 5 clients: Clipboard, CommentEngine, Dataset, Date, ProjectStore (`Sources/AppFeature/*Client.swift`). The plan's "First Ten Implementation Days" (:329-387) is history.
  - `docs/ledgers/VALIDATION_LEDGER.md` has no entry after 2026-06-13, so it records no red main.
  - `DECISIONS_LEDGER.md` has no entry for the 2026-08-08 iOS 27 / Swift 6 / Liquid Glass decision.
  - `docs/OSS_DEPENDENCY_POLICY.md:44-50` uses `from:` while the manifest uses `exact:`, and `:60` says "Pin to a Swift 5.10-compatible release".
  - `DATA_LEDGER.md` and `DATASET_SOURCE_TRANSFORM.md` claim dataset parity that no longer holds (F4).
  - `README.md:56` sends readers first to `IOS_CI_SKILL_RECOMMENDATIONS.md`.
- What it does now: Agents told to "read first" (`AGENTS.md:31-42`) load guidance that contradicts the code.
- Why it is like this: These are planning-era documents that were never revised; AGENTS.md mandates reading them.
- Why it matters: Future agents will port toward a plan that no longer exists, or keep Swift 5.10 constraints.
- Recommended replacement:
  - Record the iOS 27 decision in DECISIONS_LEDGER and PROJECT_LEDGER.
  - Rewrite CHAT_HANDOFF as a 20-line current-state note, or delete it.
  - Cut PRODUCTION_MVP_PLAN down to the scope list (formats, offline, privacy), dropping the obsolete architecture and day plan.
  - Fix the policy version syntax.
  - Add a VALIDATION_LEDGER entry recording that main has been red since 2026-08-08.
- Effort: S
- Confidence: High

### F19: Documentation ceremony the project does not need
- Severity: Low
- Kind: doc-stale
- Where:
  - `ridiculously-close-repo-audit.md` (919 lines at the repo root; self-labelled "Historical snapshot (2026-06-12)")
  - `docs/IOS_CI_SKILL_RECOMMENDATIONS.md` (63 lines; duplicates the ranking table at `AGENTS.md:145-155`, with a dated star count)
  - `docs/validation/*.md` (5 files that exist to satisfy validators, F15)
  - `docs/ledgers/WORKLOG.md` (897 lines) and `VALIDATION_LEDGER.md` (820 lines), both append-only
  - `docs/backlog/INITIAL_BACKLOG.md` (labelled "Historical")
  - `docs/release/app-store/` (about 50 marketing, press and launch-message drafts and a support-site HTML set)
  - `docs/release/app-store/05_assets/app_icon/` (duplicates the asset catalog icons)
- What it does now: Roughly 5,000 lines of markdown for an app of about 20k lines of Swift. Most of it is narrative written by agents for agents.
- Why it is like this: The ledger regime in AGENTS.md, plus several AI audit passes.
- Why it matters: Reading cost, and contradictions (F18). The git log already holds the history.
- Recommended replacement: Move the audit and the historical backlog to `docs/archive/` or delete them (git keeps them). Delete IOS_CI_SKILL_RECOMMENDATIONS, keeping the AGENTS.md table only if those tools are actually used. Cap WORKLOG/VALIDATION_LEDGER, or replace them with the git log plus CI history. Keep only the App Store copy, privacy policy and review notes that will actually be submitted.
- Effort: S
- Confidence: Medium (how much to keep is the owner's taste)

### F20: Vendored agent skills: the upstream is gone and two skills are irrelevant
- Severity: Low
- Kind: doc-stale
- Where: `skills-lock.json` (all 7 skills sourced from `wisdom-in-a-nutshell/agents`; `gh api repos/wisdom-in-a-nutshell/agents` returns 404); `.agents/skills/c-bounds-safety/` (C `-fbounds-safety`; the repo has no C code); `.agents/skills/uikit-app-modernization/` (UIKit scene/orientation migration; the app is pure SwiftUI)
- What it does now: The lock hashes cannot be re-verified or updated. `swiftui-whats-new-27`, `swiftui-specialist` and `test-modernizer` are relevant to the iOS 27 migration and say they are Apple-authored.
- Why it is like this: They were installed on 2026-06-09 (commit 140102f, "Install Xcode 27 Apple native agent skills").
- Why it matters: Small; it adds noise to agent context.
- Recommended replacement: Keep the three relevant skills as vendored files and remove the other four plus the lock entries. If Apple publishes these skills officially (e.g. inside Xcode 27's agent integration), switch to that source.
- Effort: S
- Confidence: High (404 and relevance); Low on Apple provenance, which cannot be verified now that the upstream is gone

### F21: Asset catalog and localisation setup are not iOS 27-ready
- Severity: Low
- Kind: best-practice
- Where: `Sources/CommenterIOSApp/Resources/Assets.xcassets/AppIcon.appiconset.pre-app-store-backup-20260612-114707/` (a stale backup folder inside the shipped catalog); `AppIcon.appiconset/Contents.json` (legacy multi-size iPhone set); `Package.swift:7` (`defaultLocalization: "en"`), while `git ls-files` finds no `.xcstrings`
- What it does now: The backup icon set is compiled with the catalog. The icon has no dark, tinted or clear (Liquid Glass) variants. There is no String Catalog, although the localisation plan says one is planned.
- Why it is like this: The backup was made during icon replacement in June.
- Why it matters: iOS 26+ home-screen icon appearances come from Icon Composer `.icon` files. The owner chose native Liquid Glass chrome.
- Recommended replacement: Delete the backup appiconset. Create an Icon Composer `.icon` (Xcode 26+) and set it as the app icon. Add `Localizable.xcstrings` so Xcode extracts strings automatically, even for English only.
- Effort: S
- Confidence: Medium

### F22: The ported readiness check drops co-occurring problems that V3 reports
- Severity: Low
- Kind: correctness-bug
- Where: `Sources/CommentEngine/ReportReadiness.swift:192-202` vs `C:\Commenterv3\client\src\lib\report-readiness.ts:297-329`
- What it does now: When a draft is stale, iOS returns `.staleReport` with no `placeholders` and no other issues. V3 returns the stale status plus `placeholders` and an `issues` list, with a message naming the other issues (`messageWithOtherIssues`).
- Why it is like this: A partial port in d98e862.
- Why it matters: A teacher fixes "details changed", then discovers the template text afterwards. This is a minor C006 parity gap.
- Recommended replacement: Port V3's issue accumulation, or record it as accepted.
- Effort: S
- Confidence: High

### F23: A CSV that ends in a blank line is reported as "malformed"
- Severity: Medium
- Kind: correctness-bug
- Where: `Sources/CommenterImportExport/CSVParser.swift:86-101` (see G3)
- What it does now: See G3. Header-only files with trailing newlines, which Excel and Numbers commonly write, produce the generic "The CSV file is malformed and could not be read."
- Why it is like this: The fallback parser was deleted in d98e862 (correctly, per the OSS policy), but the blank-row filtering it provided was not replaced.
- Why it matters: The error message misleads the teacher. Ragged blank lines in otherwise valid files may also be rejected, though that was not verified.
- Recommended replacement: Strip whitespace-only lines before `CSVReader.decode`, keeping CodableCSV as the parser.
- Effort: S
- Confidence: Medium

### F24: The import/export module depends on persistence only to compute a fingerprint
- Severity: Low
- Kind: architecture
- Where: `Package.swift:53`; `Sources/CommenterImportExport/BackupEnvelope.swift:2,302` (`import CommenterPersistence` → `projectFingerprint(...)` from `Sources/CommenterPersistence/ProjectFingerprint.swift`)
- What it does now: ImportExport links GRDB transitively just to hash a project.
- Why it is like this: No recorded reason.
- Why it matters: Coupling: the file-format layer depends on the database layer.
- Recommended replacement: Move `projectFingerprint` beside `TextFingerprint.swift` in `CommenterDomain` and drop the dependency.
- Effort: S
- Confidence: High

### F25: No formatter or linter
- Severity: Low
- Kind: best-practice
- Where: The repo root has no `.swift-format` or `.swiftlint.yml`, and CI has no lint step
- What it does now: Style is enforced by no tool.
- Why it is like this: No recorded reason.
- Why it matters: The diffs from many agent hands are inconsistent.
- Recommended replacement: Use `swift format`, which ships with the Swift 6 toolchain, with a committed `.swift-format`, and run `swift format lint --strict -r Sources Tests` in the build job.
- Effort: S
- Confidence: High

## Keep (good as is)
- **Module split of pure logic.** CommenterDomain (no deps), CommentEngine, CommenterReportSafety and CommenterPersistence (GRDB) have clean, testable seams, and the tests mirror them.
- **Local package + thin Xcode host app.** The right shape. Just remove the executable target (F10).
- **`Package.resolved` committed and checked with `git diff --exit-code` in CI.** Correct lockfile discipline.
- **`validate_dataset_source_transform.py`.** It is the one validator that caught a real problem (F4).
- **PrivacyInfo.xcprivacy.** Minimal and accurate: FileTimestamp C617.1, no tracking, no collected data, and no UserDefaults use found in Sources.
- **The behavioural intent of the test suite.** Truthful-state tests (no success without verified write, cancellation never reports success, no overwrite of existing exports) are valuable. Keep the assertions; fix the fixtures and structure.
- **The release workflow's fail-open secret check** (`ios-release.yml:41-69`) and `environment: app-store-release` gating. Keep the idea if the GitHub release lane is kept.
- **The `concurrency` block on main** (f73931e). Keep it.
- **Three vendored skills** (`swiftui-whats-new-27`, `swiftui-specialist`, `test-modernizer`). Directly useful for the iOS 27 / Swift Testing migration.

## Open questions for the owner
- CommenterV3 rebuilt its comment engine and dataset on ACARA v9 in Oct–Nov 2026 (F4). Should the iOS app re-port to the new V3 engine before release, or ship the June engine and record that as a deliberate divergence? This is a scope decision, not a code one.
- Release pipeline: Xcode Cloud (recommended: least maintenance, signing and TestFlight handled), or keep a GitHub Actions lane with an App Store Connect API key? This decides whether `ios-release.yml`, the signing secrets and `fastlane/` survive (F5, F17).
- How much of the ledger/handoff/audit documentation do you want kept as working documents rather than archived (F19)? Today AGENTS.md makes every agent read about 5,000 lines of it.
- Blocker noted: the root cause of G4/F6 cannot be confirmed without a Mac. The catch-all error handling hides the underlying error, and no Swift toolchain is available on this host.
