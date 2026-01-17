# Model Hierarchy Documentation

**Status**: Active Reference Document
**Last Updated**: 2026-01-16
**Phase**: Phase 2 Completion (Decomposition)
**Related**: ARCH-008 through ARCH-016, `scripts/core/models/`

## Overview

This document describes the final model hierarchy for Gridiron Dynasty after Phase 2 decomposition. The architecture follows Entity-Component composition patterns to reduce complexity, improve maintainability, and enable independent evolution of concerns.

### Design Goals (Achieved in Phase 2)

1. **Single Responsibility**: Each model class has one clear purpose
2. **Component Composition**: Complex entities decomposed into 8+ focused resources
3. **Clean Inheritance**: Shallow hierarchy (Person → Player/Coach/Scout only)
4. **Type Safety**: Strongly-typed resource classes replace loose dictionaries
5. **Serialization Consistency**: Unified `from_dict` / `to_dict` pattern across all models

---

## Entity Relationship Overview

```
Person (Base Class)
  ├─ Player (8 component resources)
  ├─ Coach (Future)
  └─ Scout (Future)

Team (Independent Entity)
  └─ Roster (1 composite resource)
       └─ RosterEntry (N entries, contains RosterContract)

League (Future)
  └─ Team (N teams)
```

**Design Principle**: Shallow inheritance (max 2 levels), heavy use of composition.

---

## Person Base Class

### Purpose

Abstract base class for all person entities in the simulation. Provides shared identity fields and serialization helpers.

### Class Definition

```gdscript
# res://scripts/core/models/Person.gd
extends Resource
class_name Person

## Base class for all person entities (Player, Coach, Scout)
## Provides shared identity fields and serialization logic

# --- Identity ---
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

## Get the person's full name (first + last)
func get_full_name() -> String:
    return ("%s %s" % [first_name, last_name]).strip_edges()

## Load identity fields from dictionary (called by subclasses)
func from_dict_person(d: Dictionary) -> void:
    id = String(d.get("id", id))
    first_name = String(d.get("first_name", first_name))
    last_name = String(d.get("last_name", last_name))

## Serialize identity fields to dictionary (called by subclasses)
func to_dict_person() -> Dictionary:
    return {
        "id": id,
        "first_name": first_name,
        "last_name": last_name
    }
```

### Design Notes

- **Minimal Surface**: Only 3 fields + 3 methods (identity only)
- **No Gameplay Logic**: Pure data container
- **Helper Pattern**: `from_dict_person` / `to_dict_person` invoked by subclasses
- **Cannot Instantiate**: Abstract base - only subclasses used in practice

---

## Player Entity

### Inheritance

`Player extends Person`

### Composition Structure

Player is composed of **8 component resources** plus inherited Person identity:

```
Player (extends Person)
  ├─ Identity (inherited)
  │    ├─ id: String
  │    ├─ first_name: String
  │    └─ last_name: String
  │
  ├─ Core Fields (in Player.gd)
  │    ├─ position: String
  │    ├─ age: int
  │    ├─ stage: PlayerStage (enum)
  │    ├─ class_tag: String
  │    ├─ jersey_number: int
  │    ├─ gen_mode: String
  │    ├─ school_tag: String
  │    └─ notes: String
  │
  └─ Component Resources (8 total)
       ├─ 1. PlayerPhysicals
       ├─ 2. CombineResults
       ├─ 3. StatsProfile
       ├─ 4. TraitSet
       ├─ 5. CareerRecord
       ├─ 6. HealthStatus
       ├─ 7. Contract
       └─ 8. (RosterEntry lives in Roster, not Player)
```

### Class Definition

