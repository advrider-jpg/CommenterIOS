# Dependency Audit

## 2026-05-31 - OSS/native posture

Binding posture:
Use native Apple APIs and focused OSS packages for generic infrastructure.
Keep custom code for Commenter domain/product logic, deterministic generation,
truthful local persistence, format-specific validation rules, and small adapters
around native or OSS APIs. Do not write broad custom replacements for mature
generic infrastructure unless the app has a proven product need and fixtures to
justify the ownership cost.

Current package posture:

Release hardening update:
The manifest now pins all third-party packages with exact version constraints. A release machine still must run `swift package resolve` and commit the generated `Package.resolved` before public submission, because this audit environment cannot fetch GitHub-hosted package revisions.

| Package | Manifest constraint | License | Current role | Offline/local-first fit |
| --- | --- | --- | --- | --- |
| The Composable Architecture (`swift-composable-architecture`) | `exact: "1.17.0"` | MIT | App state, effects, dependency boundaries, and reducer tests. | Runs in-process with explicit side effects, helping keep save/import/export/generation states truthful and testable without network or backend services. |
| CodableCSV | `exact: "0.6.7"` | MIT | CSV parsing/writing infrastructure around Commenter-specific import/export validation. | Pure local file/data processing; suitable for offline teacher roster/result files when wrapped by all-or-nothing domain validation. |
| CoreXLSX | `exact: "0.14.1"` | Apache License 2.0 | XLSX parsing infrastructure for Open XML workbook support. | Pure local workbook parsing; appropriate for offline spreadsheet import/export workflows when paired with Commenter validation and explicit unsupported-path errors. |
| OLEKit | `exact: "0.2.0"` | Apache License 2.0, with bundled olefile-derived FreeBSD-style license notice | OLE compound file infrastructure for legacy Office binary containers. | Pure local binary-container handling; appropriate for legacy `.xls` work only as infrastructure, not as a substitute for full BIFF cell semantics. |
| GRDB.swift | `exact: "7.10.0"` | MIT | SQLite project index infrastructure in `CommenterPersistence`. | Pure local SQLite access; replaces direct `sqlite3` wrapper ownership with an approved local persistence dependency. |
| ZIPFoundation | `exact: "0.9.0"` | MIT | ZIP archive infrastructure for OOXML package assembly and verification. | Pure local archive read/write; appropriate as the generic ZIP layer for DOCX/XLSX payloads while higher-level document/workbook ownership remains under audit. |

License references:

- TCA: https://github.com/pointfreeco/swift-composable-architecture/blob/main/LICENSE
- CodableCSV: https://github.com/dehesa/CodableCSV/blob/0.6.7/LICENSE
- CoreXLSX: https://github.com/CoreOffice/CoreXLSX/blob/master/LICENSE.md
- OLEKit: https://github.com/CoreOffice/OLEKit/blob/master/LICENSE and https://github.com/CoreOffice/OLEKit/blob/master/LICENSE-olefile
- GRDB.swift: https://github.com/groue/GRDB.swift/blob/master/LICENSE
- ZIPFoundation: https://github.com/weichsel/ZIPFoundation/blob/development/LICENSE

Manifest/import consistency evidence:

- `Package.swift` declares package products for every third-party source import
  currently found under `Sources` and `Tests`: `ComposableArchitecture`,
  `CodableCSV`, `CoreXLSX`, `OLEKit`, `GRDB`, and `ZIPFoundation`.
- `CommenterPersistence` imports `GRDB` only in `SQLiteProjectIndex.swift`, and
  the target declares `.product(name: "GRDB", package: "GRDB.swift")`.
- `CommenterImportExport` imports `CodableCSV`, `CoreXLSX`, `OLEKit`, and
  `ZIPFoundation`, and the target declares each matching package product.
- `AppFeature` and `AppFeatureTests` import `ComposableArchitecture`, and both
  targets declare the matching package product.
- No `SwiftUIX`, `SwiftUIIntrospect`, `SwiftDocX`, `xlsxwriter`, `libxlsxwriter`,
  or `libxls` imports were found in the current source scan.

