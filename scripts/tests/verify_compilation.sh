#!/bin/bash
# Verify all .gd files compile without syntax errors
# This script should be run before submitting code for review
#
# Usage:
#   ./verify_compilation.sh         # Check only changed files (cached)
#   ./verify_compilation.sh --all   # Force check all files
#   ./verify_compilation.sh --staged # Check only staged files (for pre-commit)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_FILE="$PROJECT_ROOT/.godot_compilation_cache"

# Parse arguments
CHECK_ALL=false
CHECK_STAGED=false
for arg in "$@"; do
    case $arg in
        --all)
            CHECK_ALL=true
            ;;
        --staged)
            CHECK_STAGED=true
            ;;
    esac
done

echo "=================================================="
echo "Gridiron Dynasty - Compilation Verification"
echo "=================================================="
echo ""

if [ "$CHECK_STAGED" = true ]; then
    echo "Checking staged .gd files compile without syntax errors..."
elif [ "$CHECK_ALL" = true ]; then
    echo "Checking ALL .gd files compile without syntax errors..."
else
    echo "Checking changed .gd files compile without syntax errors..."
    echo "(Use --all to force check all files)"
fi
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL_FILES=0
PASSED_FILES=0
FAILED_FILES=0
SKIPPED_FILES=0
ERRORS_FILE=$(mktemp)

# Load cache if it exists
declare -A FILE_CACHE
if [ -f "$CACHE_FILE" ] && [ "$CHECK_ALL" = false ]; then
    while IFS='|' read -r file_path file_hash; do
        FILE_CACHE["$file_path"]="$file_hash"
    done < "$CACHE_FILE"
fi

# Function to check if file needs compilation check
needs_check() {
    local file="$1"

    # Always check if --all flag is set
    if [ "$CHECK_ALL" = true ]; then
        return 0
    fi

    # Check if file hash has changed
    local current_hash=$(md5sum "$file" | awk '{print $1}')
    local cached_hash="${FILE_CACHE[$file]}"

    if [ -z "$cached_hash" ] || [ "$cached_hash" != "$current_hash" ]; then
        return 0  # Needs check
    else
        return 1  # Skip - unchanged
    fi
}

# Function to update cache for a file
update_cache() {
    local file="$1"
    local hash=$(md5sum "$file" | awk '{print $1}')
    FILE_CACHE["$file"]="$hash"
}

# Get list of files to check
if [ "$CHECK_STAGED" = true ]; then
    # Only check staged .gd files
    FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' | grep -E '^(scripts|autoloads)/' || true)
    if [ -z "$FILES" ]; then
        echo "No staged .gd files to check."
        echo ""
        echo -e "${GREEN}ALL FILES COMPILE SUCCESSFULLY${NC}"
        exit 0
    fi
    # Convert to array
    mapfile -t FILE_ARRAY <<< "$FILES"
else
    # Check all files in scripts and autoloads
    mapfile -t -d '' FILE_ARRAY < <(find "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/autoloads" -name "*.gd" -not -path "*/.godot/*" -print0 2>/dev/null)
fi

# Check each file
for file in "${FILE_ARRAY[@]}"; do
    # Handle both absolute and relative paths
    if [[ "$file" != /* ]]; then
        file="$PROJECT_ROOT/$file"
    fi

    [ -f "$file" ] || continue

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Get relative path for cleaner output
    REL_PATH="${file#$PROJECT_ROOT/}"

    # Check if we need to verify this file
    if needs_check "$file"; then
        # Run compilation check
        if godot --headless --check-only --script "$file" 2>&1 | grep -i "error" > "$ERRORS_FILE"; then
            echo -e "${RED}✗${NC} $REL_PATH"
            cat "$ERRORS_FILE" | sed 's/^/  /'
            FAILED_FILES=$((FAILED_FILES + 1))
        else
            echo -e "${GREEN}✓${NC} $REL_PATH"
            PASSED_FILES=$((PASSED_FILES + 1))
            update_cache "$file"
        fi
    else
        echo -e "${YELLOW}⊘${NC} $REL_PATH (cached)"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
    fi
done

rm -f "$ERRORS_FILE"

# Save cache
if [ "$CHECK_ALL" = false ]; then
    > "$CACHE_FILE"  # Clear cache file
    for file_path in "${!FILE_CACHE[@]}"; do
        echo "$file_path|${FILE_CACHE[$file_path]}" >> "$CACHE_FILE"
    done
fi

echo ""
echo "=================================================="
echo "Results:"
echo "  Total files:  $TOTAL_FILES"
echo -e "  ${GREEN}Passed:${NC}       $PASSED_FILES"
if [ $SKIPPED_FILES -gt 0 ]; then
    echo -e "  ${YELLOW}Skipped:${NC}      $SKIPPED_FILES (cached)"
fi
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
    if [ $SKIPPED_FILES -gt 0 ]; then
        echo "($SKIPPED_FILES files skipped via cache)"
    fi
    echo "Code is ready for next testing phase."
    exit 0
fi
