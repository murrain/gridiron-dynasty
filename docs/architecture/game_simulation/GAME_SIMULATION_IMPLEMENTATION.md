# Game Simulation Implementation Plan

**Task ID**: GAME_SIM_1 (Phase 1 - MVP)
**Dependencies**: None (integrates with existing systems)
**Estimated Effort**: 5-7 days
**Priority**: Medium
**Status**: Design Phase

---

## Goal

Implement Phase 1 (MVP) of the game simulation system that generates realistic season outcomes for college and NFL levels during 20-year world bootstrapping. The system must be deterministic, performant (<10% bootstrap overhead), and architecturally coherent with existing simulation patterns.

---

## Motivation

Currently, the simulation tracks player development through high school, college, and NFL but does not simulate actual games. This means:

1. **No historical context**: Cannot query "Who won the championship in 2020?"
2. **Missing realism**: Teams have rosters but no win/loss records
3. **Incomplete world state**: Recruiting and draft occur without competitive history
4. **Limited future features**: Cannot implement coaching changes, rivalry tracking, or playoff scenarios

Game simulation provides the foundation for:
- Historical championship tracking
- Player legacy metrics (championships won, playoff appearances)
- Recruiting bonuses for successful programs
- Draft stock influenced by team performance
- UI features (season records, championship history)

---

## Implementation Phases

### Phase 1: MVP (This Task)

**Scope**: Simple probabilistic winner determination with aggregated results.

**Features**:
- Fixed round-robin schedules (no conference logic)
- Team strength = mean roster rating
- Win probability from logistic curve (accounts for home advantage)
- Store W/L records per team per year
- Integrate into existing CollegeSeason and NflSeason

**Constraints**:
- No detailed play-by-play
- No per-player game stats
- No conference championships or playoffs
- No score generation (just W/L)

**Target**: <5% bootstrap overhead, >95% determinism (same seed = same results)

### Phase 2: Conference-Aware (Future)

**Scope**: Realistic schedules with conference structure, playoffs, bowl games.

**Not in this task**.

### Phase 3: Player Integration (Future)

**Scope**: Development bonuses for winning teams, performance tracking.

**Not in this task**.

### Phase 4: Parallelization (Future)

**Scope**: Week-level parallel execution for performance.

**Not in this task**.

---

## File Structure

### New Files

```
scripts/
└── world/
    └── GameSimulator.gd         # NEW: Pure game simulation functions

scripts/tests/
└── test_game_simulator.gd       # NEW: Unit tests for game simulation
└── test_season_simulation.gd    # NEW: Integration tests
└── benchmark/
    └── benchmark_game_sim.gd    # NEW: Performance benchmarks
```

### Modified Files

```
scripts/world/CollegeSeason.gd   # Add _simulate_season() method
scripts/world/NflSeason.gd       # Add _simulate_nfl_season() method

configs/sports/american_football/world/colleges.json  # Add game_simulation section
configs/sports/american_football/world/league.json    # Add game_simulation section
```

### Documentation

```
docs/architectural_notes/GAME_SIMULATION_ARCHITECTURE.md  # COMPLETE
docs/tasks/GAME_SIMULATION_IMPLEMENTATION.md              # THIS FILE
docs/tasks/GAME_SIMULATION_SPECS.md                       # NEXT: Technical specs
```

---

## Implementation Steps

### Step 1: Create GameSimulator Class (1 day)

**File**: `scripts/world/GameSimulator.gd`

**Purpose**: Pure functions for schedule generation, team strength calculation, winner determination, and result aggregation.

**Interface**:

