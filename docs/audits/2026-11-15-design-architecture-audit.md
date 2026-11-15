# CommenterIOS design, architecture and feature audit — 15 November 2026

Read-only review of the whole iPhone app (about 25,000 lines of app code and 10,700 lines of tests) by four
Opus 5.5 reviewers, one per area, with every high-impact claim re-checked against the code by the lead
reviewer. Nothing was built or run: this machine has no Xcode. Items marked "needs a Mac check" are readings of
the code that a simulator run must confirm.

Words used in this report:
- **web app** — CommenterV3, the product this iPhone app ports.
- **comment** — the generated text for one student in one subject (the app's "draft").
- **wording file** — the 20 MB bank of comment wording bundled inside the app.
- **report file** — an exported DOCX, XLSX or XLS file.
- **backup** — a plain JSON backup or a password-protected `.cbackup`.
- **automated checks** — the build-and-test run on GitHub after every change.
- "For the fixer" lines carry file references for whoever does the work.

## The answer in one page

**What is good and should stay.** The app keeps its core promises: it is offline, it never shows success
without a real completed operation, it refuses unresolved placeholders, and AI text cannot be exported until the
teacher approves it. Screens never touch files directly. Backup encryption is the right design. Imports show a
preview and commit all-or-nothing. Those parts are careful work.

**What is wrong, in four sentences.**
1. **It is out of date.** It still targets iOS 17, Swift 5.10 and an Xcode 15-era project, its core framework
   is nine versions behind, and the automated checks have failed since 8 August.
2. **It has drifted from the web app.** Since the port, the web app has rebuilt comment generation four times
   (most recently this morning), changed the backup format (so backups no longer move between the two apps in
   either direction), and changed how report files are exported.
3. **The screens break the project's own rules and Apple's patterns.** One giant feature drives every screen.
   Three home-made component kits copy what SwiftUI already provides. The design will likely be unreadable in
   Dark Mode. There is no autosave, and deletions happen without asking.
4. **Generic file code was written by hand when maintained packages exist.** The DOCX writer, XLSX writer, XLS
   reader, CSV pre-parsers and password key derivation are all hand-made, and the hand-made XLS reader cannot
   read ordinary Excel files.

**Should it be patched or rebuilt?** Keep and repair the data model, saving, import validation, backup
encryption, the safety rules and the test intentions. Re-port comment generation, backups and export from the
current web app rather than patching the June copy; most comment-engine defects disappear with that. Rebuild
the screen layer on native SwiftUI and a proper feature tree; patching 11,000 lines of the current structure
would cost about as much and leave the structural problems in place.

**Count.** 93 findings from the four reviewers, merged here into 62 issues, plus issue 63 added after your
15 November AI decision: 63 issues in all — 7 critical, 22 high, 21 medium, 13 low.

## Decisions only you can make

These gate the work. My recommendation is first in each.

| # | Decision | Recommendation | Why it matters |
|---|---|---|---|
| D1 | Re-port the iPhone app to the web app's new comment generation (Australian Curriculum text and sentence frames, levels A–E, Years 5–7, merged 15 Nov) before release? | **Yes, now.** | It replaces the wording file, generation rules and parts of the data model. Fixing the old engine first is wasted work. |
| D2 | The web app's change of 15 Nov records "No AI in the app". The iPhone app's decision of 5 June allows on-device AI. Which stands for iPhone? | **Decided 15 Nov: the iPhone app is fully AI-enabled, using Apple's on-device models only** — a deliberate difference from the web app. | Issues 39, 47–50 and 63 are in scope, and issue 49 (pinning the AI to the on-device model) becomes a hard rule. |
| D3 | Does "No migrations: the app is pre-production" apply to the iPhone app too? | **Yes.** | Lets old backup versions, legacy fields and compatibility code be deleted outright (issues 24, 25, 30). |
| D4 | Must backups move between the web app and the iPhone app? | **Yes.** | It is the main reason a backup exists in a port. If not, the JavaScript-exact JSON and fingerprint code can go entirely. |
| D5 | Keep exporting legacy `.xls` report files? (A core rule currently requires it.) | **Keep reading `.xls` (via a package), stop writing it**; export `.xlsx` and `.csv`. | `.xls` writing is 460 hand-written lines with no package to replace it and no proof Excel opens the files. |
| D6 | Recovery copies: offer a restore screen, or drop them? | **Drop them.** "Delete Project" then erases everything, and teachers rely on their backups. | Today the copies are kept but can never be restored, and deleted student data stays on the phone. |
| D7 | Saving: one JSON file per project, or move everything to the GRDB database? | **One JSON file per project; remove GRDB.** | The database is written on every save and never read. |
| D8 | Autosave instead of a Save button (as the web app does)? | **Yes.** | Edits are lost if iOS closes the app, and mistakes cannot be undone. |
| D9 | Dark Mode: should the paper look stay light, or get a dark version? | **System menus and bars follow Dark Mode; the paper report area stays light.** | Today the app will likely show white text on cream paper. |
| D10 | Allow Apple's built-in Writing Tools (Rewrite, Proofread) in the comment editor? | **Turn them off in comment fields, and provide the same help through the app's own on-device AI.** | Today they can rewrite a comment, which is then exported as if the teacher had typed it. Apple can also send some Writing Tools requests to its cloud servers, which breaks the on-device-only rule. |
| D11 | Merge "Mark Done", "Approve AI draft" and "Mark Warnings Reviewed" into one Done button? | **Yes.** | Three confirmations for one job. |
| D12 | Which other web-app features belong in the iPhone first release: past reporting periods, custom comment library, teacher profile/settings, planner? | **Follow whatever the web app treats as core after D1;** export by scope and grouping is required regardless (issue 9). | Sets the size of the rebuild. |
| D13 | Release pipeline: Xcode Cloud, or keep a GitHub release workflow? | **Xcode Cloud.** It handles signing and TestFlight, with 25 free hours a month. | Decides whether the release workflow, signing secrets and Fastlane folders survive. |
| D14 | How much of the ledger and handoff documentation should agents keep reading and maintaining? | **Decided 15 Nov: ledgers deleted.** Product rules live only in `PROJECT_RULES.md`; working rules in `AGENTS.md`. | The rest of the stale documentation is issue 57. |
| D15 | Mac access. | **The new Xcode 27 GitHub machine handles builds and tests, so start without one. Rent a Mac (about US$149 a month) only for the on-screen and iPhone checks before release.** | Every "needs a Mac check" item. |

## Order of work

1. **Phase 1 — Get back to green (no decisions needed, about 3–5 days).** Issues 1–5, 46, 49 and 59: dependency and toolchain update on the Xcode 27 GitHub machine; fix
   the 25 failing tests; protect main; fix the privacy-policy link, the CSV blank-line bug and the XLSX
   template failure.
2. **Phase 2 — Re-port from the web app (after D1–D4).** Issues 6–15, 24, 26–28, 30 and 62: comment
   generation, backups, export, autosave, confirmations; plus the AI feature plan (issue 63).
3. **Phase 3 — Rebuild the screens on native SwiftUI and a TCA feature tree (after D8–D12).** Issues 16–21,
   25, 39–45, 47, 48, 50 and 63 (building the AI features).
4. **Phase 4 — Replace hand-written file code with packages (after D5–D7).** Issues 22, 23, 29, 31–38 and
   61.
5. **Phase 5 — Tests, release and documentation.** Issues 51–58 and 60.

---

# Issues

Severity is shown in brackets. Each issue lists effort as S (under a day), M (1–3 days) or L (over 3 days).

## A. Out of date — first on the list

**Issue 1: The app's packages are far behind their current versions [Critical]**

- **What's wrong:** Every package is pinned to an exact older version, and three are no longer maintained by their authors. The app's core framework, The Composable Architecture (TCA), is nine releases behind, and the version in use predates its fix for Xcode 27. So the app cannot be assumed to build with current Apple tools.
- **Current example:**

  | Package | In use | Latest |
  |---|---|---|
  | The Composable Architecture | 1.17.0 | 1.26.2 |
  | GRDB (database) | 7.10.0 | 7.12.0 |
  | ZIPFoundation | 0.9.11 | 0.9.20 (includes a security fix) |
  | GitHub check steps (checkout, upload) | v4 | v7 |
  | CSV, XLSX and XLS readers | 0.6.7 / 0.14.1 / 0.2.0 | no newer release; authors stopped work in 2021–2023 |

- **Proposed fix:** Update TCA, GRDB and ZIPFoundation in one change, and migrate TCA's retired screen pattern at the same time. Switch from exact pins to version ranges, with the existing lock file still enforced by the automated checks. Add Dependabot so updates arrive as pull requests. The three abandoned readers are replaced in issues 24, 27 and 28, not just bumped.
- **New example:** TCA 1.26.2, GRDB 7.12.0 (or removed under D7), ZIPFoundation 0.9.20, check steps v7, with Dependabot proposing future updates automatically.
- **Advantages:** Builds on Xcode 27, picks up the security and memory fixes, and future updates are no longer forgotten.
- **Disadvantages:** The TCA update touches the main screen file. That is mechanical, but it needs the automated checks green to prove it.
- **Recommendation:** Do this first, together with issue 2.
- For the fixer: `Package.swift:27-32`; TCA migration notes at the 1.24 and 1.25 releases; `AppView.swift:29` `WithViewStore`; 8 `-> Effect<Action>` helpers.

**Issue 2: The project settings still target iOS 17, Swift 5.10 and an Xcode 15-era project [Critical]**

- **What's wrong:** You decided on 8 August to move to iOS 27 minimum, iPhone only, Swift 6 and Xcode 27. Nothing in the project reflects that, and until 15 November the decision was recorded nowhere (it is now in `PROJECT_RULES.md`). The automated checks run on an old macOS machine with Xcode 16.4, which cannot even compile the on-device AI code, so that code has never been compiled by anyone.
- **Current example:** iOS 17.0 minimum; Swift 5.10; Xcode project last upgraded by Xcode 15.4; automated checks on `macos-15` (Xcode 16.4); the package also claims to be a Mac app.
- **Proposed fix:** iOS 27 minimum, iPhone only, Swift 6 language mode with full concurrency checking, project upgraded in Xcode 27, checks moved to GitHub's Xcode 27 machine (generally available since 15 October), Mac platform removed. Record the 8 August decision.
- **New example:** iOS 27.0 minimum; Swift 6; Xcode 27.1; automated checks on `xcode-27`; iPhone only.
- **Advantages:** Matches your decision. Every later fix is built and tested on the real target, without owning a Mac.
- **Disadvantages:** Swift 6's stricter checking may surface a batch of compile errors that only show up once built. Expect 1–3 days.
- **Recommendation:** Do it with issue 1.
- For the fixer: `Package.swift:1,9-10`; `project.pbxproj` deployment target and `SWIFT_VERSION`; `ios-ci.yml` `runs-on`; remove the `#if canImport(FoundationModels)` and `@available(iOS 26…)` gates.

**Issue 3: Main has failed its automated checks since 8 August, and nothing stops a merge on failure [Critical]**

- **What's wrong:** 25 tests fail (CI said "31" because it counts failed assertions, not tests). The August change was merged 10 seconds after its pull request opened. Main has no branch protection, so any change can be merged before or despite failing checks.
- **Current example:** 22 failing tests are out of date: the product changed on purpose (the new "mark it Done" rule, a stale-check order change, an extra "very short" warning) and the tests were never updated. 1 is a real bug (issue 5). 2 expose the broken XLSX template download (issue 4).
- **Proposed fix:** Update the 22 out-of-date tests (mostly by marking their sample comments Done). Fix issues 4 and 5. Then require "Swift package tests" and "Build iOS app target" to pass before anything can merge into main.
- **New example:** 356 of 356 tests pass, and the merge button stays disabled until they do.
- **Advantages:** Breakage becomes visible again, and what happened in August cannot recur.
- **Disadvantages:** Each test run takes 8–20 minutes on GitHub.
- **Recommendation:** Do this in Phase 1.
- For the fixer: failure classification table in the build reviewer's notes; give the three `readyReport` helpers `reviewedAt`; protect main with a ruleset.

**Issue 4: XLSX template download fails every time, and XLSX report export is unproven [High]**

- **What's wrong:** In August the check that verifies a written XLSX file was rewritten to be much stricter, and it now rejects the app's own class-list template. A teacher who taps "XLSX template" gets a failure. The same check guards XLSX report export, and no passing test has exercised it since. The real error is thrown away and replaced with a generic one, so the cause cannot be seen from the log.
- **Current example:** Teacher taps "Download class list template (XLSX)" and sees: "The template could not be verified."
- **Proposed fix:** Keep the underlying error instead of discarding it. Reproduce on the Xcode 27 GitHub machine, then fix the writer or the check. This becomes moot once issue 23 replaces the hand-made XLSX writer.
- **New example:** The template downloads and opens.
- **Advantages:** Restores a required format.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Do this in Phase 1.
- For the fixer: `ReviewWorkbookFile.swift:150-221`; `CSVTemplates.swift:313-320`.

**Issue 5: A CSV that ends in a blank line is reported as "malformed" [Medium]**

- **What's wrong:** Excel and Numbers often end a CSV file with an empty line. Since August the app reports such a file as broken instead of reading it, or saying it has no data rows.
- **Current example:** A class list saved from Numbers with a trailing blank line shows: "The CSV file is malformed and could not be read."
- **Proposed fix:** Drop empty lines before parsing.
- **New example:** The class list imports normally.
- **Advantages:** One of the most common import cases works again.
- **Disadvantages:** None.
- **Recommendation:** Do this in Phase 1.
- For the fixer: `CSVParser.swift:86-110`.

## B. Drift from the web app

**Issue 6: The comment engine and wording file are a retired copy of the web app's [Critical]**

- **What's wrong:** The bundled wording file is byte-for-byte the web app's file of 31 May. Since then the web app has replaced it four times:
  - 12 October: removed the "recipes", pre-built variants and repetition rules.
  - 11 and 14 November: further rebuilds.
  - This morning (15 November): comments are built from Australian Curriculum v9 text and sentence frames, with achievement levels A–E and Years 5–7.

  The changes were made because the old bank produced contradictory and repetitive comments. The iPhone app still uses it, and its own wording-file check now fails.
- **Current example:** iPhone app: levels Beginning / Developing / At Standard / Above Standard; Years 5–6; 56,564 wording rows plus 4,340 pre-built variants. Web app today: levels A–E; Years 5–7; 1,927 curriculum items and 1,101 sentence frames.
- **Proposed fix:** Re-port generation, the wording file and the affected data-model fields from the web app as it is today. Delete the recipe renderer, pre-built variants and repetition-rule code. Add an automated check that the bundled wording file matches a pinned web-app version.
- **New example:** An iPhone comment for the same student matches the web app's comment word for word.
- **Advantages:** Teachers get the wording you already chose for the product. Issues 10–12 and parts of 13, 26 and 31 disappear.
- **Disadvantages:** The largest single piece of work in this report (L, roughly 1–2 weeks). The web app is still changing fast, so the port has to be pinned to a version.
- **Recommendation:** Decision D1. Re-port now.
- For the fixer: web-app files `generator.ts`, `comment-coherence.ts`, `student-agreement.ts`, `comment-engine-contract.ts`, `achievement-domain.ts`, `client/src/data/curriculum.json` at web commit 446758b.

**Issue 7: Backups no longer move between the web app and the iPhone app, in either direction [Critical]**

- **What's wrong:** On 27 September the web app stopped writing checksums in backups, and its backup reader became strict about which fields are allowed. The iPhone app still demands a checksum, so it rejects every current web backup. The web app rejects every iPhone backup, because of the extra checksum field and three missing lists. The iPhone tests still pass because they use hand-made "web" samples in the old format.
- **Current example:** A teacher exports a backup from the web app and opens it on the iPhone: "This backup could not be opened. Choose a backup created by this app."
- **Proposed fix:** Re-port the backup format from the web app as it is today, and accept exactly the versions it accepts. Replace the hand-made samples with real backups exported from the web app, plain and encrypted.
- **New example:** The same backup opens on the iPhone and shows the class.
- **Advantages:** Restores the main purpose of backups in a port. About 80 lines of checksum code are deleted.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix in Phase 2 (decision D4).
- For the fixer: `BackupEnvelope.swift:40-141, 303-315, 458-633`; web-app `backup.ts`, `persisted-schemas.ts`.

**Issue 8: About 45% of password-protected backups will fail between the apps even after issue 7 [High]**

- **What's wrong:** Part of the encrypted backup is a small piece of text that both apps must produce identically. The iPhone app's tool writes the slash character as `\/`; the web app writes `/`. The random values in that text contain a slash about 45% of the time. When they do, the other app says the password is wrong.
- **Current example:** Correct password typed, and the app shows "Check the password and try again."
- **Proposed fix:** Build that text with the standard encoder set not to escape slashes. Test with values that contain `/` and `+`.
- **New example:** The backup opens.
- **Advantages:** A misleading "wrong password" error goes away.
- **Disadvantages:** None.
- **Recommendation:** Fix with issue 7.
- For the fixer: `BackupEnvelope.swift:718-772`.

**Issue 9: Export is blocked until every comment in the class is ready, and the web app's export options are missing [High]**

- **What's wrong:** One unfinished comment blocks every report file for the whole class. The web app exports the Done comments for a chosen scope and lists what it skipped. The iPhone app also differs from the web app's export in these ways:
  - no grouping by subject;
  - no single-subject export;
  - no cover line;
  - US Letter paper instead of A4;
  - a different spreadsheet column set;
  - line breaks inside a comment collapse into spaces in Word.
- **Current example:** A teacher has finished English for all 28 students but not Maths, and "Prepare DOCX Reports" refuses.
- **Proposed fix:** Re-port the web app's export planning: scope, grouping, Done-only output and a skipped-items list. Use A4 and the web app's columns. Only Done (or approved) text is ever exported, as now.
- **New example:** Export → Subject: English → Group by student → 28 comments exported, 0 skipped.
- **Advantages:** Teachers can hand in reports subject by subject, the way they actually work.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix in Phase 2.
- For the fixer: `ReportExportPreparation.swift:247-307`; `FileWorkflowFeature.swift:384-389`; web-app `export.ts`, `report-docx.ts`.

**Issue 10: English and Maths sentences call every student "they" [High]**

- **What's wrong:** Several sentences hard-code "they" whatever the student's pronouns. A test asserts the wrong text, and both safety checks were loosened to allow "they" for everyone, so nothing catches it. The web app never had this; it was introduced in the port.
- **Current example:** "Ava writes clearly in English. In Inferencing, **they** demonstrate solid understanding."
- **Proposed fix:** Use the pronoun tokens as the web app does, and fix the test and the two checks.
- **New example:** "Ava writes clearly in English. In Inferencing, **she** demonstrates solid understanding."
- **Advantages:** Reports going home to families read correctly.
- **Disadvantages:** None.
- **Recommendation:** Do it as a one-day fix only if D1 is delayed; otherwise the re-port (issue 6) replaces these sentences.
- For the fixer: `ReportTextLibraries.swift:88-110`; `ReportGeneratorTests.swift:190,277`; `ReportSafetyValidator.swift:202-205`.

**Issue 11: Ordinary learning contexts like "Group work" are rejected as sentences, which blocks the project [High]**

- **What's wrong:** A hand-made word list decides whether a learning context is "a sentence", and it contains words like "work" and "write". "Group work", "Pair work" and "Independent work" are therefore rejected. Comments cannot be created for that student. The same check runs when a project is saved, restored or exported, so a project containing one of these phrases cannot be saved at all. The web app solved exactly this case with a language library.
- **Current example:** Learning context: "Group work". The app shows: "must be a short phrase, not a sentence", and the Save button fails.
- **Proposed fix:** Use Apple's built-in language analyser (NaturalLanguage) to check for a real verb, in one place. Saving should check only length and placeholders.
- **New example:** "Group work" is accepted, and the comment reads "…during group work."
- **Advantages:** Removes a hard block on everyday input.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Fix in Phase 2. Check whether the re-port already covers it.
- For the fixer: `ProjectValidation.swift:6-7,133-164`; `ReportInputFeedback.swift:26`; web-app `report-context-fields.ts:39-41`.

**Issue 12: The safety check blocks correct comments [High]**

- **What's wrong:** The check that guards AI and safety-reviewed text has three false alarms:
  - **Shared first names.** If two students share a first name, every comment for either of them is blocked as "mentions another student".
  - **The word "student".** Any comment containing the ordinary word "student" is blocked as a placeholder.
  - **Sensitive words.** Words like "family" and "religion" are blocked unless they appear in the teacher's notes.
- **Current example:** Two students named Ava. Each Ava's comment shows: "This comment appears to mention another student."
- **Proposed fix:** Ignore names the student shares with a classmate. Match only the exact fallback placeholder. Make the sensitive words warnings rather than blocks.
- **New example:** Both comments pass.
- **Advantages:** Teachers are not stuck editing out normal words.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 2. This check guards every AI result, so with a fully AI-enabled app its false alarms would hit teachers constantly.
- For the fixer: `ReportSafetyValidator.swift:159-191,333-336`.

**Issue 13: No autosave, and unsaved changes cannot be discarded [High]**

- **What's wrong:** Edits live only in memory until the teacher taps Save. If iOS closes the app in the background, the work is gone. Every other action is blocked until the teacher saves, and there is no "Discard changes", so a mistake (see issue 14) has to be saved. The web app autosaves.
- **Current example:** The teacher types results for 10 students, switches to Mail, and iOS closes the app. All 10 are lost.
- **Proposed fix:** Save automatically shortly after each change and when the app goes to the background. Show "Saved" the way the web app does. Add "Revert to last saved".
- **New example:** The screen shows "All changes saved"; reopening shows all 10 results.
- **Advantages:** No lost work, and no forced saving of mistakes.
- **Disadvantages:** None worth mentioning.
- **Recommendation:** Decision D8. Adopt it.
- For the fixer: `ProjectStateHelpers.swift:12-24`; `ProjectWorkflowFeature.swift:96-173`; web-app `ProjectDetail.tsx:253-264`.

**Issue 14: Deleting a student, turning off a subject or "Deselect all" wipes data without asking [High]**

- **What's wrong:** One tap removes results, notes and edited comments, with no confirmation and no undo. The web app asks first. A test makes the silent wipe the required behaviour.
- **Current example:** The teacher toggles off Science by mistake, and 28 results and 28 edited comments disappear instantly.
- **Proposed fix:** Confirm, naming what will be removed. Undo also comes with issue 13.
- **New example:** "Turn off Science? This removes 28 results and 28 comments." with Cancel and Turn Off buttons.
- **Advantages:** Prevents losing hours of work to a mis-tap.
- **Disadvantages:** One extra tap.
- **Recommendation:** Fix in Phase 2.
- For the fixer: `ProjectEditingFeature.swift:51-59,103-135`.

**Issue 15: Restoring a backup silently overwrites the newer project [Medium]**

- **What's wrong:** If the backup is of a project already on the phone, it replaces the local one even when the local one is newer. A Replace / Keep-both choice was written but never connected to the screen. The success message always claims a replacement happened.
- **Current example:** The teacher restores last week's backup to check one comment, and this week's work is gone.
- **Proposed fix:** Ask "Replace" or "Keep both", as the web app does, and make the message match what happened.
- **New example:** "A project named 5B 2026 Term 4 already exists" with Replace, Keep Both and Cancel buttons.
- **Advantages:** Stops silent loss of newer work.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 2.
- For the fixer: `FileWorkflowFeature.swift:80-218`; unused `BackupImportChoice`.

**Issue 16: Several web-app features have no iPhone counterpart [Medium]**

- **What's wrong:** The web app has past reporting periods, a custom comment library, a teacher profile and settings, and a planner. The iPhone app has none of them.
- **Current example:** iPhone tabs: Projects, Work list, Support. Web app: Current comments, Past periods, Custom comments, Settings, Planner.
- **Proposed fix:** Decide the scope (D12), then port.
- **New example:** Depends on D12.
- **Advantages:** Parity with the product being ported.
- **Disadvantages:** It makes the rebuild larger.
- **Recommendation:** Decision D12.

## C. Screen design and architecture

**Issue 17: The whole app is one giant feature and one giant screen file [Critical]**

- **What's wrong:**
  - Every screen shares one feature with about 140 possible actions.
  - One root view hands about 100 functions down into a 3,010-line file.
  - Pop-ups, sheets and navigation live outside the testable logic.

  The project's own dependency policy forbids exactly this ("giant root features/views"), and its core rule C007 makes that a release blocker. The planned split into separate features (projects, class list, subjects, results, comments, export, support) was never built. It also makes the tests brittle: one new warning broke three unrelated AI tests.
- **Current example:** Adding one field to the results card means editing the 140-case action list, the root view and three layers of hand-off functions.
- **Proposed fix:** Split into real features (Projects; Project home → Students, Subjects, Results, Comments, Export; Support), each with its own screen and tests, using TCA's standard navigation and pop-up tools.
- **New example:** Adding a results field touches only the Results feature and its tests.
- **Advantages:** Changes stay local, screens get faster (issue 18), navigation becomes testable, and it complies with the project's own rules.
- **Disadvantages:** Large (L). Done as part of the Phase 3 rebuild rather than as a refactor of the current screens.
- **Recommendation:** Rebuild in Phase 3.
- For the fixer: `AppFeature.swift:330-473`; `Features/AppFeatureReducer.swift`; `AppView.swift:29-352`; TCA tree-based and stack-based navigation documentation.

**Issue 18: Typing is slow because every keystroke redraws all tabs and rechecks the whole class [High]**

- **What's wrong:** The root screen watches the entire app state, so each keystroke redraws every tab and reruns the readiness check for every student in every subject. The default Work list draws every student × subject results card at once (about 224 cards for 28 students in 8 subjects), with no lazy loading. The comment editor re-runs the language check on every redraw.
- **Current example:** Typing a note for one student in a 28-student class rebuilds about 224 cards per character (lag size needs a Mac check).
- **Proposed fix:** Comes with issue 17: each screen watches only its own state. Results and comments become their own drill-down screens (issue 19). Readiness is recalculated only for the student who changed.
- **New example:** Typing touches one card.
- **Advantages:** Smooth typing at real class sizes, and better battery life.
- **Disadvantages:** None beyond issue 17's cost.
- **Recommendation:** Part of Phase 3.
- For the fixer: `AppView.swift:29`; `ProjectStateHelpers.swift:16-18`; `WorklistSections.swift:633-740, 1512-1550`.

**Issue 19: The Work list is one endless page instead of a project home with focused screens [High]**

- **What's wrong:**
  - Project details, the danger zone, the class list, subjects, every results card, every comment, exports and backup all sit in one scrolling list.
  - Comment rows do not show which comments are Done.
  - There is no "Next comment" button, so the teacher hunts for the next one.
  - Exporting takes three steps, ending at a "Prepared file" card at the bottom of the page.
  - The swipe-to-delete gestures sit where iOS cannot fire them, so they do nothing.
- **Current example:** To review 28 comments, the teacher opens each one from a long list, marks it Done, goes back and searches for the next.
- **Proposed fix:**
  - **Project home:** a progress bar ("18 of 28 Done").
  - **Students:** a searchable list with swipe actions.
  - **Subjects:** on/off switches.
  - **Results:** one student or subject at a time, with Next and Previous.
  - **Comments:** grouped by Done / Not done, with "Mark Done & Next" in the toolbar.
  - **Export:** one step that opens the save/share sheet.
- **New example:** Comments: 10 not done, 18 done. Open one, then tap "Done & Next".
- **Advantages:** The core teacher loop gets much faster on a phone.
- **Disadvantages:** Part of the Phase 3 rebuild (L).
- **Recommendation:** Rebuild in Phase 3, matching the repo's own original plan.
- For the fixer: `WorklistRootView.swift:100-386`; `PRODUCTION_MVP_PLAN.md:236-252`.

**Issue 20: Three home-made component kits copy what SwiftUI already provides [High]**

- **What's wrong:** About 1,500 lines across three stacked layers of custom "stationery" components: cards, form rows, action rows, status chips, empty states, a search bar, level buttons and option pills. The second and third layers merely forward to the first. Several components are never used. The policy forbids design-system code that duplicates SwiftUI. It also blocks your Liquid Glass decision, because system menus and bars cannot adopt it while every screen is a custom paper card.
- **Current example:**

  | Home-made | Apple's built-in equivalent |
  |---|---|
  | Notebook card with form rows | Form with sections and labelled rows |
  | Empty-state card | Content-unavailable view |
  | Custom search bar | Searchable list |
  | Achievement-level button grid | Segmented picker |
  | Option pill groups | Switch rows or a menu |
  | Save / Delete / Prepare rows | Toolbar buttons |
  | Big serif page header under the real title (so the title shows twice) | The navigation title alone |

- **Proposed fix:** Use Apple's standard controls on every screen. Keep one small "paper" background and the serif title font, used only for the comment editor and preview. Delete the rest.
- **New example:** Subjects screen: a native list of switches with Liquid Glass bars, and the comment editor on paper.
- **Advantages:** About 1,500 fewer lines. Dark Mode, accessibility and Liquid Glass work automatically.
- **Disadvantages:** The app looks less like a stationery notebook outside the editor.
- **Recommendation:** Rebuild in Phase 3, matching your 8 August decision (glass chrome, paper content).
- For the fixer: `CommenterStationeryDesignSystem.swift`; `CommenterDesignSystem.swift:122-209`; `WorklistSections.swift:2696-3010`; `SupportRootView.swift:603-698`.

**Issue 21: The app will likely be unreadable in Dark Mode [Critical — needs a Mac check]**

- **What's wrong:** The paper colours are fixed light colours with no dark versions, and the app never forces light mode. In Dark Mode the background stays cream while system text turns white.
- **Current example:** In Dark Mode, subject names, input text and row subtitles appear white or grey on cream paper.
- **Proposed fix:** Native controls (issue 20) handle Dark Mode automatically. The paper area keeps light colours deliberately (D9). Add a Dark Mode screenshot to the tests.
- **New example:** Dark system screens; the comment editor on light paper with dark text.
- **Advantages:** Readable for the many teachers who use Dark Mode, and avoids an App Review risk.
- **Disadvantages:** None.
- **Recommendation:** Decision D9, then fix in Phase 3.
- For the fixer: `CommenterStationeryDesignSystem.swift:5-23,117-121`.

**Issue 22: Saving uses two stores, and one of them is never read [Medium]**

- **What's wrong:** Every save writes the project's JSON file *and* a database row, but nothing ever reads the database. A save can fail only because the unused database failed, which then triggers a file rollback. Each save opens the database three or four times (GRDB says open once), and the saving code blocks Swift's shared worker threads with a lock.
- **Current example:** Not visible to the teacher, except as extra ways for Save to fail.
- **Proposed fix:** One JSON file per project and remove GRDB (D7), held in one Swift actor (a component that handles one request at a time).
- **New example:** Same behaviour, with one store and fewer failure paths.
- **Advantages:** Simpler, faster, and one dependency fewer.
- **Disadvantages:** Gives up future database features, which nothing uses today.
- **Recommendation:** Decision D7. Remove the database.
- For the fixer: `SQLiteProjectIndex.swift`; `ProjectStore.swift:157-161,338-369,994-1006`.

**Issue 23: Recovery copies cannot be restored, and "Delete Project" leaves student data on the phone [High]**

- **What's wrong:** Every save keeps a full recovery copy of the class (up to 10 kept, for 30 days), but no screen can restore one. Deleting a project removes only its main file. The recovery copies of every student's details stay on the phone indefinitely. The success message even says a recovery copy was made, implying it can be recovered.
- **Current example:** The teacher taps Delete Project and sees: "…was deleted after a verified recovery snapshot was created." The class data remains on the device.
- **Proposed fix:** Under D6, drop recovery copies and make Delete erase the whole project folder. Teachers rely on backups.
- **New example:** "5B 2026 Term 4 was deleted from this iPhone."
- **Advantages:** Honest deletion; privacy promises hold; less code.
- **Disadvantages:** No safety net for a project deleted by mistake without a backup. The confirmation dialog stays.
- **Recommendation:** Decision D6. Drop the copies.
- For the fixer: `ProjectStore.swift:315-419,544-665`.

**Issue 24: Any future change to the data model could make every saved project show as "damaged" [High]**

- **What's wrong:** On each load the app re-encodes the project and compares it against a stored fingerprint. If an app update adds or changes any field, the re-encoded text differs and every project moves to "Damaged saved work". There is no version number on saved files.
- **Current example:** Not visible yet. It would appear after the first update that changes the data model, which issue 6's re-port will do.
- **Proposed fix:** Add a version number to saved files. Verify the fingerprint straight after writing, not on every load. Under D3 (pre-production), simply reset projects created before the re-port.
- **New example:** After an update, projects open normally.
- **Advantages:** Removes a latent data-loss trap before the re-port triggers it.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 2, before the re-port lands.
- For the fixer: `ProjectStore.swift:770-796`; `ProjectFingerprint.swift:155-170`.

**Issue 25: A comment's review status is stored in five overlapping fields, and there are three separate "approve" buttons [Medium]**

- **What's wrong:** "Is this comment approved?" is spread across five fields that can contradict each other, so the readiness check must cross-check three of them. On screen the teacher meets three confirmations for one job: "Mark Done", "Approve AI draft" and "Mark Warnings Reviewed".
- **Current example:** An AI-touched comment needs "Approve Current AI Draft for Export"; a normal one needs "Mark Done".
- **Proposed fix:** One review status with clear states (not done / done / AI pending / AI approved), the text fingerprint worked out rather than stored, and one Done button (D11).
- **New example:** Every comment shows a single Done button.
- **Advantages:** Simpler for teachers, and impossible states cannot be stored.
- **Disadvantages:** None. Under D3 no migration is needed.
- **Recommendation:** Fix in Phase 2 or 3.
- For the fixer: `Models.swift:792-888`; `ReportReadiness.swift:238-306`.

**Issue 26: The same rules are written two or three times, and the copies disagree [Medium]**

- **What's wrong:** These rules each exist in two or three copies with slightly different behaviour:
  - learning-context checks;
  - display name;
  - pronouns;
  - "safe facts" given to the AI;
  - text hashing.

  The same input can pass one check and fail another, and the AI is judged against different facts from the ones it was given.
- **Current example:** "Group work." passes one check and fails another, because only one copy strips the full stop.
- **Proposed fix:** One owner for each rule, in the data-model module; delete the copies.
- **New example:** Every screen gives the same answer for the same input.
- **Advantages:** A fix lands everywhere at once.
- **Disadvantages:** None.
- **Recommendation:** Fix during the re-port.
- For the fixer: the engine reviewer's notes, F8.

**Issue 27: Hand-written text-processing rules where Apple provides language tools [Medium]**

- **What's wrong:**
  - **Word lists.** About 30 regex word lists and verb tables handle grammar: sentence splitting, verb forms, pronoun rewriting.
  - **Five copies of the same helpers,** each recompiled on every call. A typo in a pattern silently means "no match".
  - **Broken sentence splitting.** "e.g." and "Mr." break sentences.
  - **Pronoun rewriting changes other people.** "helped him with his work" becomes "helped her with her work" for a girl.
- **Current example:** Teacher note: "Helped Mr. Smith set up the experiment". The app splits it into two sentences after "Mr."
- **Proposed fix:** Apple's NaturalLanguage framework for parts of speech and sentence splitting, and Swift's built-in pattern-matching syntax (checked when the app is built, compiled once). Re-port the rules from the web app's current grammar module.
- **New example:** The note is treated as one sentence.
- **Advantages:** Fewer silent mistakes; faster; uses Apple's tools.
- **Disadvantages:** Part of the re-port effort (L).
- **Recommendation:** Do it with issue 6.
- For the fixer: `PlaceholderResolver.swift:230-341`; `TeacherTextRepair.swift`; `ReportReadiness.swift:457-574`.

**Issue 28: Each save encodes the whole project several times to mimic the web app byte for byte [Medium]**

- **What's wrong:** To match the web app's size limit to the exact byte, each save encodes the project, decodes it, re-encodes it with a hand-written copy of JavaScript's JSON rules, and parses it again. The web app has since changed its fingerprint anyway, so the exactness is already lost.
- **Current example:** Not visible, but up to 12 MB is processed four times per save.
- **Proposed fix:** Count the bytes of one standard encode with a small margin. Delete the JavaScript-mimicking code.
- **New example:** Same behaviour, with faster saves.
- **Advantages:** Faster saves and less custom code.
- **Disadvantages:** None.
- **Recommendation:** Fix with issue 7 (decision D4).
- For the fixer: `ProjectRules.swift:148-305`; `JavaScriptJSON.swift`.

**Issue 29: The 20 MB wording file is parsed twice at launch, and the projects list waits for it [Medium — needs a Mac check]**

- **What's wrong:** At launch the wording file is read into loose objects twice, fingerprinted twice, and run through about 60,000 pattern compilations. The projects list waits until all of that finishes.
- **Current example:** The app opens to a loading state before the teacher's projects appear (duration needs a Mac check; estimated in seconds).
- **Proposed fix:** Check the wording file when the app is built, not on the phone. Read it once into typed structures. Load projects and the wording file at the same time.
- **New example:** Projects appear immediately.
- **Advantages:** Faster launch and less memory.
- **Disadvantages:** None. The re-ported file is also three times smaller.
- **Recommendation:** Fix with issue 6.
- For the fixer: `ProductionCommentDataset.swift:31-364`; `AppLifecycleFeature.swift:11-28`.

**Issue 30: Dead code and compatibility code for versions that never shipped [Low]**

- **What's wrong:** Unused fields, unused functions, a dead fallback hash, old backup versions (v1–v3, and encryption without the extra protection), and a 10-character "legacy" password minimum that the web app itself no longer accepts.
- **Current example:** The iPhone app accepts encrypted backups with weaker protection than the web app allows.
- **Proposed fix:** Delete them (D3).
- **New example:** It accepts exactly what the web app accepts.
- **Advantages:** Smaller, safer code.
- **Disadvantages:** None.
- **Recommendation:** Fix with issue 7.

**Issue 31: Comment generation re-scans the whole wording file for every comment [Low]**

- **What's wrong:** For each student and subject, the generator walks all 4,340 variants and up to 56,564 rows.
- **Current example:** Creating 210 comments runs about 900,000 pattern checks.
- **Proposed fix:** Index the wording file once by subject, year and level.
- **New example:** Creating comments is near-instant.
- **Advantages:** Speed.
- **Disadvantages:** None.
- **Recommendation:** Superseded by the re-port (issue 6).

**Issue 32: The app is built twice, from two different starting points [Low]**

- **What's wrong:** The same app entry file and images belong both to an unused Mac command-line target in the Swift package and to the real Xcode app target. The file-format module also depends on the saving module only to compute a fingerprint.
- **Current example:** Running `swift build` produces a Mac program nobody ships.
- **Proposed fix:** Delete the package's app target and keep the Xcode app as the only one. Move the fingerprint into the data-model module.
- **New example:** One app target.
- **Advantages:** Less confusion.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 1 or 3.
- For the fixer: `Package.swift:24,95-99`; `BackupEnvelope.swift:2,302`.

## D. Hand-written code that packages or Apple already provide

**Issue 33: The DOCX report writer is hand-built Word XML [High]**

- **What's wrong:** Every part of the Word file is written as a text template, and "verification" scrapes the text back out with a pattern. That never proves Word can open the file. The project's policy names SwiftDocX as the package to evaluate before writing a custom DOCX writer. It was never evaluated, and no exception is recorded. SwiftDocX 1.0.2 (released 7 October) now supports headers, footers and page numbers.
- **Current example:** About 330 lines of hand-written Word XML; US Letter paper; line breaks lost (issue 9).
- **Proposed fix:** An adapter of about 80 lines onto SwiftDocX 1.0.2 (MIT licence). Check the output by reopening it with SwiftDocX, and open-test it in Word, Pages and LibreOffice.
- **New example:** A4 reports with the teacher's line breaks kept, generated by the package.
- **Advantages:** Follows your stance and the project's policy, and the package's code deals with Word's requirements instead of ours.
- **Disadvantages:** SwiftDocX is young (27 stars), so we depend on a small project. It sits on ZIPFoundation, which we already use.
- **Recommendation:** Adopt it in Phase 4.
- Link: https://github.com/Techopolis/SwiftDocX

**Issue 34: The XLSX writer is hand-built spreadsheet XML [High]**

- **What's wrong:** Six spreadsheet parts are hand-written, with no column widths, no text wrapping and no bold header row, so long comments are unreadable without resizing. A guard apostrophe meant for CSV shows up as a visible `'` in some cells. This breaches the policy, with no exception recorded.
- **Current example:** The review workbook opens with each comment squeezed into a narrow column on one line; a comment starting "- " shows as "'- ".
- **Proposed fix:** libxlsxwriter 1.2.4 (the standard C library for writing XLSX, which supports Swift packages) behind an adapter of about 60 lines: column widths, wrapping and a bold, frozen header.
- **New example:** A readable workbook with wrapped comments and a header row.
- **Advantages:** Readable output, and it follows the policy.
- **Disadvantages:** Adds a C library, with a permissive licence.
- **Recommendation:** Adopt it in Phase 4; this also retires issue 4.
- Link: https://github.com/jmcnamara/libxlsxwriter

**Issue 35: The XLS reader cannot read ordinary Excel files, and a hand-written file-structure reader runs before the approved one [High]**

- **What's wrong:**
  - **Missing cell types.** The hand-made reader skips the records Excel normally uses for numbers, formula results and long or formatted text. Real Excel files fail as "unreadable", or quietly lose number columns.
  - **Untested against real files.** It has only been tested against the app's own XLS writer.
  - **Two container readers.** About 400 lines of hand-written code read the XLS container itself, and the approved OLEKit package is only a fallback. OLEKit's author stopped work in 2023.
- **Current example:** A school-system XLS export with student numbers shows: "This file could not be opened as a workbook."
- **Proposed fix:** libxls 1.6.4 (released 12 October, BSD licence), the standard C library for reading old Excel files, behind an adapter of about 60 lines. Delete both hand-written readers and OLEKit. Commit real XLS files saved from Excel and LibreOffice as test samples.
- **New example:** The same file imports 28 students with their student numbers.
- **Advantages:** About 550 fewer lines, and real Excel files work.
- **Disadvantages:** libxls has no Swift package file of its own, so we include its C source with a small configuration file.
- **Recommendation:** Adopt it in Phase 4.
- Link: https://github.com/libxls/libxls

**Issue 36: The XLS writer is hand-built, with no package available to replace it [High]**

- **What's wrong:** It is 460 lines of hand-written legacy Excel format. It is missing the font and style tables that Excel expects, and nobody has proved Excel opens the files without "repairing" them. Its policy exception is explicitly "not release-complete".
- **Current example:** An exported XLS opens in LibreOffice; whether Excel opens it is unknown.
- **Proposed fix:** Under D5, stop writing XLS (export XLSX and CSV instead). If you keep it, add the missing tables and open-test it in Excel, Numbers and LibreOffice.
- **New example:** Export choices: DOCX, XLSX, CSV.
- **Advantages:** Deletes the highest-maintenance file in the app, for a format Microsoft replaced in 2007.
- **Disadvantages:** Any school still requiring .xls uploads would lose it. This needs your call against core rule C005.
- **Recommendation:** Decision D5. Drop XLS writing.

**Issue 37: CSV import has three hand-written pre-parsers, and non-UTF-8 files are misread [Medium]**

- **What's wrong:**
  - **A second parser in disguise.** Before the CSV package runs, three hand-written passes split and rewrite the file, which amounts to a second parser.
  - **Wrong encoding fallback.** Files saved by Excel on Windows (Windows-1252, as in "Zoë") are decoded as UTF-16 garbage, so the teacher sees a confusing header error.
  - **Unmaintained package.** The CSV package itself has had no updates since 2021.
- **Current example:** A class list with "Zoë" from Excel for Windows shows: "Required column First Name is missing."
- **Proposed fix:** Apple's built-in TabularData CSV reader, or SwiftCSV if its error detail is not enough. Detect the encoding explicitly, or tell the teacher to "save as CSV UTF-8".
- **New example:** The file imports, or the app shows "Save the file as CSV UTF-8 and try again."
- **Advantages:** About 110 fewer lines, no abandoned package, and honest errors.
- **Disadvantages:** Row-level error messages need re-checking against the new reader.
- **Recommendation:** Adopt it in Phase 4.
- For the fixer: `CSVParser.swift:86-286`; `SpreadsheetImportFile.swift:64-69`.

**Issue 38: The password key routine for encrypted backups is hand-written and slow [Medium]**

- **What's wrong:** The backup password is turned into a key by a hand-written loop (650,000 rounds) instead of Apple's optimised built-in routine. It runs twice per export, blocking a shared worker thread. The settings are correct and match the web app; only the implementation is home-made.
- **Current example:** Exporting a password-protected backup pauses for seconds (needs a Mac check).
- **Proposed fix:** Apple's built-in CommonCrypto PBKDF2 routine, deriving the key once per export.
- **New example:** Same file, a fraction of the wait.
- **Advantages:** Faster, and no hand-rolled cryptography to review.
- **Disadvantages:** None.
- **Recommendation:** Adopt it in Phase 4.
- For the fixer: `BackupEnvelope.swift:684-715`.

**Issue 39: The AI "before and after" view is a hand-made sentence comparison that hides changes [Medium]**

- **What's wrong:** It compares whole sentences and shows at most three changes each way:
  - one changed word shows as a whole removed sentence and a whole added one;
  - reordered sentences show as "no changes";
  - anything past three changes is silently left out.

  You asked that redline not be hand-written.
- **Current example:** The AI changes six words across four sentences. The view shows three removed and three added sentences and drops the fourth.
- **Proposed fix:** Swift's built-in difference tool over words, rendered as a full redline (strikethrough for removed words, underline for added ones) with a spoken summary for VoiceOver.
- **New example:** "Ava ~~writes clearly~~ <u>writes with clarity</u> in English…", with every change shown.
- **Advantages:** Teachers see exactly what the AI changed.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 3.
- For the fixer: `WorklistSections.swift:2188-2247`.

**Issue 40: Backup file types are not registered with iOS [Low]**

- **What's wrong:** The app never declares its backup file types to iOS, so tapping a backup in Mail or Files does not offer "Open in Report Writer". One declared type uses a double extension that can never match a file.
- **Current example:** Emailed backup → tap → no Report Writer option.
- **Proposed fix:** Declare the `.cbackup` type in the app's settings and handle files opened into the app.
- **New example:** Tap the backup, choose "Open in Report Writer", and the restore screen opens.
- **Advantages:** The normal iOS way to move files between devices works.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 3.

**Issue 41: Small hand-written helpers Apple already provides [Low]**

- **What's wrong:**
  - **Formatters.** Number and date formatters are rebuilt for every row.
  - **Export wrapper.** It works around Apple's file exporter instead of using its current form.
  - **Cancel detection.** Errors are classified by searching their wording, so any error mentioning "cancel" is silently treated as the teacher cancelling.
- **Current example:** A real save failure whose message contains "cancel" shows nothing at all.
- **Proposed fix:** Apple's built-in formatting; the current file exporter with a small transfer type; typed errors.
- **New example:** The failure is shown.
- **Advantages:** Less code and honest errors.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 3.

## E. iOS 27, accessibility and wording

**Issue 42: The app shell does not use the iOS 27 patterns you chose [Medium — needs a Mac check]**

- **What's wrong:**
  - The tab bar uses the older API, and the app's own "Tab" name will clash with SwiftUI's when migrating.
  - Actions are rows rather than toolbar buttons.
  - Paper backgrounds sit behind the glass bars.
  - Every title is shown twice.
  - Three screens may not compile under iOS 27's new state rules.
- **Current example:** The Projects screen shows "Projects" as the navigation title and again as a large serif header.
- **Proposed fix:** Comes with the Phase 3 rebuild: the iOS 27 tab API, toolbar items with overflow menus, system backgrounds for chrome, and navigation titles only.
- **New example:** One title, glass toolbar, actions in the toolbar.
- **Advantages:** Matches your 8 August decision.
- **Disadvantages:** None beyond the rebuild.
- **Recommendation:** Part of Phase 3.

**Issue 43: Several colours fail contrast standards, and VoiceOver gets incomplete information [Medium]**

- **What's wrong:**
  - **Contrast.** Orange warning text on paper measures 2.7:1 and green 3.9:1; the accessibility standard for small text is 4.5:1.
  - **Selection.** Selected options are not announced as selected.
  - **Hard-to-read text.** Some labels are rotated or shrunk.
  - **Silent progress.** Long operations are not announced.
- **Current example:** The orange "Needs review" chip is hard to read for low-vision users.
- **Proposed fix:** Native controls (which carry the right accessibility traits), system colours that pass 4.5:1, announcements when operations finish, and Apple's automated accessibility audit in the UI tests.
- **New example:** The chip passes 4.5:1, and VoiceOver says "Achievement level, At Standard, selected".
- **Advantages:** Accessibility, and fewer App Review concerns.
- **Disadvantages:** None.
- **Recommendation:** Part of Phase 3.

**Issue 44: The screens show developer language to teachers [Medium]**

- **What's wrong:** Internal test wording appears as on-screen text.
- **Current example:** Results header: "Distinct empty, failed, zero-row, and success states". An action subtitle: "It does not overwrite, approve, save, prepare, export, or share the draft." A project card: "Revision 14". A home-screen card: "Local storage ready / Verified".
- **Proposed fix:** A wording pass using the web app's plain language ("Done", "Saved on this device"), with technical details moved to Support.
- **New example:** Results header: "Results". Project card: "Term 4 · 28 students".
- **Advantages:** A cleaner, clearer phone screen.
- **Disadvantages:** None.
- **Recommendation:** Part of Phase 3.

**Issue 45: Not ready for translation, and raw internal names leak to teachers [Low]**

- **What's wrong:** There is no string catalog; plurals are hand-built; some status text shows internal names. The app icon set is the old multi-size style with a stale backup copy inside, and there is no Liquid Glass icon.
- **Current example:** AI unavailable reason shown as "deviceNotEligible".
- **Proposed fix:** An Xcode string catalog (even for English only), plain names for every status, an Icon Composer app icon, and the backup icon set deleted.
- **New example:** "This iPhone doesn't support Apple Intelligence."
- **Advantages:** Clean wording now, and translation possible later.
- **Disadvantages:** None.
- **Recommendation:** Part of Phase 3.

## F. On-device AI (in scope: fully AI-enabled, Apple on-device models only — D2)

**Issue 46: The in-app privacy policy link can never appear [High]**

*(Release blocker, listed here because it sits beside the AI settings in the app.)*

- **What's wrong:** The link's address is stored under a custom settings key that Xcode silently drops, and the value itself is defined nowhere, so the link never shows. Apple's review guidelines require a privacy policy link inside the app.
- **Current example:** Support screen: no privacy policy link.
- **Proposed fix:** Put the public web address directly in the app's code.
- **New example:** Support → Privacy Policy opens the page.
- **Advantages:** Clears an App Review requirement.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 1. It only needs the final policy web address from you.
- For the fixer: `project.pbxproj:342,375`; `AppPrivacyPolicy.swift:5`.

**Issue 47: Apple's Writing Tools can rewrite a comment and skip the AI review [Medium]**

- **What's wrong:** On Apple Intelligence iPhones, the system's Rewrite and Proofread tools work in the comment editor. The result counts as a manual edit and can be exported without the AI checks core rule C004 requires. Apple can also send some Writing Tools requests to its cloud servers, so the app cannot guarantee on-device-only processing while they are enabled.
- **Current example:** The teacher selects a comment, taps Rewrite → Professional, then Mark Done, and the comment is exported.
- **Proposed fix:** Turn Writing Tools off in comment fields (D10). Offer the same help (rewrite, adjust tone, proofread) through the app's own on-device AI, which goes through the safety check and teacher approval.
- **New example:** In the comment editor: Improve, Adjust tone and Proofread buttons, each showing a redline preview (issue 39) to accept or reject.
- **Advantages:** The review guarantee and the on-device rule both hold, with no loss of features.
- **Disadvantages:** The app's own buttons must match the quality of Apple's tools.
- **Recommendation:** Decision D10. Turn them off and provide the equivalents in-app.

**Issue 48: The Foundation Models code is iOS 26-era [Medium]**

- **What's wrong:** It does not translate the AI framework's errors (content refused, request too long, language unsupported), so raw framework text reaches the teacher. Its size limit is in characters, while the model's real limit is 8,192 tokens on iOS 27, so the limit never trips. It ignores the device language. The same request gives different text each time.
- **Current example:** A refused request shows a raw framework error message.
- **Proposed fix:**
  - Map each error to a plain message.
  - Measure size with the token-count API.
  - Check that the model supports the device language.
  - Use consistent (greedy) output for revisions.
  - Remove the iOS 26 gates.
- **New example:** "Apple Intelligence couldn't revise this comment. Try a shorter note."
- **Advantages:** Honest, understandable AI failures.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 3.

**Issue 49: Nothing pins the AI to the on-device model [High]**

- **What's wrong:** iOS 27 lets the same AI code use Apple's cloud model or partner models. The app does not name the on-device model explicitly, so one small future change could send student text off the phone (core rule C002).
- **Current example:** No visible effect today; a guard is missing.
- **Proposed fix:** Name the on-device model explicitly, and add an automated check that fails if a cloud model or partner package appears.
- **New example:** Same behaviour, with the guard in place.
- **Advantages:** Your on-device-only rule is enforced by code, not by memory.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 1. It is a few lines, and it must be in place before any AI work expands.

**Issue 50: An AI request cannot be cancelled and freezes all editing [Medium]**

- **What's wrong:** While one AI request runs, the teacher cannot type, save, switch projects or cancel. Only bulk AI has a cancel button. The app also infers "AI busy" from any busy message, so unrelated work disables the AI buttons.
- **Current example:** "Improve" on a long comment locks the whole app until the model finishes.
- **Proposed fix:** Add a Cancel button, lock only the comment being revised, and track "AI busy" as its own state.
- **New example:** Revising…, with a Cancel button; other students stay editable.
- **Advantages:** The app no longer feels hung.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 3. Prompt-wording details and App Shortcuts registration (both minor) are in the reviewers' notes.

**Issue 63: The AI features are built on the old engine and must be redesigned with the re-port [High]**

- **What's wrong:** The AI features all sit on the June comment engine and the old five-field review status (issues 6 and 25):
  - Improve and Adjust tone;
  - draft from teacher evidence;
  - AI critique;
  - bulk AI previews;
  - the AI review queue.

  The re-port replaces both, so the AI features cannot simply be carried across. Also, today AI is a set of extra buttons beside the comment, not part of each step of the teacher's work.
- **Current example:** AI appears only in the comment editor's "AI Studio" area, after a comment already exists.
- **Proposed fix:** Design AI into each step of the re-ported flow, using only Apple's on-device model:
  - **Results:** turn the teacher's rough notes into usable evidence.
  - **Comments:** suggest improvements for one comment or the whole class, using the new curriculum sentence frames as the base.
  - **Review:** flag contradictions, repetition and tone across a student's comments.
  - **Approval:** everything goes through the safety check and a redline preview the teacher approves.

  Use iOS 27's current Foundation Models features (structured output, on-device tool calls to look up curriculum text, token budgeting), with a quality test set built on Apple's evaluation tools.
- **New example:** Comments screen: "Suggest improvements for all 28 comments" → a queue of redline previews → Accept / Reject each → Done.
- **Advantages:** Delivers the fully AI-enabled app you want, built once on the new engine rather than twice.
- **Disadvantages:** Real design work (L). It needs its own short plan, with the list of AI features for you to confirm before building.
- **Recommendation:** Plan it alongside the Phase 2 re-port; build it in Phase 3.

## G. Tests, release and documentation

**Issue 51: No real files from Excel, Word or the web app are used as test samples [High]**

- **What's wrong:** The test-sample folders are empty. The tests check the code against its own output and hand-made samples, so every format bug above (issues 7, 8, 35) passes the suite. Nothing checks that report files open in Word, Excel, Numbers or LibreOffice.
- **Current example:** All backup tests pass while no real web-app backup can be opened.
- **Proposed fix:** Commit real samples:
  - XLS and XLSX files saved by Excel and LibreOffice;
  - plain and encrypted backups exported by the current web app;
  - expected report files;
  - the open-check results in the pull request that adds each sample.
- **New example:** The backup test runs against a file the web app actually produced.
- **Advantages:** A passing test then means the format really works.
- **Disadvantages:** Needs Excel and Word access once to create the samples.
- **Recommendation:** Fix alongside each format fix.

**Issue 52: Tests lock in wrong output and miss whole areas [Medium]**

- **What's wrong:**
  - Tests assert the wrong pronoun and the silent data wipe.
  - No test runs the real wording file across every subject, year, level and gender (the web app's equivalent generated 21,060 comments).
  - Nothing covers Dark Mode, Dynamic Type, accessibility, navigation, full-class performance or App Shortcuts registration.
  - The only UI test is one 800-line script that taps screen coordinates, and it will break under Liquid Glass.
- **Current example:** One UI test, `testCoreReportFlowScreenshots`.
- **Proposed fix:**
  - A whole-wording-file sweep test, and parity tests against the web app's output.
  - One short UI test per screen using accessibility labels, plus Apple's accessibility audit.
  - Dark Mode and large-text runs, and a 30-student performance test.
- **New example:** The suite includes "Every comment for every subject × year × level × gender has no placeholder and correct pronouns".
- **Advantages:** Tests catch what the teacher would see.
- **Disadvantages:** Medium effort.
- **Recommendation:** Do it in Phase 5, alongside the rebuild.

**Issue 53: Tests use the older XCTest framework, and their sample data is copied into 11 files [Low]**

- **What's wrong:**
  - **Old framework.** Apple's current framework, Swift Testing, runs each case separately. Today one failing case hides the rest (which hid the XLS template cases in issue 4).
  - **Copied sample data.** The sample project is copied into 11 files, so the August "Done" rule needed 3 copies updated, and none were.
  - **Unused shared helper.** The shared test-helper module is unused.
- **Current example:** One test loops over six template formats and stops at the first failure.
- **Proposed fix:** Move to Swift Testing gradually, starting with the format tests, and keep one shared sample project.
- **New example:** Six separate results, one per format.
- **Advantages:** Clearer failures and one place to update.
- **Disadvantages:** None.
- **Recommendation:** Do it in Phase 5.

**Issue 54: The release workflow cannot succeed, and its evidence file can claim success falsely [High]**

- **What's wrong:**
  - It calls an Xcode command that does not exist (`-validate-app`).
  - It uses manual signing without a profile.
  - It uploads with a retired tool and still sets a bitcode option, obsolete since Xcode 14.
  - Its evidence file writes "passed" whenever an archive folder exists.
  - It has never been run.
  - Fastlane is present only as two copies of draft App Store text, with "TODO" web addresses.
- **Current example:** "TestFlight lane: ready" in the documents; in reality it has never run and would fail.
- **Proposed fix:** Xcode Cloud for archiving, signing and TestFlight (D13). Delete the release workflow, the signing secrets, the evidence file and the duplicate metadata.
- **New example:** Xcode Cloud builds on every merge to main and sends it to TestFlight.
- **Advantages:** A working path to TestFlight with almost no upkeep.
- **Disadvantages:** Ties releases to Apple's service, with 25 free hours a month.
- **Recommendation:** Decision D13. Use Xcode Cloud.

**Issue 55: Most of the 811 lines of release-check scripts are ceremony [Medium]**

- **What's wrong:**
  - **Prose checks.** Seven Python scripts "prove" release gates. Most check that documents contain certain phrases, not that the app works.
  - **Not run automatically.** Only one runs in the automated checks.
  - **Missed the obvious.** They reported "passed" while main was failing.
  - **Will pass vacuously.** One only recognises v4 of a GitHub step, so it will pass without checking anything after issue 1.
- **Current example:** The localisation script passes if the plan document contains the words "English-only".
- **Proposed fix:** Keep the wording-file check (it caught issue 6) and run it automatically. Keep the screenshot extractor until issue 52 replaces it. Delete the other five scripts and the five documents written to satisfy them.
- **New example:** Two scripts, both meaningful and both automated.
- **Advantages:** Less upkeep and no false reassurance.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 5.

**Issue 56: The key project documents contradict the code [Medium]**

- **What's wrong:**
  - **Handoff note.** It describes feature modules that do not exist and says only "validation and hardening" remain.
  - **MVP plan.** It describes 12 service connectors where 5 exist.
  - **Source-truth map.** It points at web-app files that no longer exist. (The ledgers were deleted on 15 November; the 8 August and 15 November decisions are now in `PROJECT_RULES.md`.)
  - **Dependency policy.** It still tells agents to stay Swift 5.10-compatible.
- **Current example:** An agent told to "read first" is directed to build a feature tree the code abandoned, on Swift 5.10.
- **Proposed fix:**
  - Record further decisions from this audit in `PROJECT_RULES.md` as you make them.
  - Rewrite the handoff as a short current-state note.
  - Cut the MVP plan to its scope list.
  - Update the source map and dependency policy.
- **New example:** The handoff says: "Main is green on Xcode 27; Phase 2 re-port in progress."
- **Advantages:** Future agents start from the truth.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 5, alongside the code it describes.

**Issue 57: About 5,000 lines of agent-written documentation the project doesn't need [Low]**

- **What's wrong:** A 919-line June audit at the repo root, a CI-skills document, five validator documents, a historical backlog, an outdated handoff note and MVP plan, and around 50 marketing and launch drafts. (The append-only ledgers were deleted on 15 November.) Git already keeps the history.
- **Current example:** Agents following old pointers still land on these documents.
- **Proposed fix:** Delete them (the shared rules forbid archiving stale documents), keeping only the App Store text actually to be submitted.
- **New example:** Required reading under 600 lines.
- **Advantages:** Faster, cheaper and less confused agents.
- **Disadvantages:** Some history moves out of view (still in git).
- **Recommendation:** Delete in Phase 5.

**Issue 58: The repo's Apple coding guides come from a source that no longer exists [Low]**

- **What's wrong:** All seven vendored guides came from a GitHub repository that now returns "not found", so they cannot be refreshed. Two are irrelevant: one is for C code, one for UIKit.
- **Current example:** Seven guides; three are useful (SwiftUI specialist, SwiftUI for iOS 27, test modernizer).
- **Proposed fix:** Keep the three useful ones and delete four. When a Mac is available, refresh them from the copies Xcode 27 ships.
- **New example:** Three guides.
- **Advantages:** Less noise for agents.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 5.

**Issue 59: The automated checks waste paid Mac minutes and lack basic hardening [Low]**

- **What's wrong:**
  - A whole Mac machine runs just for one privacy-file lint.
  - Nothing is cached between runs.
  - There is no permissions limit, and steps are pinned by changeable tags.
  - The screenshot workflow is a duplicate copy.
- **Current example:** Each run rebuilds every package from scratch on a machine billed at 10× the Linux rate.
- **Proposed fix:** Merge the lint into the build job; cache packages; restrict permissions; pin steps by commit; delete the duplicate workflow.
- **New example:** Faster, cheaper runs.
- **Advantages:** Cost and time.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 1 with issue 2.

**Issue 60: No code formatter [Low]**

- **What's wrong:** Code from many AI sessions is formatted inconsistently, and nothing enforces a style.
- **Current example:** Mixed styles across files.
- **Proposed fix:** Apple's `swift format`, which ships with Swift 6, run in the automated checks.
- **New example:** One consistent style, checked automatically.
- **Advantages:** Cleaner diffs.
- **Disadvantages:** One large formatting-only change.
- **Recommendation:** Fix in Phase 5.

**Issue 61: Exported files sit unencrypted in temporary storage for up to 12 hours, with the weakest useful protection [Low]**

- **What's wrong:** Prepared backups and report files stay in temporary storage until they are discarded, or until the next launch after 12 hours. The app also re-applies the iOS default protection level (a no-op) instead of the stronger "complete" level.
- **Current example:** An unencrypted backup of a class remains in temporary storage after an abandoned share.
- **Proposed fix:** Write with complete file protection, and discard prepared files when the share sheet closes and when the app goes to the background.
- **New example:** No leftover files.
- **Advantages:** Privacy.
- **Disadvantages:** None.
- **Recommendation:** Fix in Phase 4.

**Issue 62: The readiness check reports only the first problem when a comment is out of date [Low]**

- **What's wrong:** When a comment is out of date, the iPhone app reports only that. The web app also lists the other problems, such as unfilled placeholders, so the teacher can fix everything at once.
- **Current example:** The teacher fixes "details changed", then discovers a placeholder afterwards.
- **Proposed fix:** Port the web app's list of all issues.
- **New example:** "Details changed since this comment was created; it also contains [context]."
- **Advantages:** One pass instead of two.
- **Disadvantages:** None.
- **Recommendation:** Covered by the re-port (issue 6).

---

## Where the full reviewer notes are

The four reviewers' complete notes, with every file and line reference, are in the `2026-11-15-reviewer-notes`
folder beside this report: screens and UI (A), files and saving (B), comment engine, data model and AI (C), and
build, tests, CI and docs (D, which includes the table classifying all 25 failing tests). Every finding in them
is covered above. Delete the folder once the fixes land. Their combined "keep" lists:

- **Keep:** offline-only design with no networking anywhere; the truthful-state discipline (no success without a
  verified operation); fail-closed generation (no unresolved placeholders); the AI preview-then-approve rule; the
  screen layer reaching files only through dependency clients; the prepared-file lifecycle; native file pickers
  and the share-sheet bridge; AES-GCM backup encryption with 650,000-round key derivation (matching the web app
  and above OWASP's minimum); zip-bomb limits; the import preview and all-or-nothing commit; revision-conflict
  detection on save; value-type data models ready for Swift 6; the committed package lock file checked in CI; the
  minimal, accurate privacy manifest; the 92 feature tests' intentions; the wording-file hash check.
