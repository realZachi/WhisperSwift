#!/bin/bash
# Dead Feature Flag Detection Script
# Finds feature flags that are defined but never used in the codebase

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Dead Feature Flag Detection ==="
echo ""

# Extract all feature flag cases from FeatureFlags.swift
FLAGS_FILE="$PROJECT_ROOT/whisperswift/FeatureFlags.swift"

if [ ! -f "$FLAGS_FILE" ]; then
    echo -e "${RED}Error: FeatureFlags.swift not found${NC}"
    exit 1
fi

# Extract flag names - only from the FeatureFlag enum (stop at FeatureFlagCategory)
FLAGS=$(awk '/^enum FeatureFlag:/,/^enum FeatureFlagCategory/ { if (/case [a-zA-Z]+/) print }' "$FLAGS_FILE" | \
    sed -E 's/.*case ([a-zA-Z]+).*/\1/' | \
    grep -v "^$")

DEAD_FLAGS=()
USED_FLAGS=()

echo "Scanning for feature flag usage..."
echo ""

for flag in $FLAGS; do
    # Search for usage in Swift files, excluding:
    # - FeatureFlags.swift (definition file)
    # - Test files
    # - Comments

    # Look for patterns like:
    # - .flagName
    # - FeatureFlag.flagName
    # - isFeatureEnabled(.flagName)

    USAGE_COUNT=$(grep -r --include="*.swift" \
        -E "\.$flag\b" \
        "$PROJECT_ROOT/whisperswift" \
        2>/dev/null | \
        grep -v "FeatureFlags.swift" | \
        grep -v "Tests/" | \
        grep -v "case $flag" | \
        grep -v "case \.$flag:" | \
        grep -v "^[[:space:]]*//.*\.$flag" | \
        wc -l | tr -d ' ')

    if [ "$USAGE_COUNT" -eq 0 ]; then
        DEAD_FLAGS+=("$flag")
    else
        USED_FLAGS+=("$flag")
    fi
done

# Output results
echo "=== Results ==="
echo ""

if [ ${#DEAD_FLAGS[@]} -eq 0 ]; then
    echo -e "${GREEN}No dead feature flags found.${NC}"
else
    echo -e "${YELLOW}Potentially Dead Feature Flags (no direct usage found):${NC}"
    for flag in "${DEAD_FLAGS[@]}"; do
        echo "  - $flag"
    done
    echo ""
    echo -e "Note: These flags may be accessed via string rawValue or used in tests only."
fi

echo ""
echo -e "${GREEN}Active Feature Flags (${#USED_FLAGS[@]} in use):${NC}"
for flag in "${USED_FLAGS[@]}"; do
    # Count usage
    COUNT=$(grep -r --include="*.swift" -E "\.$flag\b" "$PROJECT_ROOT/whisperswift" 2>/dev/null | \
        grep -v "FeatureFlags.swift" | grep -v "Tests/" | wc -l | tr -d ' ')
    echo "  - $flag ($COUNT usages)"
done

echo ""
echo "=== Summary ==="
echo "Total flags: $((${#DEAD_FLAGS[@]} + ${#USED_FLAGS[@]}))"
echo -e "Active: ${GREEN}${#USED_FLAGS[@]}${NC}"
echo -e "Potentially dead: ${YELLOW}${#DEAD_FLAGS[@]}${NC}"

# Generate machine-readable output for CI
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "dead_count=${#DEAD_FLAGS[@]}" >> "$GITHUB_OUTPUT"
    echo "active_count=${#USED_FLAGS[@]}" >> "$GITHUB_OUTPUT"
fi

# Exit with error if dead flags found (for CI enforcement)
# Change exit 0 to exit 1 to enforce no dead flags
if [ ${#DEAD_FLAGS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Review dead flags and consider removing them or adding usage.${NC}"
    exit 0
fi
