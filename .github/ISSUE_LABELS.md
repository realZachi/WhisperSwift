# Issue Labels

This document describes the labeling system used for issues and pull requests in the WhisperSwift repository.

## Label Categories

### Type Labels

| Label | Description | Color |
|-------|-------------|-------|
| `bug` | Something isn't working as expected | `#d73a4a` (red) |
| `enhancement` | New feature or improvement request | `#a2eeef` (cyan) |
| `documentation` | Documentation improvements | `#0075ca` (blue) |
| `question` | Further information is requested | `#d876e3` (purple) |
| `refactor` | Code refactoring without functional changes | `#fbca04` (yellow) |

### Priority Labels

| Label | Description | Color |
|-------|-------------|-------|
| `priority: critical` | Must be fixed immediately | `#b60205` (dark red) |
| `priority: high` | Should be fixed soon | `#d93f0b` (orange) |
| `priority: medium` | Normal priority | `#fbca04` (yellow) |
| `priority: low` | Nice to have, not urgent | `#0e8a16` (green) |

### Status Labels

| Label | Description | Color |
|-------|-------------|-------|
| `needs-triage` | Needs initial review and categorization | `#e4e669` (light yellow) |
| `needs-info` | Waiting for more information from reporter | `#d4c5f9` (lavender) |
| `in-progress` | Currently being worked on | `#1d76db` (blue) |
| `blocked` | Blocked by another issue or external factor | `#b60205` (dark red) |
| `ready-for-review` | Ready for code review | `#0e8a16` (green) |

### Component Labels

| Label | Description | Color |
|-------|-------------|-------|
| `area: audio` | Related to audio recording | `#c5def5` (light blue) |
| `area: transcription` | Related to Groq API/transcription | `#c5def5` (light blue) |
| `area: ui` | Related to user interface | `#c5def5` (light blue) |
| `area: hotkeys` | Related to hotkey detection | `#c5def5` (light blue) |
| `area: text-insertion` | Related to text insertion/pasting | `#c5def5` (light blue) |
| `area: permissions` | Related to macOS permissions | `#c5def5` (light blue) |

### Special Labels

| Label | Description | Color |
|-------|-------------|-------|
| `good first issue` | Good for newcomers to the project | `#7057ff` (purple) |
| `help wanted` | Extra attention is needed | `#008672` (teal) |
| `dependencies` | Dependency updates (used by Dependabot) | `#0366d6` (blue) |
| `github-actions` | CI/CD workflow changes | `#000000` (black) |
| `duplicate` | This issue or PR already exists | `#cfd3d7` (gray) |
| `wontfix` | This will not be worked on | `#ffffff` (white) |
| `invalid` | This doesn't seem right | `#e4e669` (yellow) |

## Label Usage Guidelines

### When Creating Issues

1. **Type**: Always apply exactly one type label (`bug`, `enhancement`, etc.)
2. **Priority**: Apply priority label after triage (maintainers only)
3. **Component**: Apply relevant `area:` labels to categorize
4. **Status**: New issues get `needs-triage` automatically via templates

### When Working on Issues

1. Add `in-progress` when you start working
2. Remove `in-progress` and add `ready-for-review` when opening a PR
3. Add `blocked` if waiting on external factors

### For Pull Requests

- PRs inherit type labels from linked issues
- Add `dependencies` for Dependabot PRs
- Add `github-actions` for CI/CD changes

## Automation

- Issue templates automatically apply `needs-triage` and type labels
- Dependabot applies `dependencies` label automatically
- Stale issues may receive `stale` label after inactivity
