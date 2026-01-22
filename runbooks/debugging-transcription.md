# Debugging Transcription Runbook

This runbook helps diagnose and resolve transcription issues in WhisperSwift.

## Log File Location

WhisperSwift writes detailed logs to:

```
/tmp/whisperswift.log
```

### Viewing Logs

```bash
# View entire log
cat /tmp/whisperswift.log

# View last 50 lines
tail -50 /tmp/whisperswift.log

# Follow log in real-time
tail -f /tmp/whisperswift.log

# Search for errors
grep -i error /tmp/whisperswift.log

# Search for transcription events
grep -E "(transcription|Groq)" /tmp/whisperswift.log
```

### Clearing Logs

```bash
# Clear the log file
> /tmp/whisperswift.log
```

## Common Transcription Failures

### 1. API Key Missing

**Symptoms**:
- Alert dialog: "API Key Missing"
- Log entry: `API key missing, showing notification`

**Solution**:
1. Open Settings (click menu bar icon > Settings)
2. Enter your Groq API key in the General tab
3. See [API Key Rotation Runbook](./api-key-rotation.md) for details

### 2. Empty Transcription

**Symptoms**:
- Log entry: `Empty transcription result`
- No text inserted after speaking

**Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Recording too short | Hold hotkey longer while speaking |
| Microphone not working | Check microphone in System Settings |
| Audio too quiet | Speak louder or move closer to microphone |
| Background noise | Move to quieter environment |

**Diagnostic steps**:
```bash
# Check if audio was recorded
grep "Recorded.*samples" /tmp/whisperswift.log

# Should see something like:
# Recorded 48000 samples, transcribing...
# If you see 0 samples, the microphone isn't capturing audio
```

### 3. Network/API Errors

**Symptoms**:
- Log entry: `Transcription failed: ...`
- Log entry: `Groq request failed with status XXX`

**Solution by error code**:

| HTTP Status | Meaning | Solution |
|-------------|---------|----------|
| 400 | Bad Request | Check audio format; ensure recording captured properly |
| 401 | Unauthorized | API key is invalid; rotate key |
| 403 | Forbidden | API key lacks permission; check Groq console |
| 429 | Rate Limited | Too many requests; wait and retry |
| 500 | Server Error | Groq API issue; check [status.groq.com](https://status.groq.com) |
| 502/503/504 | Service Unavailable | Temporary outage; retry in a few minutes |

### 4. Text Cleanup Failures

**Symptoms**:
- Log entry: `Cleanup failed, using raw transcription`
- Transcription works but contains filler words

**This is usually non-critical** - the raw transcription is used as fallback.

**Causes**:
- Cleanup model rate limits
- Network issues during cleanup request
- Model temporarily unavailable

### 5. No Focused Target

**Symptoms**:
- Log entry: `No focused target - saved to clipboard`
- Text not inserted into application

**Solution**:
1. Click into the target application to give it focus
2. Use manual paste: press `Cmd+Ctrl+V`
3. Or paste normally with `Cmd+V` (text is in clipboard)

## Log Entry Reference

### Normal Workflow

A successful transcription shows these log entries in order:

```
[time] Key DOWN detected
[time] Recording started
[time] Key UP detected
[time] Stopping recording...
[time] Recorded XXXXX samples, transcribing...
[time] Sending audio to Groq (model: whisper-large-v3-turbo)
[time] Groq transcription received
[time] Sending transcript to Groq cleanup (model: ..., profile: default)
[time] Groq cleanup received
[time] Inserting text...
[time] Text inserted
```

### Error Indicators

Watch for these patterns:

| Log Pattern | Meaning |
|-------------|---------|
| `Failed to start recording` | Microphone permission or hardware issue |
| `No audio recorded (0 samples)` | Microphone not capturing |
| `API key missing` | No API key configured |
| `request failed with status` | API error (see status codes above) |
| `Transcription failed` | General transcription error |
| `No focused target` | No application to insert text into |

## Diagnostic Commands

### Check Application State

```bash
# Is WhisperSwift running?
pgrep -x WhisperSwift

# Check process info
ps aux | grep WhisperSwift
```

### Check Permissions

```bash
# List apps with microphone access (look for WhisperSwift)
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT client FROM access WHERE service='kTCCServiceMicrophone';" 2>/dev/null

# Check if accessibility is enabled (returns 1 if enabled)
# Note: This requires running from within the app context
```

### Check Network Connectivity

```bash
# Test connection to Groq API
curl -s -o /dev/null -w "%{http_code}" https://api.groq.com/openai/v1/models

# Should return 401 (unauthorized) if network is working
# Returns 000 or other errors if network issue
```

### Test API Key

```bash
# Test your API key (replace with your key)
curl -s https://api.groq.com/openai/v1/models \
  -H "Authorization: Bearer gsk_your_key_here" | head -c 100

# Should return JSON with model list, not an error
```

## Advanced Debugging

### Enable Verbose Logging

The app already logs extensively. For additional system-level audio debugging:

```bash
# Check Audio MIDI Setup for device issues
open -a "Audio MIDI Setup"

# List audio devices
system_profiler SPAudioDataType
```

### Check for App Crashes

```bash
# Recent crash logs
ls -la ~/Library/Logs/DiagnosticReports/ | grep -i whisper

# View a crash log
cat ~/Library/Logs/DiagnosticReports/WhisperSwift*.crash | head -100
```

### Memory Issues

If transcription fails with large audio files:

```bash
# Check memory usage
ps aux | grep WhisperSwift | awk '{print $4 "% memory"}'
```

The app chunks audio longer than 40 seconds automatically, but extremely long recordings may still cause issues.

## Escalation

If none of the above resolves the issue:

1. **Collect diagnostic information**:
   ```bash
   # Create diagnostic bundle
   mkdir -p ~/Desktop/whisperswift-debug
   cp /tmp/whisperswift.log ~/Desktop/whisperswift-debug/
   system_profiler SPAudioDataType > ~/Desktop/whisperswift-debug/audio-info.txt
   sw_vers > ~/Desktop/whisperswift-debug/macos-version.txt
   ```

2. **Open a GitHub issue** with:
   - macOS version
   - WhisperSwift version
   - Steps to reproduce
   - Relevant log excerpts
   - Audio device information
