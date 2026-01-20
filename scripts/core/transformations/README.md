# Pure Function Layer for Player State Architecture

This directory contains the pure functional transformation layer for player lifecycle management, implementing the architecture specified in `/docs/architecture/PURE_FUNCTIONAL_PLAYER_STATE_ARCHITECTURE.md`.

## Overview

All functions in this layer are **PURE** - they never modify input dictionaries and always return new dictionaries with updated values. This ensures:

- **Testability**: Pure functions are trivial to test (input → output)
- **Traceability**: No hidden mutations or side effects
- **Predictability**: Same inputs always produce same outputs
- **Determinism**: Identical seeds produce identical results
- **Composability**: Functions can be easily chained together

## Core Files

### 1. **StagePipeline.gd** - Lifecycle Orchestrator
Main entry point that orchestrates player lifecycle transformations.

**Key Functions:**
- `advance_one_year(player, context, configs, rng) -> Dictionary`
  - Orchestrates age increment, development, injury, and retirement
  - RNG consumption: ~20-30 calls per player per year
  - Returns: `{player: Dictionary, retired: bool, report: Dictionary}`

- `transition_stage(player, to_stage) -> Dictionary`
  - Pure stage transition (no validation)
  - Returns: NEW player dict with updated stage

- `compose(functions: Array[Callable]) -> Callable`
  - Function composition utility for chaining transformations

**Example:**
```gdscript
var result := StagePipeline.advance_one_year(player, context, configs, rng)
assert(player["age"] == 22)  # Original unchanged
assert(result.player["age"] == 23)  # New copy modified
assert(result.has("retired"))
```

### 2. **GrowthFunctions.gd** - Stat Development
Pure functions for player stat progression and development.

**Key Functions:**
- `apply_development(player, context, configs, rng) -> Dictionary`
  - Main entry point for stat development
  - RNG consumption: ~15-20 calls (one per base stat)
  - Returns: `{player: Dictionary, report: Dictionary}`

