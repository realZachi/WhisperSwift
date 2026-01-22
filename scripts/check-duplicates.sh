#!/bin/bash
# Duplicate Code Detection Script for WhisperSwift
# Usage: ./scripts/check-duplicates.sh [--report] [--threshold N]
#
# Options:
#   --report      Generate full HTML/JSON/Markdown reports in reports/jscpd/
#   --threshold N Override the default duplication threshold (default: 5%)
#   --help        Show this help message

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
GENERATE_REPORT=false
THRESHOLD=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --help)
            echo "Duplicate Code Detection Script for WhisperSwift"
            echo ""
            echo "Usage: $0 [--report] [--threshold N]"
            echo ""
            echo "Options:"
            echo "  --report      Generate full HTML/JSON/Markdown reports in reports/jscpd/"
            echo "  --threshold N Override the default duplication threshold (default: 5%)"
            echo "  --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Quick check with console output"
            echo "  $0 --report           # Generate full reports"
            echo "  $0 --threshold 10     # Allow up to 10% duplication"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if jscpd is installed
if ! command -v jscpd &> /dev/null; then
    echo -e "${YELLOW}jscpd is not installed. Installing...${NC}"

    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}Error: npm is not installed. Please install Node.js and npm first.${NC}"
        echo "Install via Homebrew: brew install node"
        exit 1
    fi

    npm install -g jscpd
    echo -e "${GREEN}jscpd installed successfully.${NC}"
fi

cd "$PROJECT_ROOT"

echo ""
echo "=========================================="
echo "  WhisperSwift Duplicate Code Detection"
echo "=========================================="
echo ""

# Build jscpd arguments
JSCPD_ARGS=("--config" ".jscpd.json")

if [ "$GENERATE_REPORT" = true ]; then
    mkdir -p reports/jscpd
    JSCPD_ARGS+=("--reporters" "console,json,markdown,html")
    JSCPD_ARGS+=("--output" "./reports/jscpd")
    echo "Report output: reports/jscpd/"
else
    JSCPD_ARGS+=("--reporters" "console")
fi

if [ -n "$THRESHOLD" ]; then
    JSCPD_ARGS+=("--threshold" "$THRESHOLD")
    echo "Threshold: ${THRESHOLD}%"
else
    echo "Threshold: 5% (default from .jscpd.json)"
fi

echo ""
echo "Scanning for duplicate code..."
echo ""

# Run jscpd
set +e
jscpd "${JSCPD_ARGS[@]}" .
EXIT_CODE=$?
set -e

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "  No significant code duplication found!"
    echo -e "==========================================${NC}"
else
    echo -e "${RED}=========================================="
    echo "  Code duplication exceeds threshold!"
    echo -e "==========================================${NC}"
    echo ""
    echo "Please review the duplicate code blocks above and consider:"
    echo "  - Extracting common code into reusable functions"
    echo "  - Creating shared utilities or extensions"
    echo "  - Using protocols for common behavior"
    echo ""

    if [ "$GENERATE_REPORT" = true ]; then
        echo "Full reports available in: reports/jscpd/"
        echo "  - jscpd-report.json (machine-readable)"
        echo "  - jscpd-report.md (markdown summary)"
        echo "  - jscpd-report.html (visual report)"
    fi
fi

exit $EXIT_CODE
