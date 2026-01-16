# Game Saves Implementation Plan

**Feature**: Game Save System with Unified UI Architecture
**Status**: Planning Phase
**Created**: 2026-01-16
**Updated**: 2026-01-16
**Target**: Post-Phase 3 (Database Persistence Complete)

---

## Executive Summary

Implement a complete game save system with a unified UI architecture that supports both development testing (World Explorer) and player experience (Game UI) through a shared component system with different viewing contexts.

### Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Stats Storage** | Hybrid (JSON + queryable columns) | Flexibility for all 49 stats + efficient queries on ~15-20 key stats |
| **Information Asymmetry** | Player-coach only | AI coaches use true stats; only player-coach sees revealed stats |
| **Query Strategy** | Query true stats, filter by knowledge | Simple implementation; filter results by scouting data |
| **UI Architecture** | Shared components, ViewContext enum | One codebase, two modes (omniscient vs player-coach) |
| **Query Interface** | Builder UI + Raw SQL mode | Accessible for casual players, powerful for advanced users |

---

## Architecture Overview

### Unified UI System

```
┌─────────────────────────────────────────────────────────────────────┐
│                      SHARED UI COMPONENTS                           │
│  (PlayerSearchPanel, PlayerCard, QueryBuilder, SqlEditor, etc.)     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────────────────┐     ┌─────────────────────────┐      │
│   │    WORLD EXPLORER       │     │       GAME UI           │      │
│   │  (Debug/Testing Tool)   │     │  (Player Experience)    │      │
│   │                         │     │                         │      │
│   │  ViewContext.OMNISCIENT │     │  ViewContext.PLAYER_COACH│     │
│   │                         │     │                         │      │
│   │  • Shows TRUE stats     │     │  • Shows REVEALED stats │      │
│   │  • No filtering         │     │  • Unscouted = "??"     │      │
│   │  • All players visible  │     │  • Filtered by knowledge│      │
│   │  • Can load ANY save    │     │  • Attached to one team │      │
│   │  • No team attachment   │     │  • Scouting affects view│      │
│   └─────────────────────────┘     └─────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### World Explorer Access Modes

World Explorer operates independently from the Game UI and can:

1. **Generate New World** - Create fresh world for testing
2. **Load Any Save** - Open any saved game state for inspection
3. **God Mode View** - See all data without team attachment

This allows developers/testers to:
- Inspect saved games without affecting player progress
- Debug world state at any point in time
- Verify data integrity across save/load cycles
- Test query systems with full data visibility

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DATABASE LAYER                              │
│                                                                     │
│   player table ──┬── player_stat_queryable (indexed columns)        │
│                  └── player_stats (JSON blobs for all 49 stats)     │
│                                                                     │
│   team table ────── player_scouting_reports (player-coach only)     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         QUERY LAYER                                 │
│                                                                     │
│   1. PlayerQueryBuilder / Raw SQL                                   │
│      └── Queries TRUE stats from player_stat_queryable              │
│                                                                     │
│   2. Post-Query Filter (Game UI only)                               │
│      └── Removes players where required stats aren't revealed       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                             │
│                                                                     │
│   PlayerDataProvider(ViewContext, team?)                            │
│      │                                                              │
│      ├── OMNISCIENT: Return true_value                              │
│      │                                                              │
│      └── PLAYER_COACH: Return revealed_value or null                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Current System Analysis

### What Exists (Phase 3 Complete)

✅ **Persistence Backend** (`autoloads/PersistenceLayer.gd`)
- Abstraction layer supporting JSON and SQLite backends
- `save_world_state()` and `load_world_state()` methods
- Transaction support for SQLite

✅ **Database Layer** (`scripts/persistence/`)
- `DatabasePersistence.gd`: SQLite save/load implementation
- `PlayerDAO.gd` and `TeamDAO.gd`: Entity-level persistence
- Full schema in `schema.sql` with player/team/roster tables

✅ **World Generation** (`scripts/pipelines/`)
- `BootstrapGameWorld.gd`: Multi-year world orchestrator
- Deterministic RNG via `Rand.splitmix64()`

✅ **Scouting Infrastructure** (Partial)
- `Team.scouting_data`: Dictionary for per-team knowledge
- `ScoutingResourceManager.gd`: Report schema with revealed_stats
- `Scout.estimate_stat()`: Adds noise based on scout skill

### What's Missing

❌ **Queryable Stats Table** - Stats stored as JSON blobs, not queryable
❌ **Main Menu Scene** - No UI for New Game / Continue Game
❌ **Save Metadata System** - No tracking of save metadata
❌ **Scouting Persistence** - Team.scouting_data not saved to database
❌ **Unified UI Components** - No shared component system with ViewContext
❌ **Query Builder UI** - No visual query interface
❌ **Raw SQL Mode** - No advanced query interface

---

## Implementation Plan

### Phase 0: Data Model Enhancement (6-8 hours)

**Goal**: Enable efficient database queries on player stats

#### 0.1: Add Queryable Stats Table

**File**: Modify - `scripts/persistence/schema.sql`

```sql
-- Queryable subset of player stats for efficient filtering
-- JSON blob still stores all 49 stats for flexibility
CREATE TABLE IF NOT EXISTS player_stat_queryable (
    player_id TEXT PRIMARY KEY,

    -- Physical/Athletic stats (most common filters)
    speed REAL,
    acceleration REAL,
    agility REAL,
    strength REAL,
    stamina REAL,

    -- Throwing stats
    throw_power REAL,
    throw_accuracy REAL,
    throw_on_run REAL,

    -- Coverage stats
    coverage REAL,
    press_coverage REAL,
    zone_coverage REAL,

    -- Receiving stats
    catching REAL,
    route_running REAL,

    -- Defensive stats
    tackling REAL,
    pass_rush REAL,
    block_shedding REAL,

    -- Mental stats
    awareness REAL,
    football_iq REAL,

    -- Derived/Overall
    overall_rating REAL,

    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_stat_speed ON player_stat_queryable(speed);
CREATE INDEX IF NOT EXISTS idx_stat_overall ON player_stat_queryable(overall_rating);
CREATE INDEX IF NOT EXISTS idx_stat_coverage ON player_stat_queryable(coverage);
CREATE INDEX IF NOT EXISTS idx_stat_throw_power ON player_stat_queryable(throw_power);

-- Composite indexes for position-specific searches
CREATE INDEX IF NOT EXISTS idx_qb_search ON player_stat_queryable(throw_power, throw_accuracy, awareness);
CREATE INDEX IF NOT EXISTS idx_cb_search ON player_stat_queryable(coverage, speed, agility);
CREATE INDEX IF NOT EXISTS idx_wr_search ON player_stat_queryable(catching, speed, route_running);
```

#### 0.2: Create PlayerQueryBuilder

**File**: New - `scripts/persistence/PlayerQueryBuilder.gd`

```gdscript
class_name PlayerQueryBuilder
extends RefCounted

## Fluent API for building player queries
##
## Example usage:
##   var results = PlayerQueryBuilder.new(db) \
##       .position("CB") \
##       .stat_min("speed", 85.0) \
##       .stat_min("coverage", 80.0) \
##       .age_range(21, 27) \
##       .order_by("overall_rating", false) \
##       .limit(25) \
##       .execute()

var _db: SQLite
var _where_clauses: Array[String] = []
var _params: Array = []
var _order_by: String = ""
var _limit: int = 100
var _offset: int = 0

func _init(db: SQLite) -> void:
    _db = db

func position(pos: String) -> PlayerQueryBuilder:
    _where_clauses.append("p.position = ?")
    _params.append(pos)
    return self

func positions(pos_list: Array[String]) -> PlayerQueryBuilder:
    var placeholders = []
    for pos in pos_list:
        placeholders.append("?")
        _params.append(pos)
    _where_clauses.append("p.position IN (%s)" % ", ".join(placeholders))
    return self

func stat_min(stat_name: String, min_val: float) -> PlayerQueryBuilder:
    if _is_valid_stat(stat_name):
        _where_clauses.append("sq.%s >= ?" % stat_name)
        _params.append(min_val)
    return self

func stat_max(stat_name: String, max_val: float) -> PlayerQueryBuilder:
    if _is_valid_stat(stat_name):
        _where_clauses.append("sq.%s <= ?" % stat_name)
        _params.append(max_val)
    return self

func stat_range(stat_name: String, min_val: float, max_val: float) -> PlayerQueryBuilder:
    if _is_valid_stat(stat_name):
        _where_clauses.append("sq.%s BETWEEN ? AND ?" % stat_name)
        _params.append(min_val)
        _params.append(max_val)
    return self

func age_min(min_age: int) -> PlayerQueryBuilder:
    _where_clauses.append("p.age >= ?")
    _params.append(min_age)
    return self

func age_max(max_age: int) -> PlayerQueryBuilder:
    _where_clauses.append("p.age <= ?")
    _params.append(max_age)
    return self

func age_range(min_age: int, max_age: int) -> PlayerQueryBuilder:
    _where_clauses.append("p.age BETWEEN ? AND ?")
    _params.append(min_age)
    _params.append(max_age)
    return self

func stage(player_stage: int) -> PlayerQueryBuilder:
    _where_clauses.append("p.stage = ?")
    _params.append(player_stage)
    return self

func order_by(column: String, ascending: bool = true) -> PlayerQueryBuilder:
    var direction = "ASC" if ascending else "DESC"
    if _is_valid_stat(column):
        _order_by = "ORDER BY sq.%s %s" % [column, direction]
    elif column in ["age", "position", "first_name", "last_name"]:
        _order_by = "ORDER BY p.%s %s" % [column, direction]
    return self

func limit(count: int) -> PlayerQueryBuilder:
    _limit = mini(count, 500)  # Cap at 500 for safety
    return self

func offset(skip: int) -> PlayerQueryBuilder:
    _offset = skip
    return self

func build_sql() -> String:
    var sql = """
        SELECT p.id, p.first_name, p.last_name, p.position, p.age, p.stage,
               sq.speed, sq.acceleration, sq.agility, sq.strength,
               sq.throw_power, sq.throw_accuracy, sq.coverage, sq.press_coverage,
               sq.catching, sq.route_running, sq.tackling, sq.pass_rush,
               sq.awareness, sq.football_iq, sq.overall_rating
        FROM player p
        JOIN player_stat_queryable sq ON p.id = sq.player_id
    """

    if not _where_clauses.is_empty():
        sql += " WHERE " + " AND ".join(_where_clauses)

    if not _order_by.is_empty():
        sql += " " + _order_by

    sql += " LIMIT %d" % _limit

    if _offset > 0:
        sql += " OFFSET %d" % _offset

    return sql

func get_params() -> Array:
    return _params

func execute() -> Array:
    var sql = build_sql()
    return _db.query_with_bindings(sql, _params)

## Get list of stat columns used in query (for scouting filter)
func get_required_stats() -> Array[String]:
    var stats: Array[String] = []
    for clause in _where_clauses:
        for stat in VALID_STATS:
            if "sq.%s" % stat in clause and stat not in stats:
                stats.append(stat)
    return stats

const VALID_STATS := [
    "speed", "acceleration", "agility", "strength", "stamina",
    "throw_power", "throw_accuracy", "throw_on_run",
    "coverage", "press_coverage", "zone_coverage",
    "catching", "route_running",
    "tackling", "pass_rush", "block_shedding",
    "awareness", "football_iq", "overall_rating"
]

func _is_valid_stat(stat_name: String) -> bool:
    return stat_name in VALID_STATS
```

#### 0.3: Create SafeQueryExecutor for Raw SQL

**File**: New - `scripts/persistence/SafeQueryExecutor.gd`

```gdscript
class_name SafeQueryExecutor
extends RefCounted

## Executes user-provided SQL with security validation
##
## Features:
## - Whitelist of allowed tables/columns
## - Blocks dangerous operations (DROP, ALTER, etc.)
## - Forces LIMIT on all queries
## - Provides helpful error messages

var _db: SQLite

# Whitelist of allowed tables
const ALLOWED_TABLES := [
    "player", "player_stat_queryable", "player_stats", "player_physicals",
    "team", "roster_entry", "contract"
]

# Whitelist of allowed operations
const ALLOWED_OPERATIONS := ["SELECT"]

# Forbidden patterns (case-insensitive check)
const FORBIDDEN_PATTERNS := [
    ";",           # No statement chaining
    "--",          # No SQL comments
    "/*",          # No block comments
    "DROP",        # No DDL
    "ALTER",
    "CREATE",
    "INSERT",
    "UPDATE",
    "DELETE",
    "TRUNCATE",
    "ATTACH",      # No database attachment
    "DETACH",
    "PRAGMA",      # No pragma access
    "VACUUM",
    "REINDEX",
]

const MAX_LIMIT := 500
const DEFAULT_LIMIT := 100

func _init(db: SQLite) -> void:
    _db = db

## Validate and execute a user-provided SQL query
## Returns: { "success": bool, "data": Array, "error": String, "sql": String }
func execute(sql: String) -> Dictionary:
    var result := {
        "success": false,
        "data": [],
        "error": "",
        "sql": ""
    }

    var validation := validate(sql)
    if not validation.valid:
        result.error = validation.error
        return result

    result.sql = validation.sanitized

    # Execute the query
    var query_result = _db.query(validation.sanitized)
    if query_result == null:
        result.error = "Query execution failed"
        return result

    result.success = true
    result.data = query_result
    return result

## Validate a SQL query without executing
## Returns: { "valid": bool, "error": String, "sanitized": String }
func validate(sql: String) -> Dictionary:
    var result := {"valid": false, "error": "", "sanitized": ""}
    var upper_sql := sql.to_upper().strip_edges()

    # Must start with SELECT
    if not upper_sql.begins_with("SELECT"):
        result.error = "Only SELECT queries are allowed"
        return result

    # Check forbidden patterns
    for pattern in FORBIDDEN_PATTERNS:
        if pattern in upper_sql:
            result.error = "Forbidden pattern detected: %s" % pattern
            return result

    # Validate table references
    var tables := _extract_table_references(sql)
    for table in tables:
        if table.to_lower() not in ALLOWED_TABLES:
            result.error = "Table not allowed: %s. Allowed tables: %s" % [table, ", ".join(ALLOWED_TABLES)]
            return result

    # Ensure LIMIT is present and reasonable
    var sanitized := sql.strip_edges()
    if "LIMIT" not in upper_sql:
        sanitized = sanitized.trim_suffix(";") + " LIMIT %d" % DEFAULT_LIMIT
    else:
        # Check if limit is too high
        var limit_match := _extract_limit(upper_sql)
        if limit_match > MAX_LIMIT:
            result.error = "LIMIT too high (%d). Maximum allowed: %d" % [limit_match, MAX_LIMIT]
            return result

    result.valid = true
    result.sanitized = sanitized
    return result

## Get query templates for users to learn from
static func get_templates() -> Dictionary:
    return {
        "Fast CBs": """SELECT p.first_name, p.last_name, sq.speed, sq.coverage, sq.overall_rating
FROM player p
JOIN player_stat_queryable sq ON p.id = sq.player_id
WHERE p.position = 'CB' AND sq.speed >= 90
ORDER BY sq.speed DESC
LIMIT 25""",

        "Young High-Potential QBs": """SELECT p.first_name, p.last_name, p.age, sq.throw_power, sq.throw_accuracy, sq.overall_rating
FROM player p
JOIN player_stat_queryable sq ON p.id = sq.player_id
WHERE p.position = 'QB' AND p.age <= 25
ORDER BY sq.overall_rating DESC
LIMIT 25""",

        "Elite Pass Rushers": """SELECT p.first_name, p.last_name, p.position, sq.pass_rush, sq.speed, sq.strength
FROM player p
JOIN player_stat_queryable sq ON p.id = sq.player_id
WHERE sq.pass_rush >= 85 AND sq.speed >= 80
ORDER BY sq.pass_rush DESC
LIMIT 25""",

        "Slot Receivers": """SELECT p.first_name, p.last_name, sq.speed, sq.agility, sq.catching, sq.route_running
FROM player p
JOIN player_stat_queryable sq ON p.id = sq.player_id
WHERE p.position = 'WR' AND sq.agility >= 85 AND sq.route_running >= 80
ORDER BY sq.agility DESC
LIMIT 25""",

        "Undervalued Veterans": """SELECT p.first_name, p.last_name, p.age, p.position, sq.overall_rating
FROM player p
JOIN player_stat_queryable sq ON p.id = sq.player_id
WHERE p.age >= 30 AND sq.overall_rating >= 80
ORDER BY sq.overall_rating DESC
LIMIT 25"""
    }

func _extract_table_references(sql: String) -> Array[String]:
    var tables: Array[String] = []
    var words := sql.split(" ")
    var next_is_table := false

    for word in words:
        var clean_word := word.strip_edges().to_lower()
        if clean_word in ["from", "join"]:
            next_is_table = true
        elif next_is_table and not clean_word.is_empty():
            # Remove any alias or punctuation
            var table_name := clean_word.split(" ")[0].trim_suffix(",")
            if not table_name.is_empty() and table_name not in ["on", "where", "and", "or", "left", "right", "inner", "outer"]:
                tables.append(table_name)
            next_is_table = false

    return tables

func _extract_limit(upper_sql: String) -> int:
    var limit_idx := upper_sql.find("LIMIT")
    if limit_idx == -1:
        return 0

    var after_limit := upper_sql.substr(limit_idx + 5).strip_edges()
    var limit_str := ""
    for c in after_limit:
        if c.is_valid_int():
            limit_str += c
        else:
            break

    return int(limit_str) if not limit_str.is_empty() else 0
```

#### 0.4: Update PlayerDAO to Persist Queryable Stats

**File**: Modify - `scripts/persistence/PlayerDAO.gd`

Add method to save queryable stats alongside existing stats:

```gdscript
## Save player's queryable stats to indexed table
func _save_queryable_stats(player: Player) -> bool:
    var stats: Dictionary = player.stats_profile.current if player.stats_profile else {}
    var derived: Dictionary = player.stats_profile.derived if player.stats_profile else {}

    var sql := """
        INSERT OR REPLACE INTO player_stat_queryable (
            player_id, speed, acceleration, agility, strength, stamina,
            throw_power, throw_accuracy, throw_on_run,
            coverage, press_coverage, zone_coverage,
            catching, route_running,
            tackling, pass_rush, block_shedding,
            awareness, football_iq, overall_rating
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    var params := [
        player.id,
        stats.get("speed", 0.0),
        stats.get("acceleration", 0.0),
        stats.get("agility", 0.0),
        stats.get("strength", 0.0),
        stats.get("stamina", 0.0),
        stats.get("throw_power", 0.0),
        stats.get("throw_accuracy", 0.0),
        stats.get("throw_on_run", 0.0),
        stats.get("coverage", 0.0),
        stats.get("press_coverage", 0.0),
        stats.get("zone_coverage", 0.0),
        stats.get("catching", 0.0),
        stats.get("route_running", 0.0),
        stats.get("tackling", 0.0),
        stats.get("pass_rush", 0.0),
        stats.get("block_shedding", 0.0),
        stats.get("awareness", 0.0),
        stats.get("football_iq", 0.0),
        derived.get("overall", 0.0)
    ]

    return _db.query_with_bindings(sql, params) != null
```

**Acceptance Criteria**:
- [ ] `player_stat_queryable` table created with indexes
- [ ] `PlayerQueryBuilder` provides fluent query API
- [ ] `SafeQueryExecutor` validates and executes raw SQL safely
- [ ] PlayerDAO persists queryable stats on save
- [ ] Query templates provided for user learning
- [ ] Unit tests for query builder and safe executor

---

### Phase 1: Save Metadata & Scouting Persistence (6-8 hours)

**Goal**: Track save metadata and persist player-coach scouting data

#### 1.1: Add Scouting Reports Table

**File**: Modify - `scripts/persistence/schema.sql`

```sql
-- Player-coach scouting reports (single team's knowledge)
-- AI coaches use true stats directly, so we only persist player-coach data
CREATE TABLE IF NOT EXISTS player_scouting_reports (
    player_id TEXT PRIMARY KEY,
    revealed_stats TEXT NOT NULL DEFAULT '{}',  -- JSON: {"speed": 84.5, "coverage": 78.2}
    hours_invested REAL DEFAULT 0.0,
    confidence_level TEXT DEFAULT 'minimal',    -- "minimal"|"basic"|"detailed"|"comprehensive"
    last_updated_year INTEGER NOT NULL,
    evaluation_years TEXT DEFAULT '[]',         -- JSON: [2025, 2026]
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_scouting_confidence ON player_scouting_reports(confidence_level);

-- Save metadata table
CREATE TABLE IF NOT EXISTS save_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 1.2: Create SaveMetadata Resource

**File**: New - `scripts/persistence/SaveMetadata.gd`

```gdscript
extends Resource
class_name SaveMetadata

@export var save_name: String = ""
@export var created_at: int = 0
@export var updated_at: int = 0
@export var current_year: int = 2025
@export var base_seed: int = 0
@export var years_simulated: int = 0
@export var persistence_backend: String = "sqlite"

# World state summary
@export var nfl_team_count: int = 0
@export var nfl_player_count: int = 0
@export var college_count: int = 0
@export var college_player_count: int = 0
@export var retired_player_count: int = 0
@export var scouted_player_count: int = 0

# RNG state for determinism
@export var rng_state: int = 0

# User-facing
@export var display_name: String = ""
@export var player_team_id: String = ""  # Team controlled by player-coach

func from_world_state(world_state: Dictionary, save_name: String, base_seed: int) -> void:
    self.save_name = save_name
    self.created_at = Time.get_unix_time_from_system()
    self.updated_at = self.created_at
    self.current_year = int(world_state.get("current_year", 2025))
    self.base_seed = base_seed
    self.persistence_backend = "sqlite"

    # Extract counts
    self.nfl_team_count = (world_state.get("nfl_teams", []) as Array).size()
    self.nfl_player_count = _count_nfl_players(world_state)
    self.college_count = (world_state.get("colleges", []) as Array).size()
    self.college_player_count = _count_college_players(world_state)
    self.retired_player_count = (world_state.get("retired_players", []) as Array).size()

    # Count scouted players
    var player_team = _get_player_team(world_state)
    if player_team:
        self.player_team_id = player_team.get("id", "")
        self.scouted_player_count = player_team.get("scouting_data", {}).size()

    if display_name.is_empty():
        display_name = "Year %d - %s" % [current_year, Time.get_datetime_string_from_unix_time(created_at)]

func get_formatted_date() -> String:
    var dt = Time.get_datetime_dict_from_unix_time(created_at)
    return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func get_world_summary() -> String:
    return "%d NFL Teams | %d Players | %d Scouted" % [nfl_team_count, nfl_player_count, scouted_player_count]

func to_dict() -> Dictionary:
    return {
        "save_name": save_name,
        "created_at": created_at,
        "updated_at": updated_at,
        "current_year": current_year,
        "base_seed": base_seed,
        "years_simulated": years_simulated,
        "persistence_backend": persistence_backend,
        "nfl_team_count": nfl_team_count,
        "nfl_player_count": nfl_player_count,
        "college_count": college_count,
        "college_player_count": college_player_count,
        "retired_player_count": retired_player_count,
        "scouted_player_count": scouted_player_count,
        "rng_state": rng_state,
        "display_name": display_name,
        "player_team_id": player_team_id
    }

func from_dict(d: Dictionary) -> void:
    save_name = String(d.get("save_name", ""))
    created_at = int(d.get("created_at", 0))
    updated_at = int(d.get("updated_at", 0))
    current_year = int(d.get("current_year", 2025))
    base_seed = int(d.get("base_seed", 0))
    years_simulated = int(d.get("years_simulated", 0))
    persistence_backend = String(d.get("persistence_backend", "sqlite"))
    nfl_team_count = int(d.get("nfl_team_count", 0))
    nfl_player_count = int(d.get("nfl_player_count", 0))
    college_count = int(d.get("college_count", 0))
    college_player_count = int(d.get("college_player_count", 0))
    retired_player_count = int(d.get("retired_player_count", 0))
    scouted_player_count = int(d.get("scouted_player_count", 0))
    rng_state = int(d.get("rng_state", 0))
    display_name = String(d.get("display_name", ""))
    player_team_id = String(d.get("player_team_id", ""))

func _count_nfl_players(world_state: Dictionary) -> int:
    var rosters: Dictionary = world_state.get("nfl_rosters", {})
    var total := 0
    for team_id in rosters.keys():
        var roster_data = rosters[team_id]
        if roster_data is Dictionary:
            total += (roster_data.get("players", []) as Array).size()
    return total

func _count_college_players(world_state: Dictionary) -> int:
    var rosters: Dictionary = world_state.get("college_rosters", {})
    var total := 0
    for college_id in rosters.keys():
        var roster: Dictionary = rosters[college_id]
        total += (roster.get("players", []) as Array).size()
    return total

func _get_player_team(world_state: Dictionary) -> Dictionary:
    var teams: Array = world_state.get("nfl_teams", [])
    for team in teams:
        if team is Dictionary and team.get("is_player_controlled", false):
            return team
    return {}
```

#### 1.3: Create ScoutingDAO

**File**: New - `scripts/persistence/ScoutingDAO.gd`

```gdscript
class_name ScoutingDAO
extends RefCounted

## Persistence for player-coach scouting data
## AI coaches use true stats directly; only player-coach data is persisted

var _db: SQLite

func _init(db: SQLite) -> void:
    _db = db

## Save all scouting reports from player-coach's team
func save_scouting_data(scouting_data: Dictionary) -> bool:
    # Clear existing reports
    _db.query("DELETE FROM player_scouting_reports")

    for player_id in scouting_data.keys():
        var report: Dictionary = scouting_data[player_id]
        if not _save_report(player_id, report):
            push_error("ScoutingDAO: Failed to save report for player %s" % player_id)
            return false

    return true

func _save_report(player_id: String, report: Dictionary) -> bool:
    var revealed_stats_json := JSON.stringify(report.get("revealed_stats", {}))
    var eval_years_json := JSON.stringify(report.get("evaluation_years", []))

    var sql := """
        INSERT OR REPLACE INTO player_scouting_reports
        (player_id, revealed_stats, hours_invested, confidence_level, last_updated_year, evaluation_years)
        VALUES (?, ?, ?, ?, ?, ?)
    """

    var params := [
        player_id,
        revealed_stats_json,
        report.get("hours_invested", 0.0),
        report.get("confidence_level", "minimal"),
        report.get("last_updated_year", 0),
        eval_years_json
    ]

    return _db.query_with_bindings(sql, params) != null

## Load all scouting reports into dictionary
func load_scouting_data() -> Dictionary:
    var result: Dictionary = {}
    var rows = _db.query("SELECT * FROM player_scouting_reports")

    if rows == null:
        return result

    for row in rows:
        var player_id := String(row["player_id"])

        var json_parser := JSON.new()

        json_parser.parse(String(row["revealed_stats"]))
        var revealed_stats: Dictionary = json_parser.data if json_parser.data is Dictionary else {}

        json_parser.parse(String(row["evaluation_years"]))
        var eval_years: Array = json_parser.data if json_parser.data is Array else []

        result[player_id] = {
            "player_id": player_id,
            "revealed_stats": revealed_stats,
            "hours_invested": float(row["hours_invested"]),
            "confidence_level": String(row["confidence_level"]),
            "last_updated_year": int(row["last_updated_year"]),
            "evaluation_years": eval_years
        }

    return result

## Check if a specific stat is revealed for a player
func has_revealed_stat(player_id: String, stat_name: String, scouting_data: Dictionary) -> bool:
    var report: Dictionary = scouting_data.get(player_id, {})
    var revealed: Dictionary = report.get("revealed_stats", {})
    return revealed.has(stat_name)

## Check if all required stats are revealed for a player
func has_all_revealed_stats(player_id: String, required_stats: Array, scouting_data: Dictionary) -> bool:
    var report: Dictionary = scouting_data.get(player_id, {})
    var revealed: Dictionary = report.get("revealed_stats", {})

    for stat in required_stats:
        if not revealed.has(stat):
            return false

    return true

## Filter query results to only include players with sufficient scouting
func filter_by_scouting(players: Array, required_stats: Array, scouting_data: Dictionary) -> Array:
    return players.filter(func(player):
        var player_id: String = player.get("id", "") if player is Dictionary else ""
        return has_all_revealed_stats(player_id, required_stats, scouting_data)
    )
```

**Acceptance Criteria**:
- [ ] SaveMetadata resource tracks all save information
- [ ] Scouting reports table persists player-coach knowledge
- [ ] ScoutingDAO saves/loads scouting data correctly
- [ ] Filter method removes players without sufficient scouting
- [ ] Unit tests for all DAO methods

---

### Phase 2: Unified UI Components (8-10 hours)

**Goal**: Create shared UI components with ViewContext support

#### 2.1: Create ViewContext and PlayerDataProvider

**File**: New - `scripts/ui/shared/ViewContext.gd`

```gdscript
class_name ViewContext
extends RefCounted

## Viewing context for UI components
##
## OMNISCIENT: World Explorer mode - shows true stats for all players
## PLAYER_COACH: Game UI mode - shows only revealed stats

enum Mode {
    OMNISCIENT,     # Debug/testing - sees everything
    PLAYER_COACH    # Player experience - filtered by knowledge
}

var mode: Mode
var player_team: Dictionary  # Only used in PLAYER_COACH mode
var scouting_data: Dictionary  # Player-coach's scouting reports

func _init(p_mode: Mode, p_team: Dictionary = {}, p_scouting: Dictionary = {}) -> void:
    mode = p_mode
    player_team = p_team
    scouting_data = p_scouting

func is_omniscient() -> bool:
    return mode == Mode.OMNISCIENT

func is_player_coach() -> bool:
    return mode == Mode.PLAYER_COACH
```

**File**: New - `scripts/ui/shared/PlayerDataProvider.gd`

```gdscript
class_name PlayerDataProvider
extends RefCounted

## Provides player data respecting view context
##
## In OMNISCIENT mode: Returns true stats
## In PLAYER_COACH mode: Returns revealed stats or null

var _context: ViewContext

func _init(context: ViewContext) -> void:
    _context = context

## Get stat value respecting view context
## Returns float for known stat, null for unknown
func get_stat(player_id: String, stat_name: String, true_value: float) -> Variant:
    if _context.is_omniscient():
        return true_value

    # PLAYER_COACH mode - check if revealed
    var report: Dictionary = _context.scouting_data.get(player_id, {})
    var revealed: Dictionary = report.get("revealed_stats", {})

    if revealed.has(stat_name):
        return revealed[stat_name]  # May differ from true_value due to scouting noise

    return null  # Not revealed

## Format stat for display
## Returns "85" for known, "85?" for low confidence, "??" for unknown
func format_stat(player_id: String, stat_name: String, true_value: float) -> String:
    var value = get_stat(player_id, stat_name, true_value)

    if value == null:
        return "??"

    if _context.is_player_coach():
        var confidence := get_confidence(player_id)
        if confidence in ["minimal", "basic"]:
            return "%d?" % int(value)

    return str(int(value))

## Get confidence level for a player's scouting report
func get_confidence(player_id: String) -> String:
    var report: Dictionary = _context.scouting_data.get(player_id, {})
    return report.get("confidence_level", "none")

## Check if player has been scouted at all
func is_scouted(player_id: String) -> bool:
    return _context.scouting_data.has(player_id)

## Check if specific stat is revealed
func has_stat(player_id: String, stat_name: String) -> bool:
    if _context.is_omniscient():
        return true

    var report: Dictionary = _context.scouting_data.get(player_id, {})
    var revealed: Dictionary = report.get("revealed_stats", {})
    return revealed.has(stat_name)

## Filter query results based on scouting knowledge
func filter_results(players: Array, required_stats: Array[String]) -> Array:
    if _context.is_omniscient():
        return players

    return players.filter(func(player):
        var player_id: String
        if player is Dictionary:
            player_id = player.get("id", "")
        else:
            player_id = ""

        for stat in required_stats:
            if not has_stat(player_id, stat):
                return false
        return true
    )

## Get display color for confidence level
func get_confidence_color(player_id: String) -> Color:
    var confidence := get_confidence(player_id)
    match confidence:
        "comprehensive":
            return Color.GREEN
        "detailed":
            return Color.LIGHT_GREEN
        "basic":
            return Color.YELLOW
        "minimal":
            return Color.ORANGE
        _:
            return Color.GRAY
```

#### 2.2: Create Query Builder UI Component

**File**: New - `scripts/ui/shared/QueryBuilderPanel.gd`

```gdscript
extends PanelContainer
class_name QueryBuilderPanel

## Visual query builder with toggle to raw SQL mode

signal query_executed(results: Array, required_stats: Array)
signal mode_changed(is_advanced: bool)

@onready var position_dropdown: OptionButton = $VBox/Filters/PositionDropdown
@onready var speed_min: SpinBox = $VBox/Filters/SpeedMin
@onready var coverage_min: SpinBox = $VBox/Filters/CoverageMin
@onready var age_min: SpinBox = $VBox/Filters/AgeMin
@onready var age_max: SpinBox = $VBox/Filters/AgeMax
@onready var order_by_dropdown: OptionButton = $VBox/Filters/OrderByDropdown
@onready var limit_spinbox: SpinBox = $VBox/Filters/LimitSpinbox

@onready var sql_editor: TextEdit = $VBox/SqlEditor
@onready var sql_error_label: Label = $VBox/SqlErrorLabel
@onready var template_dropdown: OptionButton = $VBox/TemplateDropdown

@onready var search_button: Button = $VBox/Buttons/SearchButton
@onready var clear_button: Button = $VBox/Buttons/ClearButton
@onready var toggle_mode_button: Button = $VBox/Buttons/ToggleModeButton

@onready var builder_container: Control = $VBox/Filters
@onready var advanced_container: Control = $VBox/AdvancedContainer

var _db: SQLite
var _is_advanced_mode := false

const POSITIONS := ["Any", "QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S", "K", "P"]
const ORDER_BY_OPTIONS := ["overall_rating", "speed", "coverage", "throw_power", "age"]

func _ready() -> void:
    _setup_dropdowns()
    _connect_signals()
    _set_mode(false)

func setup(db: SQLite) -> void:
    _db = db
    _load_templates()

func _setup_dropdowns() -> void:
    for pos in POSITIONS:
        position_dropdown.add_item(pos)

    for option in ORDER_BY_OPTIONS:
        order_by_dropdown.add_item(option.capitalize().replace("_", " "))

func _connect_signals() -> void:
    search_button.pressed.connect(_on_search_pressed)
    clear_button.pressed.connect(_on_clear_pressed)
    toggle_mode_button.pressed.connect(_on_toggle_mode)
    template_dropdown.item_selected.connect(_on_template_selected)

func _set_mode(advanced: bool) -> void:
    _is_advanced_mode = advanced
    builder_container.visible = not advanced
    advanced_container.visible = advanced
    toggle_mode_button.text = "← Builder" if advanced else "Advanced →"
    mode_changed.emit(advanced)

func _on_toggle_mode() -> void:
    _set_mode(not _is_advanced_mode)

func _on_search_pressed() -> void:
    if _is_advanced_mode:
        _execute_raw_sql()
    else:
        _execute_builder_query()

func _on_clear_pressed() -> void:
    position_dropdown.selected = 0
    speed_min.value = 0
    coverage_min.value = 0
    age_min.value = 18
    age_max.value = 45
    sql_editor.text = ""
    sql_error_label.text = ""

func _execute_builder_query() -> void:
    var builder := PlayerQueryBuilder.new(_db)
    var required_stats: Array[String] = []

    # Position filter
    var pos_idx := position_dropdown.selected
    if pos_idx > 0:  # Not "Any"
        builder.position(POSITIONS[pos_idx])

    # Stat filters
    if speed_min.value > 0:
        builder.stat_min("speed", speed_min.value)
        required_stats.append("speed")

    if coverage_min.value > 0:
        builder.stat_min("coverage", coverage_min.value)
        required_stats.append("coverage")

    # Age filter
    builder.age_range(int(age_min.value), int(age_max.value))

    # Order by
    var order_idx := order_by_dropdown.selected
    if order_idx >= 0:
        builder.order_by(ORDER_BY_OPTIONS[order_idx], false)

    builder.limit(int(limit_spinbox.value))

    # Execute
    var results := builder.execute()
    query_executed.emit(results, required_stats)

func _execute_raw_sql() -> void:
    var executor := SafeQueryExecutor.new(_db)
    var result := executor.execute(sql_editor.text)

    if not result.success:
        sql_error_label.text = "Error: " + result.error
        sql_error_label.add_theme_color_override("font_color", Color.RED)
        return

    sql_error_label.text = "Query executed successfully (%d results)" % result.data.size()
    sql_error_label.add_theme_color_override("font_color", Color.GREEN)

    # For raw SQL, we can't easily determine required stats
    # Pass empty array - in PLAYER_COACH mode, user must ensure they've scouted
    query_executed.emit(result.data, [])

func _load_templates() -> void:
    template_dropdown.clear()
    template_dropdown.add_item("-- Select Template --")

    var templates := SafeQueryExecutor.get_templates()
    for template_name in templates.keys():
        template_dropdown.add_item(template_name)

func _on_template_selected(idx: int) -> void:
    if idx == 0:
        return

    var templates := SafeQueryExecutor.get_templates()
    var template_name := template_dropdown.get_item_text(idx)
    sql_editor.text = templates.get(template_name, "")
```

**Acceptance Criteria**:
- [ ] ViewContext enum distinguishes omniscient vs player-coach modes
- [ ] PlayerDataProvider returns appropriate values for each mode
- [ ] QueryBuilderPanel provides visual query interface
- [ ] Toggle switches between builder and raw SQL modes
- [ ] Templates load and populate SQL editor
- [ ] Validation errors display clearly

---

### Phase 3: Main Menu & Game UI (8-10 hours)

**Goal**: Create main menu and game UI entry points using shared components

#### 3.1: Main Menu Scene

**File**: New - `scenes/ui/main_menu/main_menu.tscn`

Scene structure:
```
MainMenu (Control)
├── Background (ColorRect)
├── TitleContainer (VBoxContainer)
│   ├── GameTitle (Label) - "GRIDIRON DYNASTY"
│   └── Version (Label)
├── MenuContainer (VBoxContainer)
│   ├── NewGameButton (Button)
│   ├── ContinueButton (Button)
│   └── ExitButton (Button)
```

**File**: New - `scripts/ui/main_menu/MainMenu.gd`

```gdscript
extends Control
class_name MainMenu

@onready var continue_button: Button = $MenuContainer/ContinueButton

func _ready() -> void:
    $MenuContainer/NewGameButton.pressed.connect(_on_new_game)
    $MenuContainer/ContinueButton.pressed.connect(_on_continue)
    $MenuContainer/ExitButton.pressed.connect(_on_exit)

    # Disable continue if no saves
    continue_button.disabled = PersistenceLayer.list_saves().is_empty()

func _on_new_game() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/main_menu/new_game_config.tscn")

func _on_continue() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/main_menu/continue_game.tscn")

func _on_exit() -> void:
    get_tree().quit()
```

#### 3.2: New Game Configuration

**File**: New - `scenes/ui/main_menu/new_game_config.tscn`

Scene includes:
- Save name input
- Seed input (0 = random)
- Years slider (10-50)
- Team selection dropdown
- Start/Back buttons

#### 3.3: Continue Game Screen

**File**: New - `scenes/ui/main_menu/continue_game.tscn`

Scene includes:
- Scrollable save list
- Save entry items showing metadata
- Load/Delete buttons

#### 3.4: Game UI Entry Point

**File**: New - `scripts/ui/game/GameUI.gd`

```gdscript
extends Control
class_name GameUI

## Main game interface using PLAYER_COACH view context

var _context: ViewContext
var _data_provider: PlayerDataProvider
var _world_state: Dictionary

func setup(world_state: Dictionary, player_team: Dictionary, scouting_data: Dictionary) -> void:
    _world_state = world_state
    _context = ViewContext.new(ViewContext.Mode.PLAYER_COACH, player_team, scouting_data)
    _data_provider = PlayerDataProvider.new(_context)

    # Initialize all panels with player-coach context
    _setup_panels()

func _setup_panels() -> void:
    # All shared components receive the same context
    # They will automatically filter/format data appropriately
    pass
```

**Acceptance Criteria**:
- [ ] Main menu launches with proper button states
- [ ] New game config passes settings to world generation
- [ ] Continue game lists saves with metadata
- [ ] Game UI initializes with PLAYER_COACH context
- [ ] All navigation flows work correctly

---

### Phase 4: World Explorer Update (4-6 hours)

**Goal**: Update World Explorer to use shared components with OMNISCIENT context and support loading any save

#### 4.1: Add Save Browser to World Explorer

**File**: New - `scripts/ui/world_explorer/WorldExplorerLauncher.gd`

```gdscript
extends Control
class_name WorldExplorerLauncher

## Entry point for World Explorer with options to:
## 1. Generate new world (existing behavior)
## 2. Load any existing save file for inspection

@onready var new_world_button: Button = $Options/NewWorldButton
@onready var load_save_button: Button = $Options/LoadSaveButton
@onready var save_list: ItemList = $SaveBrowser/SaveList

func _ready() -> void:
    new_world_button.pressed.connect(_on_new_world)
    load_save_button.pressed.connect(_on_load_save)
    _populate_save_list()

func _populate_save_list() -> void:
    save_list.clear()
    var saves = PersistenceLayer.list_saves_with_metadata()
    for metadata in saves:
        save_list.add_item("%s - Year %d (%s)" % [
            metadata.display_name,
            metadata.current_year,
            metadata.get_formatted_date()
        ])
        save_list.set_item_metadata(save_list.item_count - 1, metadata.save_name)

func _on_new_world() -> void:
    # Launch world generation (existing flow)
    get_tree().root.set_meta("world_explorer_mode", "generate")
    get_tree().change_scene_to_file("res://scenes/main/world_explorer_main.tscn")

func _on_load_save() -> void:
    var selected = save_list.get_selected_items()
    if selected.is_empty():
        return

    var save_name = save_list.get_item_metadata(selected[0])
    get_tree().root.set_meta("world_explorer_mode", "load")
    get_tree().root.set_meta("world_explorer_save", save_name)
    get_tree().change_scene_to_file("res://scenes/main/world_explorer_main.tscn")
```

#### 4.2: Modify WorldExplorer for Unified Architecture

**File**: Modify - `scripts/ui/world_explorer/WorldExplorer.gd`

```gdscript
extends Control
class_name WorldExplorer

## Debug/testing tool using OMNISCIENT view context
## Shows TRUE stats for all players - no scouting filter applied
## Can load any save file for inspection without team attachment

var _context: ViewContext
var _data_provider: PlayerDataProvider
var _world_state: Dictionary
var _loaded_save_name: String = ""  # Empty if generated, save name if loaded

func _ready() -> void:
    # World Explorer always uses OMNISCIENT mode - no team attachment
    _context = ViewContext.new(ViewContext.Mode.OMNISCIENT)
    _data_provider = PlayerDataProvider.new(_context)

func load_world_state(world_state: Dictionary, save_name: String = "") -> void:
    _world_state = world_state
    _loaded_save_name = save_name
    _refresh_panels()
    _update_title()

func _update_title() -> void:
    if _loaded_save_name.is_empty():
        $Title.text = "World Explorer - Generated World"
    else:
        $Title.text = "World Explorer - %s (Read-Only)" % _loaded_save_name

func _refresh_panels() -> void:
    # Panels use _data_provider which returns true stats in OMNISCIENT mode
    pass
```

#### 4.3: Update WorldExplorerMain for Load Mode

**File**: Modify - `scripts/main/WorldExplorerMain.gd`

Add support for loading saves in World Explorer mode:

```gdscript
func _run_setup() -> void:
    var mode = get_tree().root.get_meta("world_explorer_mode", "generate")
    get_tree().root.remove_meta("world_explorer_mode")

    if mode == "load":
        var save_name = get_tree().root.get_meta("world_explorer_save", "")
        get_tree().root.remove_meta("world_explorer_save")
        _load_save_for_inspection(save_name)
    else:
        _run_bootstrap()

func _load_save_for_inspection(save_name: String) -> void:
    print("[WorldExplorerMain] Loading save for inspection: %s" % save_name)
    loading_label.text = "Loading save for inspection..."

    var loaded_state = PersistenceLayer.load_world_state(save_name)
    if loaded_state.is_empty():
        _show_error("Failed to load save: %s" % save_name)
        return

    world_state = loaded_state
    explorer.load_world_state(world_state, save_name)  # Pass save name for title
    _finalize_world_setup()
```

**Acceptance Criteria**:
- [ ] World Explorer launcher shows option to generate or load
- [ ] Save browser lists all available saves with metadata
- [ ] Loading a save opens it in read-only omniscient mode
- [ ] Title indicates whether viewing generated or loaded world
- [ ] No team attachment required - pure god mode view
- [ ] Loaded saves are not modified by World Explorer inspection

---

### Phase 5: Integration & Testing (6-8 hours)

**Goal**: Integrate all systems and ensure they work together

#### 5.1: Save/Load Integration

- WorldExplorerMain handles new game vs load save
- Auto-save after world generation
- Scouting data persisted with world state

#### 5.2: Query Integration

- Query builder works in both modes
- PLAYER_COACH mode filters results by scouting
- OMNISCIENT mode shows all results

#### 5.3: Testing

**Unit Tests**:
- [ ] PlayerQueryBuilder constructs correct SQL
- [ ] SafeQueryExecutor blocks dangerous queries
- [ ] ViewContext/PlayerDataProvider return correct values
- [ ] ScoutingDAO saves/loads correctly
- [ ] SaveMetadata serialization round-trips

**Integration Tests**:
- [ ] Full save/load cycle preserves all data
- [ ] Scouting data persists across sessions
- [ ] Query results filtered correctly in PLAYER_COACH mode
- [ ] Same components work in both view modes

**Manual Testing**:
- [ ] New Game → Generate → Save → Exit → Continue → Load
- [ ] World Explorer shows true stats
- [ ] Game UI shows revealed stats only
- [ ] Query builder filters by scouting in Game UI
- [ ] Raw SQL mode works with validation

---

## File Structure

```
gridiron-dynasty/
├── autoloads/
│   └── PersistenceLayer.gd (MODIFIED)
│
├── scenes/
│   ├── main/
│   │   └── world_explorer_main.tscn (MODIFIED)
│   └── ui/
│       ├── main_menu/ (NEW)
│       │   ├── main_menu.tscn
│       │   ├── new_game_config.tscn
│       │   ├── continue_game.tscn
│       │   └── save_entry.tscn
│       ├── game/ (NEW)
│       │   └── game_ui.tscn
│       ├── shared/ (NEW)
│       │   ├── query_builder_panel.tscn
│       │   ├── player_card.tscn
│       │   └── player_search_results.tscn
│       └── world_explorer/
│           └── world_explorer.tscn (MODIFIED)
│
├── scripts/
│   ├── persistence/
│   │   ├── schema.sql (MODIFIED)
│   │   ├── PlayerDAO.gd (MODIFIED)
│   │   ├── SaveMetadata.gd (NEW)
│   │   ├── ScoutingDAO.gd (NEW)
│   │   ├── PlayerQueryBuilder.gd (NEW)
│   │   └── SafeQueryExecutor.gd (NEW)
│   └── ui/
│       ├── main_menu/ (NEW)
│       │   ├── MainMenu.gd
│       │   ├── NewGameConfig.gd
│       │   ├── ContinueGame.gd
│       │   └── SaveEntry.gd
│       ├── game/ (NEW)
│       │   └── GameUI.gd
│       ├── shared/ (NEW)
│       │   ├── ViewContext.gd
│       │   ├── PlayerDataProvider.gd
│       │   └── QueryBuilderPanel.gd
│       └── world_explorer/
│           └── WorldExplorer.gd (MODIFIED)
│
└── project.godot (MODIFIED)
```

---

## Summary

This plan implements:

1. **Hybrid Stats Storage** - Queryable columns + JSON blobs for flexibility
2. **Information Asymmetry** - Player-coach sees revealed stats; AI uses true stats
3. **Unified UI Architecture** - Shared components, two viewing modes (ViewContext)
4. **Powerful Query System** - Visual builder + raw SQL for advanced users
5. **Complete Save System** - Metadata, scouting data, and world state persistence

The architecture ensures:
- **Code reuse** between World Explorer and Game UI
- **Clean separation** between data and presentation
- **Security** through SQL validation and whitelisting
- **Extensibility** for future features

**Estimated Total Effort**: 38-50 hours
