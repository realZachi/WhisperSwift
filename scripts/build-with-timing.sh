#!/bin/bash
# Build script with timing for WhisperSwift
# Records build start/end times, outputs duration, and saves to log file

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/whisperswift.xcodeproj"
SCHEME="whisperswift"
LOG_DIR="$PROJECT_ROOT/build/logs"
TIMING_LOG="$LOG_DIR/build-timing.log"

# Default configuration
CONFIGURATION="${1:-Debug}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Generate timestamp for this build
BUILD_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
BUILD_DATE=$(date "+%Y-%m-%d")

# Record start time
START_TIME=$(date +%s)
START_TIME_READABLE=$(date "+%H:%M:%S")

echo "========================================"
echo "WhisperSwift Build with Timing"
echo "========================================"
echo "Configuration: $CONFIGURATION"
echo "Build started: $BUILD_TIMESTAMP"
echo "========================================"

# Run the build with timing flags
# -showBuildTimingSummary shows per-target timing
# -buildWithTimingInfo provides detailed timing info
BUILD_OUTPUT=$(mktemp)
BUILD_EXIT_CODE=0

xcodebuild -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildTimingSummary \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    build 2>&1 | tee "$BUILD_OUTPUT" || BUILD_EXIT_CODE=$?

# Record end time
END_TIME=$(date +%s)
END_TIME_READABLE=$(date "+%H:%M:%S")

# Calculate duration
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Format duration string
if [ $MINUTES -gt 0 ]; then
    DURATION_STRING="${MINUTES}m ${SECONDS}s"
else
    DURATION_STRING="${SECONDS}s"
fi

# Determine build result
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    BUILD_RESULT="SUCCESS"
else
    BUILD_RESULT="FAILED"
fi

echo ""
echo "========================================"
echo "Build Summary"
echo "========================================"
echo "Result: $BUILD_RESULT"
echo "Start time: $START_TIME_READABLE"
echo "End time: $END_TIME_READABLE"
echo "Duration: $DURATION_STRING ($DURATION seconds)"
echo "========================================"

# Extract build timing summary from output if available
TIMING_SUMMARY=""
if grep -q "Build Timing Summary" "$BUILD_OUTPUT" 2>/dev/null; then
    TIMING_SUMMARY=$(sed -n '/Build Timing Summary/,/^$/p' "$BUILD_OUTPUT")
fi

# Save to timing log
{
    echo "----------------------------------------"
    echo "Build: $BUILD_TIMESTAMP"
    echo "Configuration: $CONFIGURATION"
    echo "Result: $BUILD_RESULT"
    echo "Duration: $DURATION_STRING ($DURATION seconds)"
    if [ -n "$TIMING_SUMMARY" ]; then
        echo ""
        echo "$TIMING_SUMMARY"
    fi
    echo "----------------------------------------"
    echo ""
} >> "$TIMING_LOG"

# Create/update JSON log for programmatic access
JSON_LOG="$LOG_DIR/build-timing.json"
NEW_ENTRY=$(cat <<EOF
{
  "timestamp": "$BUILD_TIMESTAMP",
  "configuration": "$CONFIGURATION",
  "result": "$BUILD_RESULT",
  "duration_seconds": $DURATION,
  "duration_formatted": "$DURATION_STRING"
}
EOF
)

# Append to JSON array (create if doesn't exist)
if [ -f "$JSON_LOG" ]; then
    # Read existing content, remove trailing ] and add new entry
    EXISTING=$(cat "$JSON_LOG")
    if [ "$EXISTING" = "[]" ]; then
        echo "[$NEW_ENTRY]" > "$JSON_LOG"
    else
        # Remove trailing ]
        TRIMMED="${EXISTING%]}"
        echo "${TRIMMED},$NEW_ENTRY]" > "$JSON_LOG"
    fi
else
    echo "[$NEW_ENTRY]" > "$JSON_LOG"
fi

# Cleanup
rm -f "$BUILD_OUTPUT"

# Output for CI systems
echo ""
echo "::notice::Build completed in $DURATION_STRING"

# Exit with the original build exit code
exit $BUILD_EXIT_CODE
