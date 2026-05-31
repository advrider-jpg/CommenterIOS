# Data Ledger

Append durable source data, generated artifact, fixture, schema, migration,
provenance, and data-assumption changes here.

## Source Data

The production source dataset is the live CommenterV3 file:

`C:\Commenterv3\client\public\data\comment-engine.json`

This dataset must be bundled into the iOS app as a local resource after the
SwiftUI/TCA project is scaffolded. Production runtime code must not use sample
fixtures as fallback data.

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

None.

## Current Migrations

None.
