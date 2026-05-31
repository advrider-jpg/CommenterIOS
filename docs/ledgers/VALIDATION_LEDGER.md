# Validation Ledger

Append durable validation commands, gates, last known evidence, release
criteria, and validation gaps here.

## Current Validation Status

The repo contains an initial Swift package scaffold, bundled production dataset,
and a minimal `CommenterIOS.xcodeproj` iOS app host.

Local validation on this checkout is limited because `swift`, `xcodebuild`,
`xcodegen`, and `tuist` are not available on PATH. XcodeBuildMCP can discover
the project, but scheme listing, build, run, and test still require `xcodebuild`
and simulator defaults.

## Current Commands

Document hygiene:

```powershell
git status --short
git diff --check
git diff --cached --check
git ls-files --eol
```

Dataset copy verification:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\Commenterv3\client\public\data\comment-engine.json'
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\CommenterIOS\Sources\CommentEngine\Resources\comment-engine.json'
node -e "const fs=require('fs'),crypto=require('crypto'); const src=fs.readFileSync('C:/Commenterv3/client/public/data/comment-engine.json','utf8').replace(/\r\n/g,'\n'); const dst=fs.readFileSync('C:/CommenterIOS/Sources/CommentEngine/Resources/comment-engine.json','utf8'); if(src!==dst) throw new Error('normalized source text differs from bundle'); const data=JSON.parse(dst); console.log(crypto.createHash('sha256').update(dst).digest('hex'), data.ComponentBank.length, data.RecipeBank.length, data.AssembledVariants.length, data.UniquenessGuard.length)"
```

Swift package validation intended on macOS/Apple toolchain:

```bash
swift package resolve
swift test
```

Xcode app-target validation intended on macOS/Xcode:

```bash
xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation -skipMacroValidation build CODE_SIGNING_ALLOWED=NO
```

XcodeBuildMCP discovery:

```text
session_show_defaults
discover_projs(workspaceRoot: "C:\CommenterIOS", scanPath: "C:\CommenterIOS", maxDepth: 5)
list_schemes(projectPath: "C:\CommenterIOS\CommenterIOS.xcodeproj")
```

## Last Known Evidence

2026-05-30:

- `git diff --check` was clean before initial planning commit.
- `git diff --cached --check` was clean before line-ending policy commit.
- `git ls-files --eol` showed LF-pinned tracked docs after `.gitattributes`.
- CommenterV3 ProjectStatus dashboard was updated for the planning repo
  creation task.

2026-05-31:

- `mcp__xcodebuildmcp__session_show_defaults` showed no configured project,
  workspace, scheme, or simulator defaults.
- `mcp__xcodebuildmcp__discover_projs` found 0 projects and 0 workspaces in
  `C:\CommenterIOS`.
- `Get-Command swift`, `xcodebuild`, `xcodegen`, and `tuist` found no local
  executable on PATH.
- Production dataset source raw SHA-256 was
  `60BAB50DA5E7735AF545D39C1DF73EFD96A533B2871B83571A042ABF52E404F7`.
- Bundled dataset was normalized to LF for repo line-ending policy; bundled
  SHA-256 was
  `438950A8A72DE0CE3B6B0E4271F95858D6519162C9F530A295E36722618B9572`.
- Node inspection verified normalized source text equals the bundled resource
  text and showed 56,564 components, 5 recipes, 4,340 assembled variants, and
  2 uniqueness rules.
- Re-ran XcodeBuildMCP discovery in `C:\CommenterIOS`; session defaults still
  had no project/workspace/scheme and discovery still found 0 projects and 0
  workspaces.
- `git diff --check` remained clean after dataset validation and subject mapping
  additions.
- Re-ran available hygiene checks after the import/export manifest dependency
  fix and persistence foundation additions: `git diff --check`,
  `git diff --cached --check`, untracked `git ls-files --eol --others
  --exclude-standard`, dataset copy verification, and local tool availability
  checks all completed with no whitespace/staged-diff issues; Swift/Xcode tools
  were still unavailable.
- Re-ran available checks after the generator/readiness/CSV/domain validation
  slices: `git diff --check`, `git diff --cached --check`, untracked
  `git ls-files --eol --others --exclude-standard`, local tool availability
  checks, XcodeBuildMCP `session_show_defaults` and `discover_projs`, and Node
  dataset copy verification. Hygiene and dataset verification passed;
  XcodeBuildMCP still found 0 projects/workspaces; Swift/Xcode tools remained
  unavailable.
- Re-ran available checks after CSV import validation/template additions and
  fingerprint normalization tightening: `git diff --check`,
  `git diff --cached --check`, untracked `git ls-files --eol --others
  --exclude-standard`, no-fake/mock source scan, local Swift/Xcode tool
  availability checks, and Node dataset copy verification. Hygiene and dataset
  verification passed; Swift/Xcode tools remained unavailable.
- `swift`, `xcodebuild`, `xcodegen`, and `tuist` remained unavailable on PATH,
  so Swift package tests and XcodeBuildMCP build/test could not be run locally.
- Re-ran XcodeBuildMCP after the manifest/status-copy guardrail pass:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults, and `discover_projs` still found 0 projects and 0 workspaces in
  `C:\CommenterIOS`.
- Re-ran import/export target dependency audit after the guardrail report:
  `CommenterImportExport` source imports `CommenterDomain`, `CommentEngine`,
  `CommenterPersistence`, and `Foundation`; `Package.swift` declares the three
  package target dependencies and `Foundation` needs no package dependency.
- Re-ran available hygiene checks after backup file workflow and raw backup
  validation tightening: `git diff --check`, `git diff --cached --check`,
  untracked `git ls-files --eol --others --exclude-standard`, local
  Swift/Xcode tool availability checks, no-fake/mock source scan, and Node
  dataset copy verification. Hygiene and dataset verification passed; the scan
  found no matches.
- `swift test` was attempted and failed because `swift` is not recognized in
  this Windows environment.
- Re-ran XcodeBuildMCP before the report export preparation slice:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults, and `discover_projs` still found 0 projects and 0 workspaces.
- Re-ran available checks after report export preparation helpers and tests:
  `git diff --check`, `git diff --cached --check`, untracked
  `git ls-files --eol --others --exclude-standard`, local Swift/Xcode tool
  availability checks, no-fake/mock source scan, and Node dataset copy
  verification. Hygiene and dataset verification passed; Swift/Xcode tools
  remained unavailable.
- `swift test` was attempted again after the report export preparation slice
  and failed because `swift` is not recognized in this Windows environment.
- Re-ran XcodeBuildMCP before the project import commit helper slice:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults, and `discover_projs` still found 0 projects and 0 workspaces.
- Re-ran available checks after pure project import commit helpers and tests:
  `git diff --check`, `git diff --cached --check`, untracked
  `git ls-files --eol --others --exclude-standard`, local Swift/Xcode tool
  availability checks, no-fake/mock source scan, and Node dataset copy
  verification. Hygiene and dataset verification passed; Swift/Xcode tools
  remained unavailable.
- `swift test` was attempted again after the import commit helper slice and
  failed because `swift` is not recognized in this Windows environment.
- Re-ran XcodeBuildMCP during the app-shell project storage slice:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults; `discover_projs` still found 0 projects and 0 workspaces in
  `C:\CommenterIOS`.
- Re-ran available checks after wiring the TCA project storage client and
  AppFeature reducer tests: `git diff --check`, `git diff --cached --check`,
  untracked `git ls-files --eol --others --exclude-standard`, local
  Swift/Xcode tool availability checks, no-fake/mock source scan, and Node
  dataset copy verification. Hygiene and dataset verification passed; Swift,
  xcodebuild, xcodegen, and tuist remained unavailable.
- `swift test` was attempted again after the AppFeature project storage slice
  and failed because `swift` is not recognized in this Windows environment.
- Re-ran XcodeBuildMCP during the XLSX review workbook preparation slice:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults; `discover_projs` still found 0 projects and 0 workspaces in
  `C:\CommenterIOS`.
- Re-ran available checks after adding the OOXML ZIP/XLSX review workbook
  helper and tests: `git diff --check`, `git diff --cached --check`,
  `git ls-files --eol --others --exclude-standard` filtered for CRLF/mixed
  worktree files, local Swift/Xcode tool availability checks, no-fake/mock
  source scan, and Node dataset copy verification. Hygiene and dataset
  verification passed; Swift, xcodebuild, xcodegen, and tuist remained
  unavailable.
- `swift test` was attempted again after the XLSX review workbook slice and
  failed because `swift` is not recognized in this Windows environment.
- Re-ran XcodeBuildMCP during the DOCX report document preparation slice:
  `session_show_defaults` still had no project, workspace, scheme, or simulator
  defaults; `discover_projs` still found 0 projects and 0 workspaces in
  `C:\CommenterIOS`.
- Re-ran available checks after adding the WordprocessingML DOCX report
  document helper and tests: `git diff --check`, `git diff --cached --check`,
  `git ls-files --eol --others --exclude-standard` filtered for CRLF/mixed
  worktree files, local Swift/Xcode tool availability checks, no-fake/mock
  source scan, and Node dataset copy verification. Hygiene and dataset
  verification passed; Swift, xcodebuild, xcodegen, and tuist remained
  unavailable.
- `swift test` was attempted again after the DOCX report document slice and
  failed because `swift` is not recognized in this Windows environment.
- Re-ran the manifest dependency guardrail after the monitor report:
  `BackupEnvelope.swift` imports `CommenterPersistence`, and the
  `CommenterImportExport` target in `Package.swift` declares
  `CommenterPersistence` alongside its other non-Foundation imports. Available
  hygiene checks passed: `git diff --check`, `git diff --cached --check`,
  untracked line-ending scan for CRLF/mixed files, targeted package import
  audit, no-fake/mock source scan, XcodeBuildMCP discovery, and Node dataset
  copy verification. `swift test` remained blocked because `swift` is not
  available on PATH.
- Re-ran available checks after the legacy XLS review workbook preparation
  slice: `git diff --check`, `git diff --cached --check`, untracked
  line-ending scan for CRLF/mixed files, no-fake/mock source scan, import
  dependency scan, XcodeBuildMCP defaults/discovery, local tool availability
  checks, and Node dataset copy verification. Hygiene and dataset verification
  passed; `swift test` still failed because `swift` is not available on PATH.
  The XLS slice has internal OLE/BIFF structure verification only; Excel,
  Numbers, LibreOffice, or other target-app open validation remains a release
  gap.
- Added `CommenterIOS.xcodeproj` with a shared `CommenterIOS` scheme and an
  iOS app target that hosts the local `AppFeature` package product. XcodeBuildMCP
  `discover_projs` now finds 1 project and 0 workspaces. XcodeBuildMCP
  `list_schemes` could not run because this Windows checkout has no
  `xcodebuild` executable (`spawn xcodebuild ENOENT`).
- Re-ran available checks after the Xcode app-host project and documentation
  updates: `git diff --check`, `git diff --cached --check`, untracked
  line-ending scan for CRLF/mixed files, stale no-Xcode-project wording scan,
  local tool availability checks, Node dataset copy verification,
  XcodeBuildMCP defaults/discovery/list-schemes, shared scheme XML parsing,
  `project.pbxproj` structural marker scan, and no-fake/mock source scan.
  Hygiene, stale-wording, dataset, scheme XML, and structural marker checks
  passed. `swift test`, `xcodebuild ... build`, and XcodeBuildMCP scheme
  listing/build validation remained blocked because `swift` and `xcodebuild`
  are not available on PATH in this Windows checkout.
- Re-ran available checks after the OSS/native workflow implementation pass:
  `git diff --check`, `git diff --cached --check`, `git ls-files --eol`,
  untracked line-ending scan for new Swift/test files, no-disabled-required-flow
  UI scan, no-direct-sqlite scan, OOXML ZIP custom-writer scan, and package API
  source checks for CodableCSV/CoreXLSX/OLEKit/ZIPFoundation. Hygiene and EOL
  checks passed. `swift package resolve`, `swift test`, and
  `xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination
  'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` remain
  blocked because `swift` and `xcodebuild` are not available on PATH in this
  Windows checkout.
