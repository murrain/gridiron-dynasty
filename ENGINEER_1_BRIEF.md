# Engineer 1: Foundations (ARCH-017, ARCH-018)

## Role: Database Schema & Abstraction Engineer

## Mission
Design and implement the persistence layer abstraction and complete SQLite schema that supports the Phase 2 decomposed models.

## Tickets Assigned
- **ARCH-017**: Implement PersistenceLayer abstraction (6-8 hrs)
- **ARCH-018**: Design SQLite schema (4-6 hrs)

**Total Estimate**: 10-14 hours

## Phase 2 Model Context

You are designing schema for these **already implemented** models:

### Player Decomposition
```gdscript
# Player.gd - Main entity
class_name Player extends Person

# 8 Component Resources:
@export var physicals: PlayerPhysicals          # height, weight, hand size, etc.
@export var combine: CombineResults             # 40-yard, vertical, etc. (nullable)
@export var stats_profile: StatsProfile         # current, potential, derived dicts
@export var trait_set: TraitSet                 # visible/hidden traits
@export var career: CareerRecord                # awards, wear, development history
@export var health: HealthStatus                # injuries array
@export var contract: Contract                  # contract terms
# Inherited from Person: id, first_name, last_name

# Player fields (not extracted):
@export var position: String
@export var age: int
@export var stage: PlayerStage  # enum: HIGH_SCHOOL, COLLEGE, DRAFT_ELIGIBLE, NFL_ROOKIE, NFL_VETERAN, NFL_FREE_AGENT, RETIRED
@export var class_tag: String
@export var jersey_number: int
@export var gen_mode: String
@export var school_tag: String
@export var notes: String
```

### Roster Decomposition
```gdscript
# Team.gd
class_name Team
@export var roster: Roster

# Roster.gd
class_name Roster
@export var entries: Array[Dictionary]  # Will be Array[RosterEntry] in future

# RosterEntry.gd
class_name RosterEntry extends Resource
@export var player_id: String
@export var status: Roster.RosterStatus  # ACTIVE, PRACTICE_SQUAD, INJURED_RESERVE, SUSPENDED
@export var cap_exempt: bool
@export var cap_exempt_reason: String
@export var ir_eligible_week: int
@export var roster_contract: RosterContract
```

### StatsProfile Structure (Important!)
```gdscript
# StatsProfile.gd
class_name StatsProfile
var current: Dictionary = {}     # 20-40 stat keys: "speed", "strength", "awareness", etc.
var potential: Dictionary = {}   # Same keys as current
var derived: Dictionary = {}     # 5-10 keys: "overall", "pass_rating", etc.
```

**Critical Decision**: How to store these dictionaries?
- **Option A - EAV Table**: Flexible, queryable, but complex joins
- **Option B - JSON Column**: Simple, fast, but not queryable by individual stat
- **Recommendation**: Start with JSON column (simpler), migrate to EAV if query needs emerge

## Deliverable 1: PersistenceLayer Abstraction (ARCH-017)

### File Structure
```
autoloads/PersistenceLayer.gd              # Main autoload (register in project.godot)
scripts/persistence/JSONPersistence.gd     # JSON backend wrapper
scripts/persistence/DatabasePersistence.gd # SQLite backend implementation
```

### PersistenceLayer.gd Interface