```gdscript
extends RefCounted
class_name GameSimulator

## Calculates team strength from roster (Phase 1: mean rating)
static func calculate_team_strength(
  roster: Dictionary,
  positions_cfg: Dictionary,
  main_cfg: Dictionary
) -> float:
  # Implementation in SPECS doc
  pass

## Calculates win probability using logistic curve
static func calculate_win_probability(
  team_a_strength: float,
  team_b_strength: float,
  is_home: bool,
  cfg: Dictionary
) -> float:
  # Implementation in SPECS doc
  pass

## Determines winner for a single game
static func determine_winner(
  game_matchup: Dictionary,
  team_strengths: Dictionary,
  rng: RandomNumberGenerator,
  cfg: Dictionary
) -> Dictionary:
  # Returns GameResult dictionary
  # Implementation in SPECS doc
  pass

## Generates round-robin schedule for college (simplified)
static func generate_college_schedule(
  colleges: Array,
  year: int,
  weeks: int,
  seed: int
) -> Array[Dictionary]:
  # Returns array of game matchups
  # Implementation in SPECS doc
  pass

## Generates simplified NFL schedule
static func generate_nfl_schedule(
  teams: Array,
  divisions: Array,
  year: int,
  seed: int
) -> Array[Dictionary]:
  # Returns array of game matchups
  # Implementation in SPECS doc
  pass

## Aggregates game results into season records
static func aggregate_season_results(
  game_results: Array[Dictionary],
  team_ids: Array
) -> Dictionary:
  # Returns {team_id: SeasonRecord}
  # Implementation in SPECS doc
  pass
```

**Key Design Points**:
- All functions are `static` (no instance state)
- RNG explicitly passed (no hidden randomness)
- Pure functions (no side effects, same inputs = same outputs)
- Config-driven parameters (no magic numbers)

### Step 2: Integrate with CollegeSeason (1 day)

**File**: `scripts/world/CollegeSeason.gd`

**Changes**:

1. Add simulation method:

```gdscript
## Simulates college season and returns aggregated results
## RNG consumption: 1 call per game (randf in determine_winner)
func _simulate_season(
  world_state: Dictionary,
  year: int,
  seed: int,
  config: Dictionary
) -> Dictionary:
  var game_sim_cfg: Dictionary = config.get("game_simulation", {})
  if not bool(game_sim_cfg.get("enabled", false)):
    return {}  # Simulation disabled

  var colleges: Array = world_state.get("colleges", [])
  var rosters: Dictionary = world_state.get("college_rosters", {})
  var positions_cfg: Dictionary = _get_config().get_config("positions")
  var main_cfg: Dictionary = _get_config().get_config("main")

  # Calculate team strengths (expensive, cache results)
  var team_strengths := {}
  for college in colleges:
    var c: Dictionary = college
    var college_id := String(c.get("id", ""))
    if rosters.has(college_id):
      var roster: Dictionary = rosters[college_id]
      var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
      team_strengths[college_id] = strength

  # Generate schedule
  var weeks := int(game_sim_cfg.get("regular_season_weeks", 12))
  var schedule := GameSimulator.generate_college_schedule(colleges, year, weeks, seed)

  # Simulate games week by week (sequential for RNG determinism)
  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  var all_results: Array[Dictionary] = []

  for week in range(1, weeks + 1):
    var week_matchups := _filter_week(schedule, week)
    for matchup in week_matchups:
      var result := GameSimulator.determine_winner(matchup, team_strengths, rng, game_sim_cfg)
      all_results.append(result)

  # Aggregate results
  var college_ids := colleges.map(func(c): return String(c.get("id", "")))
  var season_results := GameSimulator.aggregate_season_results(all_results, college_ids)

  return season_results
```

2. Integrate into `run()` method:

```gdscript
func run(world_state: Dictionary, year: int, seed: int, config: Dictionary, ...) -> Dictionary:
  # ... existing roster loading ...

  # NEW: Simulate season BEFORE player lifecycle
  var sim_seed := Rand.splitmix64(seed ^ 0xC011E6E4)  # Unique salt for simulation
  var season_results := _simulate_season(world_state, year, sim_seed, config)

  # Store season records in world_state
  if not season_results.is_empty():
    var season_records: Dictionary = world_state.get("season_records", {})
    if not season_records.has(year):
      season_records[year] = {}
    for team_id in season_results.keys():
      season_records[year][team_id] = season_results[team_id]
    world_state["season_records"] = season_records

  # ... existing player lifecycle and graduation logic ...

  return {
    # ... existing fields ...
    "season_simulation": {
      "enabled": not season_results.is_empty(),
      "games_simulated": _count_games(season_results) if not season_results.is_empty() else 0
    }
  }
```

3. Add helper functions:

```gdscript
static func _filter_week(schedule: Array, week_number: int) -> Array:
  var filtered := []
  for matchup in schedule:
    var m: Dictionary = matchup
    if int(m.get("week", 0)) == week_number:
      filtered.append(m)
  return filtered

static func _count_games(season_results: Dictionary) -> int:
  var total := 0
  for team_id in season_results.keys():
    var record: Dictionary = season_results[team_id]
    total += int(record.get("wins", 0)) + int(record.get("losses", 0))
  return total / 2  # Each game counted twice (winner and loser)
```

### Step 3: Integrate with NflSeason (1 day)

**File**: `scripts/world/NflSeason.gd`

**Changes**: Similar pattern to CollegeSeason.

```gdscript
func _simulate_nfl_season(
  world_state: Dictionary,
  year: int,
  seed: int,
  league_cfg: Dictionary
) -> Dictionary:
  var game_sim_cfg: Dictionary = league_cfg.get("game_simulation", {})
  if not bool(game_sim_cfg.get("enabled", false)):
    return {}

  var teams: Array = world_state.get("nfl_teams", [])
  var rosters: Dictionary = world_state.get("nfl_rosters", {})
  var positions_cfg: Dictionary = _get_config().get_config("positions")
  var main_cfg: Dictionary = _get_config().get_config("main")

  # Calculate team strengths
  var team_strengths := {}
  for team in teams:
    var t: Dictionary = team
    var team_id := String(t.get("id", ""))
    if rosters.has(team_id):
      var roster: Dictionary = rosters[team_id]
      var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
      team_strengths[team_id] = strength

  # Generate schedule (simplified NFL schedule)
  var divisions := _extract_divisions(league_cfg)
  var schedule := GameSimulator.generate_nfl_schedule(teams, divisions, year, seed)

  # Simulate games (sequential)
  var rng := RandomNumberGenerator.new()
  rng.seed = seed
  var all_results: Array[Dictionary] = []

  var weeks := int(game_sim_cfg.get("regular_season_weeks", 17))
  for week in range(1, weeks + 1):
    var week_matchups := _filter_week(schedule, week)
    for matchup in week_matchups:
      var result := GameSimulator.determine_winner(matchup, team_strengths, rng, game_sim_cfg)
      all_results.append(result)

  # Aggregate results
  var team_ids := teams.map(func(t): return String(t.get("id", "")))
  var season_results := GameSimulator.aggregate_season_results(all_results, team_ids)

  return season_results

func _extract_divisions(league_cfg: Dictionary) -> Array:
  # Parse divisions from regions (each region = 1 division in Phase 1)
  var regions: Array = league_cfg.get("regions", [])
  var divisions: Array = []
  for region in regions:
    var r: Dictionary = region
    divisions.append({
      "id": String(r.get("id", "")),
      "teams": []  # Populated by schedule generator
    })
  return divisions
```

Integration into `run()`:

```gdscript
func run(world_state: Dictionary, year: int, seed: int, league_cfg: Dictionary, ...) -> Dictionary:
  # ... existing roster loading ...

  # NEW: Simulate season BEFORE player lifecycle
  var sim_seed := Rand.splitmix64(seed ^ 0x5EA50004)  # Unique salt for NFL simulation
  var season_results := _simulate_nfl_season(world_state, year, sim_seed, league_cfg)

  # Store season records
  if not season_results.is_empty():
    var season_records: Dictionary = world_state.get("season_records", {})
    if not season_records.has(year):
      season_records[year] = {}
    for team_id in season_results.keys():
      season_records[year][team_id] = season_results[team_id]
    world_state["season_records"] = season_records

  # ... existing player lifecycle and retirement logic ...

  return {
    # ... existing fields ...
    "season_simulation": {
      "enabled": not season_results.is_empty(),
      "games_simulated": _count_games(season_results) if not season_results.is_empty() else 0
    }
  }
```

### Step 4: Update Config Files (0.5 day)

**File**: `configs/sports/american_football/world/colleges.json`

```json
{
  "version": 2,
  "college_count": 130,
  "default_capacity": 85,
  "name_format": "College %03d",
  "regions": [...],
  "eliteness_tiers": [...],
  "roster_capacity": {...},
  "recruiting": {...},
  "usage_profile": {...},
  "competition": {...},
  "early_declaration": {...},
  "draft_declaration": {...},
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 12,
    "home_field_advantage": 3.0,
    "strength_sensitivity": 0.1,
    "calculation_method": "mean_rating"
  }
}
```

**File**: `configs/sports/american_football/world/league.json`

```json
{
  "version": 3,
  "cap_limit": 200.0,
  "team_count": 32,
  "name_format": "Team %03d",
  "regions": [...],
  "roster_limits": {...},
  "draft": {...},
  "game_simulation": {
    "enabled": true,
    "regular_season_weeks": 17,
    "home_field_advantage": 2.5,
    "strength_sensitivity": 0.1,
    "calculation_method": "mean_rating"
  }
}
```

**Version Bumps**:
- `colleges.json`: v1 → v2
- `league.json`: v2 → v3

**Migration**: Existing configs without `game_simulation` section will disable simulation (feature flag pattern).

### Step 5: Unit Tests (1 day)

**File**: `scripts/tests/test_game_simulator.gd`

```gdscript
extends GutTest

const GameSimulator = preload("res://scripts/world/GameSimulator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

func test_calculate_team_strength_empty_roster():
  var roster := {"players": []}
  var strength := GameSimulator.calculate_team_strength(roster, {}, {})
  assert_eq(strength, 50.0, "Empty roster should return default strength")

func test_calculate_team_strength_single_player():
  var player := {
    "stats": {"speed": 80.0, "strength": 70.0, "agility": 75.0},
    "position": "RB"
  }
  var roster := {"players": [player]}
  var positions_cfg := {"RB": {"core_stats": ["speed", "agility"]}}
  var main_cfg := {"class_rules": {}}

  var strength := GameSimulator.calculate_team_strength(roster, positions_cfg, main_cfg)
  assert_gt(strength, 0.0, "Single player should have non-zero strength")
  assert_lt(strength, 100.0, "Strength should be capped at 100")

func test_calculate_win_probability_equal_teams():
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}
  var prob := GameSimulator.calculate_win_probability(50.0, 50.0, false, cfg)
  assert_almost_eq(prob, 0.5, 0.01, "Equal teams should have 50% win probability")

func test_calculate_win_probability_home_advantage():
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}
  var home_prob := GameSimulator.calculate_win_probability(50.0, 50.0, true, cfg)
  assert_gt(home_prob, 0.5, "Home team should have >50% probability with advantage")
  assert_lt(home_prob, 0.6, "Home advantage should not be overwhelming")

func test_calculate_win_probability_strong_favorite():
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}
  var prob := GameSimulator.calculate_win_probability(80.0, 50.0, false, cfg)
  assert_gt(prob, 0.85, "Strong favorite should have high win probability")
  assert_lt(prob, 1.0, "Win probability should never be 100%")

func test_determine_winner_determinism():
  var matchup := {
    "game_id": "test_game_1",
    "year": 2025,
    "week": 1,
    "home_team_id": "team_a",
    "away_team_id": "team_b",
    "game_type": "regular"
  }
  var team_strengths := {"team_a": 60.0, "team_b": 55.0}
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}

  var rng1 := RandomNumberGenerator.new()
  rng1.seed = 12345
  var result1 := GameSimulator.determine_winner(matchup, team_strengths, rng1, cfg)

  var rng2 := RandomNumberGenerator.new()
  rng2.seed = 12345
  var result2 := GameSimulator.determine_winner(matchup, team_strengths, rng2, cfg)

  assert_eq(result1["winner_id"], result2["winner_id"], "Same seed should produce same winner")
  assert_eq(result1["loser_id"], result2["loser_id"], "Same seed should produce same loser")

func test_aggregate_season_results():
  var game_results: Array[Dictionary] = [
    {"winner_id": "team_a", "loser_id": "team_b", "game_type": "regular"},
    {"winner_id": "team_a", "loser_id": "team_c", "game_type": "regular"},
    {"winner_id": "team_b", "loser_id": "team_c", "game_type": "regular"}
  ]
  var team_ids := ["team_a", "team_b", "team_c"]

  var season_results := GameSimulator.aggregate_season_results(game_results, team_ids)

  assert_eq(season_results["team_a"]["wins"], 2, "Team A should have 2 wins")
  assert_eq(season_results["team_a"]["losses"], 0, "Team A should have 0 losses")
  assert_eq(season_results["team_b"]["wins"], 1, "Team B should have 1 win")
  assert_eq(season_results["team_b"]["losses"], 1, "Team B should have 1 loss")
  assert_eq(season_results["team_c"]["losses"], 2, "Team C should have 2 losses")
```

