# CI/CD Workflows

GitHub Actions workflows in `.github/workflows/`:

| Workflow | Purpose |
|----------|---------|
| `ci.yml` | Build, lint (SwiftLint), test, code coverage |
| `duplicate-detection.yml` | Code duplication detection via jscpd |
| `docs.yml` | Documentation generation and publishing |
| `pr-review.yml` | Automated PR review |
| `release.yml` | Release build, notarization, DMG generation |
