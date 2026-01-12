# Task F4: Deep Copy Reduction

**Track**: Performance Optimization (Track F)
**Dependencies**: F3 (Scout Caching)
**Status**: Not started
**Estimated Effort**: 1-2 days
**Priority**: P2 - Medium Impact

## Problem Statement

The codebase extensively uses `player.duplicate(true)` for safety and immutability. While architecturally sound, this creates significant overhead:

- Each deep copy allocates new memory for all nested dictionaries/arrays
- Player dictionaries contain ~50+ fields including nested `stats`, `potential`, `physicals`
- Copies happen multiple times per player per simulation step

## Hot Spots Identified

### 1. PlayerLifecycle._advance_player_one_year

```gdscript
static func _advance_player_one_year(...) -> Dictionary:
    var p := player.duplicate(true)  # Full deep copy
    # ... modifications
    return {"player": p, ...}
```

Called for every player in every season phase.

### 2. ScoutRuntime._perceive / _perceive_potential

```gdscript
static func _perceive(player, ...) -> Dictionary:
    var p2 := player.duplicate(true)  # Deep copy for perception
    # ... stat modifications
    return p2
```

Called 2x per scout evaluation.

### 3. Season Development Context

```gdscript
func _apply_development_context(players, ...) -> Array:
    for i in range(players.size()):
        var next := p.duplicate(true)  # Deep copy
        next["development_context"] = context
        updated[i] = next
```

Called in HighSchoolSeason, CollegeSeason, NflSeason.

### 4. Roster Updates

```gdscript
func _initialize_college_rosters(...) -> void:
    var player_copy := player.duplicate(true)  # Copy on roster add
    player_copy["college_id"] = college_id
```

## Proposed Solutions

### Strategy 1: Selective Field Copying

Only copy fields that will be modified:

```gdscript
static func _advance_player_one_year_optimized(...) -> Dictionary:
    # Shallow copy of top-level dict
    var p := player.duplicate(false)

    # Deep copy only modified nested structures
    p["stats"] = (player.get("stats", {}) as Dictionary).duplicate(true)
    p["wear"] = (player.get("wear", {}) as Dictionary).duplicate(true)

    # Immutable fields like "name", "position" are shared (no copy needed)
    # ... modifications to stats, wear

    return {"player": p, ...}
```

### Strategy 2: In-Place Modification with Ownership Tracking

For simulation loops where we own the data:

```gdscript
func run_season(players: Array, ...) -> Dictionary:
    # Mark that we own this array and can modify in-place
    for i in range(players.size()):
        var p: Dictionary = players[i]
        # Modify directly - no copy needed
        p["age"] = int(p.get("age", 18)) + 1
        _update_stats_in_place(p, ...)
```

### Strategy 3: Copy-on-Write Pattern

Implement a wrapper that defers copying until modification:

```gdscript
class LazyPlayer:
    var _original: Dictionary
    var _modified_fields: Dictionary = {}
    var _copied: bool = false

    func _init(original: Dictionary) -> void:
        _original = original

    func get(key: String, default: Variant = null) -> Variant:
        if _modified_fields.has(key):
            return _modified_fields[key]
        return _original.get(key, default)

    func set(key: String, value: Variant) -> void:
        if not _copied and typeof(_original.get(key)) == TYPE_DICTIONARY:
            # Deep copy the nested dict on first modification
            _modified_fields[key] = (_original.get(key) as Dictionary).duplicate(true)
        _modified_fields[key] = value

    func materialize() -> Dictionary:
        if _modified_fields.is_empty():
            return _original
        var result := _original.duplicate(false)
        for key in _modified_fields:
            result[key] = _modified_fields[key]
        return result
```

### Strategy 4: Immutable Field Extraction

Separate immutable from mutable player data:

```gdscript
# Immutable (copy once, share everywhere)
var player_identity := {
    "player_id": "...",
    "name": "...",
    "birth_year": 2005,
    "draft_year": 2027,
    "position": "QB"
}

# Mutable (copy on each update)
var player_state := {
    "age": 22,
    "stats": {...},
    "potential": {...},
    "wear": {...}
}
```

## Recommended Approach

Combine Strategies 1 and 2:

1. **Identify ownership boundaries**: Season loops own their player arrays
2. **Use selective deep copying** for nested mutable structures only
3. **Avoid copying immutable fields** (name, position, birth_year)
4. **In-place modification** where ownership is clear

## Implementation Plan

### Phase 1: Audit and Categorize Fields

Document which player fields are:
- **Immutable**: name, player_id, position, birth_year, draft_year
- **Mutable per-season**: stats, potential, wear, development_context
- **Mutable per-lifecycle**: age, injuries, contract

### Phase 2: Update PlayerLifecycle

**File**: `scripts/world/PlayerLifecycle.gd`