**Coverage Target**: >95% for GameSimulator functions.

### Step 6: Integration Tests (1 day)

**File**: `scripts/tests/test_season_simulation.gd`

```gdscript
extends GutTest

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")

func test_college_season_simulation_integration():
  # Setup world_state with colleges and rosters
  var world_state := _create_test_world_state_college()

  # Run college season with simulation enabled
  var season := CollegeSeason.new()
  var config := _create_test_config_with_simulation()
  var result := season.run(world_state, 2025, 12345, config, {}, {}, {}, {})

  # Verify season_records exist
  assert_true(world_state.has("season_records"), "World state should have season_records")
  assert_true(world_state["season_records"].has(2025), "Season records should exist for year 2025")

  # Verify W/L counts
  var records_2025 := world_state["season_records"][2025]
  for college_id in records_2025.keys():
    var record: Dictionary = records_2025[college_id]
    assert_true(record.has("wins"), "Record should have wins")
    assert_true(record.has("losses"), "Record should have losses")
    assert_ge(record["wins"], 0, "Wins should be non-negative")
    assert_ge(record["losses"], 0, "Losses should be non-negative")

  # Verify phase output
  assert_true(result.has("season_simulation"), "Result should include simulation summary")
  assert_true(result["season_simulation"]["enabled"], "Simulation should be enabled")
  assert_gt(result["season_simulation"]["games_simulated"], 0, "Should have simulated games")

func test_nfl_season_simulation_integration():
  # Similar pattern to college test
  var world_state := _create_test_world_state_nfl()
  var season := NflSeason.new()
  var config := _create_test_nfl_config_with_simulation()
  var result := season.run(world_state, 2025, 12345, config, {}, {}, {}, {})

  assert_true(world_state.has("season_records"), "World state should have season_records")
  assert_true(world_state["season_records"].has(2025), "Season records should exist for year 2025")

  var records_2025 := world_state["season_records"][2025]
  for team_id in records_2025.keys():
    var record: Dictionary = records_2025[team_id]
    assert_eq(record["wins"] + record["losses"], 17, "NFL teams should play 17 games")

func test_simulation_determinism():
  # Run bootstrap twice with same seed
  var world_state_1 := _create_test_world_state_college()
  var world_state_2 := _create_test_world_state_college()

  var season := CollegeSeason.new()
  var config := _create_test_config_with_simulation()

  season.run(world_state_1, 2025, 12345, config, {}, {}, {}, {})
  season.run(world_state_2, 2025, 12345, config, {}, {}, {}, {})

  # Compare season_records
  var records_1 := world_state_1["season_records"][2025]
  var records_2 := world_state_2["season_records"][2025]

  assert_eq(records_1.keys().size(), records_2.keys().size(), "Same number of teams")
  for team_id in records_1.keys():
    assert_eq(records_1[team_id]["wins"], records_2[team_id]["wins"], "Same wins for %s" % team_id)
    assert_eq(records_1[team_id]["losses"], records_2[team_id]["losses"], "Same losses for %s" % team_id)

# Helper functions to create test world states
func _create_test_world_state_college() -> Dictionary:
  # Create minimal world_state with 10 colleges and rosters
  # (Implementation details in SPECS doc)
  pass

func _create_test_config_with_simulation() -> Dictionary:
  return {
    "game_simulation": {
      "enabled": true,
      "regular_season_weeks": 12,
      "home_field_advantage": 3.0,
      "strength_sensitivity": 0.1
    }
  }
```

