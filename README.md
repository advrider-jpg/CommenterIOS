# CommenterIOS

CommenterIOS is the native iPhone version of the offline teacher report-writing app CommenterV3. Enter a class, record results and observations, generate suggested comment wording from the production comment bank, review it, and export the comments marked **Done**. Everything stays on the device: there is no account, cloud sync, analytics or remote AI.

## Teacher use

Projects, rosters, results, drafts and reports are saved locally and checked after each save, with recovery copies. Import class lists and results from CSV, XLSX or legacy XLS, using the matching templates the app provides. Export reports as DOCX, XLSX or XLS through the native iOS file and share sheets. Back up and restore a project as a plain JSON file or a password-protected `.cbackup` file.

Generated wording is deterministic: the same inputs give the same comment. The earlier AI features have been removed; AI is rebuilt in the parity phase (see `PROJECT_RULES.md`). Support shows whether Apple Intelligence is available on the iPhone. A damaged saved project is listed with options to copy its raw data for support or remove it while keeping its recovery copies.

## Development

The app is SwiftUI with The Composable Architecture, organized as local Swift packages for the domain, comment generation, persistence, import/export, the AI availability scaffold and the design system. The production comment bank is copied from `C:\Commenterv3\client\public\data\comment-engine.json`; see [the dataset copy rule](docs/validation/DATASET_SOURCE_TRANSFORM.md).

Building and testing needs macOS with Xcode 27 and an iOS 27 simulator. A Windows host can run only Git and document hygiene checks and the dataset-copy check.

| Purpose | Command |
|---|---|
| Resolve packages | `swift package resolve` |
| Unit tests on the iPhone simulator | From a folder holding only copies of `Package.swift`, `Package.resolved`, `Sources` and `Tests` (xcodebuild otherwise picks the app project): `xcodebuild test -scheme CommenterIOS-Package -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` |
| Build the iOS app | `xcodebuild build -project CommenterIOS.xcodeproj -scheme CommenterIOS -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` |
| Dataset copy matches CommenterV3 | `python scripts/validate_dataset_source_transform.py` |
| Whitespace and line endings | `git diff --check` and `git ls-files --eol` |

Pull requests run the same unit tests, app build and screenshot walk-through on GitHub's Xcode 27 machine in [iOS CI](.github/workflows/ios-ci.yml).

## Documentation

- [AGENTS.md](AGENTS.md) and [PROJECT_RULES.md](PROJECT_RULES.md): operating and product rules.
- [Source truth map](docs/source-truth/commenterv3-source-map.md): which CommenterV3 files own each ported behavior.
- [OSS dependency policy](docs/OSS_DEPENDENCY_POLICY.md): approved packages and limits on custom infrastructure.
- [iOS CI tools](docs/IOS_CI_SKILL_RECOMMENDATIONS.md): CI debugging tools and install commands.
- [Release](docs/release/): TestFlight and App Store material.
