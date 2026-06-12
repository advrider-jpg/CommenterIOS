# Repo-Based Claims

| Claim | Repo evidence |
| --- | --- |
| iPhone-first | `TARGETED_DEVICE_FAMILY = 1` in `CommenterIOS.xcodeproj/project.pbxproj`; `docs/ledgers/CORE_RULES.md` says native iPhone-first SwiftUI/TCA app. |
| Education category | `INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education"` in the Xcode project. |
| Bundle ID | `PRODUCT_BUNDLE_IDENTIFIER = com.commenterios.app` in the app target. |
| Version number | `MARKETING_VERSION = 1.0.0`; `CURRENT_PROJECT_VERSION = 1`. |
| Display name | `INFOPLIST_KEY_CFBundleDisplayName = "Report Writer"`. |
| Supported year levels | `ProjectYearLevel` has Year 5, Year 6, and Mixed; `StudentYearLevel` has Year 5 and Year 6. |
| Supported learning areas | `SubjectDisplay.swift` exposes English, Mathematics, Science, HASS, Health and Physical Education, The Arts, and Technologies. The bundled dataset has specific Arts and Technologies strands. |
| Achievement levels | `AchievementLevel` has Beginning, Developing, At Standard, and Above Standard. |
| Import formats | `ImportExportFormat` has CSV, XLSX, XLS, DOCX, and backup JSON; `SpreadsheetImportFile` parses CSV/XLSX/XLS. |
| Export formats | `ReportDocumentFile`, `ReviewWorkbookFile`, and `BackupFileWorkflow` prepare DOCX, XLSX/XLS, and backup JSON outputs. |
| Backup/restore | `BackupEnvelope`, `BackupFileWorkflow`, and reducer tests cover backup import/export paths. |
| No account system | Repo scan found no configured account/login code; MVP docs list accounts as a non-goal. |
| No cloud sync | MVP docs list cloud sync as a non-goal; repo scan found no CloudKit/Firebase sync. |
| No analytics/tracking/ads | Privacy manifest declares no tracking and no collected data; repo scan found no configured analytics, tracking, or ads SDK. |
| No IAP/subscriptions | MVP docs list subscriptions/paywalls as non-goals; repo scan found no StoreKit purchase flow. |
| No remote AI/backend | Core rules prohibit remote AI/backend persistence; repo scan found no production URLSession/OpenAI/Gemini/Claude path. |
| Privacy manifest | `Sources/CommenterIOSApp/Resources/PrivacyInfo.xcprivacy` exists and declares no collected data. |
| Local storage | `ProjectStore.swift` writes local project files with atomic replacement, readback, fingerprints, and recovery snapshots. |
| Teacher review/checking | Report review state and export preparation require export-ready/approved report text before export. |

## Public Copy Decisions

Teacher-facing copy claims CSV, XLSX, XLS, DOCX, backup JSON, Year 5/6,
teacher checking, no sign-in, no online account, and no upload to an
online account because those are supported by current repo evidence and
core rules.

Do not claim Languages support, Australian Curriculum alignment, school
approval, department approval, or universal compliance.