```gdscript
# res://scripts/core/models/Player.gd
extends "res://scripts/core/models/Person.gd"
class_name Player

# --- Component Preloads ---
const Contract = preload("res://scripts/core/models/Contract.gd")
const PlayerPhysicals = preload("res://scripts/core/models/PlayerPhysicals.gd")
const CombineResults = preload("res://scripts/core/models/CombineResults.gd")
const TraitSet = preload("res://scripts/core/models/TraitSet.gd")
const CareerRecord = preload("res://scripts/core/models/CareerRecord.gd")
const HealthStatus = preload("res://scripts/core/models/HealthStatus.gd")
const StatsProfile = preload("res://scripts/core/models/StatsProfile.gd")

# --- Lifecycle Enum ---
enum PlayerStage {
    HIGH_SCHOOL = 0,
    COLLEGE = 1,
    DRAFT_ELIGIBLE = 2,
    NFL_ROOKIE = 3,
    NFL_VETERAN = 4,
    NFL_FREE_AGENT = 5,
    RETIRED = 6
}

# --- Core Fields ---
@export var position: String = "ATH"
@export var age: int = 18
@export var stage: PlayerStage = PlayerStage.HIGH_SCHOOL
@export var class_tag: String = ""
@export var jersey_number: int = 0

# --- Component Resources ---
@export var physicals: PlayerPhysicals = null
@export var combine: CombineResults = null
@export var stats_profile: StatsProfile = null
@export var trait_set: TraitSet = null
@export var career: CareerRecord = null
@export var health: HealthStatus = null
@export var contract: Contract = null

func _init() -> void:
    # Initialize all component resources to avoid null checks
    contract = Contract.new()
    physicals = PlayerPhysicals.new()
    combine = CombineResults.new()
    trait_set = TraitSet.new()
    career = CareerRecord.new()
    health = HealthStatus.new()
    stats_profile = StatsProfile.new()
```

---

## Player Component Resources (Detailed)

### 1. PlayerPhysicals

**Purpose**: Physical measurements for player body attributes.

```gdscript
class_name PlayerPhysicals extends Resource

@export var height_in: float = 72.0       # Height in inches
@export var weight_lb: float = 200.0      # Weight in pounds
@export var hand_size_in: float = 9.5     # Hand size in inches
@export var arm_length_in: float = 32.0   # Arm length in inches
@export var wingspan_in: float = 78.0     # Wingspan in inches

# Utility methods
func get_height_feet_inches() -> String
func get_bmi() -> float
func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Separated from Player to group physical measurements logically and enable independent validation/display.

---

### 2. CombineResults

**Purpose**: NFL Combine test results and medical evaluations.

```gdscript
class_name CombineResults extends Resource

# Timed Drills
@export var forty_sec: float = 0.0
@export var shuttle20_sec: float = 0.0
@export var cone3_sec: float = 0.0
@export var shuttle60_sec: float = 0.0

# Strength & Athleticism
@export var vertical_in: float = 0.0
@export var broad_in: float = 0.0
@export var bench_225_reps: int = 0

# Cognitive & Medical
@export var wonderlic: int = 0
@export var cybex_index: float = 0.0
@export var injury_eval: String = "normal"
@export var drug_screen: String = "negative"
@export var combine_year: int = 0

# Utility methods
func has_completed_combine() -> bool
func get_athleticism_score() -> float
func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Combine results are optional (nullable) and have distinct lifecycle (one-time event). Separated for clarity.

---

### 3. StatsProfile

**Purpose**: Player gameplay ratings (current, potential, derived).

```gdscript
class_name StatsProfile extends Resource

# Stat Dictionaries (flexible schema driven by stats.json config)
var current: Dictionary = {}      # Current playable ratings (0-100)
var potential: Dictionary = {}    # Ceiling ratings (max development)
var derived: Dictionary = {}      # Computed stats (cached formulas)

# Access methods
func get_stat(stat_name: String) -> float
func get_potential(stat_name: String) -> float
func get_derived(stat_name: String) -> float
func set_stat(stat_name: String, value: float) -> void
func get_overall_rating() -> float
func get_development_gap(stat_name: String) -> float

# Formula evaluation
func recompute_derived(derived_specs: Array[Dictionary], scope: Dictionary) -> void
func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Stats are config-driven with 20-40 dynamic keys. Dictionary format provides flexibility while StatsProfile encapsulates stat access logic.

---

### 4. TraitSet

**Purpose**: Player traits (visible and hidden) affecting ratings and behavior.

```gdscript
class_name TraitSet extends Resource

@export var visible: Array[String] = []   # Public traits (e.g., "Ball Hawk")
@export var hidden: Array[String] = []    # Hidden traits (e.g., "InjuryFlag:Hamstring")

# Query methods
func has_trait(trait_name: String) -> bool
func has_visible_trait(trait_name: String) -> bool
func has_hidden_trait(trait_name: String) -> bool

