# Incident Response Runbook

## Overview

This runbook describes how to diagnose and resolve issues with WhisperSwift.

## Common Issues

### 1. Transcription Not Working

**Symptoms**: User presses hotkey, records audio, but no text is inserted.

**Diagnosis Steps**:

1. Check logs for errors:
   ```bash
   tail -100 /tmp/whisperswift.log
   ```

2. Look for specific error patterns:
   - `API key missing` - User needs to configure Groq API key
   - `Transcription failed` - Network or API error
   - `No audio recorded (0 samples)` - Microphone issue

**Resolution**:

- **API Key Missing**: Open Settings and enter Groq API key
- **Network Error**: Check internet connection, verify Groq API status
- **Microphone Issue**: Check System Preferences > Privacy > Microphone permissions

### 2. Text Not Inserting

**Symptoms**: Transcription succeeds (visible in logs) but text doesn't appear.

**Diagnosis Steps**:

1. Check logs for insertion outcome:
   ```bash
   grep -E "(inserted|clipboard|target)" /tmp/whisperswift.log | tail -20
   ```

2. Check for `noFocusedTarget` or `copiedToClipboard` outcomes

**Resolution**:

- **No Focused Target**: Ensure a text field is focused before recording
- **Accessibility Not Granted**: Grant Accessibility permission in System Preferences
- Use manual paste (Cmd+Ctrl+V) as fallback

### 3. Hotkey Not Detected

**Symptoms**: Pressing hotkey does nothing.

**Diagnosis Steps**:

1. Check if app is running (menu bar icon visible)
2. Check logs for hotkey events:
   ```bash
   grep -E "Key (DOWN|UP)" /tmp/whisperswift.log | tail -20
   ```

**Resolution**:

- **App Not Running**: Launch WhisperSwift
- **Wrong Hotkey**: Check Settings for configured hotkey
- **Accessibility Not Granted**: Required for global hotkey detection

### 4. App Crashes

**Symptoms**: App disappears from menu bar unexpectedly.

**Diagnosis Steps**:

1. Check system logs:
   ```bash
   log show --predicate 'process == "WhisperSwift"' --last 5m
   ```

2. Check for crash reports:
   ```bash
   ls -la ~/Library/Logs/DiagnosticReports/WhisperSwift*
   ```

**Resolution**:

- Restart the application
- If persistent, try reinstalling
- Report crash with logs to GitHub Issues

## Escalation

If the issue cannot be resolved:

1. Collect diagnostic information:
   - `/tmp/whisperswift.log` contents
   - macOS version
   - WhisperSwift version
   - Steps to reproduce

2. Create GitHub Issue with collected information

## Post-Incident

After resolving an incident:

1. Document the root cause
2. Update this runbook if a new pattern was identified
3. Consider if a code fix is needed to prevent recurrence
