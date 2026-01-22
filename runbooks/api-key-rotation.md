# API Key Rotation Runbook

This runbook covers the process of rotating the Groq API key used by WhisperSwift.

## When to Rotate

- **Scheduled rotation**: Every 90 days as a security best practice
- **Key compromise**: Immediately if the key may have been exposed
- **Personnel changes**: When team members with key access leave
- **Suspicious activity**: If unauthorized API usage is detected

## Prerequisites

- Access to the [Groq Console](https://console.groq.com)
- WhisperSwift installed on the target machine
- Administrative access to the macOS user account

## Step 1: Generate a New API Key

1. Log in to the [Groq Console](https://console.groq.com)
2. Navigate to **API Keys** section
3. Click **Create API Key**
4. Give the key a descriptive name (e.g., `whisperswift-prod-2026-01`)
5. Copy the new key immediately (it will only be shown once)
6. Store it securely (password manager recommended)

## Step 2: Update the Key in WhisperSwift

### Option A: Via Settings UI (Recommended)

1. Click the WhisperSwift icon in the menu bar
2. Select **Settings...**
3. In the **General** tab, locate the **Groq API** section
4. Clear the existing API Key field
5. Paste the new API key
6. Close the Settings window (changes are saved automatically)

### Option B: Via UserDefaults (Terminal)

```bash
# Set the new API key
defaults write com.realzachi.whisperswift groqApiKey "gsk_your_new_api_key_here"

# Verify the key was saved (shows partial key)
defaults read com.realzachi.whisperswift groqApiKey | cut -c1-10
```

### Option C: Via Environment Variable

For development or CI environments:

```bash
# Add to shell profile (~/.zshrc or ~/.bashrc)
export GROQ_API_KEY="gsk_your_new_api_key_here"

# Or set for a single session
GROQ_API_KEY="gsk_your_new_api_key_here" open -a WhisperSwift
```

**Note**: UserDefaults key takes precedence over the environment variable. The environment variable `GROQ_API_KEY` is only used as a fallback when no key is stored in UserDefaults.

## Step 3: Verify the New Key

1. **Restart WhisperSwift**:
   - Click the menu bar icon
   - Select **Quit**
   - Relaunch the application

2. **Test transcription**:
   - Hold the configured hotkey (default: Fn)
   - Speak a test phrase: "Testing one two three"
   - Release the hotkey
   - Verify the text is transcribed and inserted

3. **Check logs for success**:
   ```bash
   tail -20 /tmp/whisperswift.log | grep -E "(Groq|transcription)"
   ```

   Expected output should include:
   ```
   [timestamp] Sending audio to Groq (model: whisper-large-v3-turbo)
   [timestamp] Groq transcription received
   ```

## Step 4: Revoke the Old Key

**Important**: Only revoke the old key after confirming the new key works.

1. Return to the [Groq Console](https://console.groq.com)
2. Navigate to **API Keys**
3. Locate the old key
4. Click the trash icon or **Revoke** button
5. Confirm the revocation

## Troubleshooting

### New key not working

1. **Check key format**: Groq keys start with `gsk_`
2. **Verify no extra whitespace**: Keys should have no leading/trailing spaces
3. **Check logs for errors**:
   ```bash
   tail -50 /tmp/whisperswift.log | grep -i error
   ```

### "API Key Missing" error after update

1. Ensure the key was saved correctly:
   ```bash
   defaults read com.realzachi.whisperswift groqApiKey
   ```
2. If empty, re-enter the key via Settings UI
3. Restart the application

### Rate limiting errors (status 429)

The new key may have different rate limits. Check your Groq plan and adjust usage accordingly.

## Security Best Practices

- Never commit API keys to version control
- Use environment variables for development/CI
- Store production keys in a secure password manager
- Enable Groq API key notifications if available
- Review API usage regularly for anomalies
- Rotate keys at least every 90 days

## Rollback Procedure

If the new key has issues and you need to restore the old one:

1. If the old key is still active (not yet revoked):
   - Update the key in Settings to the old value
   - Test transcription
   - Investigate issues with the new key before trying again

2. If the old key was already revoked:
   - Generate a fresh new key from the Groq Console
   - Follow this runbook from Step 2