### Step 7: Performance Benchmarks (0.5 day)

**File**: `scripts/tests/benchmark/benchmark_game_sim.gd`

```gdscript
extends RefCounted
class_name BenchmarkGameSim

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func run() -> Dictionary:
  print("=== Game Simulation Benchmark ===")

  # Baseline: 20-year bootstrap WITHOUT simulation
  var baseline_time := _benchmark_bootstrap(false)
  print("Baseline (no simulation): %.2f seconds" % (baseline_time / 1000000.0))

  # With simulation: 20-year bootstrap WITH simulation
  var simulation_time := _benchmark_bootstrap(true)
  print("With simulation: %.2f seconds" % (simulation_time / 1000000.0))

  # Calculate overhead
  var overhead_us := simulation_time - baseline_time
  var overhead_pct := (overhead_us / float(baseline_time)) * 100.0
  print("Overhead: %.2f seconds (%.1f%%)" % (overhead_us / 1000000.0, overhead_pct))

  # Validation
  if overhead_pct > 10.0:
    push_warning("Game simulation overhead exceeds 10% target!")

  return {
    "baseline_us": baseline_time,
    "simulation_us": simulation_time,
    "overhead_us": overhead_us,
    "overhead_percent": overhead_pct,
    "target_met": overhead_pct <= 10.0
  }

func _benchmark_bootstrap(simulation_enabled: bool) -> int:
  # Temporarily modify configs to enable/disable simulation
  var college_cfg := _load_college_config()
  var nfl_cfg := _load_nfl_config()

  var original_college_enabled := college_cfg.get("game_simulation", {}).get("enabled", false)
  var original_nfl_enabled := nfl_cfg.get("game_simulation", {}).get("enabled", false)

  # Override config
  if not simulation_enabled:
    college_cfg["game_simulation"]["enabled"] = false
    nfl_cfg["game_simulation"]["enabled"] = false
  else:
    college_cfg["game_simulation"]["enabled"] = true
    nfl_cfg["game_simulation"]["enabled"] = true

  _save_college_config(college_cfg)
  _save_nfl_config(nfl_cfg)

  # Run bootstrap with timing
  var bootstrap := BootstrapGameWorld.new()
  bootstrap.years_to_simulate = 20
  var start_time := Time.get_ticks_usec()
  var result := bootstrap.run(12345, false)  # Deterministic seed, no timing capture
  var end_time := Time.get_ticks_usec()

  # Restore original config
  college_cfg["game_simulation"]["enabled"] = original_college_enabled
  nfl_cfg["game_simulation"]["enabled"] = original_nfl_enabled
  _save_college_config(college_cfg)
  _save_nfl_config(nfl_cfg)

  return end_time - start_time

func _load_college_config() -> Dictionary:
  # Load from configs/sports/american_football/world/colleges.json
  pass

func _save_college_config(cfg: Dictionary) -> void:
  # Save to configs/sports/american_football/world/colleges.json
  pass

# Similar for NFL config
```