```gdscript
# autoloads/PersistenceLayer.gd
extends Node

enum Backend { JSON, SQLITE }

var current_backend: Backend = Backend.JSON
var _json_handler: JSONPersistence = null
var _db_handler: DatabasePersistence = null

func _ready() -> void:
    _json_handler = JSONPersistence.new()
    _db_handler = DatabasePersistence.new()

# --- World State Operations ---

## Save complete world state
## @param world_state: Dictionary with all game entities
## @param save_name: Identifier for this save (e.g., "autosave_year_10")
## @return: true on success, false on failure
func save_world_state(world_state: Dictionary, save_name: String) -> bool:
    match current_backend:
        Backend.JSON:
            return _json_handler.save_world_state(world_state, save_name)
        Backend.SQLITE:
            return _db_handler.save_world_state(world_state, save_name)
    return false

## Load complete world state
## @param save_name: Identifier for save to load
## @return: World state dictionary (empty on failure)
func load_world_state(save_name: String) -> Dictionary:
    match current_backend:
        Backend.JSON:
            return _json_handler.load_world_state(save_name)
        Backend.SQLITE:
            return _db_handler.load_world_state(save_name)
    return {}

# --- Transaction Support (SQLite only, no-op for JSON) ---

func begin_transaction() -> bool:
    if current_backend == Backend.SQLITE:
        return _db_handler.begin_transaction()
    return true  # JSON doesn't need transactions

func commit_transaction() -> bool:
    if current_backend == Backend.SQLITE:
        return _db_handler.commit_transaction()
    return true

func rollback_transaction() -> bool:
    if current_backend == Backend.SQLITE:
        return _db_handler.rollback_transaction()
    return true

# --- Entity-Level Operations (Future API for direct entity access) ---

## Save single player (SQLite: INSERT/UPDATE, JSON: no-op)
func save_player(player: Player) -> bool:
    if current_backend == Backend.SQLITE:
        return _db_handler.save_player(player)
    return false  # JSON saves entire world state at once

## Query players with filters
## @param filters: {position: "QB", age_min: 21, age_max: 25, stage: PlayerStage.NFL_ROOKIE}
func query_players(filters: Dictionary = {}) -> Array[Player]:
    if current_backend == Backend.SQLITE:
        return _db_handler.query_players(filters)
    return []  # JSON doesn't support queries

## Set active backend
func set_backend(backend: Backend) -> void:
    current_backend = backend
    print("PersistenceLayer: Switched to %s backend" % Backend.keys()[backend])
```

### JSONPersistence.gd (Wrapper for Current Logic)

**Task**: Create wrapper that calls existing JSON save/load logic. Don't reimplement - just find and call it.

Search for existing JSON operations:
```bash
grep -r "FileAccess.*JSON\|JSON\.stringify\|JSON\.parse_string" scripts/ --include="*.gd"
```

If no centralized logic exists, implement minimal version:
```gdscript
# scripts/persistence/JSONPersistence.gd
extends RefCounted
class_name JSONPersistence

const SAVE_DIR = "user://saves/"

func save_world_state(world_state: Dictionary, save_name: String) -> bool:
    var path = SAVE_DIR + save_name + ".json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if not file:
        push_error("Failed to open file for writing: %s" % path)
        return false

    var json_string = JSON.stringify(world_state, "\t")  # Pretty print
    file.store_string(json_string)
    file.close()
    return true

func load_world_state(save_name: String) -> Dictionary:
    var path = SAVE_DIR + save_name + ".json"
    if not FileAccess.file_exists(path):
        push_error("Save file not found: %s" % path)
        return {}

    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("Failed to open file for reading: %s" % path)
        return {}

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
        return {}

    return json.data as Dictionary
```

### DatabasePersistence.gd (SQLite Backend)

