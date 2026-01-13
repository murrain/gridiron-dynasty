#!/bin/bash
# Complete the archiving of superseded planning documents
# Run this script after the initial commit to finalize the reorganization

set -e

cd "$(dirname "$0")"

echo "Completing planning documentation reorganization..."

# Create archive directory
mkdir -p archive

# Move old documents to archive with .bak extension
git mv MASTER_IMPLEMENTATION_PLAN.md archive/MASTER_IMPLEMENTATION_PLAN.md.bak
git mv QUICK_WINS_LIST.md archive/QUICK_WINS_LIST.md.bak
git mv FEATURE_EXPANSION_PLAN.md archive/FEATURE_EXPANSION_PLAN.md.bak
git mv ACTIVE_TASKS.md archive/ACTIVE_TASKS.md.bak
git mv ARCHITECTURAL_GUARDIAN_ASSESSMENT.md archive/ARCHITECTURAL_GUARDIAN_ASSESSMENT.md.bak

# Remove FUTURE_FEATURES_ANALYSIS.md (content moved to PHASE_2_FEATURES.md)
if [ -f FUTURE_FEATURES_ANALYSIS.md ]; then
    git rm FUTURE_FEATURES_ANALYSIS.md
fi

echo "Archiving complete!"
echo ""
echo "Next steps:"
echo "1. Review changes: git status"
echo "2. Commit: git commit -m 'docs: complete archiving of superseded planning documents'"
echo "3. Push: git push origin docs/consolidate-planning-documents"
