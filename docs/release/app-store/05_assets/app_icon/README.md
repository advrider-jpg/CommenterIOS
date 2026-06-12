# App icon assets

This folder contains a generated iOS app icon set for Report Comment Writer.

## Files

- `report-comment-writer-icon-1024.png`: marketing icon master.
- `AppIcon.appiconset/`: Xcode asset catalog app icon set.
- `AccentColor.colorset/`: Xcode accent colour based on the app’s action blue.

## How to use in Xcode

The uploaded repo did not include an asset catalog. To use these assets:

1. Add an asset catalog to the app target, for example `Assets.xcassets`.
2. Copy `AppIcon.appiconset` into the asset catalog.
3. Copy `AccentColor.colorset` into the asset catalog.
4. Set the app target’s App Icons Source to `AppIcon`.
5. Keep the app display name as `Report Writer` unless you decide otherwise.

## Design note

The icon intentionally avoids text. It uses a report page, comment bubble and checkmark to communicate report comments and teacher review.
