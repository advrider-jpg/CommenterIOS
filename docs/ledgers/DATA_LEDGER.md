# Data Ledger

Append durable source data, generated artifact, fixture, schema, migration,
provenance, and data-assumption changes here.

## Source Data

The production source dataset is the live CommenterV3 file:

`C:\Commenterv3\client\public\data\comment-engine.json`

This dataset is bundled into the Swift package at:

`Sources/CommentEngine/Resources/comment-engine.json`

Production runtime code must not use sample fixtures as fallback data.

Current copied dataset evidence:

- Source raw SHA-256: `65E37D45A707CE7D3B18A79CFA06C0507DC7AECEEBF790F0005406DFE4D6B0EF`
- Bundled LF-normalized SHA-256: `C6D7F90C06F16C9D4B810BB076FB6647DE1C5831A1ED99E118F470A19F7F48F3`
- Normalized source text equals bundled resource text after CRLF-to-LF
  normalization.
- Components: 56,564
- Recipes: 5
- Assembled variants: 4,340
- Uniqueness rules: 2
- Subjects: Dance, Design and Technologies, Digital Technologies, Drama,
  English, HASS, Health and P.E., Mathematics, Media Arts, Music, Science,
  Visual Arts

The only approved dataset-copy transform is documented in
`docs/validation/DATASET_SOURCE_TRANSFORM.md` and enforced by
`scripts/validate_dataset_source_transform.py`: read the live CommenterV3 JSON
as UTF-8, replace CRLF line endings with LF, and otherwise preserve the JSON
bytes exactly.

## Source Behavior Map

The source map for porting behavior is:

`docs/source-truth/commenterv3-source-map.md`

Agents must inspect current source files before porting behavior.

## Implemented iOS Storage Model

The MVP storage model is canonical project JSON plus SQLite metadata and
indexes. Project JSON is the authoritative restorable record; SQLite is a
rebuildable local index and usage ledger rather than a second source of truth.

Canonical project JSON remains important for:

- backup compatibility
- deterministic fingerprints
- recovery snapshots
- portability between web and iOS
- transparent debugging and migration

SQLite metadata/indexes are implemented for:

- project listing
- revision, timestamp, fingerprint, and file-path metadata
- deterministic variant-usage ledger lookup

Recovery snapshots are verified JSON files managed alongside the canonical
project store; they are not represented as authoritative SQLite records.

## Fixture Boundaries

Fixtures belong under:

- `fixtures/golden-projects/`
- `fixtures/imports/`
- `fixtures/exports/expected/`

Fixtures are test-only. They must not be bundled into the production app as
runtime fallback data.

## Current Product Artifacts

The repository now contains production implementation surfaces rather than only
the initial scaffold:

- `Package.swift`
- `CommenterIOS.xcodeproj` and the native app host
- package targets under `Sources/` for domain, generation, persistence,
  import/export, report safety, on-device AI gates, App Intents, design system,
  and the application feature
- source-backed test targets under `Tests/`
- the bundled production comment-engine resource

## Teacher Import Template Artifacts

The app prepares the same class-list and report-details templates exposed by
live CommenterV3 in CSV, XLSX, and legacy XLS form. The spreadsheet variants use
the `Class List` and `Report Details` sheet names, respectively. Prepared files
are written atomically, protected, read back, structurally verified, and given a
collision-safe filename before the native save/share controls are enabled.

## Backup Envelope Contract

The implementation preserves the CommenterV3 backup wrapper contract:

- `format: "commenter-project-backup"`
- `version: 4` for new plaintext payloads; versions 1 through 4 remain readable
- `createdAt` ISO-8601 timestamp
- `checksum.algorithm: "sha256"`
- `checksum.projectFingerprint`
- `checksum.bundleFingerprint` for version 3 and later
- `project`

The fingerprint payload removes `metadata.persistence`, stable-sorts object
keys recursively, serializes to compact JSON, and hashes with SHA-256. This is
the source-truth contract from `C:\Commenterv3\client\src\lib\backup.ts` and
`C:\Commenterv3\client\src\lib\persistence-fingerprint.ts`. New iOS backups
emit the current version 4 payload with the canonical fingerprint for empty web
side stores. Imports fail openly when a web backup contains custom comments,
custom-comment usage, sticky notes, teacher profile, reporting preferences, or
structured reporting-period data that the iOS app cannot preserve. The
password-encrypted outer envelope remains its separate version 2 contract.

Native backup file import/export workflows preserve the internal
`commenter-project-backup` payload format for CommenterV3 compatibility. New
Report Writer backup files use the user-facing
`*.report-writer-backup.json` filename suffix; the legacy
`*.commenter-backup.json` suffix remains accepted for import compatibility.
Password-protected exports use CommenterV3's `.cbackup` extension and are
written, read back, decrypted, and compared with the source project before the
app reports a prepared file.

## Dataset Validation Contract

The implementation ports the source-truth dataset validation contract from
`C:\Commenterv3\client\src\lib\comment-engine-contract.ts`.

Validation now records:

- fatal errors for non-object roots, missing/non-array/non-object sections, empty
  eligible `ComponentBank`, and empty eligible `RecipeBank`
- warnings for object-shaped sections, duplicate component keys, duplicate
  variant IDs, empty eligible assembled variants, and empty uniqueness rules
- rejection counts for malformed records, missing required fields, unsupported
  component types, and orphaned variants
- eligible subject, band, and level lists
- uniqueness-rule values
- bracket placeholder counts

The Swift dataset model and production loader now preserve the V3 recipe-bank
metadata fields `ComponentMode` and `RequiredTypes` when present. Recipe
rendering uses those fields to distinguish sentence-component recipes from
phrase-component recipes and to reject declared component-slot mismatches before
generation can emit misleading assembled text.

The implementation also ports CommenterV3 subject mapping for supported subject
aliases and aggregate subjects. `The Arts` and `Technologies` require a concrete
focus before generation can honestly proceed.

## Current Migrations

None.
