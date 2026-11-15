# File import, file export, backups and local persistence review

## Summary
This area is carefully defensive (size limits, zip-bomb limits, control-character blocking, atomic writes, all-or-nothing import with a preview, revision checks), but it has three serious problems. First, **backup files no longer move between CommenterV3 and the iPhone app in either direction.** V3 dropped its backup checksums on 2026-09-27, and the iOS parser still requires them. Second, the app hand-writes generic infrastructure that the binding OSS policy forbids, and no decisions-ledger exception covers it: a DOCX writer, an XLSX writer, an OLE compound-file reader that runs *before* OLEKit, a BIFF decoder, CSV tokenizing passes, and PBKDF2. The legacy XLS writer does have a temporary exception, but that exception is not release-complete. Third, the persistence design carries machinery that delivers nothing:
- The SQLite index is written on every save and never read.
- Recovery snapshots are written but cannot be restored from anywhere in the app.
- "Delete" leaves the student data on the device.

The legacy-XLS import decoder cannot read ordinary Excel files: it misses number records written as RK/MULRK, formula results and shared strings split across CONTINUE records. The tests only check it against the app's own writer, and the `fixtures/` folders are empty. Export has drifted from current V3: the whole class is blocked unless every report is ready, and grouping by subject, subject scope, the cover line, A4 page size and V3's column set are all missing. Things that are sound and worth keeping: the AES-GCM/CryptoKit design and its parameters, the bounded ZIP extraction, the CoreXLSX adapter's bounds checks, the import validation/preview/commit split, the native fileImporter/fileExporter use, and the share-sheet wrapper.

## Findings

### F1: Backups are incompatible with current CommenterV3 in both directions
- Severity: Critical
- Kind: correctness-bug
- Where: Sources/CommenterImportExport/BackupEnvelope.swift:40-75, 118-141, 303-315, 458-506, 611-633; C:\Commenterv3\client\src\lib\persisted-schemas.ts:220-249; C:\Commenterv3\client\src\lib\backup.ts:35-62, 409-457; Tests/CommenterImportExportTests/BackupEnvelopeTests.swift:357-440
- What it does now:
  - **Plain backups, V3 to iOS.** iOS requires a `checksum` object (`projectFingerprint` plus `bundleFingerprint`) for backup versions 2 and up (BackupEnvelope.swift:482-505: `guard let checksum = payload.checksum ... else { throw BackupError.couldNotOpen }`). Current V3 v4 backups have no `checksum` field (backup.ts:35-46, 410-424), so every current V3 backup is rejected with "could not be opened".
  - **Encrypted backups, V3 to iOS.** `EncryptedProjectBackupPayload.checksum` is non-optional (BackupEnvelope.swift:123). The V3 encrypted envelope has no `checksum` (backup.ts:48-62), so decoding fails at line 614 and the teacher gets `couldNotOpen`.
  - **iOS to V3.** V3's schemas are `.strict()` (persisted-schemas.ts:232, 249), require `customComments`, `customCommentUsage` and `stickyNotes` arrays (lines 227-229), and do not allow `checksum`. iOS writes `checksum` (BackupEnvelope.swift:307-313, 382-387) and leaves the three arrays out because they are nil (lines 303-315). V3 therefore rejects every iOS backup, plain or encrypted.
- Why it is like this: V3 commit b3515ee (2026-09-27, "Apply reviewed cleanup...") removed `checksum`/`bundleFingerprint`/`ciphertextHash` from both the writer and the schemas. The last iOS change to BackupEnvelope.swift was d98e862 (2026-08-08). The iOS tests build their "web" fixtures by hand with the old checksum fields (BackupEnvelopeTests.swift:357-372, 391-394, 430-433), so they keep passing against a contract V3 no longer has. This breaches C006 (port from live source).
- Why it matters: A teacher who moves from the web app to the iPhone (or back) cannot restore their class. That is the main reason a backup exists in a port. The error message ("could not be opened... choose a backup created by this app") is truthful but does not help.
- Recommended replacement: Re-port the envelope from live backup.ts/persisted-schemas.ts:
  - Make `checksum` optional or remove it, and match V3's strict key set.
  - Always write the three empty side-store arrays.
  - Accept exactly the versions V3 accepts (v4 / encrypted v2).
  - Delete the hand-built "web" fixtures, and add fixture files actually produced by current V3 (plain and encrypted) under `fixtures/`, plus a round-trip test of an iOS-written file through V3's schema.
  - This deletes about 80 lines (bundle-fingerprint code at 556-568, ciphertext-hash checks at 575-577).
- Effort: M
- Confidence: High

