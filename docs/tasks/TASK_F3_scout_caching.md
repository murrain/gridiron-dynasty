# Task F3: Scout Evaluation Caching

**Track**: Performance Optimization (Track F)
**Dependencies**: F2 (Recruiting Optimization)
**Status**: Not started
**Estimated Effort**: 1-2 days
**Priority**: P1 - High Impact

## Problem Statement

Scout evaluations are performed redundantly across multiple contexts:
1. College recruiting: Each college evaluates all recruits
2. NFL Draft: Each team scores the entire draft pool per pick
3. Multiple scouts may evaluate the same player with similar results

## Current Hot Path

In `scripts/core/scouting/ScoutRuntime.gd`:

```gdscript
static func score_player(scout, player, positions_data, stats_cfg, class_rules, rng) -> float:
    # 1. Deep copy player for perception
    var curr := _perceive(player, stats_cfg, ...)
    var pot := _perceive_potential(player, stats_cfg, ...)

    # 2. Blend current/potential
    var blended := _blend_stats(curr, pot, pot_bias)

    # 3. Apply valuation multipliers
    for k in blended["stats"].keys():
        ...

    # 4. Compute composite
    var res := RecruitRater.compute(blended, positions_data, {}, class_rules, {})
    return float(res.get("composite", 0.0))
```

**Problems**:
1. Two deep copies per call (`_perceive` and `_perceive_potential`)
2. No caching of intermediate results
3. `RecruitRater.compute()` called even if result would be similar

## Proposed Solution

### Layer 1: Immutable Player Hash

Create a stable hash for player state that invalidates cache:

```gdscript
static func _player_hash(player: Dictionary) -> int:
    var stats: Dictionary = player.get("stats", {})
    var potential: Dictionary = player.get("potential", {})
    var age := int(player.get("age", 0))
    var position := String(player.get("position", ""))

    # FNV-1a hash of key fields
    var key := "%s|%d|%.2f|%.2f" % [
        position,
        age,
        _stats_hash(stats),
        _stats_hash(potential)
    ]
    return _fnv1a_64(key)
```

### Layer 2: Scout-Agnostic Base Score Cache

Cache the "objective" player score before scout perception:

```gdscript
class ScoreCache:
    var _base_scores: Dictionary = {}  # player_hash -> base_score
    var _rated_players: Dictionary = {}  # player_hash -> rated_player_dict

    func get_base_score(player: Dictionary, positions_cfg: Dictionary, class_rules: Dictionary) -> float:
        var hash := _player_hash(player)
        if _base_scores.has(hash):
            return _base_scores[hash]

        var score := RecruitRater.compute(player, positions_cfg, {}, class_rules, {})
        _base_scores[hash] = float(score.get("composite", 0.0))
        return _base_scores[hash]
```

### Layer 3: Scout Perception Delta

Instead of full re-perception, compute scout-specific adjustment:

```gdscript
static func score_with_cache(
    scout: Dictionary,
    player: Dictionary,
    cache: ScoreCache,
    positions_cfg: Dictionary,
    class_rules: Dictionary,
    rng: RandomNumberGenerator
) -> float:
    # Get cached base score (most expensive part)
    var base := cache.get_base_score(player, positions_cfg, class_rules)

    # Apply scout-specific modifiers (cheap)
    var position := String(player.get("position", ""))
    var val_mult: Dictionary = scout.get("valuation_multipliers", {})
    var pos_pref := float(val_mult.get(position, 1.0))

    # Scout perception adds noise (cheap)
    var base_skill := float(scout.get("base_skill", 0.55))
    var noise_sigma := (1.0 - base_skill) * 5.0
    var noise := rng.randf_range(-noise_sigma, noise_sigma)

    return clamp(base * pos_pref + noise, 0.0, 100.0)
```

## NflDraft Specific Optimization

The draft has additional redundancy: each pick re-scores the entire pool.

```gdscript
# Current: O(rounds * teams * pool_size)
for round_num in range(1, rounds + 1):
    for team in sorted_teams:
        var scored_players := _score_draft_pool(remaining_pool, ...)  # Full re-evaluation
```

**Optimization**: Maintain sorted pool, only remove selected players:

```gdscript
# Optimized: O(pool_size * log(pool_size)) initial + O(picks) removals
var cache := ScoreCache.new()

# Pre-score all players once
var scored_pool := []
for player in draft_pool:
    scored_pool.append({
        "player": player,
        "base_score": cache.get_base_score(player, ...)
    })

# Sort once
scored_pool.sort_custom(func(a, b): return a.base_score > b.base_score)

# For each pick, apply team-specific need weighting to find best
for pick in total_picks:
    var team := _team_for_pick(pick)
    var needs := _calculate_position_needs(team_roster, positions_cfg)

    # Find best available (already sorted by base score)
    for candidate in scored_pool:
        var adjusted := candidate.base_score * needs.get(candidate.player.position, 1.0)
        # Select if above threshold
```

