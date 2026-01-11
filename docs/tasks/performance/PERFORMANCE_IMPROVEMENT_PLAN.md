# Performance Improvement Plan: 20-Year Bootstrap Simulation

**Document Version**: 1.0
**Date**: 2026-01-11
**Target**: Reduce 20-year bootstrap time from 158.49s to <90s
**Current Overage**: 68.49s (76% over budget)

---

## Executive Summary

### Current State
- **Performance**: 158.49 seconds (2.6 minutes)
- **Target**: <90 seconds
- **Time per year**: ~7.92 seconds
- **Context**: Phase 1 implementation added 17 features across 6 tracks

### Performance Budget Breakdown
Based on analysis of codebase and previous optimization work (F1-F6), estimated time allocation:

| Component | Est. Time | % of Total | Priority |
|-----------|-----------|------------|----------|
| Game Simulation (College + NFL) | ~50s | 32% | **High** |
| Player Stat Generation | ~35s | 22% | **High** |
| Player Lifecycle (Development) | ~25s | 16% | Medium |
| Award Selection (All-Pro/Pro Bowl) | ~20s | 13% | **High** |
| Player Morale Calculation | ~15s | 9% | Medium |
| Team History Aggregation | ~8s | 5% | Low |
| Other (Transfer Portal, etc.) | ~5s | 3% | Low |

### Key Findings

**Primary Bottlenecks Identified:**
1. **Stat Generation** (~35s): O(players × games) with 3-5 RNG calls per player per game
2. **Game Simulation** (~50s): Simulating ~21,000 games over 20 years
3. **Award Selection** (~20s): O(n log n) sorting of 1,700 NFL players × 20 years
4. **Player Morale** (~15s): 7,800 college players × 20 years = 156,000 calculations

**Root Causes:**
- Repeated roster traversals (multiple passes per team)
- Redundant calculations (team strengths, ratings)
- Expensive RNG-based stat generation
- Lack of caching for frequently accessed values
- Sequential processing where parallelization possible

### Projected Outcome
**Conservative estimate**: 110-120 seconds (30-40% reduction)
**Optimistic estimate**: 85-95 seconds (40-46% reduction)
**Aggressive estimate**: 70-80 seconds (50-56% reduction, requires significant refactoring)

Target of <90 seconds is **achievable** with Phase A + Phase B optimizations.

---

## Detailed Bottleneck Analysis

### 1. Stat Generation (StatGenerator.gd) - 35 seconds (~22%)

**Current Implementation:**
```gdscript
# For EACH game (21,000 games × 20 years):
for player in home_roster.players + away_roster.players:
    # 3-5 RNG calls per player
    stat_line = _generate_player_stats(player, ...)
    # Creates new Dictionary for every player
    all_stats[player_id] = stat_line
```

**Performance Issues:**
- **O(players × games)**: ~100 players per game × 21,000 games = 2.1M stat generations
- **RNG overhead**: 3-5 `randf()` calls per player = 6.3-10.5M RNG calls
- **Dictionary allocation**: 2.1M new dictionaries created
- **No caching**: Recalculates starter status, ratings for every game

**Specific Hotspots:**
- `StatGenerator._generate_qb_stats()`: 5 RNG calls (lines 346-376)
- `StatGenerator._generate_rb_stats()`: 4 RNG calls (lines 401-436)
- `StatGenerator._generate_wr_stats()`: 4 RNG calls (lines 453-484)
- `StatGenerator._determine_starters()`: O(n log n) sort per team per game (lines 193-234)

**Optimization Opportunities:**
1. **Cache starters per team-year** (not per game) → O(teams × years) instead of O(games)
2. **Pre-generate stat distributions** → Replace RNG with lookup tables
3. **Batch stat generation** → Process full roster at once, not per-player
4. **Reduce precision** → Use integer math where possible (performance > realism)
5. **Skip stats for bench players** → Generate only for starters (~30% of players)

---

### 2. Game Simulation (GameSimulator.gd) - 50 seconds (~32%)

**Current Implementation:**
```gdscript
# For EACH season (20 years):
for matchup in schedule:  # 1,050 games/year
    result = determine_winner(matchup, team_strengths, rng, cfg)
    accumulate_player_stats(world_state, result, home_roster, away_roster, ...)
```

