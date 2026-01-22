#!/bin/bash
# Setup git hooks for WhisperSwift
# Run this once after cloning the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up git hooks for WhisperSwift..."

# Configure git to use the .githooks directory
git config core.hooksPath .githooks

# Make hooks executable
chmod +x "$PROJECT_DIR/.githooks/"*

echo ""
echo "Git hooks configured successfully!"
echo ""
echo "Active hooks:"
ls -la "$PROJECT_DIR/.githooks/" | grep -v "^total" | grep -v "^\." | awk '{print "  - " $NF}'
echo ""
echo "Hooks will now run automatically on commit."
echo "To bypass a hook (not recommended): git commit --no-verify"
