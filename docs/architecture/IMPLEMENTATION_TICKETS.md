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

## Phase 5: Draft System Realism

### DRAFT-001: Draft Day Trading System

**Priority:** CRITICAL
**Estimated Effort:** 12-16 hours
**Risk:** MEDIUM
**Dependencies:** None

#### Description

Implement draft-day trading, allowing both AI teams and users to propose/execute trades during the live draft. NFL drafts average 20-30 trades per year - without this, draft behavior is unrealistic (no trading up for QBs, no trading back for value).

#### Current State
- Pick ownership infrastructure exists (`draft_pick_ownership`)
- `value_draft_pick()` function exists but is unused
- No execution layer for trades during draft

#### Target State
```gdscript
# scripts/world/DraftTradeEngine.gd (NEW FILE)
extends RefCounted
class_name DraftTradeEngine

signal trade_proposed(proposing_team_id: String, receiving_team_id: String, offer: Dictionary)
signal trade_executed(trade: Dictionary)
signal trade_rejected(proposing_team_id: String, reason: String)

func propose_trade(from_team: String, to_team: String, offer: Dictionary) -> bool:
    # Validate trade legality
    # Calculate value differential
    # Return acceptance likelihood

func evaluate_trade_value(offer: Dictionary) -> float:
    # Use pick value chart
    # Consider team needs
    # Factor in draft position desperation

func execute_trade(trade: Dictionary) -> void:
    # Update draft_pick_ownership
    # Log trade to history
    # Emit signal for UI update

func get_ai_trade_interest(team_id: String, current_pick: int) -> Array[Dictionary]:
    # AI teams wanting to trade up/down
    # Based on player availability and needs
```

#### Components Needed
- **DraftTradeEngine** - Core trade logic and validation
- **TradeProposalDialog.gd** - UI for user trade proposals
- **AI Trade Logic** - Team willingness to trade up/down based on needs
- **Pick Value Chart Integration** - Use existing `value_draft_pick()`
- **Trade History Tracking** - `draft_trades[year]` in world_state

