# Plan to fix the 15 November 2026 audit — modernization phase

Status: **approved 15 November; PR 1 in progress.** Written by the lead agent alone (no subagents) from
the audit report, the four reviewers' notes, `AGENTS.md`, `PROJECT_RULES.md` (as updated 15 November) and the live
iPhone code at main `fddb0e8`.

Words used here are the audit's: **web app** (CommenterV3), **comment**, **wording file**, **report file**,
**backup**, **automated checks**. "Package" in a work-package table means a unit of delegated work; "Swift package"
means a code dependency.

---

## 1. The plan in one page

**Two phases, by your direction (recorded in `PROJECT_RULES.md` → Phasing):**

1. **Modernization (this plan).** Bring the app to iOS 27 / Swift 6 / Xcode 27, update every package, replace
   hand-written generic code with Apple frameworks and open-source packages, rebuild the screens on native SwiftUI
   components and a proper feature tree, fix the defects that lose work or block teachers, and delete the current
   AI features down to a small scaffold.
2. **Parity and AI (a later plan).** Bring comment generation, features, workflow and branding into parity with
   CommenterV3, and rebuild the AI features. Section 8 lists what moves there.

**Modernization runs as four pull requests:**

| PR | What it does | Rough size |
|---|---|---|
| **PR 1 — Back to green, AI removed** | iOS 27 / Swift 6 / Xcode 27; packages updated; the current AI features deleted down to a scaffold; the remaining failing tests fixed; CSV blank-line bug and XLSX template failure fixed; privacy link with a placeholder address; automated checks tidied and main protected; stale documents deleted. | 3–5 days |
| **PR 2 — Replace hand-written file and storage code** | libxls for old Excel files, Apple's TabularData for CSV, SwiftDocX for Word, libxlsxwriter for Excel; XLS writing removed; saving becomes one file per project with no database and no recovery copies; backup code stripped of web-compatibility machinery, with Apple's own password-key routine; the "they" and "Group work" defects fixed. | 1–2 weeks |
| **PR 3 — Rebuild the screens** | Native SwiftUI controls and a TCA feature tree replace the one giant feature, the 3,010-line screen file and the three home-made component kits; light appearance only; autosave; confirmations before destructive changes; Replace / Keep Both on restore; one Done button; Writing Tools off in comment fields; plain wording and accessibility fixes. | 2–3 weeks |
| **PR 4 — Tests, formatter, release clean-up** | Remaining tests moved to Swift Testing; the approved new tests; Apple's code formatter; the broken release workflow and release ceremony deleted; documents brought up to date. | 1 week |

**Orchestration:** yes — 18 work packages (3 Haiku 5.5 high, 14 Sonnet 5.5 medium including four independent
checks, 1 Opus 5.5 medium), run in waves. Modules split cleanly, the screen foundation is intricate enough for Opus,
deletions and formatting suit Haiku, and a fresh Sonnet checker verifies each PR against this plan. The lead writes
every instruction sheet, owns the shared files (`Package.swift`, `Package.resolved`, `PROJECT_RULES.md`,
`README.md`), reads the automated-check logs and decides every question.

---

## 2. Decisions

**Recorded in `PROJECT_RULES.md` on 15 November:** pre-production status and placeholders; no file or data
compatibility with CommenterV3 (parity of features and branding stays the goal); phasing; light appearance only;
one JSON file per project with no database (D7); autosave with no Save button (D8); Delete Project erases
everything, no recovery copies (D6); one Done action (D11); legacy XLS read but not written (D5); no migrations of
earlier test builds (D3).

**Approved, process only (kept in this plan, not in the rules):** no "Revert to last saved" button (N2); the
wording-file check stays a local script (N3); the new tests in Section 7 (N5, minus the two parity tests, which
move to phase 2).

**Deferred by your direction:** Xcode Cloud / release pipeline (D13); Mac rental (D15).

**Moved to the parity phase:** D1 (re-port comment generation), D12 (which web features), N1 (AI feature list).

**Approved 15 November:** Q1, the AI scaffold as described in 4.1; Q2, the placement of the borderline items at the
end of Section 8. Status: PR 1 in progress.

---

## 3. How the work runs on this Windows machine

- **No Xcode here.** Every Swift build and test runs on GitHub's Xcode 27 machine (`xcode-27`, labelled "preview"
  by GitHub today). Each PR opens as a draft at its first push and is bound to the app's PR monitor, which wakes
  the lead on failures; nobody polls.
- **One automated-check run per finished batch of edits** (running-slow-checks): executors finish and commit
  their package, the lead integrates the wave and pushes once, reads the full saved log on failure, fixes every
  failure, and pushes once more.
- **Executors decide nothing.** The lead writes each line-anchored instruction sheet immediately before dispatch,
  against the code as it stands after the previous wave. Questions an executor raises come back to the lead.
- **Models, as you specified:** Opus 5.5 medium only for the most complex package; Sonnet 5.5 medium for most;
  Haiku 5.5 high for mechanical work. `model` and `effort` are passed on every Agent call; agents are fresh, never
  forks.
- **Excel test files** are made on this computer with the installed Excel 16 through its automation interface.
- **Publication** only when you say "publish" or "quick publish".

---

## 4. PR 1 — Back to green, AI removed

### 4.1 Design

**Toolchain and packages (issues 1, 2, 32 first half).**
- `Package.swift`: `swift-tools-version: 6.4`; `platforms: [.iOS(.v27)]` only. Dependencies switch from `exact:` to
  `.upToNextMinor(from:)`: TCA `1.26.2`, GRDB `7.12.0`, ZIPFoundation `0.9.20`, CoreXLSX `0.14.2`, OLEKit `0.3.1`,
  CodableCSV `0.6.7` (GRDB, OLEKit and CodableCSV are removed in PR 2; bumping them now keeps PR 1 compiling).
- Delete the `CommenterIOSApp` executable product and target; move `Sources/CommenterIOSApp/` to `App/`,
  referenced only by the Xcode project. Delete the `CommenterTestSupport` library product. Delete the
  `CommenterReportSafety` target, product and test target (its only consumers are the AI features being deleted),
  and `CommenterAITestSupport` entirely.
