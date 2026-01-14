# Architecture Improvement Implementation Tickets

> Generated from Architecture Review (2026-01-14)
> Status: PENDING - Waiting for dependent branch merge

---

## Overview

This document contains detailed implementation tickets for the architectural improvements identified by the architecture-guardian review. Work is organized into three phases with dependencies clearly marked.

**Total Estimated Effort:** 173-218 hours across 10-14 weeks
**Risk Level:** Low to Medium (phased approach minimizes disruption)

> **Note:** Phase 4 (Testing Infrastructure) can run in parallel with Phases 1-3, potentially reducing calendar time.

---

## Phase 1: Foundation (Low Risk, High Value)

### ARCH-001: Rename SportPlayer to Player

**Priority:** HIGH
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** None

#### Description
Remove the unnecessary "Sport" prefix from `SportPlayer` class. The prefix adds no semantic value in a sports simulation context and creates naming inconsistency.

#### Current State
```gdscript
# scripts/core/models/Player.gd:4
class_name SportPlayer
```

#### Target State
```gdscript
class_name Player
```

#### Acceptance Criteria
- [ ] Rename `class_name SportPlayer` → `class_name Player` in Player.gd
- [ ] Update all references to `SportPlayer` across codebase
- [ ] Update type hints: `var player: SportPlayer` → `var player: Player`
- [ ] Update factory methods and constructors
- [ ] Verify serialization still works (from_dict/to_dict)
- [ ] All existing tests pass
- [ ] No runtime errors in 1-year simulation

#### Files to Modify
- `scripts/core/models/Player.gd` (primary)
- All files referencing `SportPlayer` (use grep to find)

#### Search Command
```bash
grep -r "SportPlayer" --include="*.gd" scripts/
```

---

### ARCH-002: Rename SportRoster to Roster

**Priority:** HIGH
**Estimated Effort:** 1-2 hours
**Risk:** LOW
**Dependencies:** None (can parallelize with ARCH-001)

#### Description
Remove the unnecessary "Sport" prefix from `SportRoster` class for consistency with ARCH-001.

#### Current State
```gdscript
# scripts/core/models/Roster.gd:2
class_name SportRoster
```

#### Target State
```gdscript
class_name Roster
```

#### Acceptance Criteria
- [ ] Rename `class_name SportRoster` → `class_name Roster`
- [ ] Update all references across codebase
- [ ] Update type hints in Team.gd and related files
- [ ] Verify serialization compatibility
- [ ] All existing tests pass

#### Files to Modify
- `scripts/core/models/Roster.gd` (primary)
- `scripts/core/models/Team.gd` (has `roster: SportRoster`)
- All files referencing `SportRoster`

---

### ARCH-003: Create Person Base Class

**Priority:** HIGH
**Estimated Effort:** 3-4 hours
**Risk:** LOW
**Dependencies:** ARCH-001 (Player rename should happen first)

#### Description
Introduce a `Person` base class to eliminate code duplication across `Player`, `Coach`, and `Scout` entities. All three share identity fields (id, first_name, last_name) but currently duplicate this code.

#### Current State
```gdscript
# Player.gd
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

func get_full_name() -> String:
    return ("%s %s" % [first_name, last_name]).strip_edges()

# Coach.gd - Same fields, NO get_full_name() method
@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

# Scout.gd - Different pattern!
@export var name: String = "Scout"  # Single name field
```

#### Target State
```gdscript
# scripts/core/models/Person.gd (NEW FILE)
extends Resource
class_name Person

@export var id: String = ""
@export var first_name: String = ""
@export var last_name: String = ""

func get_full_name() -> String:
    return ("%s %s" % [first_name, last_name]).strip_edges()

func from_dict_person(d: Dictionary) -> void:
    id = String(d.get("id", id))
    first_name = String(d.get("first_name", first_name))
    last_name = String(d.get("last_name", last_name))

func to_dict_person() -> Dictionary:
    return {
        "id": id,
        "first_name": first_name,
        "last_name": last_name
    }
```

```gdscript
# Player.gd
extends Person
class_name Player

# Remove duplicate id, first_name, last_name, get_full_name()
# Keep position, age, etc.

func from_dict(d: Dictionary) -> void:
    from_dict_person(d)
    position = String(d.get("position", position))
    # ... rest of player fields
```

```gdscript
# Coach.gd
extends Person
class_name Coach

# Remove duplicate fields
# Add get_full_name() usage (now inherited)
```

```gdscript
# Scout.gd
extends Person
class_name Scout

# BREAKING: Change from single "name" field to first_name/last_name
# Migration: Split existing "name" into first_name + last_name
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/Person.gd` with shared identity logic
- [ ] Modify Player.gd to `extends Person`, remove duplicate fields
- [ ] Modify Coach.gd to `extends Person`, remove duplicate fields
- [ ] Modify Scout.gd to `extends Person`, migrate `name` → `first_name/last_name`
- [ ] Add migration logic in Scout.from_dict() for backward compatibility
- [ ] Test polymorphic operations (iterating over Array[Person])
- [ ] All serialization tests pass
- [ ] All existing tests pass

#### Migration Notes for Scout
```gdscript
# Scout.gd from_dict() - backward compatibility
func from_dict(d: Dictionary) -> void:
    from_dict_person(d)

    # Migration: old saves have "name", new saves have first_name/last_name
    if d.has("name") and not d.has("first_name"):
        var parts = String(d.get("name", "")).split(" ", false, 2)
        first_name = parts[0] if parts.size() > 0 else "Unknown"
        last_name = parts[1] if parts.size() > 1 else ""
```

#### Files to Create
- `scripts/core/models/Person.gd`

#### Files to Modify
- `scripts/core/models/Player.gd`
- `scripts/core/models/Coach.gd`
- `scripts/core/models/Scout.gd`

---

### ARCH-004: Extract Contract Resource

**Priority:** HIGH
**Estimated Effort:** 4-5 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-001

#### Description
Replace the untyped `contract: Dictionary` field in Player with a proper `Contract` Resource class. This provides type safety, validation, and centralized contract logic.

#### Current State
```gdscript
# Player.gd:82
@export var contract: Dictionary = {}

# Player.gd:248-259 - Schema buried in default function
func _default_contract() -> Dictionary:
    return {
        "current_year": 0,
        "total_years": 0,
        "annual_value": 0.0,
        "guaranteed": 0.0,
        "range_min": 0.0,
        "range_max": 0.0,
        "valuation_source": "",
        "valuation_seed": 0,
        "source_eval_id": ""
    }
```

#### Target State
```gdscript
# scripts/core/models/Contract.gd (NEW FILE)
extends Resource
class_name Contract

@export var current_year: int = 0
@export var total_years: int = 0
@export var annual_value: float = 0.0
@export var guaranteed: float = 0.0
@export var range_min: float = 0.0
@export var range_max: float = 0.0
@export var valuation_source: String = ""
@export var valuation_seed: int = 0
@export var source_eval_id: String = ""

func is_active() -> bool:
    return current_year > 0 and current_year <= total_years

func is_expired() -> bool:
    return total_years > 0 and current_year > total_years

func years_remaining() -> int:
    return max(0, total_years - current_year)

func advance_year() -> void:
    if is_active():
        current_year += 1

func from_dict(d: Dictionary) -> void:
    current_year = int(d.get("current_year", 0))
    total_years = int(d.get("total_years", 0))
    annual_value = float(d.get("annual_value", 0.0))
    guaranteed = float(d.get("guaranteed", 0.0))
    range_min = float(d.get("range_min", 0.0))
    range_max = float(d.get("range_max", 0.0))
    valuation_source = String(d.get("valuation_source", ""))
    valuation_seed = int(d.get("valuation_seed", 0))
    source_eval_id = String(d.get("source_eval_id", ""))

func to_dict() -> Dictionary:
    return {
        "current_year": current_year,
        "total_years": total_years,
        "annual_value": annual_value,
        "guaranteed": guaranteed,
        "range_min": range_min,
        "range_max": range_max,
        "valuation_source": valuation_source,
        "valuation_seed": valuation_seed,
        "source_eval_id": source_eval_id
    }
```

