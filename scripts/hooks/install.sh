#!/bin/bash
# Install Git hooks from scripts/hooks/ into .git/hooks/
# Part of testing process improvements (2026-01-12)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing Git hooks..."
echo ""

# Check if .git directory exists
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    echo "❌ Error: .git/hooks directory not found"
    echo "   Are you running this from a Git repository?"
    exit 1
fi

# Install pre-commit hook
if [ -f "$SCRIPT_DIR/pre-commit" ]; then
    ln -sf "$SCRIPT_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
    chmod +x "$GIT_HOOKS_DIR/pre-commit"
    echo "✅ Installed pre-commit hook"
else
    echo "⚠️  Warning: pre-commit hook not found at $SCRIPT_DIR/pre-commit"
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
ls -lh "$GIT_HOOKS_DIR" | grep -v "sample" | grep -v "^total" | grep -v "^d" || true
echo ""
