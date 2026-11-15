# Screens, workflow logic, app shell and UI components review

## Summary
The truthfulness discipline is solid. Every save, import, export and AI step is backed by a real operation, and stale results are discarded. Reducers reach files, the database and the AI model only through dependency clients, never directly. The weak part is everything around that discipline.
- **One giant feature.** The app is a single TCA root feature with a 140-case action list. Its "sub-features" are only `extension AppFeature` functions. The repo's own policy forbids exactly this ("giant root features/views").
- **Old TCA style and whole-state observation.** The root view uses the deprecated `WithViewStore(observe: { $0 })`, so it watches the entire app state. About 100 closures are threaded through it into one 3,010-line view file.
- **Slow typing.** Every keystroke re-renders all three tabs and recomputes readiness for the whole project. The default Work list view draws every student × subject result card inside single list rows, so nothing is lazy.
- **Unreadable in Dark Mode.** The UI is built on three stacked custom "stationery" component layers that copy what Form, Section, LabeledContent, ContentUnavailableView and Picker already do. Their colours are hard-coded light values with no dark variants, and the light appearance is never forced. In Dark Mode, text that uses `.primary` or `.secondary` will render white on cream paper.
- **Teacher workflow gaps.**
  - Saving is manual, there is no autosave, and unsaved changes cannot be discarded.
  - Turning off a subject or deleting a student wipes results and drafts without asking. CommenterV3 asks first and autosaves.
  - Exports are blocked until 100% of comments are ready. CommenterV3 exports the Done comments for a chosen scope.
  - The AI "before/after" view is a hand-written sentence comparison that shows at most 3 changes each way.
- **Worth keeping.** The state machine for prepared files, the fingerprint-based AI review gates, the file importer/exporter and share-sheet bridges, and the 92 reducer tests.

## Findings

### F1: Dark Mode will make large parts of the app unreadable
- Severity: Critical
- Kind: correctness-bug
- Where: Sources/DesignSystem/CommenterStationeryDesignSystem.swift:5-23 (all colours are fixed `Color(red:green:blue:)` values), :117-121 (paper background always cream); no `preferredColorScheme` or `UIUserInterfaceStyle` anywhere (grep of Sources and CommenterIOS.xcodeproj/project.pbxproj:339-392). Text that will turn white: ProjectsRootView.swift:155,168,181 (`Text(...).font(.headline)` with no colour); WorklistSections.swift:510-514 (subject titles use `.foregroundStyle(.primary)` and `.secondary`), :858 (achievement level labels), :1073 (option pills); CommenterStationeryDesignSystem.swift:489-500 (action-row subtitles and chevrons use `.secondary` and `.tertiary`); all `TextField` and `TextEditor` input text (AppView.swift:496, WorklistSections.swift:22, 1455).
- What it does now: the palette holds only light-mode RGB values. The background stays cream in Dark Mode, but every view that uses system semantic colours (`.primary`, `.secondary`, `.tertiary`) or typed text turns light. The result is white or grey text on cream paper.
- Why it is like this: introduced by the "stationery redesign" commit cae98d8 (2026-06-01); no decision records a light-only app. The single screenshot test never switches appearance (UITests/CommenterIOSScreenshotTests.swift:24 is the only test).
- Why it matters: in Dark Mode (very common on iPhones) teachers would see blank-looking fields and labels. This is an App Review and accessibility risk.
- Recommended replacement: move colours into an asset catalog with Any/Dark appearances (or `Color(light:dark:)`-style dynamic colours), and use semantic system colours for all chrome. If the owner wants paper to stay light, apply `.preferredColorScheme(.light)` only to the report and editor content, not to system chrome. Add Dark Mode and Dynamic Type variants to the screenshot test.
- Effort: M
- Confidence: Medium (static reading; the colour logic is certain, the exact on-screen result needs a simulator run)

### F2: The whole app is one root reducer and one root view, which breaches the repo's TCA feature-tree rule
- Severity: Critical
- Kind: architecture
- Where: Sources/AppFeature/AppFeature.swift:11-41 (one State with about 30 fields for every screen), :330-473 (one flat `Action` enum with about 140 cases), :484-488 (one `Reduce`); Features/AppFeatureReducer.swift:41-195 (a hand-written switch that routes cases to `reduceAppLifecycle`, `reduceProjectWorkflow`, `reduceProjectEditing`, `reduceProjectAIWorkflow` and `reduceFileWorkflow`, all `extension AppFeature` functions on the same state); AppView.swift:29-352 (one `WithViewStore` that passes about 100 closures into WorklistRootView.swift:7-96, which forwards them again into WorklistSections.swift:1092-1131 and :1415-1447). No `Scope`, `ifLet`, `forEach`, `@Presents`, `PresentationAction` or `StackState` anywhere (grep).
- What it does now: the "features" in the Features folder are file splits of one reducer, not TCA child features. Every screen sees and mutates the whole app state. Sheets, dialogs, navigation and editor state live in view `@State` (AppView.swift:13-21, WorklistRootView.swift:98), so the reducer cannot test them.
- Why it is like this: started this way in the bootstrap commit 164b548 (2026-05-30) and grew by accretion. OSS_DEPENDENCY_POLICY.md:94 explicitly disallows "Giant root features/views that bypass the planned TCA feature tree", and CORE_RULES C007 makes a violation a release blocker. DECISIONS_LEDGER.md records no exception.
- Why it matters: any change touches the 140-case enum and the 100-closure call chain. Performance suffers (see F5). Navigation and presentation cannot be tested or deep-linked properly, and App Intents routing has to go through a singleton (F16).
- Recommended replacement (TCA 1.26.2):
  - Split into real child features: `ProjectsFeature`, `ProjectFeature` (holding `RosterFeature`, `SubjectsFeature`, `ResultsFeature`, `DraftsFeature`, `ReportEditorFeature`, `ExportFeature`), `SupportFeature` and `AIReviewFeature`.
  - Compose them with `Scope` and `ifLet`, use `@Presents` for the create-project sheet, delete dialog, password alerts and share/export, and use `StackState` with `NavigationStack(path:)` for drill-down.
  - Have views take `StoreOf<Child>` and use `@Bindable var store` with `$store.field` bindings (`BindableAction`) instead of hand-written `xxxChanged` actions and closures.
  - This deletes AppFeatureReducer.swift and the closure parameter lists.
  - Docs: https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/treebasednavigation and https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/stackbasednavigation
