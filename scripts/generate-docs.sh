#!/bin/bash
#
# generate-docs.sh
# WhisperSwift API Documentation Generator
#
# This script generates API documentation using swift-doc.
# Swift-doc is a documentation generator for Swift projects.
#
# Usage:
#   ./scripts/generate-docs.sh [output_dir]
#
# Arguments:
#   output_dir  - Optional. Directory for generated docs. Default: docs/api
#
# Requirements:
#   - swift-doc (install via: brew install swiftdocorg/formulae/swift-doc)
#   - Swift 5.0+
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${1:-$PROJECT_ROOT/docs/api}"
SOURCE_DIR="$PROJECT_ROOT/whisperswift"
MODULE_NAME="whisperswift"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if swift-doc is installed
check_swift_doc() {
    if command -v swift-doc &> /dev/null; then
        log_info "swift-doc found: $(swift-doc --version 2>/dev/null || echo 'version unknown')"
        return 0
    fi
    return 1
}

# Install swift-doc via Homebrew
install_swift_doc() {
    log_info "Installing swift-doc via Homebrew..."

    if ! command -v brew &> /dev/null; then
        log_error "Homebrew is not installed. Please install it from https://brew.sh"
        exit 1
    fi

    brew install swiftdocorg/formulae/swift-doc

    if check_swift_doc; then
        log_success "swift-doc installed successfully"
    else
        log_error "Failed to install swift-doc"
        exit 1
    fi
}

# Generate documentation using swift-doc
generate_with_swift_doc() {
    log_info "Generating documentation with swift-doc..."
    log_info "Source: $SOURCE_DIR"
    log_info "Output: $OUTPUT_DIR"

    # Create output directory
    mkdir -p "$OUTPUT_DIR"

    # Generate HTML documentation
    swift-doc generate "$SOURCE_DIR" \
        --module-name "$MODULE_NAME" \
        --output "$OUTPUT_DIR" \
        --format html \
        --base-url "/api" \
        2>&1 || {
            log_warning "swift-doc encountered issues. Trying alternative approach..."
            generate_fallback_docs
            return
        }

    log_success "Documentation generated at: $OUTPUT_DIR"

    # Generate index if it doesn't exist
    if [[ ! -f "$OUTPUT_DIR/index.html" ]]; then
        create_index_html
    fi
}

# Fallback documentation generator using SourceKitten if swift-doc fails
generate_fallback_docs() {
    log_info "Attempting fallback documentation generation..."

    # Create a simple markdown-based documentation
    mkdir -p "$OUTPUT_DIR"

    cat > "$OUTPUT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WhisperSwift API Documentation</title>
    <style>
        :root {
            --bg-color: #ffffff;
            --text-color: #1a1a1a;
            --link-color: #0066cc;
            --code-bg: #f5f5f5;
            --border-color: #e0e0e0;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg-color: #1a1a1a;
                --text-color: #e0e0e0;
                --link-color: #66b3ff;
                --code-bg: #2d2d2d;
                --border-color: #404040;
            }
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 2rem;
            background: var(--bg-color);
            color: var(--text-color);
        }
        h1, h2, h3 { margin-top: 2rem; }
        h1 { border-bottom: 2px solid var(--border-color); padding-bottom: 0.5rem; }
        a { color: var(--link-color); }
        code {
            background: var(--code-bg);
            padding: 0.2em 0.4em;
            border-radius: 4px;
            font-family: 'SF Mono', Menlo, monospace;
        }
        pre {
            background: var(--code-bg);
            padding: 1rem;
            border-radius: 8px;
            overflow-x: auto;
        }
        .service {
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 1rem;
            margin: 1rem 0;
        }
        .service h3 { margin-top: 0; }
    </style>
