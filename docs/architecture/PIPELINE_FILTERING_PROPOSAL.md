# Pipeline Filtering Proposal

**Date**: 2026-01-10
**Status**: Planning & Discussion
**Goal**: Apply quality thresholds at BOTH pipeline transitions to eliminate unrealistic player movement

---

## Problem Statement

Currently, the simulation moves players through the pipeline without quality checks:

1. **High School → College**: ALL HS graduates are eligible for college recruiting
2. **College → NFL**: ~~ALL college seniors declare for draft~~ ✅ FIXED (rating >= 65)

**Reality Check:**
- Not every high school player is college-worthy
- Not every college player is NFL-worthy (already fixed)

---

## Current State

### College → NFL Draft (✅ IMPLEMENTED)

From `scripts/world/CollegeSeason.gd` lines 100-106:
```gdscript
var draft_threshold_cfg: Dictionary = config.get("draft_declaration", {}) as Dictionary
var rating_threshold := float(draft_threshold_cfg.get("rating_threshold", 65.0))
var player_rating := _calculate_overall_rating(p, positions_cfg, class_rules)

if player_rating >= rating_threshold:
    is_draft_eligible = true
    total_graduates += 1
```

**Config**: `configs/sports/american_football/world/colleges.json` lines 57-60:
```json
"draft_declaration": {
  "rating_threshold": 65.0,
  "comment": "Only seniors with rating >= 65 declare for NFL draft"
}
```

**Result**: Only ~520 of ~2,900 college seniors declare for draft (top 18%)

---

## Proposed: High School → College Filter

### Current Problem

From `scripts/pipelines/AdvanceWorldYear.gd` lines 227-234:

```gdscript
var graduates: Array = output.get("graduates", []) as Array
world_state["hs_players"] = active

var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
var profiles := _build_recruit_profiles(graduates, year)
recruit_pool[year] = profiles
world_state["hs_recruit_pool"] = recruit_pool
```

**Issue**: ALL HS graduates become recruitable, regardless of skill level

### Proposed Solution

Add quality threshold when building recruit profiles:

```gdscript
var graduates: Array = output.get("graduates", []) as Array
var filtered_recruits := _filter_college_eligible(graduates, positions_cfg, class_rules, recruit_cfg)
world_state["hs_players"] = active

var recruit_pool: Dictionary = world_state.get("hs_recruit_pool", {}) as Dictionary
var profiles := _build_recruit_profiles(filtered_recruits, year)
recruit_pool[year] = profiles
world_state["hs_recruit_pool"] = recruit_pool

return {
    "year": year,
    "count": active.size(),
    "graduates": graduates.size(),
    "college_eligible": filtered_recruits.size(),
    "ineligible": graduates.size() - filtered_recruits.size(),
    # ...
}
```

### Filter Implementation

```gdscript
## Filters HS graduates to only include college-worthy players.
## Returns top X% based on rating threshold.
static func _filter_college_eligible(
    graduates: Array,
    positions_cfg: Dictionary,
    class_rules: Dictionary,
    recruit_cfg: Dictionary
) -> Array:
    var threshold := float(recruit_cfg.get("college_eligibility_threshold", 40.0))
    var eligible := []

    for player in graduates:
        var p: Dictionary = player
        var rating := _calculate_overall_rating(p, positions_cfg, class_rules)

        if rating >= threshold:
            eligible.append(p)

    return eligible
```

### Config Addition

Add to `configs/sports/american_football/world/high_schools.json`:

```json
{
  "version": 1,
  "school_count": 420,
  "name_format": "High School %03d",
  "recruiting": {
    "college_eligibility_threshold": 40.0,
    "comment": "Only HS graduates with rating >= 40 are eligible for college recruiting"
  }
}
```

---

## Expected Impact

### Realistic Funnel

```
High School Graduates:  4,500 players/year (from generation)
                        ↓ Filter: rating >= 40
College Eligible:       ~3,150 players/year (top 70%)
                        ↓ Recruiting: colleges select best
College Recruited:      ~2,888 players/year
                        ↓ Development: 4 years
College Graduates:      ~2,900 seniors/year
                        ↓ Filter: rating >= 65
NFL Draft Eligible:     ~520 players/year (top 18%)
                        ↓ Draft + UDFA: NFL selects best
NFL Rosters:            ~400 players/year signed
```