- Re-ran QA/truthfulness evidence after the project-storage action guard pass
  and the concurrent import-preview source update:
  `git diff --check` and `git diff --cached --check` passed; `git ls-files
  --eol` showed tracked files as LF in the worktree, and
  `git ls-files --eol --others --exclude-standard` showed the untracked
  `Sources/CommenterImportExport/ImportPreviewPreparation.swift` as LF; direct
  SQLite scan `rg -n "import SQLite3|\bsqlite3\b|sqlite3_|sqlite_" Sources
  Tests Package.swift` returned no matches; direct ZIP-header scan found only
  test ZIP magic-number assertions and no production direct ZIP writer markers;
  the source network/privacy scan found no `URLSession`, Firebase, analytics,
  or telemetry usage in production sources. Package import verification found
  `GRDB`, `CodableCSV`, `CoreXLSX`, `OLEKit`, `ZIPFoundation`, and
  `ComposableArchitecture` imports only where matching `Package.swift` products
  are declared. `.build/checkouts` was not present, so package API source
  inspection was limited to manifest/import checks.
- Re-ran production dataset copy verification: raw CommenterV3 dataset SHA-256
  remained `60BAB50DA5E7735AF545D39C1DF73EFD96A533B2871B83571A042ABF52E404F7`;
  bundled LF-normalized dataset SHA-256 remained
  `438950A8A72DE0CE3B6B0E4271F95858D6519162C9F530A295E36722618B9572`; Node
  normalized-text comparison passed and reported 56,564 components, 5 recipes,
  4,340 assembled variants, and 2 uniqueness rules.
