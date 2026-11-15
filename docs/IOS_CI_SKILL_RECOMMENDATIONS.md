# iOS checking tools

These are the tools agents use for SwiftUI correctness and CI diagnosis on this project.

- **swiftui-specialist** — Best practices and idiomatic patterns for writing, reviewing and editing SwiftUI code.
  - Install: Vendored in this repository; no install needed.
- **swiftui-whats-new-27** — New SwiftUI APIs, behaviors and deprecations in the 2027 OS releases, for fixing SDK 27 build errors and warnings.
  - Install: Vendored in this repository; no install needed.
- **test-modernizer** — Modernizes test suites to use Swift Testing or migrates them from XCTest.
  - Install: Vendored in this repository; no install needed.
- **XcodeBuildMCP** — Builds, tests, runs and inspects iOS apps on simulators and devices, with logs, screenshots and UI automation.
  - Install:
    ```bash
    brew tap getsentry/xcodebuildmcp
    brew install xcodebuildmcp

    # Or:
    npm install -g xcodebuildmcp@latest

    # Then initialize its agent skills:
    xcodebuildmcp init
    ```
- **gh-fix-ci** — Inspects the failing GitHub Actions checks on a pull request, pulls the failing job logs and proposes a fix plan.
  - Install:
    ```bash
    # In Codex, install the official CI fixer:
    $skill-installer gh-fix-ci
    ```