```gdscript
# scripts/persistence/DatabasePersistence.gd
extends RefCounted
class_name DatabasePersistence

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")
const PlayerDAO = preload("res://scripts/persistence/PlayerDAO.gd")
const TeamDAO = preload("res://scripts/persistence/TeamDAO.gd")

var _db: SQLite = null
var _player_dao: PlayerDAO = null
var _team_dao: TeamDAO = null

const DB_DIR = "user://saves/"

func _init() -> void:
    _db = SQLite.new()

## Open database connection (call before any operations)
func open_database(save_name: String) -> bool:
    _db.path = DB_DIR + save_name + ".db"
    if not _db.open_db():
        push_error("Failed to open database: %s" % _db.path)
        return false

    # Initialize DAOs
    _player_dao = PlayerDAO.new(_db)
    _team_dao = TeamDAO.new(_db)

    return true

## Close database connection
func close_database() -> void:
    if _db:
        _db.close_db()

## Create schema if not exists
func initialize_schema() -> bool:
    # Load schema from SQL file
    var schema_sql = _load_schema_file()
    if schema_sql.is_empty():
        return false

    # Execute schema creation (split by semicolons)
    var statements = schema_sql.split(";")
    for stmt in statements:
        var trimmed = stmt.strip_edges()
        if trimmed.is_empty():
            continue
        if not _db.query(trimmed):
            push_error("Schema creation failed: %s" % trimmed)
            return false

    return true

func _load_schema_file() -> String:
    var path = "res://scripts/persistence/schema.sql"
    if not FileAccess.file_exists(path):
        push_error("Schema file not found: %s" % path)
        return ""

    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return ""

    var content = file.get_as_text()
    file.close()
    return content

# --- Transaction Support ---

func begin_transaction() -> bool:
    return _db.query("BEGIN TRANSACTION")

func commit_transaction() -> bool:
    return _db.query("COMMIT")

func rollback_transaction() -> bool:
    return _db.query("ROLLBACK")

# --- World State Operations ---

func save_world_state(world_state: Dictionary, save_name: String) -> bool:
    if not open_database(save_name):
        return false

    if not initialize_schema():
        close_database()
        return false

    begin_transaction()

    # Save all players
    var players = world_state.get("all_players", [])
    for player_data in players:
        var player = Player.new()
        player.from_dict(player_data)
        if not _player_dao.save(player):
            rollback_transaction()
            close_database()
            return false

    # Save all teams (TODO: Engineer 2)
    # var teams = world_state.get("nfl_teams", {})
    # ...

    commit_transaction()
    close_database()
    return true

func load_world_state(save_name: String) -> Dictionary:
    if not open_database(save_name):
        return {}

    var world_state = {}

    # Load all players
    var players_data = []
    var players = _player_dao.load_all()
    for player in players:
        players_data.append(player.to_dict())
    world_state["all_players"] = players_data

    # Load teams (TODO: Engineer 2)

    close_database()
    return world_state

# --- Entity Operations ---

func save_player(player: Player) -> bool:
    return _player_dao.save(player)

func query_players(filters: Dictionary) -> Array[Player]:
    return _player_dao.query(filters)
```

## Deliverable 2: SQLite Schema Design (ARCH-018)

### Schema File Location
`scripts/persistence/schema.sql`

### Required Tables

#### 1. Schema Metadata (CRITICAL)
```sql
-- Schema versioning for migrations
CREATE TABLE schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO schema_metadata (key, value) VALUES ('schema_version', '1');
INSERT INTO schema_metadata (key, value) VALUES ('created_at', datetime('now'));
```

#### 2. Player Tables

**Main Player Table**:
```sql
CREATE TABLE player (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    position TEXT NOT NULL,
    age INTEGER NOT NULL,
    stage INTEGER NOT NULL,  -- PlayerStage enum value
    class_tag TEXT,
    jersey_number INTEGER DEFAULT 0,
    gen_mode TEXT,
    school_tag TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries (MUST be in initial schema)
CREATE INDEX idx_player_position ON player(position);
CREATE INDEX idx_player_age ON player(age);
CREATE INDEX idx_player_stage ON player(stage);
CREATE INDEX idx_player_school ON player(school_tag);
```