- `project.pbxproj`: deployment target `27.0`; `SWIFT_VERSION = 6.0`; `SWIFT_STRICT_CONCURRENCY = complete`; app
  paths to `App/`; delete both `INFOPLIST_KEY_REPORT_WRITER_PRIVACY_POLICY_URL` lines. (Xcode's project-format
  upgrade needs Xcode's own window and is deferred.)
- TCA 1.26 deprecation warnings in the current screens are left; PR 3 deletes those files. Only compile errors are
  fixed, with real `Sendable` corrections (no `nonisolated(unsafe)`, no new `@unchecked Sendable`).
- `.github/dependabot.yml`: ecosystems `swift` and `github-actions`, directory `/`, weekly.

**AI removed down to a scaffold (your direction; issues 39, 47–50, 63 move to phase 2).**
Delete:
- `Sources/CommenterAI/AIRequestValidation.swift`, `FoundationModelReportGenerator.swift`, `PromptRegistry.swift`,
  `FoundationModelAvailabilityChecker.swift` and `AIClient.swift`;
- `Sources/CommenterAITestSupport/`, `Sources/CommenterReportSafety/`, `Tests/CommenterAITests/`,
  `Tests/CommenterReportSafetyTests/`, `Tests/CommenterDomainTests/ProjectAIMetadataTests.swift`;
- `Sources/AppFeature/Features/ProjectAIWorkflowFeature.swift`, `Sources/AppFeature/AIClientDependency.swift`
  (replaced by the scaffold's dependency), every AI action case in `AppFeature.swift` and its routing in
  `AppFeatureReducer.swift`, the AI Studio, bulk AI, AI review queue, local safety check and before/after views in
  `WorklistSections.swift`, their closures in `AppView.swift`/`WorklistRootView.swift`, and AI rows in
  `SupportDiagnostics.swift`;
- AI fields in `Models.swift` (`reviewState`, `approvalFingerprint`, `approvedTextFingerprint`, AI traces,
  `ProjectAIMetadata` and related types) and their checks in `ProjectValidation.swift`; the AI approval branch in
  `ReportReadiness.swift`; `Sources/CommenterImportExport/HiddenAIExportStrings.swift` and its callers;
- the "Open AI Review Queue" App Intent and its shortcut;
- AI test cases in `AppFeatureTests.swift`, `ReportReadinessTests.swift`, `ProjectValidationTests.swift` and the three
  export test files (this removes reviewer D's group G1 and the AI case in G5 instead of fixing them).

**Scaffold kept (recommended answer to Q1):** the `CommenterAI` target with one file, `AIAvailability.swift`:
```swift
import FoundationModels

public enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

public struct AIClient: Sendable {
    public var availability: @Sendable () -> AIAvailability
}

extension AIClient {
    /// Apple's on-device model, named explicitly (PROJECT_RULES.md). No other model is ever used.
    public static let live = AIClient {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .unavailable(reason: "This iPhone doesn't support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled): .unavailable(reason: "Apple Intelligence is turned off in Settings.")
        case .unavailable(.modelNotReady): .unavailable(reason: "Apple Intelligence is still downloading.")
        case .unavailable: .unavailable(reason: "Apple Intelligence isn't available on this iPhone.")
        }
    }
}
```
registered as a TCA dependency `\.aiClient`, and shown in one row under Support: "Apple Intelligence — Available on
this iPhone" or the reason. No AI control appears anywhere else.

**Privacy link (issue 46).**
```swift
public enum AppPrivacyPolicy {
    // PLACEHOLDER (PROJECT_RULES.md, pre-production): set the real address before App Store submission.
    // While this is nil, the Support screen shows no privacy-policy link rather than a dead one.
    public static let url: URL? = nil
}
```
Its caller in the Support screen uses it directly. The build-setting step in `APP_STORE_RELEASE_CHECKLIST.md` is
deleted.

**Tests on the iPhone simulator (issue 2).** CI runs the package test targets with the package's own
`CommenterIOS-Package` scheme on the simulator, from a copy of `Package.swift`, `Sources` and `Tests` (xcodebuild
picks the app project when it sits beside `Package.swift`). The app scheme lists only CommenterIOSScreenshotTests.
No test plan: a plan that pointed at the package's own test targets from the app project found no tests on Xcode 27.1.
Delete `scripts/validate_xcode_scheme_scope.py` and `docs/validation/XCODE_SCHEME_SCOPE.md`.

**Automated checks (issues 59, 55 part).** New `.github/workflows/ios-ci.yml`, in full:

```yaml
name: iOS CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

permissions:
  contents: read

env:
  DESTINATION: platform=iOS Simulator,name=iPhone 17
  DERIVED_DATA_PATH: ${{ github.workspace }}/build/DerivedData

jobs:
  ios-build:
    name: Build iOS app target
    runs-on: xcode-27
    timeout-minutes: 35
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: build/DerivedData/SourcePackages
          key: spm-${{ hashFiles('Package.resolved') }}
      - name: Lint privacy manifest
        run: plutil -lint App/Resources/PrivacyInfo.xcprivacy
      - name: Resolve packages
        run: |
          set -euo pipefail
          mkdir -p build
          xcodebuild -resolvePackageDependencies -project CommenterIOS.xcodeproj -scheme CommenterIOS \
            -derivedDataPath "$DERIVED_DATA_PATH"
          cp Package.resolved build/Package.resolved.after
          git diff --exit-code Package.resolved
      - name: Build iOS app target
        run: |
          set -euo pipefail
          xcodebuild build -project CommenterIOS.xcodeproj -scheme CommenterIOS \
            -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA_PATH" \
            -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO \
            2>&1 | tee build/ios-build.log
      - name: Upload diagnostics
        if: failure()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: ios-build-diagnostics
          path: |
            build/ios-build.log
            build/Package.resolved.after

  swift-package:
    name: Swift package tests
    runs-on: xcode-27
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: build/DerivedData/SourcePackages
          key: spm-${{ hashFiles('Package.resolved') }}
      - name: Run unit tests on the iPhone simulator
        # xcodebuild picks the app project when it sits beside Package.swift, so the package
        # tests run from a copy of the package alone, using its own CommenterIOS-Package scheme.
        run: |
          set -euo pipefail
          mkdir -p build
          pkg="$RUNNER_TEMP/package"
          mkdir -p "$pkg"
          cp -R Package.swift Package.resolved Sources Tests "$pkg/"
          cd "$pkg"
          xcodebuild test -scheme CommenterIOS-Package \
            -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA_PATH" \
            -resultBundlePath "$GITHUB_WORKSPACE/build/UnitTests.xcresult" \
            -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO \
            2>&1 | tee "$GITHUB_WORKSPACE/build/unit-tests.log"
      - name: Upload diagnostics
        if: failure()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: unit-test-diagnostics
          path: |
            build/unit-tests.log
            build/UnitTests.xcresult

  screenshots:
    name: Capture core app screenshots
    runs-on: xcode-27
    timeout-minutes: 45
    needs: [ios-build, swift-package]
    env:
      COMMENTER_SCREENSHOT_DIR: ${{ github.workspace }}/build/screenshots
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: build/DerivedData/SourcePackages
          key: spm-${{ hashFiles('Package.resolved') }}
      - name: Run screenshot UI test
        run: |
          set -euo pipefail
          mkdir -p build "$COMMENTER_SCREENSHOT_DIR"
          xcodebuild test -project CommenterIOS.xcodeproj -scheme CommenterIOS \
            -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA_PATH" \
            -only-testing:CommenterIOSScreenshotTests/CommenterIOSScreenshotTests/testCoreReportFlowScreenshots \
            -resultBundlePath build/Screenshots.xcresult \
            -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO \
            2>&1 | tee build/screenshots.log
      - name: Export screenshot PNGs
        if: always()
        run: |
          set -euo pipefail
          out="$RUNNER_TEMP/attachments"; mkdir -p "$out"
          if [ -d build/Screenshots.xcresult ]; then
            xcrun xcresulttool export attachments --path build/Screenshots.xcresult --output-path "$out"
          fi
          python3 scripts/extract_core_screenshots.py "$out" "$COMMENTER_SCREENSHOT_DIR"
      - name: Upload screenshots
        if: always()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: core-screenshots
          path: |
            build/screenshots/*.png
            build/screenshots.log
```
This merges the privacy lint into the build job, caches packages, makes permissions read-only, pins actions by
commit, runs tests on the iPhone simulator, and stops the screenshot job reporting an artificial second failure.
Delete `.github/workflows/ios-screenshots.yml`, `scripts/validate_ci_artifact_privacy.py` and
`docs/validation/CI_ARTIFACT_PRIVACY.md`. Job names "Build iOS app target" and "Swift package tests" are kept for
the ruleset. If "iPhone 17" is not on the image, the lead substitutes the newest iPhone simulator listed in
GitHub's `xcode-27-arm64-Readme.md` before dispatch. The first run uploads the regenerated `Package.resolved`,
which the lead commits.

**Remaining failing tests (issue 3)**, per reviewer D's classification:
- **G2** (2 readiness tests): give the fixture comment a `resultFingerprint` from `buildGenerationFingerprint`.
- **G5** (16 export tests left after the AI case is deleted): the three `readyReport` helpers set `reviewedAt`;
  `testPreparationBlocksTextThatCannotBeRepresentedInOOXML` asserts that the `notReady` issue list contains the
  control-character issue.
- **G3** (issue 5): in `CSVParser.swift`, drop empty or whitespace-only lines before `CSVReader.decode`. Expected
  result unchanged: "has no data rows".
- **G4** (issue 4): in `CSVTemplates.swift` lines 313–320 the thrown verification error carries the underlying
  `error.localizedDescription` (the existing case gains an `underlying: String` value). The first run's log shows
  the cause; the lead writes the fix to whichever of the writer or verifier is wrong, without loosening the test.

**Main protected (issue 3; your permission given 15 November).** After the PR's checks pass, the lead adds a
ruleset on `main`: required checks "Swift package tests" and "Build iOS app target", branches up to date, no
bypass.

**Stale documents and assets (issues 56 part, 57, 58).** Delete `ridiculously-close-repo-audit.md`,
`docs/backlog/INITIAL_BACKLOG.md`, `docs/CHAT_HANDOFF.md`, `docs/PRODUCTION_MVP_PLAN.md`,
`.agents/skills/c-bounds-safety/`, `uikit-app-modernization/`, `audit-xcode-security-settings/`,
`device-interaction/` and their `skills-lock.json` entries, and the stale icon folder
`AppIcon.appiconset.pre-app-store-backup-20260612-114707/`. Rewrite `docs/IOS_CI_SKILL_RECOMMENDATIONS.md` to the
three kept skills, XcodeBuildMCP and gh-fix-ci (it stays because `PROJECT_RULES.md` links to it). Update
`README.md`'s development commands and remove every reference to deleted files.

### 4.2 Work packages

| ID | Wave | Agent / model (why) | Reason for the split | Owned files | Done when |
|---|---|---|---|---|---|
| A1 | 1 | general-purpose / Sonnet 5.5 medium (many interacting project-file edits) | Toolchain files are disjoint from the AI deletion | `CommenterIOS.xcodeproj/**`, `App/**`, `AppPrivacyPolicy.swift`, `.github/**`, the two validator scripts and their docs | Every 4.1 toolchain, privacy and CI edit present; nothing else changed |
| A2 | 1 | general-purpose / Sonnet 5.5 medium (deletion across many interlocking files) | AI code is its own slice | everything listed under "AI removed", `Sources/CommenterAI/AIAvailability.swift`, the Support row | Every listed AI file and case gone; scaffold present; no AI control left on any screen |
| A3 | 1 | general-purpose / Haiku 5.5 high (deletions and one rewrite) | Documents only | the stale-document list, `docs/IOS_CI_SKILL_RECOMMENDATIONS.md`, `APP_STORE_RELEASE_CHECKLIST.md`, `skills-lock.json` | Files gone; a search for each deleted name finds nothing |
| A4 | 2 | general-purpose / Sonnet 5.5 medium (test reasoning) | Tests depend on A2's deletions | `Tests/**`, `CSVParser.swift`, `CSVTemplates.swift`, `ReviewWorkbookFile.swift` | G2–G5 changes made as specified |
| A5 | 3 | general-purpose / Sonnet 5.5 medium (diagnosing compile and test failures in named areas) | Needs the integrated branch and the first run's log | any `Sources/**` file named in the log | Both required jobs green |
| A6 | 4 | general-purpose / Sonnet 5.5 medium (independent check) | Fresh eyes against 4.1 | none | No deviation, or each listed |

The lead edits `Package.swift` (all 4.1 changes, including the deleted AI and safety targets) before wave 1.

---

## 5. PR 2 — Replace hand-written file and storage code

### 5.1 Design

**Old Excel reading (issue 35).** Vendor libxls v1.6.4 (BSD-2) as a SwiftPM C target `CLibXLS` at
`Sources/CLibXLS/` (upstream `src/`, `include/`, licence, a checked-in `config.h` using libxls's built-in
UTF-16→UTF-8 conversion). Adapter `func readXLSRows(_ data: Data) throws -> [[String]]` in
`SpreadsheetImportFile.swift`: opens with `xls_open_buffer`, reads the first worksheet, renders each cell as
displayed text (whole numbers without `.0`), and maps failures to "This file could not be opened as a workbook."
The existing size and sheet caps apply. Delete the custom OLE reader, BIFF decoder, fast path, OLEKit fallback and
the OLEKit dependency.

**CSV (issue 37).** Apple's TabularData: `DataFrame(csvData:options:types:)`, every column `.string`, header row on.
A UTF-8 byte-order mark is stripped; valid UTF-8 is used as is; anything else is decoded as Windows-1252. Delete the
three pre-parsers and the UTF-16 fallback; row-width errors come from the parsed rows; `CSVReadingError` row and
column map to the existing row-level messages. CSV writing (templates, CSV report export) uses
`DataFrame.csvRepresentation()`, keeping the apostrophe formula guard for CSV only. Remove CodableCSV.

**Word reports (issue 33).** SwiftDocX 1.0.2 (MIT) behind one adapter
`func makeReportDocument(_ packet: PreparedReportPacket) throws -> Data`, producing the same content as today but
on **A4** with the teacher's **line breaks kept** (both are defects in today's file, not parity work — see Q2).
Checked by reopening the bytes with SwiftDocX and comparing paragraph text. Delete the hand-written
WordprocessingML and the regex "verification".

**Excel reports and templates (issues 34, 4).** libxlsxwriter 1.2.4 behind
`func makeWorkbook(columns: [String], rows: [[String]], sheetName: String) throws -> Data`: bold frozen header,
column widths from the longest value up to 80 characters, wrapped comment column, no apostrophe guard. Same columns
as today. Checked by reopening with CoreXLSX. Delete the hand-written SpreadsheetML.

**Legacy XLS writing (issue 36, D5).** Delete `LegacyXLSWorkbookWriter.swift`, the XLS report export option and the
XLS template option, and their tests.

**One write helper (reviewer B-F18).** `writeVerifiedFile(_ data: Data, to: URL, verify: (Data) throws -> Void)` and
one `FileExportError` replace the five copied write-then-verify blocks and four error enums. Writes use
`[.atomic, .completeFileProtectionUnlessOpen]`; the byte-for-byte read-back is dropped; the package reopen check is
kept. Duplicate XML escapers and forbidden-string lists are deleted.

**Saving (issues 22, 23, 24, 28, 61; D6, D7, D3).**
- `ProjectStore` becomes an `actor`, created once and provided through the TCA dependency. One file per project,
  `Application Support/Projects/<projectId>.json`:
  ```swift
  struct SavedProjectFile: Codable, Sendable {
      static let currentSchemaVersion = 1
      var schemaVersion: Int
      var revision: Int
      var savedAt: Date
      var project: Project
  }
  ```
- A save passes `expectedRevision`; a mismatch fails with "This project changed elsewhere. Reopen it to see the
  latest version."
- A file that does not decode, or has another `schemaVersion`, is listed under "Can't open" with "This project was
  saved by an earlier test version of Report Writer and can't be opened." and the actions Delete and Share a support
  copy (the existing damaged-record flow, kept).
- Delete Project removes the file: "<name> was deleted from this iPhone."
- The project size limit counts the bytes of one `JSONEncoder` encode (12 MiB).
- Delete: `SQLiteProjectIndex.swift`, GRDB, `ProjectStoreOperationCoordinator`, recovery snapshots, load-time
  fingerprint verification, `ProjectFingerprint.swift`, `JavaScriptJSON.swift` and the JS-exact size count, the
  `setAttributes` protection helpers, `verifyReadAfterWrite`, the `canImport(CryptoKit)` fallbacks.
- Prepared export files are deleted when the share or save sheet closes and when the app moves to the background.
- Minimal edits to the current screens' store client and messages keep the app compiling until PR 3 replaces them.

**Backups (issues 7, 8, 30, 38; no compatibility required).** The web-compatibility layer goes: checksums, bundle
fingerprints, ciphertext hashes, versions 1–3, encrypted version 1, the 10-character legacy minimum, the hand-built
authenticated-data string. The new format is the app's own:
```swift
struct ProjectBackup: Codable, Sendable {
    var format = "report-writer-backup"; var version = 1; var project: Project
}
struct EncryptedProjectBackup: Codable, Sendable {
    var format = "report-writer-backup-encrypted"; var version = 1
    var iterations: Int; var salt: String; var nonce: String; var ciphertext: String   // base64
}
```
Encryption stays AES-256-GCM with 650,000 PBKDF2-HMAC-SHA256 iterations, 16-byte salt, 12-byte nonce, NFKC
passwords, 12-character minimum. The authenticated data is the `JSONEncoder` encoding of
`{format, version, iterations, salt, nonce}`. The key comes from CommonCrypto `CCKeyDerivationPBKDF`, once per
export (the verify step reuses it). Salt and nonce from `SymmetricKey`/`AES.GCM.Nonce`. Plain backups keep `.json`;
encrypted backups use `.cbackup`. A new store function `restore(_ project: Project, as: RestoreChoice)`, where
`RestoreChoice` is `.replace` or `.keepBoth` (Keep Both assigns a new id and appends " (restored)" to the name),
backs the Replace / Keep Both choice that PR 3 puts on screen.

**Two defects that block or embarrass teachers today (issues 10, 11).**
- **"They" for every student (10):** restore the pronoun tokens in the English-focus and Maths sentences
  (`ReportTextLibraries.swift` 88–110), fix the test that expects "they" for a girl, and accept "they" in the
  language check only when the student's pronouns are they/them or unset.
- **"Group work" rejected (11):** one `isClause(_:)` function in `CommenterDomain/TextRules.swift` using
  `NLTagger(tagSchemes: [.lexicalClass])` — a clause is a noun or pronoun followed later by a verb — replaces both
  verb-list checks; saving checks only length and placeholders. "Group work", "Pair work" and "Show and tell" pass.

**Real test files.** A PowerShell script drives Excel 16 to save a class list as `.xls`, `.xlsx` and Windows-1252
`.csv`, containing whole numbers (stored as RK/MULRK records), a formula, a bold run inside a cell, "Zoë", and
enough distinct text to push the shared-string table past 8 KB. The files go in `fixtures/imports/`; the script is
not committed. The reader tests use them; the test that read the app's own XLS writer output is deleted.

### 5.2 Work packages

| ID | Wave | Agent / model | Reason | Owned files | Done when |
|---|---|---|---|---|---|
| C1 | 1 | general-purpose / Sonnet 5.5 medium (C-library packaging) | Input side | `Sources/CLibXLS/**`, `SpreadsheetImportFile.swift`, `CSVParser.swift`, reader tests, `fixtures/imports/**`, `ReportTextLibraries.swift`, `ReportGenerator.swift` pronoun lines, `ReportReadiness.swift` language check, `ReportInputFeedback.swift`, `ProjectValidation.swift`, `CommenterDomain/TextRules.swift` (new), their tests | Reader and defect tests green on the real files |
| C2 | 1 | general-purpose / Sonnet 5.5 medium (C-library packaging) | Output side | `ReportDocumentFile.swift`, `ReviewWorkbookFile.swift`, `CSVTemplates.swift`, `ReportExportPreparation.swift`, `OOXMLZipWriter.swift`, `ProtectedFileWrites.swift`, deleted XLS writer, export and template tests | Export tests green; reopened files match |
| C3 | 1 | general-purpose / Sonnet 5.5 medium | Saving and backups | `Sources/CommenterPersistence/**`, `BackupEnvelope.swift`, `BackupFileWorkflow.swift`, `ProjectRules.swift`, `JavaScriptJSON.swift` (deleted), `ProjectStoreClient.swift` and the store messages in the current screens, persistence and backup tests | Persistence and backup tests green |
| C4 | 2 | general-purpose / Sonnet 5.5 medium | Independent check | none | No deviation from 5.1 |

The lead edits `Package.swift` (add CLibXLS, SwiftDocX, libxlsxwriter; remove GRDB, OLEKit, CodableCSV) and
`docs/OSS_DEPENDENCY_POLICY.md` / `docs/dependencies/DEPENDENCY_AUDIT.md` (Swift 6, ranges, the new packages, the
removed ones, the Swift 5.10 line deleted).

---

## 6. PR 3 — Rebuild the screens

### 6.1 Design (on the current data model; parity features are phase 2)

**Feature tree (TCA 1.26.2):**
```
AppFeature (TabView: Projects · Settings)
├─ ProjectsFeature        list, create sheet, restore backup, delete confirmation, "Can't open" section
│   └─ path: StackState<ProjectFeature>
├─ ProjectFeature         Project home: progress Gauge "18 of 28 Done", save status, rows to the screens below
│   ├─ RosterFeature      searchable List, swipe Delete (confirmed), student editor
│   ├─ SubjectsFeature    Form of Toggles; turning one off asks first
│   ├─ ResultsFeature     one student or one subject at a time, Previous / Next
│   ├─ CommentsFeature    grouped Not done / Done; editor with "Done & Next"
│   ├─ ExportFeature      format → prepares and opens the save/share sheet in one step
│   ├─ BackupFeature      plain or password-protected; restore with Replace / Keep Both
│   └─ ImportFeature      file picker → preview → confirm
└─ SettingsFeature        Privacy Policy, Support (diagnostics, Apple Intelligence row)
```
Children compose with `Scope`, `ifLet`, `forEach`; dialogs and sheets use `@Presents` with
`AlertState`/`ConfirmationDialogState`; views use `@Bindable var store` and `$store` bindings. `ProjectFeature`
holds `@Shared var project: Project` (swift-sharing, in memory) handed to each child. Delete the old state and
140-case action list in `AppFeature.swift`, `AppFeatureReducer.swift`, every `extension AppFeature` "feature"
file, `WorklistRootView.swift`, `WorklistSections.swift`, `ProjectsRootView.swift`, `SupportRootView.swift`,
`OperationStatusView.swift`, `DateClient.swift`, the manual client inits and the `ObservableObject` intent router.
Kept clients become `@DependencyClient`s; dates and ids use `\.date` and `\.uuid`. Launch loads projects and the
wording file at the same time (issue 29, the launch-order part).

**Autosave (issue 13, D8).** One second after the last change (a cancellable effect keyed `AutosaveID`) and
immediately on `scenePhase == .background`. Status: "Saving…", "All changes saved", or "Couldn't save changes. Your
edits are still on screen." with Try Again. No Save button, no Revert, no "save before…" guards.

**Confirmations (issue 14).** "Turn off Science? This removes 28 results and 28 comments." (Cancel / Turn Off);
"Delete Ava Smith? This removes 8 results and 8 comments." (Cancel / Delete); "Turn off all subjects? This removes
N results and N comments." Counts computed from the project.

**Restore (issue 15).** On an id collision: "A project named <name> already exists" with Replace, Keep Both,
Cancel; the success message names what happened.

**One Done button (issue 25, D11).** With AI gone, the review fields reduce to `reviewedAt`: Done = `reviewedAt` set
and the comment's fingerprint current. "Mark Warnings Reviewed" folds into Done (warnings are shown beside the
button; Done records that the teacher saw them). Delete `validationWarningReview`, `currentTextFingerprint`
(computed when needed) and the `didSet` side effects; editing the text clears `reviewedAt` in one mutating method.

**Native components and light appearance (issues 20, 21, 42, 43).** `Form`, `List`, `Section`, `LabeledContent`,
`ContentUnavailableView`, `Picker(.segmented)` for achievement level, `Toggle`, `.searchable`, `.swipeActions`,
toolbar items with `ToolbarOverflowMenu`, the iOS 27 `Tab` API (the app's enum renamed `AppTab`), navigation titles
only, system colours. `UIUserInterfaceStyle = Light` in the app's Info.plist. `DesignSystem` keeps only
`PaperSurface` (paper background for the comment editor and report preview) and the serif title font;
`CommenterStationeryDesignSystem.swift`, `CommenterDesignSystem.swift`, `ProjectSummaryCard.swift` and the
Worklist/Support component copies are deleted.

**Accessibility and wording (issues 43, 44, 45).** System colours instead of the failing orange and green; native
selection traits; no rotated or shrunk text; `AccessibilityNotification.Announcement` when import, export, backup
and generation finish. A `Localizable.xcstrings` String Catalog with catalog plurals; plain display names for every
status; no developer language on screen (revision numbers and storage state only under Support). The Icon Composer
icon is deferred (needs a Mac).

**Writing Tools (issue 47).** `.writingToolsBehavior(.disabled)` on the comment editor and every field whose text
can reach a comment.

**File types (issue 40).** Exported type `<bundle id>.cbackup` conforming to `public.json`, plus
`CFBundleDocumentTypes`, in Info.plist; `UTType(exportedAs:)` in code; `.onOpenURL` routes an opened backup into
restore. The two multi-dot dynamic types are deleted.

**Small helpers (issue 41).** `.formatted()` replaces `CommenterFormatters`; `fileExporter` with a small
`Transferable` replaces the fake `FileDocument`; errors matched by type, never by wording. `ActivityShareSheet` kept.

**App Intents (reviewer A-F16).** "Open Report Preparation" kept, open-only, exposed through `AppIntentsPackage`
and routed via a TCA dependency.

**Screenshot test.** The existing UI test is rewritten to walk the new screens by accessibility identifier (it is
the existing proof owner and cannot survive the rebuild as written).

### 6.2 Work packages

| ID | Wave | Agent / model (why) | Reason | Owned files | Done when |
|---|---|---|---|---|---|
| B1 | 1 | general-purpose / **Opus 5.5 medium** (architecture foundation) | Every screen depends on it | AppFeature root, `ProjectsFeature`, `ProjectFeature` (incl. autosave), `SettingsFeature`, clients, `Sources/DesignSystem/**`, `Sources/CommenterAppIntents/**`, `Localizable.xcstrings`, Info.plist entries; deletes the old screen layer; review-field reduction in `Models.swift` and `ReportReadiness.swift`; `docs/decisions/0001-native-swiftui-tca.md` | App builds; ported tests for these features green |
| B2 | 2 | general-purpose / Sonnet 5.5 medium | Separate folders | `RosterFeature`, `SubjectsFeature`, `ResultsFeature` (+ tests) | Their tests green |
| B3 | 2 | general-purpose / Sonnet 5.5 medium | Separate folders | `CommentsFeature`, `ExportFeature`, `BackupFeature`, `ImportFeature` (+ tests), prepared-file lifecycle | Their tests green |
| B4 | 3 | general-purpose / Sonnet 5.5 medium | Independent check; owns the screenshot test | `UITests/**` | No deviation from 6.1; all three jobs green; screenshots show every screen |

---

## 7. PR 4 — Tests, formatter, release clean-up

- **Swift Testing (issue 53).** New and ported tests in PRs 2–3 are written in Swift Testing. PR 4 converts the rest,
  turning loops over cases into `@Test(arguments:)`. One shared `Project.fixture(...)` and
  `GeneratedReport.exportReady(...)` in `CommenterTestSupport` replace the eleven private copies. The UI test stays
  XCTest.
- **Approved new tests (N5):**

  | Test | What it proves | Replaces |
  |---|---|---|
  | One short UI test per screen (8) by accessibility identifier, with `performAccessibilityAudit()` and a largest-text run | Screens, contrast and VoiceOver work | The single 800-line coordinate-tapping test and `extract_core_screenshots.py` |
  | 30-student class: open, type, generate, export within a time limit | Typing and generation stay fast at real class sizes | Nothing |
  | Exported DOCX and XLSX opened by LibreOffice in headless mode on the GitHub runner | Report files are well-formed and open in an office program | Nothing; today nothing opens them |

  (The whole-wording-file sweep and the web parity test move to phase 2, where the wording file is replaced.)
- **Formatter (issue 60).** Commit `.swift-format`; one formatting-only commit with
  `swift format format -i -r Sources Tests App`; `swift format lint --strict -r Sources Tests App` added to the build
  job.
- **Release clean-up (issues 54, 55).** The pipeline choice is deferred, but nothing broken is kept: delete
  `.github/workflows/ios-release.yml`, both `fastlane/` metadata trees, the release evidence file,
  `validate_app_store_release_package.py`, `validate_release_proof_matrix.py`, `validate_localization_plan.py` and
  their `docs/validation/` companions, and every App Store draft except the text to be submitted, kept as one file
  `docs/release/app-store-text.md`. `APP_STORE_RELEASE_CHECKLIST.md` becomes the list of open release steps (choose
  the pipeline, replace the privacy placeholder, the deferred items in Section 9).
- **Docs.** `README.md` current; references to deleted files removed; this plan deleted. The audit folder stays
  until phase 2, which still needs its issue list.

| ID | Wave | Agent / model | Reason | Owned files | Done when |
|---|---|---|---|---|---|
| T1 | 1 | general-purpose / Sonnet 5.5 medium | Tests | `Tests/**`, `UITests/**`, `Sources/CommenterTestSupport/**`, the LibreOffice step in `.github/workflows/ios-ci.yml`, `scripts/extract_core_screenshots.py` (deleted when replaced) | All tests green; approved tests present |
| T2 | 1 | general-purpose / Haiku 5.5 high | Deletions and doc rewrites | the release and doc files above | Files gone; no references left |
| T3 | 2 | general-purpose / Haiku 5.5 high | Formatting comes last | `.swift-format`, every Swift file (whitespace only), the lint step | Lint green; diff whitespace-only beyond config and workflow |
| T4 | 3 | general-purpose / Sonnet 5.5 medium | Independent check | none | No deviation from this section |

---

## 8. Every audit issue, and which phase fixes it

**Modernization (this plan):**

| Issue | Where | Issue | Where | Issue | Where |
|---|---|---|---|---|---|
| 1 packages | PR 1 | 21 Dark Mode | PR 3 (light only) | 42 iOS 27 shell | PR 3 |
| 2 iOS 27 / Swift 6 | PR 1 | 22 two stores | PR 2 | 43 contrast, VoiceOver | PR 3 |
| 3 red main, protection | PR 1 | 23 recovery copies | PR 2 | 44 developer language | PR 3 |
| 4 XLSX template | PR 1; writer replaced PR 2 | 24 "damaged" trap | PR 2 | 45 strings | PR 3 (icon deferred) |
| 5 CSV blank line | PR 1 | 25 review fields, three buttons | PR 1 (AI fields), PR 3 | 46 privacy link | PR 1 (placeholder) |
| 10 "they" | PR 2 | 28 JS-exact encoding | PR 2 | 47 Writing Tools | PR 3 |
| 11 "Group work" | PR 2 | 29 slow launch | PR 3 (load order) | 51 real samples | PR 2 (Excel files) |
| 13 autosave | PR 3 | 30 dead/compat code | PR 1, PR 2 | 52 test gaps | PR 3, PR 4 |
| 14 confirmations | PR 3 | 32 two app targets, coupling | PR 1, PR 2 | 53 XCTest, copied fixtures | PR 3, PR 4 |
| 15 restore overwrite | PR 2, PR 3 | 33 DOCX writer | PR 2 | 54 release workflow | PR 4 (deleted) |
| 17 one giant feature | PR 3 | 34 XLSX writer | PR 2 | 55 script ceremony | PR 1, PR 4 |
| 18 slow typing | PR 3 | 35 XLS reader | PR 2 | 56 stale key docs | PR 1–4 |
| 19 endless Work list | PR 3 | 36 XLS writer | PR 2 (deleted) | 57 unneeded docs | PR 1, PR 4 |
| 20 three component kits | PR 3 | 37 CSV pre-parsers | PR 2 | 58 vendored skills | PR 1 |
| 40 file types | PR 3 | 38 PBKDF2 | PR 2 | 59 CI waste | PR 1 |
| 41 small helpers | PR 3 | 61 temp files | PR 2 | 60 formatter | PR 4 |

**Closed by your decision, not by code:** 7 and 8 (backups moving between the apps — compatibility is not required;
the compatibility code is deleted in PR 2).

**Removed with the AI now, rebuilt in phase 2:** 12 (safety-check false alarms — the check is deleted with the AI it
guards), 39 (before/after view), 48, 49, 50, 63.

**Parity phase (later plan):** 6 (re-port comment generation and wording file), 9 (export scope, grouping, cover
line, web columns), 16 (missing web features), 26, 27, 31 (engine internals the re-port replaces), 29 (the
double-parsed wording file), 62 (readiness listing every problem), plus D1, D12, N1 and branding parity.

**Q2 — the borderline items.** Recommended placement above: autosave, confirmations and Keep Both in modernization
(they stop lost work); A4 and line breaks with the Word swap in modernization (defects in today's file); "they" and
"Group work" in modernization (wrong reports and a save that fails); engine internals 26, 27, 29 (parse), 31 and 62
in the parity phase (the re-port replaces that code).

Reviewer-only findings: App Intents packaging (A-F16, PR 3), duplicated AI guard chains (A-F21, deleted with the AI
in PR 1), nested project card (A-F10, PR 3), prompt hygiene (C-F15, deleted with the AI), Swift 6 globals (C-F17,
PR 1), dead test-support module (D-F13, PR 4), coordinate-tap UI test (D-F14, PR 3–4).

---

## 9. Checked on GitHub, and deferred

**Checked on GitHub's Xcode 27 machine instead of a Mac:** every screen walked on the iPhone simulator with
screenshots; the accessibility audit and largest-text runs; the 30-student timing test; exported DOCX and XLSX
opened by LibreOffice. On this computer, agents also open exported files in Word and Excel 16.

**Deferred by your direction:** the release pipeline (Xcode Cloud or another); Xcode's project-format upgrade; the
Icon Composer icon; App Shortcuts appearing in the Shortcuts app; opening exports in Pages; anything needing a real
iPhone.

---

## 10. What is deleted and what replaces it

| Old version (deleted) | Where it lives now | Replaced by | Readers switched in the same PR |
|---|---|---|---|
| macOS platform and `swift test` | `Package.swift`, `ios-ci.yml` | iOS-only package; package scheme on the simulator | CI, README (PR 1) |
| Package executable target | `Package.swift`, `Sources/CommenterIOSApp` | Xcode app target, files in `App/` | Xcode project, CI lint path (PR 1) |
| Privacy URL build setting | `project.pbxproj`, `AppPrivacyPolicy` | Swift constant (placeholder) | Support screen (PR 1) |
| Current AI features, prompt registry, AI review fields, safety validator | `CommenterAI`, `CommenterReportSafety`, `ProjectAIWorkflowFeature`, `Models.swift` | availability scaffold (Q1) | screens, readiness, export, App Intents, tests (PR 1) |
| Duplicate screenshot workflow, two validators | `.github`, `scripts`, `docs/validation` | `workflow_dispatch` on CI | — (PR 1) |
| Hand-written OLE reader, BIFF decoder, OLEKit | `SpreadsheetImportFile.swift` | libxls adapter | import (PR 2) |
| CSV pre-parsers, CodableCSV | `CSVParser.swift`, `CSVTemplates.swift` | TabularData | import, templates, CSV export (PR 2) |
| Hand-written Word and Excel XML, XLS writer, regex verification, five write blocks | ImportExport | SwiftDocX, libxlsxwriter, `writeVerifiedFile` | export, templates (PR 2) |
| GRDB index, lock coordinator, recovery copies, load-time fingerprint, JS-exact JSON | Persistence, Domain | `ProjectStore` actor, one file per project | project list, open, save, delete (PR 2) |
| Web-compatible backup format, hand-built PBKDF2 | `BackupEnvelope.swift` | the app's own backup format, CommonCrypto | backup and restore (PR 2) |
| Two verb-list clause checks | `ProjectValidation.swift`, `ReportInputFeedback.swift` | `isClause` with NaturalLanguage | generation, saving (PR 2) |
| One giant feature, 3,010-line view, three component kits | `AppFeature`, `DesignSystem` | TCA feature tree, native SwiftUI, `PaperSurface` | every screen, App Intents, tests (PR 3) |
| Release workflow, Fastlane metadata, evidence file, three validators | `.github`, `fastlane`, `scripts`, `docs/validation` | one App Store text file; pipeline later | release checklist (PR 4) |

**Kept, because nothing new covers it:** CoreXLSX (no maintained replacement; forked only if it fails under Swift 6);
ZIPFoundation (used by CoreXLSX and SwiftDocX); `ActivityShareSheet`; `JSONValue` while untyped fields remain; the
current comment engine and wording file (replaced in phase 2); the import preview/commit flow; revision-conflict
detection; the "Can't open" flow; zip-bomb limits; the privacy manifest; the wording-file validator (local; it
reports drift until phase 2).

**Real losses:** no undo for a project deleted without a backup; no XLS export; no AI features until phase 2;
backups from earlier test builds and from CommenterV3 do not open.

---

## 11. Estimates

| Item | Estimate |
|---|---|
| Test cases | +40 to +70 added / ~80 to 120 modified / −110 to −160 deleted (from 356). PR 1 deletes the AI and safety tests (~70) and fixes ~20. PR 2 replaces reader, writer, persistence and backup tests. PR 3 ports most of the 92 reducer tests onto the new features. PR 4 adds the approved tests (~15 cases) and converts the rest to Swift Testing (modified, not added). |
| Documentation files | ~8 updated / 1 added (`app-store-text.md`) / ~65 deleted |
| Custom CSS | 0 lines (Swift only) |
| Dependencies | 3 added (SwiftDocX, libxlsxwriter, libxls vendored) / 3 removed (GRDB, OLEKit, CodableCSV) |
| App code | roughly −10,000 to −14,000 lines net |

## 12. Scope and simplicity

| Question | Answer |
|---|---|
| Does the plan implement the full object and purpose of the requested work? | **Y** — every modernization issue has a PR (Section 8); parity items sit in the parity phase by your direction, recorded in `PROJECT_RULES.md`. |
| Does it reduce scope because implementation is difficult? | **N** — the phase split is your direction about purpose, not difficulty; the screen rebuild and every package replacement stay in. |
| Does it delete and replace obsolete behaviour? | **Y** — Section 10; nothing old is kept beside its replacement. |
| Does it add needless machinery? | **N** — no model-policy check, no CI token, no Revert; the AI scaffold is one file used by one Support row. |
| Does it rewrite or delete stale documentation? | **Y** — deleted or rewritten alongside the code; no archive folder. |
| Does it cover other cases affected by the same cause? | **Y** — one write helper for all five copies; one clause check for both copies; every AI consumer removed together. |
| Does it keep the system lean and fast? | **Y** — removes the unused database, load-time fingerprints, byte read-backs and JS-exact re-encoding. |

## 13. Open-source and components

| Question | Answer |
|---|---|
| Did you check GitHub for OSS? | **Y** — release pages checked 15 Nov with `gh api`. |
| Did you inspect the approved UI framework and reuse it? | **Y** — native SwiftUI and TCA 1.26.2 replace the custom kits. |
| Did you recheck the frameworks' official repositories? | **Y** — TCA 1.26.2 (28 Aug 2026), ZIPFoundation 0.9.20, CoreXLSX 0.14.2. |

| OSS option | Covers | Use | Why |
|---|---|---|---|
| [Techopolis/SwiftDocX](https://github.com/Techopolis/SwiftDocX) 1.0.2, MIT | Word files with headers, footers, page numbers, breaks | Y | Named by the dependency policy; replaces ~330 lines of hand-written XML. Young project. |
| [jmcnamara/libxlsxwriter](https://github.com/jmcnamara/libxlsxwriter) v1.2.4, FreeBSD | Excel writing with widths, wrap, frozen header | Y | Standard library with its own Package.swift; preferred in the dependency policy. |
| [libxls/libxls](https://github.com/libxls/libxls) v1.6.4, BSD-2 | Old Excel reading incl. its container | Y | Reads ordinary Excel files; deletes ~550 lines and OLEKit. Vendored (no upstream Package.swift). |

Apple frameworks instead of packages: TabularData, NaturalLanguage, CommonCrypto, FormatStyle, Foundation Models
(availability only in this phase).

## 14. Rule check

Checked against `AGENTS.md`, `PROJECT_RULES.md` (as updated 15 Nov), your global instructions and your messages in
this conversation. **Changed** marks a rule that forced a change to the previous draft.

| Rule | Result | Evidence and fix |
|---|---|---|
| Your instruction: phase it; modernize now; parity and AI later; delete AI to a scaffold | **Changed** | The previous draft re-ported the engine and rebuilt AI in one effort; now Section 8 splits the phases and PR 1 deletes the AI. Recorded in `PROJECT_RULES.md` → Phasing. |
| Your instruction: no compatibility with CommenterV3 | **Changed** | Web-exact backup format, fingerprint parity and JS JSON deleted (PR 2); issues 7–8 closed by decision; recorded in `PROJECT_RULES.md`. |
| Your instruction: no Dark Mode | **Changed** | `UIUserInterfaceStyle = Light`; Dark Mode screenshots dropped; recorded in `PROJECT_RULES.md`. |
| Your instruction: placeholder privacy address; Excel files made by agents; Xcode Cloud and Mac later | Complies | 4.1 placeholder; 5.1 Excel script; Section 9. |
| Your instruction: lead writes the plan; Opus medium only for the most complex; Sonnet medium main; Haiku high easy | Complies | Written without subagents; 1 Opus (B1), 14 Sonnet, 3 Haiku; model and effort passed on every call. |
| AGENTS 1–2: no phasing or scaffolds unless you direct; no scope cut for difficulty | Complies | Both expressly directed by you; `PROJECT_RULES.md` cites rule 1. |
| AGENTS 4 / pre-production: replace, don't preserve | Complies | No converters; old test-build projects show "Can't open". |
| AGENTS 5: one source of truth | Complies | One store, one write helper, one clause check, one backup format. |
| AGENTS 6: end to end | Complies | Each "done when" exercises the real path: real Excel files, reopened report files, screenshots of every screen. |
| AGENTS 9: docs current | Complies | Docs updated in the PR that changes the code; the CI-skills doc rewritten because `PROJECT_RULES.md` links to it. |
| AGENTS 11: never fake success | Complies | The AI scaffold shows the real device state only; no AI buttons in this phase; the placeholder link is marked. |
| AGENTS 19: proportionate | Complies | No model-policy check, no CI token, no byte read-back. |
| AGENTS tests: expansion needs approval; don't rewrite expectations to match code | Complies | Section 7 tests approved by you; each test fix follows reviewer D's classification. |
| AGENTS Git: publish only on your word | Complies | Four PRs; none merged without "publish". |
| PROJECT_RULES AI rules | Complies | No AI controls in this phase; the scaffold names `SystemLanguageModel.default`; Writing Tools disabled in comment fields. |
| PROJECT_RULES formats (as updated) | Complies | CSV, XLSX, XLS import; DOCX, XLSX, CSV export; backup JSON. |
| PROJECT_RULES dependencies: no hand-rolled formats | Complies | PR 2 replaces every hand-written format layer. |
| PROJECT_RULES Windows host | Complies | All Swift verification on GitHub's Xcode 27 machine; real-iPhone behaviour listed as deferred, not claimed. |
| Global: running-slow-checks | Complies | One run per finished batch; saved logs; no exploratory reruns. |
