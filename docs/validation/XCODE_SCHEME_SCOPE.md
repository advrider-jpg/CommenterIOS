# Xcode Scheme Test Scope

`CommenterIOS.xcodeproj/xcshareddata/xcschemes/CommenterIOS.xcscheme`
intentionally contains the app target and the
`CommenterIOSScreenshotTests` UI test bundle. It is not the source of truth for
Swift package unit, reducer, import/export, persistence, or generation tests.

CI must keep these gates separate:

- `swift test` runs the Swift package test targets declared in `Package.swift`.
- `xcodebuild build` proves the native iOS app target compiles.
- `xcodebuild test ... -only-testing:CommenterIOSScreenshotTests/...` captures
  the real SwiftUI core-flow screenshot evidence through the shared Xcode
  scheme.

Run `python scripts/validate_xcode_scheme_scope.py` after editing the shared
scheme or screenshot workflows. It verifies that the scheme's `TestAction` stays
UI-screenshot scoped, that `ios-ci.yml` still runs `swift test`, and that both
screenshot workflows use the shared required-screenshot extraction script.
