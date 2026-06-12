# Integration Notes

## Added

- App Store release package under `docs/release/app-store`.
- Root Fastlane metadata under `fastlane/metadata/en-AU`.
- Release package validation scripts.
- Draft support/privacy/terms HTML pages.
- Repo evidence and release risk notes.

## Copied From Package

Source package detected: `C:\Users\jackg\Downloads\report_comment_writer_release_package (1).zip`.

Copied release docs, icon assets, logo assets, social assets, screenshot
drafts, support-site drafts, and Fastlane metadata, then updated the
repo-specific evidence and copy.

## Generated Or Updated

- `INTEGRATION_NOTES.md`
- `MANIFEST.json`
- `scripts/validate_app_store_release_package.py`
- `05_assets/_generation_scripts/generate_release_assets.py`
- `05_assets/_generation_scripts/validate_release_assets.py`
- Central TODO list
- Root `fastlane/README.md`

## Wired Into Xcode

Installed the package app icon set into:

`Sources/CommenterIOSApp/Resources/Assets.xcassets/AppIcon.appiconset`

Installed the package accent colour set into:

`Sources/CommenterIOSApp/Resources/Assets.xcassets/AccentColor.colorset`

Previous app icon backup:

`Sources/CommenterIOSApp/Resources/Assets.xcassets/AppIcon.appiconset.pre-app-store-backup-20260612-114707`

The Xcode project already had:

- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
- `INFOPLIST_KEY_CFBundleDisplayName = "Report Writer"`
- `TARGETED_DEVICE_FAMILY = 1`

## Not Changed

- Bundle ID
- Team ID
- Signing
- Deployment target
- Product module/source names
- Package dependencies
- Privacy manifest content

The App Store name is metadata (`Report Comment Writer`); the shorter home screen
name is the on-device name (`Report Writer`).

## Remaining TODOs

See `08_after_you_add_contact_details/todo_placeholders_to_replace.txt`.

## Validation Steps Run

- `python scripts/validate_app_store_release_package.py` - passed; `plutil` skipped because unavailable.
- `python docs/release/app-store/05_assets/_generation_scripts/validate_release_assets.py` - passed.
- `git diff --check` - passed.
- `git ls-files --eol` - run for tracked file line-ending audit.

## Tests Not Run

- `plutil -lint Sources/CommenterIOSApp/Resources/PrivacyInfo.xcprivacy` - `plutil` unavailable in this environment.
- `xcodebuild -list -project CommenterIOS.xcodeproj` - `xcodebuild` unavailable in this environment.
- `swift package describe` - `swift` unavailable in this environment.
- `swift test` - `swift` unavailable in this environment.
- `xcodebuild -scheme CommenterIOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build` - `xcodebuild` unavailable in this environment.

## Validation Command To Re-run

Run:

`python scripts/validate_app_store_release_package.py`

Also run when available:

- `plutil -lint Sources/CommenterIOSApp/Resources/PrivacyInfo.xcprivacy`
- `xcodebuild -list -project CommenterIOS.xcodeproj`
- `swift package describe`
- `swift test`
- `xcodebuild -scheme CommenterIOS -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' build`

## Owner Next Steps

1. Replace TODO placeholders.
2. Host privacy/support pages.
3. Open Xcode and confirm the icon.
4. Capture final screenshots from the real app.
5. Re-check privacy against the final binary.
6. Submit metadata in App Store Connect.
