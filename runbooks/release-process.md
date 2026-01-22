# Release Process Runbook

## Overview

This runbook describes how to create a new WhisperSwift release.

## Prerequisites

- Write access to the repository
- macOS with Xcode installed (for local testing)
- Git CLI configured

## Release Steps

### 1. Prepare the Release

1. Ensure all changes are merged to `main`:
   ```bash
   git checkout main
   git pull origin main
   ```

2. Update CHANGELOG.md:
   - Move items from [Unreleased] to new version section
   - Add release date
   - Ensure all notable changes are documented

3. Update version in Xcode project (if applicable):
   - Open `whisperswift.xcodeproj`
   - Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`

4. Commit version changes:
   ```bash
   git add CHANGELOG.md
   git commit -m "Prepare release v1.x.x"
   git push origin main
   ```

### 2. Create Release Tag

1. Create and push tag:
   ```bash
   git tag -a v1.x.x -m "Release v1.x.x"
   git push origin v1.x.x
   ```

2. GitHub Actions will automatically:
   - Build the release
   - Create DMG
   - Create GitHub Release with release notes

### 3. Verify Release

1. Check GitHub Actions workflow completed successfully
2. Download DMG from GitHub Releases
3. Test installation on a clean system:
   - Drag to Applications
   - Launch app
   - Verify permissions prompts
   - Test basic recording/transcription

### 4. Announce Release

1. Update any relevant documentation
2. Notify users through appropriate channels

## Rollback

If a release has critical issues:

1. Delete the GitHub Release (keeps tag for reference)
2. Create hotfix branch from main:
   ```bash
   git checkout -b hotfix/v1.x.x-fix
   ```
3. Fix the issue, test locally
4. Merge and create new patch release (v1.x.x+1)

## Manual DMG Creation (if needed)

For signed releases or if automation fails:

```bash
# Build Release
xcodebuild -project whisperswift.xcodeproj \
  -scheme whisperswift \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build

# Create DMG
APP_PATH="build/DerivedData/Build/Products/Release/WhisperSwift.app"
hdiutil create -volname "WhisperSwift" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "WhisperSwift-v1.x.x.dmg"
```

## Contacts

- Repository Owner: @realZachi