```gdscript
# Player.gd - Updated
@export var contract: Contract = null

func _init() -> void:
    contract = Contract.new()

func from_dict(d: Dictionary) -> void:
    # ... other fields ...
    if d.has("contract"):
        contract.from_dict(d["contract"])

func to_dict() -> Dictionary:
    var result = {
        # ... other fields ...
        "contract": contract.to_dict()
    }
    return result
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/Contract.gd` with all fields and methods
- [ ] Update Player.gd to use `contract: Contract` instead of Dictionary
- [ ] Add `is_active()`, `is_expired()`, `years_remaining()`, `advance_year()` methods
- [ ] Update Player.from_dict() to handle nested Contract deserialization
- [ ] Update Player.to_dict() to serialize Contract
- [ ] Backward compatible with existing save files
- [ ] Update all contract access patterns: `player.contract["field"]` → `player.contract.field`
- [ ] All contract-related tests pass
- [ ] ContractNegotiation service works with new type

#### Files to Create
- `scripts/core/models/Contract.gd`

#### Files to Modify
- `scripts/core/models/Player.gd`
- `scripts/core/player_agency/ContractNegotiation.gd`
- Any file accessing `player.contract` as Dictionary

#### Search Command
```bash
grep -r "\.contract\[" --include="*.gd" scripts/
grep -r "contract\.get(" --include="*.gd" scripts/
```

---

### ARCH-005: Type Injuries Array

**Priority:** HIGH
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** ARCH-001

#### Description
Change `injuries: Array[Dictionary]` to `injuries: Array[Injury]`. The `Injury` resource already exists but isn't being used - injuries are stored as untyped dictionaries.

#### Current State
```gdscript
# Player.gd:71
var injuries: Array[Dictionary] = []

# But Injury.gd EXISTS as a proper Resource!
# scripts/core/models/Injury.gd
extends Resource
class_name Injury
```

#### Target State
```gdscript
# Player.gd
var injuries: Array[Injury] = []

func add_injury(injury: Injury) -> void:
    injuries.append(injury)

func clear_injuries() -> void:
    injuries.clear()

func has_active_injury() -> bool:
    return injuries.size() > 0
```

#### Acceptance Criteria
- [ ] Change Player.injuries type from `Array[Dictionary]` to `Array[Injury]`
- [ ] Update Player.from_dict() to deserialize injuries as Injury resources
- [ ] Update Player.to_dict() to serialize Injury array
- [ ] Update all code that creates injuries to use `Injury.new()` instead of Dictionary
- [ ] Update all code that reads injury properties to use typed access
- [ ] Backward compatible with existing save files (Dictionary → Injury migration)
- [ ] All injury-related tests pass

#### Migration in from_dict
```gdscript
func from_dict(d: Dictionary) -> void:
    # ... other fields ...
    injuries.clear()
    for injury_data in d.get("injuries", []):
        var injury = Injury.new()
        injury.from_dict(injury_data)
        injuries.append(injury)
```

#### Files to Modify
- `scripts/core/models/Player.gd`
- Any file creating injuries as Dictionary
- Any file reading injury properties

---

### ARCH-006: Add PlayerStage Enum

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** LOW
**Dependencies:** ARCH-001

#### Description
Add a `PlayerStage` enum to discriminate player lifecycle states at the type level. Currently, player stage is inferred from optional string fields and collection membership.

#### Current State
```gdscript
# Player.gd - Stage inferred from context
@export var class_tag: String = ""  # Set for HS/college players
@export var school_tag: String = "" # Set for current school

# Stage determined by which collection player is in:
# - draft_pool[year] = draft eligible
# - free_agents = NFL free agent
# - retired_players = retired
# - nfl_rosters[team] = NFL active
```

#### Target State
```gdscript
# Player.gd
enum PlayerStage {
    HIGH_SCHOOL,
    COLLEGE,
    DRAFT_ELIGIBLE,
    NFL_ROOKIE,
    NFL_VETERAN,
    NFL_FREE_AGENT,
    RETIRED
}

@export var stage: PlayerStage = PlayerStage.HIGH_SCHOOL

func is_nfl_player() -> bool:
    return stage in [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN]

func is_available_for_draft() -> bool:
    return stage == PlayerStage.DRAFT_ELIGIBLE

func is_college_player() -> bool:
    return stage == PlayerStage.COLLEGE

func transition_to(new_stage: PlayerStage) -> void:
    # Validate transition is legal
    var valid_transitions = {
        PlayerStage.HIGH_SCHOOL: [PlayerStage.COLLEGE],
        PlayerStage.COLLEGE: [PlayerStage.DRAFT_ELIGIBLE, PlayerStage.COLLEGE],
        PlayerStage.DRAFT_ELIGIBLE: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_FREE_AGENT],
        PlayerStage.NFL_ROOKIE: [PlayerStage.NFL_VETERAN, PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
        PlayerStage.NFL_VETERAN: [PlayerStage.NFL_FREE_AGENT, PlayerStage.RETIRED],
        PlayerStage.NFL_FREE_AGENT: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_VETERAN, PlayerStage.RETIRED],
        PlayerStage.RETIRED: []
    }
    if new_stage in valid_transitions.get(stage, []):
        stage = new_stage
    else:
        push_warning("Invalid stage transition: %s -> %s" % [PlayerStage.keys()[stage], PlayerStage.keys()[new_stage]])
```

#### Acceptance Criteria
- [ ] Add `PlayerStage` enum to Player.gd
- [ ] Add `@export var stage: PlayerStage` field
- [ ] Add helper methods: `is_nfl_player()`, `is_college_player()`, etc.
- [ ] Add `transition_to()` with validation
- [ ] Update from_dict/to_dict to serialize stage
- [ ] Backward compatibility: Infer stage from existing fields if not present
- [ ] Update player generation to set appropriate stage
- [ ] Update draft/FA/retirement logic to use stage transitions

#### Migration Logic
```gdscript
func from_dict(d: Dictionary) -> void:
    # ... other fields ...

    # Explicit stage if present
    if d.has("stage"):
        stage = d["stage"] as PlayerStage
    else:
        # Infer from context (backward compatibility)
        stage = _infer_stage_from_fields(d)

func _infer_stage_from_fields(d: Dictionary) -> PlayerStage:
    var has_contract = d.get("contract", {}).get("total_years", 0) > 0
    var has_school = d.get("school_tag", "") != ""
    var age = int(d.get("age", 18))

    if has_contract:
        return PlayerStage.NFL_VETERAN if age > 23 else PlayerStage.NFL_ROOKIE
    elif has_school:
        return PlayerStage.COLLEGE if age >= 18 else PlayerStage.HIGH_SCHOOL
    elif age >= 21:
        return PlayerStage.NFL_FREE_AGENT
    else:
        return PlayerStage.HIGH_SCHOOL
```

#### Files to Modify
- `scripts/core/models/Player.gd`
- `scripts/pipelines/NflDraft.gd`
- `scripts/core/player_agency/*.gd`
- Player generation services

---

### ARCH-007: Standardize ID Field Conventions

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-001, ARCH-002

#### Description
Establish and enforce consistent ID field naming across the codebase. Currently there's a mix of `id`, `player_id`, and `{entity}_id` patterns causing confusion and normalization code.

#### Convention to Adopt
| Context | Pattern | Example |
|---------|---------|---------|
| Entity model field | `id` | `player.id`, `team.id` |
| Reference in typed array | Access via `.id` | `for p in players: p.id` |
| Reference in Dictionary | `{entity}_id` | `{"player_id": "abc"}` |
| Collection of IDs | `{entity}_ids` | `team.player_ids: Array[String]` |

#### Current Issues
```gdscript
# NflDraft.gd:94-99 - Normalization shouldn't be needed
if p.has("player_id") and not p.has("id"):
    p["id"] = p["player_id"]
```

#### Target State
- All entity Resources use `id` field
- All Dictionary-based references use `{entity}_id`
- Remove normalization code once source is fixed
- Document convention in ARCHITECTURE.md

#### Acceptance Criteria
- [ ] Audit all ID field usage patterns
- [ ] Fix inconsistent sources (draft pool creation, FA pool, etc.)
- [ ] Remove normalization code in NflDraft.gd
- [ ] Update documentation with convention
- [ ] All ID-based lookups work consistently
- [ ] No "id not found" errors in simulation

