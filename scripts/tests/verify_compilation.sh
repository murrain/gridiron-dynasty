#!/bin/bash
# Verify all .gd files compile without syntax errors
# This script should be run before submitting code for review

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=================================================="
echo "Gridiron Dynasty - Compilation Verification"
echo "=================================================="
echo ""
echo "Checking all .gd files compile without syntax errors..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
ERRORS_FILE=$(mktemp)

# Find all .gd files except in .godot directory
while IFS= read -r -d '' file; do
    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Get relative path for cleaner output
    REL_PATH="${file#$PROJECT_ROOT/}"

    # Run compilation check
    if godot --headless --check-only --script "$file" 2>&1 | grep -i "error" > "$ERRORS_FILE"; then
        echo -e "${RED}✗${NC} $REL_PATH"
        cat "$ERRORS_FILE" | sed 's/^/  /'
        FAILED_FILES=$((FAILED_FILES + 1))
    else
        echo -e "${GREEN}✓${NC} $REL_PATH"
        PASSED_FILES=$((PASSED_FILES + 1))
    fi
done < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/autoloads" -name "*.gd" -not -path "*/.godot/*" -print0 2>/dev/null)

rm -f "$ERRORS_FILE"

echo ""
echo "=================================================="
echo "Results:"
echo "  Total files:  $TOTAL_FILES"
echo -e "  ${GREEN}Passed:${NC}       $PASSED_FILES"
echo -e "  ${RED}Failed:${NC}       $FAILED_FILES"
echo "=================================================="

if [ $FAILED_FILES -gt 0 ]; then
    echo ""
    echo -e "${RED}COMPILATION FAILED${NC}"
    echo "Fix all syntax errors before submitting code for review."
    exit 1
else
    echo ""
    echo -e "${GREEN}ALL FILES COMPILE SUCCESSFULLY${NC}"
    echo "Code is ready for next testing phase."
    exit 0
fi
