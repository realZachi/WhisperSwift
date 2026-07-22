# CI/CD Workflows

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `pr.yml` | Pull requests | All PR checks (lint, duplicates, build, tests) |
| `ci.yml` | Push to main | Full CI pipeline |
| `docs.yml` | Push to main | Documentation generation and publishing |

Releases are built locally with Developer ID signing and Apple notarization by
following `.release.md`. Tag pushes must not build or replace release assets.

## Local Pre-Commit Hook

Run `./scripts/setup-hooks.sh` once to enable local duplicate detection before commits.