### F2: Encrypted-backup authenticated data is built with escaped slashes, so about 45% of cross-app encrypted backups cannot be opened
- Severity: High
- Kind: correctness-bug
- Where: Sources/CommenterImportExport/BackupEnvelope.swift:718-739, 764-772; C:\Commenterv3\client\src\lib\backup.ts:233-240
- What it does now: The AES-GCM additional authenticated data is a JSON string assembled by hand. Each value goes through `jsonStringLiteral`, which uses `JSONSerialization.data(withJSONObject:)` with default options. Apple's JSONSerialization escapes `/` as `\/` unless `.withoutEscapingSlashes` is passed. V3 computes the same bytes with `JSON.stringify`, which never escapes `/`. Base64 `salt` (16 bytes) and `iv` (12 bytes) contain `/` about 45% of the time (1 − (63/64)^38). In those files the two apps authenticate different bytes, and decryption fails with "check the password". iOS-to-iOS round trips are unaffected because both sides escape the same way.
- Why it is like this: No recorded reason. The test fixtures use salt `AAECAwQFBgcICQoLDA0ODw==` and iv `EBESExQVFhcYGRob` (BackupEnvelopeTests.swift:385-386), which contain no `/`, so the bug is never exercised.
- Why it matters: Once F1 is fixed, nearly half of password-protected backups made in one app will still fail in the other, and the teacher will be told the password is wrong. That is a misleading error and a lost backup.
- Recommended replacement: Build the AAD with `JSONEncoder` using `outputFormatting = [.withoutEscapingSlashes]`, from a Codable struct whose property order matches V3's object order. This removes the hand-built string at 718-739 and `jsonStringLiteral`. Add a test with a salt/iv containing `/` and `+`, and a V3-produced fixture. (Apple: https://developer.apple.com/documentation/foundation/jsonserialization/writingoptions/withoutescapingslashes)
- Effort: S
- Confidence: High

### F3: Legacy .xls import cannot read ordinary Excel files
- Severity: High
- Kind: correctness-bug
- Where: Sources/CommenterImportExport/SpreadsheetImportFile.swift:729-777 (parseBIFFRows), 803-841 (decodeSST / decodeXLUnicodeStringWithLength)
- What it does now: The hand-written BIFF8 decoder reads only BOF, SST, LABEL, LABELSST, NUMBER and EOF records. It has these gaps:
  - It ignores RK (0x027E) and MULRK (0x00BD), which is how Excel normally stores integers such as "5" or student numbers. It also ignores FORMULA (0x0006) cached results and BOOLERR.
  - `decodeSST` reads only the single SST record payload. Real Excel files continue the SST in CONTINUE (0x003C) records once it passes 8,224 bytes, so `strings.count == count` fails and the workbook is "unreadable".
  - SST strings with rich-text runs (flag 0x08) or phonetic data (0x04) are decoded without skipping `cRun`/`cbExtRst`. The offsets then drift and parsing throws.
  - Numeric cells therefore become empty strings. Where the column is required, validation blocks the row. Where the column is optional, the value is silently dropped.
