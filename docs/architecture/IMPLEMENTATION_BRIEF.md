# Phase 3 Database Persistence - Implementation Brief

## Overview

Implement high-performance SQLite database persistence layer for Gridiron Dynasty world state. This replaces JSON-based save/load operations with a normalized database schema that supports efficient querying.

## Architecture Decisions

### Backend Abstraction
- **PersistenceLayer** autoload provides interface for all save/load operations
- Supports two backends: JSON (current/legacy) and SQLite (new)
- Backend selection configurable at runtime
- No breaking changes to existing game logic

### Data Access Objects (DAO)
- **PlayerDAO**: Handles Player entity + 8 nested resources
- **TeamDAO**: Handles Team entity + Roster entries
- Transaction support for atomic multi-entity operations
- Batch operations for performance

### Schema Design Principles
1. **Normalized Structure**: 1 main player table + 7 related tables for components
2. **Versioned Schema**: `schema_metadata` table tracks version for migrations
3. **Indexed Queries**: Indexes on position, age, stage, team_id from day 1
4. **Backward Compatible**: JSON backend continues working during rollout

## Phase 2 Model Structure (Context)

Player resource decomposition (already merged to main):
```
Player (extends Person)
├── physicals: PlayerPhysicals
├── combine: CombineResults
├── stats_profile: StatsProfile
├── trait_set: TraitSet
├── career: CareerRecord
├── health: HealthStatus
└── contract: Contract
```

Roster structure:
```
Team
└── roster: Roster
    └── entries: Array[RosterEntry]
        └── roster_contract: RosterContract
```

## Critical Requirements

### Schema Versioning (BLOCKING)
Every schema change must be versioned:
```sql
CREATE TABLE schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO schema_metadata (key, value) VALUES ('schema_version', '1');
```

### Transaction Support (BLOCKING)
All DAO operations must support explicit transactions:
```gdscript
func begin_transaction() -> bool
func commit_transaction() -> bool
func rollback_transaction() -> bool
```

### Loading Strategies (BLOCKING)
Document which relationships are eager vs lazy loaded:
- **Eager**: Player physicals, combine, stats_profile (always needed)
- **Lazy**: Team roster entries (may load IDs only, resolve on demand)
- **Batch**: Use `load_batch()` for multiple players by ID list

### Migration Verification (BLOCKING)
Migration tool must verify integrity:
- Entity counts match (players, teams, roster entries)
- ID checksums match (sorted list of all IDs)
- Spot-check random entities for field equality

## Performance Targets

- **5x improvement** in save/load operations (baseline: ~120s for 10-year world)
- **Query capability**: Position/age/stage queries < 100ms
- **Memory efficiency**: Stream large result sets, don't load entire database

## Engineer Assignment

### Engineer 1: Foundations (ARCH-017, ARCH-018)
**Estimated**: 10-14 hours

**Deliverables**:
1. `autoloads/PersistenceLayer.gd` - Backend abstraction autoload
2. `scripts/persistence/JSONPersistence.gd` - Wrapper for current logic
3. `scripts/persistence/DatabasePersistence.gd` - SQLite implementation skeleton
4. `docs/architecture/DATABASE_SCHEMA.md` - Complete schema documentation
5. SQL schema with versioning + indexes

**Acceptance Criteria**:
- Backend switching works (JSON backend functional)
- Schema documented with relationships diagram
- All indexes defined in initial schema
- Transaction support in interface

### Engineer 2: DAOs (ARCH-019, ARCH-020)
**Estimated**: 10-13 hours

**Deliverables**:
1. `scripts/persistence/PlayerDAO.gd` - Full CRUD for Player + nested resources
2. `scripts/persistence/TeamDAO.gd` - Full CRUD for Team + Roster
3. Transaction support throughout
4. Unit tests for all DAO operations

**Acceptance Criteria**:
- Save/load Player with all 8 component resources
- Batch operations (load 1000 players efficiently)
- Query support (by position, age, stage)
- Transaction rollback on error

### Engineer 3: Migration & Performance (ARCH-021, ARCH-022)
**Estimated**: 8-11 hours

**Deliverables**:
1. `scripts/tools/MigrateSaveToDatabase.gd` - JSON→SQLite migration
2. Benchmark suite for query performance
3. Migration verification report
4. Performance comparison report

**Acceptance Criteria**:
- Migrate 10-year world state without data loss
- Verification report shows 100% entity match
- 5x performance improvement demonstrated
- Query benchmarks documented

## Quality Gates

### 4-Layer Testing (MANDATORY)
1. **Syntax**: `godot --headless --check-only --script <file>`
2. **Unit**: DAO CRUD operations with test database
3. **Integration**: Save/load world_state, verify determinism preserved
4. **Runtime**: Full simulation with SQLite backend, compare to JSON baseline

### Code Quality (BLOCKING)
- Minimum 9.5/10 from code-quality-reviewer
- Review at CP4 (100% implementation complete)

## References

- **Main repo**: `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/main/` (READ ONLY)
- **Workspace**: `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team-persistence/`
- **Implementation tickets**: `main/docs/architecture/IMPLEMENTATION_TICKETS.md`
- **SQLite plugin**: `addons/godot-sqlite/` (2shady4u/godot-sqlite)
- **Phase 2 models**: `main/scripts/core/models/` (Player, Team, Roster, etc.)

## SQLite Plugin Usage

```gdscript
const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")

var db = SQLite.new()
db.path = "user://saves/world.db"
db.open_db()

# Execute query
db.query("CREATE TABLE test (id INTEGER PRIMARY KEY)")

# Parameterized query
db.query_with_bindings("INSERT INTO test VALUES (?)", [123])

# Select
var rows = db.query("SELECT * FROM test")
```

## Checkpoint Protocol

Report progress using this format:
```
CHECKPOINT {N} STATUS - Engineer {N}
Ticket: ARCH-0XX
Status: [Complete/In Progress/Blocked]
Files Created: [list]
Tests Passing: [Yes/No/N/A]
Blockers: [None/Description]
Next Steps: [Brief description]
```

## Success Criteria

- ✅ All 6 tickets (ARCH-017 through ARCH-022) implemented
- ✅ 4-layer testing passes (syntax, unit, integration, runtime)
- ✅ Code quality review ≥9.5/10
- ✅ 5x performance improvement demonstrated
- ✅ Zero data loss in migration
- ✅ JSON backend continues working (backward compatibility)