### Performance Impact

**Current (no HS filter):**
- HS graduates → recruit pool: 4,500 players
- College recruiting evaluates: 4,500 players × 130 colleges = 585,000 evaluations

**Proposed (with HS filter at 40):**
- HS graduates: 4,500 players
- College eligible: ~3,150 players (70%)
- College recruiting evaluates: 3,150 × 130 = 409,500 evaluations
- **Reduction: 175,500 fewer evaluations (30% faster recruiting)**

### Memory Impact

**Current:**
- Recruit pool: 4,500 players × 4KB = 18MB

**Proposed:**
- Recruit pool: 3,150 players × 4KB = 12.6MB
- **Savings: 5.4MB per year**

---

## Threshold Selection Guide

### Option 1: Fixed Thresholds (Simple)

| Threshold | Players Passing | % Passing | Use Case |
|-----------|-----------------|-----------|----------|
| **30** | ~3,825 | 85% | Very inclusive (all FBS + FCS + Division II) |
| **35** | ~3,600 | 80% | Inclusive (FBS + FCS + top D-II) |
| **40** | ~3,150 | 70% | **Recommended** (FBS + top FCS) |
| **45** | ~2,475 | 55% | Selective (mostly FBS-worthy) |
| **50** | ~1,800 | 40% | Very selective (top FBS only) |

**Recommendation: 40** (70% pass rate)
- Matches realistic FBS + FCS recruiting pool
- Provides 3,150 players for 2,888 needed (10% buffer)
- Eliminates bottom 30% who wouldn't get recruited anyway

### Option 2: Dynamic Top-N (Complex)

Calculate threshold dynamically to ensure sufficient recruiting pool:

```gdscript
func calculate_college_threshold(
    graduates: Array,
    colleges: int,
    avg_class_size: float,
    buffer: float = 1.1
) -> float:
    var target_pool_size := int(colleges * avg_class_size * buffer)

    # Sort by rating descending
    var sorted := graduates.duplicate()
    sorted.sort_custom(func(a, b):
        return _rating(a) > _rating(b)
    )

    # Threshold is rating of Nth player
    if sorted.size() > target_pool_size:
        return _rating(sorted[target_pool_size - 1])
    else:
        return 0.0  # All players eligible if not enough
```

**Benefits:**
- Adapts to actual need
- Never undersupplies colleges
- Automatically adjusts if generation changes

**Drawbacks:**
- More complex
- Threshold varies by year
- Harder to reason about

---

## Position-Specific Thresholds (Advanced)

Different positions have different supply/demand:

| Position | Demand (per college) | Supply | Threshold Adjustment |
|----------|---------------------|--------|---------------------|
| **QB** | 3-4 | High | +5 (stricter) |
| **RB** | 4-6 | High | +2 |
| **WR** | 8-10 | Very High | +0 (baseline) |
| **OL** | 12-15 | Medium | -5 (more lenient) |
| **DL** | 8-10 | Low | -8 (much more lenient) |
| **EDGE** | 4-6 | Low | -5 |
| **LB** | 6-8 | Medium | -3 |
| **CB** | 6-8 | High | +0 |
| **S** | 4-6 | Medium | -2 |

**Example:**
```gdscript
var base_threshold := 40.0
var position := String(player.get("position", ""))
var adjustment := position_threshold_adjustments.get(position, 0.0)
var threshold := base_threshold + adjustment

if rating >= threshold:
    eligible.append(player)
```

**Benefits:**
- Addresses position scarcity
- More realistic recruiting dynamics
- Prevents OL/DL shortages

---

## Implementation Phases

### Phase 1: Simple Fixed Threshold (Recommended to Start)

**Implementation:**
1. Add `college_eligibility_threshold: 40.0` to HS config
2. Add `_filter_college_eligible()` function to AdvanceWorldYear.gd
3. Filter graduates before building recruit profiles
4. Update output to track eligible vs ineligible counts

**Testing:**
- Verify ~70% of graduates become recruitable
- Verify colleges can still fill rosters
- Measure recruiting performance improvement

**Expected Results:**
- 30% reduction in recruit pool size
- 30% faster recruiting phase
- 5.4MB memory savings per year

