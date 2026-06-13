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

## Planned iOS Storage Model

The intended MVP storage model is canonical project JSON plus SQLite metadata
and indexes.

Canonical project JSON remains important for:

- backup compatibility
- deterministic fingerprints
- recovery snapshots
- portability between web and iOS
- transparent debugging and migration

SQLite metadata/indexes are planned for:

- project listing
- revisions
- timestamps
- recovery snapshot lookup
- usage ledger lookup

## Fixture Boundaries

Fixtures belong under:

- `fixtures/golden-projects/`
- `fixtures/imports/`
- `fixtures/exports/expected/`

Fixtures are test-only. They must not be bundled into the production app as
runtime fallback data.

## Current Generated Artifacts

Initial generated/scaffolded app artifacts:

- `Package.swift`
- `Sources/`
- `Tests/`
- `.github/workflows/ios-ci.yml`

## Backup Envelope Contract

The Swift scaffold includes the CommenterV3 backup wrapper foundation:

- `format: "commenter-project-backup"`
- `version: 2` for new backups
- `createdAt` ISO-8601 timestamp
- `checksum.algorithm: "sha256"`
- `checksum.projectFingerprint`
- `project`

The fingerprint payload removes `metadata.persistence`, stable-sorts object
keys recursively, serializes to compact JSON, and hashes with SHA-256. This is
the source-truth contract from `C:\Commenterv3\client\src\lib\backup.ts` and
`C:\Commenterv3\client\src\lib\persistence-fingerprint.ts`.

Native backup file import/export workflows preserve the internal
`commenter-project-backup` payload format for CommenterV3 compatibility. New
Report Writer backup files use the user-facing
`*.report-writer-backup.json` filename suffix; the legacy
`*.commenter-backup.json` suffix remains accepted for import compatibility.

## Dataset Validation Contract

The Swift scaffold ports the source-truth dataset validation contract from
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

The Swift scaffold also ports CommenterV3 subject mapping for supported subject
aliases and aggregate subjects. `The Arts` and `Technologies` require a concrete
focus before generation can honestly proceed.

## Current Migrations

None.
