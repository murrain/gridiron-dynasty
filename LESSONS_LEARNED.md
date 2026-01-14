# Lessons Learned

## Code Quality Reviews: Trust the Reviewer's Expanded Scope

**Date:** 2026-01-13
**Context:** UDFA/Draft/FA integration implementation

### What Happened

1. Initial code review returned **9.2/10** with specific integration concerns:
   - UDFA profile duplication
   - Late field normalization

2. Applied targeted fixes to address those two issues

3. Second review returned **7.4/10** and identified **four systemic issues**:
   - Player ID field inconsistency (dual fields across codebase)
   - Roster composition logic duplication (ideal depths scattered)
   - Missing error handling (silent failures)
   - RNG budget inaccuracy (Box-Muller 2-call pattern undocumented)

4. Initially felt like scope creep (15 min "quick fix" → 4-7 hour refactor)

5. User chose comprehensive refactor approach

6. After addressing all four issues, final review returned **9.0/10** (passing threshold)

### The Lesson

**When a code reviewer escalates from "fix these specific issues" to "fix these architectural problems," they're usually right.**

The reviewer's deeper analysis revealed technical debt that would have caused:
- Maintenance time bombs (player ID inconsistency)
- Divergence risk (scattered depth requirements)
- Silent data corruption (missing error handling)
- RNG budget miscalculation (affecting determinism guarantees)

These weren't "nice to have" improvements—they were **blockers for long-term maintainability**.

### Key Insight

The "comprehensive refactor" approach actually saves time in the long run:
- **Cost now:** 4-7 hours of focused refactoring
- **Cost later:** 10-20 hours spread across multiple bugs, debugging sessions, and emergency fixes

The reviewer saw patterns we missed during initial implementation. Trust that signal.

### Application

When a code quality reviewer:
1. Identifies systemic issues beyond original scope
2. Points to coupling, duplication, or consistency problems
3. Recommends extraction of shared services

→ **Do the comprehensive refactor.** The reviewer is protecting future you from technical debt.

### Evidence of Success

After the comprehensive refactor:
- Created `RosterComposition.gd` service (single source of truth)
- Eliminated 3 duplicated ideal depth dictionaries
- Standardized player ID handling (early normalization)
- Added proper error handling with logging
- Replaced custom RNG with native functions

Result: Code that's **sound and maintainable** (reviewer's assessment).
