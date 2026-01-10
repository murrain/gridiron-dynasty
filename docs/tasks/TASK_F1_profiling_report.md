# Task F1: Performance Profiling Report and Analysis

**Track**: Performance Optimization (Track F)
**Dependencies**: None (foundational analysis task)
**Status**: Completed
**Date**: 2026-01-10

## Executive Summary

The world bootstrapping simulation (20 years) takes approximately 36+ seconds per year in the current implementation, resulting in a full bootstrap time exceeding 10+ minutes. This analysis identifies key bottlenecks and proposes targeted optimizations.

## Profiling Methodology

### Test Environment
- Godot 4.5-stable (headless)
- Bootstrap Preview scene with 20-year simulation
- Default configuration (2000 players/class)

### Observations

Running `bootstrap_preview.tscn` in headless mode:
- Years 2006-2010 (5 years) completed in ~180 seconds before timeout
- **Average time per year: ~36 seconds**
- **Estimated full 20-year bootstrap: 12+ minutes**

## Identified Bottlenecks

### 1. College Recruiting (Critical - O(N*M) Complexity)

**File**: `scripts/pipelines/CollegeRecruiting.gd`

**Problem**: For each college (N colleges), the system builds a recruitment board by scoring all recruits (M recruits). This creates O(N*M) scout evaluations.

```
Recruits per year: ~2000
Colleges: ~130
Scout evaluations per year: ~260,000
```

**Key Code Path**:
```gdscript
for college in colleges:
    var board := _build_board(recruits, college, scout, ...)  # Scores ALL recruits
```

**Impact**: This is the most expensive operation, running scout perception + rating calculations for every recruit-college combination.

### 2. DraftClassGenerator Player Creation (Medium)

**File**: `scripts/generation/DraftClassGenerator.gd`

**Problem**: While already using ThreadPool for parallelization, several operations are performed sequentially:
- `_rate_and_rank(players)` - Single-threaded cohort percentile calculations
- `_copy_potential_to_baseline(players)` - Deep copies 2000 player dictionaries
- `_de_age_players(players, ...)` - Additional deep copies

**Impact**: 2000 players * complex rating calculations per year

### 3. PlayerLifecycle.advance_one_year (Medium)

**File**: `scripts/world/PlayerLifecycle.gd`

**Problem**: Called multiple times per year across different contexts:
- HighSchoolSeason: ~2000-8000 players (grows over years)
- CollegeSeason: ~650+ players per college roster (iterates all colleges)
- NflSeason: ~1600+ NFL players

**Key Costs**:
- `_apply_development()` - Per-stat calculations with config lookups
- `player.duplicate(true)` - Deep copies for each player advancement
- Development report accumulation in player dictionaries

### 4. NflDraft Player Scoring (Medium)

**File**: `scripts/world/NflDraft.gd`

**Problem**: Each pick requires re-scoring the entire remaining draft pool:
```gdscript
for round_num in range(1, rounds + 1):        # 7 rounds
    for team in sorted_teams:                  # 32 teams
        var scored_players := _score_draft_pool(remaining_pool, ...)  # ~200+ players
```

**Calculations per draft**: 7 * 32 * ~200 = ~44,800 scout evaluations

### 5. ScoutRuntime.score_player (Hot Path)

**File**: `scripts/core/scouting/ScoutRuntime.gd`

**Problem**: Called from multiple contexts (college recruiting, NFL draft). Each call:
- Deep copies player dictionary (twice for current + potential perception)
- Iterates all stats in stats_cfg
- Calls RecruitRater.compute()

### 6. Config Loading Overhead (Low)

**File**: `autoloads/Config.gd`

**Observation**: Config loading is cached, but `_get_config()` is called repeatedly throughout phases. The caching works, but dictionary accesses add up.

### 7. Dictionary Deep Copies (Pervasive)

**Problem**: Extensive use of `player.duplicate(true)` throughout the codebase to maintain immutability. While safe, this creates significant memory allocation and copy overhead.

**Examples**:
- `_apply_development_context()` in HighSchoolSeason, CollegeSeason, NflSeason
- `_perceive()` in ScoutRuntime
- Every PlayerLifecycle advancement

## Data Flow Analysis

### Current Pipeline Order (Per Year)

```
Phase                    | Est. Time | Cumulative Players
-------------------------|-----------|--------------------
1. hs_generation         | ~2s       | +2000 HS
2. hs_assignment         | ~1s       |
3. hs_season             | ~3s       | (lifecycle for all HS)
4. college_generation    | <1s       | (one-time setup)
5. nfl_team_generation   | <1s       | (one-time setup)
6. college_recruiting    | ~15s      | MAJOR BOTTLENECK
7. college_season        | ~5s       | (lifecycle for all college)
8. draft_prep            | <1s       | (stub only)
9. nfl_draft             | ~5s       |
10. cap_validation       | <1s       |
11. nfl_season           | ~4s       | (lifecycle for all NFL)
```

### Memory Growth Pattern

Year-over-year, the `world_state` dictionary accumulates:
- `hs_players`: Capped at ~4000 (4 years of classes, 1000/year active)
- `college_rosters`: ~130 colleges * ~85 players = ~11,000 players
- `nfl_rosters`: 32 teams * 53 players = ~1,700 players
- `retired_players`: Grows unbounded (~100-200/year after stabilization)
- `draft_pool`, `hs_recruit_pool`: Keyed by year (grows)

## Architectural Concerns

### 1. Immutable Data Pattern Overhead
The codebase uses `player.duplicate(true)` extensively for safety. This is architecturally sound but expensive. Consider:
- Copy-on-write semantics
- Selective deep copying (only modified fields)

### 2. Missing Index Structures
- Recruits are searched linearly in college recruiting
- No caching of expensive computations (scout scores, ratings)

### 3. Scout Evaluation Redundancy
- Same recruit evaluated by multiple scouts without caching base scores
- `_baseline_scores()` partially addresses this but scout-specific evaluations still O(N*M)

### 4. Development Report Accumulation
- `development_report` array in each player grows unbounded
- Not used during simulation (only for UI/debugging)
- Could be computed on-demand or capped

## Recommendations Priority

| Priority | Optimization | Est. Impact | Complexity |
|----------|--------------|-------------|------------|
| P0 | Cache/prune college recruiting | 50-70% time reduction | Medium |
| P1 | Lazy evaluation for scout scores | 20-30% time reduction | Medium |
| P2 | Reduce deep copies | 10-20% time reduction | Low |
| P3 | Parallel PlayerLifecycle per team | 10-15% time reduction | Medium |
| P4 | Development report deferral | Memory + 5% time | Low |
| P5 | Early binding of config lookups | 5-10% time reduction | Low |

## Success Metrics

Target: Reduce full 20-year bootstrap from 12+ minutes to under 3 minutes.

| Metric | Current | Target |
|--------|---------|--------|
| Per-year simulation | ~36s | <9s |
| 20-year bootstrap | ~12min | <3min |
| Memory peak | TBD | <2GB |

## Next Steps

Proceed to TASK_F2_recruiting_optimization.md for the highest-impact optimization.
