# DMG Release Build (Styled + Notarized)

Use a fresh release derived data folder (avoids asset copy permission issues after icon changes).

## Release Build Command

```bash
xcodebuild -project whisperswift.xcodeproj -scheme whisperswift -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" \
  DEVELOPMENT_TEAM=<TEAMID> \
  OTHER_CODE_SIGN_FLAGS="--timestamp" build
```

## Create Styled DMG

```bash
APP_NAME="WhisperSwift"
VOL_NAME="WhisperSwift"
DERIVED="build/DerivedDataRelease"
APP_PATH="$DERIVED/Build/Products/Release/${APP_NAME}.app"
DMG_RW="build/${APP_NAME}.rw.dmg"
DMG_FINAL="build/${APP_NAME}.dmg"

rm -f "$DMG_RW" "$DMG_FINAL"
hdiutil create -size 200m -fs HFS+ -volname "$VOL_NAME" -ov "$DMG_RW"
MOUNT_INFO=$(hdiutil attach -nobrowse -readwrite "$DMG_RW")
DEVICE=$(echo "$MOUNT_INFO" | awk '/^\\/dev\\// {print $1; exit}')
MOUNT_POINT=$(echo "$MOUNT_INFO" | awk '/Volumes\\/[^ ]+/ {print $3; exit}')

cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"

# Background image
mkdir -p "$MOUNT_POINT/.background"
python3 - <<'PY'
import math
w, h = 680, 420
c1 = (205, 228, 255)
c2 = (245, 245, 245)
with open("/tmp/WhisperSwift_bg.ppm", "wb") as f:
    f.write(f"P6\\n{w} {h}\\n255\\n".encode())
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

# Finder layout
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

chflags hidden "$MOUNT_POINT/.background"
chflags hidden "$MOUNT_POINT/.background/bg.png"

sync
hdiutil detach "$DEVICE"
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_FINAL"
rm -f "$DMG_RW"
```

## Notarize and Staple

```bash
xcrun notarytool submit "$DMG_FINAL" --keychain-profile "<profile-name>" --wait
xcrun stapler staple "$DMG_FINAL"
```

## Notarization Notes

- `notarytool` only accepts `.zip`, `.pkg`, or `.dmg`. To notarize the `.app`, zip it first:
  ```bash
  ditto -c -k --sequesterRsrc --keepParent WhisperSwift.app build/WhisperSwift.app.zip
  ```
- After acceptance, always `stapler staple` the `.app` and the `.dmg` so Gatekeeper works offline.
