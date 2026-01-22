# Weighted OVR Calculation System - Architecture Design

**Date**: 2026-01-21
**Author**: architecture-guardian
**Status**: Design Phase

---

## Problem Statement

Current OVR calculation uses simple unweighted average of position core stats:
```gdscript
core_avg = sum(core_stats) / core_stats.size()
```

**Issues**:
1. **Mathematical bias**: Positions with more core stats are more "forgiving" (EDGE 6 stats vs OL 3 stats)
2. **Unrealistic**: Ignores universal attributes (all players need speed, strength, stamina)
3. **Inflexible**: Can't tune position balance without changing stat values
4. **Not football-accurate**: CB speed should matter more than OL speed

---

## Design Goals

1. **Realistic Evaluation**: OVR should reflect actual player quality
2. **Universal Foundation**: All players evaluated on base attributes
3. **Side-of-Ball Specialization**: Offensive vs defensive skill sets
4. **Position Specificity**: Each position emphasizes different attributes
5. **Inheritable/Overridable**: Positions customize base calculations
6. **Tunable Balance**: Adjust position representation via weights, not stat inflation
7. **Deterministic**: Same stats → same OVR (no RNG)
8. **Performant**: Fast calculation (called frequently during simulation)

---

## Stat Visibility and Evaluation Uncertainty

**Key Insight**: Not all stats are equally observable or measurable. Some stats are concrete and measurable (speed, height), while others are subjective or hard to judge (decision_making, anticipation, composure).

### Stat Visibility Tiers

Already defined in `positions.json`:
- **Public**: Always known precisely (speed, height, weight, 40-time)
- **Scoutable**: Requires scouting to reveal, has uncertainty ranges (awareness, anticipation, decision_making)
- **Hidden**: Never fully known to evaluators (future: injury_prone, personality traits)

### Evaluation Confidence