Custom generic infrastructure inventory from the current source scan:

| Area | Current source evidence | Policy status |
| --- | --- | --- |
| CSV parsing/writing | `Sources/CommenterImportExport/CSVParser.swift` imports `CodableCSV` and layers Commenter-specific header normalization, row limits, formula guarding, and tabular validation. | Compliant adapter posture; not a standalone CSV parser. |
| XLSX import | `Sources/CommenterImportExport/SpreadsheetImportFile.swift` imports `CoreXLSX` and maps worksheets into Commenter tabular validation. | Compliant adapter posture for XLSX import. |
| Legacy XLS import | `SpreadsheetImportFile.swift` tries the fixture-limited local OLE compound-file extractor first, falls back to `OLEKit` for OLE container reading, then decodes a narrow BIFF subset in custom code. | Temporary risk. This remains narrower than a full XLS reader, and full `.xls` parity needs `libxls`/equivalent evaluation or a recorded exception with fixture and target-app proof. |
| DOCX generation | `Sources/CommenterImportExport/ReportDocumentFile.swift` hand-assembles WordprocessingML XML entries and uses `OOXMLZipWriter` for packaging. | Policy risk. `SwiftDocX` is not in the manifest and has not replaced this hand-written DOCX layer; keep this only as a temporary bridge until SwiftDocX is evaluated against Commenter fixtures. |
| XLSX export | `Sources/CommenterImportExport/ReviewWorkbookFile.swift` hand-assembles SpreadsheetML XML entries and uses `OOXMLZipWriter` for packaging. | Policy risk. `libxlsxwriter`/approved XLSX writer evaluation is still required before treating this as release-complete infrastructure. |
| OOXML ZIP packaging | `Sources/CommenterImportExport/OOXMLZipWriter.swift` imports `ZIPFoundation` and handles duplicate-entry, size, required-entry, and readback validation. | Acceptable small adapter around approved ZIP infrastructure, provided document/workbook XML generation above is tracked separately. |
| Legacy XLS export | `Sources/CommenterImportExport/LegacyXLSWorkbookWriter.swift` hand-writes a narrow OLE compound file and BIFF workbook stream. | Highest remaining policy risk. No mature iOS SwiftPM BIFF writer is currently recorded as suitable; the code must stay fixture-limited and needs decision/validation evidence before release parity is claimed. |
| SQLite project index | `Sources/CommenterPersistence/SQLiteProjectIndex.swift` imports `GRDB`; no direct `sqlite3` import was found. | Compliant with the approved persistence dependency posture. |
| Reusable UI helpers | `Sources/DesignSystem` contains small SwiftUI views only; no SwiftUIX or introspection imports were found. | Compliant native SwiftUI posture for the current scan. |

Packages not added yet:

- SwiftUIX is not added now. The current UI posture uses native SwiftUI/HIG
  controls, and no owned wrapper need has been proven.
- SwiftUI Introspect is not added now. No current native UX requirement has
  proven that UIKit/AppKit introspection is needed.

Either package may be added later only behind owned wrappers, with a documented
native UX need, tests or simulator evidence for the behavior being unlocked, and
no user-visible path that pretends unsupported behavior works.

Remaining risk:
Legacy `.xls` parity is not complete merely because OLE container support
exists. Full production BIFF cell decoding/writing still needs either mature
`libxls`/`libxlsxwriter` integration or a documented production-grade
compatibility reason backed by real fixtures and target-app validation. Until
then, `.xls` work must keep surfacing incomplete coverage honestly.
## 2026-05-31 - DOCX, ZIP, XLSX writer, and legacy XLS package suitability

Scope:
This is a dependency/package suitability sidecar only. It does not approve
manifest, source, or test edits by itself. Before adding any package below,
prove the exact package revision with `swift package resolve`, `swift test`,
`xcodebuild`, simulator/device file workflows, and target-app open validation.

Product constraints checked:

- iOS SwiftPM/Xcode integration must work without manual host installs in CI.
- All document and workbook work must remain local/offline and must not transmit
  teacher, student, project, or report data.