#### Files to Audit
```bash
grep -r "player_id" --include="*.gd" scripts/
grep -r "\.id\b" --include="*.gd" scripts/
grep -r '"id"' --include="*.gd" scripts/
```

---

## Phase 2: Model Decomposition (Medium Risk, Medium Value)

### ARCH-008: Extract PlayerPhysicals Component

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-001, ARCH-003

#### Description
Extract physical measurement fields from Player into a composed `PlayerPhysicals` resource to reduce Player class complexity.

#### Fields to Extract
```gdscript
# Currently in Player.gd lines 15-22
@export var height_in: float = 72.0
@export var weight_lb: float = 200.0
@export var hand_size_in: float = 9.5
@export var arm_length_in: float = 32.0
@export var wingspan_in: float = 78.0
```

#### Target State
```gdscript
# scripts/core/models/PlayerPhysicals.gd (NEW FILE)
extends Resource
class_name PlayerPhysicals

@export var height_in: float = 72.0
@export var weight_lb: float = 200.0
@export var hand_size_in: float = 9.5
@export var arm_length_in: float = 32.0
@export var wingspan_in: float = 78.0

func get_height_feet_inches() -> String:
    var feet = int(height_in / 12)
    var inches = int(height_in) % 12
    return "%d'%d\"" % [feet, inches]

func get_bmi() -> float:
    # BMI = (weight in pounds * 703) / (height in inches)^2
    return (weight_lb * 703.0) / (height_in * height_in)

func from_dict(d: Dictionary) -> void:
    height_in = float(d.get("height_in", height_in))
    weight_lb = float(d.get("weight_lb", weight_lb))
    hand_size_in = float(d.get("hand_size_in", hand_size_in))
    arm_length_in = float(d.get("arm_length_in", arm_length_in))
    wingspan_in = float(d.get("wingspan_in", wingspan_in))

func to_dict() -> Dictionary:
    return {
        "height_in": height_in,
        "weight_lb": weight_lb,
        "hand_size_in": hand_size_in,
        "arm_length_in": arm_length_in,
        "wingspan_in": wingspan_in
    }
```

```gdscript
# Player.gd - Updated
@export var physicals: PlayerPhysicals = null

func _init() -> void:
    super()  # Person base
    physicals = PlayerPhysicals.new()
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/PlayerPhysicals.gd`
- [ ] Add `physicals: PlayerPhysicals` to Player
- [ ] Remove individual physical fields from Player
- [ ] Add helper methods (height formatting, BMI)
- [ ] Update from_dict with backward compatibility (flat → nested)
- [ ] Update to_dict to nest physicals
- [ ] Update all `player.height_in` → `player.physicals.height_in`
- [ ] All physical-related tests pass

#### Backward Compatibility
```gdscript
func from_dict(d: Dictionary) -> void:
    # Support both nested and flat format
    if d.has("physicals") and d["physicals"] is Dictionary:
        physicals.from_dict(d["physicals"])
    else:
        # Legacy flat format
        physicals.height_in = float(d.get("height_in", 72.0))
        physicals.weight_lb = float(d.get("weight_lb", 200.0))
        # ... etc
```

---

### ARCH-009: Extract CombineResults Component

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-001, ARCH-003

#### Description
Extract NFL Combine measurement fields from Player into a composed `CombineResults` resource. This also enables representing players who haven't done a combine (null component).

#### Fields to Extract
```gdscript
# Currently in Player.gd lines 23-39
@export var forty_sec: float = 5.0
@export var shuttle20_sec: float = 4.5
@export var cone3_sec: float = 7.5
@export var vertical_in: float = 30.0
@export var broad_in: float = 108.0
@export var bench_225_reps: int = 20
@export var wonderlic: int = 20
@export var cybex_index: float = 0.85
@export var injury_eval: String = "normal"
@export var drug_screen: String = "negative"
```

#### Target State
```gdscript
# scripts/core/models/CombineResults.gd (NEW FILE)
extends Resource
class_name CombineResults

@export var forty_sec: float = 5.0
@export var shuttle20_sec: float = 4.5
@export var cone3_sec: float = 7.5
@export var vertical_in: float = 30.0
@export var broad_in: float = 108.0
@export var bench_225_reps: int = 20
@export var wonderlic: int = 20
@export var cybex_index: float = 0.85
@export var injury_eval: String = "normal"
@export var drug_screen: String = "negative"
@export var combine_year: int = 0  # Year player did combine

func has_completed_combine() -> bool:
    return combine_year > 0

func get_athleticism_score() -> float:
    # Composite athletic score based on measurables
    var forty_score = remap(forty_sec, 4.2, 5.2, 100, 0)
    var vert_score = remap(vertical_in, 24, 44, 0, 100)
    var broad_score = remap(broad_in, 96, 132, 0, 100)
    return (forty_score + vert_score + broad_score) / 3.0

func from_dict(d: Dictionary) -> void:
    forty_sec = float(d.get("forty_sec", forty_sec))
    shuttle20_sec = float(d.get("shuttle20_sec", shuttle20_sec))
    # ... all fields

func to_dict() -> Dictionary:
    return {
        "forty_sec": forty_sec,
        "shuttle20_sec": shuttle20_sec,
        # ... all fields
    }
```

```gdscript
# Player.gd - Updated
@export var combine: CombineResults = null  # null = no combine yet

func _init() -> void:
    super()
    # combine stays null until player does combine

func did_combine() -> bool:
    return combine != null and combine.has_completed_combine()
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/CombineResults.gd`
- [ ] Add `combine: CombineResults` to Player (nullable)
- [ ] Remove individual combine fields from Player
- [ ] Add `has_completed_combine()` and `get_athleticism_score()` helpers
- [ ] Update from_dict with backward compatibility
- [ ] Handle null combine for players who haven't done combine
- [ ] Update scout evaluation to check for combine existence
- [ ] All combine-related tests pass

---

### ARCH-010: Extract StatsProfile Component

**Priority:** MEDIUM
**Estimated Effort:** 4-5 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-001

#### Description
Extract stats-related fields from Player into a `StatsProfile` resource. This includes current stats, potential stats, and derived stats.

#### Fields to Extract
```gdscript
# Currently in Player.gd lines 40-44
var stats: Dictionary = {}      # Current ratings
var potential: Dictionary = {}  # Ceiling ratings
var derived: Dictionary = {}    # Computed stats
```

#### Target State
```gdscript
# scripts/core/models/StatsProfile.gd (NEW FILE)
extends Resource
class_name StatsProfile

# Core stat dictionaries (keep as Dictionary for flexibility with config-driven stats)
var current: Dictionary = {}
var potential: Dictionary = {}
var derived: Dictionary = {}

func get_stat(stat_name: String) -> float:
    return float(current.get(stat_name, 0.0))

func get_potential(stat_name: String) -> float:
    return float(potential.get(stat_name, 0.0))

func get_derived(stat_name: String) -> float:
    return float(derived.get(stat_name, 0.0))

func set_stat(stat_name: String, value: float) -> void:
    current[stat_name] = value

func get_overall_rating() -> float:
    return get_derived("overall")

func get_development_gap(stat_name: String) -> float:
    return get_potential(stat_name) - get_stat(stat_name)

func recompute_derived(specs: Array, scope: Dictionary) -> void:
    # Move logic from Player.gd here
    derived.clear()
    for spec in specs:
        # ... derived stat computation logic

func from_dict(d: Dictionary) -> void:
    current = d.get("current", d.get("stats", {})).duplicate(true)
    potential = d.get("potential", {}).duplicate(true)
    derived = d.get("derived", {}).duplicate(true)

func to_dict() -> Dictionary:
    return {
        "current": current.duplicate(true),
        "potential": potential.duplicate(true),
        "derived": derived.duplicate(true)
    }
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/StatsProfile.gd`
- [ ] Add `stats_profile: StatsProfile` to Player
- [ ] Remove individual stats/potential/derived from Player
- [ ] Move `recompute_derived()` logic to StatsProfile
- [ ] Add helper methods for stat access
- [ ] Update from_dict with backward compatibility (flat "stats" → nested "current")
- [ ] Update all `player.stats[x]` → `player.stats_profile.get_stat(x)`
- [ ] All stats-related tests pass

---

