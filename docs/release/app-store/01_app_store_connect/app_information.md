# App information

## Recommended fields

| Field | Recommended value | Notes |
| --- | --- | --- |
| App Store name | Report Comment Writer | 21 characters. Under Apple’s 30-character app name limit. |
| Home screen name | Report Writer | Already present in the Xcode build settings as `CFBundleDisplayName`. |
| Subtitle | For Australian teachers | 23 characters. Under Apple’s 30-character subtitle limit. |
| Bundle ID | `com.commenterios.app` | Found in the Xcode project. Change only if you also change the Xcode build setting. |
| SKU | `report-comment-writer-ios-001` | Internal only. Can be changed before app creation, not after. |
| Primary category | Education | Found in the Xcode project as `public.app-category.education`. |
| Secondary category | Leave blank | Keep the positioning simple. |
| Apple platforms | iPhone | The project currently targets device family `1`, which is iPhone. |
| Minimum iOS version | iOS 17.0 | Found in the Xcode project. |
| Version | `1.0` for public release | The repo currently says `0.1.0`; use `1.0` when ready for a public App Store launch. |
| Copyright | TODO: `2026 <owner name>` | Apple adds the copyright symbol. |
| Support URL | TODO | Required on the product page. |
| Privacy Policy URL | TODO | Required for all apps. |

## Positioning sentence

> Report Comment Writer helps Australian teachers turn class notes into clear student report comment drafts, with every comment checked by the teacher before export.

## Why this positioning

Australian reporting guidance uses plain language such as report comments, achievement, progress, strengths, areas for improvement, evidence, parent/carer, and teacher judgement. The App Store copy uses those words instead of tech words such as local-only, offline-first, deterministic generation, telemetry, or workflow automation.
