# Permissions Troubleshooting Runbook

WhisperSwift requires two macOS permissions to function properly: **Microphone** access and **Accessibility** access. This runbook helps diagnose and resolve permission issues.

## Required Permissions

| Permission | Purpose | Impact if Missing |
|------------|---------|-------------------|
| Microphone | Record audio for transcription | Cannot capture voice |
| Accessibility | Global hotkey detection, text insertion | Hotkey may not work, text won't auto-insert |

## Checking Permission Status

### Via WhisperSwift Settings

1. Click the WhisperSwift icon in the menu bar
2. Select **Settings...**
3. Go to the **Permissions** tab
4. View the status indicators:
   - Green checkmark = Granted
   - Red X = Denied or not granted

### Via Terminal

```bash
# Check if WhisperSwift is in the accessibility database
# (Requires admin privileges)
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client,allowed FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%whisperswift%';"
```

## Microphone Permission Issues

### Symptoms

- Log entry: `Microphone access denied/restricted`
- Log entry: `Failed to start recording`
- Recording indicator shows but no audio captured
- Status shows `Recorded 0 samples`

### Solution: Grant Microphone Access

#### Method 1: Via System Settings (Recommended)

1. Open **System Settings** (or System Preferences on older macOS)
2. Navigate to **Privacy & Security** > **Microphone**
3. Find **WhisperSwift** in the list
4. Toggle the switch to **ON**
5. If prompted, enter your password
6. Restart WhisperSwift

#### Method 2: Via WhisperSwift Settings

1. Open WhisperSwift Settings > Permissions
2. Click **Grant** next to Microphone
3. System Settings will open automatically
4. Toggle WhisperSwift to ON
5. Return to WhisperSwift and click **Refresh Status**

#### Method 3: Via Terminal

```bash
# Open microphone settings directly
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
```

### If WhisperSwift Doesn't Appear in the List

1. The app needs to request permission first
2. Try starting a recording (hold the hotkey)
3. A system dialog should appear asking for permission
4. Click **OK** to grant access
5. If no dialog appears, try resetting permissions (see below)

## Accessibility Permission Issues

### Symptoms

- Log entry: `Accessibility NOT granted`
- Hotkey doesn't trigger recording
- Text doesn't auto-insert after transcription
- Log entry: `Text copied to clipboard (enable Accessibility for auto-insert)`

### Solution: Grant Accessibility Access

#### Method 1: Via System Settings (Recommended)

1. Open **System Settings**
2. Navigate to **Privacy & Security** > **Accessibility**
3. Click the lock icon and enter your password
4. Click the **+** button
5. Navigate to **Applications** > **WhisperSwift.app**
6. Click **Open**
7. Ensure the checkbox next to WhisperSwift is checked
8. Close System Settings
9. Restart WhisperSwift

#### Method 2: Via WhisperSwift Settings

1. Open WhisperSwift Settings > Permissions
2. Click **Grant** next to Accessibility
3. A system dialog will prompt for accessibility access
4. Click **Open System Settings**
5. Follow the steps above to add WhisperSwift

#### Method 3: Via Terminal

```bash
# Open accessibility settings directly
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

### Accessibility Permission Not Taking Effect

If you've granted permission but it's still not working:

1. **Remove and re-add the permission**:
   - Go to Privacy & Security > Accessibility
   - Find WhisperSwift and uncheck it
   - Quit WhisperSwift completely
   - Re-check WhisperSwift in the list
   - Relaunch WhisperSwift

2. **Restart the Accessibility service**:
   ```bash
   # Kill the accessibility daemon (will auto-restart)
   sudo killall -9 universalaccessd
   ```

3. **Check for multiple versions**:
   ```bash
   # Find all WhisperSwift instances
   mdfind "kMDItemDisplayName == 'WhisperSwift'"
   ```
   If multiple exist, remove duplicates and keep only one.

## Resetting Permissions

### Reset Microphone Permission

```bash
# Reset microphone permission for WhisperSwift
tccutil reset Microphone com.realzachi.whisperswift
```

Then relaunch the app and grant permission again when prompted.

### Reset Accessibility Permission

```bash
# Reset accessibility permission for WhisperSwift
# Note: Must be run as admin and may require SIP to be disabled
sudo tccutil reset Accessibility com.realzachi.whisperswift
```

### Full Permission Reset (Nuclear Option)

If permissions are completely broken:

```bash
# Reset ALL microphone permissions (affects all apps)
tccutil reset Microphone

# Reset ALL accessibility permissions (affects all apps)
sudo tccutil reset Accessibility
```

**Warning**: This resets permissions for ALL applications.

## System Settings Navigation Quick Reference

### macOS Ventura and Later (13.0+)

- **Microphone**: System Settings > Privacy & Security > Microphone
- **Accessibility**: System Settings > Privacy & Security > Accessibility

### macOS Monterey and Earlier (12.x)

- **Microphone**: System Preferences > Security & Privacy > Privacy > Microphone
- **Accessibility**: System Preferences > Security & Privacy > Privacy > Accessibility

### Direct URL Schemes

```bash
# Microphone settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

# Accessibility settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

# All privacy settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy"
```

## Common Issues

### "WhisperSwift would like to access the microphone" dialog doesn't appear

**Cause**: macOS caches permission requests.

**Solution**:
```bash
# Reset the permission to trigger the dialog again
tccutil reset Microphone com.realzachi.whisperswift

# Relaunch WhisperSwift
```

### Permission granted but still showing as denied

**Cause**: App signature may have changed (common after updates).

**Solution**:
1. Remove WhisperSwift from the Accessibility list
2. Quit WhisperSwift
3. Re-add WhisperSwift to the list
4. Relaunch

### Accessibility permission requires admin password every time

**Cause**: Normal behavior for security reasons.

**Note**: This is a macOS security feature. Admin password is required to modify accessibility permissions.

### "WhisperSwift" not found in Applications

**Cause**: App may be running from a different location (like Downloads).

**Solution**:
1. Move WhisperSwift.app to the Applications folder
2. Remove old entries from Accessibility settings
3. Add the new location

## Verification Checklist

After fixing permissions, verify everything works:

- [ ] WhisperSwift Settings > Permissions shows both permissions granted
- [ ] Hotkey (Fn/Option/Control) triggers recording indicator
- [ ] Speaking while recording captures audio (check log for sample count > 0)
- [ ] Transcribed text auto-inserts into focused application
- [ ] If no focused app, text is copied to clipboard with notification

## Logs to Check

```bash
# Permission-related log entries
grep -E "(Permission|Accessibility|Microphone|access)" /tmp/whisperswift.log
```

Expected healthy output:
```
Microphone access already granted
Accessibility access already granted
```