### ARCH-011: Extract TraitSet Component

**Priority:** LOW
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** ARCH-001

#### Description
Extract trait arrays from Player into a `TraitSet` resource for better encapsulation and trait-related logic.

#### Fields to Extract
```gdscript
# Currently in Player.gd lines 46-49
@export var traits: Array[String] = []
@export var hidden_traits: Array[String] = []
```

#### Target State
```gdscript
# scripts/core/models/TraitSet.gd (NEW FILE)
extends Resource
class_name TraitSet

@export var visible: Array[String] = []
@export var hidden: Array[String] = []

func has_trait(trait_name: String) -> bool:
    return visible.has(trait_name) or hidden.has(trait_name)

func has_visible_trait(trait_name: String) -> bool:
    return visible.has(trait_name)

func has_hidden_trait(trait_name: String) -> bool:
    return hidden.has(trait_name)

func add_trait(trait_name: String, is_hidden: bool = false) -> void:
    if is_hidden:
        if not hidden.has(trait_name):
            hidden.append(trait_name)
    else:
        if not visible.has(trait_name):
            visible.append(trait_name)

func remove_trait(trait_name: String) -> void:
    visible.erase(trait_name)
    hidden.erase(trait_name)

func reveal_trait(trait_name: String) -> bool:
    if hidden.has(trait_name):
        hidden.erase(trait_name)
        visible.append(trait_name)
        return true
    return false

func get_all_traits() -> Array[String]:
    var all: Array[String] = []
    all.append_array(visible)
    all.append_array(hidden)
    return all

func from_dict(d: Dictionary) -> void:
    visible.clear()
    hidden.clear()
    for t in d.get("visible", d.get("traits", [])):
        visible.append(String(t))
    for t in d.get("hidden", d.get("hidden_traits", [])):
        hidden.append(String(t))

func to_dict() -> Dictionary:
    return {
        "visible": visible.duplicate(),
        "hidden": hidden.duplicate()
    }
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/TraitSet.gd`
- [ ] Add `trait_set: TraitSet` to Player
- [ ] Remove `traits` and `hidden_traits` from Player
- [ ] Add helper methods for trait operations
- [ ] Add `reveal_trait()` for scouting to reveal hidden traits
- [ ] Update from_dict with backward compatibility
- [ ] All trait-related tests pass

---

### ARCH-012: Extract CareerRecord Component

**Priority:** LOW
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** ARCH-001

#### Description
Extract career tracking fields from Player into a `CareerRecord` resource for awards, wear, and development history.

#### Fields to Extract
```gdscript
# Currently in Player.gd lines 55-69
@export var career_awards: Dictionary = {
    "opoy": 0, "dpoy": 0, "all_pro_first": 0, ...
}
@export var wear: Dictionary = {"snaps": 0, "collisions": 0, "injury_count": 0}
@export var development_report: Array = []
```

#### Target State
```gdscript
# scripts/core/models/CareerRecord.gd (NEW FILE)
extends Resource
class_name CareerRecord

# Award type constants
const AWARD_MVP = "mvp"
const AWARD_OPOY = "opoy"
const AWARD_DPOY = "dpoy"
const AWARD_ALL_PRO_FIRST = "all_pro_first"
const AWARD_ALL_PRO_SECOND = "all_pro_second"
const AWARD_PRO_BOWL = "pro_bowl"
const AWARD_ROOKIE_OF_YEAR = "rookie_of_year"
const AWARD_CHAMPIONSHIPS = "championships"

@export var awards: Dictionary = {
    AWARD_MVP: 0,
    AWARD_OPOY: 0,
    AWARD_DPOY: 0,
    AWARD_ALL_PRO_FIRST: 0,
    AWARD_ALL_PRO_SECOND: 0,
    AWARD_PRO_BOWL: 0,
    AWARD_ROOKIE_OF_YEAR: 0,
    AWARD_CHAMPIONSHIPS: 0
}

@export var wear: Dictionary = {
    "snaps": 0,
    "collisions": 0,
    "injury_count": 0
}

@export var development_history: Array = []

func add_award(award_type: String, count: int = 1) -> void:
    if awards.has(award_type):
        awards[award_type] += count

func get_award_count(award_type: String) -> int:
    return int(awards.get(award_type, 0))

func get_total_accolades() -> int:
    var total = 0
    for count in awards.values():
        total += int(count)
    return total

func add_snap_wear(snaps: int, collisions: int = 0) -> void:
    wear["snaps"] += snaps
    wear["collisions"] += collisions

func record_injury() -> void:
    wear["injury_count"] += 1

func add_development_entry(entry: Dictionary) -> void:
    development_history.append(entry)

func from_dict(d: Dictionary) -> void:
    # ... serialization

func to_dict() -> Dictionary:
    # ... serialization
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/CareerRecord.gd`
- [ ] Add constants for award types
- [ ] Add `career: CareerRecord` to Player
- [ ] Remove `career_awards`, `wear`, `development_report` from Player
- [ ] Add helper methods for awards and wear tracking
- [ ] Update from_dict with backward compatibility
- [ ] Update HallOfFame service to use CareerRecord
- [ ] All career/awards tests pass

---

### ARCH-013: Extract HealthStatus Component

**Priority:** LOW
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** ARCH-001, ARCH-005

#### Description
Extract health-related fields into a `HealthStatus` component that manages the typed `Array[Injury]`.

#### Target State
```gdscript
# scripts/core/models/HealthStatus.gd (NEW FILE)
extends Resource
class_name HealthStatus

var injuries: Array[Injury] = []
var injury_prone: bool = false
var career_ending_injury: bool = false

func is_injured() -> bool:
    return injuries.size() > 0

func add_injury(injury: Injury) -> void:
    injuries.append(injury)

func remove_injury(injury_type: String) -> bool:
    for i in range(injuries.size() - 1, -1, -1):
        if injuries[i].type == injury_type:
            injuries.remove_at(i)
            return true
    return false

func clear_all_injuries() -> void:
    injuries.clear()

func get_injury_by_type(injury_type: String) -> Injury:
    for injury in injuries:
        if injury.type == injury_type:
            return injury
    return null

func get_total_severity() -> float:
    var total = 0.0
    for injury in injuries:
        total += injury.severity
    return total

func requires_ir() -> bool:
    for injury in injuries:
        if injury.requires_ir():
            return true
    return false

func from_dict(d: Dictionary) -> void:
    injuries.clear()
    for injury_data in d.get("injuries", []):
        var injury = Injury.new()
        injury.from_dict(injury_data)
        injuries.append(injury)
    injury_prone = bool(d.get("injury_prone", false))
    career_ending_injury = bool(d.get("career_ending_injury", false))

func to_dict() -> Dictionary:
    var injury_dicts = []
    for injury in injuries:
        injury_dicts.append(injury.to_dict())
    return {
        "injuries": injury_dicts,
        "injury_prone": injury_prone,
        "career_ending_injury": career_ending_injury
    }
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/HealthStatus.gd`
- [ ] Add `health: HealthStatus` to Player
- [ ] Move injury array management to HealthStatus
- [ ] Add `injury_prone` and `career_ending_injury` flags
- [ ] Add helper methods for injury queries
- [ ] Update from_dict with backward compatibility
- [ ] All injury-related tests pass

---

### ARCH-014: Clarify Scout Entity vs Service

**Priority:** MEDIUM
**Estimated Effort:** 4-5 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-003

#### Description
Scout currently extends Resource (entity pattern) but contains service methods like `score_player()`. Clarify the boundary by splitting into ScoutEntity (data) and ScoutingService (behavior).

#### Current State
```gdscript
# Scout.gd - Hybrid entity/service
extends Resource
class_name Scout

# Entity data
@export var name: String = "Scout"
@export var role: String = "Regional"
var base_skill: float = 0.6
var stat_bias_mean: Dictionary = {}

# Service methods (should be separate)
func score_player(player: Dictionary, ...) -> float:
    # Pure function operating on external data

static func get_rng_calls_per_evaluation(...) -> int:
    # Static utility
```

#### Target State

