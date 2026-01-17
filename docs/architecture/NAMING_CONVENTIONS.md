# Naming Conventions

**Status**: Active Reference Document
**Last Updated**: 2026-01-16
**Related**: Phase 1 Refactoring (PR #135), ARCH-001, ARCH-002, ARCH-007

## Overview

This document codifies naming conventions established during Phase 1 refactoring and applied consistently across the Gridiron Dynasty codebase. These conventions ensure clarity, reduce cognitive overhead, and maintain consistency across 10,000+ lines of game code.

## Design Philosophy

1. **Clarity over Brevity**: Full words preferred over abbreviations (`position` not `pos`)
2. **Semantic Consistency**: Same concept = same name everywhere (`id` always means identifier)
3. **Type Safety through Naming**: Suffixes indicate data types and units (`_in` = inches, `_sec` = seconds)
4. **No Redundant Prefixes**: Removed "Sport" prefix pattern - namespacing handled by class hierarchy
5. **GDScript Conventions**: Follow Godot style guide for PascalCase classes, snake_case variables

---

## ID Field Conventions

### The `id` Pattern

**Rule**: Entity models use `id` as their primary identifier field. Reference fields use `{entity}_id` pattern.

#### In Model Classes (Primary Key)
```gdscript
# Person.gd
@export var id: String = ""

# Player.gd (inherits from Person)
# Uses inherited `id` field - no redefinition needed

# Team.gd
@export var id: String = ""

# Contract.gd
# No id field - Contract is a component, not an independent entity
```

**Rationale**:
- Simple `id` in models keeps code clean and matches database primary key naming
- Component resources (PlayerPhysicals, Contract, etc.) don't need IDs - they're owned by parent entities
- Consistent with SQL convention where primary key is simply `id`

#### In Dictionaries and References (Foreign Key)

```gdscript
# Roster entry dictionary
{
    "player_id": "player-123",  # Reference to Player.id
    "team_id": "team-456",      # Reference to Team.id
    "status": "active"
}

# Scouting data dictionary key
scouting_data: Dictionary = {
    "player-123": { ... },  # Key is player_id
}

# World state structure
world_state = {
    "players": [...],           # Array of player dictionaries
    "teams": [...],             # Array of team dictionaries
    "players_by_id": {...}      # Dictionary keyed by player_id
}
```

**Pattern Rules**:
- Dictionary keys for entity lookups: Use `{entity}_id` as the key name
- Dictionaries that map ID → data: Key is the ID value itself
- Foreign key fields: Always use `{entity}_id` suffix (never just `id`)

#### Lookup Pattern Example

```gdscript
# CORRECT: Lookup player from world state
var player_id = roster_entry["player_id"]
var player = world_state["players_by_id"][player_id]

# INCORRECT: Ambiguous naming
var id = roster_entry["id"]  # Which entity's ID?
var player = players[id]      # What collection is this?
```

---

## Collection Naming

### Plural vs Singular Rules

**Rule**: Use plural for collections of entities, singular for single instances and types.

#### Arrays and Dictionaries (Collections)

```gdscript
# Arrays of entities - always plural
var players: Array[Player] = []
var teams: Array[Team] = []
var injuries: Array[Injury] = []

# Dictionary collections - plural
var players_by_id: Dictionary = {}      # ID → Player lookup
var teams_by_name: Dictionary = {}      # Name → Team lookup

# World state structure - plural for collections
world_state = {
    "players": [...],           # Array of all players
    "teams": [...],             # Array of all teams
    "players_by_id": {...},     # Player lookup dictionary
    "current_year": 2026        # Singular for scalars
}
```

#### Type Names and Single Instances (Singular)

```gdscript
# Class names - always singular (represents one instance)
class_name Player
class_name Team
class_name Roster
class_name Contract

# Single instance variables - singular
var player: Player = null
var team: Team = null
var roster_entry: Dictionary = {}

# Component resources - singular (one per parent)
@export var contract: Contract = null
@export var physicals: PlayerPhysicals = null
```

#### Special Cases

```gdscript
# Stats and traits - context dependent
@export var stats_profile: StatsProfile = null  # Singular - one profile per player
var stats: Dictionary = {}                       # Plural - multiple stat values

@export var trait_set: TraitSet = null          # Singular - one set per player
var traits: Array[String] = []                   # Plural - multiple trait strings

# Roster - singular despite containing multiple players
@export var roster: Roster = null               # Roster is a single entity
var roster_entries: Array[Dictionary] = []      # Entries within roster are plural
```

---

## World State Key Patterns

### Standard Keys

World state dictionary follows consistent naming for top-level keys:

```gdscript
world_state = {
    # === Entity Collections (plural) ===
    "players": Array[Dictionary],       # All player data
    "teams": Array[Dictionary],         # All team data
    "coaches": Array[Dictionary],       # All coach data (future)
    "scouts": Array[Dictionary],        # All scout data (future)

    # === Lookup Indexes (plural_by_field) ===
    "players_by_id": Dictionary,        # player_id → player data
    "teams_by_id": Dictionary,          # team_id → team data

    # === Simulation State (singular) ===
    "current_year": int,                # Current simulation year
    "current_week": int,                # Current week within season
    "league_name": String,              # League identifier
    "user_team_id": String,             # User's controlled team

    # === Metadata (singular) ===
    "version": String,                  # Save format version
    "created_at": String,               # ISO timestamp
    "last_saved": String,               # ISO timestamp
}
```

### Naming Pattern Rules

1. **Entity Arrays**: Plural entity name (`players`, `teams`, `injuries`)
2. **Lookup Dictionaries**: `{plural}_by_{field}` (`players_by_id`, `teams_by_name`)
3. **Scalar State**: Singular descriptive name (`current_year`, `league_name`)
4. **Avoid Abbreviations**: Use full words (`current_week` not `cur_wk`)

---

## Unit Suffix Conventions

### The Unit Pattern

**Rule**: Measurement fields must include unit suffix to prevent ambiguity. Use standard abbreviations.

#### Physical Measurements

```gdscript
# PlayerPhysicals.gd
@export var height_in: float = 72.0        # Inches (6 feet = 72 inches)
@export var weight_lb: float = 200.0       # Pounds
@export var hand_size_in: float = 9.5      # Inches
@export var arm_length_in: float = 32.0    # Inches
@export var wingspan_in: float = 78.0      # Inches
```

#### Time Measurements

```gdscript
# CombineResults.gd
@export var forty_sec: float = 0.0          # 40-yard dash in seconds
@export var shuttle20_sec: float = 0.0      # 20-yard shuttle in seconds
@export var cone3_sec: float = 0.0          # 3-cone drill in seconds
@export var shuttle60_sec: float = 0.0      # 60-yard shuttle in seconds
```

#### Jump Measurements

```gdscript
# CombineResults.gd
@export var vertical_in: float = 0.0        # Vertical jump in inches
@export var broad_in: float = 0.0           # Broad jump in inches
```

### Standard Unit Suffixes

| Suffix | Unit | Usage |
|--------|------|-------|
| `_in` | Inches | Height, length, jump distances |
| `_ft` | Feet | Large distances (rare - prefer inches for consistency) |
| `_lb` | Pounds | Weight, force |
| `_sec` | Seconds | Time measurements |
| `_min` | Minutes | Longer durations |
| `_ms` | Milliseconds | High-precision timing |
| `_pct` | Percentage | Rates, ratios (0-100 scale) |
| `_usd` | US Dollars | Currency (rare - usually implied) |

### No Suffix Cases

**Rule**: Omit suffix when unit is obvious from context or field is unitless.

```gdscript
# Counts and indices - no suffix needed
@export var age: int = 18                   # Years implied
@export var jersey_number: int = 0          # Unitless identifier
@export var bench_225_reps: int = 0         # "reps" in name clarifies unit
@export var wonderlic: int = 0              # Unitless test score
@export var combine_year: int = 0           # Years implied

# Ratings and grades - no suffix (0-100 scale implied)
var speed: float = 75.0                     # Game stat rating
var strength: float = 80.0                  # Game stat rating
var overall: float = 85.0                   # Derived rating
```

---

## Class Naming Conventions

### GDScript Class Naming

**Rule**: Follow Godot style guide - PascalCase for classes, no prefixes.

#### Entity Models

```gdscript
# Base classes
class_name Person        # Base class for all people entities
class_name Resource      # Godot base class

# Derived entities
class_name Player        # Inherits from Person
class_name Coach         # Inherits from Person
class_name Scout         # Inherits from Person

# Top-level entities
class_name Team
class_name League
class_name Roster
```

#### Component Resources

```gdscript
# Player component resources
class_name PlayerPhysicals
class_name CombineResults
class_name StatsProfile
class_name TraitSet
class_name CareerRecord
class_name HealthStatus
class_name Contract

# Nested components
class_name Injury        # Used within HealthStatus
class_name RosterEntry   # Used within Roster
```

#### Data Access Objects

```gdscript
# DAO pattern - "DAO" suffix
class_name PlayerDAO
class_name TeamDAO
class_name LeagueDAO     # Future
```

#### Utilities and Managers

```gdscript
# Manager pattern - "Manager" suffix (only when truly managing lifecycle)
class_name PlayerGenerationManager
class_name ScoutingResourceManager

# System pattern - "System" suffix (rare - for systems spanning multiple entities)
class_name DevelopmentSystem         # Future

# Tool/Utility pattern - descriptive name
class_name MigrateSaveToDatabase
class_name BenchmarkDatabase
```

### Removed Patterns

**Historical Note**: Phase 1 removed "Sport" prefix pattern.

```gdscript
# OLD (before Phase 1)
class_name SportPlayer      # Redundant prefix
class_name SportTeam        # Redundant prefix

# NEW (after Phase 1)
class_name Player           # Clean, namespacing via directory structure
class_name Team             # Clean, obvious context
```

**Rationale**:
- Godot's class_name provides global namespace
- Directory structure (`scripts/core/models/`) provides logical grouping
- "Sport" prefix added no semantic value
- Shorter names improve readability

---

## Enum Naming Conventions

### Enum and Value Naming

**Rule**: Enum type names use PascalCase. Enum values use UPPER_SNAKE_CASE.

#### Enum Type: PascalCase

```gdscript
# Player.gd
enum PlayerStage {
    HIGH_SCHOOL = 0,
    COLLEGE = 1,
    DRAFT_ELIGIBLE = 2,
    NFL_ROOKIE = 3,
    NFL_VETERAN = 4,
    NFL_FREE_AGENT = 5,
    RETIRED = 6
}

# Roster.gd
enum RosterStatus {
    ACTIVE = 0,
    PRACTICE_SQUAD = 1,
    INJURED_RESERVE = 2,
    SUSPENDED = 3
}

# PersistenceLayer.gd
enum Backend {
    JSON,
    SQLITE
}
```

#### Enum Values: UPPER_SNAKE_CASE

```gdscript
# Usage in code
player.stage = Player.PlayerStage.NFL_ROOKIE
roster_entry.status = Roster.RosterStatus.ACTIVE
backend = PersistenceLayer.Backend.SQLITE

# Conditional checks
if player.stage == Player.PlayerStage.COLLEGE:
    print("College player")

match roster_status:
    Roster.RosterStatus.ACTIVE:
        apply_cap_hit()
    Roster.RosterStatus.INJURED_RESERVE:
        exempt_from_cap()
```

#### Explicit Value Assignment

**Rule**: Always assign explicit integer values to enum members for serialization stability.

```gdscript
# CORRECT - explicit values ensure stable serialization
enum PlayerStage {
    HIGH_SCHOOL = 0,
    COLLEGE = 1,
    DRAFT_ELIGIBLE = 2,
    NFL_ROOKIE = 3,
    NFL_VETERAN = 4,
    NFL_FREE_AGENT = 5,
    RETIRED = 6
}

# INCORRECT - implicit values break when enum is reordered
enum PlayerStage {
    HIGH_SCHOOL,      # Implicitly 0, but fragile
    COLLEGE,          # Implicitly 1
    DRAFT_ELIGIBLE    # Implicitly 2
}
```

**Rationale**: Explicit values prevent save file corruption when enum members are reordered or removed during refactoring.

---

## Variable Naming Patterns

### Local Variables

```gdscript
# snake_case for all local variables
var player_id: String = "player-123"
var team_name: String = "Patriots"
var is_active: bool = true
var roster_count: int = 53

# Temporary/loop variables - descriptive names preferred
for player in players:
    print(player.get_full_name())

# Avoid single-letter variables except in small scopes
for i in range(10):          # OK - common idiom
    print(i)

var p = player               # AVOID - unclear abbreviation
```

### Member Variables

```gdscript
# snake_case with @export for serialization
@export var id: String = ""
@export var first_name: String = ""
@export var age: int = 18

# Private/internal members - leading underscore (optional but recommended)
var _cached_overall: float = 0.0
var _last_update_time: int = 0

# Constants - UPPER_SNAKE_CASE
const MAX_ROSTER_SIZE = 53
const DEFAULT_SALARY_CAP = 224_800_000  # Use underscores for readability
```

### Boolean Variables

**Rule**: Use `is_`, `has_`, `can_` prefixes for boolean clarity.

```gdscript
# Status checks
var is_active: bool = true
var is_injured: bool = false
var is_over_cap: bool = false

# Possession checks
var has_contract: bool = true
var has_trait: bool = false

# Capability checks
var can_play: bool = true
var can_be_drafted: bool = false

# Methods returning boolean
func is_nfl_player() -> bool:
    return stage in [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN]

func has_completed_combine() -> bool:
    return combine_year > 0
```

---

## Method Naming Patterns

### Getters and Setters

```gdscript
# Getters - use get_ prefix
func get_full_name() -> String:
    return "%s %s" % [first_name, last_name]

func get_stat(name: String) -> float:
    return stats_profile.get_stat(name)

func get_overall_rating() -> float:
    return get_derived("overall")

# Setters - use set_ prefix
func set_stat(name: String, value: float) -> void:
    stats_profile.set_stat(name, value)

# Boolean getters - use is_, has_, can_ (no get_ prefix)
func is_injured() -> bool:
    return injuries.size() > 0

func has_trait(trait_name: String) -> bool:
    return visible.has(trait_name) or hidden.has(trait_name)
```

### Serialization Methods

**Rule**: Use consistent `from_dict` / `to_dict` pattern across all models.

```gdscript
# Every Resource model implements these two methods
func from_dict(d: Dictionary) -> void:
    # Load data from dictionary into this instance
    id = String(d.get("id", id))
    first_name = String(d.get("first_name", first_name))

func to_dict() -> Dictionary:
    # Serialize this instance to dictionary
    return {
        "id": id,
        "first_name": first_name,
        "last_name": last_name
    }
```

**Inheritance Pattern**: Base classes provide `from_dict_{class}` and `to_dict_{class}` helpers.

```gdscript
# Person.gd (base class)
func from_dict_person(d: Dictionary) -> void:
    id = String(d.get("id", id))
    first_name = String(d.get("first_name", first_name))
    last_name = String(d.get("last_name", last_name))

func to_dict_person() -> Dictionary:
    return {"id": id, "first_name": first_name, "last_name": last_name}

# Player.gd (derived class)
func from_dict(d: Dictionary) -> void:
    from_dict_person(d)  # Load base class fields
    position = String(d.get("position", position))
    age = int(d.get("age", age))

func to_dict() -> Dictionary:
    var result = to_dict_person()  # Start with base fields
    result["position"] = position
    result["age"] = age
    return result
```

### Action Methods

```gdscript
# Use imperative verbs for actions
func add_injury(injury: Injury) -> void
func remove_injury(injury_type: String) -> bool
func clear_all_injuries() -> void

func add_trait(trait_name: String, is_hidden: bool = false) -> void
func reveal_trait(trait_name: String) -> bool

func transition_to(new_stage: PlayerStage) -> bool
func advance_year() -> void
```

---

## File Naming

### Script Files

**Rule**: PascalCase matching class name.

```
scripts/core/models/Player.gd           # class_name Player
scripts/core/models/Team.gd             # class_name Team
scripts/core/models/PlayerPhysicals.gd  # class_name PlayerPhysicals

scripts/persistence/PlayerDAO.gd        # class_name PlayerDAO
scripts/persistence/TeamDAO.gd          # class_name TeamDAO

scripts/tools/MigrateSaveToDatabase.gd  # class_name MigrateSaveToDatabase
```

### Resource Files

```
resources/stats.json                    # Config data
resources/traits.json                   # Config data
resources/derived_stats.json            # Formula definitions

scripts/persistence/schema.sql          # Database schema
```

### Documentation Files

```
docs/architecture/NAMING_CONVENTIONS.md        # UPPER_SNAKE_CASE.md
docs/architecture/MODEL_HIERARCHY.md           # UPPER_SNAKE_CASE.md
docs/architecture/DATABASE_SCHEMA.md           # UPPER_SNAKE_CASE.md
docs/architecture/IMPLEMENTATION_TICKETS.md    # UPPER_SNAKE_CASE.md
```

---

## Anti-Patterns to Avoid

### 1. Inconsistent ID Naming

```gdscript
# INCORRECT - mixing id patterns
var player_id = roster_entry["id"]           # Ambiguous!
var team = teams_by_id[roster_entry["team"]] # Missing _id suffix

# CORRECT - consistent {entity}_id pattern
var player_id = roster_entry["player_id"]
var team = teams_by_id[roster_entry["team_id"]]
```

### 2. Abbreviated Variable Names

```gdscript
# INCORRECT - unclear abbreviations
var pos = "QB"
var ht = 72.0
var wt = 200.0

# CORRECT - full words
var position = "QB"
var height_in = 72.0
var weight_lb = 200.0
```

### 3. Missing Unit Suffixes

```gdscript
# INCORRECT - ambiguous units
var height = 72.0     # Inches? Feet? Centimeters?
var time = 4.5        # Seconds? Minutes? Milliseconds?

# CORRECT - explicit units
var height_in = 72.0
var forty_sec = 4.5
```

### 4. Redundant Prefixes

```gdscript
# INCORRECT - redundant context
class_name SportPlayer
class_name GameTeam
class_name DataContract

# CORRECT - context from namespace/directory
class_name Player      # In scripts/core/models/
class_name Team        # In scripts/core/models/
class_name Contract    # In scripts/core/models/
```

### 5. Implicit Enum Values

```gdscript
# INCORRECT - fragile to reordering
enum PlayerStage {
    HIGH_SCHOOL,       # 0
    COLLEGE,           # 1
    NFL_ROOKIE         # 2
}

# CORRECT - explicit values
enum PlayerStage {
    HIGH_SCHOOL = 0,
    COLLEGE = 1,
    NFL_ROOKIE = 3     # Can skip values intentionally
}
```

---

## Cross-References

- **Model Hierarchy**: See `MODEL_HIERARCHY.md` for inheritance patterns
- **Database Schema**: See `DATABASE_SCHEMA.md` for table/column naming
- **Implementation Tickets**: See `IMPLEMENTATION_TICKETS.md` for refactoring history
- **Godot Style Guide**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

---

## Changelog

### Version 1.0 (2026-01-16) - ARCH-023
- Initial documentation of naming conventions
- Codified patterns from Phase 1 refactoring (PR #135)
- ID field conventions (id vs {entity}_id)
- Collection naming (plural vs singular)
- World state key patterns
- Unit suffix conventions
- Class naming (removed Sport prefix)
- Enum naming (PascalCase type, UPPER_SNAKE_CASE values)
- Method naming patterns (from_dict/to_dict, getters/setters)
- File naming conventions
- Anti-patterns section
