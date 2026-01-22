# Release Process Runbook

This runbook documents the complete process for building, signing, notarizing, and publishing a new WhisperSwift release.

## Pre-Release Checklist

Before starting the release process, verify:

- [ ] All features for this release are merged to main
- [ ] All CI checks pass on main branch
- [ ] Version number updated in project settings
- [ ] CHANGELOG updated with release notes
- [ ] All known critical bugs are fixed
- [ ] Tested on target macOS versions (13.0+)
- [ ] API key rotation runbook is up to date

### Version Number Locations

Update version in these locations:

1. **Xcode Project**: Target > General > Version and Build
2. **AboutView.swift**: Update version string if hardcoded

## Prerequisites

### Required Tools

- Xcode Command Line Tools
- Valid Developer ID Application certificate
- Apple Developer account with notarization credentials
- `notarytool` keychain profile configured

### Set Up Notarization Profile (One-Time)

```bash
# Store credentials in keychain (replace placeholders)
xcrun notarytool store-credentials "whisperswift-notarize" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

Generate an app-specific password at [appleid.apple.com](https://appleid.apple.com).

## Step 1: Clean Build Environment

```bash
cd /path/to/localwhisper

# Remove previous build artifacts
rm -rf build/
rm -rf ~/Library/Developer/Xcode/DerivedData/whisperswift-*
```

## Step 2: Build Release

```bash
# Build with Developer ID signing
xcodebuild -project whisperswift.xcodeproj \
  -scheme whisperswift \
  -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build
```

**Replace placeholders**:
- `Your Name` - Your developer name
- `TEAM_ID` / `YOUR_TEAM_ID` - Your Apple Developer Team ID

### Verify Build

```bash
# Check the app was built
ls -la build/DerivedDataRelease/Build/Products/Release/WhisperSwift.app

# Verify code signature
codesign -dv --verbose=4 build/DerivedDataRelease/Build/Products/Release/WhisperSwift.app
```

## Step 3: Create Styled DMG

```bash
# Set variables
APP_NAME="WhisperSwift"
VOL_NAME="WhisperSwift"
DERIVED="build/DerivedDataRelease"
APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
DMG_RW="build/${APP_NAME}.rw.dmg"
DMG_FINAL="build/${APP_NAME}.dmg"

# Clean previous DMGs
rm -f "$DMG_RW" "$DMG_FINAL"

# Create writable DMG
hdiutil create -size 200m -fs HFS+ -volname "$VOL_NAME" -ov "$DMG_RW"

# Mount it
MOUNT_INFO=$(hdiutil attach -nobrowse -readwrite "$DMG_RW")
DEVICE=$(echo "$MOUNT_INFO" | awk '/^\/dev\// {print $1; exit}')
MOUNT_POINT="/Volumes/$VOL_NAME"

# Copy app and create Applications symlink
cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

# Create background image
mkdir -p "$MOUNT_POINT/.background"
python3 - <<'PY'
import math
w, h = 680, 420
c1 = (205, 228, 255)
c2 = (245, 245, 245)
with open("/tmp/WhisperSwift_bg.ppm", "wb") as f:
    f.write(f"P6\n{w} {h}\n255\n".encode())
    for y in range(h):
        for x in range(w):
            t = (x + y) / (w + h)
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)
            f.write(bytes((r, g, b)))
PY
sips -s format png /tmp/WhisperSwift_bg.ppm --out "$MOUNT_POINT/.background/bg.png" >/dev/null
rm -f /tmp/WhisperSwift_bg.ppm

# Configure Finder window layout
osascript <<OSA
tell application "Finder"
  tell disk "${VOL_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 780, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:bg.png"
    set position of item "${APP_NAME}.app" to {170, 250}
    set position of item "Applications" to {530, 250}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA

# Hide background folder
chflags hidden "$MOUNT_POINT/.background"
chflags hidden "$MOUNT_POINT/.background/bg.png"

# Finalize DMG
sync
hdiutil detach "$DEVICE"
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_FINAL"
rm -f "$DMG_RW"
```

## Step 4: Notarize the DMG

```bash
# Submit for notarization
xcrun notarytool submit "$DMG_FINAL" \
  --keychain-profile "whisperswift-notarize" \
  --wait

# Check notarization log if needed
xcrun notarytool log <submission-id> \
  --keychain-profile "whisperswift-notarize"

# Staple the notarization ticket
xcrun stapler staple "$DMG_FINAL"
```

### Verify Notarization

```bash
# Check stapling
xcrun stapler validate "$DMG_FINAL"

# Verify Gatekeeper will accept it
spctl -a -t open --context context:primary-signature "$DMG_FINAL"
```

## Step 5: Create GitHub Release

### Prepare Release Notes

Create release notes including:
- New features
- Bug fixes
- Known issues
- Breaking changes (if any)
- Minimum macOS version

### Create Release

1. Go to GitHub repository > Releases > Draft a new release
2. Create a new tag (e.g., `v1.0.0`)
3. Set release title (e.g., `WhisperSwift 1.0.0`)
4. Paste release notes
5. Upload `build/WhisperSwift.dmg` as release asset
6. For pre-releases, check "This is a pre-release"
7. Click "Publish release"

### Alternative: Via GitHub CLI

```bash
# Create and publish release
gh release create v1.0.0 \
  --title "WhisperSwift 1.0.0" \
  --notes "Release notes here" \
  build/WhisperSwift.dmg
```

## Step 6: Post-Release Verification

- [ ] Download the DMG from GitHub releases
- [ ] Verify it opens without Gatekeeper warnings
- [ ] Install and test basic functionality
- [ ] Verify version number in About screen

## Troubleshooting

### Notarization Failed

```bash
# Get detailed log
xcrun notarytool log <submission-id> --keychain-profile "whisperswift-notarize"
```

Common issues:
- **Unsigned code**: Ensure all binaries are signed
- **Hardened runtime issues**: Check entitlements
- **Missing timestamp**: Add `--timestamp` to signing

### Code Signing Errors

```bash
# List available signing identities
security find-identity -v -p codesigning

# Re-sign the app
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --options runtime \
  --timestamp \
  build/DerivedDataRelease/Build/Products/Release/WhisperSwift.app
```

### DMG Creation Fails

```bash
# Check for existing mount
hdiutil info | grep WhisperSwift

# Force detach if stuck
hdiutil detach /Volumes/WhisperSwift -force
```

## Rollback Procedure

If a release has critical issues:

1. **On GitHub**:
   - Edit the release and mark as pre-release
   - Or delete the release entirely

2. **Communicate**:
   - Post issue on GitHub discussions
   - Update release notes with known issues

3. **Hotfix**:
   - Create hotfix branch from release tag
   - Fix the issue
   - Follow this runbook for new release

## Release Checklist Summary

```
[ ] Version updated
[ ] Tests pass
[ ] Clean build
[ ] Release build succeeds
[ ] App is properly signed
[ ] DMG created
[ ] Notarization submitted
[ ] Notarization succeeded
[ ] Stapled
[ ] GitHub release created
[ ] DMG uploaded
[ ] Post-release verification
[ ] Announcement posted (if applicable)
```