**Option A: Keep Scout as Entity, Extract Service**
```gdscript
# Scout.gd - Entity only
extends Person
class_name Scout

@export var role: String = "Regional"
@export var years_exp: int = 0
var base_skill: float = 0.6
var stat_skill: Dictionary = {}
var stat_bias_mean: Dictionary = {}
var stat_bias_sigma: Dictionary = {}
var pos_bias_pts: Dictionary = {}
var estimation_multipliers: Dictionary = {}

# Remove score_player, estimate_stat - move to service
```

```gdscript
# scripts/core/scouting/ScoutingService.gd (NEW FILE)
extends RefCounted
class_name ScoutingService

static func score_player(scout: Scout, player: Dictionary, rng: RandomNumberGenerator, ...) -> float:
    # Scoring logic using scout's skills and biases

static func estimate_stat(scout: Scout, true_value: float, stat_key: String, rng: RandomNumberGenerator) -> float:
    # Estimation logic

static func get_rng_calls_per_evaluation(num_stats: int) -> int:
    # Utility function
```

**Option B: Keep Methods on Scout, Document as "Rich Entity"**
- Add comment explaining Scout is a "rich entity" with behavior
- Ensure methods only operate on Scout's own state + passed parameters
- This is acceptable if team prefers keeping related code together

#### Recommendation
**Option A** is cleaner architecturally but requires more refactoring.
**Option B** is pragmatic and lower risk.

Choose based on team preference and how widely Scout methods are called.

#### Acceptance Criteria
- [ ] Decide on Option A or B
- [ ] If A: Create ScoutingService, migrate methods, update callers
- [ ] If B: Document pattern, ensure methods are pure functions
- [ ] Scout extends Person (ARCH-003)
- [ ] Scout uses first_name/last_name (migrate from single "name")
- [ ] All scouting tests pass

---

### ARCH-015: Remove Team.player_ids Redundancy

**Priority:** MEDIUM
**Estimated Effort:** 2-3 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-002

#### Description
Team has both `roster: Roster` and `player_ids: Array[String]`, creating unclear ownership and potential sync issues. Remove `player_ids` and derive from roster.

#### Current State
```gdscript
# Team.gd
@export var roster: SportRoster = SportRoster.new()
@export var player_ids: Array[String] = []  # Redundant?
```

#### Target State
```gdscript
# Team.gd
@export var roster: Roster = null

func _init() -> void:
    roster = Roster.new()

# Computed property instead of stored field
func get_player_ids(include_inactive: bool = false) -> Array[String]:
    var ids: Array[String] = []
    for entry in roster.entries:
        if include_inactive or entry.status == Roster.RosterStatus.ACTIVE:
            ids.append(entry.player_id)
    return ids

func get_active_player_ids() -> Array[String]:
    return get_player_ids(false)

func get_all_player_ids() -> Array[String]:
    return get_player_ids(true)
```

#### Acceptance Criteria
- [ ] Remove `player_ids` field from Team
- [ ] Add `get_player_ids()` computed method
- [ ] Update all `team.player_ids` references to use method
- [ ] Update Team.from_dict() to not expect player_ids
- [ ] Update Team.to_dict() to not serialize player_ids
- [ ] Verify roster is authoritative source
- [ ] All team roster tests pass

#### Search for Usage
```bash
grep -r "\.player_ids" --include="*.gd" scripts/
grep -r "player_ids\[" --include="*.gd" scripts/
```

---

### ARCH-016: Extract RosterEntry Resource

**Priority:** LOW
**Estimated Effort:** 3-4 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-002

#### Description
Replace `Array[Dictionary]` roster entries with typed `Array[RosterEntry]` for type safety.

#### Current State
```gdscript
# Roster.gd
@export var entries: Array[Dictionary] = []

# Entry shape documented in comments:
# {
#   "player_id": "player-123",
#   "status": "active",
#   "cap_exempt": false,
#   ...
# }
```

#### Target State
```gdscript
# scripts/core/models/RosterEntry.gd (NEW FILE)
extends Resource
class_name RosterEntry

@export var player_id: String = ""
@export var status: Roster.RosterStatus = Roster.RosterStatus.ACTIVE
@export var cap_exempt: bool = false
@export var cap_exempt_reason: String = ""
@export var ir_eligible_week: int = 0
@export var roster_contract: RosterContract = null

func _init() -> void:
    roster_contract = RosterContract.new()

func from_dict(d: Dictionary) -> void:
    player_id = String(d.get("player_id", ""))
    status = _parse_status(String(d.get("status", "active")))
    cap_exempt = bool(d.get("cap_exempt", false))
    # ...

func _parse_status(status_str: String) -> Roster.RosterStatus:
    match status_str:
        "active": return Roster.RosterStatus.ACTIVE
        "practice_squad": return Roster.RosterStatus.PRACTICE_SQUAD
        "ir", "injured_reserve": return Roster.RosterStatus.INJURED_RESERVE
        "suspended": return Roster.RosterStatus.SUSPENDED
        _: return Roster.RosterStatus.ACTIVE
```

```gdscript
# Roster.gd - Updated
@export var entries: Array[RosterEntry] = []

func add_player(player_id: String, status: RosterStatus = RosterStatus.ACTIVE) -> RosterEntry:
    var entry = RosterEntry.new()
    entry.player_id = player_id
    entry.status = status
    entries.append(entry)
    return entry
```

#### Acceptance Criteria
- [ ] Create `scripts/core/models/RosterEntry.gd`
- [ ] Create `scripts/core/models/RosterContract.gd` for cap accounting
- [ ] Update Roster.entries type to `Array[RosterEntry]`
- [ ] Update all Dictionary-based entry creation to use RosterEntry
- [ ] Use RosterStatus enum instead of strings
- [ ] Update from_dict with backward compatibility
- [ ] All roster tests pass

---

## Phase 3: Database Persistence (Medium-High Risk)

### ARCH-017: Implement PersistenceLayer Abstraction

**Priority:** HIGH
**Estimated Effort:** 6-8 hours
**Risk:** LOW
**Dependencies:** None (can start in parallel)

#### Description
Create an abstraction layer that allows switching between JSON and database persistence backends without changing game logic.

#### Target State
```gdscript
# res://autoloads/PersistenceLayer.gd
extends Node
class_name PersistenceLayer

enum Backend { JSON, SQLITE }

var current_backend: Backend = Backend.JSON
var _json_handler: JSONPersistence = null
var _db_handler: DatabasePersistence = null

func save_world_state(world_state: Dictionary, save_name: String) -> bool:
    match current_backend:
        Backend.JSON:
            return _json_handler.save(world_state, save_name)
        Backend.SQLITE:
            return _db_handler.save(world_state, save_name)
    return false

func load_world_state(save_name: String) -> Dictionary:
    match current_backend:
        Backend.JSON:
            return _json_handler.load(save_name)
        Backend.SQLITE:
            return _db_handler.load(save_name)
    return {}

# Entity-specific operations for DB backend
func save_player(player: Player) -> bool:
    # JSON: no-op (saved with world_state)
    # SQLite: INSERT/UPDATE player table

func load_players(filter: Dictionary = {}) -> Array[Player]:
    # JSON: filter from loaded world_state
    # SQLite: SELECT with WHERE clause

func query_players_by_position(position: String) -> Array[Player]:
    # Efficient query for DB, scan for JSON
```

#### Acceptance Criteria
- [ ] Create PersistenceLayer autoload
- [ ] Implement JSONPersistence handler (wrap existing logic)
- [ ] Define interface for DatabasePersistence
- [ ] Add configuration for backend selection
- [ ] Ensure all save/load operations go through PersistenceLayer
- [ ] No breaking changes to existing functionality
- [ ] Tests pass with JSON backend

---

### ARCH-018: Design SQLite Schema

**Priority:** HIGH
**Estimated Effort:** 4-6 hours
**Risk:** LOW
**Dependencies:** Phase 1 completion recommended

#### Description
Design the SQLite database schema based on the entity models, considering normalization, indexing, and query patterns.