- Effort: L
- Confidence: High

### F3: Manual Save only, no autosave, and no way to discard unsaved changes
- Severity: High
- Kind: correctness-bug
- Where: Features/ProjectStateHelpers.swift:12-24 (every edit sets `hasUnsavedProjectChanges` and a "dirty" status); Features/ProjectWorkflowFeature.swift:96-112 (tapping the open project does nothing; opening another project is refused while unsaved), :148-173 (save only on `saveProjectTapped`); Views/ProjectsRootView.swift:96-102 and :246 (the whole project list, including the open project, is disabled while unsaved); Features/AppLifecycleFeature.swift:71-74 (a "dirty" status cannot be dismissed). No `scenePhase`, autosave or "discard/revert" action exists (grep). CommenterV3 autosaves: C:\Commenterv3\client\src\pages\ProjectDetail.tsx:253-264 and :816-817 ("Saving changes" / "All changes saved").
- What it does now: a teacher's edits live only in memory until they tap Save. If the app is suspended and killed, the edits are lost. If they make a mistake (for example, turning off a subject wipes its results, F4), there is no "Discard changes". Every exit is blocked until they save, which makes the mistake permanent.
- Why it is like this: no recorded reason. PRODUCTION_MVP_PLAN.md:118 lists "draft autosave" as a persistence responsibility and :251-252 asks for "clear save states", but autosave was never built into the UI. This is a parity break with live CommenterV3 (C006).
- Why it matters: teachers can lose work, or be forced to save destructive edits. This is the opposite of the product's truthfulness and safety posture.
- Recommended replacement:
  - Debounced autosave as a reducer effect using `.debounce(id:for:scheduler:)` or a cancellable `.run` with `clock.sleep`. Save on `scenePhase == .background`.
  - Keep a "Saved at …" status like V3.
  - Add a "Revert to last saved" action that reloads from the store.
  - This deletes the explicit Save rows and the "Save the open project before…" guards.
- Effort: M
- Confidence: High

