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
xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
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