- Every success state must be backed by a real written file, nonzero size,
  package/readback verification, native export/share completion where relevant,
  and target-app open proof for release.
- Licenses must be permissive enough for App Store distribution and must be
  included in third-party notices.

Package findings:

| Area | Exact package checked | Suitability | Build and compatibility concerns | Licensing concerns | Custom adapter exception |
| --- | --- | --- | --- | --- | --- |
| DOCX generation | `Techopolis/SwiftDocX`, latest observed `1.0.1`, manifest URL `https://github.com/Techopolis/SwiftDocX.git`, product `SwiftDocX` | Promising but not mature enough to treat as proven production infrastructure yet. It is pure Swift, supports SwiftPM, declares iOS 13+, and depends on ZIPFoundation. It should be evaluated before any further custom DOCX writer work. | Small/young project footprint observed upstream. Must prove it can create the required Commenter packet: title page, per-student sections, headings, headers, footers, page numbers, page breaks, paragraph spacing, XML escaping, and no unresolved placeholders. Must open in Word and Pages after iOS export/share. | MIT license. ZIPFoundation transitive MIT notice also required. | A small Commenter adapter from `PreparedReportPacket` to SwiftDocX document calls is justified. A broad custom DOCX XML/package writer is not justified unless SwiftDocX fails a documented fixture/open-validation matrix. |
| ZIP/OOXML assembly | `weichsel/ZIPFoundation`, recommended manifest URL `https://github.com/weichsel/ZIPFoundation.git`, product `ZIPFoundation` | Suitable generic ZIP infrastructure. It is mature, SwiftPM-compatible, supports Apple platforms including iOS, and is local/offline. Use for direct OOXML package read/write only when a higher-level DOCX/XLSX package does not own the ZIP layer. | Must verify deterministic archive output is not required by any fingerprint contract. Must verify in-memory and temp-file behavior on iOS sandbox for expected file sizes. | MIT license. | A small adapter that writes or reads required OOXML entries through ZIPFoundation is justified. A custom ZIP writer/reader is not justified. |
| XLSX writing, direct C package | `jmcnamara/libxlsxwriter`, latest observed `v1.2.4`, manifest URL `https://github.com/jmcnamara/libxlsxwriter.git`, product `libxlsxwriter` | Best candidate for XLSX export if a thin Swift adapter is acceptable. Swift Package Index reports iOS build compatibility, and upstream says the library creates XLSX files, supports text/numbers/formulas/hyperlinks, works on iOS, and uses zlib. | It is a C API, not a Swift-native model. Must prove SwiftPM/Xcode can link zlib for app and tests, temp-file behavior works in the iOS sandbox, output omits private fields, formula-leading strings are neutralized, and output opens in Excel, Numbers, and LibreOffice. Must pin a release, not a moving branch. | FreeBSD license plus bundled third-party notices for FreeBSD macros, zlib/minizip, tmpfileplus MPL 2.0 unless compiled out, optional DTOA MIT-style notice, and optional MD5 public-domain/BSD-style notice. Legal/notices review required. | A small Swift adapter from `ReportReviewRow`/template rows to libxlsxwriter calls is justified. Custom XLSX XML generation is not justified if this package builds and passes fixture/open validation. |
| XLSX writing, Swift wrapper | `damuellen/xlsxwriter.swift`, manifest URL `https://github.com/damuellen/xlsxwriter.swift`, product `xlsxwriter` | Not the preferred route unless direct `jmcnamara/libxlsxwriter` proves worse. The wrapper exposes Swift ergonomics, but its README still describes manual libxlsxwriter installation in places and branch-based SPM usage. | Must prove the selected branch/tag builds on iOS through SwiftPM without manual host-installed C libraries and without a floating branch in release code. The wrapper has lower adoption than upstream libxlsxwriter. | Wrapper license file mirrors libxlsxwriter/freeBSD and bundled third-party notices; verify wrapper-specific copyright and notices before shipping. | A wrapper adapter is acceptable only if it reduces code while preserving pinned, reproducible SwiftPM builds. Otherwise use direct libxlsxwriter. |
| Legacy XLS BIFF parsing | `libxls/libxls`, latest observed `1.6.3`, URL `https://github.com/libxls/libxls` | Best mature parser candidate for binary `.xls` import semantics, but not drop-in for this repo yet. It reads old OLE/BIFF XLS, has in-memory parsing APIs, fuzzing history, and CI on Mac/Linux/Windows. | No first-party SwiftPM manifest was observed. It uses autotools/configure rather than a direct iOS SwiftPM package. Must prove an iOS-compatible module map or vendored SwiftPM target can build reproducibly in CI before replacing the current OLEKit-plus-BIFF adapter. | BSD 2-clause license. Include notices. | A small import adapter on top of libxls is justified if the package can be vendored cleanly. Until that proof exists, a narrowly scoped BIFF parser on top of OLEKit remains temporarily justified only for required fixture-backed cells. |
| Legacy XLS BIFF writing | `libxls/libxls` plus search for mature Swift/iOS BIFF writers | No suitable mature SwiftPM/iOS writer was found in this audit. `libxls` is read-focused and is not an XLS writer. `libxlsxwriter` writes only modern `.xlsx`, not legacy BIFF `.xls`. | Because legacy `.xls` export is MVP-required, either find a maintained iOS-compatible BIFF writer in a future audit or keep the smallest possible custom BIFF8/OLE writer with hard limits. Must pass real `.xls` fixtures and open in Excel/LibreOffice/Numbers where supported. | Any custom exception must avoid pulling in unclear-license code snippets. If a future writer is found, license must be re-audited. | A small custom XLS writer exception remains justified for now, but only as a recorded exception with row/column/cell-size limits, OLE/BIFF structural tests, and target-app open validation. |

