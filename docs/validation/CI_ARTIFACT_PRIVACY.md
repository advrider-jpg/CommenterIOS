# CI Artifact Privacy

CI artifacts must remain diagnostic and fixture-only. Workflows may upload only
the current allowlisted build/test logs, `.xcresult` bundles, and verified
core-flow screenshot PNGs produced by the screenshot UI test.

Do not upload app container directories, generated project files, backups,
imports, exports, raw simulator data, arbitrary DerivedData trees, or broad
workspace globs.

Run `python scripts/validate_ci_artifact_privacy.py` after editing GitHub
Actions artifact uploads. The script rejects unapproved artifact names and
paths in `.github/workflows/ios-ci.yml` and
`.github/workflows/ios-screenshots.yml`.