# Mutation methods
func add_trait(trait_name: String, is_hidden: bool = false) -> void
func remove_trait(trait_name: String) -> void
func reveal_trait(trait_name: String) -> bool
func get_all_traits() -> Array[String]

func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Traits have unique visibility semantics (visible vs hidden). Encapsulating in TraitSet clarifies trait operations.

---

### 5. CareerRecord

**Purpose**: Career achievements, awards, wear tracking, and development history.

```gdscript
class_name CareerRecord extends Resource

# Award constants
const AWARD_MVP = "mvp"
const AWARD_OPOY = "opoy"
const AWARD_DPOY = "dpoy"
const AWARD_ALL_PRO_FIRST = "all_pro_first"
const AWARD_ALL_PRO_SECOND = "all_pro_second"
const AWARD_PRO_BOWL = "pro_bowl"
const AWARD_ROOKIE_OF_YEAR = "rookie_of_year"
const AWARD_CHAMPIONSHIPS = "championships"

@export var awards: Dictionary = {
    "mvp": 0, "opoy": 0, "dpoy": 0,
    "all_pro_first": 0, "all_pro_second": 0,
    "pro_bowl": 0, "rookie_of_year": 0,
    "championships": 0
}

@export var wear: Dictionary = {
    "snaps": 0,
    "collisions": 0,
    "injury_count": 0
}

@export var development_history: Array = []

# Methods
func add_award(award_type: String, count: int = 1) -> void
func get_award_count(award_type: String) -> int
func get_total_accolades() -> int
func add_snap_wear(snaps: int, collisions: int = 0) -> void
func record_injury() -> void
func add_development_entry(entry: Dictionary) -> void
func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Career data has distinct lifecycle (append-only historical record). Separated to keep Player.gd focused on current state.

---

### 6. HealthStatus

**Purpose**: Player injury tracking and health flags.

```gdscript
class_name HealthStatus extends Resource

const Injury = preload("res://scripts/core/models/Injury.gd")

var injuries: Array[Injury] = []
var injury_prone: bool = false
var career_ending_injury: bool = false

# Query methods
func is_injured() -> bool
func requires_ir() -> bool
func get_total_severity() -> float
func get_injury_by_type(injury_type: String) -> Injury

# Mutation methods
func add_injury(injury: Injury) -> void
func remove_injury(injury_type: String) -> bool
func clear_all_injuries() -> void

func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Injury Nested Type**:
```gdscript
class_name Injury extends Resource

@export var type: String = ""                    # e.g., "hamstring", "acl"
@export var severity: float = 0.0                # 0-100 scale
@export var weeks_remaining: int = 0             # Recovery time
@export var occurred_week: int = 0               # When injury happened
@export var is_career_ending: bool = false
```

**Rationale**: Health/injury state is volatile and has complex mutation logic. Encapsulation prevents pollution of Player class.

---

### 7. Contract

**Purpose**: Player contract with typed fields for financial terms.

```gdscript
class_name Contract extends Resource

@export var current_year: int = 0
@export var total_years: int = 0
@export var annual_value: float = 0.0
@export var guaranteed: float = 0.0
@export var range_min: float = 0.0
@export var range_max: float = 0.0
@export var valuation_source: String = ""
@export var valuation_seed: int = 0
@export var source_eval_id: String = ""

# Contract state methods
func is_active() -> bool
func is_expired() -> bool
func years_remaining() -> int
func advance_year() -> void

func from_dict(d: Dictionary) -> void
func to_dict() -> Dictionary
```

**Rationale**: Contract is a first-class entity with lifecycle (signing, extension, expiration). Strongly-typed resource replaces fragile dictionary.

---

### 8. RosterEntry (Lives in Roster, Not Player)

**Important Architectural Note**: RosterEntry is NOT a Player component. It lives in Team.Roster.

```gdscript
# RosterEntry is part of Team.Roster, not Player
class_name Roster extends Resource

@export var entries: Array[Dictionary] = []  # Array of roster entry dictionaries

# Each entry dictionary contains:
# {
#   "player_id": String,           # Foreign key to Player
#   "status": String,               # "active", "practice_squad", "ir", "suspended"
#   "cap_exempt": bool,
#   "cap_exempt_reason": String,
#   "ir_eligible_week": int,
#   "contract": {...}               # RosterContract (cap accounting)
# }
```