Recommended next package posture:

1. Add/evaluate `ZIPFoundation` before touching any direct OOXML ZIP assembly.
2. Evaluate `SwiftDocX` for DOCX generation behind a narrow
   `PreparedReportPacket` adapter. Keep the existing custom DOCX output only as
   a temporary bridge until SwiftDocX passes or fails documented fixtures.
3. Prefer direct `jmcnamara/libxlsxwriter` over `damuellen/xlsxwriter.swift`
   for XLSX export unless the wrapper proves a pinned iOS SwiftPM release with
   better ergonomics and no manual native dependency steps.
4. Evaluate `libxls` only for legacy `.xls` import, not export.
5. Keep a temporary custom legacy `.xls` writer exception only because no mature
   iOS SwiftPM BIFF writer was identified. The exception is not release-complete
   until real workbook fixtures and target-app open checks pass.

Sources checked:

- SwiftDocX: `https://github.com/Techopolis/SwiftDocX`,
  `https://raw.githubusercontent.com/Techopolis/SwiftDocX/master/Package.swift`,
  `https://raw.githubusercontent.com/Techopolis/SwiftDocX/master/LICENSE`
- ZIPFoundation: `https://github.com/weichsel/ZIPFoundation`,
  `https://raw.githubusercontent.com/weichsel/ZIPFoundation/development/Package.swift`,
  `https://raw.githubusercontent.com/weichsel/ZIPFoundation/development/LICENSE`
- libxlsxwriter: `https://swiftpackageindex.com/jmcnamara/libxlsxwriter`,
  `https://raw.githubusercontent.com/jmcnamara/libxlsxwriter/main/Package.swift`,
  `https://libxlsxwriter.github.io/`,
  `https://libxlsxwriter.github.io/getting_started.html`,
  `https://raw.githubusercontent.com/jmcnamara/libxlsxwriter/main/License.txt`
- xlsxwriter.swift: `https://github.com/damuellen/xlsxwriter.swift`,
  `https://raw.githubusercontent.com/damuellen/xlsxwriter.swift/main/Package.swift`,
  `https://raw.githubusercontent.com/damuellen/xlsxwriter.swift/main/License.txt`
- libxls: `https://github.com/libxls/libxls`,
  `https://raw.githubusercontent.com/libxls/libxls/master/README.md`,
  `https://raw.githubusercontent.com/libxls/libxls/master/LICENSE`,
  `https://raw.githubusercontent.com/libxls/libxls/master/configure.ac`