#### Core Tables
```sql
-- Player and related tables
CREATE TABLE player (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    position TEXT NOT NULL,
    age INTEGER NOT NULL,
    stage TEXT NOT NULL,
    class_tag TEXT,
    jersey_number INTEGER,
    gen_mode TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE player_physicals (
    player_id TEXT PRIMARY KEY REFERENCES player(id),
    height_in REAL,
    weight_lb REAL,
    hand_size_in REAL,
    arm_length_in REAL,
    wingspan_in REAL
);

CREATE TABLE player_combine (
    player_id TEXT PRIMARY KEY REFERENCES player(id),
    forty_sec REAL,
    shuttle20_sec REAL,
    cone3_sec REAL,
    vertical_in REAL,
    broad_in REAL,
    bench_225_reps INTEGER,
    wonderlic INTEGER,
    combine_year INTEGER
);

CREATE TABLE player_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT REFERENCES player(id),
    season_year INTEGER,
    stat_type TEXT,  -- 'current', 'potential', 'derived'
    stat_name TEXT,
    stat_value REAL,
    UNIQUE(player_id, season_year, stat_type, stat_name)
);

CREATE TABLE player_trait (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT REFERENCES player(id),
    trait_name TEXT NOT NULL,
    is_hidden BOOLEAN DEFAULT FALSE,
    UNIQUE(player_id, trait_name)
);

CREATE TABLE player_contract (
    player_id TEXT PRIMARY KEY REFERENCES player(id),
    current_year INTEGER,
    total_years INTEGER,
    annual_value REAL,
    guaranteed REAL,
    signed_date DATE
);

CREATE TABLE player_injury (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT REFERENCES player(id),
    injury_type TEXT,
    severity REAL,
    week_occurred INTEGER,
    season_year INTEGER,
    is_active BOOLEAN DEFAULT TRUE
);

-- Team tables
CREATE TABLE team (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    league_level TEXT,
    offensive_scheme TEXT,
    defensive_scheme TEXT,
    cap_limit REAL,
    is_user_controlled BOOLEAN DEFAULT FALSE
);

CREATE TABLE roster_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    team_id TEXT REFERENCES team(id),
    player_id TEXT REFERENCES player(id),
    status TEXT,
    cap_exempt BOOLEAN DEFAULT FALSE,
    UNIQUE(team_id, player_id)
);

-- Historical data
CREATE TABLE player_career_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT REFERENCES player(id),
    season_year INTEGER,
    team_id TEXT,
    games_played INTEGER,
    -- Position-specific stats as columns
    pass_yards INTEGER,
    pass_tds INTEGER,
    rush_yards INTEGER,
    rush_tds INTEGER,
    receptions INTEGER,
    rec_yards INTEGER,
    tackles INTEGER,
    sacks REAL,
    interceptions INTEGER,
    UNIQUE(player_id, season_year)
);

-- Indexes for common queries
CREATE INDEX idx_player_position ON player(position);
CREATE INDEX idx_player_stage ON player(stage);
CREATE INDEX idx_player_age ON player(age);
CREATE INDEX idx_roster_team ON roster_entry(team_id);
CREATE INDEX idx_career_stats_player ON player_career_stats(player_id);
```

#### Acceptance Criteria
- [ ] Design schema for all core entities
- [ ] Document table relationships (ER diagram)
- [ ] Identify required indexes
- [ ] Consider stats storage approach (EAV vs wide table)
- [ ] Plan for historical data archival
- [ ] Schema reviewed by team

---

### ARCH-019: Implement Player DAO

**Priority:** HIGH
**Estimated Effort:** 6-8 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-017, ARCH-018

#### Description
Create Data Access Object for Player entity that handles all database operations.

#### Target State
```gdscript
# scripts/persistence/PlayerDAO.gd
extends RefCounted
class_name PlayerDAO

var _db: SQLite = null

func _init(db: SQLite) -> void:
    _db = db

func save(player: Player) -> bool:
    # INSERT OR REPLACE into player table
    # Save related data (physicals, combine, stats, etc.)

func load(player_id: String) -> Player:
    # SELECT from player + JOIN related tables
    # Construct Player resource

func load_batch(player_ids: Array[String]) -> Array[Player]:
    # Efficient batch loading

func query(filters: Dictionary) -> Array[Player]:
    # Build WHERE clause from filters
    # Return matching players

func delete(player_id: String) -> bool:
    # CASCADE delete player and related data

func save_stats(player_id: String, stats: StatsProfile, season_year: int) -> bool:
    # Save stats to player_stats table

func load_career_stats(player_id: String) -> Array[Dictionary]:
    # Load all seasons of career stats
```

#### Acceptance Criteria
- [ ] Implement CRUD operations for Player
- [ ] Handle nested resources (physicals, combine, etc.)
- [ ] Implement batch operations for performance
- [ ] Support filtering/querying
- [ ] Transaction support for atomic operations
- [ ] Comprehensive error handling
- [ ] Unit tests for all DAO methods

---

### ARCH-020: Implement Team DAO

**Priority:** HIGH
**Estimated Effort:** 4-5 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-017, ARCH-018, ARCH-019

#### Description
Create Data Access Object for Team entity including roster management.

#### Acceptance Criteria
- [ ] Implement CRUD operations for Team
- [ ] Handle roster_entry join table
- [ ] Support loading team with full roster
- [ ] Support loading team with player IDs only (lazy loading)
- [ ] Unit tests for all DAO methods

---

### ARCH-021: Create JSON to SQLite Migration Tool

**Priority:** MEDIUM
**Estimated Effort:** 6-8 hours
**Risk:** MEDIUM
**Dependencies:** ARCH-019, ARCH-020

#### Description
Create a migration utility that converts existing JSON save files to SQLite database format.

#### Features
- Load JSON save file
- Validate data integrity
- Create new SQLite database
- Migrate all entities with relationships
- Verify migration success (checksums)
- Report migration statistics

#### Acceptance Criteria
- [ ] Parse any valid JSON save file
- [ ] Create SQLite database with full schema
- [ ] Migrate all player data with relationships
- [ ] Migrate all team and roster data
- [ ] Migrate historical stats
- [ ] Validate migrated data matches source
- [ ] Handle migration errors gracefully
- [ ] Provide detailed migration report
- [ ] Test with multiple save file versions

---

### ARCH-022: Add Database Performance Indexes

**Priority:** MEDIUM
**Estimated Effort:** 2-3 hours
**Risk:** LOW
**Dependencies:** ARCH-018

#### Description
Implement indexes for common query patterns identified in the codebase.

#### Common Query Patterns to Optimize
1. Find players by position
2. Find players by age range
3. Find players by stage (NFL, college, etc.)
4. Find players on specific team
5. Load roster for team
6. Career stats lookup by player
7. Draft pool by year
8. Free agents by position

#### Acceptance Criteria
- [ ] Add indexes for all common query patterns
- [ ] Benchmark queries before/after indexes
- [ ] Document index strategy
- [ ] Verify no regression in write performance

---

## Documentation Tickets

### ARCH-023: Document Naming Conventions

**Priority:** MEDIUM
**Estimated Effort:** 2-3 hours
**Risk:** NONE
**Dependencies:** ARCH-001, ARCH-002, ARCH-007

#### Description
Create comprehensive naming conventions documentation based on decisions made during this refactoring.

#### Content
- ID field conventions (when to use `id` vs `{entity}_id`)
- Collection naming (plural vs singular)
- World state key patterns
- Unit suffix conventions (`_in`, `_lb`, `_sec`)
- Class naming conventions
- Enum naming conventions

#### Deliverable
`docs/architecture/NAMING_CONVENTIONS.md`

---

### ARCH-024: Document Model Hierarchy

**Priority:** MEDIUM
**Estimated Effort:** 2-3 hours
**Risk:** NONE
**Dependencies:** Phase 2 completion

#### Description
Create documentation of the final model hierarchy after decomposition.

#### Content
- Entity class diagram
- Component composition diagram
- Serialization format documentation
- Migration guide for old save files

#### Deliverable
`docs/architecture/MODEL_HIERARCHY.md`

---

### ARCH-025: Document Persistence Layer

**Priority:** MEDIUM
**Estimated Effort:** 2-3 hours
**Risk:** NONE
**Dependencies:** Phase 3 completion

#### Description
Document the persistence layer architecture and usage.

#### Content
- Backend configuration
- DAO usage patterns
- Transaction handling
- Migration procedures
- Performance tuning guide

#### Deliverable
`docs/architecture/PERSISTENCE.md`

---

## Phase 4: Testing Infrastructure

### ARCH-026: Migrate to GdUnit4 Testing Framework

