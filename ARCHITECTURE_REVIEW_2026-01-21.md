# Architecture Review: Draft Position Distribution Issues
**Date**: 2026-01-21
**Reviewer**: architecture-guardian
**Session**: Resume from 2026-01-18

---

## Executive Summary

Stat tuning achieved partial success (QB now appears at 8.2%), but revealed **fundamental architectural issues** in the OVR calculation system that create systemic bias favoring positions with more core stats.

**Root Cause**: Simple unweighted average of core stats makes positions with more core stats mathematically "forgiving" and positions with fewer core stats "punishing".

---

## Results of Stat Tuning Pass

### Successes ✅
- **QB**: Now appearing! 36 players (8.2% of draft pool, target: 8-12)
- **CB**: Reduced from 21% → 7.9% (target: 13-16%, exceeded goal)
- **WR**: Reduced from 25% → 7.5% (target: 14-18%, exceeded goal)

### Partial Failures ⚠️
- **OL**: Still only 5.7% combined (no breakdown by archetype)
- **EDGE**: Still dominates at 26.1% (target: 16-22%)

### Critical Issues Found ❌
- **Archetype data NOT preserved**: All OL players show "Unknown" archetype
- **No OT/OG/C separation**: Draft pool treats OL as single position

---

## Architectural Issue #1: OVR Calculation Bias

**Location**: `scripts/core/rating/PlayerRatingCalculator.gd:61`

**Current Implementation**:
```gdscript
var core_avg := core_sum / float(core_stats.size())
```

**The Problem**: Simple unweighted average creates mathematical bias.

### Impact Analysis

| Position | Core Stats | Impact of Weak Stat | Current Pool % | Target % |
|----------|-----------|---------------------|----------------|----------|
| EDGE     | 6         | 16.7% penalty       | 26.1%          | 16-22%   |
| QB       | 5         | 20.0% penalty       | 8.2%           | 9-16%    |
| CB       | 5         | 20.0% penalty       | 7.9%           | 13-19%   |
| WR       | 4         | 25.0% penalty       | 7.5%           | -        |
| **OL**   | **3**     | **33.3% penalty**   | **5.7%**       | **25%+** |

**EDGE has 2x more "forgiveness" than OL!**

### Why EDGE Dominates

EDGE has 6 core stats: `pass_rush`, `acceleration`, `agility`, `tackling`, `shedding_blocks`, `strength`

Even if one stat is mediocre, the other 5 dilute the impact. With an average of ~75 across all stats, EDGE players easily exceed the 65.0 draft threshold.

### Why OL Struggles

OL has only 3 core stats: `strength`, `blocking`, `balance`

Any weakness (even a single stat at 70) drags the average down by 33.3%. To hit 75 OVR, ALL three stats must be 75+.

**Mathematical Reality**:
- EDGE with [80, 78, 76, 74, 72, 70] = 75.0 avg → **DRAFTS**
- OL with [85, 80, 60] = 75.0 avg → **DRAFTS** (but needs very high top stats)
- OL with [80, 80, 65] = 75.0 avg → **BARELY** (any drop = undrafted)

---

## Architectural Issue #2: Archetype System Not Implemented

**Discovery**: Searched entire codebase for archetype assignment - **ONLY** found in `ScoutFactory.gd` (for scouts, not players).

**Evidence from Draft Pool Analysis**:
```
2024 OL Players (25 total):
  Unknown: 25 (100.0%)
```

All OL players have `archetype: "Unknown"`, meaning:
1. Archetypes are defined in `positions.json` (Tackle, Guard, Center)
2. Archetypes are never assigned during player generation
3. Draft pool has no way to differentiate OT from OG from C

**Implications**:
- Cannot track OT vs OG vs C separately in draft
- Cannot apply archetype-specific bonuses during player generation
- Position.json archetype config is effectively unused
- All OL stat boosts applied equally to the "OL" position

---

## Architectural Issue #3: Draft Eligibility Threshold

**Location**: `scripts/world/CollegeSeason.gd:162`

```gdscript
var rating_threshold := float(draft_threshold_cfg.get("rating_threshold", 65.0))
```

**Single Universal Threshold**: 65.0 OVR for ALL positions

**Problem**: Positions with different core stat counts need different thresholds to achieve fair representation.

### Recommended Position-Specific Thresholds

Based on core stat count analysis:

| Position | Core Stats | Current Threshold | Suggested Threshold | Rationale |
|----------|-----------|-------------------|---------------------|-----------|
| OL       | 3         | 65.0              | **62.0**            | 33% penalty per stat |
| WR       | 4         | 65.0              | **64.0**            | 25% penalty per stat |
| QB       | 5         | 65.0              | **65.0** (baseline)  | 20% penalty per stat |
| CB       | 5         | 65.0              | **65.0** (baseline)  | 20% penalty per stat |
| EDGE     | 6         | 65.0              | **67.0**            | 17% penalty per stat |

**Implementation**: Add `rating_threshold_by_position` to config, fall back to 65.0 default.

---

## Recommended Solutions

### Priority 1: Implement Position-Specific Thresholds (Quick Fix)

**Effort**: Low (config change + 10 lines of code)
**Impact**: High (immediately balances position representation)

**Implementation**:
1. Add to `configs/main_config.json`:
```json
{
  "draft_declaration": {
    "rating_threshold": 65.0,
    "rating_threshold_by_position": {
      "OL": 62.0,
      "WR": 64.0,
      "EDGE": 67.0
    }
  }
}
```