- `swift test` was attempted during the QA/truthfulness pass and failed because
  `swift` is not recognized in this Windows environment. The app-target
  `xcodebuild` command was also attempted and failed because `xcodebuild` is not
  recognized in this Windows environment.
- Re-ran final integration checks after the import-preview, generation, UI, and
  persistence code lanes were integrated: `git diff --check`,
  `git diff --cached --check`, full `git ls-files --eol`, untracked EOL scan,
  direct SQLite scan, direct ZIP-header scan, package/import consistency scan
  with Apple-native frameworks allowed, source network/privacy scan, Node
  production dataset normalized-text/hash comparison, XcodeBuildMCP
  `session_show_defaults`, `discover_projs`, and `list_schemes`. Hygiene,
  EOL, source scans, package/import consistency, dataset parity, and Xcode
  project discovery passed. XcodeBuildMCP found
  `C:\CommenterIOS\CommenterIOS.xcodeproj`; scheme listing failed with
  `spawn xcodebuild ENOENT`, matching the local `xcodebuild` blocker.
- Final direct command attempts remained blocked on Windows:
  `swift test` failed because `swift` is not recognized, and
  `xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
  failed because `xcodebuild` is not recognized.
- During the follow-up integration pass, `git diff --check`,
  `git diff --cached --check`, tracked CRLF/mixed EOL scan, and untracked EOL
  scan were re-run after the import-preview wording polish. Hygiene remained
  clean, and the new `ImportPreviewPreparation.swift` file remained LF. A direct
  `swift package resolve` attempt failed because `swift` is not recognized, and
  `swift test` continued to fail for the same reason.
- After the monitor course-correction, four code-owning lanes produced
  additional source/test changes: import/export privacy readback verification,
  Worklist pending-import/prepared-file state controls, stale prepared-file
  reducer cleanup, and CommenterV3 manual-edit readiness precedence. Scoped
  worker hygiene checks reported `git diff --check` clean for touched files;
  worker Swift test attempts remained blocked because `swift` is not available
  on PATH.
- Re-ran the final Windows-safe integration sweep after ledger updates:
  `git diff --check` and `git diff --cached --check` passed; tracked CRLF/mixed
  EOL scan returned no matches; untracked EOL scan showed
  `Sources/CommenterImportExport/ImportPreviewPreparation.swift` as LF; direct
  SQLite scan returned no matches; direct ZIP-header scan found only test
  assertions; package/import consistency scan passed with imports
  `AppFeature`, `CodableCSV`, `CommentEngine`, `CommenterDomain`,
  `CommenterImportExport`, `CommenterPersistence`, `ComposableArchitecture`,
  `CoreXLSX`, `DesignSystem`, `GRDB`, `OLEKit`, and `ZIPFoundation`;
  no `URLSession`, Firebase, analytics, remote-config, TODO/FIXME, fake-success,
  stateless, pretend, or decorative source hits were found. Dataset normalized
  text still matched live CommenterV3 with raw source SHA-256
  `60bab50da5e7735af545d39c1df73efd96a533b2871b83571a042abf52e404f7`, bundled
  SHA-256 `438950a8a72de0ce3b6b0e4271f95858d6519162c9f530a295e36722618b9572`,
  and counts `56564/5/4340/2`. XcodeBuildMCP defaults remained unset,
  discovery found `C:\CommenterIOS\CommenterIOS.xcodeproj`, and scheme listing
  failed with `spawn xcodebuild ENOENT`. Direct `swift package resolve`,
  `swift test`, and app-target `xcodebuild` attempts failed because `swift` and
  `xcodebuild` are not recognized on this Windows PATH.
- Re-ran Windows-safe checks after tightening backup JSON export cleanup:
  `git diff --check` and `git diff --cached --check` passed; tracked CRLF/mixed
  EOL scan returned no matches; untracked EOL scan still showed
  `ImportPreviewPreparation.swift` as LF; package/import consistency scan
  passed with `@testable import CommenterImportExport` included; direct SQLite
  scan returned no matches; direct ZIP-header scan found only test assertions;
  no production `URLSession`, Firebase, analytics, remote-config, TODO/FIXME,
  fake-success, stateless, pretend, or decorative source hits were found.
  Production dataset normalized text still matched live CommenterV3 with source
  raw SHA-256
  `60bab50da5e7735af545d39c1df73efd96a533b2871b83571a042abf52e404f7`, bundled
  SHA-256 `438950a8a72de0ce3b6b0e4271f95858d6519162c9f530a295e36722618b9572`,
  and counts `56564/5/4340/2`. XcodeBuildMCP defaults remained unset,
  discovery found `C:\CommenterIOS\CommenterIOS.xcodeproj`, and scheme listing
  still failed with `spawn xcodebuild ENOENT`. Direct `swift package resolve`,
  `swift test`, and app-target `xcodebuild` attempts still failed because
  `swift` and `xcodebuild` are not recognized on this Windows PATH.
- Re-ran checks after removing the stale unavailable import/export contract
  surface. `git diff --check` and `git diff --cached --check` passed; exact
  stale-contract scan for `FileWorkflowState`, `ImportPreview`,
  `SpreadsheetImporting`, `ReportExporting`, `UnavailableImportExporter`, and
  "not been ported yet" returned no matches; package/import consistency still
  passed; direct SQLite, production network/privacy, TODO/FIXME, fake-success,
  stateless, pretend, and decorative scans returned no matches. Dataset
  normalized text still matched live CommenterV3 with the same hashes and
  counts. Direct `swift package resolve`, `swift test`, and app-target
  `xcodebuild` attempts remained blocked because `swift` and `xcodebuild` are
  not recognized on this Windows PATH.
- Re-ran Windows-safe integration checks after the new subagent code slices:
  Support UI state wiring, import preview no-op blocking, recovery snapshot
  readback validation, V3 placeholder-order parity, and empty export-document
  hardening. `git diff --check` and `git diff --cached --check` passed; tracked
  CRLF/mixed EOL scan returned no matches; untracked EOL scan still showed
  `Sources/CommenterImportExport/ImportPreviewPreparation.swift` as LF;
  package/import consistency passed; stale unavailable import/export contract
  scan returned no matches; direct SQLite scan returned no matches; direct ZIP
  header scan found only test assertions; production network/privacy,
  TODO/FIXME, fake-success, stateless, pretend, and decorative scans returned
  no matches. Production dataset normalized text still matched live
  CommenterV3 with raw source SHA-256
  `60bab50da5e7735af545d39c1df73efd96a533b2871b83571a042abf52e404f7`, bundled
  SHA-256 `438950a8a72de0ce3b6b0e4271f95858d6519162c9f530a295e36722618b9572`,
  and counts `56564/5/4340/2`. XcodeBuildMCP defaults remained unset,
  discovery found `C:\CommenterIOS\CommenterIOS.xcodeproj`, and scheme listing
  still failed with `spawn xcodebuild ENOENT`. Direct `swift package resolve`,
  `swift test`, and app-target `xcodebuild` attempts still failed because
  `swift` and `xcodebuild` are not recognized on this Windows PATH.

- Re-ran validation in the patch container after the MVP completion pass:
  `swift package dump-package` succeeded; all Swift source and test files passed
  `swiftc -parse`; `git diff --no-index --check` against the original upload
  emitted no whitespace warnings; the privacy manifest parsed with
  `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1`; bundled dataset
  SHA-256 remained
  `438950a8a72de0ce3b6b0e4271f95858d6519162c9f530a295e36722618b9572` with
  56,564 components, 5 recipes, 4,340 assembled variants, and 2 uniqueness
  rules; direct SQLite/ZIP implementation scans returned no production matches;
  production source network/privacy scan found no `URLSession`, Firebase,
  analytics, telemetry, or remote-config calls beyond package URLs, plist DTD,
  and OOXML namespace strings. `swift package resolve` and `swift test
  --skip-build` could not resolve dependencies because the container cannot
  resolve `github.com`; the app-target `xcodebuild` command failed because
  `xcodebuild` is not installed in the container.

- Re-ran validation in the live Windows checkout after applying and hardening
  the MVP completion patch. `git apply --check
  C:\Users\jackg\Downloads\commenterios-mvp-completion.patch` passed before
  applying. `git diff --check` passed, `git ls-files --eol` showed tracked text
  files with LF working-tree endings, and the privacy manifest parsed with
  `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1`. XcodeBuildMCP
  discovered `C:\CommenterIOS\CommenterIOS.xcodeproj`, but simulator listing,
  scheme listing, simulator build, and simulator tests were blocked by missing
  Apple tools: `spawn xcrun ENOENT` or `spawn xcodebuild ENOENT`. Direct
  `swift package resolve` and `swift test` failed because `swift` is not
  recognized on this Windows PATH; direct app-target `xcodebuild` failed
  because `xcodebuild` is not recognized.
- GitHub Actions PR run `26717887504` passed `swift package resolve` and
  `swift test`, then failed the app-target `xcodebuild` step during
  `ComputeTargetDependencyGraph` because TCA package macros were not trusted in
  noninteractive Xcode. The CI app-target build command now includes
  `-skipPackagePluginValidation` and `-skipMacroValidation` so the real app
  compilation can run in Actions.
- GitHub Actions PR run `26718211590` on commit
  `c9f6f3cff5e08bb003c10cdb099ef11e14da087c` passed the full current CI job:
  `swift package resolve`, `swift test`, and the unsigned generic iOS Simulator
  app-target `xcodebuild` build with package plugin and macro validation
  skipped for noninteractive CI.
- Added a separate `iOS Screenshots` GitHub Actions workflow for real simulator
  screenshot evidence. The intended hosted command is `xcodebuild test -project
  CommenterIOS.xcodeproj -scheme CommenterIOS -destination <available iPhone
  simulator> -only-testing:CommenterIOSScreenshotTests/CommenterIOSScreenshotTests/testCoreAppPages
  -resultBundlePath build/CommenterIOSScreenshots.xcresult
  -skipPackagePluginValidation -skipMacroValidation ARCHS=arm64
  CODE_SIGNING_ALLOWED=NO` with `COMMENTER_SCREENSHOT_DIR` set to
  `build/screenshots`. The workflow verifies at least ten PNG files and uploads
  them with the `.xcresult` bundle. This live Windows checkout cannot execute
  the new workflow locally because `swift`, `xcodebuild`, and `xcrun` are not
  installed.

## Future Required Gates

Future required gates beyond current Swift package checks:

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
