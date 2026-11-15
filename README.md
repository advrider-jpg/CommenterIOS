# CommenterIOS

CommenterIOS is the native iPhone version of the offline teacher report-writing app CommenterV3. Enter a class, record results and observations, generate suggested comment wording from the production comment bank, review it, and export the comments marked **Done**. Everything stays on the device: there is no account, cloud sync, analytics or remote AI.

## Teacher use

Projects, rosters, results, drafts and reports are saved locally and checked after each save, with recovery copies. Import class lists and results from CSV, XLSX or legacy XLS, using the matching templates the app provides. Export reports as DOCX, XLSX or XLS through the native iOS file and share sheets. Back up and restore a project as a plain JSON file or a password-protected `.cbackup` file.

Generated wording is deterministic: the same inputs give the same comment. Where Apple's on-device AI is available, it can suggest revisions or drafts, but the teacher previews and approves each one, and AI wording cannot be exported until it passes the app's checks and is approved. A damaged saved project is listed with options to copy its raw data for support or remove it while keeping its recovery copies.

## Development

The app is SwiftUI with The Composable Architecture, organized as local Swift packages for the domain, comment generation, persistence, import/export, report safety, AI and the design system. The production comment bank is copied from `C:\Commenterv3\client\public\data\comment-engine.json`; see [the dataset copy rule](docs/validation/DATASET_SOURCE_TRANSFORM.md).

Building and testing needs macOS with Xcode and an iOS simulator. A Windows host can run only Git and document hygiene checks and the dataset-copy check.

| Purpose | Command |
|---|---|
| Resolve packages | `swift package resolve` |
| Swift package tests | `swift test` |
| Build the iOS app | `xcodebuild -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` |
| Dataset copy matches CommenterV3 | `python scripts/validate_dataset_source_transform.py` |
| Whitespace and line endings | `git diff --check` and `git ls-files --eol` |

Pull requests run the same package tests and app build in [iOS CI](.github/workflows/ios-ci.yml).

## Documentation

- [AGENTS.md](AGENTS.md) and [PROJECT_RULES.md](PROJECT_RULES.md): operating and product rules.
- [Source truth map](docs/source-truth/commenterv3-source-map.md): which CommenterV3 files own each ported behavior.
- [OSS dependency policy](docs/OSS_DEPENDENCY_POLICY.md): approved packages and limits on custom infrastructure.
- [Production MVP plan](docs/PRODUCTION_MVP_PLAN.md): MVP scope and release gates.
- [iOS CI tools](docs/IOS_CI_SKILL_RECOMMENDATIONS.md): CI debugging tools and install commands.
- [Release](docs/release/): TestFlight and App Store material.