### F4: Destructive edits run with no confirmation
- Severity: High
- Kind: correctness-bug
- Where: Features/ProjectEditingFeature.swift:103-114 (turning a subject off deletes its results and reports), :127-135 ("Deselect all" deletes all results and reports), :51-59 (delete student also deletes their results and reports); Views/WorklistSections.swift:441-449 ("Deselect all" button), :498 (subject toggle), :247-254 (swipe delete), :349-353 ("Delete Student" in the editor). CommenterV3 confirms both: components/SubjectSelectionStep.tsx:119-122 (AlertDialog for `pendingRemoval`) and components/StudentListStep.tsx (AlertDialog imports at :25-29).
- What it does now: one tap removes a student's or subject's results, evidence and edited drafts, with no dialog. Combined with F3 there is no undo.
- Why it is like this: AppFeatureTests.swift:535 (`testSubjectSelectAllAndDeselectAllClearDependentData`) codifies the wipe. No decision records dropping V3's confirmation.
- Why it matters: hours of result entry and edited comments can vanish from a mis-tap.
- Recommended replacement: `confirmationDialog` driven by reducer state (`@Presents var destination` with a `ConfirmationDialogState`, or SwiftUI's iOS 27 `confirmationDialog(item:)` overload, see .agents/skills/swiftui-whats-new-27/references/item-binding.md). The dialog text should name how many results and drafts will be removed. Also register an `UndoManager` action, or rely on F3's revert.
- Effort: S
- Confidence: High

### F5: Typing is slow: every keystroke re-renders all tabs and recomputes the whole project
- Severity: High
- Kind: best-practice
- Where:
  - **Whole-state observation:** AppView.swift:29 (`WithViewStore(store, observe: { $0 })`), :162 (SupportRootView receives the whole `viewStore.state`).
  - **Per-keystroke reducer work:** ProjectStateHelpers.swift:16-18 (full `Project` equality, then `getProjectReadiness(project)` on every edit); ProjectEditingFeature.swift:214-224 (AI-derived drafts are re-validated on every keystroke).
  - **Non-lazy result list:** WorklistSections.swift:633-740 (default "All" filter renders roster × subjects result cards, each with about 15 controls, in a `ForEach` that does `project.results.first {…}` per card (:635) and `readiness.entries.first(where:)` per card (:729), which is O(n²)); WorklistSections.swift:220-262 and :1251-1271 (the whole roster and the whole draft list are each placed inside one list row, so List cannot lazy-load them).
  - **Lint in the view body:** WorklistSections.swift:1512-1550 (the report editor runs placeholder search, `lintReportLanguage` and `getReportReadiness` in `body` on every render).
- What it does now: a class of 28 students × 8 subjects gives about 224 result cards and thousands of controls, all rebuilt on every character typed into any field.
- Why it is like this: a consequence of F2. `WithViewStore(observe: { $0 })` has been soft-deprecated since TCA 1.7 precisely because it observes everything.
- Why it matters: visible typing lag on real class sizes, battery drain, and a large stale-render surface.
- Recommended replacement: scoped child stores with `@ObservableState` (fine-grained observation, TCA 1.26.2). Make results and drafts drill-down screens (F6). Precompute readiness incrementally per (student, subject) in the reducer and store dictionaries keyed by `studentId::subject` instead of linear searches. Move lint into the reducer, debounced.
- Effort: L (comes largely free with F2 and F6)
- Confidence: High (code); Medium on the exact lag magnitude (not measured; no device available)

### F6: The Work list is one huge scrolling page instead of the planned Project Home → focused screens
- Severity: High
- Kind: architecture
- Where:
  - **One list, one filter:** WorklistRootView.swift:100-274 (one `List` holding project details, danger zone, roster, subjects, all result cards, drafts, exports, backup and the prepared file, filtered by a "Task focus" menu that defaults to "All", :352-386).
  - **Draft rows hide readiness:** WorklistSections.swift:1251-1271 (draft rows show only "Locked against regeneration / Editable draft", not Done or Needs review status).
  - **No next-draft navigation:** the report editor at :1449-1509 has no previous/next control.
  - **Navigation style:** WorklistSections.swift:1230-1232 and :1253-1255 (`NavigationLink { destination }` capturing a value-type `report`).
  - **The plan this departs from:** PRODUCTION_MVP_PLAN.md:236-252 ("Projects -> Project Home -> focused task screens", "searchable lists, focused editors, previews, filters, next-item navigation").
- What it does now:
  - To review comments, a teacher scrolls a long list and opens each draft without seeing which ones are still not Done. After marking one Done they go back and hunt for the next.
  - Exporting takes three steps. Tap "Prepare DOCX Reports", scroll to a "Prepared file" card at the bottom, then tap Save or Share. The card also shows a "Temporary file" name.
- Why it is like this: no recorded reason; it departs from the repo's own plan.
- Why it matters: the core teacher loop (enter results → generate → read and mark Done → export) is slow and error-prone on a phone.
- Recommended replacement:
  - A `NavigationStack(path:)` (TCA `StackState`) with a Project Home that shows progress (`Gauge` or `ProgressView(value:)` for "18 of 24 Done").
  - Screens for Students (`List` + `.searchable` + `.swipeActions`), Subjects (`Form` with `Toggle`s), Results (per student or per subject, with Next/Previous), and Drafts (`List` grouped by status with a Done badge). In the draft editor, put "Mark Done & Next" in the toolbar.
  - Export as one action that prepares and immediately presents the exporter or share sheet.
- Effort: L
- Confidence: High

### F7: Export is blocked until every comment is ready; CommenterV3 exports the Done comments for a chosen scope
- Severity: High
- Kind: missing-feature
- Where: Features/FileWorkflowFeature.swift:384-389 (refuses unless `readiness.ready == readiness.expected`); Views/WorklistSections.swift:2421-2424 (same gate in the UI). V3: C:\Commenterv3\client\src\pages\ProjectDetail.tsx:122-131 (`ExportReportsPanel` with scope and `exportableCount`), :181 ("No Done comments match this selection…"), :545 (grouping "by student"/"by subject").
- What it does now: one unfinished comment blocks all DOCX/XLSX/XLS output. There is no student/subject scope and no by-student or by-subject grouping.
- Why it is like this: no recorded decision. Parity gap under C006. (Whether the export library itself also requires 100% belongs to the import/export reviewer.)
- Why it matters: teachers routinely hand in reports subject by subject or student by student.
- Recommended replacement: port V3's scope + grouping + "exports only Done comments" model into an `ExportFeature`. Keep the truthfulness rule that only Done or approved text is exported.
- Effort: M
- Confidence: High

### F8: Three stacked custom design systems duplicate SwiftUI controls and conflict with the Liquid Glass decision
- Severity: High
- Kind: hand-written-generic-code
- Where:
  - **Layer 1, stationery components:** Sources/DesignSystem/CommenterStationeryDesignSystem.swift (817 lines: `StationeryScreen`, `NotebookCard`, `PaperStack`, `TapeLabel`, `HandwrittenAnnotation`, `StationeryFormRow`, `StationeryActionRow`, `StationeryStatusChip`, `StationeryEmptyState`, `StationerySearchBar`, `StationeryMetric`, `WorkflowTimeline`, `DeskEdgeDecoration` with coffee-mug doodles).
  - **Layer 2, pass-through wrappers:** CommenterDesignSystem.swift:122-209 (`StatusChip`, `CommenterActionRow`, `CommenterEmptyState`, all thin forwards to Stationery*).
  - **Layer 3, a private copy inside the Work list file:** Views/WorklistSections.swift:2696-3010 (`WorklistTone` mirroring `StationeryTone` 1:1, plus `WorklistNotebookCard`, `WorklistFormRow`, `WorklistActionRow`, `WorklistStatusChip`, `WorklistEmptyCard`, all forwarding again).
  - **More private copies:** SupportRootView.swift:603-698 (`SupportDiagnosticRow`, `SupportHashBlock`, a copy of the unused `HashBlock`).
- What it does now:
  - **Custom components and their native replacements:**

    | Custom component | Native replacement |
    |---|---|
    | NotebookCard + StationeryFormRow | `Form` + `Section` + `LabeledContent` |
    | StationeryEmptyState / WorklistEmptyCard | `ContentUnavailableView` |
    | StationerySearchBar | `.searchable` |
    | AchievementLevelButton grid (WorklistSections.swift:787-883) | `Picker` with `.segmented` or `.inline` style |
    | OptionPillButton groups (:955-1090) | `Toggle` rows, or `Menu` with `Toggle` items |
    | StationeryActionRow used as a button | `Button` / `NavigationLink` rows, or toolbar items |
    | StationeryStatusChip | `Label` + `.badge` / `.tint` |
    | SupportDiagnosticRow | `LabeledContent` |
    | StationeryMetric | `Gauge` / `LabeledContent` |
    | Save / Delete / Prepare action rows | `ToolbarItem` / `ToolbarOverflowMenu` (iOS 27) |
    | Screen headers (`StationeryPageHeader`) drawn above navigation titles | the navigation title alone |

  - **Dead code:** `CommenterActionRow`, `CommenterEmptyState`, `HashBlock`, `StationerySearchBar`, `StationeryMetric`, `WorkflowTimeline`/`WorkflowTimelineItem`, `PaperStack`'s external uses and `DeskEdgeDecoration`'s callers have 0 call sites outside DesignSystem (grep).
- Why it is like this: stationery redesign cae98d8 (2026-06-01), then "Reuse shared stationery components" df0b239 added the Worklist* layer. OSS_DEPENDENCY_POLICY.md:93 and :106-107 disallow "broad design-system primitives that duplicate SwiftUI" and say DesignSystem "must not become a custom UI framework". The 2026-08-08 owner decision is native Liquid Glass for chrome, paper only for report and editor content.
- Why it matters: system chrome (tab bar, nav bars, sheets, controls) cannot adopt Liquid Glass while every screen is a custom paper card. It also causes the Dark Mode, contrast and accessibility defects (F1, F17) and roughly 1,500 lines of maintenance.
- Recommended replacement: native `Form`/`List`/`Section`/`LabeledContent`/`ContentUnavailableView`/`Picker`/`Toggle`/toolbar on all screens. Keep a small `DesignSystem` holding only the paper look for the report editor and preview (one `PaperSurface` background modifier and the serif title font). Delete the Worklist*/Support*/Commenter* layers and the dead components.
- Effort: L
- Confidence: High

### F9: Swipe-to-delete gestures are wired to views where they cannot fire
- Severity: Medium
- Kind: correctness-bug
- Where: Views/ProjectsRootView.swift:247-254 (`.swipeActions` on cards inside `StationeryScreen`'s `ScrollView`/`VStack`, CommenterStationeryDesignSystem.swift:122); Views/WorklistSections.swift:247-254 (`.swipeActions` on each student button, but all students sit inside one list row, :220-262).
- What it does now: before iOS 27, `swipeActions` works only on `List` rows. On iOS 27 it needs `swipeActionsContainer()` on the scroll container (.agents/skills/swiftui-whats-new-27/references/swipe-actions.md). Several swipe actions inside one row are also undefined. So these swipes are effectively dead UI, and the student swipe would delete without confirmation (F4).
- Why it is like this: no recorded reason.
- Why it matters: decorative UI that implies a working gesture (AGENTS.md truthfulness directive).
- Recommended replacement: real `List` rows with `.swipeActions` plus confirmation (comes with F6 and F8).
- Effort: S
- Confidence: High

### F10: The project list shows a card inside a card with two folder icons
- Severity: Low
- Kind: correctness-bug
- Where: Views/ProjectsRootView.swift:229-236 (`NotebookCard { StatusIconBubble("folder"); ProjectSummaryCard(...) }`); Sources/DesignSystem/ProjectSummaryCard.swift:15-17 (ProjectSummaryCard draws its own `NotebookCard` with another folder `StatusIconBubble`).
- What it does now: every saved project row draws a nested paper card, a duplicate folder icon and two shadows. It also shows "Revision N", an internal storage counter.
- Why it is like this: no recorded reason.
- Why it matters: a visible polish defect on the first screen.
- Recommended replacement: a `List` row with `LabeledContent` / `Label(name, systemImage: "folder")` and the term as a subtitle. Delete ProjectSummaryCard.
- Effort: S
- Confidence: High

### F11: The AI "before and after" is a hand-written sentence comparison that hides changes
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Views/WorklistSections.swift:2188-2247 (`AIRevisionDiffView`: splits text on `.!?`, compares sentence sets, shows `removedSentences.prefix(3)` and `addedSentences.prefix(3)`, full proposed text collapsed in a `DisclosureGroup`).
- What it does now:
  - One changed word shows as a whole removed sentence plus a whole added sentence.
  - Reordered or duplicated sentences show as "no changes".
  - "Mr." and "3.5" break sentence splitting.
  - Anything past three changes is silently omitted from the comparison.
- Why it is like this: added in 90ef865 (2026-06-05, AI workflow foundation); no decision considered an existing diff.
- Why it matters: the teacher review gate (C004) depends on teachers seeing what the AI changed. The owner has said redline/diff should not be hand-written.
- Recommended replacement: Swift standard library `CollectionDifference` (`proposedWords.difference(from: originalWords)`, available since Swift 5.1, no package needed). Render one `Text(AttributedString)` with strikethrough for removals and underline/colour for insertions, plus a VoiceOver summary ("4 words removed, 6 added"). Show the full redline, not a truncated one. Delete `sentenceSet`, `removedSentences`, `addedSentences` and `diffRow`.
- Effort: S
- Confidence: High

### F12: Apple Writing Tools can rewrite report text and bypass the AI review gate
- Severity: Medium
- Kind: correctness-bug
- Where: Views/WorklistSections.swift:1455-1465 (report `TextEditor` with no `writingToolsBehavior`); ProjectEditingFeature.swift:214-224 (any edit to a deterministic draft is treated as a plain manual edit); ProjectEditingFeature.swift:232-253 ("Mark Done" checks readiness only, not the `ReportSafetyValidator` used for AI text).
- What it does now: on Apple Intelligence devices the system Writing Tools (Rewrite, Friendly, Professional, Proofread) work in this `TextEditor` automatically. AI-rewritten text then enters as a "manual edit" and can be marked Done and exported without the AI validation path that C004 requires for "AI-generated or AI-revised" text.
- Why it is like this: no recorded consideration.
- Why it matters: it undermines the app's AI review guarantee. Separately, the app's own "Improve" and "Adjust Tone" buttons duplicate what Writing Tools already offers.
- Recommended replacement: either set `.writingToolsBehavior(.limited)` or `.disabled` on report fields (https://developer.apple.com/documentation/swiftui/view/writingtoolsbehavior(_:)), or run `ReportSafetyValidator` on every Mark Done. The owner should decide (see Open questions).
- Effort: S
- Confidence: Medium

### F13: A single AI request cannot be cancelled and freezes all editing
- Severity: Medium
- Kind: best-practice
- Where: Features/ProjectAIWorkflowFeature.swift:12-15 (every AI or review action is refused while any AI work runs), :73-80, :184-191, :308-315, :722-729 (single-request `.run` effects with no `.cancellable`); only bulk has a cancel id (:8, :425, :517); ProjectEditingFeature.swift:7-10 (all editing is blocked while AI runs); WorklistSections.swift:1795-1798 (the busy flag is derived from any `.busy` status, so non-AI work also disables AI buttons).
- What it does now: while an on-device model call runs (seconds, possibly longer), the teacher cannot type, save, switch projects or cancel. Bulk AI is sequential over every unlocked draft and locks editing for its whole run.
- Why it is like this: a conservative reading of the 2026-06-05 AI decisions (DECISIONS_LEDGER.md:268-288 require bulk to be cancellable; they say nothing about single requests).
- Why it matters: the app feels hung, and there is no way out of a slow model call.
- Recommended replacement: `.cancellable(id: AIRequestID.self)` plus a Cancel toolbar button. Lock only the report being revised, not the whole project (the result is already discarded if its draft changed, ProjectAIWorkflowFeature.swift:92-95).
- Effort: S
- Confidence: High

### F14: TCA usage is pre-1.7 style on a version 9 minors behind
- Severity: High
- Kind: outdated-version
- Where:
  - **Deprecated root view style:** AppView.swift:29 (`WithViewStore`), :358/:378/:400/:428/:446 (`ViewStore<…>` parameters), :30 (`viewStore.binding(get:send:)`).
  - **Hand-written dependency clients:** ProjectStoreClient.swift:29-372 (manual init, manual `testValue`), ClipboardClient.swift, DateClient.swift.
  - **Copies of built-in dependencies:** DateClient.swift duplicates TCA's built-in `@Dependency(\.date)`; ProjectStoreClient.swift:113 and :212 call `UUID()` directly instead of `@Dependency(\.uuid)`.
  - **Old observation style:** ReviewIntents.swift:10-13 and AppView.swift:22 (`ObservableObject` / `@Published` / `@StateObject`).
  - **Version:** swift-composable-architecture pinned 1.17.0 vs 1.26.2 (CONTEXT facts).
- What it does now: State is already `@ObservableState` (AppFeature.swift:11), but the view ignores observation and uses the deprecated whole-state `WithViewStore`.
- Why it is like this: the bootstrap commit 164b548 (2026-05-30) was written in the pre-1.7 idiom even though 1.17 was in use. This is a model-era accident, with no recorded reason.
- Why it matters: deprecation warnings become errors under future TCA, it causes F5, and it adds hundreds of lines of client boilerplate.
- Recommended replacement: TCA 1.26.2 with `@Bindable var store: StoreOf<Feature>`, `store.scope(state:action:)` and `$store` bindings (https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/migratingto1.7). Use `@DependencyClient` macro clients (https://swiftpackageindex.com/pointfreeco/swift-dependencies/main/documentation/dependenciesmacros/dependencyclient()), which auto-generate an unimplemented `testValue`. Use `\.date.now` / `\.uuid`. Delete DateClient and the manual inits.
- Effort: M
- Confidence: High

### F15: iOS 27 / Liquid Glass readiness gaps in the app shell
- Severity: Medium
- Kind: outdated-version
- Where:
  - **Old tab API:** AppView.swift:30-190 (`TabView(selection:)` with `.tabItem`/`.tag`; the content-builder TabView initialiser is soft-deprecated in SDK 27 per .agents/skills/swiftui-specialist/references/soft-deprecated-apis.md, "Use TabContentBuilder-based TabView initializers").
  - **Name collision:** AppFeature.swift:54 (an `AppFeature.Tab` enum will collide with SwiftUI's `Tab` type when migrating).
  - **Non-builder overlays:** CommenterStationeryDesignSystem.swift:121 and WorklistRootView.swift:391 (`.overlay(StationeryPaperTexture())`), :299 (`.overlay(Circle().stroke…)`). These are the forms flagged under `@ContentBuilder` (.agents/skills/swiftui-whats-new-27/references/content-builder.md).
  - **Custom headers duplicating navigation titles:** ProjectsRootView.swift:21, :90, SupportRootView.swift:23, :32, WorklistRootView.swift:103-107, :262 (a large serif header drawn below a native navigation title, so each title appears twice).
  - **Full-screen paper backgrounds:** CommenterStationeryDesignSystem.swift:117-121, WorklistRootView.swift:259-260 (`scrollContentBackground(.hidden)` and paper behind the Liquid Glass bars).
  - **Actions as rows, not toolbar items:** almost every action is a row (Save, Generate, Prepare, Delete), with no `toolbar` items except in the create sheet (AppView.swift:540-558).
  - **Old deployment settings:** deployment target 17.0, Swift 5.10 (project.pbxproj:266-439).
  - **Possible `@State` macro compile issue:** ResultsSection (WorklistSections.swift:550-551), ReportsSection (:1132) and WorklistRootView (:98) mix `@State private var` with an implicitly synthesized memberwise init. Per references/state-macro.md, memberwise-init synthesis changes under the `@State` macro, so these may need explicit inits.
- What it does now: compiles today against iOS 17, but it does not use the iOS 27 shell idioms the owner chose.
- Why it is like this: written for iOS 17 before the 2026-08-08 cut-over decision.
- Why it matters: a non-native look under Liquid Glass, deprecation warnings, and possible SDK 27 build errors.
- Recommended replacement: `TabView(selection:) { Tab("Projects", systemImage: "folder", value: .projects) { … } }` with the enum renamed (for example `AppTab`). Use toolbar items with `.topBarPinnedTrailing`, `ToolbarOverflowMenu` and `toolbarMinimizeBehavior` (references/toolbar.md). Use trailing-closure `overlay { }`. Use system backgrounds for chrome. Use navigation titles only. Set the iOS 27 target with Swift 6 mode.
- Effort: M
- Confidence: Medium (the `@State` item is Low confidence until built with Xcode 27)

### F16: App Intents are minimal and may not register at all
- Severity: Medium
- Kind: best-practice
- Where: Sources/CommenterAppIntents/ReviewIntents.swift:32-82 (two `AppIntent`s and an `AppShortcutsProvider` inside a Swift package library; no `AppIntentsPackage` conformance in the package or app, grep), :9-27 (a `@MainActor ObservableObject` singleton router consumed by AppView.swift:22, :195-204), :32/:46/:60 (`@available(iOS 17.0…)`).
- What it does now: "Open AI Review Queue" and "Open Report Preparation" set a flag on a singleton, which the view relays to the store. There are no `AppEntity` types (for example a project), no `OpenIntent` / target content, and no parameters ("Open 5B reports").
- Why it is like this: DECISIONS_LEDGER.md:268-288 limits intents to open-only, which is sound, but nothing records the packaging choice.
- Why it matters: intents and shortcuts defined in a package must be exposed via `AppIntentsPackage` (https://developer.apple.com/documentation/appintents/appintentspackage), or they may not appear in Shortcuts or Spotlight. The singleton bypasses TCA dependency injection, which makes it untestable in a TestStore.
- Recommended replacement:
  - Declare `AppIntentsPackage` in the package and an app-side package listing it.
  - Add a `ProjectEntity: AppEntity` with an `EntityQuery`, and use `OpenIntent` with a `target` parameter for "Open project".
  - Route through a TCA dependency (an `AsyncStream` of destinations) instead of the `ObservableObject` singleton.
  - Drop the iOS 17 availability.
  - Add a test that the shortcuts provider registers.
- Effort: M
- Confidence: Medium (registration behaviour must be confirmed on device)

### F17: Accessibility: contrast failures, missing selected traits, no announcements
- Severity: Medium
- Kind: best-practice
- Where:
  - **Contrast:** CommenterStationeryDesignSystem.swift:18-19 and :57-66. Computed WCAG contrast:

    | Text colour | Background | Ratio |
    |---|---|---|
    | attentionOrange | paper | 2.74:1 |
    | attentionOrange | its own soft chip | 2.6:1 |
    | localGreen | paper | 3.85:1 |
    | localGreen | green chip | 3.76:1 |

    WCAG AA needs 4.5:1 for small text. Warning text uses orange in WorkflowStatusView.swift:353-354, WorklistSections.swift:2890-2892 and :2949-2953, and status chips use caption-size text (:403-406).
  - **Selection state not exposed as a trait:** custom radio and pill buttons announce selection only via `.accessibilityValue("Selected")` instead of the `.isSelected` trait (WorklistSections.swift:880-882, :1086-1088, :524-525).
  - **Rotated text:** CommenterStationeryDesignSystem.swift:213 (`HandwrittenAnnotation` rotated italic), :243 (`TapeLabel` rotated).
  - **Text shrinking:** `minimumScaleFactor` on names and labels (ProjectSummaryCard.swift:22, WorklistSections.swift:860, :1074).
  - **No announcements:** no `AccessibilityNotification.Announcement` for long operations (grep), although PRODUCTION_MVP_PLAN.md:263-266 requires "High contrast checks" and that "progress and cancellation states are announced".
- What it does now: shown in the list above.
- Why it is like this: a by-product of the custom stationery components (F8).
- Why it matters: low-vision and VoiceOver users, plus App Store accessibility expectations.
- Recommended replacement: native controls (which carry correct traits), semantic colours that pass 4.5:1, `AccessibilityNotification.Announcement(...).post()` on operation completion, no rotated body text, and Accessibility Inspector audits in UI tests (`XCUIApplication().performAccessibilityAudit()`).
- Effort: M
- Confidence: High (ratios computed from the source RGB values)

### F18: Not localization-ready
- Severity: Medium
- Kind: best-practice
- Where: no String Catalog (`.xcstrings`) in the repo. User text is built by interpolation with hand-made plurals throughout (for example AppLifecycleFeature.swift:50-52, ProjectAIWorkflowFeature.swift:493-498, WorklistRootView.swift:100-107). Raw enum values are shown to teachers: WorklistSections.swift:1305 and :2348 (`reason.rawValue`, so the teacher reads "deviceNotEligible"), :240 (`student.yearLevel.rawValue`), :815 (`level.rawValue`). Status messages are built as `String` in reducers (AppFeature.swift:103-112) rather than `LocalizedStringResource`.
- What it does now: English only, with grammar hard-coded.
- Why it is like this: no recorded reason. Australian English is the current market.
- Why it matters: adding a language later needs a rewrite of every message, and raw enum names leak to users today.
- Recommended replacement: an Xcode String Catalog with automatic plural variations (`^[\(count) preview](inflect: true)` or catalog plurals). Make status payloads `LocalizedStringResource`, and give enums display names.
- Effort: M
- Confidence: High

### F19: Teacher-facing text is full of developer language
- Severity: Medium
- Kind: best-practice
- Where: WorklistSections.swift:743 (Results header: "Distinct empty, failed, zero-row, and success states"), :1288 ("Deterministic local draft generation"), :2533 ("Temporary file"), :2547-2549 ("…sharing records completed, cancelled, or failed native share outcomes"); ProjectsRootView.swift:29-37 (a "Storage / Local storage ready / Verified" card on the home screen); ProjectSummaryCard.swift:27 ("Revision N"); WorklistRootView.swift:359 ("Local state, progress, and recovery prompts"); action-row subtitles such as WorklistSections.swift:1681 ("It does not overwrite, approve, save, prepare, export, or share the draft.").
- What it does now: internal test-contract wording is shown as UI copy.
- Why it is like this: copy appears to have been written to satisfy truthfulness tests rather than teachers.
- Why it matters: it adds clutter and confusion on a small screen. V3 uses plain words ("Done", "Saved on this device").
- Recommended replacement: a copy pass aligned with V3 wording. Move diagnostics (revision, fingerprint, storage state) to Support only.
- Effort: S
- Confidence: High

### F20: Startup loads the 20 MB dataset before showing saved projects
- Severity: Medium
- Kind: best-practice
- Where: Features/AppLifecycleFeature.swift:11-28 (sequential: purge, then `datasetClient.load()`, then `listProjectDiagnostics()`, then AI availability).
- What it does now: the Projects list waits for the full comment dataset to parse.
- Why it is like this: no recorded reason.
- Why it matters: slow launch to the first useful screen.
- Recommended replacement: run the dataset, project-list and AI checks concurrently inside `.run` (`async let` / `withTaskGroup`), or use separate `.merge` effects.
- Effort: S
- Confidence: High

### F21: Duplicated guard logic and a single global status string drive the state machine
- Severity: Medium
- Kind: architecture
- Where: ProjectAIWorkflowFeature.swift:17-56, :129-168, :240-282, :660-690 (the same 8-guard chain copied for polish, tone, evidence and critique, with the same Completed/Failed handling); AppFeature.swift:103-112 (one `OperationStatus` shared by all tabs); ProjectStateHelpers.swift:164-172 and WorklistRootView.swift:426-434 ("unsaved" is partly inferred from `operationStatus == .dirty`, a UI message); WorklistSections.swift:1795-1798 ("AI busy" is inferred from any `.busy` message).
- What it does now: business state is partly derived from display messages. A message set by one tab shows on the others.
- Why it is like this: grew with F2.
- Why it matters: easy to break. For example, an unrelated "busy" message disables AI buttons.
- Recommended replacement: one `AIRequest` child feature parameterised by request kind. Use explicit state flags (`isDirty`, `activeAIRequest`). Show transient messages as per-feature alerts or toasts (`@Presents var alert: AlertState`).
- Effort: M
- Confidence: High

### F22: File types are not declared, so backups cannot be opened from Files or Mail
- Severity: Low
- Kind: best-practice
- Where: Views/FilePresentation.swift:105-114 (`UTType(filenameExtension: "report-writer-backup.json")` creates a dynamic type that matches nothing; `.cbackup` is a dynamic type "conformingTo: .json"); no `UTExportedTypeDeclarations` / `CFBundleDocumentTypes` / `onOpenURL` (grep of project.pbxproj and Sources).
- What it does now: the importer relies on `.json` and dynamic types. Report Writer does not appear in "Open in…" for its own backups.
- Why it is like this: no recorded reason.
- Why it matters: restoring a backup emailed to oneself is awkward.
- Recommended replacement: declare an exported type (for example `com.<team>.reportwriter.backup`) in Info.plist, use `UTType(exportedAs:)`, and handle `.onOpenURL` into the backup-import flow.
- Effort: S
- Confidence: Medium

### F23: Fragile string matching to classify errors
- Severity: Low
- Kind: correctness-bug
- Where: Views/FilePresentation.swift:122-128 (any error whose text contains "cancel" is treated as a user cancel and swallowed); Features/FileWorkflowFeature.swift:571-574 (`isZeroAcceptedRowsMessage` looks for "no " and "accepted"; `rowLabel` is unused).
- What it does now: real errors can be silently shown as "cancelled", and import states are decided by wording.
- Why it is like this: no recorded reason.
- Why it matters: a minor truthfulness risk.
- Recommended replacement: typed errors (`ImportExportError.zeroAcceptedRows`, `CocoaError.userCancelled`, `CancellationError`) matched by case.
- Effort: S
- Confidence: High

### F24: The export file document is a workaround around the native exporter
- Severity: Low
- Kind: hand-written-generic-code
- Where: Views/FilePresentation.swift:56-103 (a `FileDocument` with a fake `init(configuration:)`, reading the whole file into memory); AppView.swift:218-225.
- What it does now: works, but carries dead code.
- Why it is like this: no recorded reason.
- Why it matters: small maintenance cost; SDK 27 guidance steers away from `FileDocument` for new code (references/document-based-apps.md).
- Recommended replacement: `fileExporter(isPresented:item:contentTypes:defaultFilename:onCompletion:)` with a tiny `Transferable` whose `FileRepresentation` returns `SentTransferredFile(url)`. Keep `ActivityShareSheet` (see Keep).
- Effort: S
- Confidence: Medium

### F25: Hand-written formatter helpers
- Severity: Low
- Kind: hand-written-generic-code
- Where: Sources/AppFeature/SupportDiagnostics.swift:28-52 (`CommenterFormatters` allocates a `NumberFormatter` or `DateFormatter` on every call).
- What it does now: creates a formatter for each row of each render.
- Why it is like this: no recorded reason.
- Why it matters: small, but it is generic code Apple provides.
- Recommended replacement: `value.formatted()` and `Date(...).formatted(date: .abbreviated, time: .shortened)` (FormatStyle). Delete `CommenterFormatters`.
- Effort: S
- Confidence: High

### F26: Several CommenterV3 teacher features have no iOS counterpart
- Severity: Medium
- Kind: missing-feature
- Where: C:\Commenterv3\client\src\App.tsx:39-47 (routes: Current comments, Past periods, Custom comments, Settings, Planner). iOS tabs: AppView.swift:30-190 (Projects, Work list, Support only); grep of Sources/AppFeature finds no reporting period, custom comment library, teacher profile or settings.
- What it does now: there is no reporting-period organisation, no reusable custom comment library, no teacher profile or cover line, no settings and no planner.
- Why it is like this: PRODUCTION_MVP_PLAN.md:249 lists "Settings" as a project section but it was never built. V3 has moved on since the port (its latest commit is 2026-11-14).
- Why it matters: parity under C006, depending on what the owner considers MVP.
- Recommended replacement: an owner scope decision first (see Open questions), then features ported from the V3 files listed.
- Effort: L
- Confidence: Medium (V3 is changing fast)

### F27: Tests cover reducers well but nothing on screen
- Severity: Medium
- Kind: test-gap
- Where: Tests/AppFeatureTests/AppFeatureTests.swift (92 TestStore tests, all reducer level); UITests/CommenterIOSScreenshotTests/CommenterIOSScreenshotTests.swift:24 (one test: `testCoreReportFlowScreenshots`); AppFeatureTests.swift:535 (codifies the unconfirmed destructive deselect); Tests/CommenterAppIntentsTests (tests only the singleton router).
- What it does now: there are no tests for Dark Mode, Dynamic Type, accessibility audits, swipe/confirmation behaviour, navigation, performance with a full class, or App Intents registration.
- Why it is like this: no recorded reason.
- Why it matters: F1, F5, F9, F10 and F16 all slipped through.
- Recommended replacement: XCUITest with `performAccessibilityAudit()`, appearance and Dynamic Type launch arguments, a 30-student fixture with an `XCTMetric` (`XCTOSSignpostMetric` / scroll metrics), and swift-snapshot-testing (pointfreeco) for key screens if the owner accepts the dependency.
- Effort: M
- Confidence: High

### F28: Two separate approval concepts confuse the review step
- Severity: Low
- Kind: best-practice
- Where: ProjectEditingFeature.swift:232-253 ("Mark Done" for generated drafts), :255-312 ("Approve Current AI Draft for Export" for AI-touched drafts); WorklistSections.swift:1470-1499; plus "Mark Warnings Reviewed" (:1767-1779).
- What it does now: the teacher must learn three different confirmations for the same job ("this text is fine to send").
- Why it is like this: DECISIONS_LEDGER.md:247-266 (AI approval is separate from Done).
- Why it matters: the teacher's mental load, and the button changes meaning by draft origin.
- Recommended replacement: one "Done" action that internally runs the correct validation for the draft's origin. The approval record and fingerprints stay as they are.
- Effort: S
- Confidence: Medium (product call)

## Keep (good as is)
- **Dependency-client boundary.** Reducers never perform file IO, parsing, document generation or database work directly; everything goes through `projectStoreClient`, `commentEngineClient` and `aiClient` (FileWorkflowFeature.swift, ProjectWorkflowFeature.swift). This satisfies OSS policy :104-105.
- **Prepared-file state machine.** Stale checks, project-ID binding, temp-file discard after save/share/cancel, 12-hour purge and file-protection class (FileWorkflowFeature.swift:430-505, ProjectStoreClient.swift:283-345). This is a correct truthfulness design.
- **AI review gates.** Fingerprint check before accept, results discarded when the draft or project changed, bulk results become previews only, bulk is cancellable (ProjectAIWorkflowFeature.swift). The logic is right; only its packaging (F21) needs work.
- **Native file pickers.** `fileImporter` / `fileExporter` with security-scoped access (AppView.swift:211-225, ProjectStoreClient.swift:364-372).
- **`ActivityShareSheet`.** A small `UIActivityViewController` bridge, justified because `ShareLink` gives no completion or cancel result, which the truthfulness rule requires.
- **Project delete confirmation and recovery snapshot.** `confirmationDialog` plus recovery-snapshot messaging (AppView.swift:254-278).
- **Encrypted backup.** Password prompt and validation flow (FileWorkflowFeature.swift:302-366).
- **Readiness logic.** Report readiness and generation prerequisites (ProjectStateHelpers.swift:191-256).
- **Reducer tests.** 92 TestStore tests; keep and port them onto the child features.
- **Accessibility groundwork.** Text styles throughout (Dynamic Type mostly works), 44-pt minimum targets, accessibility identifiers.

## Open questions for the owner
- **Writing Tools.** Should Apple Writing Tools be disabled on report fields, or allowed with every Done running the safety validator (F12)?
- **Paper look in Dark Mode.** Should the paper look stay light in Dark Mode (paper islands on dark system chrome), or should paper get a dark variant (F1)?
- **MVP scope.** Which CommenterV3 features are in the iOS MVP: reporting periods/past periods, custom comment library, teacher profile/settings, planner, export scope and grouping (F7, F26)?
- **Approval wording.** Merge "Mark Done" and "Approve AI draft" into one teacher action (F28)?
- **Autosave.** Confirm autosave (like V3) replaces the explicit Save button (F3).
- **Not checked.** I could not build or run the app (no Xcode on this host). F1, F5, F9, F15 (`@State` macro) and F16 are static readings that need simulator confirmation.
