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

## References

- **Phase 2 Models**: `/main/scripts/core/models/` (Player, Team, Roster, etc.)
- **SQLite Plugin**: `addons/godot-sqlite/` (2shady4u/godot-sqlite)
- **Implementation Tickets**: `/main/docs/architecture/IMPLEMENTATION_TICKETS.md`
- **SQLite Documentation**: https://www.sqlite.org/docs.html
- **Foreign Keys**: https://www.sqlite.org/foreignkeys.html
- **FTS5**: https://www.sqlite.org/fts5.html

## Changelog

### Version 1 (2026-01-15)
- Initial schema design
- Core player tables (8 component resources)
- Team and roster tables
- League/draft tables (placeholders for future)
- All indexes defined in initial schema
- JSON columns for flexible data (stats, awards, development history)