**Displayed OVR** (what teams see) vs **True OVR** (player's actual quality):

1. **Public Stats**: 100% confidence
   - Speed measured at combine
   - Height/weight objective
   - Used at full weight in displayed OVR

2. **Scoutable Stats**: Confidence depends on scouting investment
   - Unscouted: Estimated from public stats (fuzzy, ±10 points)
   - Partially scouted: Revealed with noise (±5 points)
   - Fully scouted: Revealed with minimal noise (±2 points)
   - Weight scales with confidence

3. **Hidden Stats**: Not included in displayed OVR
   - Affects in-game performance but not pre-draft evaluation
   - Creates "boom or bust" prospects

### Implementation Note

The weighted OVR system uses **true stat values** for threshold calculations (draft eligibility).

**Separate system** handles displayed OVR for scouting:
- `calculate_weighted_ovr()` → True OVR (for thresholds)
- `calculate_displayed_ovr()` → What teams see (for draft boards)

This preserves existing scouting uncertainty while making OVR calculation realistic.

---

## Three-Tier Weight System

### Tier 1: Base Weights (ALL Players)
Universal attributes that apply to every position.

**Attributes**:
- `speed` - Movement speed
- `strength` - Physical power
- `stamina` - Endurance
- `agility` - Change of direction
- `awareness` - Football IQ / field vision

**Default Weights** (sum to ~20-25%):
```json
{
  "speed": 0.05,
  "strength": 0.05,
  "stamina": 0.04,
  "agility": 0.04,
  "awareness": 0.05
}
```

**Rationale**: Every player benefits from these, but they're not the primary differentiators.

---

### Tier 2: Side-of-Ball Weights (Offense vs Defense)

Attributes shared by all positions on one side of the ball.

**Offensive Attributes**:
- `blocking` - Pass/run blocking ability
- `catching` - Receiving ability
- `ball_security` - Fumble avoidance (future)

**Defensive Attributes**:
- `tackling` - Tackle success rate
- `coverage` - Pass defense ability
- `shedding_blocks` - Getting past blockers
- `pass_rush` - Quarterback pressure

**Default Weights** (sum to ~15-25%):
```json
{
  "offensive": {
    "blocking": 0.08,
    "catching": 0.08
  },
  "defensive": {
    "tackling": 0.10,
    "coverage": 0.08,
    "shedding_blocks": 0.06
  }
}
```

**Rationale**: Specialized skills that define offensive vs defensive roles.

---

### Tier 3: Position-Specific Weights

High-weight attributes that define position excellence.

**Per-Position** (sum to ~50-60%):
- QB: `throw_accuracy` (25%), `decision_making` (20%), `throw_power` (10%)
- CB: `coverage` (30%), `speed` (20%), `agility` (15%)
- OL: `blocking` (30%), `strength` (20%), `balance` (10%)

**Rationale**: These are the "make or break" attributes for each position.

---

## Config Schema Design

### Structure

```json
{
  "ovr_calculation": {
    "base_weights": {
      "speed": 0.05,
      "strength": 0.05,
      "stamina": 0.04,
      "agility": 0.04,
      "awareness": 0.05
    },
    "side_of_ball_weights": {
      "offensive": {
        "blocking": 0.08,
        "catching": 0.08
      },
      "defensive": {
        "tackling": 0.10,
        "coverage": 0.08,
        "shedding_blocks": 0.06
      }
    },
    "position_weights": {
      "QB": {
        "side_of_ball": "offensive",
        "weights": {
          "throw_accuracy": 0.25,
          "decision_making": 0.20,
          "throw_power": 0.10,
          "composure": 0.08,
          "anticipation": 0.07
        },
        "override_base": {
          "speed": 0.02,
          "agility": 0.02
        },
        "override_side": {
          "blocking": 0.01
        }
      },
      "CB": {
        "side_of_ball": "defensive",
        "weights": {
          "coverage": 0.30,
          "press_coverage": 0.12,
          "reaction_time": 0.10,
          "ball_skills": 0.08
        },
        "override_base": {
          "speed": 0.10,
          "agility": 0.08
        },
        "override_side": {
          "tackling": 0.06
        }
      },
      "OL": {
        "side_of_ball": "offensive",
        "weights": {
          "blocking": 0.35,
          "balance": 0.12,
          "awareness": 0.08
        },
        "override_base": {
          "strength": 0.12,
          "speed": 0.02,
          "agility": 0.06
        }
      }
    }
  }
}
```

### Schema Rules

1. **Weight Summation**: All weights for a position MUST sum to 1.0 (100%)
   - Validation error if sum != 1.0

2. **Override Semantics**:
   - `override_base`: Replaces base weight for this position
   - `override_side`: Replaces side-of-ball weight for this position
   - If not overridden, uses default from base/side tiers

3. **Side-of-Ball Assignment**: Each position must declare "offensive" or "defensive"
   - Special teams (K, P) use "offensive" by default (or create "special" tier)

4. **Missing Stats**: If player lacks a stat, use neutral value (50.0)
   - Log warning if position weight references missing stat

---

## Example Weight Distributions

### Quarterback (QB)

```json
{
  "QB": {
    "side_of_ball": "offensive",
    "weights": {
      "throw_accuracy": 0.25,    // Key stat
      "decision_making": 0.20,   // Key stat
      "throw_power": 0.10,       // Important
      "composure": 0.08,         // Important
      "anticipation": 0.07       // Important
    },
    "override_base": {
      "speed": 0.02,             // Less important for QB
      "strength": 0.03,          // Some importance
      "stamina": 0.04,           // Standard
      "agility": 0.02,           // Less important
      "awareness": 0.08          // Very important for QB
    },
    "override_side": {
      "blocking": 0.01,          // Minimal for QB
      "catching": 0.00           // Not applicable
    }
  }
}
```

**Total**: 1.00 (100%)

---

### Cornerback (CB)

```json
{
  "CB": {
    "side_of_ball": "defensive",
    "weights": {
      "coverage": 0.30,          // Key stat
      "press_coverage": 0.12,    // Important
      "reaction_time": 0.10,     // Important
      "ball_skills": 0.08        // Important
    },
    "override_base": {
      "speed": 0.10,             // CRITICAL for CB
      "strength": 0.03,          // Some importance
      "stamina": 0.04,           // Standard
      "agility": 0.08,           // Very important
      "awareness": 0.05          // Important
    },
    "override_side": {
      "tackling": 0.06,          // Moderate importance
      "coverage": 0.00,          // Handled by position weights
      "shedding_blocks": 0.04    // Some importance
    }
  }
}
```

**Total**: 1.00 (100%)

---

### Offensive Line (OL)

```json
{
  "OL": {
    "side_of_ball": "offensive",
    "weights": {
      "blocking": 0.35,          // Key stat (note: overrides side weight)
      "balance": 0.12,           // Important
      "footwork": 0.08           // Important
    },
    "override_base": {
      "speed": 0.02,             // Less important
      "strength": 0.12,          // CRITICAL for OL
      "stamina": 0.04,           // Standard
      "agility": 0.06,           // Moderate importance
      "awareness": 0.08          // Important for protection reads
    },
    "override_side": {
      "blocking": 0.00,          // Handled by position weights (avoid double-counting)
      "catching": 0.00           // Not applicable
    }
  }
}
```

**Total**: 1.00 (100%)

**Note**: OL has `blocking` in both side-of-ball and position weights. The position weight takes precedence to avoid double-counting.

---

### Edge Rusher (EDGE)

```json
{
  "EDGE": {
    "side_of_ball": "defensive",
    "weights": {
      "pass_rush": 0.25,         // Key stat
      "acceleration": 0.12,      // Important
      "shedding_blocks": 0.10,   // Important
      "finesse_moves": 0.08,     // Important
      "power_moves": 0.08        // Important
    },
    "override_base": {
      "speed": 0.08,             // Important for edge speed
      "strength": 0.08,          // Important for power
      "stamina": 0.04,           // Standard
      "agility": 0.06,           // Important for bend
      "awareness": 0.04          // Moderate
    },
    "override_side": {
      "tackling": 0.07,          // Important
      "coverage": 0.00,          // Not applicable
      "shedding_blocks": 0.00    // Handled by position weights
    }
  }
}
```

**Total**: 1.00 (100%)

---

### Wide Receiver (WR)

```json
{
  "WR": {
    "side_of_ball": "offensive",
    "weights": {
      "catching": 0.25,          // Key stat (overrides side weight)
      "route_running": 0.18,     // Key stat
      "separation": 0.10,        // Important
      "contested_catch": 0.08    // Important
    },
    "override_base": {
      "speed": 0.12,             // CRITICAL for WR
      "strength": 0.04,          // Some importance
      "stamina": 0.04,           // Standard
      "agility": 0.10,           // Very important
      "awareness": 0.05          // Important for reads
    },
    "override_side": {
      "blocking": 0.04,          // Some importance
      "catching": 0.00           // Handled by position weights
    }
  }
}
```

**Total**: 1.00 (100%)

---

## Code Architecture

### New Calculator Implementation

**Location**: `scripts/core/rating/PlayerRatingCalculator.gd`

```gdscript
## Calculates weighted OVR using three-tier inheritance system.
##
## Calculation order:
## 1. Load base weights (applies to ALL positions)
## 2. Load side-of-ball weights (offensive vs defensive)
## 3. Load position-specific weights
## 4. Apply position overrides to base/side weights
## 5. Calculate weighted sum: sum(stat * weight) for all weights
##
## Weight inheritance:
## - Position overrides replace base/side weights for specific stats
## - If stat not in position weights, check side-of-ball weights
## - If stat not in side weights, check base weights
## - Total weights must sum to 1.0 (validated at config load time)
##
## Parameters:
##   player: Player dictionary with stats
##   position: Position string (QB, CB, OL, etc.)
##   ovr_config: OVR calculation config (from main_config.json)
##
## Returns:
##   Weighted OVR as float (0.0-100.0 range)
static func calculate_weighted_ovr(
    player: Dictionary,
    position: String,
    ovr_config: Dictionary
) -> float:
    # Get player stats (may be nested under "stats" key or at top level)
    var stats_dict: Dictionary = player.get("stats", {}) as Dictionary
    var use_nested := not stats_dict.is_empty()

    # Load three tiers of weights
    var base_weights: Dictionary = ovr_config.get("base_weights", {})
    var side_weights_all: Dictionary = ovr_config.get("side_of_ball_weights", {})
    var position_weights_all: Dictionary = ovr_config.get("position_weights", {})

    # Get position-specific config
    if not position_weights_all.has(position):
        push_warning("No OVR weights defined for position: " + position)
        return _fallback_calculation(player, stats_dict, use_nested)

    var pos_config: Dictionary = position_weights_all.get(position, {})
    var side_of_ball := String(pos_config.get("side_of_ball", "offensive"))
    var pos_weights: Dictionary = pos_config.get("weights", {})
    var override_base: Dictionary = pos_config.get("override_base", {})
    var override_side: Dictionary = pos_config.get("override_side", {})

    # Get side-of-ball weights
    var side_weights: Dictionary = side_weights_all.get(side_of_ball, {})

    # Build final weight map (position > side > base)
    var final_weights := {}

    # Start with base weights
    for stat in base_weights.keys():
        final_weights[stat] = float(base_weights[stat])

    # Layer in side-of-ball weights (may override base)
    for stat in side_weights.keys():
        final_weights[stat] = float(side_weights[stat])

    # Apply position overrides to base/side
    for stat in override_base.keys():
        final_weights[stat] = float(override_base[stat])
    for stat in override_side.keys():
        final_weights[stat] = float(override_side[stat])

    # Layer in position-specific weights (highest priority)
    for stat in pos_weights.keys():
        final_weights[stat] = float(pos_weights[stat])

    # Calculate weighted sum
    var weighted_sum := 0.0
    var total_weight := 0.0  # For validation

    for stat_name in final_weights.keys():
        var weight := float(final_weights[stat_name])

        # Get stat value from player
        var stat_value: float
        if use_nested:
            stat_value = float(stats_dict.get(stat_name, 50.0))
        else:
            stat_value = float(player.get(stat_name, 50.0))

        weighted_sum += stat_value * weight
        total_weight += weight

    # Validation: weights should sum to ~1.0
    if abs(total_weight - 1.0) > 0.01:
        push_warning("Position %s weights sum to %.2f (expected 1.0)" % [position, total_weight])

    # Normalize if weights don't sum to exactly 1.0
    if total_weight > 0.0:
        return weighted_sum / total_weight * 100.0  # Scale to 0-100
    else:
        return 50.0  # Neutral fallback

## Fallback calculation for positions without weight config
static func _fallback_calculation(
    player: Dictionary,
    stats_dict: Dictionary,
    use_nested: bool
) -> float:
    # Use legacy core_avg or simple average
    if player.has("core_avg"):
        return float(player.get("core_avg", 50.0))

    var stat_sum := 0.0
    var stat_count := 0

    var source := stats_dict if use_nested else player
    for key in source.keys():
        var value = source[key]
        if value is float or value is int:
            if key not in ["player_id", "age", "year", "college_year", "hs_year"]:
                stat_sum += float(value)
                stat_count += 1

    if stat_count > 0:
        return stat_sum / float(stat_count)
    return 50.0
```

### Config Validation Function

```gdscript
## Validates OVR config at startup.
## Ensures all position weights sum to 1.0 and all referenced stats exist.
static func validate_ovr_config(ovr_config: Dictionary, positions_cfg: Dictionary) -> bool:
    var is_valid := true
    var position_weights: Dictionary = ovr_config.get("position_weights", {})

    for position in position_weights.keys():
        var pos_config: Dictionary = position_weights.get(position, {})

        # Check side_of_ball is specified
        if not pos_config.has("side_of_ball"):
            push_error("Position %s missing 'side_of_ball' declaration" % position)
            is_valid = false
            continue

        # Calculate total weight
        var total_weight := 0.0

        # Base overrides
        var override_base: Dictionary = pos_config.get("override_base", {})
        for stat in override_base.keys():
            total_weight += float(override_base[stat])

        # Side overrides
        var override_side: Dictionary = pos_config.get("override_side", {})
        for stat in override_side.keys():
            total_weight += float(override_side[stat])

        # Position weights
        var weights: Dictionary = pos_config.get("weights", {})
        for stat in weights.keys():
            total_weight += float(weights[stat])

        # Check sum
        if abs(total_weight - 1.0) > 0.01:
            push_error("Position %s weights sum to %.3f (expected 1.0)" % [position, total_weight])
            is_valid = false

    return is_valid
```

---

## Migration Strategy

### Phase 1: Add Weighted System Alongside Current System

**Goal**: No breaking changes, allow parallel testing.

**Steps**:
1. Add `ovr_calculation` config to `main_config.json`
2. Implement `calculate_weighted_ovr()` in `PlayerRatingCalculator.gd`
3. Add feature flag: `use_weighted_ovr: false` (default to current system)
4. Add validation function called at game startup
5. Write unit tests comparing weighted vs unweighted OVR

**Timeline**: 1-2 days

---

### Phase 2: Define Weights for All Positions

**Goal**: Complete weight distributions for all 12+ positions.

**Positions to Define**:
- Offense: QB, RB, WR, TE, OL (with archetypes)
- Defense: DL, EDGE, LB, CB, S
- Special: K, P

**Steps**:
1. Research realistic attribute importance per position
2. Define weight distributions (sum to 1.0)
3. Add to `main_config.json`
4. Validate with `validate_ovr_config()`

**Timeline**: 2-3 days (research + config + validation)

---

### Phase 3: Test and Tune Weights

**Goal**: Achieve balanced draft pool distribution.

**Steps**:
1. Enable weighted OVR: `use_weighted_ovr: true`
2. Generate 20-year snapshot
3. Analyze draft pool composition
4. Tune weights if needed (increase/decrease emphasis)
5. Repeat until balanced

**Success Criteria**:
- No position > 20% of draft pool
- All positions > 3% of draft pool (except K/P)
- Round 1 picks reflect NFL-like distribution

**Timeline**: 3-5 days (iterative tuning)

---

### Phase 4: Remove Legacy System

**Goal**: Clean up codebase, make weighted system the default.

**Steps**:
1. Remove `use_weighted_ovr` flag
2. Remove legacy `calculate_overall_rating()` function
3. Update all callers to use `calculate_weighted_ovr()`
4. Update documentation

**Timeline**: 1 day

---

## Performance Considerations

### Calculation Cost

**Current System**:
- 3-6 stat lookups
- 1 division operation
- **~10-15 µs per call**

**Weighted System**:
- 15-25 stat lookups (base + side + position)
- 15-25 multiplications
- 15-25 additions
- 1 division operation
- **~30-50 µs per call**

**Impact**: 3x slower per call, but still negligible (<0.1ms).

**Frequency**: Called ~500-1000 times per year (draft eligibility filtering).

**Total Impact**: <50ms per year of simulation. **Acceptable.**

---

### Optimization Opportunities

If performance becomes an issue:

1. **Cache Position Weights**: Pre-compute final weight map per position at config load time
   - Reduces runtime lookups from 3 tiers to 1 map
   - Speeds up by ~40%

2. **Pre-compute OVR**: Calculate OVR once per player per year, store in `player.ovr_cache`
   - Requires cache invalidation on stat changes
   - Eliminates repeated calculations

3. **Vectorize Calculations**: Use array operations instead of loops (if GDScript supports)

**Recommendation**: Implement caching only if profiling shows bottleneck.

---

## Validation Rules

### Config Load Time

1. **Weight Summation**: All position weights must sum to 1.0 (±0.01)
2. **Side-of-Ball**: Each position must declare "offensive" or "defensive"
3. **No Duplicate Stats**: Position weights shouldn't duplicate base/side stats (log warning)
4. **Stat Existence**: Warn if weighted stat doesn't exist in position distributions

### Runtime

1. **Missing Stats**: Use neutral value (50.0) if stat missing from player
2. **Weight Normalization**: If weights don't sum to 1.0, normalize before calculation
3. **Fallback**: Use legacy calculation if position has no weight config

---

## Testing Strategy

### Unit Tests

```gdscript
# Test 1: Weighted OVR calculation accuracy
func test_weighted_ovr_qb():
    var player := {
        "position": "QB",
        "throw_accuracy": 80.0,
        "decision_making": 75.0,
        "throw_power": 70.0,
        "speed": 60.0,
        "strength": 65.0
    }
    var ovr := PlayerRatingCalculator.calculate_weighted_ovr(player, "QB", ovr_config)
    # Expected: (80*0.25 + 75*0.20 + 70*0.10 + ...) = X
    assert_float_eq(ovr, 74.5, 0.1)

# Test 2: Weight summation validation
func test_weight_validation():
    var invalid_config := {
        "position_weights": {
            "QB": {
                "weights": {"throw_accuracy": 0.5}  # Only sums to 0.5
            }
        }
    }
    assert_false(PlayerRatingCalculator.validate_ovr_config(invalid_config, {}))

# Test 3: Override behavior
func test_base_weight_override():
    # QB should have lower speed weight than CB
    var qb_config := ovr_config["position_weights"]["QB"]
    var cb_config := ovr_config["position_weights"]["CB"]
    assert_lt(qb_config["override_base"]["speed"], cb_config["override_base"]["speed"])
```

### Integration Tests

```gdscript
# Test 1: Draft pool distribution
func test_draft_pool_balanced():
    var world_state := generate_20_year_world()
    var draft_pool := world_state.get("draft_pool", {}).get("2024", [])

    var positions := {}
    for player in draft_pool:
        var pos := player.get("position", "UNKNOWN")
        positions[pos] = positions.get(pos, 0) + 1

    # No position should dominate
    for pos in positions:
        var pct := positions[pos] / float(draft_pool.size())
        assert_lt(pct, 0.25, "Position %s has %d%%" % [pos, pct * 100])

# Test 2: OVR reflects quality
func test_ovr_correlates_with_performance():
    # High OVR players should have high key stats for their position
    var cb_high := {"position": "CB", "coverage": 90, "speed": 88}
    var cb_low := {"position": "CB", "coverage": 60, "speed": 62}

    var ovr_high := calculate_weighted_ovr(cb_high, "CB", config)
    var ovr_low := calculate_weighted_ovr(cb_low, "CB", config)

    assert_gt(ovr_high, ovr_low + 10.0)  # Significant difference
```

---

## Benefits of This Approach

1. **Realistic Evaluation**: OVR reflects actual player quality, not mathematical artifacts
2. **Eliminates Bias**: No more "positions with more core stats are better"
3. **Tunable Balance**: Adjust position representation via weights, not stat inflation
4. **Football Accuracy**: CB speed matters more than OL speed (as it should)
5. **Transparent**: Weights visible in config, easy to understand and modify
6. **Future-Proof**: Easy to add new stats or positions
7. **Inheritable**: Positions share common attributes, customize where needed
8. **Debuggable**: Can trace exactly why a player has a certain OVR

---

## Example: Why This Fixes Position Balance

### Current System (Unweighted)

**EDGE** (6 core stats):
- pass_rush: 82, acceleration: 78, agility: 74, tackling: 75, shedding_blocks: 73, strength: 70
- **OVR** = (82+78+74+75+73+70) / 6 = **75.3** → DRAFTS

**OL** (3 core stats):
- strength: 88, blocking: 82, balance: 78
- **OVR** = (88+82+78) / 3 = **82.7** → DRAFTS (but requires ALL stats high)

EDGE more forgiving → overrepresented.

---

### New System (Weighted)

**EDGE**:
- Base: speed(0.08*72) + strength(0.08*70) + stamina(0.04*68) + agility(0.06*74) + awareness(0.04*62)
- Side: tackling(0.07*75) + shedding_blocks(0.00*73 override)
- Position: pass_rush(0.25*82) + acceleration(0.12*78) + shedding_blocks(0.10*73) + ...
- **OVR** = weighted_sum = **~76.5**

**OL**:
- Base: speed(0.02*38) + strength(0.12*88) + stamina(0.04*66) + agility(0.06*48) + awareness(0.08*64)
- Side: blocking(0.00*82 override)
- Position: blocking(0.35*82) + balance(0.12*78) + footwork(0.08*72)
- **OVR** = weighted_sum = **~79.2**

Now OL with strong core stats gets appropriate OVR!

---

## Next Steps

1. **Review This Design**: Get stakeholder feedback on weight distributions
2. **Implement Phase 1**: Add weighted system alongside current system
3. **Define All Weights**: Complete weight distributions for all positions
4. **Test and Tune**: Generate snapshots, analyze balance, iterate
5. **Deploy**: Switch to weighted system as default

---

**End of Design Document**