**Run Command**:
```bash
godot --headless -s res://scripts/tests/benchmark/benchmark_game_sim.gd
```

### Step 8: Statistical Validation (0.5 day)

**File**: `scripts/tests/test_simulation_validation.gd`

```gdscript
extends GutTest

const GameSimulator = preload("res://scripts/world/GameSimulator.gd")

func test_home_win_rate_realistic():
  # Simulate 1000 games between equal teams
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}
  var team_strengths := {"home": 50.0, "away": 50.0}
  var rng := RandomNumberGenerator.new()
  rng.seed = 12345

  var home_wins := 0
  var total_games := 1000

  for i in range(total_games):
    var matchup := {
      "game_id": "test_%d" % i,
      "year": 2025,
      "week": 1,
      "home_team_id": "home",
      "away_team_id": "away",
      "game_type": "regular"
    }
    var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
    if result["winner_id"] == "home":
      home_wins += 1

  var home_win_rate := float(home_wins) / float(total_games)
  print("Home win rate: %.1f%%" % (home_win_rate * 100.0))

  # NCAA/NFL home win rate is ~57-60%
  assert_gt(home_win_rate, 0.55, "Home win rate should be >55%")
  assert_lt(home_win_rate, 0.65, "Home win rate should be <65%")

func test_upset_frequency_realistic():
  # Simulate 1000 games where home team is 10 points stronger
  var cfg := {"home_field_advantage": 3.0, "strength_sensitivity": 0.1}
  var team_strengths := {"favorite": 65.0, "underdog": 55.0}
  var rng := RandomNumberGenerator.new()
  rng.seed = 54321

  var upsets := 0
  var total_games := 1000

  for i in range(total_games):
    var matchup := {
      "game_id": "test_%d" % i,
      "year": 2025,
      "week": 1,
      "home_team_id": "favorite",
      "away_team_id": "underdog",
      "game_type": "regular"
    }
    var result := GameSimulator.determine_winner(matchup, team_strengths, rng, cfg)
    if result["winner_id"] == "underdog":
      upsets += 1

  var upset_rate := float(upsets) / float(total_games)
  print("Upset rate (10-point underdog): %.1f%%" % (upset_rate * 100.0))

  # Expect ~15-25% upset rate for 10-point underdog
  assert_gt(upset_rate, 0.10, "Upset rate should be >10%")
  assert_lt(upset_rate, 0.30, "Upset rate should be <30%")

func test_strength_correlation():
  # Run full season simulation and check correlation between team strength and wins
  # (Implementation requires full integration test setup)
  # Expected: Pearson r > 0.6
  pass
```

### Step 9: Documentation (0.5 day)

**Files to update**:
- Add inline code comments explaining RNG patterns
- Update `docs/README.md` with link to game simulation docs
- Create `docs/tasks/GAME_SIMULATION_SPECS.md` with detailed algorithms

**Code comments example**:

```gdscript
## Determines winner for a single game using probabilistic model.
##
## RNG consumption: 1 call (randf for win probability roll)
## Determinism: Same inputs + same RNG seed = same winner
##
## Algorithm:
##   1. Calculate win probability using logistic curve (home advantage applied)
##   2. Roll RNG (0.0-1.0)
##   3. If roll < win_probability, home team wins
##   4. Detect upsets (underdog by >5 points wins)
##   5. Return GameResult dictionary with winner, loser, metadata
##
## Performance: ~7 µs per game (negligible in 20-year bootstrap)
static func determine_winner(...) -> Dictionary:
  # ...
```