**Why RosterEntry is NOT in Player**:
- Player is context-independent (exists before/after roster)
- RosterEntry represents team-specific state (status, depth chart position)
- One player can only be on one roster at a time (1:1 relationship managed by Team)
- Cap accounting lives with team ownership, not player

---

## Serialization Patterns

### The from_dict / to_dict Contract

Every model class implements two methods:

```gdscript
func from_dict(d: Dictionary) -> void:
    # Deserialize dictionary into this instance
    # Mutates self, returns nothing

func to_dict() -> Dictionary:
    # Serialize this instance to dictionary
    # Returns new dictionary, does not mutate self
```

### Inheritance Pattern

Base classes provide `from_dict_{class}` and `to_dict_{class}` helpers:

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
    # Step 1: Load base class fields
    from_dict_person(d)

    # Step 2: Load Player-specific fields
    position = String(d.get("position", position))
    age = int(d.get("age", age))
    stage = d.get("stage", stage) as PlayerStage

    # Step 3: Load component resources
    if physicals == null:
        physicals = PlayerPhysicals.new()
    if d.has("physicals") and d["physicals"] is Dictionary:
        physicals.from_dict(d["physicals"])

    # Repeat for all 8 components...

func to_dict() -> Dictionary:
    # Step 1: Start with base class fields
    var result = to_dict_person()

    # Step 2: Add Player-specific fields
    result["position"] = position
    result["age"] = age
    result["stage"] = stage

    # Step 3: Add component resources
    result["physicals"] = physicals.to_dict() if physicals != null else {}
    result["combine"] = combine.to_dict() if combine != null else {}
    # ... all 8 components

    return result
```

### Backward Compatibility Pattern

Player.from_dict() supports both legacy flat format and new nested format:

```gdscript
# New nested format (current)
{
    "id": "player-123",
    "first_name": "Tom",
    "last_name": "Brady",
    "position": "QB",
    "physicals": {
        "height_in": 76.0,
        "weight_lb": 225.0
    },
    "stats_profile": {
        "current": {"speed": 75, "strength": 80},
        "potential": {"speed": 85, "strength": 85}
    }
}

# Legacy flat format (pre-Phase 2)
{
    "id": "player-123",
    "first_name": "Tom",
    "last_name": "Brady",
    "position": "QB",
    "height_in": 76.0,        # Flattened into Player
    "weight_lb": 225.0,
    "stats": {"speed": 75},   # Old key name
    "potential": {"speed": 85}
}

# Player.from_dict() handles BOTH formats
func from_dict(d: Dictionary) -> void:
    from_dict_person(d)

    if d.has("physicals") and d["physicals"] is Dictionary:
        # New nested format
        physicals.from_dict(d["physicals"])
    else:
        # Legacy flat format - read directly from player dict
        physicals.height_in = float(d.get("height_in", physicals.height_in))
        physicals.weight_lb = float(d.get("weight_lb", physicals.weight_lb))
```

**Rationale**: Enables gradual migration without breaking existing save files.

---

## Class Diagrams

### Person Inheritance Hierarchy

```
┌─────────────────────────────┐
│         Resource            │  (Godot base class)
│    (Godot Engine Base)      │
└──────────────┬──────────────┘
               │
               │ extends
               ↓
┌─────────────────────────────┐
│          Person             │  (Abstract Base)
├─────────────────────────────┤
│ + id: String                │
│ + first_name: String        │
│ + last_name: String         │
├─────────────────────────────┤
│ + get_full_name() → String  │
│ + from_dict_person(dict)    │
│ + to_dict_person() → dict   │
└──────────────┬──────────────┘
               │
       ┌───────┴───────┬───────────┐
       │               │           │
       │ extends       │ extends   │ extends
       ↓               ↓           ↓
