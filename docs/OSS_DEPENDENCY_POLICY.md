# OSS Dependency Policy

This document is binding project policy. Agents must read it before changing
`Package.swift`, import/export code, persistence code, file workflows, or reusable
UI infrastructure.

## Rule

Prefer mature OSS packages and Apple-native APIs over custom generic
infrastructure. Custom code is allowed for Commenter-specific behavior and for
small adapters around approved dependencies. Custom parsers, document writers,
database wrappers, file-flow abstractions, navigation frameworks, or UI
primitive systems are disallowed unless this file or a later decision ledger
entry records a specific exception.

Truthfulness does not mean downgrading required MVP scope to unsupported. It
means the required workflow must be implemented through real native/OSS-backed
operations, and success can be shown only after the operation actually completes.

## Apple-Native Baseline

Use these platform APIs before adding package or custom code:

- SwiftUI for view structure, forms, lists, navigation, sheets, alerts, and
  accessibility.
- UniformTypeIdentifiers for import/export type declarations.
- FileDocument, fileImporter, fileExporter, ShareLink, and native document/share
  flows for iOS file workflows.
- Foundation Codable, JSONEncoder, JSONDecoder, FileManager, URL, Date, and
  Data for backup JSON and simple file IO.
- CryptoKit for hashes/fingerprints where it satisfies the existing contract.
- XCTest plus TCA TestStore for reducer and adapter tests.

Do not wrap these APIs with broad custom frameworks. A wrapper should only adapt
native results to TCA actions or Commenter domain types.

## Required Swift Packages

These packages are the approved dependency baseline. Prefer the packages already
added by the current worker when possible.

| Area | Package | Manifest entry | Product | Status | Source |
| --- | --- | --- | --- | --- | --- |
| TCA architecture | `pointfreeco/swift-composable-architecture` | `.package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0")` | `ComposableArchitecture` | Required; already used by worker | https://github.com/pointfreeco/swift-composable-architecture |
| CSV import/export | `dehesa/CodableCSV` | `.package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7")` | `CodableCSV` | Required; already used by worker | https://github.com/dehesa/CodableCSV |
| XLSX import | `CoreOffice/CoreXLSX` | `.package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.1"))` | `CoreXLSX` | Required; already used by worker | https://github.com/CoreOffice/CoreXLSX |
| Legacy XLS/OLE container | No current package | N/A | N/A | Exception: OLEKit was removed after CI exposed a process-level crash path; keep only the fixture-limited local extractor until `libxls` or another iOS-compatible parser is proven. | See decision ledger |
| SQLite project index | `groue/GRDB.swift` | `.package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")` | `GRDB` | Required before further custom SQLite work | https://github.com/groue/GRDB.swift |
| ZIP/OOXML package assembly | `weichsel/ZIPFoundation` | `.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")` | `ZIPFoundation` | Required for any direct ZIP/OOXML package work not fully handled by another dependency | https://github.com/weichsel/ZIPFoundation |
| DOCX generation | `Techopolis/SwiftDocX` | `.package(url: "https://github.com/Techopolis/SwiftDocX.git", from: "1.0.0")` | `SwiftDocX` | Required evaluation before custom DOCX writer changes | https://github.com/Techopolis/SwiftDocX |

## Approved UI Helper Packages

These are allowed only behind owned design-system wrappers. They should not
define product behavior or replace native SwiftUI/HIG defaults.

| Area | Package | Manifest entry | Product | Status | Source |
| --- | --- | --- | --- | --- | --- |
| SwiftUI helper views | `SwiftUIX/SwiftUIX` | Pin to a reviewed revision or compatible tag; do not leave a floating branch in release code | `SwiftUIX` | Approved only when native SwiftUI would otherwise require custom generic UI code | https://github.com/SwiftUIX/SwiftUIX |
| UIKit/AppKit introspection | `siteline/SwiftUI-Introspect` | Pin to a Swift 5.10-compatible release/revision before use | `SwiftUIIntrospect` | Approved only for specific native behavior not exposed by SwiftUI | https://github.com/siteline/SwiftUI-Introspect |

## Conditional Candidates

These packages are not yet approved as required dependencies, but must be
evaluated before writing or keeping custom generic infrastructure in their area.

| Area | Candidate | Status | Required proof before use or rejection |
| --- | --- | --- | --- |
| XLSX writing | `damuellen/xlsxwriter.swift` or another maintained SwiftPM/libxlsxwriter wrapper | Candidate only | Must build on iOS through SwiftPM without manual host installs, support release CI, and have acceptable license/attribution. If rejected, document why before keeping any custom XLSX writer. |
| Legacy XLS BIFF parsing/writing | `libxls` or another maintained iOS-compatible option | Candidate only | Must build for iOS, parse BIFF Workbook streams, and pass real fixture tests. If no suitable package exists, keep only the smallest Commenter-specific BIFF/OLE adapter with fixtures and a decision-ledger exception. |

## Custom-Code Limits

Allowed custom code:

- Commenter domain models and validation contracts.
- Source-truth mapping from CommenterV3 data into Swift types.
- Report-generation parity logic that is specific to Commenter.
- Backup compatibility with CommenterV3 envelopes.
- Small adapters from approved packages/native APIs into Commenter types.
- TCA feature reducers and views that express product behavior.

Disallowed custom code unless a decision ledger entry grants an exception:

- New CSV parsers.
- New XLSX parsers.
- New OLE container readers beyond the recorded fixture-limited legacy XLS exception.
- New SQLite wrapper layers below GRDB.
- New DOCX/OOXML ZIP writers when SwiftDocX or ZIPFoundation can cover the
  generic portion.
- Broad file picker/share/export abstractions beyond TCA/native-result adapters.
- Broad design-system primitives that duplicate SwiftUI, SwiftUIX, or
  SwiftUI-Introspect.
- Giant root features/views that bypass the planned TCA feature tree.

## Required Adapter Boundaries

- `CommenterImportExport` may adapt CodableCSV, CoreXLSX,
  ZIPFoundation, SwiftDocX, or an approved XLSX/XLS writer into Commenter import
  rows and export payloads. It must not own broad generic parser/writer engines.
- `CommenterPersistence` must use GRDB for SQLite metadata/index work once
  dependency migration begins. Direct `sqlite3` calls may remain only as legacy
  code until replaced, or behind a documented exception.
- `AppFeature` and subfeatures may use TCA dependency clients. Reducers must not
  perform direct file IO, document generation, database work, or package parsing.
- `DesignSystem` may wrap SwiftUI, SwiftUIX, and SwiftUI-Introspect into small
  product components. It must not become a custom UI framework.

## Dependency-Audit Gate

Before an agent implements or edits generic infrastructure, it must answer in
the worklog or decision ledger:

1. Which approved package/native API covers this?
2. If no package is used, which package was checked and why was it rejected?
3. What is the smallest allowed custom adapter?
4. Which fixtures/tests prove the adapter works?

Skipping this gate is a process failure. Shipping custom generic infrastructure
without this gate is a release blocker.