- Why it is like this: DECISIONS_LEDGER 2026-05-31 calls the BIFF layer "fixture-limited" and says full parity "still requires a proven mature parser such as libxls". The only test reads a workbook made by the app's own writer (SpreadsheetImportFileTests.swift:365), and `fixtures/imports` is empty.
- Why it matters: Teachers whose school systems export .xls (C005 requires .xls) will usually see "could not be opened as a workbook" or have optional values silently lost.
- Recommended replacement: Vendor libxls v1.6.4 (2026-10-12, BSD-2, https://github.com/libxls/libxls) as a SwiftPM C target with a checked-in `config.h`; upstream has no Package.swift, only autotools, which I checked via `gh api`. Use its in-memory `xls_open_buffer` API behind a roughly 60-line adapter returning `[[String]]`. This deletes the custom OLE reader, the BIFF decoder and OLEKit (see F4), about 550 lines. Add real .xls fixtures saved from Excel and LibreOffice.
- Effort: L
- Confidence: High (record coverage read directly from code; CONTINUE/RK behaviour is standard BIFF8)

### F4: A hand-written OLE compound-file reader runs before the approved OLEKit, which then serves only as a fallback
- Severity: High
- Kind: hand-written-generic-code
- Where: SpreadsheetImportFile.swift:155-190 (parseXLS fast path), 195-575 (workbookStreamFromCompoundFile, FAT/DIFAT/mini-FAT/sector-chain readers), 579-597 (OLEKit fallback); LegacyXLSWorkbookWriter.swift:301-327 (a second, separate OLE reader used for validation)
- What it does now: About 400 lines of custom OLE parsing (DIFAT walk, FAT, mini-FAT, mini stream, directory entries) run first. `OLEFile` from OLEKit is used only if that path throws. A second minimal OLE reader inside the writer validates the app's own output.
- Why it is like this: The OSS policy lists "new OLE container readers" as disallowed. DECISIONS_LEDGER 2026-05-31 first removed OLEKit and kept "the smallest fixture-limited local OLE compound-file extractor". A later entry the same day superseded that, restoring OLEKit as "the approved OLE container fallback". No entry approves keeping a full custom reader as the primary path.
- Why it matters: Two OLE implementations means double the maintenance and attack surface, and the custom one is primary without an exception. OLEKit itself is unmaintained (F13).
- Recommended replacement: libxls (F3) includes its own OLE layer, so adopting it deletes both readers and OLEKit. If libxls is rejected, delete the custom reader and use only OLEKit, upgraded to 0.3.1 (https://github.com/CoreOffice/OLEKit), and record the decision.
- Effort: M (folded into F3)
- Confidence: High

### F5: The DOCX report is hand-assembled WordprocessingML although the approved SwiftDocX now covers it
- Severity: High
- Kind: hand-written-generic-code
- Where: Sources/CommenterImportExport/ReportDocumentFile.swift:95-122, 308-427 (XML strings), 145-211 and 264-280 (regex "verification")
- What it does now:
  - Every OOXML part is written as a string literal: content types, rels, core and app properties, styles, header, footer with a PAGE field, and document.
  - Text is escaped with `replacingOccurrences`.
  - The output is "verified" by regex-scraping `<w:t>` back out. That proves the strings round-trip but does not show the XML is well-formed or that Word can open it.
- Why it is like this: DEPENDENCY_AUDIT.md calls this a "temporary bridge until SwiftDocX is evaluated" and a "policy risk". The OSS policy says SwiftDocX evaluation is "required before custom DOCX writer changes". No exception is recorded, and VALIDATION_LEDGER.md:199-200 and 755/785 record that target-app open validation is absent.
- Why it matters: This breaches the owner's stance and the policy's release-blocker clause ("Shipping custom generic infrastructure without this gate is a release blocker"). Nothing proves the output opens in Word or Pages.
- Recommended replacement: Techopolis/SwiftDocX 1.0.2 (2026-10-07, MIT, https://github.com/Techopolis/SwiftDocX). Its source has `Header`/`Footer`, `addPageNumber`, page breaks, headings, paragraph spacing and alignment, and it builds on ZIPFoundation. Write an adapter of about 80 lines from `PreparedReportPacket` to `Document`, and delete about 330 lines of XML. Its model types are classes, so keep them local to the preparation function for Swift 6 Sendable checking. Open-test the output in Word, Pages and LibreOffice.
- Effort: M
- Confidence: High

### F6: The XLSX review workbook and templates are hand-assembled SpreadsheetML
- Severity: High
- Kind: hand-written-generic-code
- Where: Sources/CommenterImportExport/ReviewWorkbookFile.swift:102-117, 254-353
- What it does now: The writer hand-writes six XML parts with inline strings. The worksheet has no column widths, no wrapped text for long comments, no bold or frozen header, and a single-entry `<fills>` list. Verification is a regex over `<t>` (210-226). The `'` formula guard from `spreadsheetSafeText` (ReportExportPreparation.swift:141-148) is stored as literal text, so a comment beginning "- " or "=" shows a visible apostrophe. Inline strings are never evaluated as formulas, so the guard only matters for CSV.
- Why it is like this: DEPENDENCY_AUDIT.md says "libxlsxwriter/approved XLSX writer evaluation is still required before treating this as release-complete"; DECISIONS_LEDGER 2026-05-31 names direct libxlsxwriter as the preferred candidate. No exception is recorded.
- Why it matters: Policy breach (release blocker). Teachers get an unformatted sheet in which multi-sentence comments are unreadable without manual resizing.
- Recommended replacement: jmcnamara/libxlsxwriter v1.2.4 (2026-01-12, FreeBSD licence plus bundled notices, has Package.swift, https://github.com/jmcnamara/libxlsxwriter), behind an adapter of about 60 lines that sets column widths, text wrap and a bold header. Drop the apostrophe prefix for XLSX/XLS and keep it for CSV only. Deletes about 200 lines.
- Effort: M
- Confidence: High

### F7: The legacy XLS writer's exception is not release-complete and its output is structurally minimal
- Severity: High
- Kind: hand-written-generic-code
- Where: Sources/CommenterImportExport/LegacyXLSWorkbookWriter.swift:88-119 (globals: BOF, CODEPAGE, WINDOW1, BOUNDSHEET, EOF only), 166-188 (LABEL records), 199-299 (hand-written OLE container)
- What it does now: It writes 460 lines of BIFF8 plus OLE by hand. The globals substream has no FONT, XF, STYLE or SST records, yet every cell references XF index 0 through LABEL (0x0204) records rather than LABELSST. The only check is a read-back by its own parser.
- Why it is like this: DECISIONS_LEDGER 2026-05-31 ("Document package suitability") grants "a narrow custom legacy .xls writer exception... temporarily justified because no mature iOS SwiftPM BIFF writer was identified, but the exception is not release-complete without fixtures and target-app open validation". VALIDATION_LEDGER.md:199-200 confirms "Excel, Numbers, LibreOffice... open validation remains a release" gap. I also found no maintained Swift or iOS BIFF writer; libxlsxwriter writes only .xlsx.
- Why it matters: C005 makes .xls export mandatory, but it is unproven that Excel opens these files without "repair". Lenient readers such as LibreOffice will probably open them; strict Excel behaviour with no XF table is the risk. This is the highest-maintenance file in the area, for a format Microsoft superseded in 2007.
- Recommended replacement: There is no suitable package (honest assessment). The smallest acceptable form is what exists, plus:
  - the minimum required globals (FONT ×5, 16 style XFs plus one cell XF, STYLE);
  - LABELSST with an SST record;
  - real open validation in Excel for Mac/Windows, Numbers and LibreOffice, and committed sample outputs.
  - Also flag the cost to the owner (see Open questions); do not overrule C005.
- Effort: M
- Confidence: Medium (whether Excel accepts the XF-less file is unverified, since no Excel is available here)

### F8: Recovery snapshots cannot be restored, and "Delete" keeps all student data on the device indefinitely
- Severity: High
- Kind: architecture
- Where: Sources/CommenterPersistence/ProjectStore.swift:315-317, 378-419, 544-665; Sources/AppFeature/Features/ProjectWorkflowFeature.swift:212, 281, 322; Sources/AppFeature/Views/WorklistSections.swift:107
- What it does now:
  - Every save writes a full-project recovery snapshot (throttled to one a minute, at most 10 kept, 30 days). Every delete and every backup-replace also writes one.
  - No part of the app calls `listRecoverySnapshots` or offers a restore. AppFeature has no reference to `RecoverySnapshot` (grep).
  - `deleteProject` removes only `project.json`. The `recovery/` folder with up to 10 complete copies of the class stays. `pruneRecoverySnapshotsLocked` runs only when a new snapshot is created for that same project, so after a delete the copies are never pruned. `listProjects` skips folders without `project.json`, so the teacher never sees them again.
  - The success text says "...was deleted after a verified recovery snapshot was created", which implies the project can be recovered when the app offers no way to do it.
- Why it is like this: Ported from V3's recovery concept (CORE_RULES C004 lists "recovery operations"). No recorded decision on a restore UI or on retention after delete.
- Why it matters:
  - It is ceremony: a safety net with no way to use it.
  - Teachers are led to believe they can undo a delete or a backup overwrite (C004).
  - Private student data survives an explicit "Delete Project", which conflicts with the C002 privacy posture and with any App Store privacy answer of "user can delete data".
- Recommended replacement: Decide one of two options (see Open questions):
  - (a) Add a restore list (a TCA feature reading `listRecoverySnapshots`) and purge a deleted project's `recovery/` after a stated grace period.
  - (b) Drop recovery snapshots and make delete remove the whole project folder, relying on the teacher's exported backups.
  - Either way, fix the delete message.
- Effort: M
- Confidence: High

### F9: Saved-project fingerprints are computed over the re-encoded model, so a future model change will make every saved project look "damaged"
- Severity: High
- Kind: architecture
- Where: Sources/CommenterPersistence/ProjectStore.swift:781-796, 770-779; Sources/CommenterPersistence/ProjectFingerprint.swift:155-170; Sources/CommenterDomain/Models.swift:55-60 (decodeIfPresent with defaults)
- What it does now: On every read, `readProject` decodes `project.json` into `Project`, re-encodes it, computes a JavaScript-compatible stable JSON string and SHA-256, and throws `verificationFailed` if the result differs from the stored fingerprint. A project that fails is moved to the "damaged saved work" list. The model already decodes some keys with defaults (Models.swift:57-58). If an app update adds a defaulted field, or changes how any field encodes, the re-encoded JSON differs from what was saved, and every existing project fails. There is no schema version and no migration step.
- Why it is like this: The design mirrors V3's persistence fingerprint (source map: persistence-fingerprint.ts) to detect tampering and corruption. No decision addresses schema evolution.
- Why it matters: This is a latent data-loss path. After an ordinary app update, the teacher's whole class list could show as damaged, with only "support copy" and "remove" offered. It also turns any well-intentioned model change into a breaking change.
- Recommended replacement: Add `schemaVersion` to the stored record and a migration step before verification. Alternatively, fingerprint the raw stored bytes, or verify only immediately after a write (where the encoder is the same), and on load treat a mismatch on an older schema version as "migrate and re-save" rather than "damaged". If F12 moves data into GRDB, use `DatabaseMigrator` (https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations).
- Effort: M
- Confidence: Medium (mechanism confirmed; whether it fires depends on future model edits)

### F10: Report export has drifted from current V3 and blocks the whole class unless every report is ready
- Severity: High
- Kind: missing-feature
- Where: Sources/CommenterImportExport/ReportExportPreparation.swift:26-79, 150-205, 247-307; ReportDocumentFile.swift:337, 364; C:\Commenterv3\client\src\lib\export.ts:15-29, 121-183, 200-212; C:\Commenterv3\client\src\lib\report-docx.ts:27-31, 205-216
- What it does now:
  - **All-or-nothing scope.** `validatedReportExportScope` throws `notReady` if any student × subject is not export-ready (303-305). V3 exports the ready entries and reports the skipped ones (export.ts:153-182). A teacher halfway through a class cannot export finished reports.
  - **Missing V3 options.** iOS has no grouping by subject, no single-subject scope and no cover line (export.ts:15-29, 92-98).
  - **Workbook columns differ.** iOS writes "Learning Focus" (filled from `focusStrand` into a property called `specificSubject`) and "Reporting Period Name" (holding the project name). V3 writes Student Name, Year Level, Subject, Specific Subject, Learning Focus, Achievement Level, Report Comment, Saved Work Name, Reporting Period.
  - **DOCX page and language.** iOS uses US Letter (`w:w="12240" w:h="15840"`, ReportDocumentFile.swift:337). V3 uses the docx-library default (A4) and sets en-AU proofing language (report-docx.ts:208).
  - **Line breaks.** Single line breaks inside a paragraph are joined with "\n" into one `<w:t>` (ReportExportPreparation.swift:128; ReportDocumentFile.swift:364), and Word renders them as spaces. V3 emits `break: 1` (report-docx.ts:31).
- Why it is like this: V3's export changed repeatedly in November 2026 (3b1d7b2 2026-11-11, 2e1e1b3, ee67f33). The iOS port dates from August. This breaches C006.
- Why it matters: The teacher's end goal is a finished report file. Today they cannot get partial output, and the files they do get differ from the web app's (wrong paper size for Australian schools, missing columns, collapsed lines).
- Recommended replacement: Re-port `planReportExport`, its skipped-entry reporting and the grouping/scope options from live V3, and match V3's column set. This is Commenter-specific logic, so custom code is correct here. Page size, language and line breaks come free with SwiftDocX (F5): `Paragraph` runs with breaks and section page size.
- Effort: M
- Confidence: High

### F11: No real third-party fixtures exist; tests prove the code agrees with itself
- Severity: High
- Kind: test-gap
- Where: fixtures/imports, fixtures/exports/expected, fixtures/golden-projects (all empty); Tests/CommenterImportExportTests/SpreadsheetImportFileTests.swift:357-380; BackupEnvelopeTests.swift:357-440; Tests/CommenterPersistenceTests/FileProjectStoreTests.swift (24 tests)
- What it does now:
  - The .xls reader is tested only on output of the app's own .xls writer, and the XLSX tests use hand-built zips.
  - The backup "web" fixtures are hand-built in the old V3 contract (F1), and none has `/` in its salt or iv (F2).
  - Nothing tests that DOCX, XLSX or XLS output opens in Word, Excel, Numbers or LibreOffice.
  - Persistence tests cover conflicts and damage handling, but not loading a project saved by an older model version (F9) or delete leaving `recovery/` behind (F8).
- Why it is like this: There is no Apple toolchain on the development host, and VALIDATION_LEDGER.md:199-200 and 785 list open validation as an outstanding gap.
- Why it matters: Every Critical/High correctness finding above (F1, F2, F3) passes the current suite. Green tests here do not mean the formats work.
- Recommended replacement: Commit real files: .xls and .xlsx saved by Excel and LibreOffice (including numbers, formulas and rich text), and plain and encrypted backups exported by current V3. Add golden DOCX/XLSX/XLS outputs, a model-version fixture, and a manual open-check log in VALIDATION_LEDGER.
- Effort: M
- Confidence: High

### F12: The SQLite index is written on every save but never read, so the two-store design adds failure modes and no value
- Severity: Medium
- Kind: architecture
- Where: Sources/CommenterPersistence/SQLiteProjectIndex.swift:12-115; ProjectStore.swift:338-369 (save with index rollback), 392-418 (delete), 520-522, 667-674 (ensureStorageLayout opens the database on every list/save/delete)
- What it does now:
  - Tables `projects` and `usage_ledger` are upserted on each save. No code anywhere runs a SELECT against them (grep of Sources). Listing decodes and fingerprints every `project.json` (213-266).
  - `usage_ledger` stores used variant IDs that the generator never reads; it uses the project's own reports (AppFeature/CommentEngineClient.swift:41).
  - Each operation constructs a new `FileProjectStore` (ProjectStoreClient.swift:104-217), and each index call opens a fresh `DatabaseQueue` (SQLiteProjectIndex.swift:117-120), so a single save opens SQLite three or four times. GRDB's documentation says to open one queue or pool per database for the app's lifetime (https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/databaseconnections).
  - A save can fail only because the unused index failed, which then triggers the file-restore rollback (350-368).
  - Rows store absolute paths, which break when the iOS container path changes.
- Why it is like this: The OSS policy says SQLite metadata/index work must use GRDB "once dependency migration begins". The index seems to be a port of a planned feature that never got a reader. No decision justifies keeping two stores.
- Why it matters: It doubles the persistence code paths and the error handling, and adds real failure and rollback cases for no user-visible benefit. This is exactly the "accident of an earlier model" pattern the owner asked about.
- Recommended replacement: Choose one store:
  - **Simplest:** delete SQLiteProjectIndex.swift and the GRDB dependency, keeping one JSON file per project with atomic writes (fine for a handful of classes of ≤ 40 students).
  - **Or:** move fully to GRDB 7.12.0 (https://github.com/groue/GRDB.swift) with one long-lived `DatabaseQueue`, `DatabaseMigrator` for schema versions (fixes F9), and `ValueObservation` for the project list. Projects would be stored as rows or JSON columns and the per-project files dropped.
  - SwiftData is not recommended: its Codable/JSON fingerprint parity with V3 and its testability are weaker.
- Effort: M
- Confidence: High

### F13: Three file-format dependencies are unmaintained, and two pins are behind
- Severity: Medium
- Kind: outdated-version
- Where: Package.swift:27-31; OOXMLZipWriter.swift:39, 99
- What it does now (upstream checked with `gh api` on 2026-11-15):

  | Package | Pinned | Latest | Upstream activity / notes |
  |---|---|---|---|
  | CodableCSV | 0.6.7 | 0.6.7 (2021-08) | last push 2023-11 |
  | CoreXLSX | 0.14.1 | 0.14.2 (2023-03) | last push 2024-03 |
  | OLEKit | 0.2.0 | 0.3.1 (2021-01) | last push 2023-02, 25 stars |
  | ZIPFoundation | 0.9.11 | 0.9.20 (2025-09-24) | 0.9.17 added throwing `Archive` initializers and deprecated the failable `Archive(data:accessMode:)` used at OOXMLZipWriter.swift:39 and 99; 0.9.18 fixed a path-escape vulnerability (not exploitable here because extraction is in-memory) |
  | GRDB | 7.10.0 | 7.12.0 | |
- Why it is like this: Exact pins were set during release hardening (DEPENDENCY_AUDIT.md "Release hardening update"). Nobody has re-checked maintenance since then.
- Why it matters: Under the Swift 6 language mode with full concurrency checking (the iOS 27 target), unmaintained packages are likely to produce strict-concurrency diagnostics that nobody upstream will fix.
- Recommended replacement:
  - **OLEKit:** delete via F3/F4.
  - **CodableCSV:** replace reading with Apple's TabularData `DataFrame(csvData:options:types:)` with every column typed `.string` (iOS 15+, https://developer.apple.com/documentation/tabulardata/dataframe). Writing a handful of template/CSV rows can use `DataFrame.csvRepresentation()` or a 20-line quoted writer. If TabularData's error detail proves too coarse, use swiftcsv/SwiftCSV 0.10.0 (MIT, last push 2025-12, https://github.com/swiftcsv/SwiftCSV).
  - **CoreXLSX:** keep for now. No maintained Swift XLSX reader has better adoption, and replacing it with ZIPFoundation plus XMLParser would be a disallowed "new XLSX parser". Re-check it under Swift 6 and fork it if it fails.
  - **ZIPFoundation:** bump to 0.9.20 and use `try Archive(data:accessMode:)`.
  - **GRDB:** bump to 7.12.0, or remove it (F12).
- Effort: S (bumps) / M (CSV swap)
- Confidence: High (versions); Medium (TabularData suitability for the row-level error messages)

### F14: CSV import wraps CodableCSV with three hand-written tokenizing passes, and non-UTF-8 files are decoded as UTF-16
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Sources/CommenterImportExport/CSVParser.swift:86-103, 207-286; SpreadsheetImportFile.swift:64-69
- What it does now:
  - `unquotedRowWidthMismatch` splits on `\n` and `,` itself, `normalizeUnquotedRowBreaks` is a quote-state machine that rewrites line endings, and `hasUnterminatedQuotedField` is a third scanner. Only then does CodableCSV parse. In effect this is a partial second CSV parser.
  - The file is decoded as UTF-8, otherwise as UTF-16. A Windows-1252 CSV (common from Excel on Windows, e.g. "Zoë") fails UTF-8, and an even byte count can "succeed" as UTF-16 garbage. The result is then a confusing header error instead of "save as UTF-8".
- Why it is like this: The passes were apparently added so that CodableCSV's errors could be turned into V3's row-level messages. No exception is recorded, and DEPENDENCY_AUDIT.md calls this "not a standalone CSV parser".
- Why it matters: The policy disallows "new CSV parsers". The encoding fallback gives teachers misleading errors.
- Recommended replacement: Use one maintained parser (F13) and derive row-width errors from its parsed rows (already done in `parseTabularRows`, 153-155). Detect a BOM explicitly; for files that are not valid UTF-8, either try `.windowsCP1252` or show "save the file as CSV UTF-8". Deletes about 110 lines.
- Effort: S
- Confidence: High

### F15: PBKDF2 is hand-written in a Swift HMAC loop and runs twice per encrypted export
- Severity: Medium
- Kind: hand-written-generic-code
- Where: Sources/CommenterImportExport/BackupEnvelope.swift:684-715; BackupFileWorkflow.swift:83-96 (encrypt, then decrypt again to verify)
- What it does now: The code implements PBKDF2-HMAC-SHA256 by hand with 650,000 iterations, allocating a new `Data` and `[UInt8]` on every iteration. Exporting derives the key twice (encrypt, then verify by decrypting), and each import attempt derives once. All of this runs synchronously inside an async dependency closure.
- Why it is like this: CryptoKit has no PBKDF2. Apple added post-quantum KEM/signatures and SHA-3 in iOS 26, but no password KDF. The author wrote PBKDF2 on top of CryptoKit's HMAC rather than using CommonCrypto. No recorded reason.
- Why it matters: Hand-rolled crypto carries review burden, and it is much slower than the optimised system routine, so the teacher waits seconds while it blocks a cooperative thread. The algorithm and parameters themselves are fine: 650k iterations exceeds OWASP's 600,000 minimum for PBKDF2-HMAC-SHA256 (https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), and they must match V3's WebCrypto, so Argon2id is not an option.
- Recommended replacement:
  - Apple CommonCrypto `CCKeyDerivationPBKDF(kCCPBKDF2, ..., kCCPRFHmacAlgSHA256, 650_000, ...)` (native since iOS 5, no dependency). Alternatively apple/swift-crypto `_CryptoExtras` `KDF.Insecure.PBKDF2` (https://github.com/apple/swift-crypto), but that adds a package for one call.
  - Deletes about 35 lines.
  - Derive once per export: reuse the key for the verification decrypt.
  - Also replace `SecRandomCopyBytes` with `SymmetricKey(size:)`/`AES.GCM.Nonce()`, and drop the `#if canImport(CryptoKit)` fallbacks, which are dead code on iOS 27.
- Effort: S
- Confidence: High (that it is custom); Medium (exact speed-up, which was not measured here)

### F16: Custom file types are never declared, so .cbackup is a dynamic type and backups cannot be opened into the app from Files or Mail
- Severity: Medium
- Kind: best-practice
- Where: Sources/AppFeature/Views/FilePresentation.swift:70-79; CommenterIOS.xcodeproj/project.pbxproj:339-346 (generated Info.plist, no UTExportedTypeDeclarations or CFBundleDocumentTypes); BackupFileWorkflow.swift:16-17
- What it does now: `UTType(filenameExtension: "cbackup", conformingTo: .json)` and `UTType(filenameExtension: "report-writer-backup.json")` are created at runtime. No type is declared, so the system mints dynamic `dyn.*` identifiers. Multi-dot "extensions" never match a filename extension, so those two types are inert. The `.json` entry is what actually lets plain backups through.
- Why it is like this: No recorded reason. Probably done to avoid editing the Xcode project.
- Why it matters: Whether the document picker reliably enables `.cbackup` files depends on dynamic-type matching. The teacher also cannot tap a backup in Mail or Files and choose "Open in Report Writer", which is the normal iOS way to move a file between apps.
- Recommended replacement: Declare an exported type, for example `<bundle-id>.cbackup` conforming to `public.json` with extension `cbackup`, in the target's Info.plist. Use `UTType(exportedAs:)` (https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/init(exportedas:conformingto:)) and add CFBundleDocumentTypes so backups open into the app. Delete the two multi-dot types.
- Effort: S
- Confidence: Medium (exact picker behaviour with dynamic types is not verified on device)

### F17: The persistence API is async in name only, doing blocking file and SQLite IO under a process-wide lock
- Severity: Medium
- Kind: best-practice
- Where: Sources/CommenterPersistence/ProjectStore.swift:157-161, 203-290, 994-1006; Sources/AppFeature/ProjectStoreClient.swift:102-237
- What it does now: The `async` methods call synchronous code that takes a global `NSRecursiveLock` (`ProjectStoreOperationCoordinator.shared`, shared by all stores whatever their root) and performs file IO, JSON coding, SHA-256 and SQLite opens on a Swift-concurrency cooperative thread. `saveProject(_:options:)` is not async at all and is called from async closures.
- Why it is like this: No recorded reason. The pattern predates the iOS 27 / Swift 6 decision.
- Why it matters: Under Swift 6 strict concurrency, the 2026 practice is to isolate this state in an `actor` (or rely on GRDB's own serialized queue) rather than block cooperative threads with locks. A recursive lock also hides re-entrancy bugs.
- Recommended replacement: Make the store an `actor`, or a `final class` owning one GRDB `DatabaseQueue` if F12 goes the GRDB way, created once and provided through the TCA dependency. Remove `ProjectStoreOperationCoordinator`.
- Effort: S–M
- Confidence: High

### F18: The write-then-verify pipeline and its helpers are copy-pasted five times
- Severity: Medium
- Kind: architecture
- Where: BackupFileWorkflow.swift:99-148, 180-199; ReportDocumentFile.swift:41-93, 124-143, 217-306; ReviewWorkbookFile.swift:44-100, 186-252, 266-285, 315-331; CSVTemplates.swift:251-343; ProjectStore.swift:423-460
- What it does now:
  - Five near-identical blocks each do: ensure directory → write atomically → stat size → read back and compare bytes → parse back → delete on failure.
  - Four error enums carry the same cases (`invalidDirectory`, `emptyWrittenFile`, `verificationFailed`, `failedOutputCouldNotBeRemoved`).
  - Other copies: `forbidden*ExportStrings`/`publicExportValues`/`uniqueForbiddenStrings` twice, XML escape/unescape twice, two OLE readers, two little-endian `Data` extensions.
  - The byte-for-byte read-back straight after `Data.write(.atomic)` proves little: atomic write already guarantees all-or-nothing replacement, and the read is served from cache.
  - The regex "XML verification" never checks well-formedness.
- Why it is like this: C004 ("verified" success) was applied by copying the first implementation into each new file.
- Why it matters: About 400 redundant lines and five places to fix the same bug. The checks that matter (does the parsed file contain what we meant, and is the XML valid) are weaker than the ceremony suggests.
- Recommended replacement: One internal `writeVerifiedFile(data:to:verify:)` helper and one error type. Keep the parse-back check, which is meaningful, and drop the raw byte comparison. Once F5/F6 adopt packages, verify by reopening with the same package's reader (SwiftDocX `Document(contentsOf:)`, CoreXLSX) rather than with regexes.
- Effort: M
- Confidence: High

### F19: Restoring a backup silently replaces the local project with the same ID; V3 offers Replace or Copy
- Severity: Medium
- Kind: missing-feature
- Where: Sources/AppFeature/Features/FileWorkflowFeature.swift:80-99, 185-218; Sources/CommenterImportExport/BackupEnvelope.swift:153-157, 268-293
- What it does now:
  - A backup whose project ID matches a local project is saved with `expectedRevision: nil`, overwriting newer local work (a snapshot is taken, but F8 means it cannot be restored).
  - `BackupImportChoice` (REPLACE/COPY/CANCEL) and `normalizeBackupImportChoice` exist but are unused.
  - The success text always says "A matching local project id was replaced only after a recovery snapshot was prepared", even when there was no match.
- Why it is like this: The choice API was ported (commit d11c855 "collision guard"), but the screen flow was never finished.
- Why it matters: A teacher restoring last week's backup to check something destroys this week's comments. The success message is inaccurate (C004).
- Recommended replacement: When the IDs collide, ask Replace or Keep both. Keep both re-IDs the project, as V3's restore-target logic does (C:\Commenterv3\client\src\lib\backup-restore-target.ts). Make the success message reflect what actually happened.
- Effort: S–M
- Confidence: High

### F20: File protection is set explicitly to the iOS default, and plaintext exports sit in tmp for up to 12 hours
- Severity: Low
- Kind: best-practice
- Where: ProjectStore.swift:924-934; ProtectedFileWrites.swift:291-302; ProjectStoreClient.swift:301-361
- What it does now: Every file and folder gets `FileProtectionType.completeUntilFirstUserAuthentication` after it is written. That is already the default class for third-party app data (Apple Platform Security, https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web), so the calls change nothing. Prepared backups (unencrypted) and reports stay in `tmp/ReportWriterExports` until they are discarded or the next launch purge after 12 hours.
- Why it is like this: No recorded reason.
- Why it matters: It is ceremony. A foreground-only app holding student data could use the stronger `.complete` or `.completeUnlessOpen` class.
- Recommended replacement: Write with `Data.WritingOptions.completeFileProtectionUnlessOpen` (or `.completeFileProtection`) and delete the separate `setAttributes` helpers. Discard prepared files when the export or share sheet completes, which mostly happens already, and also on scene background.
- Effort: S
- Confidence: Medium (the right class depends on whether any background work touches files)

### F21: Dead compatibility code in a pre-production app
- Severity: Low
- Kind: best-practice
- Where: ProjectStore.swift:63-65 (`verifyReadAfterWrite` "retained for source compatibility", ignored); BackupEnvelope.swift:19, 458, 482, 494, 556-568, 592-596, 619 (backup v1–v3 and encrypted v1 with empty AAD, 10-character "legacy" password minimum); ProjectFingerprint.swift:137-185 (`canImport(CryptoKit)` fallback)
- What it does now: The code keeps options and format versions that no shipped iOS app ever produced. Current V3 accepts only v4 and encrypted v2 (backup.ts:170-173).
- Why it is like this: Defensive porting.
- Why it matters: Extra branches to test and audit, and the app accepts weaker legacy encryption (no AAD, 10-character passwords) that V3 itself now refuses.
- Recommended replacement: Delete them, and accept exactly what V3 accepts (aligns with F1).
- Effort: S
- Confidence: High

### F22: Dependency audit and ledgers describe a different state from the code
- Severity: Low
- Kind: doc-stale
- Where: docs/dependencies/DEPENDENCY_AUDIT.md (SwiftDocX "latest observed 1.0.1", ZIP/XLS rows); docs/ledgers/DECISIONS_LEDGER.md (2026-05-31 entries)
- What it does now:
  - The audit says legacy XLS import "tries the fixture-limited local OLE compound-file extractor first, falls back to OLEKit". That is accurate, but the latest ledger entry describes OLEKit as the approved path and the local reader as superseded.
  - SwiftDocX is now 1.0.2 with header, footer and page-number support.
  - Neither document mentions the backup contract change in V3, the unused SQLite index, or the custom PBKDF2.
- Why it is like this: The documents were not updated after May/June 2026.
- Why it matters: Future agents will rely on outdated reasoning.
- Recommended replacement: Update both documents when F1–F15 are decided.
- Effort: S
- Confidence: High

## Keep (good as is)
- AES-256-GCM through CryptoKit with a fresh 16-byte salt and 12-byte nonce, 650k PBKDF2 iterations bounded 100k–1M, NFKC password normalisation, 12-character minimum: correct design, and it matches V3 and OWASP (only the KDF implementation should change, F15).
- `OOXMLZipWriter.storedEntries` bounded extraction (entry count, per-entry and total uncompressed caps): good zip-bomb protection; keep it as the generic adapter over ZIPFoundation.
- CoreXLSX adapter checks in `parseXLSX` (one workbook, sheet cap, duplicate relationship IDs, column-reference bounds, size caps before parsing): solid hardening around an unmaintained parser.
- Control-character and unresolved-placeholder blocking before export (ReportExportPreparation.swift:292-334): prevents invalid XML and template leaks.
- Import validation → preview → explicit confirm → save (ImportValidation, ImportPreviewPreparation, ProjectImportCommit): all-or-nothing, Commenter-specific, correctly custom.
- Atomic writes plus `expectedRevision` conflict detection in `FileProjectStore.saveProject`: a real protection against lost updates (keep it whichever store wins F12).
- Damaged-record handling (content-hash record IDs, quarantine instead of delete, labelled support copies): sound, if heavy.
- Content-sniffing of file signatures (ZIP/OLE versus extension) before parsing: good.
- Native `fileImporter`/`fileExporter` with security-scoped access (AppView.swift:211-225, ProjectStoreClient.swift:364-372): correct native flow, not re-implemented.
- The `UIActivityViewController` wrapper (ActivityShareSheet.swift): justified, because `ShareLink` gives no completion or cancel result and C004 needs one.
- Filename collision handling (`availableFileDestination`) and safe-filename sanitising: fine.

## Open questions for the owner
- Legacy .xls export (C005): it costs about 460 lines of hand-written BIFF/OLE with no maintained package to replace it, and it still needs Excel open-validation. Do schools still need .xls output in 2026, or would .xlsx plus .csv meet the requirement? (Not overruled here; C005 stands until you decide.)
- Recovery snapshots (F8): should the app offer a restore list with a time limit, or drop snapshots and make "Delete Project" erase everything immediately?
- Persistence store (F12): keep plain per-project JSON files and remove GRDB, or move entirely to GRDB? Either removes the unused second store. Plain files are simpler; GRDB gives migrations.
- Should a restored backup with a matching ID offer "Replace" and "Keep both" as V3 does (F19)?
- Blocked: no Swift/Xcode toolchain and no Excel/Word/Numbers on this host, so these were not verified here: the exact behaviour of dynamic UTTypes in the document picker (F16), whether Excel accepts the XF-less .xls (F7), and the PBKDF2 speed-up (F15).