┌──────────┐    ┌──────────┐  ┌──────────┐
│  Player  │    │  Coach   │  │  Scout   │
│ (active) │    │ (future) │  │ (future) │
└──────────┘    └──────────┘  └──────────┘
```

---

### Player Component Composition

```
┌────────────────────────────────────────────────────────────┐
│                        Player                               │
│  (extends Person)                                           │
├────────────────────────────────────────────────────────────┤
│  Inherited from Person:                                     │
│    • id: String                                             │
│    • first_name: String                                     │
│    • last_name: String                                      │
│    • get_full_name() → String                               │
├────────────────────────────────────────────────────────────┤
│  Player Core Fields:                                        │
│    • position: String                                       │
│    • age: int                                               │
│    • stage: PlayerStage (enum)                              │
│    • class_tag: String                                      │
│    • jersey_number: int                                     │
│    • gen_mode, school_tag, notes: String                    │
└────────────────────────────────────────────────────────────┘
         │
         │ composes (1:1)
         │
         ├────> PlayerPhysicals
         │        ├─ height_in, weight_lb
         │        ├─ hand_size_in, arm_length_in
         │        └─ wingspan_in
         │
         ├────> CombineResults (nullable)
         │        ├─ forty_sec, shuttle20_sec
         │        ├─ vertical_in, broad_in
         │        └─ wonderlic, injury_eval
         │
         ├────> StatsProfile
         │        ├─ current: Dictionary
         │        ├─ potential: Dictionary
         │        └─ derived: Dictionary
         │
         ├────> TraitSet
         │        ├─ visible: Array[String]
         │        └─ hidden: Array[String]
         │
         ├────> CareerRecord
         │        ├─ awards: Dictionary
         │        ├─ wear: Dictionary
         │        └─ development_history: Array
         │
         ├────> HealthStatus
         │        ├─ injuries: Array[Injury]
         │        ├─ injury_prone: bool
         │        └─ career_ending_injury: bool
         │
         └────> Contract
                  ├─ current_year, total_years: int
                  ├─ annual_value, guaranteed: float
                  └─ valuation_source, source_eval_id: String
```

---

### Team-Roster-Player Relationship

```
┌────────────────────┐
│       Team         │
├────────────────────┤
│ + id: String       │
│ + name: String     │
│ + league_cap: float│
└─────────┬──────────┘
          │
          │ contains (1:1)
          ↓
┌────────────────────┐
│      Roster        │
├────────────────────┤
│ + entries: Array[Dictionary] │
└─────────┬──────────┘
          │
          │ contains (1:N)
          ↓
┌────────────────────────────────┐
│     RosterEntry (Dictionary)   │
├────────────────────────────────┤
│ + player_id: String (FK)       │ ───────┐
│ + status: String               │        │
│ + cap_exempt: bool             │        │
│ + ir_eligible_week: int        │        │
│ + contract: Dictionary         │        │ references
│   (RosterContract fields)      │        │
└────────────────────────────────┘        ↓
                                  ┌────────────────┐
                                  │    Player      │
                                  │  (separate)    │
                                  └────────────────┘
```

**Key Insight**: Player and RosterEntry are separate concerns.
- Player: "Who is this person and what can they do?"
- RosterEntry: "How is this player used by this team?"

---

## Before/After Comparison

### Before Phase 2 (Monolithic Player)

```gdscript
# Player.gd (old) - 500+ lines, 50+ fields
class_name Player extends Resource

# Identity
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

# Physical measurements (mixed with identity)
@export var height_in: float = 72.0
@export var weight_lb: float = 200.0
@export var hand_size_in: float = 9.5
# ... 5 more physicals fields

# Combine results (mixed with physicals)
@export var forty_sec: float = 0.0
@export var shuttle20_sec: float = 0.0
# ... 10 more combine fields

# Stats (loose dictionaries, hard to validate)
var stats: Dictionary = {}
var potential: Dictionary = {}
var derived: Dictionary = {}

# Traits (mixed with stats)
var traits: Array = []
var hidden_traits: Array = []

# Career (mixed with everything)
var career_awards: Dictionary = {}
var wear: Dictionary = {}
var development_report: Array = []

# Health (mixed with career)
var injuries: Array = []

# Contract (loose dictionary, no validation)
var contract: Dictionary = {}

# ... 500 more lines of mixed concerns
```

**Problems**:
- 50+ fields in single class
- No logical grouping
- Hard to test individual concerns
- Difficult to evolve (change ripples everywhere)
- Unclear ownership of nested dictionaries

---

### After Phase 2 (Decomposed Player)

```gdscript
# Player.gd (new) - 400 lines, 15 fields + 8 components
class_name Player extends Person