</head>
<body>
    <h1>WhisperSwift API Documentation</h1>
    <p>WhisperSwift is a native macOS menu bar application for cloud-based speech-to-text transcription.</p>

    <h2>Services</h2>

    <div class="service">
        <h3>AudioRecorder</h3>
        <p><code>actor AudioRecorder</code></p>
        <p>Thread-safe audio capture service using AVAudioEngine. Captures audio at 16kHz mono for optimal transcription.</p>
        <h4>Key Methods</h4>
        <ul>
            <li><code>startRecording() async throws</code> - Begin audio capture</li>
            <li><code>stopRecording() -> AudioRecording</code> - Stop capture and return samples</li>
            <li><code>setLevelCallback(_:)</code> - Set callback for audio level updates</li>
        </ul>
    </div>

    <div class="service">
        <h3>GroqTranscriptionService</h3>
        <p><code>actor GroqTranscriptionService</code></p>
        <p>Handles speech-to-text transcription via the Groq API.</p>
        <h4>Key Methods</h4>
        <ul>
            <li><code>transcribe(recording:) async throws -> String</code> - Transcribe audio recording</li>
            <li><code>cleanTranscription(_:profile:) async throws -> String</code> - Clean up transcription with LLM</li>
            <li><code>hasApiKey() -> Bool</code> - Check if API key is configured</li>
        </ul>
    </div>

    <div class="service">
        <h3>HotkeyManager</h3>
        <p><code>class HotkeyManager</code></p>
        <p>Manages global hotkey detection using NSEvent monitors and CGEvent taps.</p>
        <h4>Key Methods</h4>
        <ul>
            <li><code>init(onKeyDown:onKeyUp:)</code> - Initialize with key event callbacks</li>
            <li><code>stopMonitoring()</code> - Remove all event monitors</li>
            <li><code>checkAccessibilityPermission() -> Bool</code> - Check accessibility access</li>
        </ul>
    </div>

    <div class="service">
        <h3>TextInsertionService</h3>
        <p><code>class TextInsertionService</code></p>
        <p>Inserts transcribed text into the focused application.</p>
        <h4>Key Methods</h4>
        <ul>
            <li><code>insertText(_:) -> InsertionOutcome</code> - Insert text via Accessibility or clipboard</li>
        </ul>
        <h4>InsertionOutcome</h4>
        <ul>
            <li><code>.inserted</code> - Text successfully inserted</li>
            <li><code>.copiedToClipboard</code> - Text copied to clipboard (no accessibility)</li>
            <li><code>.noFocusedTarget</code> - No text field focused</li>
            <li><code>.empty</code> - Empty text provided</li>
        </ul>
    </div>

    <div class="service">
        <h3>PermissionManager</h3>
        <p><code>class PermissionManager</code></p>
        <p>Singleton managing microphone and accessibility permissions.</p>
        <h4>Key Methods</h4>
        <ul>
            <li><code>requestPermissions() async</code> - Request all required permissions</li>
            <li><code>openMicrophoneSettings()</code> - Open System Settings for microphone</li>
            <li><code>openAccessibilitySettings()</code> - Open System Settings for accessibility</li>
        </ul>
        <h4>Properties</h4>
        <ul>
            <li><code>shared: PermissionManager</code> - Singleton instance</li>
            <li><code>hasMicrophoneAccess: Bool</code> - Microphone permission status</li>
            <li><code>hasAccessibilityAccess: Bool</code> - Accessibility permission status</li>
        </ul>
    </div>

    <h2>Data Types</h2>

    <div class="service">
        <h3>AudioRecording</h3>
        <pre><code>struct AudioRecording {
    let samples: [Float]
    let sampleRate: Double
}</code></pre>
        <p>Container for recorded audio samples.</p>
    </div>

    <h2>UI Components</h2>
    <ul>
        <li><code>StatusBarController</code> - Menu bar icon and dropdown menu</li>
        <li><code>SettingsView</code> - SwiftUI settings window</li>
        <li><code>RecordingPillController</code> - Floating recording indicator overlay</li>
    </ul>

    <h2>See Also</h2>
    <ul>
        <li><a href="../architecture/ARCHITECTURE.md">Architecture Documentation</a></li>
        <li><a href="https://github.com/your-org/whisperswift">GitHub Repository</a></li>
    </ul>

    <footer style="margin-top: 4rem; padding-top: 1rem; border-top: 1px solid var(--border-color); font-size: 0.9em; color: #666;">
        <p>Generated by WhisperSwift Documentation Generator</p>
    </footer>
