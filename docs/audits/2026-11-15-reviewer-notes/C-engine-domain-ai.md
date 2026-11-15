# Comment engine, domain model, report safety checks and on-device AI review

## Summary
This area is careful work, but much of the care is spent keeping a copy of a design the web app no longer uses. The iOS comment engine and its bundled 20 MB wording file are a frozen copy of CommenterV3 as it stood on 2026-05-31. The bundled file's SHA-256 matches web commit `a328cb7`. Since then the web app has replaced its wording file four times. It removed recipes, precomputed variants and repetition rules on 2026-10-12 (#305). Today (2026-11-15, #337) it replaced comment generation outright with comments built from Australian Curriculum v9 text and sentence frames, achievement levels A–E, Years 5–7, strand and substrand, and a "progress" field. On generation, wording and the domain model, iOS is no longer a port of the live product (C006, C003 by intent).

Inside the copy there are real defects a teacher would see:
- The English-focus and Maths-proficiency sentences hard-code "They" for every student. A test locks this in for a girl, and both the language checker and the safety validator explicitly allow "they", so nothing catches it.
- Ordinary learning-context entries such as "Group work" or "Pair work" are rejected as "sentences". The same rule sits in stored-project validation, so a project containing them cannot be saved, restored or exported.
- The safety validator blocks any report that contains the word "student", or the first name of the student if a classmate shares it.

Grammar and phrase handling is hand-written: about 30 regex word lists, `NSRegularExpression` compiled on every call, and five copied regex helper layers. Apple's NaturalLanguage and Swift Regex cover most of it. Several rules are implemented two or three times with different behaviour. The 20 MB file is parsed twice per launch with `JSONSerialization`, hashed twice, and runs about 60,000 regex compilations.

The Foundation Models code is small and sound in shape (guided generation with `@Generable`, a timeout, nothing remote). But it was written for iOS 26: it does not handle the framework's errors, measures the model's context limit in characters rather than tokens, and keeps iOS 26 availability gates.

Solid and worth keeping: the deterministic, fail-closed design (no unresolved placeholders, blocked text never silently accepted), the AI-preview-then-teacher-approval gate, value-type `Sendable` models, and the clear error types.

## Findings