# Core identity fields (8 total - position, age, stage, etc.)
@export var position: String = "ATH"
@export var age: int = 18
@export var stage: PlayerStage = PlayerStage.HIGH_SCHOOL
# ... 5 more core fields

# Component resources (8 strongly-typed resources)
@export var physicals: PlayerPhysicals = null       # 5 fields
@export var combine: CombineResults = null          # 12 fields
@export var stats_profile: StatsProfile = null      # 3 dictionaries
@export var trait_set: TraitSet = null              # 2 arrays
@export var career: CareerRecord = null             # 3 collections
@export var health: HealthStatus = null             # 1 array + 2 flags
@export var contract: Contract = null               # 9 fields

# Each component is 50-100 lines with focused responsibility
```

**Benefits**:
- Clear separation of concerns
- 8 independent, testable components
- Type safety via Resource classes
- Easy to evolve (change one component, others unaffected)
- Self-documenting structure

---

## Serialization Example (Full Round-Trip)

### Creating and Saving a Player

```gdscript
# Create new player
var player = Player.new()
player.id = "player-001"
player.first_name = "Tom"
player.last_name = "Brady"
player.position = "QB"
player.age = 23
player.stage = Player.PlayerStage.DRAFT_ELIGIBLE

# Configure physicals
player.physicals.height_in = 76.0
player.physicals.weight_lb = 225.0

# Configure stats
player.stats_profile.current["speed"] = 75
player.stats_profile.current["strength"] = 80
player.stats_profile.potential["speed"] = 85

# Add traits
player.trait_set.add_trait("Ball Hawk", false)  # Visible
player.trait_set.add_trait("Freak:speed", true) # Hidden

# Serialize to dictionary
var player_dict = player.to_dict()

# Result:
{
    "id": "player-001",
    "first_name": "Tom",
    "last_name": "Brady",
    "position": "QB",
    "age": 23,
    "stage": 2,
    "physicals": {
        "height_in": 76.0,
        "weight_lb": 225.0,
        "hand_size_in": 9.5,
        "arm_length_in": 32.0,
        "wingspan_in": 78.0
    },
    "stats_profile": {
        "current": {"speed": 75, "strength": 80},
        "potential": {"speed": 85},
        "derived": {}
    },
    "trait_set": {
        "visible": ["Ball Hawk"],
        "hidden": ["Freak:speed"]
    },
    "combine": {...},
    "career": {...},
    "health": {...},
    "contract": {...}
}
```

### Loading a Player from Dictionary

```gdscript
# Load dictionary (from JSON save file or database)
var loaded_dict = {
    "id": "player-001",
    "first_name": "Tom",
    "last_name": "Brady",
    "position": "QB",
    "physicals": {
        "height_in": 76.0,
        "weight_lb": 225.0
    },
    # ... other components
}

# Deserialize into Player instance
var player = Player.new()
player.from_dict(loaded_dict)

# Access data through strongly-typed resources
print(player.get_full_name())              # "Tom Brady"
print(player.physicals.height_in)          # 76.0
print(player.physicals.get_bmi())          # Calculated
print(player.trait_set.has_trait("Ball Hawk"))  # true
print(player.stats_profile.get_stat("speed"))   # 75
```

---

## Component Lifecycle Management

### Initialization Pattern

All components initialized in `_init()` to avoid null checks:

```gdscript
func _init() -> void:
    # Always initialize all components
    contract = Contract.new()
    physicals = PlayerPhysicals.new()
    combine = CombineResults.new()
    trait_set = TraitSet.new()
    career = CareerRecord.new()
    health = HealthStatus.new()
    stats_profile = StatsProfile.new()
```

**Why**: Godot Resource defaults can be null. Explicit initialization ensures components always exist.

### Null Safety in from_dict

```gdscript
func from_dict(d: Dictionary) -> void:
    from_dict_person(d)

    # Ensure component exists before loading
    if physicals == null:
        physicals = PlayerPhysicals.new()

    # Load nested data if present
    if d.has("physicals") and d["physicals"] is Dictionary:
        physicals.from_dict(d["physicals"])
    else:
        # Fallback: Load legacy flat format
        physicals.height_in = float(d.get("height_in", physicals.height_in))
