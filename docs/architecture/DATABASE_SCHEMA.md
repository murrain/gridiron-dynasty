# Database Schema Documentation

## Schema Version: 1

**Last Updated**: 2026-01-15
**Status**: Initial Design
**Target**: Phase 3 Database Persistence (ARCH-018)

## Overview

Normalized SQLite schema for Gridiron Dynasty world state persistence. Designed to support the Phase 2 decomposed Player model with 8 component resources and Team/Roster structures.

### Design Philosophy

1. **Component Decomposition**: Each Player component resource maps to a dedicated table
2. **Normalized Structure**: Eliminate redundancy, maintain referential integrity with foreign keys
3. **JSON for Flexibility**: Variable-schema data (stats, awards) stored as JSON columns
4. **Query Performance**: Indexes on all common query patterns from day 1
5. **Cascade Deletes**: ON DELETE CASCADE maintains consistency automatically
6. **Versioned Schema**: `schema_metadata` table enables migration tracking

## Design Principles

### When to Use JSON Columns

**Use JSON columns for**:
- **Variable Schema Data**: Stats dictionaries with 20-40 dynamic keys
- **Nested Structures**: Awards/wear metrics with multiple sub-fields
- **Config-Driven Data**: Data shape driven by external configuration files

**Use normalized tables for**:
- **Queryable Data**: Fields used in WHERE/ORDER BY clauses
- **Indexed Data**: Data requiring fast lookups
- **Relational Data**: Entities with clear relationships (Player → Team)

### Index Strategy

All indexes created in initial schema (not added incrementally) to:
- Avoid ALTER TABLE overhead on large datasets
- Ensure consistent query performance from day 1
- Simplify deployment (no separate index migration scripts)

## Entity Relationship Diagram

```
┌─────────────┐
│   player    │────────────────┐
│  (main)     │                │
└─────────────┘                │
       │                       │
       ├─────< player_physicals (1:1)
       ├─────< player_combine   (1:0..1)
       ├─────< player_stats     (1:1)
       ├─────< player_trait     (1:N)
       ├─────< player_contract  (1:1)
       ├─────< player_career    (1:1)
       └─────< player_injury    (1:N)

┌─────────────┐
│    team     │
└─────────────┘
       │
       └─────< roster_entry (1:N)
                     │
                     ├─────> player (N:1)
                     └─────< roster_contract (1:1)

┌─────────────┐
│   league    │
└─────────────┘
       │
       └─────< team (1:N)
```

### Cardinality Legend
- `1:1` - One-to-one (player has exactly one physicals record)
- `1:0..1` - One-to-zero-or-one (player may not have combine results)
- `1:N` - One-to-many (player has zero or more traits)
- `N:1` - Many-to-one (many roster entries point to one player)

## Tables

### schema_metadata

Tracks schema version for migration management.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| key | TEXT | PRIMARY KEY | Metadata key (e.g., "schema_version") |
| value | TEXT | NOT NULL | Metadata value |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Last update time |

**Purpose**: Enables version-aware migrations. Query `SELECT value FROM schema_metadata WHERE key = 'schema_version'` to check version before applying migrations.

**Example Data**:
```sql
key              | value | updated_at
-----------------+-------+-------------------------
schema_version   | 1     | 2026-01-15 10:30:00
created_at       | ...   | 2026-01-15 10:30:00
description      | ...   | 2026-01-15 10:30:00
```

---

### player

Main player entity (extends Person base class).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT | PRIMARY KEY | Unique player identifier (UUID-style) |
| first_name | TEXT | NOT NULL | Player first name |
| last_name | TEXT | NOT NULL | Player last name |
| position | TEXT | NOT NULL | Position code (QB, RB, WR, TE, OL, DL, LB, CB, S, K, P) |
| age | INTEGER | NOT NULL | Player age in years |
| stage | INTEGER | NOT NULL | PlayerStage enum (0-6) |
| class_tag | TEXT | DEFAULT '' | Recruiting class (e.g., "CLASS_OF_2033") |
| jersey_number | INTEGER | DEFAULT 0 | Jersey number (0 = unassigned) |
| gen_mode | TEXT | DEFAULT '' | Generation mode ("quota", "gauss", "chaos") |
| school_tag | TEXT | DEFAULT '' | Current school identifier |
| notes | TEXT | DEFAULT '' | Debug/scout notes |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Last update time |

**Indexes**:
- `idx_player_position` ON position - For position-based queries
- `idx_player_age` ON age - For age range queries
- `idx_player_stage` ON stage - For lifecycle filtering (NFL, college, etc.)
- `idx_player_school` ON school_tag - For roster queries by school
- `idx_player_class` ON class_tag - For recruiting class queries
- `idx_player_name` ON (last_name, first_name) - For name-based search

**PlayerStage Enum Values**:
```
0 = HIGH_SCHOOL
1 = COLLEGE
2 = DRAFT_ELIGIBLE
3 = NFL_ROOKIE
4 = NFL_VETERAN
5 = NFL_FREE_AGENT
6 = RETIRED
```

---

### player_physicals

