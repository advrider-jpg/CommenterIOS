# Dataset Source Transform

The release dataset is copied from the live CommenterV3 source file:

`C:\Commenterv3\client\public\data\comment-engine.json`

The bundled iOS resource is:

`Sources/CommentEngine/Resources/comment-engine.json`

The allowed transform is intentionally narrow:

1. Read the live CommenterV3 JSON file as UTF-8 bytes.
2. Replace CRLF line endings with LF line endings.
3. Write the normalized bytes as the bundled resource.
4. Do not sort, filter, reformat, synthesize, or otherwise mutate JSON content.

Current evidence:

- Source raw SHA-256: `65E37D45A707CE7D3B18A79CFA06C0507DC7AECEEBF790F0005406DFE4D6B0EF`
- Bundled normalized SHA-256: `C6D7F90C06F16C9D4B810BB076FB6647DE1C5831A1ED99E118F470A19F7F48F3`
- Components: 56,564
- Recipes: 5
- Assembled variants: 4,340
- Uniqueness guards: 2

Run `python scripts\validate_dataset_source_transform.py` after source-data
updates. A release must fail if the live source is unavailable, the source hash
changes without ledger updates, or the bundled bytes no longer match the
documented LF-normalized source bytes.