```

**Pattern**: Always ensure component exists, then load data.

---

## Testing Strategy

### Unit Testing Components

Each component is independently testable:

```gdscript
# Test PlayerPhysicals in isolation
func test_player_physicals_bmi():
    var physicals = PlayerPhysicals.new()
    physicals.height_in = 72.0  # 6 feet
    physicals.weight_lb = 200.0

    var bmi = physicals.get_bmi()
    assert_almost_equal(bmi, 27.1, 0.1)

# Test TraitSet in isolation
func test_trait_set_reveal():
    var trait_set = TraitSet.new()
    trait_set.add_trait("Freak:speed", true)  # Hidden

    assert_true(trait_set.has_hidden_trait("Freak:speed"))
    trait_set.reveal_trait("Freak:speed")
    assert_true(trait_set.has_visible_trait("Freak:speed"))
```

### Integration Testing Player

```gdscript
# Test Player composition
func test_player_serialization_round_trip():
    var original = Player.new()
    original.id = "test-001"
    original.first_name = "Test"
    original.last_name = "Player"
    original.physicals.height_in = 72.0

    # Serialize
    var dict = original.to_dict()

    # Deserialize
    var restored = Player.new()
    restored.from_dict(dict)

    # Verify
    assert_equal(restored.id, original.id)
    assert_equal(restored.first_name, original.first_name)
    assert_equal(restored.physicals.height_in, 72.0)
```

---

## Future Extensions

### Adding New Components

To add a new component (e.g., `SocialMedia` resource):

1. Create new Resource class:
   ```gdscript
   # scripts/core/models/SocialMedia.gd
   class_name SocialMedia extends Resource

   @export var twitter_followers: int = 0
   @export var endorsement_deals: Array[String] = []

   func from_dict(d: Dictionary) -> void: ...
   func to_dict() -> Dictionary: ...
   ```

2. Add to Player:
   ```gdscript
   # Player.gd
   const SocialMedia = preload("res://scripts/core/models/SocialMedia.gd")
   @export var social_media: SocialMedia = null

   func _init() -> void:
       social_media = SocialMedia.new()
       # ... other components

   func from_dict(d: Dictionary) -> void:
       # ... existing code
       if d.has("social_media"):
           social_media.from_dict(d["social_media"])

   func to_dict() -> Dictionary:
       var result = to_dict_person()
       # ... existing fields
       result["social_media"] = social_media.to_dict()
       return result
   ```

3. No changes needed to other components or systems.

### Adding New Person Subclasses

To add Coach or Scout:

```gdscript
# scripts/core/models/Coach.gd
extends "res://scripts/core/models/Person.gd"
class_name Coach

@export var specialty: String = "offense"  # offense, defense, special_teams
@export var years_experience: int = 0
@export var scheme_preference: String = ""

func from_dict(d: Dictionary) -> void:
    from_dict_person(d)  # Load identity from Person
    specialty = String(d.get("specialty", specialty))
    years_experience = int(d.get("years_experience", years_experience))
    scheme_preference = String(d.get("scheme_preference", scheme_preference))

func to_dict() -> Dictionary:
    var result = to_dict_person()  # Start with Person fields
    result["specialty"] = specialty
    result["years_experience"] = years_experience
    result["scheme_preference"] = scheme_preference
    return result
```

---

## References

- **Model Source Files**: `/main/scripts/core/models/`
  - `Person.gd` - Base class
  - `Player.gd` - Main entity
  - `PlayerPhysicals.gd`, `CombineResults.gd`, `StatsProfile.gd`, `TraitSet.gd`, `CareerRecord.gd`, `HealthStatus.gd`, `Contract.gd` - Components
- **Naming Conventions**: See `NAMING_CONVENTIONS.md`
- **Database Schema**: See `DATABASE_SCHEMA.md` for persistence mapping
- **Implementation History**: See `IMPLEMENTATION_TICKETS.md` (ARCH-008 to ARCH-016)

---

## Changelog

### Version 1.0 (2026-01-16) - ARCH-024
- Initial model hierarchy documentation
- Person base class specification
- Player entity with 8 component resources
- Full serialization pattern documentation
- Class diagrams (inheritance and composition)
- Before/after comparison from Phase 2
- Component lifecycle management
- Testing strategy
- Future extension patterns