### F1: The engine, wording file and domain model are a retired copy of the web generator
- Severity: Critical
- Kind: architecture
- Where: Sources/CommentEngine/Resources/comment-engine.json (SHA-256 c6d7f90c…, 20,753,261 bytes); Sources/CommentEngine/CommentEngineData.swift:39-148; Sources/CommentEngine/ReportGenerator.swift:146-388; Sources/CommentEngine/RecipeRenderer.swift (whole file); Sources/CommenterDomain/Models.swift:3-25, 300-350; docs/ledgers/DATA_LEDGER.md:8-31
- What it does now: The iOS app generates from ComponentBank (56,564 rows), RecipeBank (5), AssembledVariants (4,340) and UniquenessGuard (2), and picks wording with the May "variant first, then recipe assembly" algorithm. `git show a328cb7:client/public/data/comment-engine.json | sha256sum` gives c6d7f90c…, identical to the bundled file. The web wording file's history since then (`git log -- client/public/data/`):
  - 7749fda (2026-09-06)
  - 56cf329 (#305, 2026-10-12): "Recipes, precomputed variants and uniqueness settings are removed"; Year 7 added; specific subject and learning focus split
  - 3b1d7b2 (2026-11-11)
  - 5c9da40 (#336, 2026-11-14): classified against ACARA v9, focus areas shape the comment
  - 446758b (#337, merged 2026-11-15 07:22 UTC, now origin/main): "Replace the hand-written comment bank with comments built from the Australian Curriculum (v9) text and authored sentence frames, so that each comment… never contradicts or repeats itself". #337 also moves to levels A–E (`client/src/lib/achievement-domain.ts` on main: `ACHIEVEMENT_LEVELS = ['A','B','C','D','E']`), Years 5–7, strand/substrand/progress, and "a single fingerprint covers every input".

  Earlier web PRs (#305, #334) list defects in the old bank that iOS still carries: "They are … and is working", "HASS" beside "Humanities and Social Sciences", "Ava shows kind and helpful.", "is encouraged to" repeated in consecutive paragraphs, and Apply changed details undoing accepted wording. iOS has `StudentYearLevel` Year 5/6 only, four bands (Beginning…Above Standard), `focusStrand`, and the old generation fingerprint shape (ReportGenerator.swift:891-962). The owner's question named a PR "Rebuild comment choice so comments never contradict or repeat themselves". No PR has that exact title; #337 is the closest match by content (its body uses the same wording) and is merged.
- Why it is like this: Ported on 2026-06-04 (commit 566435d) "Port CommenterV3 parity". After that there is no re-sync commit. DATA_LEDGER.md still describes the bundled file as the copy of "the live CommenterV3 file". The source map (docs/source-truth/commenterv3-source-map.md:16) lists `client/src/lib/data-loader.ts`, which no longer exists in the web app.
- Why it matters: Teachers get the wording bank and selection rules the owner has already replaced on the web because they produced contradictory and repetitive comments. Backups made on one platform no longer match the other's data model (levels, years, strands, fingerprint). Every other finding in this file about RecipeRenderer, uniqueness rules or band mapping is moot once the port is redone.
- Recommended replacement: Re-port from the live `client/src/lib/generator.ts`, `comment-coherence.ts`, `student-agreement.ts`, `comment-engine-contract.ts`, `achievement-domain.ts` and `client/src/data/curriculum.json` at origin/main 446758b, and the new 1,927-item / 1,101-frame wording file. Delete RecipeRenderer.swift, the AssembledVariants, RecipeBank and UniquenessGuard types and validation, `bandMapping`, `allowBandFallback`, and the old fingerprint. Update the domain to A–E, Years 5–7, strand/substrand/progress. Add a CI check that compares the bundled wording file hash with the pinned web commit. Owner decision needed first: #337 records "No AI in the app" for the web product, while CommenterIOS's decision ledger (2026-06-05) allows on-device AI.
- Effort: L
- Confidence: High

### F2: English-focus and Maths sentences call every student "they", and the checks are written to allow it
- Severity: High
- Kind: correctness-bug
- Where: Sources/CommentEngine/ReportTextLibraries.swift:88-110; Sources/CommentEngine/ReportGenerator.swift:613-649, 785-792; Tests/CommentEngineTests/ReportGeneratorTests.swift:177-191; Sources/CommenterReportSafety/ReportSafetyValidator.swift:202-205; Sources/CommentEngine/ReportReadiness.swift:490
- What it does now: The templates are literal text, for example `"They have shown particular strength in {tag}."` and `"In {tag}, they demonstrate solid understanding."`. `replacePronounTemplateTokens` only replaces `{HeShe}`-style tokens, so the literal "They" survives. For a girl the comment reads "Ava writes clearly in English. In Inferencing, they demonstrate solid understanding." The test asserts exactly this for `student(gender: .female)`. The language checker skips "they" (`normalized == "they"` returns nil). The safety validator adds they/them/their to every student's allowed set, with the comment "The deterministic Commenter corpus uses singular they consistently". That is false: the corpus uses `[Student Name]` and contains no pronoun tokens (checked with a script over all 60,904 rows).
- Why it is like this: The live web source at the time used `'{HeShe} has shown particular strength in {tag}.'` (a328cb7:client/src/lib/focusLibraries.ts:127). The literal "They" appeared in the iOS port commit 566435d and matches no web version. No recorded reason.
- Why it matters: Gendered students get inconsistent pronouns in a report that goes home to families. Because the checks were loosened to fit, AI output that switches a girl to "they" also passes validation.
- Recommended replacement: Restore the `{HeShe}`/`{heshe}` tokens (or the new #337 frames, which have a single owner for pronouns), fix the test's expected text, and make "they" acceptable only for students whose pronouns are they/them or unset.
- Effort: S
- Confidence: High

### F3: Ordinary learning contexts like "Group work" are rejected, which blocks generating, saving, restoring and exporting
- Severity: High
- Kind: correctness-bug
- Where: Sources/CommenterDomain/ProjectValidation.swift:6, 133-134, 158-164; Sources/CommentEngine/ReportInputFeedback.swift:26, 43; Sources/CommentEngine/ReportGenerator.swift:744-753; callers of `validateStoredProjectShape`: Sources/CommenterPersistence/ProjectStore.swift:943, Sources/CommenterImportExport/BackupEnvelope.swift:297 and 471, ProjectImportCommit.swift:105 and 112, ReportExportPreparation.swift:248
- What it does now: A phrase that starts with a capitalised word followed by any word on a fixed verb list counts as "a sentence". "Group work", "Pair work", "Independent work", "Small group work" and "Science experiment write up" all match because "work" and "write" are on the list. The generator then throws `unsafeTeacherText`. The stored-project validator reports "must be a short phrase, not a sentence", and ProjectStore's `assertValid` refuses to save the project.
- Why it is like this: A regex word list stood in for part-of-speech tagging. The web app moved to an NLP library (`compromise`) and documents this exact case: "Noun phrases such as 'Group work', 'Show and tell' … are not clauses" (C:\Commenterv3\client\src\lib\report-context-fields.ts:39-41).
- Why it matters: A teacher who types a very common learning context cannot create draft comments. If such data arrives by import or backup, the project cannot be saved or restored at all.
- Recommended replacement: Apple NaturalLanguage `NLTagger(tagSchemes: [.lexicalClass])` to decide whether the phrase contains a finite verb after a noun or pronoun (the same rule as the web's `isClause`). It is on-device, available in iOS 12+, and needs no dependency: https://developer.apple.com/documentation/naturallanguage/nltagger. Implement it once in the domain module and delete the two other copies (see F8). Do not run phrase-style checks in stored-shape validation. Storage should check length and placeholders only.
- Effort: M
- Confidence: High

### F4: The safety validator blocks correct reports (shared first names, the word "student", "family")
- Severity: High
- Kind: correctness-bug
- Where: Sources/CommenterReportSafety/ReportSafetyValidator.swift:159-191, 333-336; used by AI results and the local safety check (Sources/AppFeature/Features/ProjectStateHelpers.swift:274, ProjectAIWorkflowFeature.swift:602)
- What it does now:
  1. For every other classmate, a case-sensitive match on that classmate's first name blocks the report. If the class has two students called Ava, every report for either Ava is blocked ("appears to mention another student").
  2. `containsWholePhrase("Student", in: text)` is case-insensitive, so any report containing the ordinary word "student" (for example "a diligent student") is blocked as a "generic student placeholder". 100 rows of the bundled wording file contain the word.
  3. Words such as "family", "anxious" and "religion" are blocked unless they appear in the supplied facts. "Religion" is legitimate HASS content.
- Why it is like this: There is no recorded reason. Tests cover a different-name leak (testBlocksOtherStudentNamesAndFirstNameOnlyLastNameLeak) but not shared first names or the common noun.
- Why it matters: AI-revised drafts and local safety checks fail with misleading messages. A teacher cannot approve correct text and has no way past except editing out normal words.
- Recommended replacement: Exclude names the selected student shares with a classmate. Match the placeholder check only on the exact fallback token (the generator emits "Student" only when both names are empty: PlaceholderResolver.swift:68), case-sensitive and standalone. Downgrade context words such as "family" to warnings. Add tests for each case.
- Effort: S
- Confidence: High

### F5: The 20 MB wording file is parsed twice per launch with untyped JSON, hashed twice, and runs about 60,000 regex compilations
- Severity: Medium
- Kind: best-practice
- Where: Sources/CommentEngine/ProductionCommentDataset.swift:31-37, 47-240, 331-364; Sources/AppFeature/DatasetClient.swift:52; Sources/AppFeature/CommentEngineClient.swift:28, 92-104; Sources/AppFeature/Features/AppLifecycleFeature.swift:18
- What it does now:
  - At launch, `DatasetClient.liveValue` calls `loadBundled()`, which is not cached. The first generation calls it again through `ProductionDatasetCache`.
  - Each load builds a full `[String: Any]` Foundation object graph with `JSONSerialization` (about 61,000 dictionaries), coerces every field with `String(describing:)`, and computes SHA-256 twice. The second hash first turns the 20 MB into a `String`, replaces CRLF, and re-encodes it.
  - `incrementPlaceholderCounts` creates a new `NSRegularExpression` for every one of the roughly 60,900 rows.
  - A `#if !canImport(CryptoKit)` branch would return a 64-bit FNV hash labelled as the dataset "hash". That branch is dead on iOS.
- Why it is like this: It ports the web's tolerant data-loader validation, and diagnostics were wanted for the support screen. There is no recorded performance decision.
- Why it matters: Peak memory and launch time on iPhone are needlessly high. My estimate is a peak of 100–250 MB and seconds of CPU per parse; I could not run this on Windows. Validating a file that ships inside the app on every launch is work a build-time check should do.
- Recommended replacement:
  - Validate and hash the wording file at build or test time; a test already exists (ProductionCommentDatasetTests). At runtime, decode once with `JSONDecoder` into `Codable` structs and keep one shared cache that both clients use.
  - Build lookup indexes once (subject × year × level).
  - For the new #337 file (6.6 MB), JSON plus `JSONDecoder` is industry-normal. A prebuilt SQLite via the already-approved GRDB 7.12.0 (https://github.com/groue/GRDB.swift) is only worth it if the file grows again.
  - Delete the non-CryptoKit fallback and the per-row regex.
- Effort: S
- Confidence: Medium (no device measurement possible)

### F6: The Foundation Models code is iOS 26-era: no error handling, a character limit instead of a token limit, no locale check, random sampling
- Severity: Medium
- Kind: outdated-version
- Where: Sources/CommenterAI/FoundationModelReportGenerator.swift:5, 31, 51-57, 92-98, 125-131, 171-179; Sources/CommenterAI/FoundationModelAvailabilityChecker.swift:1-22; Sources/CommenterAI/AIClient.swift:251-300
- What it does now:
  - Creates `LanguageModelSession(instructions:)` and calls `respond(to:generating:)` with `@Generable` output types. Guided generation is the right choice.
  - Never catches or maps `LanguageModelSession.GenerationError` (guardrail violation, context window exceeded, unsupported language or locale, assets unavailable, rate limited, concurrent requests, refusal). The raw framework error reaches the teacher. No `GenerationError` reference exists anywhere in Sources.
  - The "request too large" guard is 120,000 characters. The on-device model's context is 4,096 tokens on iOS 26 and 8,192 on iOS 27 (WWDC26 session 241 shows `model.contextSize // 8192`), so the guard never fires before the model fails.
  - The availability check ignores the device language (`supportsLocale`).
  - No `GenerationOptions` are passed, so the same request can give different text each time.
  - Every call is wrapped in `#if canImport(FoundationModels)` and `@available(iOS 26.0, macOS 26.0, *)`, which is pointless under the decided iOS 27 minimum.
- Why it is like this: Written on 2026-06-05 against the first Foundation Models SDK, before the iOS 26.4 token APIs existed.
- Why it matters: Teachers see untranslated framework errors. Refusals from the content guardrail look like crashes. Over-long requests fail late. A teacher cannot reproduce an AI preview they rejected.
- Recommended replacement:
  - Map each `GenerationError` case to a plain message plus an `AITraceOutcome`.
  - Bound the request with `SystemLanguageModel.contextSize` and `tokenCount(for:)` (iOS 26.4+, per https://developer.apple.com/videos/play/wwdc2026/241/).
  - Check `SystemLanguageModel.default.supportsLocale(Locale.current)`.
  - Pass `GenerationOptions(sampling: .greedy)` for revisions.
  - Remove the `canImport` and `@available` scaffolding and the `osVersionTooOld` and `foundationModelsFrameworkMissing` cases.
  - Consider `response.usage` (new in iOS 27) in the trace, and the new Evaluations framework for the quality harness in Tests/CommenterAITests/AIQualityEvaluationTests.swift.
- Effort: M
- Confidence: High for the code facts; Medium for exact iOS 27 API spellings (WWDC session transcript, no SDK available here)

### F7: Nothing pins the AI to the on-device model now that iOS 27 allows cloud and third-party models
- Severity: Medium
- Kind: best-practice
- Where: Sources/CommenterAI/FoundationModelReportGenerator.swift:51, 92, 125
- What it does now: The session is created without a `model:` argument. Today that means the on-device `SystemLanguageModel`. There is no networking code in the AI, engine, domain or safety modules (grep for URLSession, Network and http found nothing), so a remote fallback is not possible today and C002 holds.
- Why it is like this: In iOS 26 there was only one model.
- Why it matters: iOS 27 adds a `LanguageModel` protocol, `PrivateCloudComputeLanguageModel`, and partner packages from Anthropic and Google that plug into the same `LanguageModelSession` (https://developer.apple.com/videos/play/wwdc2026/241/). Private Cloud Compute needs a separate entitlement, but a later one-line change could send student text off the device without touching anything else.
- Recommended replacement: Pass `model: SystemLanguageModel.default` explicitly. Add a CI grep or lint that fails on `PrivateCloudComputeLanguageModel`, other `LanguageModel` conformers, partner model packages in Package.swift, or the Private Cloud Compute entitlement. Record this in CORE_RULES C002.
- Effort: S
- Confidence: Medium

### F8: Several rules are implemented two or three times, and the copies disagree
- Severity: Medium
- Kind: architecture
- Where:
  - Context-field normalising and validation: Sources/CommenterDomain/ProjectValidation.swift:113-164; Sources/CommentEngine/ReportInputFeedback.swift:22-50, 128-136; Sources/CommentEngine/PlaceholderResolver.swift:190-202; Sources/CommentEngine/ReportGenerator.swift:964-973
  - Report-safe facts: Sources/CommenterAI/PromptRegistry.swift:223-234; Sources/CommenterAI/AIRequestValidation.swift:334-348; Sources/AppFeature/Features/ProjectStateHelpers.swift:304-313
  - Display name: PlaceholderResolver.swift:64-69; PromptRegistry.swift:236-244; ReportSafetyValidator.swift:356-361
  - Pronoun set: PlaceholderResolver.swift:71-93; ReportSafetyValidator.swift:363-376
  - Hash functions: ReportGenerator.swift:865-872; RecipeRenderer.swift:324-331; TextFingerprint.swift:3-8
- What it does now: The copies differ:
  - ProjectValidation strips `.!?;:` from both ends of a phrase; the others strip only trailing punctuation.
  - Its verb list includes "be/been/may/might/must"; ReportInputFeedback's list does not. The error messages differ.
  - The facts placed in the prompt omit the draft and are not trimmed, while the facts used to validate the result include the draft. The model is therefore judged against different facts from the ones it was given.
  - When pronouns are unset, the generator uses "They" but the validator expects nothing.
- Why it is like this: Each port step copied the web logic locally. No recorded reason.
- Why it matters: The same input can pass one gate and fail another, and fixes land in one copy only.
- Recommended replacement: One owner each. Put context-field rules, display name and pronouns in CommenterDomain (one function each), report-safe facts in CommenterAI, and one hash. Delete the other copies.
- Effort: M
- Confidence: High

### F9: A hand-written regex helper layer, copied five times and recompiled on every call
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Sources/CommentEngine/PlaceholderResolver.swift:230-319, 321-341; Sources/CommentEngine/TeacherTextRepair.swift:455-531; Sources/CommentEngine/ReportReadiness.swift:554-574; Sources/CommentEngine/RecipeRenderer.swift:199-241; Sources/CommenterReportSafety/ReportSafetyValidator.swift:392-415
- What it does now:
  - Each file defines its own `RegexMatch`, `firstMatch`, `replaceAll`, `matches`, `subscript(safe:)`, `ifEmpty`, `trimmedNonEmpty` and `capitalizedFirst`.
  - Patterns are strings passed to `try? NSRegularExpression(...)` on every call. A bad pattern silently returns "no match".
  - Capture groups are collected with `compactMap`, which drops groups that did not take part in the match. Later group indexes then shift (TeacherTextRepair.swift:469-473, used with `groups[safe: 1]` at 306-315).
  - One language-check pass compiles about 20 patterns, and readiness runs it for every report on every call (ReportReadiness.swift:220-226, 373-384).
- Why it is like this: A line-for-line translation of JavaScript `.replace(/…/g)`. No recorded reason.
- Why it matters: Wasted CPU on every readiness refresh; bugs that fail silently; no compile-time checking of patterns.
- Recommended replacement: Swift `Regex` literals (iOS 16+, compile-time checked, compiled once) with `String.replacing(_:with:)` and typed captures: https://developer.apple.com/documentation/swift/regex. One small shared text-utilities file in CommenterDomain. Delete the copies.
- Effort: M
- Confidence: High

### F10: Teacher-note repair and language checks are hand-written grammar heuristics
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Sources/CommentEngine/TeacherTextRepair.swift:127-212, 263-284, 334-390; Sources/CommentEngine/ReportReadiness.swift:457-552; Sources/CommentEngine/ReportInputFeedback.swift:26
- What it does now: The code classifies teacher text as verb phrase, gerund, noun phrase and so on from fixed lists of about 40 verbs, maps verb forms with dictionaries of 28 verbs, and splits sentences on `.!?`, which breaks on "e.g." and "Mr.". Pronoun rewriting replaces every "him/her/them" in the note with the student's pronoun, including pronouns that refer to someone else ("helped him with his work" becomes "helped her with her work" for a girl).
- Why it is like this: The web's earlier regex design. The web has since moved to the `compromise` NLP library and a single verb-agreement owner, `student-agreement.ts` (#305 and #337).
- Why it matters: Notes outside the lists are misclassified (F3 is one case), and grammar fixes stay one-word-list-at-a-time.
- Recommended replacement: NaturalLanguage `NLTagger` (`.lexicalClass`, `.lemma`) for part of speech and lemmas, and `NLTokenizer(unit: .sentence/.word)` for sentence and word splitting (https://developer.apple.com/documentation/naturallanguage). Keep the product rules (what to do with a negative growth note) as product code. Re-port the rules from the web's current `student-agreement.ts` rather than the May version.
- Effort: L (do it as part of the F1 re-port)
- Confidence: Medium

### F11: A report's review status is stored in five overlapping fields, with side effects in property setters
- Severity: Medium
- Kind: architecture
- Where: Sources/CommenterDomain/Models.swift:792-888; Sources/CommentEngine/ReportReadiness.swift:238-306; Sources/CommenterDomain/ProjectValidation.swift:91-105
- What it does now: The "Done" state is spread across:
  - `reviewedAt` (for deterministic drafts)
  - `reviewState.status`, `reviewState.approvedAt` and `reviewState.approvalFingerprint` (for AI drafts)
  - `approvedTextFingerprint` (a copy of the approval fingerprint)
  - `currentTextFingerprint` (derivable from the text)
  - `validationWarningReview`

  `text` and `manualEdit` use `didSet` to clear `reviewedAt` but leave `reviewState` alone, and `didSet` does not run during decoding. Readiness has to cross-check three of these fields to decide whether a draft is approved.
- Why it is like this: The AI layer (2026-06-05) was added beside the existing `reviewedAt` rather than replacing it.
- Why it matters: Invalid combinations are possible and have to be policed by validation (ProjectValidation.swift:99-105). This is part of why the current failing tests cluster around "mark it Done" (see CONTEXT.md).
- Recommended replacement: A single enum, for example `review: ReportReview { case draft, done(at:, textHash:), aiPending(validation:), aiApproved(at:, textHash:) }`. Compute the current text hash instead of storing it. Remove the `didSet` side effects and do the invalidation in one mutating method. Back-compat decoding is not needed: the app is pre-production per the owner's #337 note "No migrations: the app is pre-production". Confirm that this applies to iOS.
- Effort: M
- Confidence: High

### F12: Saving or validating a project encodes the whole project three times
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Sources/CommenterDomain/ProjectRules.swift:148-158, 237-252, 280-305; Sources/CommenterDomain/JavaScriptJSON.swift:1-108; Sources/CommentEngine/ReportGenerator.swift:986-1024
- What it does now: `validateProjectSizeLimits` runs `JSONEncoder` over the project, decodes the result into `JSONValue`, re-serialises it with a hand-written port of JavaScript `JSON.stringify` (including an ECMAScript number formatter) only to count bytes, and then parses the original data again with `JSONSerialization` to measure nesting depth. It runs on every save (ProjectStore.swift:943). A second hand-written JSON string escaper lives in ReportGenerator for the generation fingerprint.
- Why it is like this: To match the web's 12 MiB limit to the byte, and the web's fingerprint text, so that backups move between platforms. The comment at JavaScriptJSON.swift:1-3 says so.
- Why it matters: Up to 12 MB is processed four times per save. Byte-exact JS parity has no teacher-visible value, and the web changed its fingerprint in #337, so the parity is already lost.
- Recommended replacement: Count `JSONEncoder(outputFormatting: [.sortedKeys, .withoutEscapingSlashes])` output bytes, with a small margin, and drop the depth re-parse (typed `Codable` models cannot be deeply nested except `judgements`; see F13). Build fingerprints from `JSONEncoder` with `.sortedKeys` and hash with CryptoKit `SHA256`. Delete JavaScriptJSON.swift and ReportGenerator's `jsonString`/`jsonObject` helpers.
- Effort: S
- Confidence: High

### F13: Dead code and unused legacy fields
- Severity: Low
- Kind: architecture
- Where:
  - Unused domain fields: Models.swift:224 `allowBandFallback`, :226 `legacyNotesReview` and `LegacyNotesReview` (:197-212), :893 `judgements: [JSONValue]`, :434-479 legacy `ToneAxis` string decoding
  - Unused engine functions: TeacherTextRepair.swift:392-399 `conjugateLeadingVerb`, :451-453 `replaceWord`; PlaceholderResolver.swift:53-62, 149-163 `PlaceholderError`, `canResolveReportText`, `assertNoUnresolvedPlaceholders`
  - Unused field: ReportTextLibraries.swift:77-85 `polarity`
  - Test-only or placeholder cases: AIClient.swift:318 `generationNotImplemented`; Models.swift:416 `reviewExportConsistency`; PromptRegistry.swift:41-45 an AI prompt descriptor for fact extraction, which is not AI (AIClient.swift:301-303)
  - ProductionCommentDataset.swift:356-363 a dead hash fallback
- What it does now: None of these is used outside its own definition (grep counts: `allowBandFallback` 0, `legacyNotesReview` 0, the four functions 1 each). `judgements` is used only by size limits.
- Why it is like this: Carried over from older web shapes for backup round-trip.
- Why it matters: Clutter and false signals. `judgements` is the only reason the deep-JSON complexity checker exists.
- Recommended replacement: Delete them, subject to the pre-production / no-migration confirmation in F11.
- Effort: S
- Confidence: High

### F14: Generation and readiness repeat whole-file scans and checks for every report
- Severity: Low
- Kind: best-practice
- Where: Sources/CommentEngine/ReportGenerator.swift:266-297, 326-330; Sources/CommentEngine/SubjectMapping.swift:109-117; Sources/CommentEngine/ReportReadiness.swift:127-138, 186-226
- What it does now:
  - For each report, the generator walks all 4,340 variants and, as a fallback, all 56,564 components. Every row runs `normalizeSubjectLabel`, which does a regex replace, and the year and level checks.
  - Readiness rebuilds the generation fingerprint and the language checks for every student × subject on every call.
  - `getExpectedReportKeys` does a linear `first(where:)` search per pair.
- Why it is like this: Straight port; the web later added a readiness cache keyed by the fingerprint (#337).
- Why it matters: For a 30-student, 7-subject class that is about 210 × 4,340 regex calls per "create drafts" run, plus repeated lint work on screen refreshes.
- Recommended replacement: Index the wording file once by (subject, year, level). Normalise labels at load time. Cache readiness by fingerprint. Superseded by the F1 re-port.
- Effort: S
- Confidence: Medium

### F15: Prompt construction details
- Severity: Low
- Kind: best-practice
- Where: Sources/CommenterAI/PromptRegistry.swift:112-125, 177-221; FoundationModelReportGenerator.swift:157-162
- What it does now:
  - The teacher's custom instruction and do-not-mention list are placed in the model `instructions`. Apple advises keeping instructions developer-authored and putting user-supplied text in the prompt.
  - The draft-from-evidence prompt asks for "draft text, a support summary, and review warnings", but its `@Generable` type has only `draftText`.
  - The shared policy tells the draft task to "use only the deterministic draft" when there is none.
  - Prompt ids embed "v1" and also carry a separate "1.0.0" version.
  - Prompts are built by joining strings rather than with the `Instructions {}` / `Prompt {}` builders.
- Why it is like this: First implementation; no recorded reason.
- Why it matters: Small quality and prompt-injection-hygiene issues. The teacher is trusted, so the risk is low.
- Recommended replacement: Move teacher text into the prompt, align the prompts with the `@Generable` fields, keep one version field, and use the result builders. The registry is not over-engineered; keep it as constants.
- Effort: S
- Confidence: Medium

### F16: Tests lock in wrong output and miss whole-class and AI failure paths
- Severity: Medium
- Kind: test-gap
- Where: Tests/CommentEngineTests/ReportGeneratorTests.swift:190, 277; Tests/CommentEngineTests/ReportReadinessTests.swift (`testNeutralTheyIsAllowedForStudentsWithGenderedPronouns`); Tests/CommenterReportSafetyTests/ReportSafetyValidatorTests.swift (`testAllowsNeutralSingularTheyForAnyStudent`); Tests/CommenterAITests/*
- What it does now:
  - Tests assert "they" for a girl (F2) and permit "they" for every student.
  - There is no test that runs the real wording file across every subject × year × level × gender, as the web does (#337: 21,060 comments, 0 failures).
  - There are no golden-output parity tests against the web generator.
  - There are no tests for "Group work", shared first names, or the word "student".
  - There are no tests of Foundation Models error mapping or the timeout path, and no performance test for loading the wording file.
- Why it is like this: The tests were written to match the iOS output at port time.
- Why it matters: The suite passes on the defects in F2–F4 and cannot detect drift from the web.
- Recommended replacement: A whole-dataset sweep test, a golden-file parity test fed from the web generator at the pinned commit, regression tests for F2–F4, an AI error-mapping test using a stubbed session, and an `XCTMetric` or swift-testing time limit for loading the wording file.
- Effort: M
- Confidence: High

### F17: Not yet ready for Swift 6 language mode
- Severity: Low
- Kind: outdated-version
- Where: Package.swift:1 (`swift-tools-version: 5.10`); Sources/CommentEngine/PlaceholderResolver.swift:205-210 (a global `let` of `[String: KeyPath<PlaceholderContext, String?>]`); Sources/CommentEngine/TeacherTextRepair.swift:423 (a global `NSRegularExpression?`)
- What it does now: The models are well prepared: almost every type is a `Sendable` value type and there are no classes with mutable shared state. The two global constants are of types that are not `Sendable` (key paths are not `Sendable` unless written as `& Sendable`, per SE-0418), which Swift 6 strict concurrency rejects. ReportGenerator is a mutable struct used locally, which is fine.
- Why it is like this: Built under Swift 5.10.
- Why it matters: Minor compile errors when the decided Swift 6 cut-over happens.
- Recommended replacement: Use `KeyPath<…> & Sendable`, or a `switch` instead of the dictionary, and Swift `Regex` (F9) instead of the global `NSRegularExpression`.
- Effort: S
- Confidence: Medium

### F18: The source-truth map and data ledger are stale
- Severity: Low
- Kind: doc-stale
- Where: docs/source-truth/commenterv3-source-map.md:16, 47-53; docs/ledgers/DATA_LEDGER.md:8-31
- What it does now: The source map lists `client/src/lib/data-loader.ts`, which no longer exists, and omits the current generation owners (`comment-coherence.ts`, `student-agreement.ts`, `comment-engine-index.ts`, `client/src/data/curriculum.json`). DATA_LEDGER describes the May file as the current copy of the live file.
- Why it is like this: Not updated since June.
- Why it matters: Agents following C006 are pointed at the wrong files.
- Recommended replacement: Regenerate both alongside the F1 re-port, recording the pinned web commit hash.
- Effort: S
- Confidence: High

## Keep (good as is)
- Fail-closed generation: unresolved placeholders throw (ReportGenerator.swift:497-503), unsafe teacher text blocks with a named field, and a learning focus with no matching wording errors rather than using unrelated wording. This matches C004.
- The AI-preview-then-teacher-approval gate in readiness, which checks validation, warning review and approval fingerprints (ReportReadiness.swift:238-294). Keep the rule; simplify how it is stored (F11).
- `@Generable` structured output for AI results. Correct, current API use.
- No networking anywhere in the AI, engine, domain or safety modules (C002 holds today).
- `JSONValue` (45 lines): a standard, minimal pattern. Keep while any untyped field remains.
- Value-type, `Sendable` domain models with explicit `Codable` keys matching the web's JSON names.
- The deterministic selection hash (FNV-1a over UTF-16) is product logic for matching the web. Keep only if the re-port still needs it; it is not generic infrastructure.
- The error types (`ReportGenerationError`, `AIClientError`) give teacher-readable messages.
- The prompt registry as plain constants (not over-engineered).

## Open questions for the owner
- Should the iOS app re-port to the web's #337 generator (Australian Curriculum text plus sentence frames, A–E levels, Years 5–7, strand/substrand/progress) now, before any further iOS engine fixes? I recommend yes; most other engine findings disappear with it.
- The web PR #337 records "No AI in the app". Does that apply to iOS too, or does the iOS decision of 2026-06-05 (on-device AI allowed) stand?
- Does "No migrations: the app is pre-production" (#337) apply to CommenterIOS? If so, the legacy decoding and fields in F11 and F13 can be deleted outright.
- Is moving backups between the web and iOS still a requirement? If not, the JavaScript-exact JSON and fingerprint code (F12) can go entirely.
