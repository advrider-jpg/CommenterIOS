# CommenterV3 Source Truth Map

Use the live `C:\Commenterv3` checkout as source of truth. Do not implement from
memory alone.

## Binding Project Rules

- `C:\Commenterv3\AGENTS.md`
- `C:\Commenterv3\docs\ledgers\CORE_RULES.md`
- `C:\Commenterv3\HARDENING_NOTES.md`

## Production Data

- `C:\Commenterv3\client\public\data\comment-engine.json`
- `C:\Commenterv3\client\src\lib\comment-engine-contract.ts`
- `C:\Commenterv3\client\src\lib\data-loader.ts`

## Domain Types

- `C:\Commenterv3\client\src\lib\types.ts`
- `C:\Commenterv3\client\src\lib\project-domain.ts`
- `C:\Commenterv3\client\src\lib\project-validation.ts`
- `C:\Commenterv3\client\src\lib\project-limits.ts`

## Persistence

- `C:\Commenterv3\client\src\lib\db.ts`
- `C:\Commenterv3\client\src\lib\persistence-fingerprint.ts`
- `C:\Commenterv3\client\src\lib\project-session.ts`
- `C:\Commenterv3\client\src\lib\wizard-draft.ts`

## Backup

- `C:\Commenterv3\client\src\lib\backup.ts`
- backup-related tests in `C:\Commenterv3\client\src\lib\*.test.ts`

## Import

- `C:\Commenterv3\client\src\lib\csv.ts`
- `C:\Commenterv3\client\src\lib\csv-templates.ts`
- `C:\Commenterv3\client\src\lib\spreadsheet.ts`
- `C:\Commenterv3\client\src\lib\import-validation.ts`

## Generation

- `C:\Commenterv3\client\src\lib\generator.ts`
- `C:\Commenterv3\client\src\lib\subject-mapping.ts`
- `C:\Commenterv3\client\src\lib\report-readiness.ts`
- `C:\Commenterv3\client\src\lib\report-context-fields.ts`
- `C:\Commenterv3\client\src\lib\teacher-text-repair.ts`

## Export

- `C:\Commenterv3\client\src\lib\export.ts`
- `C:\Commenterv3\client\src\lib\spreadsheet.ts`

## Current UI Reference

Do not clone these screens blindly; use them to understand workflows and copy.

- `C:\Commenterv3\client\src\App.tsx`
- `C:\Commenterv3\client\src\pages\Dashboard.tsx`
- `C:\Commenterv3\client\src\pages\Wizard.tsx`
- `C:\Commenterv3\client\src\pages\ProjectDetail.tsx`
- `C:\Commenterv3\client\src\pages\Diagnostics.tsx`
- `C:\Commenterv3\client\src\components\StudentListStep.tsx`
- `C:\Commenterv3\client\src\components\SubjectSelectionStep.tsx`
- `C:\Commenterv3\client\src\components\AchievementResultsStep.tsx`
- `C:\Commenterv3\client\src\components\ReportGenerationStep.tsx`

## Existing Validation Commands

Useful for source behavior checks:

- `npm run check`
- `npm test`
- `npm run fixtures:check`
- `npm run build`
- `npm run build:static`
- `npm run test:e2e`
- `npm run test:static`
- `npm run test:launcher`
- `npm run test:coverage`
- `npm run verify`

