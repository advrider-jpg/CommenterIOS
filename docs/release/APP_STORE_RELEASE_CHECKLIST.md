# App Store Release Checklist

This checklist records the non-code release gates that must be completed outside the source repository before public App Store submission.

## Required Apple configuration

- Set the final Apple Developer Team ID in the `CommenterIOS` app target.
- Confirm the final bundle identifier in Xcode and App Store Connect.
- Set `REPORT_WRITER_PRIVACY_POLICY_URL` to the public HTTPS privacy-policy URL before archiving.
- Archive a Release build for `generic/platform=iOS` with code signing enabled.
- Export the archive using App Store distribution options.
- Upload to App Store Connect or TestFlight and resolve all validation warnings.
- Generate and inspect Xcode’s privacy report for the app archive.

## Required App Store Connect metadata

- App name, subtitle, category, age rating, description, keywords, support URL, and privacy-policy URL.
- Screenshots for every required device class.
- App privacy answers that match the shipped build and all included third-party SDKs.
- Review notes explaining that project, roster, result, draft, backup, diagnostic, and export data are local by default; native share/export destinations are user selected; and AI features use Apple on-device availability gates.

## Device acceptance testing

Run these on a clean physical device and at least one simulator before public release:

- First launch with no prior data.
- Create, save, close, reopen, and delete a project.
- Import roster CSV/XLSX/XLS, including malformed and oversized files.
- Import results CSV/XLSX/XLS, including malformed and oversized files.
- Export backup JSON and encrypted backup JSON, then restore them.
- Export DOCX, XLSX, and XLS reports and open them in the target office apps.
- Cancel native export/share and verify temporary prepared files are removed.
- Copy redacted diagnostics and verify student/project names are not present.
- Exercise AI unavailable, AI available, AI timeout, and oversized AI prompt paths.
- Run VoiceOver and Dynamic Type checks on project, import, export, AI review, and support screens.

## App Store release package

- [Release package README](app-store/README.md)
- [App Store copy](app-store/01_app_store_connect/app_store_copy_paste.md)
- [App Privacy answers](app-store/01_app_store_connect/app_privacy_answers.md)
- [App Review notes](app-store/01_app_store_connect/app_review_notes.md)
- [Privacy policy draft](app-store/02_legal_and_privacy/privacy_policy_draft.md)
- [Brand guide](app-store/03_brand_and_marketing/brand_guide.md)
- [Screenshot plan](app-store/04_screenshots/screenshot_plan.md)
- [TODO placeholders](app-store/08_after_you_add_contact_details/todo_placeholders_to_replace.txt)