**Performance Issues:**
- **21,000 total games**: (12 weeks × 65 college games/week + 17 weeks × 16 NFL games/week) × 20
- **Team strength recalculation**: Calculated once per season, but roster lookups expensive
- **Sequential game processing**: No parallelization (required for determinism)
- **Full stat accumulation**: Every player gets stats every game (see issue #1)

**Specific Hotspots:**
- `GameSimulator.calculate_team_strength()`: O(roster_size) per team (lines 46-73)
  - Called 2× per season (college + NFL) × 20 years = 40 calls
  - Each call processes 50-85 players
- `GameSimulator.accumulate_player_stats()`: Dominates time (lines 603-649)
  - Calls StatGenerator.generate_game_stats() for every game
  - Creates/updates dictionaries for all players

**Optimization Opportunities:**
1. **Cache team strengths per season** → Calculate once per team-year
2. **Batch game simulation** → Pre-generate all outcomes, then apply
3. **Lazy stat accumulation** → Only calculate when accessed (UI display)
4. **Simplify win probability** → Pre-computed lookup table vs. exp() call
5. **Parallel season simulation** → Simulate college/NFL concurrently (requires separate RNG streams)

---

### 3. Award Selection (AwardSelector.gd) - 20 seconds (~13%)

**Current Implementation:**
```gdscript
# For EACH year (20 years):
year_stats = _extract_year_stats(player_stats, year, ...)  # O(all_players)
opoy = select_offensive_player_of_year(year_stats)  # O(n log n) sort
dpoy = select_defensive_player_of_year(year_stats)  # O(n log n) sort
all_pro = select_all_pro_teams(year_stats)  # O(n log n) × positions
pro_bowl = select_pro_bowl_rosters(year_stats)  # O(n log n) × positions × conferences
```

**Performance Issues:**
- **Multiple full roster scans**: _extract_year_stats() touches every NFL player
- **Repeated sorting**: 4 individual awards + All-Pro (22 positions) + Pro Bowl (44 positions) = ~70 sorts
- **Score recalculation**: Each award recalculates player scores independently
- **No early termination**: Sorts entire roster even when only top 1-3 needed

**Specific Hotspots:**
- `AwardSelector._extract_year_stats()`: O(players × teams) roster traversal (line 102)
- `AwardSelector.select_all_pro_teams()`: 22 positions × 2 teams = 44 sorts
- `AwardSelector.select_pro_bowl_rosters()`: 44 positions × 2 conferences = 88 sorts
- `AwardSelector._calculate_offensive_score()`: Repeated stat lookups (custom scoring per position)

**Optimization Opportunities:**
1. **Single-pass ranking** → Calculate all scores once, use for all awards
2. **Heap-based selection** → O(n log k) instead of O(n log n) when k << n
3. **Position filtering** → Pre-filter by position before sorting
4. **Cache player scores** → Reuse scores across All-Pro/Pro Bowl selections
5. **Deferred award selection** → Only calculate awards when accessed by UI

---

### 4. Player Morale (PlayerMorale.gd) - 15 seconds (~9%)

**Current Implementation:**
```gdscript
# For EACH college team (130 teams × 20 years):
for college_id in rosters.keys():
    players = roster.get("players", [])  # ~60 players
    for player in players:
        satisfaction = calculate_satisfaction(player, year, player_stats, awards, team_record)
        morale = update_morale(player, satisfaction)
        player["satisfaction"] = satisfaction
        player["morale"] = morale
```

**Performance Issues:**
- **156,000 morale calculations**: 7,800 college players × 20 years
- **Repeated dictionary lookups**: player_stats, awards, season_records accessed per player
- **Award searching**: Linear search through awards structure for each player
- **Team record duplication**: Same team record passed to every player on team

**Specific Hotspots:**
- `PlayerMorale.calculate_satisfaction()`: 3 sub-calculations per player (lines 85-114)
- `PlayerMorale._calculate_awards_score()`: Multiple dictionary lookups (lines 181-200)
- `CollegeSeason._update_all_team_morale()`: O(teams × players) nested loop (lines 596-654)

**Optimization Opportunities:**
1. **Batch morale updates** → Process entire team at once with shared context
2. **Cache award lookups** → Build player_id → awards map once per year
3. **Pre-compute team success** → Calculate once per team, not per player
4. **Skip morale for non-eligibles** → Freshmen/backups have minimal impact
5. **Defer transfer portal** → Only calculate when actually needed

---

### 5. Player Lifecycle (PlayerLifecycle.gd) - 25 seconds (~16%)

**Current Implementation:**
```gdscript
# Uses parallel processing (F5 optimization)
PlayerLifecycle.advance_one_year_parallel(
    players, positions_cfg, main_cfg, stats_cfg, lifecycle_rng,
    development_context, threads=auto, options, dev_config, ret_config
)
```

**Performance Issues:**
- **Already optimized**: F5 (parallel processing) + F6 (config caching) applied
- **Remaining overhead**: Thread pool management, config deep copying (lines 123-130)
- **Development reports**: Generated even when unused (skip_reports flag exists but memory still allocated)

**Specific Hotspots:**
- `PlayerLifecycle.advance_one_year_parallel()`: Config deep copy per call (lines 123-130)
- `PlayerLifecycle._advance_player_one_year()`: Development report creation (even when skipped)

**Optimization Opportunities:**
1. **F7: Report deferral** → Already proposed, 5-10% memory + CPU savings
2. **Eliminate config deep copy** → Use immutable config objects
3. **Adjust parallel threshold** → Current PARALLEL_THRESHOLD = 100, may be suboptimal
4. **Lock-free data structures** → Reduce thread contention

---

### 6. Game Schedule Generation - 8 seconds (~5%)

**Current Implementation:**
```gdscript
# For EACH season (20 college + 20 NFL):
schedule = GameSimulator.generate_college_schedule(colleges, year, weeks, sim_seed)
# or
schedule = GameSimulator.generate_nfl_schedule(teams, regions, year, sim_seed)
```

**Performance Issues:**
- **Fisher-Yates shuffle**: O(n) per schedule generation (lines 276-278, 443)
- **Round-robin algorithm**: O(weeks × teams) = O(12 × 130) = 1,560 ops per college season
- **No schedule caching**: Same matchups regenerated each run (for different seeds)

**Optimization Opportunities:**
1. **Template-based schedules** → Generate once, permute with seed
2. **Pre-computed rotations** → Store round-robin rotations, apply dynamically
3. **Lazy schedule generation** → Only generate when games are simulated
4. **Parallel schedule generation** → Generate college/NFL concurrently

---

### 7. Team History Tracking - 5 seconds (~3%)

**Current Implementation:**
```gdscript
# For EACH season (40 calls: 20 college + 20 NFL):
_update_team_history(world_state, year, season_results, champion_id, ...)
    for team_id in season_results.keys():
        # Update wins, losses, streaks, championships
```

**Performance Issues:**
- **Minimal impact**: Already O(teams) per season
- **Simple aggregation**: No expensive calculations

**Optimization Opportunities:**
- **None recommended**: Not a bottleneck, optimizations would add complexity for minimal gain

---

## Prioritized Optimization Catalog

### Phase A: Quick Wins (<8 hours implementation, >10s savings each)

#### A1: Cache Starter Determination (15-20s savings)
**Impact**: High | **Complexity**: Low | **Risk**: Low

**Current**: Starters determined per-game in `StatGenerator._determine_starters()` (21,000 times)
**Target**: Cache starters per team-season (compute once per 200 teams × 20 years = 4,000 times)

**Implementation**:
1. Add `_starter_cache: Dictionary` to CollegeSeason/NflSeason
2. Compute starters once per team in `_simulate_*_season()`
3. Pass cached starters to `StatGenerator.generate_game_stats()`
4. Cache key: `"{team_id}_{year}"`

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/StatGenerator.gd` (lines 193-234)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd` (lines 456-575)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd` (lines 552-676)

**Expected reduction**: 20,000 O(n log n) sorts → 4,000 sorts = **15-20 seconds**

---

#### A2: Pre-compute Team Strengths per Season (8-12s savings)
**Impact**: Medium | **Complexity**: Low | **Risk**: Low

**Current**: Team strength calculated once per season, but roster lookups expensive
**Target**: Cache team strengths in world_state for entire season

**Implementation**:
1. Add `world_state["team_strengths"][year]` dictionary
2. Calculate all team strengths before schedule simulation
3. Pass cached strengths to game simulation loop
4. Invalidate cache on roster changes

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/GameSimulator.gd` (lines 46-73, 480-489)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd` (lines 480-489)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd` (lines 577-586)

**Expected reduction**: Eliminates redundant `PlayerRatingCalculator` calls = **8-12 seconds**

---

#### A3: Single-Pass Award Ranking (10-15s savings)
**Impact**: High | **Complexity**: Low | **Risk**: Low

**Current**: Multiple independent sorts for awards (70+ sorts per year)
**Target**: Single sort, extract top candidates for each award category

**Implementation**:
1. Create `_rank_all_players_once(year_stats)` function
2. Calculate composite score for each player (offensive/defensive)
3. Sort once by position groups
4. Extract award winners from pre-sorted lists

**Algorithm**:
```gdscript
# Single pass to rank all players
var ranked = {
    "offensive": {},  # position -> sorted array
    "defensive": {}   # position -> sorted array
}

for player in year_stats:
    score = _calculate_composite_score(player)
    ranked[category][position].append({player_id, score})

# Extract awards from ranked lists (no additional sorting)
opoy = ranked["offensive"]["QB"][0]  # Top QB
all_pro_qb = ranked["offensive"]["QB"][0:1]  # Top 1
pro_bowl_qb = ranked["offensive"]["QB"][0:3]  # Top 3
```

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/awards/AwardSelector.gd` (lines 87-151)

**Expected reduction**: 70 sorts → 1 sort per position = **10-15 seconds**

---

#### A4: Batch Morale Updates with Shared Context (8-10s savings)
**Impact**: Medium | **Complexity**: Low | **Risk**: Low

**Current**: Morale calculated per-player with repeated dictionary lookups
**Target**: Pre-compute team context, apply to all players on team

**Implementation**:
1. Extract team-level data once (team_record, awards, playoff status)
2. Build player_id → awards lookup map once per year
3. Batch-update all players on team with shared context
4. Eliminate redundant dictionary access

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/player_agency/PlayerMorale.gd` (lines 85-114)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd` (lines 596-654)

**Expected reduction**: 156,000 individual lookups → 2,600 batch lookups = **8-10 seconds**

---

### Phase B: Medium Effort (8-24 hours, >5s savings each)

#### B1: Stat Generation Lookup Tables (12-18s savings)
**Impact**: High | **Complexity**: Medium | **Risk**: Medium

**Current**: RNG-based stat generation (3-5 calls per player per game)
**Target**: Pre-generated stat distributions indexed by rating/win/starter

**Implementation**:
1. Generate stat tables at bootstrap (one-time cost)
2. Index by (position, rating_bucket, won, is_starter)
3. Replace RNG calls with table lookups
4. Add deterministic seed-based table selection

**Algorithm**:
```gdscript
# Pre-generate at bootstrap
const STAT_TABLES = {
    "QB": {
        "60_won_starter": [stat_line_1, stat_line_2, ...],
        "60_lost_bench": [stat_line_1, stat_line_2, ...],
        # ... 10 rating buckets × 2 outcomes × 2 starter status = 40 entries
    }
}

# At game time (fast lookup)
var bucket = _rating_bucket(player.rating)  # 50-59, 60-69, etc.
var key = "%s_%s_%s" % [bucket, "won" if won else "lost", "starter" if starter else "bench"]
var table = STAT_TABLES[position][key]
var index = (player_id.hash() + game_id.hash()) % table.size()
return table[index]  # No RNG calls!
```

**Trade-offs**:
- Pros: 6.3M RNG calls → 0 RNG calls, massive speedup
- Cons: Less variance (but statistically equivalent), memory overhead (~10MB tables)
- Risk: Requires careful validation to ensure statistical equivalence

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/StatGenerator.gd` (lines 298-323, 341-776)

**Expected reduction**: Eliminates 6.3M RNG calls = **12-18 seconds**

---

#### B2: Parallel Season Simulation (10-15s savings)
**Impact**: Medium | **Complexity**: Medium | **Risk**: Medium

**Current**: Sequential game simulation (deterministic but slow)
**Target**: Parallel simulation with independent RNG streams per season

**Implementation**:
1. Derive independent seeds for college/NFL seasons
2. Simulate college and NFL seasons concurrently
3. Use ThreadPool for parallel execution
4. Merge results after both complete

**Algorithm**:
```gdscript
# Parallel execution
var college_seed = Rand.splitmix64(seed ^ 0xC011E6E4)
var nfl_seed = Rand.splitmix64(seed ^ 0x5EA50004)

var results = ThreadPool.map([
    {"type": "college", "seed": college_seed, ...},
    {"type": "nfl", "seed": nfl_seed, ...}
], func(item):
    if item["type"] == "college":
        return _simulate_college_season(...)
    else:
        return _simulate_nfl_season(...)
, 2)  # 2 threads
```

**Trade-offs**:
- Pros: 2x speedup for season simulation phase
- Cons: Requires independent RNG streams, more complex debugging
- Risk: Must ensure determinism with parallel execution

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd` (lines 456-575)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd` (lines 552-676)

**Expected reduction**: 50% of season simulation time = **10-15 seconds**

---

#### B3: Heap-Based Award Selection (5-8s savings)
**Impact**: Low-Medium | **Complexity**: Medium | **Risk**: Low

**Current**: Full O(n log n) sort for every award selection
**Target**: Heap-based O(n log k) selection where k << n

**Implementation**:
1. Replace `Array.sort_custom()` with min-heap for top-k selection
2. For OPOY/DPOY: Select top 1 from ~1,000 candidates
3. For All-Pro: Select top 1-5 per position from ~100 candidates
4. For Pro Bowl: Select top 2-4 per position per conference

**Algorithm**:
```gdscript
# Instead of full sort:
candidates.sort_custom(func(a, b): return a["score"] > b["score"])
winner = candidates[0]

# Use heap-based selection:
var heap = MinHeap.new(k)
for candidate in candidates:
    heap.push(candidate.score, candidate)
return heap.get_top_k()
```

**Trade-offs**:
- Pros: O(n log k) vs O(n log n), significant for large rosters
- Cons: More complex code, need heap implementation
- Risk: Low (well-established algorithm)

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/awards/AwardSelector.gd` (lines 163-193, 196-240)

**Expected reduction**: Faster award selection = **5-8 seconds**

---

#### B4: Lazy Stat Accumulation (8-12s savings)
**Impact**: Medium | **Complexity**: Medium | **Risk**: Medium

**Current**: Stats accumulated for every player every game
**Target**: Only accumulate stats when accessed (UI display, awards)

**Implementation**:
1. Add `generate_stats: bool = false` flag to game simulation
2. Store game results without player stats during bootstrap
3. Reconstruct stats on-demand from game results when needed
4. Cache reconstructed stats for UI access

**Trade-offs**:
- Pros: Eliminates stat generation during bootstrap
- Cons: Need to regenerate for historical lookups, more complex stat access
- Risk: Medium (requires careful API design)

**Files**:
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/GameSimulator.gd` (lines 603-649)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd` (lines 509-525)
- `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd` (lines 605-621)

**Expected reduction**: Skip stat generation during bootstrap = **8-12 seconds**

---

### Phase C: Complex Optimizations (>24 hours, any savings)

#### C1: GPU-Accelerated Stat Calculations (20-30s savings)
**Impact**: High | **Complexity**: Very High | **Risk**: High

**Description**: Offload stat generation and rating calculations to GPU compute shaders

**Implementation**:
1. Convert stat generation formulas to GLSL compute shaders
2. Batch all players per game into GPU buffers
3. Execute parallel stat generation on GPU
4. Read results back to CPU

**Trade-offs**:
- Pros: Massive parallelization (1000s of threads)
- Cons: Requires GPU support, complex debugging, platform-specific
- Risk: High (new technology, determinism challenges)

**Not Recommended for Phase 1**: Too complex, high risk

---

#### C2: Incremental World State (15-25s savings)
**Impact**: Medium-High | **Complexity**: Very High | **Risk**: High

**Description**: Delta-based world state updates instead of full dictionary copies

**Implementation**:
1. Implement copy-on-write data structures
2. Track modifications per phase
3. Only copy modified branches of world_state
4. Merge deltas at phase boundaries

**Trade-offs**:
- Pros: Reduces memory allocations, faster cloning
- Cons: Complex implementation, harder debugging
- Risk: High (fundamental architecture change)

**Not Recommended for Phase 1**: Too complex, architectural change

---

#### C3: Custom Player Struct (8-12s savings)
**Impact**: Low-Medium | **Complexity**: Very High | **Risk**: High

**Description**: Replace Dictionary with custom C++ struct for players

**Implementation**:
1. Create GDExtension for Player struct
2. Replace Dictionary access with member access
3. Optimize memory layout for cache efficiency
4. Provide Dictionary compatibility layer

**Trade-offs**:
- Pros: Faster access, less memory, better cache locality
- Cons: Requires GDExtension, loses Dictionary flexibility
- Risk: High (requires C++ expertise)

**Not Recommended for Phase 1**: Too complex, fundamental change

---

## Implementation Roadmap

### Phase A: Quick Wins (Target: 40-50s savings, 2-3 weeks)

**Week 1:**
- [ ] **A1: Cache Starter Determination** (3 days)
  - Day 1: Implement cache in CollegeSeason
  - Day 2: Implement cache in NflSeason
  - Day 3: Test determinism + benchmark

- [ ] **A2: Pre-compute Team Strengths** (2 days)
  - Day 1-2: Implement caching + validation

**Week 2:**
- [ ] **A3: Single-Pass Award Ranking** (3 days)
  - Day 1: Design ranking algorithm
  - Day 2: Implement + refactor AwardSelector
  - Day 3: Test determinism + validate award correctness

- [ ] **A4: Batch Morale Updates** (2 days)
  - Day 1-2: Refactor morale calculation + benchmark

**Week 3:**
- [ ] **Integration & Validation** (5 days)
  - Comprehensive determinism testing
  - Full 20-year bootstrap benchmarks
  - Regression testing (ensure no feature breakage)
  - Performance profiling to identify remaining bottlenecks

**Expected Result**: 110-120 seconds (30-40% reduction)

---

### Phase B: Medium Effort (Target: 20-30s additional savings, 3-4 weeks)

**Only pursue if Phase A doesn't achieve <90s target**

**Week 1-2:**
- [ ] **B1: Stat Generation Lookup Tables** (8 days)
  - Days 1-3: Generate stat distribution tables
  - Days 4-5: Implement table lookup system
  - Days 6-8: Validate statistical equivalence + determinism

**Week 3:**
- [ ] **B2: Parallel Season Simulation** (5 days)
  - Days 1-2: Implement parallel execution
  - Days 3-5: Test determinism + benchmark

**Week 4:**
- [ ] **B3: Heap-Based Award Selection** (3 days)
  - Implement MinHeap class + integrate

- [ ] **Integration & Validation** (2 days)

**Expected Result**: 85-95 seconds (40-46% reduction)

---

### Phase C: Complex Optimizations (Not Recommended)

**Only pursue if Phase A + B fail to achieve target**

These optimizations require >24 hours each and involve significant architectural changes. Risk vs. reward ratio is poor for current performance target.

**Recommendation**: If Phase B doesn't achieve <90s, re-evaluate performance budget rather than pursue Phase C optimizations.

---

## Performance Projections

### Conservative Estimate (Phase A Only)
| Optimization | Current | After | Savings |
|--------------|---------|-------|---------|
| Starter Cache (A1) | 35s | 18s | **17s** |
| Team Strength Cache (A2) | 50s | 40s | **10s** |
| Single-Pass Awards (A3) | 20s | 8s | **12s** |
| Batch Morale (A4) | 15s | 7s | **8s** |
| Other (unchanged) | 38.49s | 38.49s | 0s |
| **Total** | **158.49s** | **111.49s** | **47s (30%)** |

**Outcome**: Still ~21s over target, proceed to Phase B

---

### Optimistic Estimate (Phase A + B Partial)
| Optimization | Current | After | Savings |
|--------------|---------|-------|---------|
| Phase A (above) | 158.49s | 111.49s | 47s |
| Stat Lookup Tables (B1) | 35s | 22s | **13s** |
| Parallel Seasons (B2) | 50s | 40s | **10s** |
| Other (unchanged) | 38.49s | 38.49s | 0s |
| **Total** | **158.49s** | **88.49s** | **70s (44%)** |

**Outcome**: **Achieves <90s target** ✓

---

### Aggressive Estimate (Phase A + B Full)
| Optimization | Current | After | Savings |
|--------------|---------|-------|---------|
| Phase A (above) | 158.49s | 111.49s | 47s |
| Stat Lookup Tables (B1) | 35s | 20s | **15s** |
| Parallel Seasons (B2) | 50s | 38s | **12s** |
| Heap Awards (B3) | 20s | 14s | **6s** |
| Lazy Stats (B4) | 35s | 25s | **10s** |
| Other (unchanged) | 18.49s | 18.49s | 0s |
| **Total** | **158.49s** | **73.49s** | **85s (54%)** |

**Outcome**: Exceeds target with 16.5s margin

---

## Risk Assessment

### Low Risk (Safe to Implement)
- **A1-A4**: All Phase A optimizations are low-risk
  - Well-understood caching patterns
  - No algorithmic changes
  - Easy to validate determinism

### Medium Risk (Careful Validation Required)
- **B1**: Stat lookup tables
  - Risk: Statistical distribution drift
  - Mitigation: Comprehensive validation suite comparing distributions

- **B2**: Parallel season simulation
  - Risk: Determinism breakage
  - Mitigation: Independent RNG streams, extensive testing

### High Risk (Not Recommended)
- **C1-C3**: All Phase C optimizations
  - Architectural changes
  - Platform dependencies
  - Complex debugging

---

## Validation Strategy

### Per-Optimization Validation
For each optimization:

1. **Determinism Test** (CRITICAL):
   ```gdscript
   var seed = 0xBEEF_2026
   var result1 = bootstrap_20_years(seed)
   var result2 = bootstrap_20_years(seed)
   assert(result1 == result2, "Determinism broken!")
   ```

2. **Performance Benchmark**:
   ```bash
   godot --headless -s res://scripts/tests/BenchmarkRunner.gd
   ```

3. **Regression Testing**:
   - All existing tests must pass
   - Statistical validation (award distributions, player stats)
   - Spot-check key entities (ensure correctness)

### Integration Validation

After completing Phase A or B:

1. **Full 20-year bootstrap** with determinism check
2. **Statistical validation** of key metrics:
   - Award winner distributions (should match historical patterns)
   - Player stat distributions (mean, std dev, percentiles)
   - Team success patterns (championships, playoffs)
3. **Memory profiling** to ensure no regressions
4. **Comparison to baseline** (pre-optimization)

---

## Measurement & Monitoring

### Key Performance Indicators

Track these metrics before/after each optimization:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Total bootstrap time | <90s | BenchmarkRunner |
| Stat generation time | <20s | Phase timing capture |
| Game simulation time | <35s | Phase timing capture |
| Award selection time | <8s | Phase timing capture |
| Player morale time | <7s | Phase timing capture |
| Memory usage | <200MB/year | Process memory sampling |

### Profiling Tools

1. **BenchmarkRunner** (`scripts/tests/BenchmarkRunner.gd`)
   - Full 20-year bootstrap with phase breakdowns
   - Automated comparison to baseline

2. **Phase Timing Capture** (P1 implementation)
   - Per-phase microsecond timing
   - Aggregated totals across 20 years

3. **Manual Profiling** (if needed)
   ```gdscript
   var start = Time.get_ticks_usec()
   # ... operation ...
   var elapsed = (Time.get_ticks_usec() - start) / 1_000_000.0
   print("Elapsed: %.2f seconds" % elapsed)
   ```

---

## Dependencies & Prerequisites

### Required for Phase A
- [x] BenchmarkRunner (F8 complete)
- [x] Phase timing capture (P1 complete)
- [x] Baseline benchmark data
- [ ] Determinism test harness (recommended to add)

### Required for Phase B
- [ ] Statistical validation suite (for B1)
- [ ] Parallel execution framework (ThreadPool already exists)
- [ ] Heap data structure (for B3)

---

## Decision Gates

### After Phase A (Week 3)
**Decision**: Continue to Phase B or stop?

**Continue if**:
- Total time >90s after Phase A
- Phase A optimizations validated successfully
- Budget available for Phase B

**Stop if**:
- Total time <90s (target achieved!)
- Unacceptable determinism breakage
- Phase A took significantly longer than estimated

### After Phase B (Week 7)
**Decision**: Continue to Phase C or stop?

**Continue if**:
- Total time >90s after Phase B (unlikely)
- Critical performance requirement (e.g., mobile deployment)

**Stop if**:
- Total time <90s (very likely)
- Phase C complexity outweighs benefits

---

## Success Criteria

### Minimum Acceptable (Phase A)
- ✅ 20-year bootstrap: <120s (25% reduction)
- ✅ All tests pass (no regressions)
- ✅ Determinism preserved (same seed = same output)

### Target (Phase A + B Partial)
- ✅ 20-year bootstrap: <90s (43% reduction)
- ✅ All tests pass (no regressions)
- ✅ Determinism preserved (same seed = same output)
- ✅ Memory usage: <200MB/year (no regression)

### Stretch (Phase A + B Full)
- ✅ 20-year bootstrap: <75s (53% reduction)
- ✅ All tests pass (no regressions)
- ✅ Determinism preserved (same seed = same output)
- ✅ Statistical equivalence validated (award/stat distributions)

---

## Appendix A: Code Locations

### Primary Bottleneck Files

1. **StatGenerator.gd** (776 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/StatGenerator.gd`
   - Key functions:
     - `generate_game_stats()` (lines 85-122)
     - `_determine_starters()` (lines 193-234)
     - `_generate_qb_stats()` (lines 341-385)
     - `_generate_rb_stats()` (lines 397-436)

2. **GameSimulator.gd** (705 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/game_simulation/GameSimulator.gd`
   - Key functions:
     - `calculate_team_strength()` (lines 46-73)
     - `determine_winner()` (lines 161-213)
     - `accumulate_player_stats()` (lines 603-649)

3. **AwardSelector.gd** (736 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/awards/AwardSelector.gd`
   - Key functions:
     - `select_all_awards()` (lines 87-151)
     - `_extract_year_stats()` (around line 102)
     - `select_all_pro_teams()` (referenced)
     - `select_pro_bowl_rosters()` (referenced)

4. **PlayerMorale.gd** (estimated ~400 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/core/player_agency/PlayerMorale.gd`
   - Key functions:
     - `calculate_satisfaction()` (lines 85-114)
     - `_calculate_awards_score()` (lines 181-200)

5. **CollegeSeason.gd** (710 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/CollegeSeason.gd`
   - Key functions:
     - `_simulate_college_season()` (lines 456-575)
     - `_update_all_team_morale()` (lines 596-654)

6. **NflSeason.gd** (676 lines)
   - Path: `/home/patrick/Documents/code/gridiron-dynasty/scripts/world/NflSeason.gd`
   - Key functions:
     - `_simulate_nfl_season()` (lines 552-676)

---

## Appendix B: Optimization Patterns

### Pattern 1: Caching vs. Recomputation
**When to cache**:
- Computation is expensive (O(n log n) or worse)
- Result is reused multiple times
- Cache invalidation is simple

**When NOT to cache**:
- Computation is cheap (O(1) or O(log n))
- Cache overhead exceeds computation cost
- Complex invalidation logic required

### Pattern 2: Batch Processing
**Benefits**:
- Reduces per-item overhead
- Enables shared context optimization
- Improves cache locality

**Example**: Morale updates
```gdscript
# Bad: Per-player lookups
for player in team:
    record = season_records[team_id]  # Repeated lookup
    update_morale(player, record)

# Good: Batch with shared context
record = season_records[team_id]  # Single lookup
for player in team:
    update_morale(player, record)
```

### Pattern 3: Lazy Evaluation
**When to use**:
- Data is expensive to compute
- Data is infrequently accessed
- Can defer without breaking dependencies

**Example**: Award selection
```gdscript
# Eager (current): Always computed
select_all_awards(world_state, year)

# Lazy (deferred): Computed on access
if ui_requests_awards:
    select_all_awards(world_state, year)
```

---

## Appendix C: Rejected Optimizations

### R1: Skip Stat Generation Entirely
**Why Rejected**: Awards system depends on stats, can't skip

### R2: Reduce Game Count
**Why Rejected**: Breaks league simulation realism, not acceptable

### R3: Simplify Player Lifecycle
**Why Rejected**: Already optimized (F5 + F6), minimal remaining gains

### R4: Remove Morale System
**Why Rejected**: Core feature (PA6 track), not negotiable

### R5: Database-Backed World State
**Why Rejected**: Adds complexity, I/O overhead likely exceeds in-memory cost

---

## Appendix D: Historical Context

### Previous Optimization Efforts (January 2026)

**F1-F6 Achievements**:
- Bootstrap time: 12 minutes → 30 seconds (96% reduction)
- Memory usage: 2.27 GB → 154 MB (93% reduction)

**Key Techniques Used**:
1. **F2**: Recruiting O(N×M) → O(N+M) (70% reduction)
2. **F4**: Eliminated redundant deep copies (90% memory reduction)
3. **F5**: Parallel lifecycle processing (2x speedup)
4. **F6**: Config caching (10x faster access)

**Why Current Performance Lower**:
- Phase 1 added game simulation (21,000 games)
- Added stat generation for all players
- Added award selection (All-Pro, Pro Bowl)
- Added morale system (156,000 calculations)
- Added team history tracking

**Lesson Learned**: Each feature has cumulative performance cost. Current 158.49s is expected given scope increase.

---

**Document End**

**Next Steps**:
1. Review and approve this plan
2. Establish baseline benchmark (run BenchmarkRunner)
3. Begin Phase A implementation
4. Track progress against projected timelines
5. Iterate based on actual results
