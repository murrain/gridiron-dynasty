#!/bin/bash
# Task Reorganization Script
# Run from project root: bash scripts/reorganize_tasks.sh

set -e

TASKS_DIR="docs/tasks"
ARCHIVE_BASE="$TASKS_DIR/archive/2026-01"

echo "Starting task reorganization..."

# Create directory structure
mkdir -p "$ARCHIVE_BASE/performance_track_F1-F3_F8"
mkdir -p "$ARCHIVE_BASE/deep_optimizations_F4-F6"
mkdir -p "$ARCHIVE_BASE/lifecycle_refinements_P2-P3"
mkdir -p "$TASKS_DIR/valuation"
mkdir -p "$TASKS_DIR/performance"
mkdir -p "$TASKS_DIR/testing"

echo "Moving completed tasks to archive..."

# Move F1, F2, F3, F8 to performance_track archive
mv "$TASKS_DIR/TASK_F1_profiling_report.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"
mv "$TASKS_DIR/TASK_F2_recruiting_optimization.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"
mv "$TASKS_DIR/TASK_F2_SUMMARY.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"
mv "$TASKS_DIR/TASK_F2_INTEGRATION_CHECKLIST.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"
mv "$TASKS_DIR/TASK_F3_scout_caching.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"
mv "$TASKS_DIR/TASK_F8_benchmark_suite.md" "$ARCHIVE_BASE/performance_track_F1-F3_F8/"

# Move F4, F5, F6 to deep_optimizations archive
mv "$TASKS_DIR/TASK_F4_deep_copy_reduction.md" "$ARCHIVE_BASE/deep_optimizations_F4-F6/"
mv "$TASKS_DIR/TASK_F4_implementation_summary.md" "$ARCHIVE_BASE/deep_optimizations_F4-F6/"
mv "$TASKS_DIR/TASK_F5_parallel_lifecycle.md" "$ARCHIVE_BASE/deep_optimizations_F4-F6/"
mv "$TASKS_DIR/TASK_F6_config_optimization.md" "$ARCHIVE_BASE/deep_optimizations_F4-F6/"
mv "$TASKS_DIR/TASK_F6_implementation_summary.md" "$ARCHIVE_BASE/deep_optimizations_F4-F6/"

# Move P2, P3 to lifecycle_refinements archive
mv "$TASKS_DIR/TASK_P2_recruiting_score_cache.md" "$ARCHIVE_BASE/lifecycle_refinements_P2-P3/"
mv "$TASKS_DIR/TASK_P3_lifecycle_copy_reduction.md" "$ARCHIVE_BASE/lifecycle_refinements_P2-P3/"
mv "$TASKS_DIR/TASK_P3_implementation_summary.md" "$ARCHIVE_BASE/lifecycle_refinements_P2-P3/"

echo "Organizing active tasks..."

# Move valuation tasks to valuation folder
mv "$TASKS_DIR/TASK_E5_player_value_calculator.md" "$TASKS_DIR/valuation/"
mv "$TASKS_DIR/TASK_E6_update_contract_valuation.md" "$TASKS_DIR/valuation/"
mv "$TASKS_DIR/TASK_E7_market_supply.md" "$TASKS_DIR/valuation/"
mv "$TASKS_DIR/TASK_E8_wire_valuation_flow.md" "$TASKS_DIR/valuation/"
mv "$TASKS_DIR/TASK_E9_valuation_configs.md" "$TASKS_DIR/valuation/"
mv "$TASKS_DIR/TASK_E10_valuation_tests.md" "$TASKS_DIR/valuation/"

# Move remaining performance tasks to performance folder
mv "$TASKS_DIR/TASK_F7_development_report_deferral.md" "$TASKS_DIR/performance/"
mv "$TASKS_DIR/TASK_P1_phase_timing_capture.md" "$TASKS_DIR/performance/"

# Move testing tasks to testing folder
mv "$TASKS_DIR/TASK_TEST_FIXTURES.md" "$TASKS_DIR/testing/"
mv "$TASKS_DIR/TASK_TEST_PARALLEL.md" "$TASKS_DIR/testing/"

echo "Reorganization complete!"
echo ""
echo "Archive structure:"
echo "  $ARCHIVE_BASE/"
echo "    - performance_track_F1-F3_F8/ (6 files)"
echo "    - deep_optimizations_F4-F6/ (5 files)"
echo "    - lifecycle_refinements_P2-P3/ (3 files)"
echo "    - README.md"
echo ""
echo "Active tasks structure:"
echo "  $TASKS_DIR/"
echo "    - valuation/ (6 files: E5-E10)"
echo "    - performance/ (2 files: F7, P1)"
echo "    - testing/ (2 files: TEST_FIXTURES, TEST_PARALLEL)"
echo "    - README.md"
echo ""
echo "Next step: Update docs/tasks/README.md with new structure"
