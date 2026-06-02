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

- Source raw SHA-256: `60BAB50DA5E7735AF545D39C1DF73EFD96A533B2871B83571A042ABF52E404F7`
- Bundled LF-normalized SHA-256: `438950A8A72DE0CE3B6B0E4271F95858D6519162C9F530A295E36722618B9572`
- Normalized source text equals bundled resource text after CRLF-to-LF
  normalization.
- Components: 56,564
- Recipes: 5
- Assembled variants: 4,340
- Uniqueness rules: 2
- Subjects: Dance, Design and Technologies, Digital Technologies, Drama,
  English, HASS, Health and P.E., Mathematics, Media Arts, Music, Science,
  Visual Arts

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

The Swift scaffold also ports CommenterV3 subject mapping for supported subject
aliases and aggregate subjects. `The Arts` and `Technologies` require a concrete
focus before generation can honestly proceed.

## Current Migrations

None.