```gdscript
static func _advance_player_one_year(player: Dictionary, ...) -> Dictionary:
    # Shallow copy + selective deep copy
    var p := _selective_copy(player)
    p["age"] = int(p.get("age", 18)) + 1

    # Stats already deep copied by _selective_copy
    var stats: Dictionary = p["stats"]
    # ... modify stats directly

    return {"player": p, ...}

static func _selective_copy(player: Dictionary) -> Dictionary:
    var p := player.duplicate(false)  # Shallow copy

    # Deep copy only mutable nested dicts
    if player.has("stats"):
        p["stats"] = (player["stats"] as Dictionary).duplicate(true)
    if player.has("potential"):
        p["potential"] = (player["potential"] as Dictionary).duplicate(true)
    if player.has("wear"):
        p["wear"] = (player["wear"] as Dictionary).duplicate(true)
    if player.has("development_context"):
        p["development_context"] = (player["development_context"] as Dictionary).duplicate(true)
    if player.has("injuries"):
        p["injuries"] = (player["injuries"] as Array).duplicate(true)

    return p
```

### Phase 3: Update ScoutRuntime

For perception, we only need to modify stats temporarily:

```gdscript
static func _perceive_lightweight(
    player: Dictionary,
    stats_cfg: Dictionary,
    base_skill: float,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Only copy stats, not the whole player
    var perceived_stats: Dictionary = {}
    var original_stats: Dictionary = player.get("stats", {})

    for row in stats_cfg.get("stats", []):
        var sname := String((row as Dictionary).get("name", ""))
        var md := float((row as Dictionary).get("measurement_difficulty", 0.5))
        var sigma := (1.0 - md) * (1.0 - base_skill) * 12.0
        var est := float(original_stats.get(sname, 50.0))
        if sigma > 0.0:
            est += rng.randf_range(-sigma, sigma)
        perceived_stats[sname] = clamp(est, 0.0, 100.0)

    # Return only what's needed, not full player copy
    return {"stats": perceived_stats}
```

### Phase 4: Update Season Phases

For development context application:

```gdscript
func _apply_development_context_in_place(
    players: Array,
    context_template: Dictionary
) -> void:
    for i in range(players.size()):
        var p: Dictionary = players[i]
        if p == null:
            continue
        # Modify in place - we own this array
        var ctx := context_template.duplicate(false)
        # Merge with existing context
        var existing: Dictionary = p.get("development_context", {})
        for key in ctx:
            existing[key] = ctx[key]
        p["development_context"] = existing
```

## Memory Impact Analysis

Estimated memory reduction per player copy avoided:

| Field | Approx Size | Copies Saved |
|-------|-------------|--------------|
| Full player dict | ~4KB | 3-5x per phase |
| Stats only | ~1KB | 2x per scout eval |
| Context only | ~200B | 1x per phase |

With 10,000+ players per simulation and 11 phases:
- Current: ~4KB * 10,000 * 5 * 11 = ~2.2GB allocations/year
- Optimized: ~1KB * 10,000 * 2 * 11 = ~220MB allocations/year

## Determinism Preservation

In-place modification requires care:

1. **Array iteration order**: Must remain consistent
2. **Field initialization order**: Must match between runs
3. **Reference sharing**: Immutable fields can be shared safely

## Test Coverage

**File**: `scripts/tests/test_copy_optimization.gd`

```gdscript
func _test_selective_copy_correctness(t):
    var original := _create_test_player()
    var copied := PlayerLifecycle._selective_copy(original)

    # Modify copied stats
    copied["stats"]["speed"] = 99.0

    # Original unchanged
    t.assert_ne(original["stats"]["speed"], 99.0)

func _test_in_place_modification(t):
    var players := [_create_test_player(), _create_test_player()]
    _apply_development_context_in_place(players, {"usage": 1.2})

    t.assert_eq(players[0]["development_context"]["usage"], 1.2)

func _test_memory_profile(t):
    # Measure memory before/after optimization
    # Assert reduction
    pass
```

## Acceptance Criteria

- [ ] PlayerLifecycle uses selective copying
- [ ] ScoutRuntime perception is lightweight
- [ ] Season phases use in-place modification where safe
- [ ] All existing tests pass (determinism preserved)
- [ ] Memory allocations reduced by 50%+ (measured)
- [ ] No performance regression

## Files to Modify

- `scripts/world/PlayerLifecycle.gd`
- `scripts/core/scouting/ScoutRuntime.gd`
- `scripts/world/HighSchoolSeason.gd`
- `scripts/world/CollegeSeason.gd`
- `scripts/world/NflSeason.gd`
- `scripts/pipelines/CollegeRecruiting.gd`

## Files to Create

- `scripts/tests/test_copy_optimization.gd`

## Next Task

After completing F4, proceed to **TASK_F5_parallel_lifecycle.md** for parallelizing player lifecycle updates.
