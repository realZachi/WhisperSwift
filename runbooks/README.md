# WhisperSwift Runbooks

This directory contains operational runbooks for maintaining and troubleshooting WhisperSwift.

## Quick Reference

| Runbook | Description | When to Use |
|---------|-------------|-------------|
| [API Key Rotation](./api-key-rotation.md) | Rotating Groq API credentials | Regular security maintenance, key compromise |
| [Debugging Transcription](./debugging-transcription.md) | Troubleshooting transcription issues | When transcription fails or produces incorrect results |
| [Permissions Troubleshooting](./permissions-troubleshooting.md) | Fixing permission issues | When microphone or accessibility permissions fail |
| [Release Process](./release-process.md) | Building and publishing releases | When creating a new version release |
| [Incident Response](./incident-response.md) | Handling production incidents | When users report bugs or API is unavailable |

## Runbook Index

### Operations

- **[API Key Rotation](./api-key-rotation.md)**: Step-by-step guide for rotating the Groq API key, including how to update it in the app and verify the new key works correctly.

- **[Release Process](./release-process.md)**: Complete checklist for building, signing, notarizing, and publishing new releases of WhisperSwift.

### Troubleshooting

- **[Debugging Transcription](./debugging-transcription.md)**: Common transcription failures, how to check logs, API error codes, and step-by-step troubleshooting procedures.

- **[Permissions Troubleshooting](./permissions-troubleshooting.md)**: Guide for resolving microphone and accessibility permission issues on macOS.

### Incident Management

- **[Incident Response](./incident-response.md)**: Procedures for handling API outages, user-reported bugs, and rollback scenarios.

## Log File Location

WhisperSwift writes debug logs to:

```
/tmp/whisperswift.log
```

Use this log file for diagnosing issues. See [Debugging Transcription](./debugging-transcription.md) for details on log interpretation.

## Support Resources

- **GitHub Issues**: [Report bugs or request features](https://github.com/realZachi/whisperswift/issues)
- **Groq API Status**: [status.groq.com](https://status.groq.com)
- **Groq Documentation**: [console.groq.com/docs](https://console.groq.com/docs)
