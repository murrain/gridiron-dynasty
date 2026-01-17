# Documentation Archive

This directory contains completed and historical documentation that is no longer actively used but preserved for reference.

---

## Directory Structure

### `completed-sprints/`
Contains sprint planning documents from finished work sprints. These documents capture the planning, execution, and completion of major feature work.

**Contents**:
- Draft Phase 3 planning documents
- Playable UI planning documents
- Bootstrap integration plans
- Engineer briefs and specifications
- Implementation checkpoints

**Purpose**: Historical reference for understanding past decisions, effort estimates, and implementation approaches.

### `completed-tickets/`
Contains individual implementation tickets that have been completed and closed.

**Purpose**: Preserve detailed implementation specifications and acceptance criteria for completed features.

### `historical/`
Contains design documents that represent historical system design but may no longer reflect current implementation.

**Contents**:
- Original player generation design
- Player grades and growth system design
- Bug fixes and technical investigations

**Purpose**: Historical reference for understanding system evolution and past design decisions.

---

## When to Archive Documents

### Sprint Planning Docs → `completed-sprints/`
Archive when:
- Sprint is complete and all work merged
- All PRs related to sprint are closed
- No active work references the planning document

### Implementation Tickets → `completed-tickets/`
Archive when:
- Feature is fully implemented and tested
- PR is merged and closed
- Feature is in production use

### Design Docs → `historical/`
Archive when:
- Design has been superseded by new implementation
- Document no longer reflects current system
- Still valuable for historical context

---

## Archived Sprint History

### Draft System Sprints (Jan 2026)

**Draft Phase 3 Complete**:
- `DRAFT_PHASE3_PLAN.md` - Overall Phase 3 plan
- `POST_PR150_PLAN.md` - Post-PR #150 work plan
- `PLAYABLE_GAME_ROADMAP.md` - Playable experience roadmap

**Early Planning Docs**:
- `ENGINEER_1_BRIEF.md` - Initial engineer brief
- `ENGINEER_SPEC_DRAFT_001.md` - First specification
- `ENGINEER_SPEC_DRAFT_002.md` - Second specification
- `CHECKPOINT_CP1_DESIGN_COMPLETE.md` - Design checkpoint
- `IMPLEMENTATION_BRIEF.md` - Implementation brief

### Historical Design (2025-2026)

**Player Systems**:
- `PLAYER_GENERATION_REWORK.md` - Original player generation design
- `PLAYER_GRADES_GROWTH_SYSTEM.md` - Player grading and growth system

**Technical Fixes**:
- `SQLITE_PRELOAD_FIX.md` - SQLite preload optimization

---

## Active Documentation

For current and future work, see:
- `/docs/architecture/REMAINING_WORK_PLAN.md` - Current work status
- `/docs/architecture/SPRINT_PLANNING_TEMPLATE.md` - Template for new sprints
- `/docs/CURRENT_STATUS.md` - System status overview

---

## Archive Maintenance

### Adding Documents
When archiving a document:
1. Move to appropriate subdirectory
2. Update this README with entry in archive history
3. Update any references in active docs

### Retrieving Documents
Archived documents remain accessible for:
- Understanding past design decisions
- Reference during similar feature work
- Historical context during refactoring

### Pruning
Archive documents are retained indefinitely unless:
- Content is fully obsolete with no historical value
- Document contains sensitive or outdated information
- Duplicate content exists elsewhere

---

*Archive established: 2026-01-17*
*Last updated: 2026-01-17*
