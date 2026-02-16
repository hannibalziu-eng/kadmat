# Commit Batches (Recommended)

This file defines safe commit slicing for the current large working tree.

## Batch 1: Hygiene + Governance
```bash
git add \
  .gitignore \
  README.md \
  .github/workflows/repo_hygiene.yml \
  scripts/repo_hygiene_check.sh \
  scripts/clean_local_artifacts.sh \
  scripts/repo_status_report.sh \
  docs/REPO_TREE_CLEANUP_PLAN.md \
  docs/REPO_STRUCTURE.md \
  docs/CLEANUP_CLASSIFICATION.md \
  docs/COMMIT_BATCHES.md
```

## Batch 2: Backend Runtime + DB
```bash
git add backend/src backend/migrations backend/sql backend/scripts backend/tests backend/package.json backend/package-lock.json
```

## Batch 3: Flutter Runtime
```bash
git add lib pubspec.yaml pubspec.lock
```

## Batch 4: Flutter Tests + Supporting Infra
```bash
git add test analysis_options.yaml android ios macos windows .github/workflows/ci.yml
```

## Notes
- Review each batch with `git diff --staged` before commit.
- Run validation after each commit batch where possible.
- Keep commit messages explicit (scope + intent + risk).