**Component Tables**:
```sql
-- PlayerPhysicals component
CREATE TABLE player_physicals (
    player_id TEXT PRIMARY KEY REFERENCES player(id) ON DELETE CASCADE,
    height_in REAL NOT NULL,
    weight_lb REAL NOT NULL,
    hand_size_in REAL,
    arm_length_in REAL,
    wingspan_in REAL
);

-- CombineResults component (nullable - player may not have done combine)
CREATE TABLE player_combine (
    player_id TEXT PRIMARY KEY REFERENCES player(id) ON DELETE CASCADE,
    forty_sec REAL,
    shuttle20_sec REAL,
    cone3_sec REAL,
    vertical_in REAL,
    broad_in REAL,
    bench_225_reps INTEGER,
    wonderlic INTEGER,
    cybex_index REAL,
    injury_eval TEXT,
    drug_screen TEXT,
    combine_year INTEGER
);

-- StatsProfile component (DECISION: Use JSON columns for flexibility)
CREATE TABLE player_stats (
    player_id TEXT PRIMARY KEY REFERENCES player(id) ON DELETE CASCADE,
    current_stats TEXT NOT NULL,    -- JSON: {"speed": 85, "strength": 72, ...}
    potential_stats TEXT NOT NULL,  -- JSON: {"speed": 92, "strength": 80, ...}
    derived_stats TEXT NOT NULL     -- JSON: {"overall": 78, "pass_rating": 83, ...}
);

-- TraitSet component
CREATE TABLE player_trait (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    trait_name TEXT NOT NULL,
    is_hidden BOOLEAN DEFAULT 0,
    UNIQUE(player_id, trait_name)
);
CREATE INDEX idx_trait_player ON player_trait(player_id);

-- Contract component
CREATE TABLE player_contract (
    player_id TEXT PRIMARY KEY REFERENCES player(id) ON DELETE CASCADE,
    current_year INTEGER DEFAULT 0,
    total_years INTEGER DEFAULT 0,
    annual_value REAL DEFAULT 0.0,
    guaranteed REAL DEFAULT 0.0,
    range_min REAL DEFAULT 0.0,
    range_max REAL DEFAULT 0.0,
    valuation_source TEXT,
    valuation_seed INTEGER,
    source_eval_id TEXT
);

-- CareerRecord component
CREATE TABLE player_career (
    player_id TEXT PRIMARY KEY REFERENCES player(id) ON DELETE CASCADE,
    awards TEXT NOT NULL,           -- JSON: {"mvp": 0, "opoy": 1, ...}
    wear TEXT NOT NULL,             -- JSON: {"snaps": 1500, "collisions": 200, ...}
    development_history TEXT        -- JSON: [{year: 2025, stat: "speed", gain: 3}, ...]
);

-- HealthStatus component
CREATE TABLE player_injury (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    injury_type TEXT NOT NULL,
    severity REAL NOT NULL,
    week_occurred INTEGER,
    season_year INTEGER,
    is_active BOOLEAN DEFAULT 1
);
CREATE INDEX idx_injury_player ON player_injury(player_id);
```

#### 3. Team & Roster Tables

```sql
-- Team entity
CREATE TABLE team (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    abbreviation TEXT,
    league_level TEXT,          -- "nfl", "college", "high_school"
    offensive_scheme TEXT,
    defensive_scheme TEXT,
    cap_limit REAL DEFAULT 0.0,
    is_user_controlled BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- RosterEntry join table
CREATE TABLE roster_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    team_id TEXT NOT NULL REFERENCES team(id) ON DELETE CASCADE,
    player_id TEXT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    status INTEGER NOT NULL DEFAULT 0,  -- RosterStatus enum
    cap_exempt BOOLEAN DEFAULT 0,
    cap_exempt_reason TEXT,
    ir_eligible_week INTEGER DEFAULT 0,
    UNIQUE(team_id, player_id)
);
CREATE INDEX idx_roster_team ON roster_entry(team_id);
CREATE INDEX idx_roster_player ON roster_entry(player_id);

-- RosterContract (part of RosterEntry)
CREATE TABLE roster_contract (
    roster_entry_id INTEGER PRIMARY KEY REFERENCES roster_entry(id) ON DELETE CASCADE,
    base_salary REAL DEFAULT 0.0,
    signing_bonus_proration REAL DEFAULT 0.0,
    guaranteed REAL DEFAULT 0.0,
    incentives REAL DEFAULT 0.0,
    dead_money REAL DEFAULT 0.0
);
```

### Documentation File

Create `docs/architecture/DATABASE_SCHEMA.md`:

