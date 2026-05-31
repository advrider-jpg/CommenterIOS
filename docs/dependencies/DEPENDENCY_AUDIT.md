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

| Package | Manifest constraint | License | Current role | Offline/local-first fit |
| --- | --- | --- | --- | --- |
| The Composable Architecture (`swift-composable-architecture`) | `from: "1.17.0"` | MIT | App state, effects, dependency boundaries, and reducer tests. | Runs in-process with explicit side effects, helping keep save/import/export/generation states truthful and testable without network or backend services. |
| CodableCSV | `from: "0.6.7"` | MIT | CSV parsing/writing infrastructure around Commenter-specific import/export validation. | Pure local file/data processing; suitable for offline teacher roster/result files when wrapped by all-or-nothing domain validation. |
| CoreXLSX | `.upToNextMinor(from: "0.14.1")` | Apache License 2.0 | XLSX parsing infrastructure for Open XML workbook support. | Pure local workbook parsing; appropriate for offline spreadsheet import/export workflows when paired with Commenter validation and explicit unsupported-path errors. |
| OLEKit | `.upToNextMinor(from: "0.2.0")` | Apache License 2.0, with bundled olefile-derived FreeBSD-style license notice | OLE compound file infrastructure for legacy Office binary containers. | Pure local binary-container handling; appropriate for legacy `.xls` work only as infrastructure, not as a substitute for full BIFF cell semantics. |

License references:

- TCA: https://github.com/pointfreeco/swift-composable-architecture/blob/main/LICENSE
- CodableCSV: https://github.com/dehesa/CodableCSV/blob/0.6.7/LICENSE
- CoreXLSX: https://github.com/CoreOffice/CoreXLSX/blob/master/LICENSE.md
- OLEKit: https://github.com/CoreOffice/OLEKit/blob/master/LICENSE and https://github.com/CoreOffice/OLEKit/blob/master/LICENSE-olefile

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