**Algorithm:**
1. Determine lifecycle phase (growth/prime/decline) from age
2. For each base stat:
   - Roll random progress value
   - Apply phase multiplier (growth=1.0, prime=0.35, decline=-1.0)
   - Apply context multipliers (coaching, scheme fit, wear)
   - Cap by potential (can't exceed max)
3. Return new player with updated stats + detailed report

**Context Multipliers:**
- `program_quality`: 0.8 to 1.2 (coaching, facilities)
- `coach_specialization`: 0.9 to 1.1 (position coach expertise)
- `usage`: 0.7 to 1.3 (playing time)
- `competition_tier`: 0.9 to 1.1 (level of competition)
- `rehab_quality`: 0.9 to 1.1 (medical staff quality)

Final multiplier range: [0.7, 1.4] (additive deviation system)

**Example:**
```gdscript
var result := GrowthFunctions.apply_development(player, context, configs, rng)
assert(player["stats"]["speed"] == 70.0)  # Original unchanged
assert(result.player["stats"]["speed"] > 70.0)  # New copy modified
print(result.report)  # {"phase": "growth", "stat_entries": [...]}
```

### 3. **AgeFunctions.gd** - Age Transformations
Pure functions for age-related transformations and calculations.

**Key Functions:**
- `increment_age(player) -> Dictionary`
  - Simple age increment (pure, deterministic)
  - Returns: NEW player dict with age + 1

- `get_age_modifier(age, position, configs) -> float`
  - Age-based development modifier
  - Returns: multiplier in range [0.4, 1.6]

- `years_to_peak(age, position, configs) -> int`
  - Years until peak performance

- `years_until_decline(age, position, configs) -> int`
  - Years until decline phase starts

- `get_lifecycle_phase(age, position, configs) -> String`
  - Returns: "growth", "prime", or "decline"

**Example:**
```gdscript
var p2 := AgeFunctions.increment_age(player)
assert(player["age"] == 22)  # Original unchanged
assert(p2["age"] == 23)  # New copy modified

var phase := AgeFunctions.get_lifecycle_phase(24, "QB", configs)
# Returns "growth" for 24-year-old QB with peak_age=28
```

### 4. **InjuryFunctions.gd** - Injury Simulation
Pure functions for injury occurrence and generation.

**Key Functions:**
- `simulate_injuries(player, configs, rng) -> Dictionary`
  - RNG consumption: 1-5 calls per player per year
  - Returns: `{player: Dictionary, report: Dictionary}`

### 5. **RetirementFunctions.gd** - Retirement Checks
Pure functions for retirement eligibility checks.

**Key Functions:**
- `should_retire(player, configs, rng) -> bool`
  - RNG consumption: 0-1 calls per player per year
  - Returns: bool (true if player should retire)

### 6. **TransitionFunctions.gd** - Stage Transitions
Pure functions for lifecycle stage transitions (with validation).

### 7. **StatFunctions.gd** - Stat Manipulation
Pure functions for stat modifications and calculations.

## Immutability Guarantees

All functions follow strict immutability rules:

```gdscript
# CORRECT: Original unchanged, new dict returned
var new_player := AgeFunctions.increment_age(player)
assert(player["age"] == 22)  # Original unchanged
assert(new_player["age"] == 23)  # New copy modified

# INCORRECT: Never modify input directly
player["age"] += 1  # ❌ VIOLATES PURITY
```

## RNG Management

All probabilistic functions accept RNG as explicit parameter and document consumption patterns:

```gdscript
# Each function documents RNG calls:
# - AgeFunctions: 0 calls (deterministic)
# - GrowthFunctions: ~15-20 calls (one per stat)
# - InjuryFunctions: 1-5 calls (injury generation)
# - RetirementFunctions: 0-1 calls (retirement check)

var rng := RandomNumberGenerator.new()
rng.seed = 12345

# Same seed = same results (determinism)
var result1 := StagePipeline.advance_one_year(player, context, configs, rng)
rng.seed = 12345
var result2 := StagePipeline.advance_one_year(player, context, configs, rng)
assert_eq_deep(result1, result2)  # Identical results
```

## Testing

Run the verification test:

```gdscript
# In Godot Editor
var test := preload("res://scripts/core/transformations/test_pure_functions.gd")
test.run_tests()
```

Or via command line:
```bash
godot --headless --script scripts/core/transformations/test_pure_functions.gd --quit
```

## Integration with Helper Layer

These pure functions are called by the Helper Layer (PlayerStateManager):

```gdscript
# PlayerStateManager wraps pure functions and handles mutations
static func advance_players_one_year(
    world_state: Dictionary,
    collection_path: Array,
    context: Dictionary,
    configs: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    var players := _extract_collection(world_state, collection_path)

    for player in players:
        # Call pure function (no side effects!)
        var result := StagePipeline.advance_one_year(player, context, configs, rng)

        if result.retired:
            # Handle retirement
        else:
            # Update world_state

    # Emit DataBus notification (automatic!)
    DataBus.notify_collection_changed(collection_name, "bulk_update")

    return summary_stats
```

## Performance Considerations

### Deep Copying Overhead
- Pure functions require deep copying (~500 bytes per player per year)
- Mitigated by selective copying (only copy mutable nested structures)
- Performance target: < 5% regression vs. mutable implementation

### Optimization Strategies
1. **Selective Deep Copy**: Only copy fields that will be modified
2. **Batch Processing**: Process multiple players in one pass
3. **Parallel Execution**: Pure functions are trivially parallelizable

## Migration Path

Current code should migrate to use these pure functions:

```gdscript
# OLD CODE (direct mutation):
for player in players:
    player["age"] += 1  # Direct mutation
    player["stats"]["speed"] += 2.0  # Direct mutation

# NEW CODE (pure functions):
var updated := []
for player in players:
    var result := StagePipeline.advance_one_year(player, context, configs, rng)
    updated.append(result.player)
```

## Architecture Compliance

This implementation follows the architecture specified in:
- `/docs/architecture/PURE_FUNCTIONAL_PLAYER_STATE_ARCHITECTURE.md`

**Key Principles:**
1. ✅ All functions are PURE (no side effects)
2. ✅ All functions return NEW dictionaries
3. ✅ RNG passed explicitly through call chain
4. ✅ Comprehensive docstrings with RNG patterns
5. ✅ Functions are static for easy testing
6. ✅ Determinism guaranteed (same seed = same output)

## Future Enhancements

With pure functions in place, we can now implement:
1. **Undo/Redo**: Store state snapshots (trivial with pure functions)
2. **Time-Travel Debugging**: Replay state changes
3. **Optimistic Updates**: Preview changes before applying
4. **State Auditing**: Log all transformations for debugging
5. **Parallel Processing**: Process players concurrently (no race conditions)

## Questions?

See the full architecture document:
`/docs/architecture/PURE_FUNCTIONAL_PLAYER_STATE_ARCHITECTURE.md`

Or contact the Architecture Guardian for clarification.