```markdown
# Database Schema Documentation

## Schema Version: 1

Last Updated: 2026-01-15

## Overview

Normalized SQLite schema for Gridiron Dynasty world state persistence. Designed to support the Phase 2 decomposed Player model with 8 component resources.

## Design Principles

1. **Normalized Structure**: Player components map to dedicated tables with foreign keys
2. **JSON for Flexible Data**: Stats dictionaries stored as JSON for schema flexibility
3. **Indexes First**: Common query patterns indexed from day 1
4. **Cascading Deletes**: Foreign keys with ON DELETE CASCADE for referential integrity
5. **Versioned Schema**: `schema_metadata` table tracks version for migrations

## Entity Relationship Diagram

```
player (1) ─────< player_physicals (1)
           ─────< player_combine (0..1)
           ─────< player_stats (1)
           ─────< player_trait (*)
           ─────< player_contract (1)
           ─────< player_career (1)
           ─────< player_injury (*)

team (1) ───────< roster_entry (*) >─────── player (*)
roster_entry (1) ─< roster_contract (1)
```

## Tables

### schema_metadata
Tracks schema version for migrations.
- **key** (TEXT, PK): Metadata key (e.g., "schema_version")
- **value** (TEXT): Metadata value
- **updated_at** (TIMESTAMP): Last update timestamp

### player
Main player entity (extends Person base).
- **id** (TEXT, PK): Unique player identifier
- **first_name**, **last_name** (TEXT): Name components
- **position** (TEXT): Player position (QB, RB, WR, etc.)
- **age** (INTEGER): Player age in years
- **stage** (INTEGER): PlayerStage enum (0-6)
- **class_tag** (TEXT): Recruiting class (e.g., "CLASS_OF_2033")
- **jersey_number** (INTEGER): Jersey number (0 = unassigned)
- **gen_mode** (TEXT): Generation mode flag
- **school_tag** (TEXT): Current school identifier
- **notes** (TEXT): Debug/scout notes

**Indexes**:
- `idx_player_position` ON position
- `idx_player_age` ON age
- `idx_player_stage` ON stage
- `idx_player_school` ON school_tag

### player_physicals
Physical measurements (PlayerPhysicals component).
- **player_id** (TEXT, PK, FK): References player(id)
- **height_in** (REAL): Height in inches
- **weight_lb** (REAL): Weight in pounds
- **hand_size_in** (REAL): Hand size in inches
- **arm_length_in** (REAL): Arm length in inches
- **wingspan_in** (REAL): Wingspan in inches

### player_combine
NFL Combine results (CombineResults component, nullable).
- **player_id** (TEXT, PK, FK): References player(id)
- **forty_sec** (REAL): 40-yard dash time
- **shuttle20_sec** (REAL): 20-yard shuttle time
- **cone3_sec** (REAL): 3-cone drill time
- **vertical_in** (REAL): Vertical jump height
- **broad_in** (REAL): Broad jump distance
- **bench_225_reps** (INTEGER): Bench press reps at 225lb
- **wonderlic** (INTEGER): Wonderlic test score
- **cybex_index** (REAL): Injury risk index
- **injury_eval** (TEXT): Medical evaluation
- **drug_screen** (TEXT): Drug screening result
- **combine_year** (INTEGER): Year combine was performed

### player_stats
Stats profile (StatsProfile component) - JSON columns.
- **player_id** (TEXT, PK, FK): References player(id)
- **current_stats** (TEXT): JSON object of current ratings
- **potential_stats** (TEXT): JSON object of potential ratings
- **derived_stats** (TEXT): JSON object of computed stats

**Example JSON**:
```json
{
  "speed": 85,
  "strength": 72,
  "awareness": 68,
  "agility": 80
}
```

### player_trait
Player traits (TraitSet component).
- **id** (INTEGER, PK, AUTO): Surrogate key
- **player_id** (TEXT, FK): References player(id)
- **trait_name** (TEXT): Trait identifier
- **is_hidden** (BOOLEAN): 0=visible, 1=hidden

**Index**: `idx_trait_player` ON player_id

### player_contract
Contract details (Contract component).
- **player_id** (TEXT, PK, FK): References player(id)
- **current_year** (INTEGER): Current year of contract
- **total_years** (INTEGER): Total contract years
- **annual_value** (REAL): Annual salary
- **guaranteed** (REAL): Guaranteed money
- **range_min** (REAL): Value range minimum
- **range_max** (REAL): Value range maximum
- **valuation_source** (TEXT): Source of valuation
- **valuation_seed** (INTEGER): Seed for determinism
- **source_eval_id** (TEXT): Evaluation ID reference

### player_career
Career record (CareerRecord component) - JSON columns.
- **player_id** (TEXT, PK, FK): References player(id)
- **awards** (TEXT): JSON object of award counts
- **wear** (TEXT): JSON object of wear metrics
- **development_history** (TEXT): JSON array of development events

**Example awards JSON**:
```json
{
  "mvp": 0,
  "opoy": 1,
  "dpoy": 0,
  "all_pro_first": 2,
  "pro_bowl": 3,
  "championships": 1
}
```

### player_injury
Injury history (HealthStatus component).
- **id** (INTEGER, PK, AUTO): Surrogate key
- **player_id** (TEXT, FK): References player(id)
- **injury_type** (TEXT): Type of injury
- **severity** (REAL): Severity rating
- **week_occurred** (INTEGER): Week injury occurred
- **season_year** (INTEGER): Season year
- **is_active** (BOOLEAN): Is injury currently active

**Index**: `idx_injury_player` ON player_id

### team
Team entity.
- **id** (TEXT, PK): Unique team identifier
- **name** (TEXT): Team name
- **abbreviation** (TEXT): 2-3 letter code
- **league_level** (TEXT): "nfl", "college", "high_school"
- **offensive_scheme** (TEXT): Offensive scheme
- **defensive_scheme** (TEXT): Defensive scheme
- **cap_limit** (REAL): Salary cap limit
- **is_user_controlled** (BOOLEAN): User team flag

### roster_entry
Roster membership (RosterEntry component).
- **id** (INTEGER, PK, AUTO): Surrogate key
- **team_id** (TEXT, FK): References team(id)
- **player_id** (TEXT, FK): References player(id)
- **status** (INTEGER): RosterStatus enum (0-3)
- **cap_exempt** (BOOLEAN): Cap exempt flag
- **cap_exempt_reason** (TEXT): Reason for exemption
- **ir_eligible_week** (INTEGER): IR return eligibility week

**Indexes**:
- `idx_roster_team` ON team_id
- `idx_roster_player` ON player_id

**Unique Constraint**: (team_id, player_id)

### roster_contract
Roster contract details (RosterContract component).
- **roster_entry_id** (INTEGER, PK, FK): References roster_entry(id)
- **base_salary** (REAL): Base salary
- **signing_bonus_proration** (REAL): Bonus proration
- **guaranteed** (REAL): Guaranteed money
- **incentives** (REAL): Incentive amounts
- **dead_money** (REAL): Dead cap charge

## Common Query Patterns

### Find all NFL quarterbacks
```sql
SELECT * FROM player WHERE position = 'QB' AND stage IN (3, 4);  -- NFL_ROOKIE, NFL_VETERAN
```

### Find free agents by position
```sql
SELECT * FROM player WHERE position = 'WR' AND stage = 5;  -- NFL_FREE_AGENT
```

### Load team roster
```sql
SELECT p.* FROM player p
JOIN roster_entry re ON re.player_id = p.id
WHERE re.team_id = 'team-abc' AND re.status = 0;  -- ACTIVE
```

### Find injured players on team
```sql
SELECT p.*, pi.injury_type, pi.severity FROM player p
JOIN roster_entry re ON re.player_id = p.id
JOIN player_injury pi ON pi.player_id = p.id
WHERE re.team_id = 'team-abc' AND pi.is_active = 1;
```

## Migration Strategy

### Adding New Columns
Additive schema changes are backward compatible:
```sql
ALTER TABLE player ADD COLUMN new_field TEXT;
UPDATE schema_metadata SET value = '2' WHERE key = 'schema_version';
```

### Removing Columns
SQLite doesn't support DROP COLUMN. Use table recreation:
1. Create new table with desired schema
2. Copy data
3. Drop old table
4. Rename new table

### Data Migrations
Store migration scripts in `scripts/persistence/migrations/`:
- `001_to_002.sql` - Migration from version 1 to 2
- `002_to_003.sql` - Migration from version 2 to 3

## Performance Characteristics

**Expected Performance** (10-year world state):
- Save: ~24s (5x improvement over JSON's ~120s)
- Load all players: ~3s
- Query by position: <100ms
- Query by age range: <100ms

**Index Usage**:
All indexes are created in initial schema to avoid ALTER TABLE overhead.

## Future Enhancements

1. **EAV Table for Stats**: If individual stat queries become critical, migrate from JSON to:
   ```sql
   CREATE TABLE player_stat_value (
       player_id TEXT,
       stat_type TEXT,  -- 'current', 'potential', 'derived'
       stat_name TEXT,
       stat_value REAL
   );
   ```

2. **Historical Stats Table**: Track season-by-season performance:
   ```sql
   CREATE TABLE player_season_stats (
       player_id TEXT,
       season_year INTEGER,
       games_played INTEGER,
       -- position-specific stat columns
   );
   ```

3. **Full-Text Search**: Add FTS5 virtual table for player name search

## References

- Phase 2 Models: `/main/scripts/core/models/`
- SQLite Plugin: `addons/godot-sqlite/`
- Implementation Tickets: `/main/docs/architecture/IMPLEMENTATION_TICKETS.md`
```

