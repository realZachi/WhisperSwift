#!/bin/bash
# Post-create setup script for WhisperSwift devcontainer
# This script runs after the container is created

set -e

echo "=========================================="
echo "WhisperSwift Development Container Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "     $1"
}

# Navigate to workspace
cd /workspace

echo ""
echo "1. Validating Swift toolchain..."
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version 2>&1 | head -n 1)
    print_status "Swift installed: $SWIFT_VERSION"
else
    print_error "Swift not found!"
    exit 1
fi

echo ""
echo "2. Validating SwiftLint..."
if command -v swiftlint &> /dev/null; then
    SWIFTLINT_VERSION=$(swiftlint version)
    print_status "SwiftLint installed: $SWIFTLINT_VERSION"
else
    print_error "SwiftLint not found!"
    exit 1
fi

echo ""
echo "3. Validating SwiftFormat..."
if command -v swiftformat &> /dev/null; then
    SWIFTFORMAT_VERSION=$(swiftformat --version)
    print_status "SwiftFormat installed: $SWIFTFORMAT_VERSION"
else
    print_error "SwiftFormat not found!"
    exit 1
fi

echo ""
echo "4. Setting up pre-commit hooks..."
if [ -f ".pre-commit-config.yaml" ]; then
    pre-commit install --install-hooks 2>/dev/null || true
    print_status "Pre-commit hooks installed"
else
    print_warning "No .pre-commit-config.yaml found, skipping pre-commit setup"
fi

echo ""
echo "5. Validating project configuration files..."
CONFIG_FILES=(".swiftlint.yml" ".swiftformat" ".gitignore")
for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "Found $file"
    else
        print_warning "Missing $file"
    fi
done

echo ""
echo "6. Running initial lint check..."
if [ -f ".swiftlint.yml" ] && [ -d "whisperswift" ]; then
    # Run SwiftLint but don't fail on warnings
    swiftlint lint --config .swiftlint.yml --quiet 2>/dev/null && print_status "SwiftLint passed" || print_warning "SwiftLint found issues (run 'swiftlint lint' to see details)"
else
    print_warning "Skipping lint check - missing config or source directory"
fi

echo ""
echo "7. Checking SwiftFormat configuration..."
if [ -f ".swiftformat" ]; then
    print_status "SwiftFormat config found"
    print_info "Run 'swiftformat whisperswift --lint' to check formatting"
else
    print_warning "No .swiftformat config found"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT LIMITATIONS:"
echo "This devcontainer supports auxiliary development tasks only:"
echo "  - Code linting:     swiftlint lint --config .swiftlint.yml"
echo "  - Code formatting:  swiftformat whisperswift"
echo "  - Pre-commit hooks: pre-commit run --all-files"
echo "  - Documentation:    Markdown editing and linting"
echo "  - Git operations:   Full git functionality"
echo ""
echo "For full macOS development (building, running, debugging),"
echo "you MUST use a native macOS environment with Xcode installed."
echo ""
echo "Quick commands:"
echo "  swiftlint lint                    - Run linter"
echo "  swiftformat whisperswift          - Format code"
echo "  swiftformat whisperswift --lint   - Check formatting without changes"
echo "  pre-commit run --all-files        - Run all pre-commit checks"
echo ""