## Implementation Plan

### Phase 1: Create ScoreCache Class

**File**: `scripts/core/scouting/ScoreCache.gd`

```gdscript
class_name ScoreCache
extends RefCounted

var _base_scores: Dictionary = {}
var _player_ratings: Dictionary = {}
var _positions_cfg: Dictionary
var _class_rules: Dictionary

func _init(positions_cfg: Dictionary, class_rules: Dictionary) -> void:
    _positions_cfg = positions_cfg
    _class_rules = class_rules

func get_base_score(player: Dictionary) -> float:
    var hash := _player_hash(player)
    if _base_scores.has(hash):
        return _base_scores[hash]

    var result := RecruitRater.compute(player, _positions_cfg, {}, _class_rules, {})
    var score := float(result.get("composite", 0.0))
    _base_scores[hash] = score
    return score

func precompute_all(players: Array) -> void:
    # Parallel precomputation
    var items := []
    for p in players:
        items.append({"player": p, "hash": _player_hash(p)})

    var results := ThreadPool.map(items, func(item):
        if _base_scores.has(item.hash):
            return null
        var result := RecruitRater.compute(item.player, _positions_cfg, {}, _class_rules, {})
        return {"hash": item.hash, "score": float(result.get("composite", 0.0))},
        _threads_count()
    )

    for r in results:
        if r != null:
            _base_scores[r.hash] = r.score

func clear() -> void:
    _base_scores.clear()
    _player_ratings.clear()

static func _player_hash(player: Dictionary) -> int:
    var stats: Dictionary = player.get("stats", {})
    var position := String(player.get("position", ""))
    # Use composite_score if available (faster than hashing all stats)
    var cs := float(player.get("composite_score", -1.0))
    if cs >= 0.0:
        return hash("%s|%.4f" % [position, cs])
    # Fallback to core stats hash
    return hash("%s|%.4f" % [position, _core_avg(stats)])

static func _core_avg(stats: Dictionary) -> float:
    var total := 0.0
    var count := 0
    for v in stats.values():
        if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
            total += float(v)
            count += 1
    return total / max(1, count)
```

### Phase 2: Integrate with CollegeRecruiting

Modify `_build_board` to use cache:

```gdscript
func run(...) -> Dictionary:
    # Create cache once
    var cache := ScoreCache.new(positions_cfg, class_rules)
    cache.precompute_all(recruits)

    # Use cached scores in board building
    for college in colleges:
        var board := _build_board_with_cache(recruits, college, cache, ...)
```

### Phase 3: Integrate with NflDraft

Modify draft to pre-score once:

```gdscript
func run(...) -> Dictionary:
    var cache := ScoreCache.new(positions_cfg, class_rules)
    cache.precompute_all(draft_pool)

    # Build initial ranked pool
    var scored_pool := _score_pool_with_cache(draft_pool, cache)
    scored_pool.sort_custom(...)

    # Execute draft using pre-scored pool
    for pick in total_picks:
        var selection := _select_best_for_team(scored_pool, team, needs)
        scored_pool.erase(selection)
```

## Determinism Considerations

Cache introduces potential determinism issues:
1. **Hash collisions**: Use 64-bit FNV-1a to minimize
2. **Cache population order**: Use parallel precomputation with deterministic ordering
3. **RNG consumption**: Scout noise must consume RNG in consistent order

**Safeguard**: Cache key includes all fields that affect output. If player stats change, hash changes.

## Test Coverage

**File**: `scripts/tests/test_score_cache.gd`

```gdscript
func _test_cache_correctness(t):
    # Cached score matches uncached score
    pass

func _test_cache_hit_rate(t):
    # Verify cache is actually being used
    pass

func _test_hash_stability(t):
    # Same player produces same hash
    pass

func _test_determinism_with_cache(t):
    # Full simulation with cache matches without cache
    pass
```

## Acceptance Criteria

- [ ] ScoreCache class implemented with hash-based lookup
- [ ] CollegeRecruiting uses cache (50%+ speedup in recruiting phase)
- [ ] NflDraft uses cache (70%+ speedup in draft phase)
- [ ] Determinism preserved across all uses
- [ ] Cache hit rate > 90% in normal operation
- [ ] All tests pass

## Performance Targets

| Operation | Before | After | Improvement |
|-----------|--------|-------|-------------|
| College recruiting (per year) | ~15s | ~5s | 66% |
| NFL Draft (per year) | ~5s | ~1s | 80% |
| Total per year | ~36s | ~22s | 39% |

## Files to Create

- `scripts/core/scouting/ScoreCache.gd`
- `scripts/tests/test_score_cache.gd`

## Files to Modify

- `scripts/pipelines/CollegeRecruiting.gd`
- `scripts/world/NflDraft.gd`
- `scripts/core/scouting/ScoutRuntime.gd` (add cache-aware methods)

## Next Task

After completing F3, proceed to **TASK_F4_deep_copy_reduction.md** for reducing memory allocation overhead.