#### Acceptance Criteria
- [ ] Create `scripts/world/DraftTradeEngine.gd` with trade validation
- [ ] Add `TradeProposalDialog` UI component to DraftDayUI
- [ ] AI teams propose trades when they want to move up for specific players
- [ ] AI teams accept/reject user trade proposals based on value
- [ ] Pick ownership updates correctly after trades
- [ ] Trade history persisted in world_state
- [ ] InteractiveDraft has injection points for trade opportunities
- [ ] User can initiate trades during draft (not just when it's their pick)

#### Files to Create
- `scripts/world/DraftTradeEngine.gd`
- `scenes/ui/draft_day/TradeProposalDialog.gd`
- `scenes/ui/draft_day/TradeProposalDialog.tscn`

#### Files to Modify
- `scripts/world/InteractiveDraft.gd` - Add trade injection points
- `scenes/ui/draft_day/DraftDayUI.gd` - Add trade UI trigger
- World state schema - Add `draft_trades` history

#### Testing Requirements

**Unit Tests:**
- [ ] `DraftTradeEngine.propose_trade()` validates trade legality (both teams exist, picks owned by correct teams)
- [ ] Trade validation rejects trades with picks already traded away
- [ ] Trade validation rejects trades with invalid pick numbers (0, negative, > 262)
- [ ] `evaluate_trade_value()` correctly uses pick value chart (1st pick > 2nd pick > ... > 262nd pick)
- [ ] Value differential calculation matches expected formula (sum of incoming value - sum of outgoing value)
- [ ] AI acceptance logic deterministic with same seed (same team, same offer, same seed = same decision)
- [ ] Edge case: Trading pick 1 for multiple late-round picks correctly valued
- [ ] Edge case: Trading future picks (if supported) validates year constraints
- [ ] `execute_trade()` updates `draft_pick_ownership` for both teams correctly
- [ ] Executed trades append to `world_state.draft_trades[year]` array
- [ ] Pick ownership query after trade returns correct team_id for traded picks

**Integration Tests:**
- [ ] Trade executed during pick 15 correctly updates InteractiveDraft state for picks 16+
- [ ] User trades up from pick 20 to pick 10, InteractiveDraft calls user for pick 10
- [ ] AI team trades up, InteractiveDraft correctly makes AI pick with new pick number
- [ ] Multiple trades in same draft (3+ trades) maintain consistent pick ownership
- [ ] Trade involving user's current pick immediately transitions to user selection UI
- [ ] Trade history persists through save/load cycle (execute trade, save, load, verify history)
- [ ] Trade executed after draft started but before pick made correctly updates live draft state

**Determinism Tests:**
- [ ] Run draft with 5 AI-initiated trades, same seed produces identical trades (teams, picks, timing)
- [ ] AI trade acceptance with seed 12345 vs 12346 produces different but valid results
- [ ] User proposes same trade 10 times with same seed, AI response identical each time
- [ ] Trade value calculations never use `randf()` or non-deterministic sources

**Performance Tests:**
- [ ] `propose_trade()` completes in < 10ms (lightweight validation)
- [ ] `evaluate_trade_value()` completes in < 50ms (pick chart lookup + simple math)
- [ ] `get_ai_trade_interest()` completes in < 100ms (scans all 32 teams' needs)
- [ ] Draft with 20 trades completes in same time as draft with 0 trades (±5%)
- [ ] Trade UI opens in < 200ms (responsive user experience)

**UI/UX Tests:**
- [ ] TradeProposalDialog displays user's picks and target team's picks
- [ ] Trade offer shows value differential ("You give up 500 points, receive 650 points")
- [ ] Rejected trade displays reason ("Team declined: insufficient value", "Pick already traded")
- [ ] Accepted trade shows confirmation animation/notification
- [ ] Trade history panel displays all trades chronologically with teams and picks
- [ ] User can initiate trade at any point during draft (not just on their turn)
- [ ] Trade UI disabled when user has no tradeable picks remaining
- [ ] Attempting to trade pick user doesn't own shows clear error message

**Regression Tests:**
- [ ] Draft without any trades completes successfully (trade system doesn't break basic draft)
- [ ] PreDraftProcess generates valid team boards (unaffected by trade engine existence)
- [ ] Draft simulation determinism maintained (draft with no trades reproducible)
- [ ] Existing draft UI still functional (pick timer, player cards, draft board)
- [ ] Save/load draft state with 0 trades works (trade history empty array serializes correctly)

---

### DRAFT-002: Underclassman Draft Entry System

**Priority:** HIGH
**Estimated Effort:** 8-10 hours
**Risk:** MEDIUM
**Dependencies:** None

#### Description

Implement player decision to declare early for the draft vs return to school. Currently all eligible players automatically enter. Real NFL draft pools vary dramatically (200-300 players vs current fixed ~500). Elite players declaring early is a major storyline.

#### Current State
- All draft-eligible players automatically enter draft pool
- No declaration process or deadline
- No withdrawal mechanism

#### Target State
```gdscript
# scripts/world/DraftDecisionEngine.gd (NEW FILE)
extends RefCounted
class_name DraftDecisionEngine

enum DeclarationStatus { UNDECLARED, DECLARED, WITHDRAWN, RETURNING }

func evaluate_declaration(player: Dictionary, rng: RandomNumberGenerator) -> DeclarationStatus:
    # Factors:
    # - Projected draft position (1st round = likely declare)
    # - Years remaining eligibility
    # - Player development trajectory
    # - Risk tolerance (injury concerns)
    # - Family financial situation (hidden trait)

func get_declaration_probability(player: Dictionary) -> float:
    # Higher projected pick = higher declare chance
    # Senior = 100% declare
    # Redshirt junior with 1st round grade = 85%+
    # True junior with day 3 grade = 30%

func process_declaration_window(world_state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    # Run between bowl games and combine
    # Returns: declared_players, returning_players, withdrawal_list
```

#### New World Calendar Phase
```gdscript
# Add to WorldCalendar phases (between bowl_games and combine)
"draft_declaration": {
    "name": "Draft Declaration Window",
    "start_week": 18,  # Mid-January
    "end_week": 19,
    "handler": "_process_draft_declarations"
}
```

#### Acceptance Criteria
- [ ] Create `scripts/world/DraftDecisionEngine.gd`
- [ ] Add `draft_declaration` phase to WorldCalendar
- [ ] Players have `draft_eligible` flag and `years_remaining` counter
- [ ] Junior/Sophomore players make declaration decisions
- [ ] Declaration probability based on projected draft position
- [ ] Players can withdraw before draft (medical, returning to school)
- [ ] Draft pool size varies realistically year-to-year (200-350 players)
- [ ] Integration with PreDraftProcess (runs after declarations)

#### Files to Create
- `scripts/world/DraftDecisionEngine.gd`

#### Files to Modify
- `scripts/core/models/Player.gd` - Add `draft_eligible`, `years_remaining`
- `scripts/world/WorldCalendar.gd` - Add declaration phase
- `scripts/pipelines/Advance.gd` - Wire up declaration phase handler
- `scripts/world/PreDraftProcess.gd` - Use declared pool only

#### Testing Requirements

**Unit Tests:**
- [ ] `evaluate_declaration()` returns DECLARED for all seniors (100% declare rate)
- [ ] True junior with 1st round grade has ≥80% declare probability
- [ ] True junior with 7th round grade has ≤30% declare probability
- [ ] Redshirt senior with any grade returns DECLARED (exhausted eligibility)
- [ ] `get_declaration_probability()` returns values in [0.0, 1.0] range for all valid inputs
- [ ] Declaration probability deterministic for same player attributes + seed
- [ ] Edge case: Player with 0 years remaining always declares (forced)
- [ ] Edge case: Player with negative years remaining throws error (invalid data)
- [ ] Edge case: Player with 4 years remaining (true freshman) has ~0% declare rate
- [ ] `process_declaration_window()` returns three arrays: declared, returning, withdrawn
- [ ] Declared list + returning list = total eligible pool (no players lost/duplicated)
- [ ] Same seed produces identical declaration decisions across 100 eligible players

**Integration Tests:**
- [ ] WorldCalendar triggers `draft_declaration` phase at week 18
- [ ] Declaration phase runs after bowl games, before combine
- [ ] PreDraftProcess receives only declared players (returning players excluded)
- [ ] Draft pool size varies year-to-year (200-350 range over 10 simulated years)
- [ ] Player with `draft_eligible=false` never enters draft pool
- [ ] Player who returns to school has `years_remaining` decremented by 1
- [ ] Player who declares moves to draft pool, removed from college rosters
- [ ] Declaration phase UI (if present) displays eligible players and their decision
- [ ] Save/load during declaration window preserves decision state

**Determinism Tests:**
- [ ] Run 5 seasons with seed 1000, record declaration decisions, repeat → identical results
- [ ] 50 juniors with identical attributes + same seed produce same number of declarations
- [ ] Changing seed from 1000 to 1001 produces different decisions but same overall distribution
- [ ] Declaration probability formula never uses global random state

**Performance Tests:**
- [ ] `evaluate_declaration()` completes in < 5ms per player (simple probability calculation)
- [ ] `process_declaration_window()` for 500 eligible players completes in < 1 second
- [ ] Declaration phase doesn't block UI (async processing or fast enough to be unnoticeable)
- [ ] Draft pool generation with variable-size pool no slower than fixed-size pool

**UI/UX Tests:**
- [ ] Declaration phase shows list of underclassmen considering draft
- [ ] UI displays projected draft position for each underclassman (inform user)
- [ ] Declaration results show which players declared, which returned
- [ ] Surprise declarations highlighted ("Projected 5th rounder declares early!")
- [ ] User can review declaration results before advancing to combine
- [ ] Draft board updated to reflect actual pool size (not theoretical maximum)

**Regression Tests:**
- [ ] Draft with only seniors (no underclassmen) still runs correctly
- [ ] PreDraftProcess with 500-player pool (all declare) behaves as before
- [ ] Seasons without draft-eligible underclassmen don't crash declaration phase
- [ ] Player lifecycle (aging, retirement) unaffected by declaration logic
- [ ] Existing draft tests pass with dynamic pool size (no hardcoded 500 assumptions)

---

### DRAFT-003: Medical/Character Red Flag Integration

**Priority:** HIGH
**Estimated Effort:** 6-8 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Amplify the impact of medical and character concerns on draft stock. Currently this data exists but has minimal draft impact. Failed physicals, interview bombs, and character concerns cause 1-3 round drops in real drafts (Laremy Tunsil, Randy Gregory).

#### Current State
- Medical evaluation data exists (`injury_eval`, `drug_screen`)
- Character interview scores exist
- Minimal impact on draft board positioning

#### Target State
```gdscript
# Enhancement to PreDraftProcess.gd

func _apply_red_flag_adjustments(player: Dictionary, team: Dictionary) -> float:
    var penalty := 0.0

    # Medical red flags
    if player.get("injury_eval") == "concern":
        penalty += _get_team_medical_risk_penalty(team)  # 0.5-2.0 rounds
    if player.get("injury_eval") == "failed":
        penalty += 3.0  # Some teams remove from board entirely

    # Character red flags
    var interview_score = player.get("interview_score", 50)
    if interview_score < 30:
        penalty += _get_team_character_risk_penalty(team)  # 0.5-1.5 rounds

    # Drug screen
    if player.get("drug_screen") == "positive":
        penalty += 1.0 + _get_team_character_risk_penalty(team)

    return penalty

func _get_team_medical_risk_penalty(team: Dictionary) -> float:
    # Some teams are risk-tolerant (Patriots historically)
    # Some teams are risk-averse
    var risk_tolerance = team.get("risk_tolerance", 0.5)
    return remap(risk_tolerance, 0.0, 1.0, 2.0, 0.5)
```

#### Post-Combine Medical Re-evaluation
```gdscript
func _run_medical_rechecks(draft_pool: Array, rng: RandomNumberGenerator) -> void:
    for player in draft_pool:
        # 5% chance of medical concern surfacing post-combine
        if rng.randf() < 0.05:
            player["medical_grade_updated"] = true
            player["injury_eval"] = "concern"
            # Creates storyline: "Player X fails physical with Team Y"
```

#### Acceptance Criteria
- [ ] Medical concerns cause 0.5-3 round drops depending on severity
- [ ] Character/interview bombs cause 0.5-1.5 round drops
- [ ] Teams have `risk_tolerance` attribute affecting penalties
- [ ] Post-combine medical re-evaluation phase (5% chance of new concerns)
- [ ] Failed physicals can remove players from team boards entirely
- [ ] Drug screen positives have compounding penalty
- [ ] Add `medical_grade_updated` field to track post-combine changes

#### Files to Modify
- `scripts/world/PreDraftProcess.gd` - Add red flag adjustments
- `scripts/core/models/Team.gd` - Add `risk_tolerance` attribute
- Draft scoring functions - Amplify medical/character penalties

#### Testing Requirements

**Unit Tests:**
- [ ] `_apply_red_flag_adjustments()` returns 0.0 penalty for player with no red flags
- [ ] Player with `injury_eval="concern"` receives 0.5-2.0 round penalty
- [ ] Player with `injury_eval="failed"` receives ≥3.0 round penalty
- [ ] Player with `interview_score < 30` receives 0.5-1.5 round penalty
- [ ] Player with `drug_screen="positive"` receives ≥1.0 round penalty
- [ ] Team with `risk_tolerance=1.0` applies minimum penalties (risk-tolerant)
- [ ] Team with `risk_tolerance=0.0` applies maximum penalties (risk-averse)
- [ ] `_get_team_medical_risk_penalty()` returns value in [0.5, 2.0] range
- [ ] `_get_team_character_risk_penalty()` returns value in [0.5, 1.5] range
- [ ] Multiple red flags compound (failed physical + positive drug screen = 4.0+ rounds)
- [ ] Edge case: Player with interview_score=29 vs 31 has measurably different penalty
- [ ] Edge case: Team with undefined `risk_tolerance` uses default (0.5)

**Integration Tests:**
- [ ] Player ranked 15th overall with failed physical drops to ~30-45th in team boards
- [ ] Player with character concerns drafted later than projected (compare to no-concern clone)
- [ ] Team board with 50 players correctly applies penalties to all flagged players
- [ ] `_run_medical_rechecks()` updates ~5% of players with new medical concerns
- [ ] Medical recheck phase runs after combine, before draft
- [ ] Player with `medical_grade_updated=true` has modified draft position
- [ ] Team boards recalculated after medical rechecks (not using stale data)
- [ ] Red flag adjustments persist through save/load (penalties don't reset)

**Determinism Tests:**
- [ ] Medical recheck with seed 5000 updates same players every run
- [ ] 100 players, seed 5000 → exactly 5 medical rechecks (5% of 100)
- [ ] Same player, same red flags, same team → identical penalty every time
- [ ] Penalty calculation never uses `randf()` (deterministic formula)
- [ ] Different teams evaluate same player → penalties vary by `risk_tolerance` only

**Performance Tests:**
- [ ] `_apply_red_flag_adjustments()` completes in < 5ms per player
- [ ] `_run_medical_rechecks()` for 300 players completes in < 100ms
- [ ] Red flag adjustments don't significantly impact PreDraftProcess runtime (< 10% increase)
- [ ] Team board generation with red flags completes in < 500ms per team

**UI/UX Tests:**
- [ ] Player card displays medical red flags (icon or text indicator)
- [ ] Player card displays character concerns (interview score, drug test)
- [ ] Draft board highlights players with red flags (color coding or badge)
- [ ] Player comparison tool shows red flags side-by-side
- [ ] Mock draft reflects red flag penalties (players drop in projections)
- [ ] Medical recheck notification shown to user ("Player X failed physical with Team Y")
- [ ] Scouting report includes risk assessment section

**Regression Tests:**
- [ ] Players with no red flags draft at same positions as before (no unintended penalties)
- [ ] Draft with 0 red flag players completes successfully
- [ ] Existing PreDraftProcess tests pass (red flag logic doesn't break core scoring)
- [ ] Team board generation determinism maintained (same seed = same boards)
- [ ] Player evaluation without `injury_eval` field doesn't crash (graceful defaults)

---

### DRAFT-004: Positional Runs and Draft Psychology

**Priority:** MEDIUM
**Estimated Effort:** 6-8 hours
**Risk:** LOW
**Dependencies:** DRAFT-001 (for panic trade-ups)

#### Description

Implement awareness of positional runs during the draft. When 3+ teams draft the same position in a short span, remaining teams with that need should feel urgency and potentially panic-draft or trade up. Creates realistic draft dynamics (2018 QB run, 2021 CB run).

#### Current State
- AI picks independently based on static pre-computed boards
- No awareness of draft trends
- Boards don't adjust to run dynamics

#### Target State
```gdscript
# scripts/world/DraftTrendAnalyzer.gd (NEW FILE)
extends RefCounted
class_name DraftTrendAnalyzer

var _position_picks: Dictionary = {}  # position -> [pick_numbers]
var _run_threshold: int = 3  # Picks at same position to trigger "run"

func record_pick(position: String, pick_number: int) -> void:
    if not _position_picks.has(position):
        _position_picks[position] = []
    _position_picks[position].append(pick_number)

func is_position_run_active(position: String, current_pick: int, window: int = 10) -> bool:
    var recent_picks = _position_picks.get(position, [])
    var in_window = recent_picks.filter(func(p): return current_pick - p <= window)
    return in_window.size() >= _run_threshold

func get_urgency_multiplier(team_id: String, position: String, current_pick: int) -> float:
    if not is_position_run_active(position, current_pick):
        return 1.0

    # Count remaining quality players at position
    var remaining = _count_remaining_at_position(position)
    if remaining <= 2:
        return 2.0  # Panic mode
    elif remaining <= 5:
        return 1.5  # Elevated urgency
    return 1.2  # Mild concern

func should_team_panic_trade(team_id: String, position: String) -> bool:
    # Returns true if team should consider trading up
    # Based on: position need, run active, remaining players, draft capital
```

#### Integration with InteractiveDraft
```gdscript
# In InteractiveDraft._make_ai_pick()
func _make_ai_pick(pick_assignment: Dictionary) -> void:
    var team_id = pick_assignment["team_id"]

    # Check for panic trade opportunity first
    if _trade_engine and _trend_analyzer:
        var panic_position = _get_team_panic_need(team_id)
        if panic_position and _trend_analyzer.should_team_panic_trade(team_id, panic_position):
            var trade_result = _attempt_panic_trade_up(team_id, panic_position)
            if trade_result:
                return  # Trade executed, pick handled

    # Normal pick with urgency adjustments
    var board = _team_boards.get(team_id, [])
    for entry in board:
        var urgency = _trend_analyzer.get_urgency_multiplier(team_id, entry["position"], _current_pick)
        entry["adjusted_score"] = entry["score"] * urgency

    board.sort_custom(func(a, b): return a["adjusted_score"] > b["adjusted_score"])
    # ... continue with pick
```

#### Acceptance Criteria
- [ ] Create `scripts/world/DraftTrendAnalyzer.gd`
- [ ] Detect positional runs (3+ picks at same position in 10-pick window)
- [ ] Apply urgency multiplier to team boards when run active
- [ ] Teams consider panic trades when position depleted (requires DRAFT-001)
- [ ] Dynamic board re-scoring mid-draft based on trends
- [ ] Makes draft less predictable and more realistic

#### Files to Create
- `scripts/world/DraftTrendAnalyzer.gd`

#### Files to Modify
- `scripts/world/InteractiveDraft.gd` - Integrate trend analyzer

#### Testing Requirements

**Unit Tests:**
- [ ] `record_pick()` correctly appends pick number to position's pick history
- [ ] `is_position_run_active()` returns false when < 3 picks in window
- [ ] `is_position_run_active()` returns true when ≥ 3 picks at same position within 10-pick window
- [ ] Run detection ignores picks outside window (pick 5 doesn't count toward pick 20 window)
- [ ] `get_urgency_multiplier()` returns 1.0 when no run active (baseline)
- [ ] `get_urgency_multiplier()` returns 2.0 when ≤2 quality players remain (panic)
- [ ] `get_urgency_multiplier()` returns 1.5 when ≤5 quality players remain (elevated)
- [ ] `get_urgency_multiplier()` returns 1.2 when >5 quality players remain (mild concern)
- [ ] `should_team_panic_trade()` returns true for team with urgent need during run
- [ ] `should_team_panic_trade()` returns false for team without need at run position
- [ ] Edge case: Three consecutive QB picks (1, 2, 3) triggers QB run at pick 4
- [ ] Edge case: Run at multiple positions simultaneously (QB run + CB run)

**Integration Tests:**
- [ ] QB run (3 QBs in 5 picks) causes team needing QB to boost QB scores
- [ ] Team with QB need during QB run applies 1.5-2.0x multiplier to remaining QBs
- [ ] Panic trade triggered when 3 CBs drafted and only 1 elite CB remains
- [ ] Team boards dynamically re-scored mid-draft (not static pre-computed boards)
- [ ] InteractiveDraft calls `_trend_analyzer.record_pick()` after every pick
- [ ] Urgency multipliers affect AI pick decisions (urgent team drafts needed position earlier)
- [ ] Non-urgent team ignores run (doesn't panic-draft position they don't need)
- [ ] Panic trade attempt uses DraftTradeEngine integration (requires DRAFT-001)

**Determinism Tests:**
- [ ] Same draft sequence (same picks) produces identical urgency multipliers every time
- [ ] Run detection deterministic (no random elements in is_position_run_active)
- [ ] Panic trade decision deterministic with same seed (same team, same situation)
- [ ] Board re-scoring with urgency multipliers deterministic (no random score adjustments)

**Performance Tests:**
- [ ] `record_pick()` completes in < 1ms (simple array append)
- [ ] `is_position_run_active()` completes in < 5ms (window filter + count)
- [ ] `get_urgency_multiplier()` completes in < 10ms (count remaining players)
- [ ] Board re-scoring with urgency multipliers completes in < 50ms (multiply 50 scores)
- [ ] Trend analysis doesn't slow down draft picks (AI pick still < 100ms target)

**UI/UX Tests:**
- [ ] Draft UI shows "Positional Run Alert: QB" when run detected
- [ ] User's board highlights affected players (urgency indicator)
- [ ] Panic trade offer popup appears for user when they're in panic situation
- [ ] Draft commentary mentions run ("Four cornerbacks off the board in the last 10 picks")
- [ ] Team need panel shows urgency level (green/yellow/red indicator)
- [ ] User can see which teams are in panic mode for each position

**Regression Tests:**
- [ ] Draft without runs (balanced positional distribution) completes normally
- [ ] Static team boards (no runs) produce same picks as before
- [ ] InteractiveDraft determinism maintained (urgency system doesn't break reproduction)
- [ ] Draft with trend analyzer disabled still functions (graceful degradation)
- [ ] Existing AI pick logic works without trend analyzer integration

---

### DRAFT-005: Mock Drafts and Scouting Reports

**Priority:** MEDIUM
**Estimated Effort:** 10-12 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Add pre-draft intelligence including mock drafts, detailed scouting reports, and a user-customizable big board. Enhances user immersion and strategic planning without affecting core draft mechanics.

#### Target State
```gdscript
# scripts/world/MockDraftSimulator.gd (NEW FILE)
extends RefCounted
class_name MockDraftSimulator

func generate_mock_draft(world_state: Dictionary, seed: int) -> Array[Dictionary]:
    # Run AI-only draft simulation
    # Returns projected picks with explanations
    # [{"pick": 1, "team": "JAX", "player_id": "...", "position": "QB", "reasoning": "..."}]

func generate_consensus_board(world_state: Dictionary, num_mocks: int = 10) -> Array[Dictionary]:
    # Run multiple mocks with different seeds
    # Return average draft position for each player
    # [{"player_id": "...", "avg_pick": 4.2, "range": [1, 8], "variance": 2.1}]
```

```gdscript
# scripts/world/ScoutingReportGenerator.gd (NEW FILE)
extends RefCounted
class_name ScoutingReportGenerator

func generate_report(player: Dictionary, team_scouts: Array) -> Dictionary:
    return {
        "player_id": player["id"],
        "grade": _calculate_grade(player),
        "strengths": _identify_strengths(player),
        "weaknesses": _identify_weaknesses(player),
        "comparison": _find_player_comparison(player),
        "projection": _project_nfl_role(player),
        "risk_factors": _assess_risks(player),
        "scout_notes": _generate_scout_notes(player, team_scouts)
    }

func _identify_strengths(player: Dictionary) -> Array[String]:
    # Return top 3 strengths based on above-average stats

func _identify_weaknesses(player: Dictionary) -> Array[String]:
    # Return areas of concern based on below-average stats

func _find_player_comparison(player: Dictionary) -> String:
    # "Plays like a young Patrick Mahomes" style comparison
```

#### Draft War Room UI
```gdscript
# scenes/ui/draft_day/DraftWarRoomUI.gd (NEW FILE)
extends Control

# Tabs:
# - Big Board (user-customizable rankings)
# - Mock Drafts (consensus projections)
# - Scouting Reports (detailed player analysis)
# - Team Needs (depth chart gaps by position)
# - Player Comparison (side-by-side compare 3-4 players)
```

#### Player Comparison Tool (General Purpose - Reusable Component)

The comparison tool is a **general-purpose component** reusable across the game:
- **Draft**: Compare draft prospects, draft directly from comparison
- **Roster Management**: Compare your players to league leaders ("my safeties vs top 5 NFL safeties")
- **Free Agency**: Compare free agent targets to your current starters
- **Trade Evaluation**: Compare incoming player to your roster

```
╔════════════════════════════════════════════════════════════════════════╗
║  PLAYER COMPARISON                              [Filter: Safety ▼]     ║
╠════════════════════════════════════════════════════════════════════════╣
║  ATTRIBUTE        │ K. Johnson  │ M. Williams │ T. Smith  │ D. Brown  ║
║                   │ (MY ROSTER) │ (LEAGUE)    │ (DRAFTED) │ (FA)      ║
║  ─────────────────┼─────────────┼─────────────┼───────────┼───────────║
║  Team             │   My Team   │   Ravens    │    ───    │   FREE    ║
║  Age              │     26      │     28      │    22     │    30     ║
║  Contract         │  $8.2M/yr   │  $14.1M/yr  │   Rookie  │    ───    ║
║  ─────────────────┼─────────────┼─────────────┼───────────┼───────────║
║  Coverage         │     82      │     94      │    78     │    85     ║
║  Tackling         │     88      │     86      │    75     │    90     ║
║  Ball Skills      │     79      │     91      │    82     │    77     ║
║  Range            │     85      │     88      │    90     │    72     ║
║  ─────────────────┼─────────────┼─────────────┼───────────┼───────────║
║  Overall          │     83      │     90      │    81     │    81     ║
║  Status           │   STARTER   │     ───     │ UNAVAIL.  │ AVAILABLE ║
╠════════════════════════════════════════════════════════════════════════╣
║  Actions:         │   [VIEW]    │   [VIEW]    │   [───]   │  [SIGN]   ║
╚════════════════════════════════════════════════════════════════════════╝
   [Add Player]  [Add from: My Roster | League | Draft | FA]  [Clear All]
```

**Unavailable Player Handling:**
- Players drafted by other teams show "UNAVAIL." status with grayed styling
- Action button disabled (shows `[───]` instead of `[DRAFT]`)
- Player remains in comparison for reference but clearly marked
- Optional: Auto-remove unavailable players setting

**Context-Aware Actions:**
| Source | Available Actions |
|--------|-------------------|
| Draft Pool | [DRAFT] (when user's turn), [★ WATCH] |
| Free Agents | [SIGN] (opens contract negotiation), [★ WATCH] |
| League Players | [VIEW], [TRADE] (if tradeable), [★ WATCH] |
| My Roster | [VIEW] (opens player card) |

All players (except your roster) can be added to your shortlist via [★ WATCH].
Players already on shortlist show ★ indicator and [★ REMOVE] action.

Features:
- Compare 3-4 players simultaneously (same position recommended)
- **Mix players from any source**: roster, league, draft, free agents
- Color-coded cells (green = best, red = worst in category)
- Stat bars for visual comparison
- Add/remove players dynamically
- Filter by position for relevant comparisons
- **Unavailable players visually indicated** (grayed out, action disabled)
- **Context-aware action buttons** (Draft/Sign/View/Trade based on player source)
- **Shortlist integration** - [★ WATCH] action on any player, ★ indicator for shortlisted
- Export comparison to clipboard

#### Acceptance Criteria
- [ ] Create `MockDraftSimulator.gd` to generate projections
- [ ] Create `ScoutingReportGenerator.gd` for detailed reports
- [ ] Create `DraftWarRoomUI` with multiple tabs
- [ ] User can create/edit custom big board rankings
- [ ] Mock drafts show projected picks with variance
- [ ] Scouting reports include strengths, weaknesses, comparisons
- [ ] **Player comparison supports 3-4 players simultaneously**
- [ ] **Color-coded cells highlight best/worst in each category**
- [ ] **Dynamic add/remove players from comparison**
- [ ] **Draft player directly from comparison view (no back-navigation required)**
- [ ] **Compare players from mixed sources (roster, league, draft, FA)**
- [ ] **Unavailable players clearly indicated with disabled actions**
- [ ] **Context-aware action buttons based on player source**
- [ ] **Shortlist action [★ WATCH] available on all players (integrates with DRAFT-009)**
- [ ] Team needs analysis based on depth chart

#### Files to Create
- `scripts/world/MockDraftSimulator.gd`
- `scripts/world/ScoutingReportGenerator.gd`
- `scenes/ui/common/PlayerComparisonTool.gd` (reusable component)
- `scenes/ui/common/PlayerComparisonTool.tscn`
- `scenes/ui/draft_day/DraftWarRoomUI.gd`
- `scenes/ui/draft_day/DraftWarRoomUI.tscn`

#### Testing Requirements

**Unit Tests:**
- [ ] `generate_mock_draft()` produces 262 picks (full 7-round draft)
- [ ] Mock draft results include all required fields (pick, team, player_id, position, reasoning)
- [ ] Mock draft with same seed produces identical results every time
- [ ] Mock draft with different seed produces different but valid results
- [ ] `generate_consensus_board()` averages 10 mock drafts correctly
- [ ] Consensus board includes avg_pick, range [min, max], and variance for each player
- [ ] Player with picks [1, 3, 2, 4, 1] has avg_pick=2.2, range=[1,4], variance calculated
- [ ] `generate_report()` returns dictionary with all required fields
- [ ] `_identify_strengths()` returns top 3 attributes (highest values)
- [ ] `_identify_weaknesses()` returns bottom 3 attributes (lowest values)
- [ ] `_find_player_comparison()` returns non-empty string comparison
- [ ] Edge case: Player with all equal stats returns balanced strengths/weaknesses

**Integration Tests:**
- [ ] MockDraftSimulator runs actual InteractiveDraft simulation (AI-only)
- [ ] Mock draft respects team needs (team needing QB drafts QB highly)
- [ ] Mock draft includes trade probability (some mocks have trades, some don't)
- [ ] Consensus board aggregates multiple mocks without duplicating players
- [ ] Scouting report generator accesses player stats from world_state correctly
- [ ] DraftWarRoomUI loads and displays all tabs (Big Board, Mocks, Reports, Needs, Compare)
- [ ] User-customizable big board persists rankings through save/load
- [ ] Mock draft accuracy improves as draft approaches (less variance in consensus)

**Determinism Tests:**
- [ ] Run 10 consensus boards with same seed → identical avg_pick for all players
- [ ] Mock draft #1 with seed 1000 identical to mock draft #2 with seed 1000
- [ ] Scouting report generation deterministic (same player → same report)
- [ ] Player comparison tool shows identical data for same player selected twice

**Performance Tests:**
- [ ] Single mock draft completes in < 5 seconds (fast AI simulation)
- [ ] Consensus board (10 mocks) completes in < 30 seconds (acceptable for one-time generation)
- [ ] Scouting report generation completes in < 100ms per player
- [ ] Player comparison tool renders in < 200ms (responsive UI)
- [ ] Adding/removing player from comparison updates in < 50ms (smooth UX)
- [ ] Draft War Room UI loads in < 500ms (all tabs initialized)

**UI/UX Tests:**
- [ ] **Comparison tool displays 3-4 players side-by-side**
- [ ] **Color-coded cells: green=best, red=worst, gradient for middle values**
- [ ] **User can add player via "Add Player" button with source selection**
- [ ] **User can remove player via [Remove] button in player column**
- [ ] **Context-aware action buttons: [DRAFT] for draft prospects when user's turn**
- [ ] **Context-aware action buttons: [SIGN] for free agents**
- [ ] **Context-aware action buttons: [TRADE] for league players (if tradeable)**
- [ ] **Context-aware action buttons: [VIEW] for any player**
- [ ] **Context-aware action buttons: [★ WATCH] to add to shortlist**
- [ ] **Unavailable players show "UNAVAIL." status with grayed styling**
- [ ] **Unavailable players have disabled action button: [───]**
- [ ] **Shortlisted players show ★ indicator in comparison tool**
- [ ] **User can draft player directly from comparison (no navigation required)**
- [ ] **Comparison supports mixed sources: roster + league + draft + FA**
- [ ] **Filter by position for relevant comparisons**
- [ ] Big Board allows drag-and-drop ranking
- [ ] Mock drafts show variance bars (wide bar = high variance)
- [ ] Scouting reports display strengths/weaknesses/comparison clearly
- [ ] Team needs panel shows depth chart gaps with severity (critical/moderate/minor)
- [ ] Comparison tool export to clipboard works (paste into spreadsheet)

**Regression Tests:**
- [ ] Mock drafts don't interfere with actual draft execution
- [ ] Player stats unchanged by scouting report generation (read-only operation)
- [ ] Draft War Room doesn't block draft progression (view-only UI)
- [ ] Comparison tool works with players missing optional stats (graceful degradation)
- [ ] User-edited big board doesn't affect AI draft boards (independent data)
- [ ] Mock drafts with incomplete player data don't crash (validation/fallbacks)

---

### DRAFT-006: Undrafted Free Agent Bidding War

**Priority:** LOW
**Estimated Effort:** 4-6 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Implement the post-draft UDFA signing frenzy. Top undrafted players sign within minutes of Mr. Irrelevant being selected. Creates post-draft excitement and allows discovery of UDFA gems (Tony Romo, Wes Welker, etc.).

#### Target State
```gdscript
# Enhancement to post-draft flow

func _run_udfa_signing_rush(world_state: Dictionary, user_team_id: String) -> Dictionary:
    var undrafted = _get_undrafted_players(world_state)
    var top_udfas = _rank_udfas(undrafted)[:50]  # Top 50 UDFAs

    var signing_results = {
        "user_signings": [],
        "ai_signings": [],
        "available": []
    }

    # User gets first crack at their priority targets
    # Then AI teams bid based on need and interest
    # UDFA contracts: 3 years, minimum salary, no guaranteed money

    return signing_results
```

#### UDFA Signing UI
```gdscript
# Post-draft popup showing:
# - Top available UDFAs ranked by talent
# - "Priority UDFA" selection (user picks 3-5 targets)
# - Results showing who signed where
# - Option to add UDFAs to practice squad
```

#### Acceptance Criteria
- [ ] Post-draft UDFA signing phase runs immediately after draft ends
- [ ] Top 50 UDFAs ranked and available for signing
- [ ] User can select priority targets before AI bidding
- [ ] AI teams sign UDFAs based on roster needs
- [ ] UDFA contracts differ from drafted rookies (no guaranteed money)
- [ ] UI shows signing results with team destinations

#### Files to Modify
- `scripts/world/InteractiveDraft.gd` - Add post-draft UDFA phase
- `scenes/ui/draft_day/DraftDayUI.gd` - Add UDFA signing UI

#### Testing Requirements

**Unit Tests:**
- [ ] `_get_undrafted_players()` returns all players not in draft results (500 eligible - 262 drafted = 238 undrafted)
- [ ] `_rank_udfas()` sorts undrafted players by talent/potential correctly
- [ ] Top 50 UDFAs include only highest-rated undrafted players
- [ ] UDFA ranking deterministic with same seed (same order every time)
- [ ] User priority targets respected (user's top 3-5 evaluated first)
- [ ] AI team bidding based on roster needs (team needing WR targets undrafted WRs)
- [ ] UDFA contract structure: 3 years, minimum salary, $0 guaranteed
- [ ] Drafted rookie contract vs UDFA contract distinguishable (different terms)
- [ ] Edge case: 0 undrafted players (all 500 eligible players drafted) doesn't crash
- [ ] Edge case: User selects 10 priority targets but only 5 available (graceful handling)

**Integration Tests:**
- [ ] UDFA signing phase runs immediately after pick 262 (Mr. Irrelevant)
- [ ] User receives priority selection window before AI bidding
- [ ] User's top 3 priority targets signed before AI teams compete
- [ ] AI teams sign UDFAs deterministically with same seed
- [ ] UDFA signings distributed across all 32 teams (some teams sign 0-3 UDFAs)
- [ ] Signed UDFAs added to team rosters with correct contract terms
- [ ] UDFA signing results persist through save/load
- [ ] Unsigned UDFAs remain in free agent pool (available for camp invites later)

**Determinism Tests:**
- [ ] UDFA phase with seed 7000 produces identical signing results every run
- [ ] User selects same 3 priority targets → same outcome with same seed
- [ ] AI bidding order deterministic (Team A signs Player X, Team B signs Player Y)
- [ ] 50 UDFAs with same seed → same distribution across teams

**Performance Tests:**
- [ ] `_rank_udfas()` for 238 undrafted players completes in < 200ms
- [ ] UDFA signing simulation (AI bidding for 50 players) completes in < 1 second
- [ ] UDFA UI loads priority selection screen in < 300ms
- [ ] Results screen displays all signings in < 200ms (table rendering)

**UI/UX Tests:**
- [ ] UDFA signing UI shows top 50 available UDFAs ranked by talent
- [ ] User can select 3-5 priority targets via checkbox or drag-to-priority-list
- [ ] User's selections highlighted (visual confirmation)
- [ ] Results screen shows three categories: user signings, AI signings, available
- [ ] Each signing displays team, player, position, contract terms
- [ ] Option to add unsigned UDFAs to practice squad shown
- [ ] "View All UDFAs" button shows complete undrafted list (not just top 50)
- [ ] User can skip UDFA phase (auto-simulate) if not interested

**Regression Tests:**
- [ ] Draft completion without UDFA phase still works (phase is optional addon)
- [ ] Drafted players never appear in UDFA pool (proper exclusion)
- [ ] UDFA contracts don't break salary cap calculations
- [ ] Team rosters after UDFA signings respect position limits (no 10 QBs)
- [ ] UDFA signing phase doesn't block season advancement
- [ ] Player contract types (drafted vs UDFA vs veteran) remain distinguishable

---

### DRAFT-007: Draft Grades and Analysis

**Priority:** LOW
**Estimated Effort:** 3-4 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Generate post-draft analysis including team grades, best picks ("steals"), and reaches. Provides flavor and immersion without affecting simulation mechanics.

#### Target State
```gdscript
# scripts/world/DraftGradeCalculator.gd (NEW FILE)
extends RefCounted
class_name DraftGradeCalculator

func calculate_team_grade(team_id: String, draft_results: Array) -> Dictionary:
    return {
        "team_id": team_id,
        "overall_grade": "B+",  # A+ to F scale
        "value_score": 85.5,    # 0-100 based on pick value vs player value
        "need_score": 78.0,     # How well they addressed needs
        "picks": _grade_individual_picks(team_id, draft_results),
        "analysis": _generate_analysis_text(team_id, draft_results)
    }

func identify_steals(draft_results: Array) -> Array[Dictionary]:
    # Players drafted significantly later than projected value
    # [{"player_id": "...", "pick": 45, "projected": 15, "value_diff": 30}]

func identify_reaches(draft_results: Array) -> Array[Dictionary]:
    # Players drafted significantly earlier than projected value
```

#### Post-Draft Analysis Screen
```
╔══════════════════════════════════════════════════════╗
║                  2035 NFL DRAFT GRADES               ║
╠══════════════════════════════════════════════════════╣
║  TEAM          GRADE   VALUE   NEED   BEST PICK     ║
║  ────────────  ─────   ─────   ────   ────────────  ║
║  Jacksonville    A-     92.3   88.5   T. Williams   ║
║  Houston         B+     85.1   91.2   M. Johnson    ║
║  ...                                                 ║
╠══════════════════════════════════════════════════════╣
║  STEAL OF THE DRAFT: RB Marcus Cole (Pick 87)       ║
║  BIGGEST REACH: CB Devon Smith (Pick 22)            ║
╚══════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `DraftGradeCalculator.gd`
- [ ] Generate A+ to F grades for each team
- [ ] Calculate value score (pick value vs player value)
- [ ] Calculate need score (how well team addressed needs)
- [ ] Identify steals (drafted 15+ picks later than value)
- [ ] Identify reaches (drafted 15+ picks earlier than value)
- [ ] Post-draft analysis screen displays grades

#### Files to Create
- `scripts/world/DraftGradeCalculator.gd`
- `scenes/ui/draft_day/DraftAnalysisScreen.gd`
- `scenes/ui/draft_day/DraftAnalysisScreen.tscn`

#### Testing Requirements

**Unit Tests:**
- [ ] `calculate_team_grade()` returns grade in valid range (A+, A, A-, B+, ..., F)
- [ ] `value_score` in range [0.0, 100.0] (clamped if formula exceeds)
- [ ] `need_score` in range [0.0, 100.0] (clamped if formula exceeds)
- [ ] Team drafting all high-value picks receives A/A+ grade
- [ ] Team drafting all reaches receives D/F grade
- [ ] Team addressing critical needs receives high `need_score` (≥80)
- [ ] Team ignoring needs receives low `need_score` (≤50)
- [ ] `_grade_individual_picks()` assigns letter grade to each pick
- [ ] `identify_steals()` returns players drafted ≥15 picks below projected value
- [ ] `identify_reaches()` returns players drafted ≥15 picks above projected value
- [ ] Edge case: Team trades away all picks receives N/A or F grade (no picks to evaluate)
- [ ] Edge case: Team with 0 needs (perfect roster) still gets reasonable grade

**Integration Tests:**
- [ ] All 32 teams receive grades after draft completion
- [ ] Grade calculation uses actual draft results (correct pick numbers and players)
- [ ] Grade considers trades (value of acquired picks vs given picks)
- [ ] Steal identification compares actual pick to consensus mock draft projection
- [ ] Reach identification uses same projection baseline as steals
- [ ] `analysis` text mentions specific players and team needs
- [ ] Post-draft analysis screen displays all team grades in sortable table
- [ ] User can view detailed breakdown for each team (click team row)

**Determinism Tests:**
- [ ] Same draft results produce identical grades every time (no randomness in grading)
- [ ] Grade calculation never uses RNG (purely deterministic formula)
- [ ] Steal/reach identification deterministic (same thresholds applied consistently)

**Performance Tests:**
- [ ] `calculate_team_grade()` for one team completes in < 50ms
- [ ] Grade all 32 teams completes in < 2 seconds (acceptable for end-of-draft)
- [ ] `identify_steals()` and `identify_reaches()` complete in < 100ms (scan 262 picks)
- [ ] Analysis screen renders in < 300ms (display 32 rows of grades)

**UI/UX Tests:**
- [ ] Draft analysis screen shows team grades in sortable table (by grade, value, need)
- [ ] User's team highlighted in results (distinct color or border)
- [ ] "Steal of the Draft" displayed prominently with player details
- [ ] "Biggest Reach" displayed with player and team context
- [ ] User can click team to see detailed grade breakdown
- [ ] Grade breakdown shows pick-by-pick analysis (each pick's grade)
- [ ] Analysis text readable and informative ("Team X addressed QB need with Pick 10")
- [ ] Option to export grades to CSV or share (screenshot/copy)
- [ ] Color-coded grades (A/B = green, C/D = yellow, F = red)

**Regression Tests:**
- [ ] Draft grades don't affect game simulation (cosmetic feature only)
- [ ] Grades remain consistent across save/load (calculation reproducible)
- [ ] Draft without grades still completes normally (grades are optional)
- [ ] Grade calculation doesn't modify draft results data (read-only operation)
- [ ] Analysis screen accessible from draft history (review past drafts)

---

### DRAFT-008: Conditional Draft Picks (Post-1.0)

**Priority:** VERY LOW
**Estimated Effort:** 8-10 hours
**Risk:** MEDIUM
**Dependencies:** DRAFT-001

#### Description

Implement conditional draft picks that convert based on performance criteria. Rare in NFL (1-2 per year) so high complexity for low return. Consider for post-1.0 polish.

#### Examples
- "5th round pick becomes 4th if player makes Pro Bowl"
- "7th round pick becomes 6th if player plays 50%+ snaps"
- "2026 3rd becomes 2nd if team makes playoffs"

#### Target State
```gdscript
# Data model for conditional picks
var conditional_pick = {
    "base_round": 5,
    "upgrade_round": 4,
    "condition_type": "pro_bowl",  # pro_bowl, snap_percentage, playoffs, games_started
    "condition_target": "player_id_123",
    "condition_threshold": 1,  # 1 Pro Bowl
    "evaluation_year": 2026,
    "status": "pending"  # pending, upgraded, base
}

# Service to evaluate conditions
func evaluate_conditional_picks(world_state: Dictionary) -> Array[Dictionary]:
    # Run at end of each season
    # Check conditions for all pending conditional picks
    # Update pick round if condition met
```

#### Acceptance Criteria
- [ ] Data model for conditional picks with criteria
- [ ] Conditions: Pro Bowl, snap percentage, playoffs, games started
- [ ] Evaluation service runs at season end
- [ ] Pick round updates when condition met
- [ ] Trade UI supports conditional pick creation
- [ ] History tracks condition resolution

#### Testing Requirements

**Unit Tests:**
- [ ] Conditional pick data model validates all required fields (base_round, upgrade_round, condition_type, etc.)
- [ ] `base_round` must be lower value than `upgrade_round` (5th → 4th valid, 4th → 5th invalid)
- [ ] Condition types enum includes all supported types (pro_bowl, snap_percentage, playoffs, games_started)
- [ ] `evaluate_conditional_picks()` returns picks that met conditions
- [ ] Pro Bowl condition: Player makes Pro Bowl → pick upgrades (5th → 4th)
- [ ] Snap percentage condition: Player plays ≥50% snaps → pick upgrades
- [ ] Playoffs condition: Team makes playoffs → pick upgrades
- [ ] Games started condition: Player starts ≥10 games → pick upgrades
- [ ] Condition not met: Pick remains at base round (5th stays 5th)
- [ ] Edge case: Condition met in year 1 of multi-year evaluation window
- [ ] Edge case: Player traded mid-season, condition still evaluates correctly
- [ ] Edge case: Player injured (0% snaps), snap percentage condition fails

**Integration Tests:**
- [ ] Conditional pick created in trade, stored in draft_pick_ownership
- [ ] Evaluation service runs at end of each season automatically
- [ ] Pick round updated in draft_pick_ownership when condition met
- [ ] Updated pick reflects correctly in next year's draft
- [ ] Trade involving conditional pick displays condition in trade UI
- [ ] Trade history shows condition and resolution status (pending/met/failed)
- [ ] Multiple conditional picks in same trade evaluate independently
- [ ] Conditional pick persists through save/load with status intact

**Determinism Tests:**
- [ ] Conditional pick evaluation deterministic (same player stats → same outcome)
- [ ] No RNG in condition evaluation (purely rule-based)
- [ ] Multiple evaluations of same condition produce identical results

**Performance Tests:**
- [ ] `evaluate_conditional_picks()` for 5 conditional picks completes in < 100ms
- [ ] Condition evaluation doesn't slow down season advancement (< 1% overhead)
- [ ] Trade UI with conditional picks renders in < 300ms (no lag)

**UI/UX Tests:**
- [ ] Trade UI shows conditional pick creation option (checkbox or dropdown)
- [ ] User can select condition type from dropdown (Pro Bowl, Snap %, Playoffs, etc.)
- [ ] User can set condition threshold (50% snaps, 1 Pro Bowl, etc.)
- [ ] Trade preview shows conditional pick clearly ("5th → 4th if player makes Pro Bowl")
- [ ] Draft pick list shows conditional picks with badge or indicator
- [ ] Condition status displayed (pending/met/failed) with icon
- [ ] Notification when condition met ("Conditional pick upgraded to 4th round!")
- [ ] Trade history displays condition resolution with timestamp

**Regression Tests:**
- [ ] Trades without conditional picks still work (non-conditional path unaffected)
- [ ] Draft with no conditional picks completes normally
- [ ] Conditional pick system doesn't break standard pick ownership
- [ ] Game saves with 0 conditional picks load correctly (empty array)
- [ ] Legacy saves without conditional pick data load with defaults (graceful migration)

---

### DRAFT-009: Player Shortlist / Watchlist

**Priority:** MEDIUM
**Estimated Effort:** 6-8 hours
**Risk:** LOW
**Dependencies:** None (enhances DRAFT-005 comparison tool)

#### Description

Persistent watchlist for tracking players of interest across different contexts. Works year-round for strategic roster building - not just draft day. Integrates with the PlayerComparisonTool for quick comparisons.

#### Use Cases
- **Draft Prep**: Track prospects months before the draft
- **Trade Targets**: Monitor players on other teams you want to acquire
- **Free Agency Watch**: Track players whose contracts expire soon
- **Prospect Development**: Follow college players across multiple seasons

#### Target State
```gdscript
# scripts/core/models/PlayerShortlist.gd (NEW FILE)
extends Resource
class_name PlayerShortlist

enum ListCategory { DRAFT_PROSPECTS, TRADE_TARGETS, FA_WATCH, GENERAL }

var entries: Array[ShortlistEntry] = []

func add_player(player_id: String, category: ListCategory, notes: String = "") -> void:
    var entry = ShortlistEntry.new()
    entry.player_id = player_id
    entry.category = category
    entry.notes = notes
    entry.added_date = Time.get_date_string_from_system()
    entries.append(entry)

func remove_player(player_id: String) -> void:
    entries = entries.filter(func(e): return e.player_id != player_id)

func get_by_category(category: ListCategory) -> Array[ShortlistEntry]:
    return entries.filter(func(e): return e.category == category)

func is_on_shortlist(player_id: String) -> bool:
    return entries.any(func(e): return e.player_id == player_id)

func to_dict() -> Dictionary:
    # Persisted with game session
```

```gdscript
# scripts/core/models/ShortlistEntry.gd (NEW FILE)
extends Resource
class_name ShortlistEntry

@export var player_id: String = ""
@export var category: PlayerShortlist.ListCategory = PlayerShortlist.ListCategory.GENERAL
@export var notes: String = ""  # User notes: "Great zone coverage, watch 40 time"
@export var added_date: String = ""
@export var priority: int = 0  # 1-5 stars or ranking within category
@export var alert_on_available: bool = false  # Notify when FA/tradeable
```

#### Shortlist UI
```
╔══════════════════════════════════════════════════════════════════════╗
║  MY SHORTLIST                    [Draft Prospects ▼]   [+ Add Player]║
╠══════════════════════════════════════════════════════════════════════╣
║  ★★★★★  J. Williams (QB, Alabama)           DRAFT PROSPECT           ║
║         "Elite arm talent, best QB in class"         [Compare][Remove]║
║  ────────────────────────────────────────────────────────────────────║
║  ★★★★☆  M. Harrison (QB, Ohio State)        DRAFT PROSPECT           ║
║         "More mobile, watch decision making"         [Compare][Remove]║
║  ────────────────────────────────────────────────────────────────────║
║  ★★★☆☆  D. Carter (QB, Georgia)             DRAFT PROSPECT           ║
║         "Solid floor, limited ceiling"               [Compare][Remove]║
╠══════════════════════════════════════════════════════════════════════╣
║  [Compare All]  [Clear Category]  [Export]                            ║
╚══════════════════════════════════════════════════════════════════════╝

Category Tabs: [Draft Prospects (3)] [Trade Targets (5)] [FA Watch (2)] [All (10)]
```

**Integration Points:**
- **Player Detail Panel**: [★ WATCH] button on every player detail view (universal access point)
- **Comparison Tool**: [★ WATCH] action per player column, ★ indicator for shortlisted players
- **Draft UI**: Shortlist panel sidebar, filter draft board to show only shortlisted
- **Roster/League Views**: ★ indicator on shortlisted players in any list
- **Notifications**: "Player X is now available" when watched player hits FA or trade block
- **Season Rollover**: Draft prospects auto-archive after drafted/undrafted

**Status Indicators:**
| Status | Display |
|--------|---------|
| On shortlist | ★ icon on player in any list |
| Drafted (by you) | ✓ Acquired |
| Drafted (by other) | ✗ Unavailable |
| Signed elsewhere | ✗ Signed with [Team] |
| Still available | ● Available |

#### Acceptance Criteria
- [ ] Create `PlayerShortlist.gd` and `ShortlistEntry.gd` models
- [ ] Shortlist persisted with GameSession (survives save/load)
- [ ] Categories: Draft Prospects, Trade Targets, FA Watch, General
- [ ] User can add notes and priority (1-5 stars) per entry
- [ ] "Add to Shortlist" button on all player views
- [ ] Shortlist panel accessible from main UI and draft war room
- [ ] Compare All: send entire category to PlayerComparisonTool
- [ ] Filter draft board to show only shortlisted players
- [ ] Status updates when player availability changes
- [ ] Optional notifications when watched player becomes available
- [ ] Draft prospects auto-archive after draft completes

#### Files to Create
- `scripts/core/models/PlayerShortlist.gd`
- `scripts/core/models/ShortlistEntry.gd`
- `scenes/ui/common/ShortlistPanel.gd`
- `scenes/ui/common/ShortlistPanel.tscn`

#### Files to Modify
- `scripts/core/models/GameSession.gd` - Add shortlist persistence
- `scenes/ui/common/PlayerComparisonTool.gd` - Add shortlist integration
- `scenes/ui/draft_day/DraftDayUI.gd` - Add shortlist panel/filter

#### Testing Requirements

**Unit Tests:**
- [ ] `add_player()` successfully adds player to shortlist with all required fields
- [ ] `add_player()` with duplicate player_id doesn't create duplicate entry (idempotent)
- [ ] `remove_player()` successfully removes player from shortlist
- [ ] `remove_player()` with non-existent player_id doesn't throw error (graceful)
- [ ] `get_by_category()` returns only entries matching specified category
- [ ] `get_by_category(DRAFT_PROSPECTS)` excludes TRADE_TARGETS and FA_WATCH
- [ ] `is_on_shortlist()` returns true for added player, false for others
- [ ] `to_dict()` serializes shortlist to dictionary with all entries
- [ ] ShortlistEntry stores `added_date` in parseable format
- [ ] ShortlistEntry `priority` clamped to [0, 5] range (0=none, 5=critical)
- [ ] Edge case: Empty shortlist `get_by_category()` returns empty array (not null)
- [ ] Edge case: Shortlist with 100+ entries performs well (no O(n²) operations)

**Integration Tests:**
- [ ] Shortlist persisted with GameSession (survives save/load cycle)
- [ ] Player added to shortlist via draft UI appears in shortlist panel
- [ ] Player added to shortlist via comparison tool shows ★ indicator
- [ ] Player removed from shortlist via shortlist panel removes ★ indicator everywhere
- [ ] Draft board filtered to show only shortlisted players excludes non-shortlisted
- [ ] "Compare All" in category sends all category players to comparison tool
- [ ] Shortlist integrates with PlayerComparisonTool (★ WATCH action available)
- [ ] Status updates when shortlisted player drafted (★ → ✓ Acquired or ✗ Unavailable)
- [ ] Status updates when shortlisted player signs with another team
- [ ] Draft prospects auto-archive after draft completes (moved to separate category or flagged)

**Determinism Tests:**
- [ ] Shortlist operations deterministic (add/remove produce consistent state)
- [ ] Shortlist doesn't use RNG (no random sorting or filtering)
- [ ] Shortlist state identical after save/load/save/load (no data loss)

**Performance Tests:**
- [ ] `add_player()` completes in < 5ms (simple array append + validation)
- [ ] `remove_player()` completes in < 10ms (filter operation)
- [ ] `get_by_category()` completes in < 20ms for 100-entry shortlist (filter)
- [ ] `is_on_shortlist()` completes in < 10ms for 100-entry shortlist (any() check)
- [ ] Shortlist panel renders in < 200ms with 50 entries (smooth UI)
- [ ] Filtering draft board by shortlist completes in < 100ms (fast response)

**UI/UX Tests:**
- [ ] Shortlist panel displays all entries with player names, positions, categories
- [ ] Category filter dropdown shows counts (Draft Prospects (3), Trade Targets (5))
- [ ] User can edit notes inline (click to edit, save on blur)
- [ ] User can adjust priority via star rating or slider (1-5 stars)
- [ ] [★ WATCH] button on player detail panel adds player to shortlist
- [ ] [★ WATCH] button disabled if player already on shortlist (or shows [★ REMOVE])
- [ ] ★ indicator appears on shortlisted players in all list views (draft board, roster, league)
- [ ] Compare All button sends all category players to comparison tool simultaneously
- [ ] Draft board "Show Shortlist Only" toggle filters board dynamically
- [ ] Status indicators update in real-time (player drafted → ✗ Unavailable)
- [ ] Optional notifications when shortlisted player becomes available
- [ ] Export shortlist to CSV/clipboard works correctly

**Regression Tests:**
- [ ] Shortlist doesn't affect draft simulation (tracking only, no gameplay impact)
- [ ] Game saves without shortlist still load correctly (backward compatibility)
- [ ] Shortlist with invalid player IDs (deleted players) doesn't crash (validation)
- [ ] Shortlist operations don't modify player data (read-only access)
- [ ] Multiple categories work independently (changes in one don't affect others)
- [ ] Shortlist accessible year-round (not just during draft season)

---

### DRAFT-010: Speculative AI Pick Pre-computation

**Priority:** MEDIUM
**Estimated Effort:** 4-6 hours
**Risk:** LOW
**Dependencies:** None (enhances existing InteractiveDraft)

#### Description

Pre-compute upcoming AI picks while the user is deliberating on their selection. When the user submits their pick, the next 5-10 AI picks execute nearly instantly because decisions were already computed. No threading required - single-threaded speculative computation during user think time.

#### Why No Threading?

Draft picks are **inherently sequential** - Team B's pick depends on Team A's result. Even with 32 threads, execution must serialize. Threading adds complexity without benefit:

| Approach | Complexity | Benefit |
|----------|------------|---------|
| Thread per team (32) | HIGH - mutex locks, race conditions | Minimal - still serializes |
| Single background thread | MEDIUM - sync overhead | Marginal - 50ms savings |
| **Speculative batch (no threads)** | **LOW** | **Same result, zero complexity** |

**Computation time with pre-computed boards:**
- Find best available: ~5ms per pick (O(n) board scan)
- 10 picks × 5ms = **50ms total** (imperceptible to user)

#### Target State
```gdscript
# In InteractiveDraft.gd

## Speculative picks computed while user deliberates
var _speculative_picks: Array[Dictionary] = []

func _on_user_turn_started(pick_number: int) -> void:
    # Pre-compute next 5-10 AI picks in single burst (~50ms)
    _speculative_picks = _precompute_speculative_picks(10)

func _precompute_speculative_picks(count: int) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    var simulated_drafted = _drafted_players.duplicate()  # Don't modify real state

    for i in range(count):
        var future_pick = _current_pick + 1 + i
        if future_pick > _total_picks:
            break

        var assignment = _get_pick_assignment(future_pick)
        if assignment.get("is_user_pick", false):
            break  # Stop at next user pick

        # Find best available using simulated state
        var team_id = assignment["team_id"]
        var board = _team_boards.get(team_id, [])

        for entry in board:
            var player_id = entry["player_id"]
            if not simulated_drafted.has(player_id):
                results.append({
                    "pick_number": future_pick,
                    "team_id": team_id,
                    "player_id": player_id
                })
                simulated_drafted[player_id] = true  # Mark in simulation
                break

    return results

func _on_user_pick_submitted(player_id: String) -> void:
    # 1. Execute user's actual pick
    _execute_pick(_current_pick, player_id)
    _current_pick += 1

    # 2. Instantly process speculative picks
    for spec in _speculative_picks:
        if _drafted_players.has(spec["player_id"]):
            # User "stole" this pick - recompute (still fast, board exists)
            var fallback = _find_best_available(spec["team_id"])
            _execute_pick(spec["pick_number"], fallback)
        else:
            # Speculative pick still valid - instant execution
            _execute_pick(spec["pick_number"], spec["player_id"])
        _current_pick += 1

    _speculative_picks.clear()

    # 3. Check if next pick is user's turn or continue AI
    _check_next_pick()
```

#### User Experience Flow

```
┌─────────────────────────────────────────────────────────────┐
│  PICK 15: Your Turn                                         │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  [Background: Pre-computing picks 16-25 (~50ms)]            │
│                                                             │
│  User browses players, compares, deliberates...             │
│  (Takes 10-60 seconds typically)                            │
│                                                             │
│  User clicks [DRAFT] on J. Williams                         │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Instant execution:                                         │
│    Pick 15: You select J. Williams         ✓ (0ms)          │
│    Pick 16: Patriots select M. Harrison    ✓ (cached)       │
│    Pick 17: Saints select D. Carter        ✓ (cached)       │
│    Pick 18: Bengals select T. Young        ✓ (cached)       │
│    ...                                                      │
│    Pick 24: Your Turn (next user pick)                      │
│                                                             │
│  Total time: <100ms (feels instant)                         │
└─────────────────────────────────────────────────────────────┘
```

#### Edge Cases

| Scenario | Handling |
|----------|----------|
| User picks same player as speculative | Recompute that team's pick (fallback to next on board) |
| User picks player 3 teams wanted | Recompute all affected teams (still <50ms) |
| Trade occurs during user turn | Clear speculative cache, recompute after trade |
| User's next pick is immediate (back-to-back) | Skip speculation, just wait for user |
| Draft ends during speculative range | Stop at final pick |

#### Acceptance Criteria
- [ ] Pre-compute 5-10 AI picks when user's turn starts
- [ ] Speculative picks use duplicated state (don't modify real draft state)
- [ ] User pick invalidates affected speculative picks (recompute fallback)
- [ ] AI picks after user submission execute in <100ms total
- [ ] No threading - single-threaded speculative batch
- [ ] Clear speculative cache on trade events
- [ ] Works correctly with back-to-back user picks

#### Files to Modify
- `scripts/world/InteractiveDraft.gd` - Add speculative computation

#### Testing Requirements

**Unit Tests:**
- [ ] `_precompute_speculative_picks()` returns correct count of picks
- [ ] Speculative computation doesn't modify `_drafted_players` (uses duplicate)
- [ ] Speculative picks stop at next user pick
- [ ] Speculative picks stop at end of draft
- [ ] Empty speculative array when user has back-to-back picks

**Integration Tests:**
- [ ] Full draft completes correctly with speculation enabled
- [ ] User picking speculative target triggers correct fallback
- [ ] Multiple teams wanting same player handled correctly
- [ ] Trade during user turn clears speculative cache
- [ ] Speculative picks respect trade-modified pick assignments

**Determinism Tests:**
- [ ] Same seed + same user picks = identical draft results (speculation doesn't affect outcome)
- [ ] Speculative computation is deterministic (same inputs = same speculative picks)

**Performance Tests:**
- [ ] Speculative computation for 10 picks completes in <50ms
- [ ] Post-user-pick execution completes in <100ms
- [ ] No frame drops during speculative computation
- [ ] Memory usage stable (no leaks from repeated speculation)

**Regression Tests:**
- [ ] Draft works correctly with speculation disabled (fallback path)
- [ ] Existing draft tests pass unchanged
- [ ] AI pick quality unchanged (same players selected, just faster)

---

### DRAFT-011: Scheme Fit Analysis

**Priority:** HIGH
**Estimated Effort:** 8-10 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Analyze how well a prospect fits your team's offensive/defensive scheme. A zone-blocking offense values different OL traits than a power scheme. A Cover-3 defense needs different CB skills than a man-heavy scheme. This helps both user and AI make smarter draft decisions.

#### Scheme Types

**Offensive Schemes:**
| Scheme | Key Traits | Position Priorities |
|--------|------------|---------------------|
| West Coast | Short accuracy, route running, YAC | Slot WR, Pass-catching RB |
| Air Raid | Deep accuracy, arm strength | Outside WR, Pass-pro OL |
| Power Run | Run blocking, physicality | FB, Guard, TE |
| Zone Run | Athleticism, reach blocks | Center, Tackle, athletic RB |
| Spread RPO | Mobility, quick decisions | Dual-threat QB, versatile WR |

**Defensive Schemes:**
| Scheme | Key Traits | Position Priorities |
|--------|------------|---------------------|
| 4-3 Under | Run-stuffing DT, coverage LB | 3-tech DT, WILL LB |
| 3-4 | Versatile OLB, nose tackle | Edge rusher, NT |
| Cover-3 | Range, ball skills | FS, outside CB |
| Cover-2 | Zone awareness, tackling | SS, LB coverage |
| Man/Press | Press technique, speed | CB, slot defender |

#### Target State
```gdscript
# scripts/world/SchemeFitAnalyzer.gd (NEW FILE)
extends RefCounted
class_name SchemeFitAnalyzer

func calculate_scheme_fit(player: Dictionary, team: Dictionary) -> Dictionary:
    var offense_scheme = team.get("offensive_scheme", "balanced")
    var defense_scheme = team.get("defensive_scheme", "4-3")

    var fit_score = _evaluate_fit(player, offense_scheme, defense_scheme)
    var fit_grade = _score_to_grade(fit_score)  # A+ to F

    return {
        "score": fit_score,           # 0-100
        "grade": fit_grade,           # "A+", "B-", etc.
        "scheme": _get_relevant_scheme(player, offense_scheme, defense_scheme),
        "strengths": _identify_scheme_strengths(player, fit_score),
        "concerns": _identify_scheme_concerns(player, fit_score),
        "projection": _project_role_in_scheme(player, team),
        "comparison": _find_scheme_comparison(player, team)  # "Fits like Tyreek Hill in KC"
    }

func get_scheme_priorities(scheme: String, position: String) -> Array[String]:
    # Return weighted stats for this scheme/position combo
    # E.g., Zone Run + OT = ["athleticism", "reach_blocking", "footwork"]
```

#### UI Integration
```
╔══════════════════════════════════════════════════════════════════════╗
║  SCHEME FIT: J. Williams (QB) → Your Team (West Coast)               ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Overall Fit: A-  (88/100)                                          ║
║  ══════════════════════════════════════════════════                 ║
║                                                                      ║
║  ✓ STRENGTHS                    ✗ CONCERNS                          ║
║  ─────────────────              ─────────────────                    ║
║  • Elite short accuracy (94)    • Limited deep ball (78)            ║
║  • Quick release fits timing    • May struggle on 9-routes          ║
║  • Great anticipation           • Arm strength adequate, not elite  ║
║                                                                      ║
║  PROJECTED ROLE: Day 1 starter, franchise QB                        ║
║  COMP: "Fits like Joe Montana in Walsh's system"                    ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `SchemeFitAnalyzer.gd` with fit calculation logic
- [ ] Define scheme-specific trait weights for all positions
- [ ] Scheme fit score (0-100) and grade (A+ to F) per player
- [ ] Identify strengths/concerns specific to scheme fit
- [ ] Project player role in team's system
- [ ] Historical player comparison for scheme fit
- [ ] AI teams use scheme fit in draft evaluation (weighted factor)
- [ ] Scheme fit displayed in player comparison tool
- [ ] Scheme fit displayed in scouting reports

#### Testing Requirements

**Unit Tests:**
- [ ] Fit score calculation correct for each scheme type
- [ ] Zone-blocking OL valued differently than power-blocking OL
- [ ] Man-coverage CB valued differently in Cover-3 vs Man schemes
- [ ] Fit grade boundaries correct (90+ = A, 80-89 = B, etc.)

**Integration Tests:**
- [ ] AI draft boards influenced by scheme fit
- [ ] Scheme fit displays correctly in comparison tool
- [ ] Scheme fit persists in scouting reports

**Determinism Tests:**
- [ ] Same player + same scheme = same fit score (no RNG in calculation)

---

### DRAFT-012: Trade Value Calculator UI

**Priority:** MEDIUM
**Estimated Effort:** 4-6 hours
**Risk:** LOW
**Dependencies:** DRAFT-001 (uses pick value chart)

#### Description

Expose the draft pick value chart to users with an interactive calculator. Helps users understand if a proposed trade is fair before accepting/proposing. Shows value differential and historical trade comparisons.

#### Pick Value Chart (Traditional)
```
Pick 1:  3000    Pick 17:  950    Pick 33:  580
Pick 2:  2600    Pick 18:  900    Pick 40:  500
Pick 3:  2200    Pick 19:  875    Pick 50:  400
Pick 4:  1800    Pick 20:  850    Pick 64:  300
Pick 5:  1700    Pick 21:  800    Pick 100: 150
...
```

#### Target State
```gdscript
# Enhancement to DraftTradeEngine.gd

func get_trade_analysis(offer: Dictionary) -> Dictionary:
    var giving_value = _sum_pick_values(offer["giving"])
    var receiving_value = _sum_pick_values(offer["receiving"])
    var differential = receiving_value - giving_value

    return {
        "giving_total": giving_value,
        "receiving_total": receiving_value,
        "differential": differential,
        "verdict": _get_verdict(differential),  # "Fair", "You Win", "You Lose"
        "historical_comp": _find_similar_trade(offer),
        "recommendation": _get_recommendation(differential, team_needs)
    }
```

#### UI: Trade Calculator
```
╔══════════════════════════════════════════════════════════════════════╗
║  TRADE VALUE CALCULATOR                                              ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  YOU GIVE                          YOU RECEIVE                       ║
║  ──────────────────                ──────────────────                ║
║  [Pick 8 - 1400 pts    ]  ←→      [Pick 15 - 1050 pts   ]           ║
║  [                     ]          [Pick 47 - 430 pts    ]           ║
║  [+ Add Pick]                     [Pick 112 - 90 pts    ]           ║
║                                   [+ Add Pick]                       ║
║  ──────────────────                ──────────────────                ║
║  TOTAL: 1400 pts                   TOTAL: 1570 pts                   ║
║                                                                      ║
║  ════════════════════════════════════════════════════════════════   ║
║  VERDICT: GOOD TRADE (+170 pts in your favor)                       ║
║                                                                      ║
║  Similar Trade: 2034 - Bills traded #9 for #14, #46, #108           ║
║                                                                      ║
║  [Propose Trade]  [Reset]  [Save for Later]                         ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Interactive pick value calculator UI
- [ ] Add/remove picks from either side
- [ ] Real-time value calculation as picks added
- [ ] Verdict: Fair (±5%), You Win (>5%), You Lose (<-5%)
- [ ] Historical trade comparison from past drafts
- [ ] "Propose Trade" button sends to DraftTradeEngine
- [ ] AI teams use same value chart for consistency
- [ ] Future picks discounted (2026 1st worth less than 2025 1st)

#### Testing Requirements

**Unit Tests:**
- [ ] Pick value chart values correct for all 262 picks
- [ ] Future pick discount calculation correct (10% per year?)
- [ ] Verdict thresholds correct (±5% = fair)

**UI Tests:**
- [ ] Add/remove picks updates totals correctly
- [ ] Propose button disabled when trade is empty
- [ ] Historical comparison displays relevant trade

---

### DRAFT-013: Rookie Wage Scale Display

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Display the rookie wage scale so users understand the financial implications of each draft pick. Higher picks cost more cap space. Helps with draft strategy - sometimes trading down saves cap room for free agency.

#### Rookie Wage Scale (Approximate)
```
Pick 1:  $40M total / 4 years = $10M/yr cap hit
Pick 5:  $28M total / 4 years = $7M/yr cap hit
Pick 10: $20M total / 4 years = $5M/yr cap hit
Pick 32: $12M total / 4 years = $3M/yr cap hit
Pick 64: $6M total / 4 years = $1.5M/yr cap hit
...
Round 7: $4M total / 4 years = $1M/yr cap hit
```

#### Target State
```gdscript
# scripts/core/contracts/RookieWageScale.gd (NEW FILE)
extends RefCounted
class_name RookieWageScale

func get_contract_for_pick(pick_number: int, year: int) -> Dictionary:
    var slot_value = _get_slot_value(pick_number, year)
    return {
        "pick_number": pick_number,
        "total_value": slot_value,
        "years": 4,
        "annual_cap_hit": slot_value / 4.0,
        "signing_bonus": slot_value * 0.6,  # ~60% signing bonus
        "fifth_year_option": pick_number <= 32,  # 1st rounders only
        "fifth_year_value": _get_fifth_year_option_value(pick_number) if pick_number <= 32 else 0
    }
```

#### UI Integration
```
╔══════════════════════════════════════════════════════════════════════╗
║  PICK #8 - ROOKIE CONTRACT                                           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Total Value:     $24.2M over 4 years                               ║
║  Annual Cap Hit:  $6.05M average                                    ║
║  Signing Bonus:   $14.5M (prorated over 4 years)                    ║
║                                                                      ║
║  Year 1: $5.8M    Year 3: $6.1M                                     ║
║  Year 2: $5.9M    Year 4: $6.4M                                     ║
║                                                                      ║
║  ✓ 5th Year Option Available (est. $18M if exercised)               ║
║                                                                      ║
║  CONTEXT: This pick costs $2.1M/yr MORE than Pick #15               ║
║           Trading down could save $8.4M over 4 years                ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `RookieWageScale.gd` with slot values
- [ ] Display contract details for any pick number
- [ ] Show 5th year option value for 1st round picks
- [ ] Compare cost to other picks (context for trade decisions)
- [ ] Integrate with trade calculator (show cap implications)
- [ ] Display in draft UI when hovering/selecting picks

#### Testing Requirements

**Unit Tests:**
- [ ] Slot values follow realistic NFL scale
- [ ] 5th year option only for picks 1-32
- [ ] Cap hit calculation correct

---

### DRAFT-014: Draft Day Rumors & Intel

**Priority:** MEDIUM
**Estimated Effort:** 6-8 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Generate dynamic draft day rumors and intel to add immersion. "The Patriots are reportedly high on J. Williams", "Sources say the Giants are shopping pick #7", "BREAKING: Medical concern surfaces for D. Carter". Mix of accurate intel, misleading rumors, and smoke screens.

#### Rumor Types

| Type | Example | Accuracy |
|------|---------|----------|
| Team Interest | "Ravens showing strong interest in CB Smith" | 70% accurate |
| Trade Buzz | "Multiple teams calling about pick #12" | 50% accurate |
| Medical Flag | "Concern about Jones' knee surfaces" | 90% accurate |
| Smoke Screen | "Team X 'loves' Player Y" (actually want Z) | 20% accurate |
| Surprise Pick | "Don't be shocked if Team X goes off board" | 40% accurate |
| Position Run | "Teams in 10-15 range targeting WRs heavily" | 80% accurate |

#### Target State
```gdscript
# scripts/world/DraftRumorMill.gd (NEW FILE)
extends RefCounted
class_name DraftRumorMill

signal rumor_generated(rumor: Dictionary)

func generate_pre_draft_rumors(world_state: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
    var rumors: Array[Dictionary] = []
    for i in range(count):
        var rumor_type = _pick_rumor_type(rng)
        var rumor = _generate_rumor(rumor_type, world_state, rng)
        rumors.append(rumor)
    return rumors

func generate_live_rumor(world_state: Dictionary, current_pick: int, rng: RandomNumberGenerator) -> Dictionary:
    # Generate rumor based on current draft state
    # More accurate as draft progresses (less time to deceive)
    return {
        "type": "trade_buzz",
        "text": "BREAKING: Broncos and Dolphins discussing swap at #%d" % current_pick,
        "accuracy": 0.6,  # 60% chance this is real
        "source": "League Source",
        "timestamp": _get_draft_time(current_pick),
        "is_accurate": rng.randf() < 0.6  # Actual truth for simulation
    }

func _generate_smoke_screen(team: Dictionary, actual_target: Dictionary, decoy: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    return {
        "type": "smoke_screen",
        "text": "%s 'absolutely love' %s, could be target at #%d" % [team["name"], decoy["name"], team["pick"]],
        "accuracy": 0.2,  # Intentionally misleading
        "source": "Team Source",
        "actual_target": actual_target["id"],  # Who they really want
        "is_accurate": false
    }
```

#### Rumor Feed UI
```
╔══════════════════════════════════════════════════════════════════════╗
║  📰 DRAFT CENTRAL - LIVE RUMORS                          [Settings]  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  🔴 LIVE  12:34 PM                                                   ║
║  ──────────────────────────────────────────────────────────────────  ║
║  [12:34] BREAKING: Multiple teams calling Jaguars about #2 pick     ║
║          Source: League Insider  │  ⚡ High confidence              ║
║                                                                      ║
║  [12:31] Patriots "extremely high" on QB Marcus Williams            ║
║          Source: Team Source  │  ⚠️ Could be smokescreen            ║
║                                                                      ║
║  [12:28] Medical: Concerns surface about T. Johnson's shoulder      ║
║          Source: Medical Staff  │  ⚡ Verified                       ║
║                                                                      ║
║  [12:25] Buzz: 5-6 teams targeting WR in top 15                     ║
║          Source: Scout Network  │  📊 Moderate confidence           ║
║                                                                      ║
║  [12:20] Giants may go "off the board" - surprise pick brewing      ║
║          Source: Anonymous  │  ❓ Unverified                        ║
║                                                                      ║
║  ──────────────────────────────────────────────────────────────────  ║
║  💡 TIP: Rumors marked "Team Source" may be intentional misdirection║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Post-Draft Rumor Accuracy Report
```
╔══════════════════════════════════════════════════════════════════════╗
║  📊 RUMOR ACCURACY REPORT - 2035 Draft                               ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Total Rumors: 47      Accurate: 28 (60%)     Smoke Screens: 8      ║
║                                                                      ║
║  BEST INTEL:                                                         ║
║  ✓ "Patriots targeting Williams at #8" - CORRECT                    ║
║  ✓ "Medical concern for Johnson" - Led to 2-round drop              ║
║                                                                      ║
║  WORST MISDIRECTION:                                                 ║
║  ✗ "Giants love QB Carter" - Actually took DE Smith                 ║
║  ✗ "Browns shopping #4" - Never made a call                         ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `DraftRumorMill.gd` with rumor generation
- [ ] Pre-draft rumors generated during draft week
- [ ] Live rumors during draft based on current state
- [ ] Smoke screen generation (teams mislead about intentions)
- [ ] Accuracy varies by source type (Medical > Scout > Team > Anonymous)
- [ ] Rumor feed UI with confidence indicators
- [ ] Post-draft accuracy report reveals truth
- [ ] AI teams generate smoke screens for players they want
- [ ] User can enable/disable rumor feed (preference)

#### Testing Requirements

**Unit Tests:**
- [ ] Rumor type distribution matches expected frequencies
- [ ] Smoke screens have low accuracy (10-30%)
- [ ] Medical rumors have high accuracy (80-95%)
- [ ] Rumor text generation produces valid strings

**Integration Tests:**
- [ ] Rumors reference actual players/teams in draft
- [ ] Live rumors update as draft progresses
- [ ] Smoke screens align with team's actual targets

**Determinism Tests:**
- [ ] Same seed produces same rumor sequence

---

### DRAFT-015: BPA vs Need Board Toggle

**Priority:** MEDIUM
**Estimated Effort:** 3-4 hours
**Risk:** LOW
**Dependencies:** DRAFT-005 (uses draft board)

#### Description

Allow users to toggle their draft board view between "Best Player Available" (pure talent ranking) and "Team Need" (prioritized by positional need). Helps users evaluate draft strategy options.

#### Target State
```gdscript
# Enhancement to DraftWarRoomUI.gd

enum BoardMode { BPA, NEED, HYBRID, SCHEME_FIT }

func _sort_board(mode: BoardMode) -> void:
    match mode:
        BoardMode.BPA:
            _draft_board.sort_custom(_sort_by_talent)
        BoardMode.NEED:
            _draft_board.sort_custom(_sort_by_need)
        BoardMode.HYBRID:
            _draft_board.sort_custom(_sort_by_weighted_hybrid)
        BoardMode.SCHEME_FIT:
            _draft_board.sort_custom(_sort_by_scheme_fit)
```

#### UI: Board View Toggle
```
╔══════════════════════════════════════════════════════════════════════╗
║  MY DRAFT BOARD          [BPA ▼] [Need] [Hybrid] [Scheme Fit]       ║
╠══════════════════════════════════════════════════════════════════════╣
║  RK  PLAYER              POS   TALENT  NEED   FIT   YOUR RANK       ║
║  ─────────────────────────────────────────────────────────────────  ║
║   1  J. Williams         QB      98     --    A-      ↑ 1           ║
║   2  M. Harrison         QB      95     --    B+      ↓ 4           ║
║   3  T. Smith            OT      94    ★★★    A       = 3           ║
║   4  D. Johnson          EDGE    93    ★★     A+      ↑ 2           ║
║   5  K. Brown            CB      92    ★★★★   B       = 5           ║
║                                                                      ║
║  ★ = Need level (★★★★ = Critical, ★ = Low)                          ║
║  Your Rank = Your custom ranking vs calculated                       ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Toggle between BPA, Need, Hybrid, Scheme Fit views
- [ ] BPA: Pure talent/overall rating sort
- [ ] Need: Prioritize positions team lacks depth
- [ ] Hybrid: Weighted combination (configurable)
- [ ] Scheme Fit: Sort by fit score with user's team
- [ ] Show need level indicators (★ system)
- [ ] User can set custom rankings (drag-drop reorder)
- [ ] Custom rankings persist across sessions

#### Testing Requirements

**Unit Tests:**
- [ ] BPA sort matches pure talent order
- [ ] Need sort prioritizes critical needs
- [ ] Hybrid weighting configurable and correct

---

### DRAFT-016: Historical Draft Review

**Priority:** LOW
**Estimated Effort:** 4-6 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Review past drafts and see how players have developed. "The 2033 draft class produced 4 Pro Bowlers" - helps users learn from history and adds immersion.

#### Target State
```gdscript
# scripts/world/DraftHistoryAnalyzer.gd (NEW FILE)
extends RefCounted
class_name DraftHistoryAnalyzer

func get_draft_class_summary(year: int, world_state: Dictionary) -> Dictionary:
    var draft_history = world_state.get("draft_history", {}).get(str(year), {})
    var players_now = _get_current_player_status(draft_history, world_state)

    return {
        "year": year,
        "total_picks": draft_history.get("picks", []).size(),
        "pro_bowlers": _count_pro_bowlers(players_now),
        "all_pros": _count_all_pros(players_now),
        "busts": _identify_busts(players_now),
        "steals": _identify_steals(players_now),
        "best_pick": _find_best_pick(players_now),
        "worst_pick": _find_worst_pick(players_now),
        "picks_by_round": _get_picks_by_round(draft_history)
    }
```

#### UI: Historical Draft View
```
╔══════════════════════════════════════════════════════════════════════╗
║  📜 DRAFT HISTORY: 2033 CLASS (3 Years Later)                       ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  CLASS OVERVIEW                                                      ║
║  ─────────────────────────────────────────────────────────────────  ║
║  Total Picks: 262    Pro Bowlers: 12    All-Pro: 4    Busts: 18     ║
║                                                                      ║
║  🏆 BEST PICK: Marcus Williams (QB, Pick #3 → 2x Pro Bowl, 1x MVP)  ║
║  💔 BIGGEST BUST: T. Johnson (DE, Pick #7 → Out of league)          ║
║  💎 STEAL: K. Davis (WR, Pick #87 → Pro Bowler, 1200 yds/yr)        ║
║                                                                      ║
║  ROUND BREAKDOWN                                                     ║
║  ─────────────────────────────────────────────────────────────────  ║
║  R1: 8 starters, 3 Pro Bowls   │   R5: 4 starters, 0 Pro Bowls     ║
║  R2: 6 starters, 2 Pro Bowls   │   R6: 2 starters, 0 Pro Bowls     ║
║  R3: 5 starters, 1 Pro Bowl    │   R7: 1 starter,  1 Pro Bowl      ║
║  R4: 4 starters, 1 Pro Bowl    │                                    ║
║                                                                      ║
║  [View Full Draft Board]  [Compare to 2034]  [Export]               ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `DraftHistoryAnalyzer.gd`
- [ ] Track all draft picks in world_state history
- [ ] Calculate Pro Bowler/All-Pro counts per class
- [ ] Identify busts (high pick, poor career)
- [ ] Identify steals (late pick, great career)
- [ ] Compare draft classes across years
- [ ] View any player's career from draft history
- [ ] Available from main menu (not just during draft)

#### Testing Requirements

**Unit Tests:**
- [ ] Pro Bowler counting correct
- [ ] Bust identification (top 50 pick, <2 years starter)
- [ ] Steal identification (pick 100+, Pro Bowl)

---

### DRAFT-017: Private Workouts & Team Visits

**Priority:** LOW
**Estimated Effort:** 5-7 hours
**Risk:** LOW
**Dependencies:** None

#### Description

Schedule private workouts and team facility visits with prospects during the pre-draft process. Provides additional intel beyond combine - can reveal character, scheme fit, and hidden traits. Limited to 30 visits per team (NFL rule).

#### Target State
```gdscript
# scripts/world/PrivateWorkoutSystem.gd (NEW FILE)
extends RefCounted
class_name PrivateWorkoutSystem

const MAX_VISITS = 30  # NFL rule

func schedule_visit(team_id: String, player_id: String, world_state: Dictionary) -> Dictionary:
    var visits = _get_team_visits(team_id, world_state)
    if visits.size() >= MAX_VISITS:
        return {"success": false, "reason": "Visit limit reached (30)"}

    # Visit reveals additional information
    return {
        "success": true,
        "intel": _generate_visit_intel(player_id, team_id, world_state)
    }

func _generate_visit_intel(player_id: String, team_id: String, world_state: Dictionary) -> Dictionary:
    var player = _get_player(player_id, world_state)
    return {
        "character_grade": _evaluate_character_in_person(player),  # More accurate than interview
        "scheme_fit_detail": _detailed_scheme_evaluation(player, team_id),
        "hidden_trait_reveal": _maybe_reveal_hidden_trait(player),  # 30% chance
        "medical_detail": _private_medical_evaluation(player),
        "personality_notes": _generate_personality_notes(player),
        "coachability": _evaluate_coachability(player)
    }
```

#### UI: Pre-Draft Visit Scheduler
```
╔══════════════════════════════════════════════════════════════════════╗
║  🏟️ PRIVATE WORKOUTS & VISITS                    Used: 12/30        ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  SCHEDULED VISITS                                                    ║
║  ─────────────────────────────────────────────────────────────────  ║
║  J. Williams (QB) - Mar 15  │  Intel: ✓ Character A+, Scheme A-    ║
║  T. Smith (OT) - Mar 18     │  Intel: ✓ Medical cleared, Coachable ║
║  D. Johnson (EDGE) - Mar 20 │  Intel: ⏳ Pending                     ║
║                                                                      ║
║  AVAILABLE PROSPECTS                    [Filter: Position ▼]        ║
║  ─────────────────────────────────────────────────────────────────  ║
║  M. Harrison (QB, Ohio St)          [Schedule Visit]                ║
║  K. Brown (CB, Alabama)             [Schedule Visit]                ║
║  R. Davis (WR, Georgia)             [Schedule Visit]                ║
║                                                                      ║
║  💡 Visits reveal character, scheme fit, and may expose hidden traits║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Visit Intel Report
```
╔══════════════════════════════════════════════════════════════════════╗
║  📋 PRIVATE VISIT REPORT: J. Williams (QB)                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  CHARACTER EVALUATION: A+                                           ║
║  "Extremely mature, film junkie, first one in last one out"         ║
║                                                                      ║
║  SCHEME FIT (West Coast): A-                                        ║
║  "Quick release, excellent timing, may need work on deep ball"      ║
║                                                                      ║
║  🔓 HIDDEN TRAIT REVEALED: "Clutch Performer"                       ║
║  "Thrives in pressure situations, ice in his veins"                 ║
║                                                                      ║
║  MEDICAL: All clear                                                 ║
║  "No concerns, passed all physicals"                                ║
║                                                                      ║
║  COACHABILITY: High                                                 ║
║  "Receptive to feedback, asked great questions about our system"    ║
║                                                                      ║
║  SCOUT RECOMMENDATION: Strong fit, prioritize in draft              ║
╚══════════════════════════════════════════════════════════════════════╝
```

#### Acceptance Criteria
- [ ] Create `PrivateWorkoutSystem.gd`
- [ ] Limit 30 visits per team (NFL rule)
- [ ] Visits provide more accurate character/medical intel
- [ ] 30% chance to reveal hidden trait during visit
- [ ] Detailed scheme fit evaluation from in-person workout
- [ ] AI teams also schedule visits (influences their boards)
- [ ] Visit intel persists and displays in scouting reports
- [ ] Pre-draft phase for scheduling visits (before combine)

#### Testing Requirements

**Unit Tests:**
- [ ] Visit limit enforced (31st visit rejected)
- [ ] Hidden trait reveal rate ~30%
- [ ] Intel accuracy higher than combine-only

**Integration Tests:**
- [ ] AI teams schedule visits and use intel in boards
- [ ] Visit intel appears in scouting reports
- [ ] Visits occur during correct pre-draft phase

---

## Draft System Dependency Graph

```
DRAFT-001 (Trading) ─────────────────────┐
                                         │
DRAFT-002 (Underclassmen) ───────────────┤
                                         │
DRAFT-003 (Red Flags) ───────────────────┤
                                         │
DRAFT-004 (Positional Runs) ←── DRAFT-001│
                                         │
DRAFT-005 (Mock Drafts) ─────────────────┤
                                         │
DRAFT-006 (UDFA) ────────────────────────┤
                                         │
DRAFT-007 (Grades) ──────────────────────┤
                                         │
DRAFT-009 (Shortlist) ───────────────────┤
                                         │
DRAFT-010 (Speculative Picks) ───────────┤
                                         │
DRAFT-011 (Scheme Fit) ──────────────────┤
                                         │
DRAFT-012 (Trade Calculator) ←── DRAFT-001
                                         │
DRAFT-013 (Rookie Wages) ────────────────┤
                                         │
DRAFT-014 (Rumors) ──────────────────────┤
                                         │
DRAFT-015 (BPA vs Need) ←── DRAFT-005    │
                                         │
DRAFT-016 (Draft History) ───────────────┤
                                         │
DRAFT-017 (Private Workouts) ────────────┘

DRAFT-008 (Conditional) ←── DRAFT-001 [Post-1.0]
```

## Draft System Summary

| Ticket | Priority | Hours | Risk | Status |
|--------|----------|-------|------|--------|
| DRAFT-001: Draft Day Trading | CRITICAL | 12-16 | MEDIUM | PLANNED |
| DRAFT-002: Underclassman Entry | HIGH | 8-10 | MEDIUM | PLANNED |
| DRAFT-003: Medical/Character Red Flags | HIGH | 6-8 | LOW | PLANNED |
| DRAFT-004: Positional Runs | MEDIUM | 6-8 | LOW | PLANNED |
| DRAFT-005: Mock Drafts/Scouting/Comparison | MEDIUM | 10-12 | LOW | PLANNED |
| DRAFT-006: UDFA Bidding | LOW | 4-6 | LOW | PLANNED |
| DRAFT-007: Draft Grades | LOW | 3-4 | LOW | PLANNED |
| DRAFT-008: Conditional Picks | VERY LOW | 8-10 | MEDIUM | POST-1.0 |
| DRAFT-009: Player Shortlist/Watchlist | MEDIUM | 6-8 | LOW | PLANNED |
| DRAFT-010: Speculative AI Pre-computation | MEDIUM | 4-6 | LOW | PLANNED |
| DRAFT-011: Scheme Fit Analysis | HIGH | 8-10 | LOW | PLANNED |
| DRAFT-012: Trade Value Calculator | MEDIUM | 4-6 | LOW | PLANNED |
| DRAFT-013: Rookie Wage Scale | MEDIUM | 3-4 | LOW | PLANNED |
| DRAFT-014: Draft Day Rumors | MEDIUM | 6-8 | LOW | PLANNED |
| DRAFT-015: BPA vs Need Toggle | MEDIUM | 3-4 | LOW | PLANNED |
| DRAFT-016: Historical Draft Review | LOW | 4-6 | LOW | PLANNED |
| DRAFT-017: Private Workouts | LOW | 5-7 | LOW | PLANNED |
| **Total** | - | **102-133** | - | - |

```
DRAFT-001 (Trading) ─────────────────────┐
                                         │
DRAFT-002 (Underclassmen) ───────────────┤
                                         │
DRAFT-003 (Red Flags) ───────────────────┤
                                         │
DRAFT-004 (Positional Runs) ←── DRAFT-001│
                                         │
DRAFT-005 (Mock Drafts) ─────────────────┤
                                         │
DRAFT-006 (UDFA) ────────────────────────┤
                                         │
DRAFT-007 (Grades) ──────────────────────┤
                                         │
DRAFT-009 (Shortlist) ───────────────────┤
                                         │
DRAFT-010 (Speculative Picks) ───────────┘

DRAFT-008 (Conditional) ←── DRAFT-001 [Post-1.0]
```

## Draft System Summary

| Ticket | Priority | Hours | Risk | Status |
|--------|----------|-------|------|--------|
| DRAFT-001: Draft Day Trading | CRITICAL | 12-16 | MEDIUM | PLANNED |
| DRAFT-002: Underclassman Entry | HIGH | 8-10 | MEDIUM | PLANNED |
| DRAFT-003: Medical/Character Red Flags | HIGH | 6-8 | LOW | PLANNED |
| DRAFT-004: Positional Runs | MEDIUM | 6-8 | LOW | PLANNED |
| DRAFT-005: Mock Drafts/Scouting/Comparison | MEDIUM | 10-12 | LOW | PLANNED |
| DRAFT-006: UDFA Bidding | LOW | 4-6 | LOW | PLANNED |
| DRAFT-007: Draft Grades | LOW | 3-4 | LOW | PLANNED |
| DRAFT-008: Conditional Picks | VERY LOW | 8-10 | MEDIUM | POST-1.0 |
| DRAFT-009: Player Shortlist/Watchlist | MEDIUM | 6-8 | LOW | PLANNED |
| DRAFT-010: Speculative AI Pre-computation | MEDIUM | 4-6 | LOW | PLANNED |
| **Total** | - | **67-88** | - | - |

### Recommended Implementation Order

**MVP Realism** (must-have for believable drafts):
1. DRAFT-001: Draft Day Trading
2. DRAFT-003: Medical/Character Red Flags
3. DRAFT-002: Underclassman Entry System

**Complete Realism** (polished draft experience):
4. DRAFT-004: Positional Runs
5. DRAFT-005: Mock Drafts/Scouting Reports
6. DRAFT-006: UDFA Bidding

**Maximum Polish** (nice-to-have):
7. DRAFT-007: Draft Grades
8. DRAFT-008: Conditional Picks (post-1.0)

---

## Summary

| Phase | Tickets | Estimated Hours | Risk |
|-------|---------|-----------------|------|
| Phase 1: Foundation | ARCH-001 to ARCH-007 | 18-25 hours | LOW |
| Phase 2: Decomposition | ARCH-008 to ARCH-016 | 24-32 hours | MEDIUM |
| Phase 3: Persistence | ARCH-017 to ARCH-022 | 28-38 hours | MEDIUM |
| Phase 4: Testing Infrastructure | ARCH-026 to ARCH-027 | 97-114 hours | MEDIUM |
| Phase 5: Draft System Realism | DRAFT-001 to DRAFT-017 | 102-133 hours | LOW-MEDIUM |
| Documentation | ARCH-023 to ARCH-025 | 6-9 hours | NONE |
| **Total** | **44 tickets** | **275-351 hours** | - |

> **Note:** Phase 4 (Testing Infrastructure) can run **in parallel** with Phases 1-3 as it has no dependencies on model or persistence changes. However, bulk migration (Phase 4.2) should wait for Phase 1 model renames to stabilize to avoid merge conflicts.

### Recommended Execution Order

1. **Start with ARCH-001 and ARCH-002** (class renames) - Quick wins, unblock other work
2. **Then ARCH-003** (Person base) - Foundation for hierarchy
3. **Then ARCH-004, ARCH-005, ARCH-006** (Contract, Injuries, Stage) - Type safety
4. **ARCH-017 in parallel** - Persistence abstraction can start independently
5. **Phase 2 as needed** - Decomposition based on pain points
6. **Phase 3 after Phase 1** - Database work builds on clean models

### Success Metrics

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