---

## Testing Strategy

### Unit Tests (>95% coverage)

**GameSimulator class**:
- `test_calculate_team_strength_*`: Empty roster, single player, full roster, edge cases
- `test_calculate_win_probability_*`: Equal teams, home advantage, strong favorite, weak underdog
- `test_determine_winner_*`: Determinism, upset detection, RNG consumption
- `test_generate_college_schedule_*`: Coverage (all teams play), balance (home/away), determinism
- `test_generate_nfl_schedule_*`: Division structure, determinism
- `test_aggregate_season_results_*`: W/L counting, edge cases (0 games, all wins)

### Integration Tests

**Season simulation**:
- `test_college_season_simulation_integration`: End-to-end with world_state
- `test_nfl_season_simulation_integration`: End-to-end with world_state
- `test_simulation_determinism`: Same seed = same results
- `test_simulation_disabled`: Feature flag disables simulation

### Performance Tests

**Benchmarks**:
- 20-year bootstrap with/without simulation
- Target: <10% overhead
- Alert if exceeded

### Validation Tests

**Statistical realism**:
- Home win rate: 55-65%
- Upset rate: 10-25% (for 10-point underdog)
- Strength correlation: r > 0.6

---

## Acceptance Criteria

### Functionality

- [ ] `GameSimulator` class with all static functions implemented
- [ ] `CollegeSeason.run()` calls `_simulate_season()` and stores season_records
- [ ] `NflSeason.run()` calls `_simulate_nfl_season()` and stores season_records
- [ ] Config files updated with `game_simulation` sections (version bumps)
- [ ] World state includes `season_records` for all teams across 20 years
- [ ] Feature flag allows disabling simulation (existing behavior preserved)

### Quality

- [ ] Unit tests: >95% coverage for GameSimulator
- [ ] Integration tests: All pass (college, NFL, determinism)
- [ ] Performance tests: <10% bootstrap overhead
- [ ] Statistical validation: Home win rate, upset rate within expected ranges
- [ ] Code comments explain RNG patterns and determinism guarantees

### Documentation

- [ ] Inline comments on all public functions
- [ ] `GAME_SIMULATION_SPECS.md` with detailed algorithms
- [ ] `README.md` updated with link to game simulation docs
- [ ] PR description references architecture document

---

## Risk Mitigation

### High-Risk Areas

**Determinism violations**:
- Mitigation: Follow existing RNG patterns (explicit seed passing, sequential simulation)
- Validation: Automated test runs bootstrap twice with same seed, compares results

**Performance regression**:
- Mitigation: Benchmark before/after, alert if >10% overhead
- Validation: CI pipeline runs performance tests on every commit

**Integration bugs**:
- Mitigation: Comprehensive integration tests with real world_state
- Validation: Run full 20-year bootstrap in test environment before merge

### Medium-Risk Areas

**Config versioning**:
- Mitigation: Graceful degradation if `game_simulation` section missing
- Validation: Test with v1 and v2 configs, verify both work

**Schedule generation bugs**:
- Mitigation: Unit tests validate coverage, balance, determinism
- Validation: Manual inspection of generated schedules for sanity

---

## Dependencies

**None** (integrates with existing systems, no external dependencies).

---

## Next Steps

After Phase 1 completion:

1. **Phase 2 Design**: Conference-aware schedules, playoffs, bowl games
2. **Phase 3 Design**: Player development feedback from W/L records
3. **Phase 4 Design**: Week-level parallelization for performance

**Immediate Next Task**: Create `GAME_SIMULATION_SPECS.md` with detailed algorithm implementations.

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial implementation plan |

---

**Estimated Timeline**: 5-7 days for Phase 1 MVP.

**Estimated LOC**: ~800 lines (400 GameSimulator, 200 CollegeSeason, 200 NflSeason, 200 tests).

**PR Size**: Medium (new class + 2 modified classes + configs).