</body>
</html>
EOF

    log_success "Fallback documentation generated at: $OUTPUT_DIR/index.html"
}

# Create an index.html if needed
create_index_html() {
    log_info "Creating documentation index..."
    generate_fallback_docs
}

# Generate markdown documentation
generate_markdown_docs() {
    log_info "Generating markdown documentation..."

    local md_output="$OUTPUT_DIR/API.md"

    cat > "$md_output" << 'EOF'
# WhisperSwift API Reference

## Overview

WhisperSwift is a native macOS menu bar application for speech-to-text transcription using the Groq API.

## Services

### AudioRecorder

`actor AudioRecorder`

Thread-safe audio capture service using AVAudioEngine.

#### Methods

- `startRecording() async throws` - Begin audio capture
- `stopRecording() -> AudioRecording` - Stop capture and return samples
- `setLevelCallback(_: @escaping (Float) -> Void)` - Set callback for audio level updates

### GroqTranscriptionService

`actor GroqTranscriptionService`

Handles speech-to-text transcription via the Groq API.

#### Methods

- `transcribe(recording: AudioRecording) async throws -> String` - Transcribe audio
- `cleanTranscription(_: String, profile: TextCleanupProfile) async throws -> String` - Clean transcription
- `hasApiKey() -> Bool` - Check if API key is configured

### HotkeyManager

`class HotkeyManager`

Global hotkey detection using NSEvent monitors and CGEvent taps.

#### Methods

- `init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void)`
- `stopMonitoring()` - Remove all event monitors
- `checkAccessibilityPermission() -> Bool` - Static method to check accessibility

### TextInsertionService

`class TextInsertionService`

Text insertion into focused applications.

#### Methods

- `insertText(_ text: String) -> InsertionOutcome` - Insert text

#### InsertionOutcome

```swift
enum InsertionOutcome {
    case inserted
    case copiedToClipboard
    case noFocusedTarget
    case empty
}
```

### PermissionManager

`class PermissionManager` (Singleton)

Manages microphone and accessibility permissions.

#### Properties

- `shared: PermissionManager` - Singleton instance
- `hasMicrophoneAccess: Bool` - Microphone permission status
- `hasAccessibilityAccess: Bool` - Accessibility permission status

#### Methods

- `requestPermissions() async` - Request all permissions
- `openMicrophoneSettings()` - Open System Settings
- `openAccessibilitySettings()` - Open System Settings

## Data Types

### AudioRecording

```swift
struct AudioRecording {
    let samples: [Float]
    let sampleRate: Double
}
```

## Error Types

### AudioRecorderError

```swift
enum AudioRecorderError: Error {
    case engineInitFailed
    case formatCreationFailed
    case converterCreationFailed
    case recordingFailed
}
```

### GroqTranscriptionError

```swift
enum GroqTranscriptionError: Error {
    case missingApiKey
    case requestFailed(statusCode: Int, body: String)
    case invalidResponse
}
```
EOF

    log_success "Markdown documentation generated at: $md_output"
}

# Main execution
main() {
    log_info "WhisperSwift Documentation Generator"
    log_info "===================================="

    # Change to project root
    cd "$PROJECT_ROOT"

    # Check for swift-doc
    if ! check_swift_doc; then
        log_warning "swift-doc not found"

        # Ask to install in interactive mode, auto-install in CI
        if [[ "${CI:-false}" == "true" ]]; then
            install_swift_doc
        else
            read -p "Would you like to install swift-doc? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_swift_doc
            else
                log_info "Generating fallback documentation..."
                generate_fallback_docs
                generate_markdown_docs
                exit 0
            fi
        fi
    fi

    # Generate documentation
    generate_with_swift_doc
    generate_markdown_docs

    log_success "Documentation generation complete!"
    log_info "View the documentation at: $OUTPUT_DIR/index.html"
}

main "$@"