**Priority:** HIGH
**Estimated Effort:** 94-110 hours (2.5-3 weeks)
**Risk:** MEDIUM
**Dependencies:** None (can run in parallel with other phases)

#### Description

Migrate from the custom homegrown testing framework to GdUnit4 v6.0+ to gain:
- **Native test retry** on failure (per-test, not all-or-nothing)
- **Flaky test detection** with automatic reporting
- **Official GitHub Action** (`gdunit4-action`) with built-in CI features
- **HTML reports** in addition to JUnit XML
- **25 feature advantages** over alternatives (fluent assertions, scene runner, fuzzing, etc.)

#### Current State

```gdscript
# Current pattern: Custom framework
extends RefCounted

func run(t: TestHelpers) -> void:
    _test_something(t)

func _test_something(t: TestHelpers) -> void:
    t.assert_eq(actual, expected, "message")
```

#### Target State

```gdscript
# GdUnit4 pattern
extends GdUnitTestSuite

func test_something() -> void:
    assert_that(actual).is_equal(expected)
```

#### Custom Assertions Migration

Port `TestHelpers.gd` custom assertions to GdUnit4-compatible utility class:

```gdscript
# scripts/tests/TestHelpersGdUnit4.gd
extends RefCounted
class_name TestHelpersGdUnit4

## Verify a function is deterministic with a given seed.
## Uses GdUnit4's deep equality instead of JSON stringification (which has key ordering issues).
static func assert_deterministic(suite: GdUnitTestSuite, callable: Callable, seed: int, msg: String) -> void:
    var rng1 := RandomNumberGenerator.new()
    rng1.seed = seed
    var result1 = callable.call(rng1)

    var rng2 := RandomNumberGenerator.new()
    rng2.seed = seed
    var result2 = callable.call(rng2)

    # Use GdUnit4's deep equality - handles dictionaries, arrays, nested structures
    suite.assert_that(result1).is_equal(result2)

## Assert dictionary has required fields
static func assert_schema(suite: GdUnitTestSuite, obj: Dictionary, required_fields: Array, msg: String) -> void:
    for field in required_fields:
        suite.assert_bool(obj.has(field))\
            .override_failure_message("%s: missing field '%s'" % [msg, field])\
            .is_true()

## Assert operation completes within time limit
static func assert_max_time(suite: GdUnitTestSuite, callable: Callable, max_ms: float, msg: String) -> void:
    var start_usec := Time.get_ticks_usec()
    callable.call()
    var elapsed_usec := Time.get_ticks_usec() - start_usec
    var elapsed_ms := elapsed_usec / 1000.0

    suite.assert_float(elapsed_ms)\
        .override_failure_message("%s (took %.2fms, max %.2fms)" % [msg, elapsed_ms, max_ms])\
        .is_less_equal(max_ms)
```

#### CI Configuration

```yaml
# .github/workflows/test.yml
name: Run Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run GdUnit4 Tests
        uses: MikeSchulze/gdUnit4-action@v1
        with:
          godot-version: '4.5.0'  # Pin exact version
          version: 'v6.0.0'       # Pin GdUnit4 version
          paths: 'res://scripts/tests'
          retries: 3              # Per-test retry for flaky tests
          timeout: 10             # 10 minute timeout (in minutes)

      - name: Upload HTML Report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: gdunit4-report
          path: reports/

      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v2
        if: always()
        with:
          files: '**/*.xml'
```

#### SnapshotLoader Integration with GdUnit4

The existing SnapshotLoader fixture system must integrate with GdUnit4's lifecycle hooks:

```gdscript
extends GdUnitTestSuite

var world_state: Dictionary

# Runs once before all tests in this suite
func before() -> void:
    world_state = SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x5EED)

# Runs after all tests complete
func after() -> void:
    SnapshotLoader.clear_cache()  # Clean up static cache

func test_player_lifecycle() -> void:
    assert_that(world_state["current_year"]).is_equal(2035)
    # Test using world_state...
```

**Important Considerations:**
- **Static Cache**: SnapshotLoader uses static caching. Verify GdUnit4 test isolation model in POC.
- **Different Snapshots**: Tests requiring different base snapshots must use **separate test suites**.
- **Cache Cleanup**: Call `SnapshotLoader.clear_cache()` in `after()` to prevent cross-suite pollution.

#### Implementation Phases

**Phase 4.1: Proof of Concept (1 week, 28 hours)**
- [ ] Install GdUnit4 v6.0+ via Godot Asset Library
- [ ] Migrate 5 representative test files:
  - 1 simple unit test (test_rand.gd)
  - 1 determinism test (test_g1_1_game_simulation_determinism.gd)
  - 1 performance test (test_scout_runtime.gd)
  - 1 schema validation test
  - 1 integration test (test_g1_integration_season_simulation.gd)
- [ ] Implement TestHelpersGdUnit4 custom assertions
- [ ] Set up GitHub Action with retries
- [ ] Measure execution time vs current framework
- [ ] Get team feedback on fluent API syntax
- [ ] Audit all `test_*.gd` files for unintentional discovery
- [ ] Verify SnapshotLoader static cache behavior with GdUnit4
- [ ] **Decision gate**: Proceed or fall back to GUT

**POC Success Criteria (Decision Gate):**
- [ ] All 5 test types migrate successfully without blocking issues
- [ ] SnapshotLoader integration working with lifecycle hooks
- [ ] Static cache behavior verified safe (no cross-test pollution)
- [ ] Test runtime ≤ 154s (within 25% of 120s baseline)
- [ ] Team confirms fluent API readability acceptable (80%+ approval)
- [ ] GitHub Action retry demonstrated working per-test

**Fallback Plan (If POC Fails):**
If POC fails to meet success criteria, execute **ARCH-026-ALT: Migrate to GUT**:
- **Estimated Effort:** 61-73 hours (25% less than GdUnit4)
- **Trade-offs:** Lose native test retry, flaky detection, official GitHub Action
- **Decision:** Defer final decision until POC results available in Week 1

**Phase 4.2: Bulk Migration (2 weeks, 50 hours)**
- [ ] Create migration checklist/script
- [ ] Convert assertion patterns:
  - `t.assert_eq(a, b, "msg")` → `assert_that(a).is_equal(b)`
  - `t.assert_true(x, "msg")` → `assert_bool(x).is_true()`
  - `t.assert_gt(a, b, "msg")` → `assert_int(a).is_greater(b)`
  - `t.assert_between(x, lo, hi, "msg")` → `assert_float(x).is_between(lo, hi)`
  - `t.assert_approx(a, b, eps, "msg")` → `assert_float(a).is_equal_approx(b, eps)`
- [ ] Migrate remaining ~127 test files
- [ ] Update SnapshotLoader integration with GdUnit4 lifecycle hooks
- [ ] Remove old TestHelpers.gd and TestRunner.gd

**Phase 4.3: Optimization (1 week, 16 hours)**
- [ ] Identify flaky tests using retry reports
- [ ] Add test fuzzing for simulation edge cases
- [ ] Configure HTML report dashboard
- [ ] Add performance regression detection
- [ ] Document GdUnit4 patterns for team

#### Acceptance Criteria

- [ ] All 132 test files migrated to GdUnit4
- [ ] Custom assertions (deterministic, schema, max_time) working
- [ ] CI pipeline running with test retry enabled
- [ ] HTML and JUnit XML reports generated
- [ ] Test runtime within 10% of current (120-140s baseline)
- [ ] No regression in test coverage
- [ ] SnapshotLoader fixtures integrated
- [ ] Team documentation complete

#### Assertion Conversion Reference

