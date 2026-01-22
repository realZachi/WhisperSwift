# Incident Response Runbook

This runbook provides procedures for handling incidents affecting WhisperSwift users.

## Incident Classification

| Severity | Description | Response Time | Examples |
|----------|-------------|---------------|----------|
| P1 - Critical | Complete service outage | Immediate | All transcription fails, app crashes on launch |
| P2 - High | Major feature broken | < 4 hours | Hotkey not working, text not inserting |
| P3 - Medium | Feature degraded | < 24 hours | Slow transcription, occasional failures |
| P4 - Low | Minor issue | < 1 week | UI glitch, documentation error |

## Incident Response Flow

```
1. Detection -> 2. Assessment -> 3. Communication -> 4. Resolution -> 5. Post-mortem
```

## Part 1: When the Groq API is Down

### Detection

Signs that Groq API may be unavailable:
- Multiple users report transcription failures
- Log shows: `Groq request failed with status 5XX`
- Check [status.groq.com](https://status.groq.com) for outages

### Immediate Actions

1. **Verify the outage**:
   ```bash
   # Test API availability
   curl -s -o /dev/null -w "%{http_code}" \
     -H "Authorization: Bearer $GROQ_API_KEY" \
     https://api.groq.com/openai/v1/models

   # 200 = API up, 5XX = API down
   ```

2. **Check Groq status page**: [status.groq.com](https://status.groq.com)

3. **Document the outage**:
   - Time first detected
   - Error codes observed
   - Number of users affected (if known)

### User Communication

**For Known Outages** (Groq confirms):

Post to GitHub Discussions or Issues:

```markdown
## Groq API Service Disruption

**Status**: Ongoing
**Started**: [timestamp]
**Impact**: Transcription functionality is unavailable

### What's happening
The Groq API, which powers WhisperSwift's transcription, is currently
experiencing an outage. This is affecting all transcription requests.

### What you can do
- Your recordings are not being lost - they simply cannot be processed
- Monitor https://status.groq.com for updates
- We will update this thread when service is restored

### Workaround
Unfortunately, there is no workaround while the API is unavailable.
WhisperSwift requires the Groq API for all transcription.
```

**For Suspected Outages** (Not confirmed):

```markdown
## Investigating Transcription Issues

**Status**: Investigating
**Started**: [timestamp]

### What's happening
We're receiving reports of transcription failures. We're investigating
whether this is a Groq API issue or a WhisperSwift issue.

### What you can do
- Check your internet connection
- Try again in a few minutes
- Check /tmp/whisperswift.log for error details

### More information
If you're experiencing issues, please comment with:
1. Time of failure
2. Error message from logs (if any)
3. Your macOS version
```

### Resolution

Once service is restored:

1. **Verify recovery**:
   ```bash
   # Test transcription
   # Launch app and test recording
   ```

2. **Update communication**:
   ```markdown
   ## UPDATE: Service Restored

   **Resolved**: [timestamp]
   **Duration**: X hours Y minutes

   The Groq API has been restored and transcription is working normally.
   No action required - WhisperSwift will work automatically.
   ```

## Part 2: Handling User-Reported Bugs

### Initial Response

Within 24 hours of a bug report:

1. **Acknowledge the report**:
   ```markdown
   Thank you for reporting this issue! I'm looking into it.

   Could you please provide:
   - Your macOS version
   - WhisperSwift version
   - Relevant entries from /tmp/whisperswift.log
   - Steps to reproduce (if known)
   ```

2. **Triage the issue**:
   - Can you reproduce it?
   - How many users are affected?
   - Is there a workaround?
   - Assign severity (P1-P4)

3. **Label the issue** appropriately:
   - `bug`
   - `needs-triage` or `needs-info`
   - Relevant `area:` label
   - Priority label once assessed

### Investigation Checklist

- [ ] Reproduce the issue locally
- [ ] Check logs for error patterns
- [ ] Identify affected code area
- [ ] Determine root cause
- [ ] Assess impact and urgency

### Common Bug Categories

| Category | Typical Causes | Investigation Steps |
|----------|---------------|---------------------|
| Recording fails | Permissions, audio hardware | Check permissions, test microphone |
| Transcription fails | API issues, network | Check logs for HTTP status |
| Text not inserting | Accessibility, app focus | Verify permissions, check frontmost app |
| Hotkey not working | Permissions, key conflict | Test other hotkeys, check accessibility |
| Crash on launch | Corruption, incompatibility | Check crash logs, test clean install |

### Fix Workflow

1. **Create fix branch**: `git checkout -b fix/issue-number-brief-description`
2. **Implement fix**
3. **Test thoroughly**
4. **Create PR with issue reference**
5. **Review and merge**
6. **If critical**: Consider immediate patch release

## Part 3: Rollback Procedures

### When to Rollback

Consider rollback when:
- New release causes widespread crashes
- Critical functionality is broken
- Security vulnerability discovered
- Data loss or corruption possible

### GitHub Release Rollback

1. **Mark current release as pre-release or draft**:
   - Go to Releases
   - Edit the problematic release
   - Check "This is a pre-release" or save as draft

2. **Re-publish previous stable release**:
   - Find the last known good release
   - Download the DMG
   - Create new release with incremented version
   - Mark as "Latest release"

3. **Communicate**:
   ```markdown
   ## Important: Version X.Y.Z Recalled

   We've identified a critical issue with version X.Y.Z and have
   temporarily recalled it. Please download version X.Y.W instead.

   **Action required**: If you installed X.Y.Z, please:
   1. Delete WhisperSwift from Applications
   2. Download the previous version from Releases
   3. Reinstall

   We apologize for the inconvenience and are working on a fix.
   ```

### User-Side Rollback Instructions

Provide users these steps:

```markdown
## How to Rollback to Previous Version

1. Quit WhisperSwift (click menu bar icon > Quit)
2. Delete WhisperSwift.app from Applications folder
3. Download the previous version from:
   https://github.com/realZachi/whisperswift/releases
4. Mount the DMG and drag to Applications
5. Launch WhisperSwift

**Note**: Your settings (API key, preferences) are preserved.
```

## Part 4: Post-Incident Review

After any P1 or P2 incident, conduct a post-mortem:

### Post-Mortem Template

```markdown
# Incident Post-Mortem: [Brief Description]

**Date**: [Date]
**Duration**: [Start time] - [End time]
**Severity**: P1/P2/P3
**Author**: [Name]

## Summary
[1-2 sentence summary of what happened]

## Impact
- Users affected: [number/estimate]
- Features affected: [list]
- Duration of impact: [time]

## Timeline
- [HH:MM] - First report received
- [HH:MM] - Investigation started
- [HH:MM] - Root cause identified
- [HH:MM] - Fix implemented
- [HH:MM] - Verified resolved

## Root Cause
[Detailed explanation of why this happened]

## Resolution
[What was done to fix it]

## Lessons Learned
### What went well
- [List positives]

### What could be improved
- [List areas for improvement]

## Action Items
- [ ] [Action 1] - Owner: [name] - Due: [date]
- [ ] [Action 2] - Owner: [name] - Due: [date]
```

## Emergency Contacts

For critical issues requiring immediate attention:

- **Groq API Issues**: [Groq Support](https://console.groq.com/support)
- **Apple Developer Issues**: [Developer Support](https://developer.apple.com/support/)
- **Project Maintainer**: Via GitHub issues with `priority: critical` label

## Quick Reference

### Diagnostic Commands

```bash
# Check app is running
pgrep -x WhisperSwift

# View recent logs
tail -100 /tmp/whisperswift.log

# Check for crashes
ls -la ~/Library/Logs/DiagnosticReports/ | grep -i whisper

# Test Groq API
curl -s https://api.groq.com/openai/v1/models \
  -H "Authorization: Bearer $GROQ_API_KEY" | jq '.data[0].id'
```

### Status Check URLs

- Groq API Status: https://status.groq.com
- GitHub Status: https://www.githubstatus.com
- Apple Developer Status: https://developer.apple.com/system-status/