Physical measurements (PlayerPhysicals component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| player_id | TEXT | PRIMARY KEY, FK → player(id) | Player reference |
| height_in | REAL | NOT NULL, DEFAULT 72.0 | Height in inches |
| weight_lb | REAL | NOT NULL, DEFAULT 200.0 | Weight in pounds |
| hand_size_in | REAL | DEFAULT 9.5 | Hand size in inches |
| arm_length_in | REAL | DEFAULT 32.0 | Arm length in inches |
| wingspan_in | REAL | DEFAULT 78.0 | Wingspan in inches |

**Cascade**: ON DELETE CASCADE (delete physicals when player deleted)

**Derived Fields** (computed in application):
- `height_feet_inches()` - Format as "6'2""
- `bmi()` - (weight_lb * 703) / (height_in^2)

---

### player_combine

NFL Combine results (CombineResults component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| player_id | TEXT | PRIMARY KEY, FK → player(id) | Player reference |
| forty_sec | REAL | NULL | 40-yard dash time (seconds) |
| shuttle20_sec | REAL | NULL | 20-yard shuttle time (seconds) |
| cone3_sec | REAL | NULL | 3-cone drill time (seconds) |
| vertical_in | REAL | NULL | Vertical jump height (inches) |
| broad_in | REAL | NULL | Broad jump distance (inches) |
| bench_225_reps | INTEGER | NULL | Bench press reps at 225lb |
| wonderlic | INTEGER | NULL | Wonderlic test score (0-50) |
| cybex_index | REAL | NULL | Injury risk index |
| injury_eval | TEXT | NULL | Medical evaluation result |
| drug_screen | TEXT | NULL | Drug screening result |
| combine_year | INTEGER | NULL | Year combine was performed |

**Cascade**: ON DELETE CASCADE

**Nullable**: Entire row may not exist if player hasn't done combine.

**Derived Fields**:
- `has_completed_combine()` - Returns true if combine_year > 0
- `get_athleticism_score()` - Composite score from 40/vertical/broad

---

### player_stats

Stats profile (StatsProfile component) - JSON columns.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| player_id | TEXT | PRIMARY KEY, FK → player(id) | Player reference |
| current_stats | TEXT | NOT NULL, DEFAULT '{}' | JSON object of current ratings |
| potential_stats | TEXT | NOT NULL, DEFAULT '{}' | JSON object of potential ratings |
| derived_stats | TEXT | NOT NULL, DEFAULT '{}' | JSON object of computed stats |

**Cascade**: ON DELETE CASCADE

**JSON Structure Example**:
```json
{
  "speed": 85,
  "strength": 72,
  "awareness": 68,
  "agility": 80,
  "catching": 88,
  "route_running": 82
}
```

**Why JSON?**:
- Stats are config-driven (20-40 dynamic keys)
- Rarely queried individually (load entire player, then filter in-memory)
- Schema flexibility allows adding new stats without ALTER TABLE

**Future Enhancement**: If individual stat queries become critical, migrate to EAV table:
```sql
CREATE TABLE player_stat_value (
    player_id TEXT,
    stat_type TEXT,  -- 'current', 'potential', 'derived'
    stat_name TEXT,
    stat_value REAL,
    PRIMARY KEY (player_id, stat_type, stat_name)
);
CREATE INDEX idx_stat_query ON player_stat_value(stat_name, stat_type);
```

---

### player_trait

Player traits (TraitSet component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Surrogate key |
| player_id | TEXT | NOT NULL, FK → player(id) | Player reference |
| trait_name | TEXT | NOT NULL | Trait identifier (e.g., "injury_prone") |
| is_hidden | INTEGER | DEFAULT 0 | 0=visible, 1=hidden (scouting reveal) |

**Cascade**: ON DELETE CASCADE

**Indexes**:
- `idx_trait_player` ON player_id - For loading all traits for a player
- `idx_trait_name` ON trait_name - For finding players with specific trait

**Unique Constraint**: (player_id, trait_name) - Player cannot have duplicate traits

---

### player_contract

Contract details (Contract component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| player_id | TEXT | PRIMARY KEY, FK → player(id) | Player reference |
| current_year | INTEGER | DEFAULT 0 | Current year of contract (1-based) |
| total_years | INTEGER | DEFAULT 0 | Total contract years |
| annual_value | REAL | DEFAULT 0.0 | Annual salary |
| guaranteed | REAL | DEFAULT 0.0 | Guaranteed money |
| range_min | REAL | DEFAULT 0.0 | Value range minimum |
| range_max | REAL | DEFAULT 0.0 | Value range maximum |
| valuation_source | TEXT | DEFAULT '' | Source of valuation |
| valuation_seed | INTEGER | DEFAULT 0 | Seed for deterministic valuation |
| source_eval_id | TEXT | DEFAULT '' | Evaluation ID reference |

**Cascade**: ON DELETE CASCADE

**Indexes**:
- `idx_contract_active` ON (total_years, current_year) - For finding active contracts

**Contract States** (computed in application):
- `is_active()` - current_year > 0 AND current_year <= total_years
- `is_expired()` - current_year > total_years
- `years_remaining()` - total_years - current_year

---

### player_career

Career record (CareerRecord component) - JSON columns.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| player_id | TEXT | PRIMARY KEY, FK → player(id) | Player reference |
| awards | TEXT | NOT NULL, DEFAULT '{}' | JSON object of award counts |
| wear | TEXT | NOT NULL, DEFAULT '{}' | JSON object of wear metrics |
| development_history | TEXT | DEFAULT '[]' | JSON array of development events |

**Cascade**: ON DELETE CASCADE

**JSON Structure Examples**:

**awards**:
```json
{
  "mvp": 0,
  "opoy": 1,
  "dpoy": 0,
  "all_pro_first": 2,
  "all_pro_second": 3,
  "pro_bowl": 5,
  "rookie_of_year": 1,
  "championships": 1
}
```

**wear**:
```json
{
  "snaps": 1500,
  "collisions": 200,
  "injury_count": 3
}
```

**development_history**:
```json
[
  {"year": 2025, "stat": "speed", "gain": 3},
  {"year": 2026, "stat": "awareness", "gain": 5}
]
```

---

### player_injury

Injury history (HealthStatus component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Surrogate key |
| player_id | TEXT | NOT NULL, FK → player(id) | Player reference |
| injury_type | TEXT | NOT NULL | Type of injury (e.g., "ACL", "Concussion") |
| severity | REAL | NOT NULL | Severity rating (0.0-1.0) |
| week_occurred | INTEGER | NULL | Week injury occurred |
| season_year | INTEGER | NULL | Season year |
| is_active | INTEGER | DEFAULT 1 | 0=healed, 1=active injury |

**Cascade**: ON DELETE CASCADE

**Indexes**:
- `idx_injury_player` ON player_id - For loading player injury history
- `idx_injury_active` ON (is_active, player_id) - For finding currently injured players
- `idx_injury_season` ON season_year - For season-based injury queries

---

### team

Team entity.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT | PRIMARY KEY | Unique team identifier |
| name | TEXT | NOT NULL | Team name |
| abbreviation | TEXT | DEFAULT '' | 2-3 letter code (e.g., "SF", "NE") |
| league_level | TEXT | DEFAULT 'nfl' | "nfl", "college", "high_school" |
| conference | TEXT | DEFAULT '' | Conference affiliation |
| division | TEXT | DEFAULT '' | Division within conference |
| offensive_scheme | TEXT | DEFAULT '' | Offensive scheme type |
| defensive_scheme | TEXT | DEFAULT '' | Defensive scheme type |
| cap_limit | REAL | DEFAULT 0.0 | Salary cap limit |
| is_user_controlled | INTEGER | DEFAULT 0 | 0=CPU, 1=user-controlled |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Indexes**:
- `idx_team_league` ON league_level - For filtering by league
- `idx_team_user` ON is_user_controlled - For finding user team

---

### roster_entry

Team-Player membership (RosterEntry component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Surrogate key |
| team_id | TEXT | NOT NULL, FK → team(id) | Team reference |
| player_id | TEXT | NOT NULL, FK → player(id) | Player reference |
| status | INTEGER | NOT NULL, DEFAULT 0 | RosterStatus enum (0-3) |
| cap_exempt | INTEGER | DEFAULT 0 | 0=counts against cap, 1=cap-exempt |
| cap_exempt_reason | TEXT | DEFAULT '' | Reason for exemption |
| ir_eligible_week | INTEGER | DEFAULT 0 | Week player can return from IR |
| added_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | When player joined roster |

**Cascade**: ON DELETE CASCADE (both team and player)

**Indexes**:
- `idx_roster_team` ON team_id - For loading team roster
- `idx_roster_player` ON player_id - For finding player's team
- `idx_roster_status` ON status - For filtering by roster status

**Unique Constraint**: (team_id, player_id) - Player cannot be on same team twice

**RosterStatus Enum Values**:
```
0 = ACTIVE            (53-man roster)
1 = PRACTICE_SQUAD    (separate limit, cap-exempt)
2 = INJURED_RESERVE   (cap-exempt, player ineligible)
3 = SUSPENDED         (ineligible, may count against cap)
```

---

### roster_contract

Roster contract details (RosterContract component).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| roster_entry_id | INTEGER | PRIMARY KEY, FK → roster_entry(id) | Roster entry reference |
| base_salary | REAL | DEFAULT 0.0 | Base salary |
| signing_bonus_proration | REAL | DEFAULT 0.0 | Bonus proration |
| guaranteed | REAL | DEFAULT 0.0 | Guaranteed money |
| incentives | REAL | DEFAULT 0.0 | Incentive amounts |
| dead_money | REAL | DEFAULT 0.0 | Dead cap charge |

**Cascade**: ON DELETE CASCADE

**Cap Charge Calculation**:
```
cap_charge = base_salary + signing_bonus_proration + guaranteed + incentives
(dead_money excluded from active cap)
```

---

### league

League definitions (optional - for future expansion).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | TEXT | PRIMARY KEY | League identifier |
| name | TEXT | NOT NULL | League full name |
| level | INTEGER | NOT NULL | Hierarchy level (0=pro, 1=college, 2=hs) |
| salary_cap_enabled | INTEGER | DEFAULT 0 | 0=no cap, 1=cap enabled |

**Default Data**:
```sql
INSERT INTO league (id, name, level, salary_cap_enabled) VALUES
    ('nfl', 'National Football League', 0, 1),
    ('college', 'College Football', 1, 0),
    ('high_school', 'High School Football', 2, 0);
```

---

### player_season_stats (Future)

Historical season statistics (not yet implemented).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Surrogate key |
| player_id | TEXT | NOT NULL, FK → player(id) | Player reference |
| season_year | INTEGER | NOT NULL | Season year |
| team_id | TEXT | FK → team(id) | Team player played for |
| games_played | INTEGER | DEFAULT 0 | Games played that season |
| stats_json | TEXT | DEFAULT '{}' | Position-specific stats (JSON) |

**Purpose**: Track per-season performance over player career.

---

### draft_pick (Future)

Draft pick history and ownership (not yet implemented).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT | Surrogate key |
| draft_year | INTEGER | NOT NULL | Draft year |
| round | INTEGER | NOT NULL | Round number |
| pick | INTEGER | NOT NULL | Pick number within round |
| team_id | TEXT | NOT NULL, FK → team(id) | Team that owns pick |
| player_id | TEXT | FK → player(id) | Player selected (NULL if unused) |
| traded_from_team | TEXT | NULL | Original team if pick was traded |

**Unique Constraint**: (draft_year, round, pick)

**Purpose**: Track draft history and pick trading.

---

## Common Query Patterns

### Find all NFL quarterbacks
```sql
SELECT * FROM player
WHERE position = 'QB'
AND stage IN (3, 4);  -- NFL_ROOKIE, NFL_VETERAN
```
**Performance**: Uses `idx_player_position` + `idx_player_stage`

---

### Find free agents by position
```sql
SELECT * FROM player
WHERE position = 'WR'
AND stage = 5;  -- NFL_FREE_AGENT
```
**Performance**: Uses `idx_player_position` + `idx_player_stage`

---

### Load team roster (active players only)
```sql
SELECT p.* FROM player p
JOIN roster_entry re ON re.player_id = p.id
WHERE re.team_id = 'team-abc'
AND re.status = 0;  -- ACTIVE
```
**Performance**: Uses `idx_roster_team` + `idx_roster_status`

---

### Find injured players on team
```sql
SELECT p.*, pi.injury_type, pi.severity
FROM player p
JOIN roster_entry re ON re.player_id = p.id
JOIN player_injury pi ON pi.player_id = p.id
WHERE re.team_id = 'team-abc'
AND pi.is_active = 1;
```
**Performance**: Uses `idx_roster_team` + `idx_injury_active`

---

### Find college players by recruiting class
```sql
SELECT * FROM player
WHERE stage = 1  -- COLLEGE
AND class_tag = 'CLASS_OF_2033';
```
**Performance**: Uses `idx_player_stage` + `idx_player_class`

---

### Calculate team salary cap usage
```sql
SELECT
    t.name,
    t.cap_limit,
    SUM(rc.base_salary + rc.signing_bonus_proration + rc.guaranteed + rc.incentives) AS cap_used
FROM team t
JOIN roster_entry re ON re.team_id = t.id
JOIN roster_contract rc ON rc.roster_entry_id = re.id
WHERE re.cap_exempt = 0  -- Only count non-exempt players
GROUP BY t.id;
```

---

### Find players with specific trait
```sql
SELECT p.* FROM player p
JOIN player_trait pt ON pt.player_id = p.id
WHERE pt.trait_name = 'leadership'
AND pt.is_hidden = 0;  -- Visible trait only
```
**Performance**: Uses `idx_trait_name`

---

### Age range query
```sql
SELECT * FROM player
WHERE age BETWEEN 21 AND 25
AND position = 'RB';
```
**Performance**: Uses `idx_player_age` + `idx_player_position`

---

## Migration Strategy

### Schema Versioning Approach

1. **Check Current Version**:
   ```sql
   SELECT value FROM schema_metadata WHERE key = 'schema_version';
   ```

2. **Apply Migrations Sequentially**:
   - Store migrations in `scripts/persistence/migrations/`
   - Name pattern: `001_to_002.sql`, `002_to_003.sql`
   - Each migration updates `schema_metadata.value`

3. **Example Migration** (add new column):
   ```sql
   -- migrations/001_to_002.sql
   ALTER TABLE player ADD COLUMN new_field TEXT DEFAULT '';
   UPDATE schema_metadata SET value = '2', updated_at = datetime('now')
   WHERE key = 'schema_version';
   ```

### Handling Non-Additive Changes

SQLite doesn't support DROP COLUMN. Use table recreation:

```sql
-- 1. Create new table with desired schema
CREATE TABLE player_new (
    id TEXT PRIMARY KEY,
    -- ... new schema without dropped column
);

-- 2. Copy data
INSERT INTO player_new SELECT id, ... FROM player;

-- 3. Drop old table
DROP TABLE player;

-- 4. Rename new table
ALTER TABLE player_new RENAME TO player;

-- 5. Recreate indexes
CREATE INDEX idx_player_position ON player(position);

-- 6. Update version
UPDATE schema_metadata SET value = '3' WHERE key = 'schema_version';
```

### Backward Compatibility

- **Additive changes** (new columns, indexes) are backward compatible
- **Breaking changes** (removed columns, type changes) require:
  1. Data migration
  2. Version bump
  3. Client update to support new schema

## Performance Characteristics

### Expected Performance (10-year world state)

| Operation | JSON Backend | SQLite Backend | Improvement |
|-----------|--------------|----------------|-------------|
| Save world state | ~120s | ~24s | **5x faster** |
| Load world state | ~30s | ~6s | **5x faster** |
| Query by position | N/A (full load) | <100ms | **300x faster** |
| Query by age range | N/A | <100ms | **300x faster** |
| Load single team roster | ~30s (full load) | <50ms | **600x faster** |

### Index Impact

All indexes defined in initial schema provide:
- **Position queries**: 50-100ms (vs 2-3s full scan)
- **Age range queries**: 50-100ms (vs 2-3s full scan)
- **Team roster loads**: 20-50ms (vs 1-2s full scan)

### Index Strategy (ARCH-022)

The schema defines two categories of indexes:

#### Basic Single-Column Indexes

Created with the table definitions for fundamental queries:

| Index Name | Table | Column(s) | Purpose |
|------------|-------|-----------|---------|
| `idx_player_position` | player | position | Find players by position |
| `idx_player_age` | player | age | Age range queries |
| `idx_player_stage` | player | stage | Lifecycle filtering |
| `idx_player_school` | player | school_tag | School roster queries |
| `idx_player_class` | player | class_tag | Recruiting class queries |
| `idx_player_name` | player | (last_name, first_name) | Name-based search |
| `idx_roster_team` | roster_entry | team_id | Load team roster |
| `idx_roster_player` | roster_entry | player_id | Find player's team |
| `idx_roster_status` | roster_entry | status | Filter by roster status |

#### Composite Performance Indexes (ARCH-022)

Additional indexes for optimized multi-column queries:

| Index Name | Table | Column(s) | Use Case |
|------------|-------|-----------|----------|
| `idx_player_position_age` | player | (position, age) | Draft scouting: "Find QBs aged 21-25" |
| `idx_player_position_stage` | player | (position, stage) | NFL queries: "Find veteran WRs" |
| `idx_player_stage_age` | player | (stage, age) | Draft pool, retirement candidates |
| `idx_player_free_agent` | player | (stage, position, age) WHERE stage=5 | Free agent market queries |
| `idx_roster_team_status` | roster_entry | (team_id, status) | Depth chart: "Active players on team" |
| `idx_contract_expiring` | player_contract | (current_year, total_years) | Contract year queries |
| `idx_contract_value` | player_contract | annual_value | Cap management, market analysis |
| `idx_combine_forty` | player_combine | forty_sec | Athleticism filtering |
| `idx_combine_year` | player_combine | combine_year | Historical combine data |
| `idx_team_conf_div` | team | (conference, division) | Standings, scheduling |

#### Index Selection Guidelines

When adding new indexes, consider:

1. **Query frequency**: Index columns used in frequent WHERE clauses
2. **Column cardinality**: High-cardinality columns benefit more from indexing
3. **Composite order**: Place equality columns before range columns
4. **Write overhead**: Each index adds overhead to INSERT/UPDATE operations
5. **Covering indexes**: Include all selected columns to avoid table lookups

#### Benchmark Tool

Use `BenchmarkDatabase.gd` to measure query performance:

```gdscript
var bench = BenchmarkDatabase.new()
var results = bench.run_benchmarks("save_game_001.db")
bench.print_report(results)

# Analyze specific query execution plan
var plan = bench.explain_query("save_game_001.db",
    "SELECT * FROM player WHERE position = 'QB' AND age BETWEEN 21 AND 25")
```

Target performance thresholds:
- Position queries: <100ms
- Age range queries: <100ms
- Team roster loads: <50ms
- Combined filters: <100ms

### Write Performance

- **Single player insert**: ~1-2ms
- **Batch insert (1000 players)**: ~500-800ms (transaction)
- **World state save (20K players)**: ~20-30s

### Memory Usage

- **JSON backend**: Entire world state in memory (~500MB for 10-year)
- **SQLite backend**: Stream results, ~50-100MB peak

## Future Enhancements

### 1. EAV Table for Stats

If individual stat queries become critical:

```sql
CREATE TABLE player_stat_value (
    player_id TEXT NOT NULL,
    stat_type TEXT NOT NULL,  -- 'current', 'potential', 'derived'
    stat_name TEXT NOT NULL,
    stat_value REAL NOT NULL,
    PRIMARY KEY (player_id, stat_type, stat_name),
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);
CREATE INDEX idx_stat_query ON player_stat_value(stat_name, stat_type);

-- Query: Find all players with speed > 90
SELECT DISTINCT player_id FROM player_stat_value
WHERE stat_name = 'speed' AND stat_type = 'current' AND stat_value > 90;
```

**Trade-offs**:
- **Pros**: Queryable, indexed, normalized
- **Cons**: More complex joins, larger storage

### 2. Full-Text Search

Add FTS5 virtual table for player name search:

```sql
CREATE VIRTUAL TABLE player_fts USING fts5(
    player_id UNINDEXED,
    full_name,
    content=player,
    content_rowid=rowid
);

-- Populate from player table
INSERT INTO player_fts SELECT id, first_name || ' ' || last_name FROM player;

-- Search query
SELECT * FROM player_fts WHERE full_name MATCH 'John*';
```

### 3. Historical Stats Table

Track season-by-season performance:

```sql
CREATE TABLE player_season_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL,
    season_year INTEGER NOT NULL,
    team_id TEXT,
    games_played INTEGER,
    -- Position-specific columns
    pass_yards INTEGER,
    pass_tds INTEGER,
    rush_yards INTEGER,
    rush_tds INTEGER,
    receptions INTEGER,
    rec_yards INTEGER,
    tackles INTEGER,
    sacks REAL,
    interceptions INTEGER,
    UNIQUE(player_id, season_year),
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);
```

### 4. Partitioning Strategy

For very large datasets (50+ years), consider:
- **Year-based partitioning**: Separate tables per decade
- **Archive tables**: Move retired players to separate archive DB
- **View unions**: Create unified view across partitions

```sql
CREATE TABLE player_active AS SELECT * FROM player WHERE stage < 6;
CREATE TABLE player_archived AS SELECT * FROM player WHERE stage = 6;
CREATE VIEW player_all AS
    SELECT * FROM player_active
    UNION ALL
    SELECT * FROM player_archived;
```

## Validation & Maintenance

### Schema Validation

```sql
-- Verify schema version
SELECT value FROM schema_metadata WHERE key = 'schema_version';
-- Expected: "1"

-- Count all tables
SELECT COUNT(*) FROM sqlite_master WHERE type='table';
-- Expected: 15+

-- Verify foreign key constraints enabled
PRAGMA foreign_keys;
-- Expected: 1

-- Check for foreign key violations
PRAGMA foreign_key_check;
-- Expected: (empty result set)
```

### Integrity Checks

```sql
-- Find orphaned physicals records (shouldn't exist with CASCADE)
SELECT pf.player_id FROM player_physicals pf
LEFT JOIN player p ON p.id = pf.player_id
WHERE p.id IS NULL;

-- Find players without physicals (data integrity issue)
SELECT p.id, p.first_name, p.last_name FROM player p
LEFT JOIN player_physicals pf ON pf.player_id = p.id
WHERE pf.player_id IS NULL;

-- Find roster entries without contracts
SELECT re.id, re.team_id, re.player_id FROM roster_entry re
LEFT JOIN roster_contract rc ON rc.roster_entry_id = re.id
WHERE rc.roster_entry_id IS NULL;
```

### Performance Monitoring

```sql
-- Analyze query plan
EXPLAIN QUERY PLAN
SELECT * FROM player WHERE position = 'QB' AND stage = 4;

-- Check index usage
SELECT * FROM sqlite_stat1;

-- Optimize database (rebuild indexes, reclaim space)
VACUUM;
ANALYZE;
```

---

## Migration Guide: JSON to SQLite

### Overview

The `MigrateSaveToDatabase` tool (`scripts/tools/MigrateSaveToDatabase.gd`) provides transaction-based migration from JSON save files to SQLite database format.

### Migration Features

- **All-or-Nothing Transaction**: Migration rolls back on any error
- **Backward Compatibility**: Handles both legacy flat format and new nested format
- **Validation**: Verifies data integrity before writing
- **Progress Reporting**: Clear error messages and warnings
- **Dry Run Mode**: Validate without committing changes

### Basic Usage

```gdscript
# Import migration tool
const MigrateSaveToDatabase = preload("res://scripts/tools/MigrateSaveToDatabase.gd")

# Create migrator instance
var migrator = MigrateSaveToDatabase.new()

# Migrate JSON save to SQLite database
var result = migrator.migrate("save_game_001.json", "save_game_001.db")

# Check results
if result.success:
    print("Migration successful!")
    print("Migrated %d players, %d teams in %d ms" % [
        result.player_count,
        result.team_count,
        result.duration_ms
    ])
else:
    push_error("Migration failed: %s" % result.error)
    for warning in result.warnings:
        push_warning(warning)
```

### Validation-Only Mode

Run validation without creating database:

```gdscript
var migrator = MigrateSaveToDatabase.new()
var validation = migrator.validate_only("save_game_001.json")

if validation.valid:
    print("Save file is valid - ready to migrate")
    print("Contains %d players, %d teams" % [
        validation.player_count,
        validation.team_count
    ])
else:
    push_error("Validation failed: %s" % validation.error)

# Review warnings
for warning in validation.warnings:
    print("Warning: %s" % warning)
```

### Migration Result Structure

```gdscript
{
    "success": bool,              # True if migration completed
    "error": String,              # Error message if failed
    "player_count": int,          # Number of players migrated
    "team_count": int,            # Number of teams migrated
    "warnings": Array[String],    # Non-fatal issues encountered
    "duration_ms": int            # Migration time in milliseconds
}
```

### Migration Process Steps

1. **Load JSON Save**: Parse and validate JSON structure
2. **Validate Data**: Check for required fields and data integrity
3. **Create Database**: Initialize SQLite database with schema
4. **Begin Transaction**: Start atomic transaction
5. **Migrate Entities**: Convert and save players, then teams
6. **Verify Results**: Count records and check foreign keys
7. **Commit Transaction**: Finalize if verification passes, rollback on error

### Handling Legacy Save Formats

The migrator automatically handles both formats:

**Legacy Flat Format** (pre-Phase 2):
```json
{
    "id": "player-123",
    "first_name": "Tom",
    "height_in": 76.0,
    "weight_lb": 225.0,
    "stats": {"speed": 75},
    "traits": ["Ball Hawk"]
}
```

**New Nested Format** (post-Phase 2):
```json
{
    "id": "player-123",
    "first_name": "Tom",
    "physicals": {
        "height_in": 76.0,
        "weight_lb": 225.0
    },
    "stats_profile": {
        "current": {"speed": 75}
    },
    "trait_set": {
        "visible": ["Ball Hawk"]
    }
}
```

Both formats migrate correctly through Player.from_dict() backward compatibility.

### Common Migration Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Failed to load JSON save file" | File not found or invalid path | Verify file exists in `user://saves/` |
| "JSON validation failed" | Missing required fields (players, teams) | Check save file structure |
| "Failed to create database" | Permission or disk space issue | Verify write permissions and disk space |
| "Verification failed" | Entity count mismatch | Check for invalid entity data in source |
| "Skipped invalid player data" | Player missing required fields | Review warnings for specific player IDs |

### Performance Considerations

**Migration Time Estimates**:
- Small save (100 players, 10 teams): ~100ms
- Medium save (1,000 players, 32 teams): ~500ms
- Large save (10,000 players, 100 teams): ~3,000ms

**Optimization Tips**:
- Migration uses single transaction for atomicity
- Batch operations minimize overhead
- Foreign key checks run once at end

---

## DAO Usage Examples

### PlayerDAO Operations

The `PlayerDAO` class (`scripts/persistence/PlayerDAO.gd`) handles all database operations for Player entities and their 8 component resources.

#### Creating a PlayerDAO

```gdscript
# PlayerDAO requires active SQLite connection
var db = SQLite.new()
db.path = "user://saves/game.db"
db.open_db()

# Enable foreign keys
db.query("PRAGMA foreign_keys = ON;")

# Create DAO
var player_dao = PlayerDAO.new(db)
```

#### Saving Players

```gdscript
# Create player
var player = Player.new()
player.id = "player-001"
player.first_name = "Tom"
player.last_name = "Brady"
player.position = "QB"
player.age = 23
player.stage = Player.PlayerStage.DRAFT_ELIGIBLE

# Configure components
player.physicals.height_in = 76.0
player.physicals.weight_lb = 225.0
player.stats_profile.current["speed"] = 75

# Save to database (INSERT OR REPLACE)
if player_dao.save(player):
    print("Player saved successfully")
else:
    push_error("Failed to save player")
```

#### Loading Players

```gdscript
# Load single player by ID
var player = player_dao.load("player-001")
if player:
    print("Loaded: %s" % player.get_full_name())
    print("Position: %s" % player.position)
    print("Height: %s" % player.physicals.get_height_feet_inches())

# Load multiple players
var player_ids = ["player-001", "player-002", "player-003"]
var players = player_dao.load_batch(player_ids)
print("Loaded %d players" % players.size())

# Load all players (use caution on large datasets)
var all_players = player_dao.load_all()
```

#### Querying Players

```gdscript
# Query by position
var qbs = player_dao.query({"position": "QB"})
print("Found %d quarterbacks" % qbs.size())

# Query by age range
var young_players = player_dao.query({
    "age_min": 18,
    "age_max": 21
})

# Query by stage
var nfl_players = player_dao.query({
    "stage": Player.PlayerStage.NFL_VETERAN
})

# Complex query with multiple filters
var draft_eligible_qbs = player_dao.query({
    "position": "QB",
    "stage": Player.PlayerStage.DRAFT_ELIGIBLE,
    "age_min": 21,
    "limit": 50
})

# Query by school (college players)
var alabama_players = player_dao.query({
    "school_tag": "Alabama",
    "stage": Player.PlayerStage.COLLEGE
})
```

#### Updating Players

```gdscript
# Load, modify, save (update pattern)
var player = player_dao.load("player-001")
if player:
    # Modify player
    player.age += 1
    player.stats_profile.current["speed"] -= 1

    # Update in database
    if player_dao.save(player):
        print("Player updated")
```

#### Deleting Players

```gdscript
# Delete single player (CASCADE deletes all components)
if player_dao.delete("player-001"):
    print("Player deleted")

# Delete multiple players
var ids_to_delete = ["player-001", "player-002"]
var deleted_count = player_dao.delete_batch(ids_to_delete)
print("Deleted %d players" % deleted_count)
```

#### Checking Existence

```gdscript
# Check if player exists before loading
if player_dao.exists("player-001"):
    var player = player_dao.load("player-001")
else:
    push_warning("Player not found")
```

---

### TeamDAO Operations

The `TeamDAO` class (`scripts/persistence/TeamDAO.gd`) handles Team entities and Roster with RosterEntry components.

#### Creating a TeamDAO

```gdscript
var db = SQLite.new()
db.path = "user://saves/game.db"
db.open_db()
db.query("PRAGMA foreign_keys = ON;")

# TeamDAO can optionally receive PlayerDAO for loading full player objects
var player_dao = PlayerDAO.new(db)
var team_dao = TeamDAO.new(db, player_dao)
```

#### Saving Teams

```gdscript
# Create team
var team = Team.new()
team.id = "team-ne"
team.name = "New England Patriots"
team.offensive_scheme = "erhardt_perkins"
team.defensive_scheme = "cover_2"
team.league_cap = 224_800_000.0

# Add roster entries
team.roster.add_player_id("player-001", "active")
team.roster.add_player_id("player-002", "active")

# Save to database
if team_dao.save(team):
    print("Team saved successfully")
```

#### Loading Teams

```gdscript
# Load team with player IDs only (lightweight)
var team = team_dao.load("team-ne")
if team:
    print("Team: %s" % team.name)
    print("Roster size: %d" % team.roster.entries.size())

    # Roster entries contain player_id strings
    for entry in team.roster.entries:
        print("Player ID: %s" % entry["player_id"])

# Load team with full Player objects (heavyweight)
var team_with_players = team_dao.load_with_players("team-ne")
if team_with_players:
    # Roster entries now contain full Player resources
    for entry in team_with_players.roster.entries:
        if entry.has("player"):
            var player = entry["player"]
            print("Player: %s (%s)" % [player.get_full_name(), player.position])
```

#### Querying Teams

```gdscript
# Query by name pattern
var afc_teams = team_dao.query({"name_like": "%AFC%"})

# Query by scheme
var west_coast_teams = team_dao.query({
    "offensive_scheme": "west_coast"
})

# Load all teams
var all_teams = team_dao.load_all()
```

#### Updating Teams

```gdscript
# Load, modify roster, save
var team = team_dao.load("team-ne")
if team:
    # Add player to roster
    team.roster.add_player_id("player-003", "active")

    # Remove player from roster
    team.roster.remove_player_id("player-002")

    # Update team
    if team_dao.save(team):
        print("Team roster updated")
```

---

## Transaction Management Patterns

### Why Use Transactions

Transactions ensure **atomicity** - either all operations succeed or none do. Critical for maintaining data consistency.

**Use transactions for**:
- Multi-entity operations (save multiple players + teams)
- Complex state changes (draft picks, trades, season advance)
- Batch operations (import/export, migrations)
- Any operation where partial completion would corrupt world state

### Transaction API

Transactions managed through `PersistenceLayer` autoload:

```gdscript
# Begin transaction
if not PersistenceLayer.begin_transaction():
    push_error("Failed to begin transaction")
    return

# Perform operations...

# Commit on success
if success:
    PersistenceLayer.commit_transaction()
else:
    # Rollback on error
    PersistenceLayer.rollback_transaction()
```

### Pattern 1: Simple Transaction

```gdscript
# Save multiple players atomically
func save_draft_class(players: Array[Player]) -> bool:
    # Begin transaction
    if not PersistenceLayer.begin_transaction():
        return false

    # Save all players
    var player_dao = _get_player_dao()
    for player in players:
        if not player_dao.save(player):
            push_error("Failed to save player: %s" % player.id)
            PersistenceLayer.rollback_transaction()
            return false

    # Commit if all succeeded
    return PersistenceLayer.commit_transaction()
```

### Pattern 2: Complex Multi-Entity Transaction

```gdscript
# Execute draft pick (atomic operation)
func execute_draft_pick(team_id: String, player_id: String, pick_number: int) -> bool:
    if not PersistenceLayer.begin_transaction():
        return false

    var player_dao = _get_player_dao()
    var team_dao = _get_team_dao()

    # Step 1: Update player stage
    var player = player_dao.load(player_id)
    if not player:
        PersistenceLayer.rollback_transaction()
        return false

    player.stage = Player.PlayerStage.NFL_ROOKIE
    if not player_dao.save(player):
        PersistenceLayer.rollback_transaction()
        return false

    # Step 2: Add player to team roster
    var team = team_dao.load(team_id)
    if not team:
        PersistenceLayer.rollback_transaction()
        return false

    team.roster.add_player_id(player_id, "active")
    if not team_dao.save(team):
        PersistenceLayer.rollback_transaction()
        return false

    # Step 3: Record draft pick history
    if not _record_draft_pick(team_id, player_id, pick_number):
        PersistenceLayer.rollback_transaction()
        return false

    # All steps succeeded - commit
    return PersistenceLayer.commit_transaction()
```

### Pattern 3: Try-Catch Style Transaction

```gdscript
func perform_complex_operation() -> bool:
    var success = false

    # Begin transaction
    if not PersistenceLayer.begin_transaction():
        return false

    # Try block equivalent
    while true:
        # Operation 1
        if not _do_operation_1():
            break

        # Operation 2
        if not _do_operation_2():
            break

        # Operation 3
        if not _do_operation_3():
            break

        # All operations succeeded
        success = true
        break

    # Commit or rollback
    if success:
        return PersistenceLayer.commit_transaction()
    else:
        PersistenceLayer.rollback_transaction()
        return false
```

### Pattern 4: Nested Transaction Simulation

SQLite doesn't support true nested transactions, but you can simulate with savepoints:

```gdscript
# Manual savepoint management
func save_with_savepoint() -> bool:
    var db = _get_database()

    # Begin main transaction
    db.query("BEGIN TRANSACTION;")

    # Create savepoint
    db.query("SAVEPOINT before_roster_changes;")

    # Try roster changes
    if not _update_roster():
        # Rollback to savepoint (keeps transaction alive)
        db.query("ROLLBACK TO SAVEPOINT before_roster_changes;")
        # Try alternative approach
        if not _update_roster_alternative():
            db.query("ROLLBACK;")
            return false

    # Release savepoint
    db.query("RELEASE SAVEPOINT before_roster_changes;")

    # Commit main transaction
    db.query("COMMIT;")
    return true
```

### Transaction Best Practices

1. **Keep Transactions Short**: Long transactions lock tables and reduce concurrency
2. **Always Handle Errors**: Check return values and rollback on failure
3. **Batch Related Operations**: Group logically related changes in one transaction
4. **Avoid User Input During Transaction**: Don't wait for user actions mid-transaction
5. **Test Rollback Paths**: Verify rollback correctly restores state

---

## Performance Optimization Tips

### Index Usage Guidelines

**Indexes Improve Performance For**:
- WHERE clause filters (`WHERE position = 'QB'`)
- ORDER BY sorting (`ORDER BY age DESC`)
- JOIN operations (foreign keys)

**Indexes Hurt Performance For**:
- INSERT/UPDATE/DELETE operations (must update indexes)
- Wide indexes (many columns = large index size)

**Rule of Thumb**: Index columns used in WHERE/ORDER BY, but keep index count minimal.

### Query Optimization Techniques

#### 1. Use Parameterized Queries

```gdscript
# GOOD - parameterized (SQLite can cache query plan)
db.query_with_bindings(
    "SELECT * FROM player WHERE position = ?",
    ["QB"]
)

# BAD - string concatenation (new query plan every time)
db.query("SELECT * FROM player WHERE position = '%s'" % position)
```

#### 2. Limit Result Sets

```gdscript
# GOOD - limit results
var qbs = player_dao.query({
    "position": "QB",
    "limit": 50
})

# BAD - load all, then slice
var all_qbs = player_dao.query({"position": "QB"})
var top_50 = all_qbs.slice(0, 50)  # Wasteful!
```

#### 3. Use Covering Indexes

```gdscript
# Query uses index on (position, age) - no table lookup needed
db.query("SELECT position, age FROM player WHERE position = 'QB'")

# This requires table lookup (first_name not in index)
db.query("SELECT first_name FROM player WHERE position = 'QB'")
```

#### 4. Analyze Query Plans

```gdscript
# Check if query uses index
db.query("EXPLAIN QUERY PLAN SELECT * FROM player WHERE position = 'QB'")
var plan = db.query_result

# Look for "USING INDEX" in plan
for row in plan:
    print(row)
# Expected output: "SEARCH player USING INDEX idx_player_position (position=?)"
```

### Batch Operations

#### Batch Saves

```gdscript
# GOOD - single transaction for batch
PersistenceLayer.begin_transaction()
for player in players:
    player_dao.save(player)
PersistenceLayer.commit_transaction()

# BAD - separate transaction per player (slow!)
for player in players:
    PersistenceLayer.begin_transaction()
    player_dao.save(player)
    PersistenceLayer.commit_transaction()
```

#### Batch Loads

```gdscript
# GOOD - batch load with IN clause
var player_ids = ["p1", "p2", "p3"]
var players = player_dao.load_batch(player_ids)

# BAD - individual loads (N+1 query problem)
var players = []
for player_id in player_ids:
    players.append(player_dao.load(player_id))
```

### Database Maintenance

#### Regular VACUUM

Reclaim deleted space and optimize file structure:

```gdscript
# Run after deleting many records
db.query("VACUUM;")
```

#### Regular ANALYZE

Update query optimizer statistics:

```gdscript
# Run after significant data changes
db.query("ANALYZE;")
```

#### Monitoring Database Size

```gdscript
# Check database file size
var db_path = "user://saves/game.db"
var file = FileAccess.open(db_path, FileAccess.READ)
if file:
    var size_bytes = file.get_length()
    var size_mb = size_bytes / 1024.0 / 1024.0
    print("Database size: %.2f MB" % size_mb)
    file.close()
```

### Performance Benchmarks

Use `BenchmarkDatabase.gd` tool for performance testing:

```gdscript
const BenchmarkDatabase = preload("res://scripts/tools/BenchmarkDatabase.gd")

var benchmark = BenchmarkDatabase.new()
var results = benchmark.run_full_benchmark("user://saves/game.db")

print("Save 1000 players: %d ms" % results.save_1000_players_ms)
print("Load 1000 players: %d ms" % results.load_1000_players_ms)
print("Query 100 QBs: %d ms" % results.query_100_qbs_ms)
```

**Target Performance** (on typical hardware):
- Save 1000 players: <500ms
- Load 1000 players: <300ms
- Query 100 players: <50ms
- Complex JOIN query: <100ms

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Foreign key constraint failed"

**Cause**: Attempting to insert roster_entry referencing non-existent player.

**Solution**:
```gdscript
# Ensure player exists before adding to roster
if player_dao.exists(player_id):
    team.roster.add_player_id(player_id, "active")
else:
    push_error("Cannot add non-existent player to roster")
```

#### Issue: "Database is locked"

**Cause**: Another connection has an active transaction.

**Solutions**:
```gdscript
# 1. Enable WAL mode for better concurrency
db.query("PRAGMA journal_mode = WAL;")

# 2. Set busy timeout (wait up to 5 seconds)
db.query("PRAGMA busy_timeout = 5000;")

# 3. Ensure transactions are properly closed
PersistenceLayer.commit_transaction()  # or rollback_transaction()
```

#### Issue: "Slow queries on large datasets"

**Diagnostic**:
```gdscript
# Check if indexes are being used
db.query("EXPLAIN QUERY PLAN SELECT * FROM player WHERE position = 'QB'")
var plan = db.query_result
print(plan)  # Should show "USING INDEX"
```

**Solutions**:
```gdscript
# 1. Ensure indexes exist
db.query("SELECT name FROM sqlite_master WHERE type='index'")
var indexes = db.query_result
print("Indexes: %s" % indexes)

# 2. Run ANALYZE to update statistics
db.query("ANALYZE;")

# 3. Consider adding composite index for common queries
db.query("CREATE INDEX idx_player_position_stage ON player(position, stage);")
```

#### Issue: "Players missing component data after load"

**Cause**: Component table missing data or foreign key mismatch.

**Diagnostic**:
```gdscript
# Find players without physicals
db.query("""
    SELECT p.id, p.first_name, p.last_name
    FROM player p
    LEFT JOIN player_physicals pf ON pf.player_id = p.id
    WHERE pf.player_id IS NULL
""")
var missing = db.query_result
print("Players missing physicals: %d" % missing.size())
```

**Solution**:
```gdscript
# Re-save player to create missing component records
var player = player_dao.load(player_id)
if player.physicals == null:
    player.physicals = PlayerPhysicals.new()
player_dao.save(player)  # Will create physicals record
```

#### Issue: "Migration fails with verification error"

**Diagnostic**:
```gdscript
# Run validation-only first
var migrator = MigrateSaveToDatabase.new()
var validation = migrator.validate_only("save.json")

if not validation.valid:
    print("Validation error: %s" % validation.error)
    for warning in validation.warnings:
        print("Warning: %s" % warning)
```

**Solution**: Fix invalid data in source JSON before migrating.

#### Issue: "Cannot delete team due to foreign key constraint"

**Cause**: Roster entries reference team, CASCADE delete may be disabled.

**Solution**:
```gdscript
# Ensure foreign keys are enabled
db.query("PRAGMA foreign_keys = ON;")

# Delete roster entries first (if CASCADE not working)
db.query_with_bindings("DELETE FROM roster_entry WHERE team_id = ?", [team_id])
db.query_with_bindings("DELETE FROM team WHERE id = ?", [team_id])
```

### Debugging Tools

#### Enable SQL Logging

```gdscript
# Log all SQL queries (verbose!)
var db = SQLite.new()
db.verbosity_level = SQLite.VERBOSE

# Execute query
db.query("SELECT * FROM player WHERE position = 'QB'")
# Prints: "Executing query: SELECT * FROM player WHERE position = 'QB'"
```

#### Inspect Database Structure

```gdscript
# List all tables
db.query("SELECT name FROM sqlite_master WHERE type='table'")
var tables = db.query_result

# Show table schema
db.query("PRAGMA table_info(player)")
var schema = db.query_result

# List all indexes
db.query("SELECT name, tbl_name FROM sqlite_master WHERE type='index'")
var indexes = db.query_result
```

#### Check Data Integrity

```gdscript
# Run integrity check
db.query("PRAGMA integrity_check;")
var result = db.query_result
if result.size() == 1 and result[0]["integrity_check"] == "ok":
    print("Database integrity OK")
else:
    push_error("Integrity check failed: %s" % result)

# Check foreign key integrity
db.query("PRAGMA foreign_key_check;")
var violations = db.query_result
if violations.size() > 0:
    push_error("Foreign key violations found: %s" % violations)
```

---

## References

- **Phase 2 Models**: `/main/scripts/core/models/` (Player, Team, Roster, etc.)
- **Persistence Layer**: `/main/autoloads/PersistenceLayer.gd`
- **Data Access Objects**: `/main/scripts/persistence/PlayerDAO.gd`, `TeamDAO.gd`
- **Migration Tool**: `/main/scripts/tools/MigrateSaveToDatabase.gd`
- **Benchmark Tool**: `/main/scripts/tools/BenchmarkDatabase.gd`
- **SQLite Plugin**: `addons/godot-sqlite/` (2shady4u/godot-sqlite)
- **Implementation Tickets**: `/main/docs/architecture/IMPLEMENTATION_TICKETS.md`
- **Model Hierarchy**: `/main/docs/architecture/MODEL_HIERARCHY.md`
- **Naming Conventions**: `/main/docs/architecture/NAMING_CONVENTIONS.md`
- **SQLite Documentation**: https://www.sqlite.org/docs.html
- **Foreign Keys**: https://www.sqlite.org/foreignkeys.html
- **FTS5**: https://www.sqlite.org/fts5.html
- **Query Planning**: https://www.sqlite.org/queryplanner.html

## Changelog

### Version 1.2 (2026-01-16) - ARCH-025
- Added Migration Guide section with JSON to SQLite migration instructions
- Added DAO Usage Examples (PlayerDAO and TeamDAO complete examples)
- Added Transaction Management Patterns (4 patterns with code examples)
- Added Performance Optimization Tips (indexing, query optimization, batch operations)
- Added Troubleshooting section (common issues, solutions, debugging tools)
- Expanded References section with cross-document links

### Version 1.1 (2026-01-15) - ARCH-022
- Added composite performance indexes for common query patterns
- Added filtered index for free agent queries
- Added benchmark tool (`BenchmarkDatabase.gd`) for performance validation
- Added migration tool (`MigrateSaveToDatabase.gd`) for JSON to SQLite conversion
- Updated documentation with index strategy guidelines

### Version 1.0 (2026-01-15)
- Initial schema design
- Core player tables (8 component resources)
- Team and roster tables
- League/draft tables (placeholders for future)
- All indexes defined in initial schema
- JSON columns for flexible data (stats, awards, development history)
