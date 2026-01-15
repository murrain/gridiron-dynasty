#!/bin/bash
# Parallel test runner for GdUnit4
#
# This script splits tests across multiple Godot processes for faster execution.
# Usage: ./run_tests_parallel.sh [NUM_SHARDS]
#
# Requirements:
# - GODOT_BIN environment variable must be set, or godot must be in PATH
# - Run from project root directory

set -e

NUM_SHARDS=${1:-4}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/scripts/tests/gdunit4"
REPORT_DIR="$PROJECT_ROOT/reports"

# Find Godot binary
if [ -n "$GODOT_BIN" ]; then
    GODOT="$GODOT_BIN"
elif command -v godot &> /dev/null; then
    GODOT="godot"
elif command -v godot4 &> /dev/null; then
    GODOT="godot4"
else
    echo "Error: Godot binary not found. Set GODOT_BIN or add godot to PATH."
    exit 1
fi

echo "========================================"
echo "GdUnit4 Parallel Test Runner"
echo "========================================"
echo "Project root: $PROJECT_ROOT"
echo "Test directory: $TEST_DIR"
echo "Godot binary: $GODOT"
echo "Number of shards: $NUM_SHARDS"
echo "========================================"
echo ""

# Get all test files
TEST_FILES=()
while IFS= read -r -d '' file; do
    TEST_FILES+=("$file")
done < <(find "$TEST_DIR" -name "test_*.gd" -type f -print0 | sort -z)

TOTAL_FILES=${#TEST_FILES[@]}
echo "Total test files: $TOTAL_FILES"
echo ""

if [ $TOTAL_FILES -eq 0 ]; then
    echo "No test files found in $TEST_DIR"
    exit 0
fi

# Calculate files per shard
FILES_PER_SHARD=$(( (TOTAL_FILES + NUM_SHARDS - 1) / NUM_SHARDS ))

# Clean up previous reports
rm -rf "$REPORT_DIR/shard-"* 2>/dev/null || true
mkdir -p "$REPORT_DIR"

# Start time
START_TIME=$(date +%s)

# Run shards in parallel
PIDS=()
for ((shard=1; shard<=NUM_SHARDS; shard++)); do
    START_IDX=$(( (shard - 1) * FILES_PER_SHARD ))
    END_IDX=$(( shard * FILES_PER_SHARD - 1 ))

    if [ $END_IDX -ge $TOTAL_FILES ]; then
        END_IDX=$(( TOTAL_FILES - 1 ))
    fi

    if [ $START_IDX -ge $TOTAL_FILES ]; then
        echo "Shard $shard: No files to process (skipped)"
        continue
    fi

    SHARD_FILES=("${TEST_FILES[@]:$START_IDX:$((END_IDX - START_IDX + 1))}")
    SHARD_COUNT=${#SHARD_FILES[@]}

    echo "Shard $shard: Running $SHARD_COUNT files (index $START_IDX to $END_IDX)"

    # Run shard in background
    (
        cd "$PROJECT_ROOT"
        # Build GdUnit4 command with shard-specific files
        GDUNIT_CMD=("$GODOT" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c)
        for file in "${SHARD_FILES[@]}"; do
            GDUNIT_CMD+=(-a "$file")
        done
        GDUNIT_CMD+=(-rd "reports/shard-$shard")

        "${GDUNIT_CMD[@]}" > "$REPORT_DIR/shard-$shard.log" 2>&1
        echo $? > "$REPORT_DIR/shard-$shard.exit"
    ) &
    PIDS+=($!)
done

# Wait for all shards to complete
echo ""
echo "Waiting for all shards to complete..."
FAILED_SHARDS=()
for i in "${!PIDS[@]}"; do
    shard=$((i + 1))
    wait ${PIDS[$i]} || true

    if [ -f "$REPORT_DIR/shard-$shard.exit" ]; then
        EXIT_CODE=$(cat "$REPORT_DIR/shard-$shard.exit")
        if [ "$EXIT_CODE" != "0" ]; then
            FAILED_SHARDS+=($shard)
            echo "  Shard $shard: FAILED (exit code $EXIT_CODE)"
        else
            echo "  Shard $shard: PASSED"
        fi
    else
        FAILED_SHARDS+=($shard)
        echo "  Shard $shard: FAILED (no exit status)"
    fi
done

# End time and summary
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total time: ${ELAPSED}s"
echo "Shards run: $NUM_SHARDS"
echo ""

if [ ${#FAILED_SHARDS[@]} -gt 0 ]; then
    echo "FAILED SHARDS: ${FAILED_SHARDS[*]}"
    echo ""
    echo "Check logs in $REPORT_DIR/shard-*.log for details"
    exit 1
else
    echo "All shards PASSED"
    exit 0
fi
