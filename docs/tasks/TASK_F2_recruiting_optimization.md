# Task F2: College Recruiting Optimization

**Track**: Performance Optimization (Track F)
**Dependencies**: F1 (Profiling Report)
**Status**: Not started
**Estimated Effort**: 2-3 days
**Priority**: P0 - Critical Path

## Problem Statement

College recruiting currently exhibits O(N*M) complexity where:
- N = ~130 colleges
- M = ~2000 recruits per year
- Result: ~260,000 scout evaluations per year

This accounts for approximately 40-50% of total simulation time.

## Root Cause Analysis

In `scripts/pipelines/CollegeRecruiting.gd`:

```gdscript
for college in colleges:
    var board := _build_board(recruits, college, scout, ...)
    # _build_board iterates ALL recruits and scores each one
```

Each `_build_board` call:
1. Creates a new scout for the college
2. Scores every recruit using `scout.score_player()`
3. Sorts the full board
4. Slices to `board_limit` (typically 120)

## Proposed Solution

### Strategy 1: Pre-computed Baseline with Scout Deltas

Instead of N full evaluations, compute once and adjust:

```gdscript
# Phase 1: Compute baseline scores once (threaded)
var baseline_scores := _compute_all_baseline_scores(recruits, positions_cfg, class_rules)

# Phase 2: For each college, apply scout-specific adjustments
for college in colleges:
    var scout := _create_scout_for_college(college)
    var adjusted_scores := _apply_scout_deltas(baseline_scores, scout)
    var board := _sort_and_slice(adjusted_scores, board_limit)
```

**Implementation Details**:

1. **Baseline Score**: Pure rating based on player stats (no scout perception noise)
2. **Scout Delta**: Small adjustment based on scout preferences (valuation_multipliers)
3. **Perception Noise**: Applied only to top-N candidates if needed

### Strategy 2: Tiered Evaluation

Only fully evaluate top candidates:

```gdscript
# Tier 1: Quick score all recruits (simple weighted average)
var quick_scores := _quick_score_all(recruits)

# Tier 2: Full scout evaluation only for top 3*board_limit candidates
var top_candidates := _get_top_n(quick_scores, board_limit * 3)
var full_scores := _full_scout_evaluation(top_candidates, scout)

# Tier 3: Build final board from full_scores
var board := _sort_and_slice(full_scores, board_limit)
```

### Strategy 3: Parallel Board Building

Process multiple colleges in parallel:

```gdscript
var boards := ThreadPool.map(colleges, func(college):
    return _build_board_for_college(college, recruits, cached_baseline),
    threads
)
```

## Recommended Approach

Combine Strategies 1 and 3:

1. **Pre-compute baseline scores once** (already partially done with `_baseline_scores()`)
2. **Make scout adjustments lightweight** (multiply by preference weights, not full re-evaluation)
3. **Parallelize college processing** (independent boards can be built concurrently)
4. **Apply perception noise only at offer stage** (not during sorting)

## Implementation Plan

### Phase 1: Refactor _baseline_scores

**File**: `scripts/pipelines/CollegeRecruiting.gd`

```gdscript
func _baseline_scores(recruits: Array, positions_cfg: Dictionary, class_rules: Dictionary) -> Dictionary:
    # Already exists - enhance to include more pre-computed data
    var scores := {}
    var items := []
    items.resize(recruits.size())
    for i in range(recruits.size()):
        items[i] = {"index": i, "recruit": recruits[i]}

    # Parallel baseline computation
    var results := ThreadPool.map(items, func(item):
        var r: Dictionary = item["recruit"]
        var player_id := String(r.get("player_id", ""))
        var ratings: Dictionary = r.get("ratings", {}) as Dictionary
        var base_score := float(ratings.get("composite_score", 0.0))
        if base_score <= 0.0:
            var res := RecruitRater.compute(r, positions_cfg, {}, class_rules, {})
            base_score = float(res.get("composite", 0.0))
        return {"player_id": player_id, "base_score": base_score, "position": r.get("position", "")},
        _threads_count()
    )

    for result in results:
        scores[result["player_id"]] = result
    return scores
```

### Phase 2: Lightweight Scout Adjustment

Instead of full perception, apply weighted multipliers:

```gdscript
func _apply_scout_preferences(baseline: Dictionary, scout: Dictionary) -> float:
    var base := float(baseline.get("base_score", 50.0))
    var position := String(baseline.get("position", ""))

    # Scout has position preferences (from valuation_multipliers)
    var val_mult: Dictionary = scout.get("valuation_multipliers", {})
    var pos_mult := float(val_mult.get(position, 1.0))

    # Apply lightweight adjustment
    return base * pos_mult
```

### Phase 3: Parallel College Processing

```gdscript
func run(...) -> Dictionary:
    # Pre-compute baselines (single pass)
    var baseline_scores := _baseline_scores(recruits, positions_cfg, class_rules)

    # Parallel board building
    var college_items := []
    for college in colleges:
        college_items.append({
            "college": college,
            "seed": _rng_for(seed, String(college.get("id", ""))).seed
        })

    var boards := ThreadPool.map(college_items, func(item):
        return _build_board_lightweight(
            item["college"],
            recruits,
            baseline_scores,
            item["seed"],
            board_limit
        ),
        _threads_count()
    )

    # Merge results
    for i in range(colleges.size()):
        boards_by_college[colleges[i].get("id", "")] = boards[i]
```

## Determinism Preservation

**Critical**: Optimizations must preserve deterministic output.

1. **Seed derivation** must remain consistent (college-specific seeds)
2. **Sorting tiebreakers** must be stable (use player_id as secondary key)
3. **Parallel operations** must produce same results as serial

Verification:
```gdscript
# Before optimization
var result_before := recruiting.run(recruits, colleges, ..., seed, year)

# After optimization
var result_after := recruiting_optimized.run(recruits, colleges, ..., seed, year)

# Must be identical
assert_deep_equal(result_before.commitments, result_after.commitments)
```

## Test Coverage

**File**: `scripts/tests/test_recruiting_optimization.gd`

```gdscript
func _test_optimization_determinism(t):
    # Run both versions with same seed
    # Assert identical commitments
    pass

func _test_performance_improvement(t):
    # Time both versions
    # Assert optimized is at least 50% faster
    pass

func _test_board_equivalence(t):
    # Compare top-N of optimized boards to full evaluation
    # Assert high overlap (>95%)
    pass
```

## Acceptance Criteria

- [ ] College recruiting phase time reduced by 50%+
- [ ] Determinism preserved (identical commitments with same seed)
- [ ] All existing recruiting tests pass
- [ ] New performance tests added and passing
- [ ] No magic numbers (all thresholds configurable)

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Different results due to scout approximation | Use configurable "fidelity" mode that can fall back to full evaluation |
| Thread safety issues | Ensure all shared data is read-only; use seed derivation for RNG |
| Breaking existing tests | Run full test suite before/after; add regression tests |

## Files to Modify

- `scripts/pipelines/CollegeRecruiting.gd` - Main optimization target
- `scripts/generation/ScoutFactory.gd` - May need lightweight scout variant

## Files to Create

- `scripts/tests/test_recruiting_optimization.gd`

## Configuration Additions

Add to recruiting config:

```json
{
  "recruiting": {
    "optimization": {
      "use_lightweight_scoring": true,
      "quick_filter_multiplier": 3,
      "parallel_colleges": true
    }
  }
}
```

## Next Task

After completing F2, proceed to **TASK_F3_scout_caching.md** for further scout evaluation optimizations.