| Current (TestHelpers) | GdUnit4 Equivalent |
|-----------------------|-------------------|
| `t.assert_eq(a, b, msg)` | `assert_that(a).is_equal(b)` |
| `t.assert_ne(a, b, msg)` | `assert_that(a).is_not_equal(b)` |
| `t.assert_true(x, msg)` | `assert_bool(x).is_true()` |
| `t.assert_false(x, msg)` | `assert_bool(x).is_false()` |
| `t.assert_gt(a, b, msg)` | `assert_int(a).is_greater(b)` |
| `t.assert_gte(a, b, msg)` | `assert_int(a).is_greater_equal(b)` |
| `t.assert_lt(a, b, msg)` | `assert_int(a).is_less(b)` |
| `t.assert_lte(a, b, msg)` | `assert_int(a).is_less_equal(b)` |
| `t.assert_between(x, lo, hi, msg)` | `assert_float(x).is_between(lo, hi)` |
| `t.assert_approx(a, b, eps, msg)` | `assert_float(a).is_equal_approx(b, eps)` |
| `t.assert_schema(obj, fields, msg)` | `TestHelpersGdUnit4.assert_schema(self, obj, fields, msg)` |
| `t.assert_deterministic(c, s, msg)` | `TestHelpersGdUnit4.assert_deterministic(self, c, s, msg)` |
| `t.assert_max_time(c, ms, msg)` | `TestHelpersGdUnit4.assert_max_time(self, c, ms, msg)` |

#### Why GdUnit4 Over GUT

| Criterion | GUT | GdUnit4 | Decision Factor |
|-----------|-----|---------|-----------------|
| Test retry | ❌ Manual scripting | ✅ Native | **Critical for PR workflow** |
| Flaky detection | ❌ None | ✅ Built-in | **Critical for CI stability** |
| GitHub Action | Third-party | ✅ Official | **Better support** |
| HTML reports | ❌ None | ✅ Built-in | **Better visibility** |
| Feature advantages | 1 | 25 | **Long-term value** |
| Godot 4.5 compat | ✅ Stable | ✅ Stable (v6.0+) | Tie |
| Migration effort | 61 hours | 86 hours | **+25h justified by features** |

#### Risk Mitigation

| Risk | Severity | Mitigation |
|------|----------|------------|
| Fluent API learning curve | MEDIUM | Phase 4.1 POC validates team comfort |
| Performance regression | LOW | Benchmark in POC before committing |
| Custom assertion complexity | MEDIUM | Static utility pattern documented above |
| GdUnit4 breaking changes | LOW | Already on Godot 4.5, using v6.0+ |

#### Files to Create

- `addons/gdUnit4/` (installed via Asset Library)
- `scripts/tests/TestHelpersGdUnit4.gd`
- `.github/workflows/test.yml` (update existing)

#### Files to Remove (After Migration)

- `scripts/tests/TestHelpers.gd`
- `scripts/tests/TestRunner.gd`
- `scripts/tests/TestRunnerFast.gd`

---

### ARCH-027: Document Testing Patterns

**Priority:** LOW
**Estimated Effort:** 3-4 hours
**Risk:** NONE
**Dependencies:** ARCH-026

#### Description

Document GdUnit4 testing patterns and conventions for the team.

#### Content

- GdUnit4 setup and configuration
- Custom assertion usage (TestHelpersGdUnit4)
- SnapshotLoader integration patterns
- CI/CD workflow explanation
- Debugging tests in editor
- Writing deterministic tests
- Performance testing patterns

#### Acceptance Criteria

- [ ] Create `docs/testing/TESTING_GUIDE.md` with all sections
- [ ] Document GdUnit4 setup and installation process
- [ ] Include TestHelpersGdUnit4 usage examples with code samples
- [ ] Document SnapshotLoader integration with before/after patterns
- [ ] Include CI/CD workflow diagram and explanation
- [ ] Add debugging guide for both editor and command-line
- [ ] Include deterministic testing pattern examples
- [ ] Document performance testing patterns with assert_max_time usage
- [ ] Add troubleshooting section for common issues
- [ ] Peer review by 2+ team members completed

#### Deliverable

`docs/testing/TESTING_GUIDE.md`

---

## Dependency Graph

```
Phase 1 (Foundation):
ARCH-001 (Player rename) ─┬─> ARCH-003 (Person base)
ARCH-002 (Roster rename) ─┘         │
                                    v
ARCH-004 (Contract) <───────── ARCH-001
ARCH-005 (Injuries) <───────── ARCH-001
ARCH-006 (PlayerStage) <────── ARCH-001
ARCH-007 (ID conventions) <─── ARCH-001, ARCH-002

Phase 2 (Decomposition):
ARCH-008 (Physicals) <──── ARCH-001, ARCH-003
ARCH-009 (Combine) <────── ARCH-001, ARCH-003
ARCH-010 (Stats) <──────── ARCH-001
ARCH-011 (Traits) <─────── ARCH-001
ARCH-012 (Career) <─────── ARCH-001
ARCH-013 (Health) <─────── ARCH-001, ARCH-005
ARCH-014 (Scout) <──────── ARCH-003
ARCH-015 (Team cleanup) <─ ARCH-002
ARCH-016 (RosterEntry) <── ARCH-002

Phase 3 (Persistence):
ARCH-017 (Abstraction) ─────> Independent
ARCH-018 (Schema) <───────── Phase 1 recommended
ARCH-019 (Player DAO) <───── ARCH-017, ARCH-018
ARCH-020 (Team DAO) <─────── ARCH-017, ARCH-018, ARCH-019
ARCH-021 (Migration) <────── ARCH-019, ARCH-020
ARCH-022 (Indexes) <──────── ARCH-018

Phase 4 (Testing Infrastructure):    [CAN RUN IN PARALLEL]
ARCH-026 (GdUnit4 Migration) ─────> Independent (no dependencies)
ARCH-027 (Testing Docs) <───────── ARCH-026

Documentation:
ARCH-023 (Naming) <── ARCH-001, ARCH-002, ARCH-007
ARCH-024 (Models) <── Phase 2
ARCH-025 (Persistence) <── Phase 3
```

---

## Summary

| Phase | Tickets | Estimated Hours | Risk |
|-------|---------|-----------------|------|
| Phase 1: Foundation | ARCH-001 to ARCH-007 | 18-25 hours | LOW |
| Phase 2: Decomposition | ARCH-008 to ARCH-016 | 24-32 hours | MEDIUM |
| Phase 3: Persistence | ARCH-017 to ARCH-022 | 28-38 hours | MEDIUM |
<<<<<<< HEAD
| Phase 4: Testing Infrastructure | ARCH-026 to ARCH-027 | 97-114 hours | MEDIUM |
| Documentation | ARCH-023 to ARCH-025 | 6-9 hours | NONE |
| **Total** | **27 tickets** | **173-218 hours** | - |

> **Note:** Phase 4 (Testing Infrastructure) can run **in parallel** with Phases 1-3 as it has no dependencies on model or persistence changes. However, bulk migration (Phase 4.2) should wait for Phase 1 model renames to stabilize to avoid merge conflicts.
=======
| Documentation | ARCH-023 to ARCH-025 | 6-9 hours | NONE |
| **Total** | **25 tickets** | **76-104 hours** | - |
>>>>>>> origin/main

### Recommended Execution Order

1. **Start with ARCH-001 and ARCH-002** (class renames) - Quick wins, unblock other work
2. **Then ARCH-003** (Person base) - Foundation for hierarchy
3. **Then ARCH-004, ARCH-005, ARCH-006** (Contract, Injuries, Stage) - Type safety
4. **ARCH-017 in parallel** - Persistence abstraction can start independently
5. **Phase 2 as needed** - Decomposition based on pain points
6. **Phase 3 after Phase 1** - Database work builds on clean models

### Success Metrics

<<<<<<< HEAD
**Model Architecture:**
- [ ] Player.gd reduced from 296 lines to <200 lines
- [ ] All Dictionary schemas replaced with typed Resources
- [ ] Zero ID normalization code remaining
- [ ] Save/load times reduced by 5x+ with database backend

**Testing Infrastructure:**
- [ ] All 132 test files migrated to GdUnit4
- [ ] Test retry enabled in CI (flaky tests auto-detected)
- [ ] HTML reports generated on every PR
- [ ] Test runtime within 10% of baseline (120-140s)

**Quality Gates:**
- [ ] All existing tests continue to pass
- [ ] No regression in simulation determinism
- [ ] CI pipeline runs on every PR with clear pass/fail
=======
- [ ] Player.gd reduced from 296 lines to <100 lines
- [ ] All Dictionary schemas replaced with typed Resources
- [ ] Zero ID normalization code remaining
- [ ] Save/load times reduced by 5x+ with database backend
- [ ] All existing tests continue to pass
- [ ] No regression in simulation determinism
>>>>>>> origin/main