2. Update `CollegeSeason.gd:162`:
```gdscript
var base_threshold := float(draft_threshold_cfg.get("rating_threshold", 65.0))
var thresholds_by_pos: Dictionary = draft_threshold_cfg.get("rating_threshold_by_position", {})
var position := String(p.get("position", ""))
var rating_threshold := float(thresholds_by_pos.get(position, base_threshold))
```

**Expected Impact**:
- OL: 5.7% → ~12-15% (2-3x increase)
- EDGE: 26.1% → ~18-20% (25% decrease)

---

### Priority 2: Implement Weighted Core Stat Averaging (Medium Fix)

**Effort**: Medium (requires defining weights in positions.json)
**Impact**: High (more accurate player evaluation)

**Current**: All core stats weighted equally
**Proposed**: Weight stats by importance

**Example for QB**:
```json
{
  "QB": {
    "core_stats": [
      {"stat": "throw_accuracy", "weight": 0.25},
      {"stat": "decision_making", "weight": 0.20},
      {"stat": "awareness", "weight": 0.20},
      {"stat": "anticipation", "weight": 0.20},
      {"stat": "composure", "weight": 0.15}
    ]
  }
}
```

**Benefits**:
- More realistic player evaluation
- Reduces "stat dumping" strategies
- Allows fine-tuning of position balance

**Tradeoff**: Adds complexity to config, requires more careful tuning.

---

### Priority 3: Implement Archetype Assignment System (Large Fix)

**Effort**: High (requires changes to generation pipeline)
**Impact**: Critical (enables OT/OG/C tracking and specialized scouting)

**Required Changes**:
1. Modify `ClassGenerator.gd` to assign archetypes during generation
2. Apply archetype-specific stat overrides from `positions.json`
3. Update draft pool to preserve archetype field
4. Add UI/queries to filter by archetype

**Example Implementation**:
```gdscript
# In ClassGenerator.gd after position assignment
func _assign_archetype(player: Dictionary, position: String, positions_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
    var pos_cfg := positions_cfg.get(position, {})
    var archetypes := pos_cfg.get("archetypes", {})

    if archetypes.is_empty():
        return

    # Weighted random selection
    var selected_archetype := _weighted_random_choice(archetypes, rng)
    player["archetype"] = selected_archetype

    # Apply archetype stat overrides
    var arch_cfg := archetypes[selected_archetype]
    var overrides := arch_cfg.get("dist_overrides", {})
    for stat_name in overrides:
        var override := overrides[stat_name]
        var mu_add := float(override.get("mu_add", 0.0))
        player[stat_name] = player.get(stat_name, 50.0) + mu_add
```

**Benefits**:
- OT, OG, C tracked separately in draft
- Archetype-specific scouting and evaluation
- Richer player diversity
- Unlocks position.json archetype system

**Tradeoff**: Significant development effort, requires thorough testing.

---

## Alternative Approach: Normalize Core Stat Counts

**Concept**: Ensure all positions have 4-5 core stats for fairness.

**Changes Required**:
- **OL**: Add `agility` and `awareness` as core stats → 5 total
- **EDGE**: Remove 1 core stat OR accept higher threshold
- **WR**: Add `awareness` as core stat → 5 total

**Benefits**:
- Simpler than weighted averages
- Doesn't require code changes
- More "fair" mathematically

**Tradeoffs**:
- May not reflect real football evaluation
- Some positions naturally have fewer critical attributes

---

## Immediate Action Items

1. ✅ **Document findings** (this file)
2. **Implement position-specific thresholds** (Priority 1) - Quick win
3. **Test threshold changes** with new snapshot generation
4. **Evaluate need for weighted averages** (Priority 2) based on threshold results
5. **Plan archetype system implementation** (Priority 3) - Separate phase

---

## Testing Strategy

After implementing position-specific thresholds:

1. Generate new 20-year snapshot
2. Analyze draft pool composition:
   - Target: OL 12-15%, EDGE 18-20%, QB 9-12%
3. Analyze round 1 draft picks by position
4. Verify no unintended side effects on other positions

**Success Criteria**:
- All positions represented in draft pool (no 0% positions)
- No single position >20% of pool
- Round 1 picks reflect NFL-like distribution

---

## Files Modified This Session

1. `main/configs/sports/american_football/positions.json`
   - QB: 6 stat increases (throw_accuracy +5, throw_power +5, etc.)
   - OL/Guard: Archetype bonuses increased (strength +6, blocking +5)
   - OL/Tackle: Archetype bonuses increased (agility +6, blocking +3, etc.)
   - OL/Center: Archetype bonuses increased (awareness +8, blocking +3, etc.)
   - CB: 4 stat decreases (speed -2, agility -2, coverage -2, reaction_time -2)
   - WR: 4 stat decreases (speed -2, agility -2, route_running -2, catching -2)

---

## Next Steps for Implementation Team

### Engineer Tasks
1. Implement position-specific threshold system (Priority 1)
2. Add config validation for threshold overrides
3. Write deterministic tests for threshold logic

### Test Tasks
1. Create unit tests for position-specific thresholds
2. Create integration tests for draft pool composition
3. Add regression tests to detect future bias

### Architect Tasks
1. Review weighted averaging proposal
2. Design archetype assignment system architecture
3. Evaluate normalization vs weighting vs thresholds

---

## Conclusion

The stat tuning approach was a valuable diagnostic tool that revealed deeper architectural issues. While QB now appears (success!), the systemic bias in OVR calculation explains why simple stat changes can't fix position imbalance.

**The path forward is clear**:
1. Quick fix: Position-specific thresholds
2. Medium fix: Weighted stat averaging
3. Long-term fix: Full archetype system implementation

**User's insight was correct**: We need to rethink OVR calculation, not just boost stats.

---

**End of Review**