### Phase 2: Dynamic Threshold (Future Enhancement)

**Implementation:**
1. Calculate target pool size based on colleges × avg_class × buffer
2. Sort graduates by rating
3. Set threshold to Nth player's rating
4. Filter based on dynamic threshold

**Testing:**
- Verify colleges always have sufficient recruit pool
- Verify threshold adapts to generation changes
- Test edge cases (not enough graduates)

### Phase 3: Position-Specific Thresholds (Future Enhancement)

**Implementation:**
1. Define position-specific threshold adjustments
2. Apply adjustment when filtering
3. Track per-position eligible counts
4. Tune adjustments based on roster filling

**Testing:**
- Verify OL/DL positions have sufficient depth
- Verify QB position isn't oversupplied
- Measure realistic position distribution

---

## Backward Compatibility

### Breaking Changes: None

- Existing worlds continue to work (default threshold = 0.0 means all eligible)
- Config changes are additive (new field with sensible default)
- Output adds new fields but doesn't remove existing ones

### Migration Path

For existing saves:
1. Load old world state (no recruit filtering)
2. Apply filter on next HS season
3. Gradually reduces recruit pool to target size
4. No data loss, smooth transition

---

## Testing Strategy

### Unit Tests

1. **Threshold filtering:**
   - Test with various thresholds (30, 40, 50)
   - Verify correct percentage passing
   - Test edge cases (all pass, none pass)

2. **Position-specific:**
   - Test per-position adjustments
   - Verify OL/DL get more lenient thresholds

3. **Dynamic threshold:**
   - Test with various target pool sizes
   - Test with insufficient graduates (all pass)

### Integration Tests

1. **College recruiting:**
   - Run full recruiting cycle with filtered pool
   - Verify all colleges fill rosters
   - Verify recruit quality distribution

2. **Performance:**
   - Measure recruiting time with/without filter
   - Verify 30% speedup
   - Measure memory usage

3. **Determinism:**
   - Same seed produces same filtered pool
   - Same seed produces same recruiting results

---

## Questions for Discussion

1. **Threshold Level:**
   - Should we start with 40.0 (70% pass) or different value?
   - Too high = colleges might not fill rosters
   - Too low = minimal performance benefit

2. **Fixed vs Dynamic:**
   - Start with fixed threshold for simplicity?
   - Or implement dynamic from the start?

3. **Position-Specific:**
   - Implement position adjustments in Phase 1?
   - Or wait until Phase 3 after seeing results?

4. **Ineligible Players:**
   - Should they be stored somewhere for reference?
   - Or just discarded after graduation?
   - Useful for "what if" analysis?

5. **User Feedback:**
   - Should we log how many players filtered out?
   - Show warning if too few recruits available?

---

## Recommended Approach

**Start Simple, Iterate:**

1. ✅ **Phase 1A (Done)**: College → NFL filter (rating >= 65)
2. 🎯 **Phase 1B (Next)**: HS → College fixed filter (rating >= 40)
3. 📊 **Evaluate**: Run bootstrap, measure performance, check roster filling
4. 🔧 **Tune**: Adjust threshold if needed (35-45 range)
5. 🚀 **Phase 2**: Add dynamic threshold if fixed doesn't adapt well
6. 🎨 **Phase 3**: Add position-specific adjustments if needed

**Success Criteria:**
- All colleges fill rosters (2,888 recruits per year)
- 20-30% faster recruiting phase
- No complaints about insufficient recruit pool
- Maintains determinism
- Realistic funnel (70% HS → college, 18% college → NFL)

---

## References

**Code Files:**
- `scripts/pipelines/AdvanceWorldYear.gd` - HS graduation and recruit pool (line 227-234)
- `scripts/world/CollegeSeason.gd` - Draft declaration filter (line 100-106)
- `scripts/pipelines/CollegeRecruiting.gd` - Recruit evaluation

**Config Files:**
- `configs/sports/american_football/world/colleges.json` - Draft threshold (line 57-60)
- `configs/sports/american_football/world/high_schools.json` - (needs new config)

**Analysis Docs:**
- `docs/analysis/BACKWARD_CLASS_SIZING.md` - Pipeline flow analysis