## Acceptance Criteria

### ARCH-017 Complete When:
- [ ] PersistenceLayer autoload created and functional
- [ ] Backend switching works (JSON backend fully functional)
- [ ] Transaction API defined (begin/commit/rollback)
- [ ] DatabasePersistence skeleton with schema initialization
- [ ] JSONPersistence wrapper delegates to existing or minimal JSON logic
- [ ] Syntax check passes: `godot --headless --check-only --script autoloads/PersistenceLayer.gd`

### ARCH-018 Complete When:
- [ ] Complete SQL schema in `scripts/persistence/schema.sql`
- [ ] Schema versioning table included
- [ ] All indexes defined in initial schema
- [ ] Documentation in `docs/architecture/DATABASE_SCHEMA.md`
- [ ] Entity relationship diagram included
- [ ] Common query patterns documented
- [ ] Migration strategy documented

## Testing Plan

### Syntax Validation
```bash
godot --headless --check-only --script autoloads/PersistenceLayer.gd
godot --headless --check-only --script scripts/persistence/JSONPersistence.gd
godot --headless --check-only --script scripts/persistence/DatabasePersistence.gd
```

### Basic Integration Test
```gdscript
# Test backend switching
var pl = PersistenceLayer.new()
pl.set_backend(PersistenceLayer.Backend.JSON)

# Test JSON save/load (should work immediately)
var test_world = {"current_year": 2025, "all_players": []}
assert(pl.save_world_state(test_world, "test_save"))
var loaded = pl.load_world_state("test_save")
assert(loaded.get("current_year") == 2025)
```

## Blockers & Questions

If you encounter any of these, report immediately:
1. **Cannot find existing JSON save/load logic** → Implement minimal version shown above
2. **SQLite plugin API unclear** → Check `addons/godot-sqlite/godot-sqlite.gd` for documentation
3. **Schema design questions** → Refer to Phase 2 models in `main/scripts/core/models/`

## Reporting Protocol

After each ticket completion, report:
```
CHECKPOINT STATUS - Engineer 1
Ticket: ARCH-0XX
Status: Complete
Files Created:
- autoloads/PersistenceLayer.gd
- scripts/persistence/JSONPersistence.gd
- scripts/persistence/DatabasePersistence.gd
- docs/architecture/DATABASE_SCHEMA.md
- scripts/persistence/schema.sql

Tests Passing: Syntax checks pass
Blockers: None
Next Steps: Begin ARCH-018 schema documentation
```

## Success Criteria

- ✅ Backend abstraction functional with JSON backend working
- ✅ Complete normalized schema designed for Phase 2 models
- ✅ Schema versioning infrastructure in place
- ✅ All indexes defined from day 1
- ✅ Comprehensive documentation with ER diagram

Your foundation work enables Engineers 2 and 3 to implement DAOs and migration tools. Focus on correctness and documentation quality.
