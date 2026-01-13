# Team Alpha Technical Specification
## Phases 1 + 2: College Stats & Conference System

**Date**: 2026-01-13
**Architect**: Team Alpha Architect
**Branch**: `team-alpha/architect`

---

## Overview

This specification defines the implementation of:
- **Phase 1**: College Performance Statistics - Season-by-season stat tracking and analysis
- **Phase 2**: Conference/Competition Level Weighting - Conference tiers and strength of schedule

---

## Architecture Integration Points

### Existing Infrastructure

The simulation already tracks player stats via:
```gdscript
world_state["player_career_stats"][player_id][year] = {
  "year": int,
  "team_id": string,
  "games_played": int,
  "games_started": int,
  "position": string,
  ... position-specific stats (passing_yards, rushing_yards, etc.) ...
}
```

Stats are accumulated in `GameSimulator.accumulate_player_stats()`, called from `CollegeSeason._simulate_college_season()` line 549.

### New Services

We will create two new service classes that operate on this existing data:

1. **CollegeStatsService** - Analyzes and aggregates `player_career_stats` data
2. **ConferenceService** - Manages conference assignments and strength of schedule

---

## Phase 1: CollegeStatsService

### Purpose

Provide draft evaluation tools by analyzing raw game stats:
- Calculate efficiency metrics (QBR, yards per carry, completion %, etc.)
- Detect production trajectories (improving, declining, breakout)
- Aggregate career totals for scouting

### Data Model

**No new data stored on player dictionaries**. Instead, CollegeStatsService provides pure functions that compute metrics on-demand from `player_career_stats`.

Optional: For UI performance, we may cache computed metrics in:
```gdscript
world_state["college_stat_analysis"][player_id] = {
  "career_totals": {...},
  "efficiency_metrics": {...},
  "trajectory": "rising" | "declining" | "stable"
}
```

### API Specification

```gdscript
class_name CollegeStatsService

## Calculate efficiency metrics for a player's season
## Returns: Dictionary with position-specific efficiency stats
## RNG: None (pure calculation)
static func calculate_efficiency_metrics(
  player_id: String,
  year: int,
  career_stats: Dictionary,
  positions_cfg: Dictionary
) -> Dictionary

## Analyze production trajectory across seasons
## Returns: {"trend": "rising"|"declining"|"stable", "year_over_year": [floats]}
## RNG: None (pure calculation)
static func analyze_production_trajectory(
  player_id: String,
  career_stats: Dictionary,
  positions_cfg: Dictionary
) -> Dictionary

## Get career totals for a player
## Returns: Dictionary with cumulative stats across all seasons
## RNG: None (pure aggregation)
static func get_career_totals(
  player_id: String,
  career_stats: Dictionary
) -> Dictionary

## Get draft boost/penalty based on trajectory
## Returns: float multiplier (0.95 - 1.05)
static func get_trajectory_draft_modifier(
  trajectory: Dictionary,
  config: Dictionary
) -> float
```

### Efficiency Metrics by Position

**QB**:
- `qbr`: Passer rating calculation
- `completion_percentage`: completions / attempts
- `yards_per_attempt`: passing_yards / attempts
- `td_int_ratio`: touchdown_passes / max(interceptions, 1)

**RB**:
- `yards_per_carry`: rushing_yards / carries
- `yards_per_reception`: receiving_yards / receptions
- `total_yards_per_touch`: (rushing + receiving) / (carries + receptions)

**WR/TE**:
- `yards_per_reception`: receiving_yards / receptions
- `catch_rate`: receptions / targets
- `yards_per_route`: receiving_yards / routes_run (if available, else estimate)

**Defensive**:
- `tackles_per_game`: tackles / games_played
- `sacks_per_game`: sacks / games_played (EDGE, DL)
- `passes_defended_per_game`: passes_defended / games_played (CB, S)

### Configuration Format

File: `configs/sports/american_football/college_stats.json`

```json
{
  "efficiency_metrics": {
    "QB": {
      "qbr": {
        "formula": "passer_rating",
        "weight": 0.4
      },
      "yards_per_attempt": {
        "formula": "passing_yards / max(attempts, 1)",
        "weight": 0.3
      }
    },
    "RB": {
      "yards_per_carry": {
        "formula": "rushing_yards / max(carries, 1)",
        "weight": 0.5
      }
    }
  },
  "trajectory_analysis": {
    "rising": {
      "year_over_year_threshold": 5.0,
      "draft_boost": 0.05
    },
    "declining": {
      "year_over_year_threshold": -3.0,
      "draft_penalty": -0.03
    },
    "breakout": {
      "sophomore_to_junior_threshold": 10.0,
      "draft_boost": 0.08
    }
  }
}
```

### Integration Point

File: `scripts/world/CollegeSeason.gd`

Add after line 165 (after rosters updated, before world_state updated):

```gdscript
# PHASE 1: Update college stat analysis for draft evaluation
# This computes efficiency metrics and production trajectories
# RNG: None (pure calculation)
if options.get("enable_stat_analysis", true):
  _update_college_stat_analysis(world_state, year, positions_cfg, config)
```

New function at end of file:

```gdscript
func _update_college_stat_analysis(
  world_state: Dictionary,
  year: int,
  positions_cfg: Dictionary,
  config: Dictionary
) -> void:
  var career_stats: Dictionary = world_state.get("player_career_stats", {})
  var analysis: Dictionary = world_state.get("college_stat_analysis", {})

  for player_id in career_stats.keys():
    var player_years: Dictionary = career_stats[player_id]
    if not player_years.has(year):
      continue

    # Calculate efficiency metrics for this season
    var efficiency := CollegeStatsService.calculate_efficiency_metrics(
      player_id, year, career_stats, positions_cfg
    )

    # Analyze production trajectory
    var trajectory := CollegeStatsService.analyze_production_trajectory(
      player_id, career_stats, positions_cfg
    )

    # Get career totals
    var totals := CollegeStatsService.get_career_totals(
      player_id, career_stats
    )

    analysis[player_id] = {
      "efficiency_metrics": efficiency,
      "trajectory": trajectory,
      "career_totals": totals
    }

  world_state["college_stat_analysis"] = analysis
```

---

## Phase 2: ConferenceService

### Purpose

Add realistic conference structure to colleges:
- Assign colleges to conferences (SEC, Big Ten, etc.)
- Track conference tiers (Power 5, Group of 5, FCS)
- Calculate strength of schedule based on opponents' conference tiers
- Provide draft weight multipliers for conference quality

### Data Model

**College dictionaries extended** (in `world_state["colleges"]`):
```gdscript
{
  "id": "col_001",
  "name": "College 001",
  "region": "south",
  "eliteness": 92.5,
  "tier": "elite",
  "conference": "sec",              # NEW
  "conference_tier": "power_5",     # NEW
  "strength_of_schedule": 0.0       # NEW (computed each season)
}
```

**World state additions**:
```gdscript
world_state["conferences"] = {
  "sec": {
    "id": "sec",
    "name": "SEC",
    "tier": "power_5",
    "draft_weight_multiplier": 1.15,
    "members": ["col_001", "col_015", ...]
  },
  ...
}
```

### API Specification

```gdscript
class_name ConferenceService

## Assign colleges to conferences during world generation
## RNG: Uses explicit rng parameter for conference selection
static func assign_colleges_to_conferences(
  colleges: Array,
  config: Dictionary,
  rng: RandomNumberGenerator
) -> void

## Calculate strength of schedule for a college based on season results
## RNG: None (pure calculation)
## Returns: float 0.0-1.0 (normalized SOS score)
static func calculate_strength_of_schedule(
  college_id: String,
  season_results: Dictionary,
  college_index: Dictionary
) -> float

## Get draft weight multiplier for a conference tier
## RNG: None (config lookup)
## Returns: float multiplier (e.g., 1.15 for SEC, 0.85 for FCS)
static func get_conference_tier_multiplier(
  conference_tier: String,
  config: Dictionary
) -> float

## Get conference data by ID
## RNG: None (lookup)
static func get_conference(
  conference_id: String,
  conferences: Dictionary
) -> Dictionary
```

### Conference Assignment Algorithm

Called from `CollegeGenerator.generate()` after colleges are created:

1. Load conference definitions from config
2. For each conference, calculate "fit score" for each college:
   - Region match bonus (SEC prefers south, Big Ten prefers midwest)
   - Eliteness match (Power 5 conferences prefer elite/power colleges)
3. Assign colleges to conferences using weighted selection
4. Balance conference sizes (min 10, max 16 per conference)

### Configuration Format

File: `configs/sports/american_football/world/colleges.json` (additions)

```json
{
  "version": 3,
  ...existing fields...

  "conferences": [
    {
      "id": "sec",
      "name": "SEC",
      "tier": "power_5",
      "draft_weight_multiplier": 1.15,
      "preferred_regions": ["south"],
      "region_weight": 0.6,
      "min_eliteness": 70.0,
      "size_min": 12,
      "size_max": 16
    },
    {
      "id": "big_ten",
      "name": "Big Ten",
      "tier": "power_5",
      "draft_weight_multiplier": 1.12,
      "preferred_regions": ["midwest", "northeast"],
      "region_weight": 0.5,
      "min_eliteness": 68.0,
      "size_min": 12,
      "size_max": 16
    },
    {
      "id": "acc",
      "name": "ACC",
      "tier": "power_5",
      "draft_weight_multiplier": 1.10,
      "preferred_regions": ["south", "northeast"],
      "region_weight": 0.5,
      "min_eliteness": 65.0,
      "size_min": 12,
      "size_max": 16
    },
    {
      "id": "pac_12",
      "name": "Pac-12",
      "tier": "power_5",
      "draft_weight_multiplier": 1.08,
      "preferred_regions": ["west"],
      "region_weight": 0.7,
      "min_eliteness": 63.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "big_12",
      "name": "Big 12",
      "tier": "power_5",
      "draft_weight_multiplier": 1.07,
      "preferred_regions": ["midwest", "south"],
      "region_weight": 0.5,
      "min_eliteness": 60.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "american",
      "name": "American Athletic Conference",
      "tier": "group_5",
      "draft_weight_multiplier": 0.95,
      "preferred_regions": ["south", "midwest"],
      "region_weight": 0.3,
      "min_eliteness": 50.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "mountain_west",
      "name": "Mountain West",
      "tier": "group_5",
      "draft_weight_multiplier": 0.93,
      "preferred_regions": ["west"],
      "region_weight": 0.5,
      "min_eliteness": 48.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "mac",
      "name": "Mid-American Conference",
      "tier": "group_5",
      "draft_weight_multiplier": 0.90,
      "preferred_regions": ["midwest"],
      "region_weight": 0.4,
      "min_eliteness": 45.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "cusa",
      "name": "Conference USA",
      "tier": "group_5",
      "draft_weight_multiplier": 0.88,
      "preferred_regions": ["south"],
      "region_weight": 0.4,
      "min_eliteness": 45.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "sun_belt",
      "name": "Sun Belt",
      "tier": "group_5",
      "draft_weight_multiplier": 0.87,
      "preferred_regions": ["south"],
      "region_weight": 0.4,
      "min_eliteness": 43.0,
      "size_min": 10,
      "size_max": 14
    },
    {
      "id": "fcs_independent",
      "name": "FCS Independent",
      "tier": "fcs",
      "draft_weight_multiplier": 0.80,
      "preferred_regions": [],
      "region_weight": 0.0,
      "min_eliteness": 0.0,
      "size_min": 1,
      "size_max": 999
    }
  ],

  "tier_weights": {
    "power_5": {
      "base_draft_multiplier": 1.10,
      "competition_multiplier": 1.05
    },
    "group_5": {
      "base_draft_multiplier": 0.95,
      "competition_multiplier": 1.00
    },
    "fcs": {
      "base_draft_multiplier": 0.80,
      "competition_multiplier": 0.95
    }
  }
}
```

### Integration Points

#### Point 1: CollegeGenerator.gd

After line 58 (after colleges array is populated), add:

```gdscript
# PHASE 2: Assign colleges to conferences
# RNG: Uses explicit rng parameter
ConferenceService.assign_colleges_to_conferences(colleges, cfg, rng)

# Store conference definitions in world_state
var conferences := ConferenceService.build_conference_index(colleges, cfg)
```

Return value changes to:
```gdscript
return {
  "colleges": colleges,
  "conferences": conferences,  # NEW
  "config": cfg
}
```

#### Point 2: CollegeSeason.gd

After line 594 (after team history updated), add:

```gdscript
# PHASE 2: Calculate strength of schedule for all colleges
# RNG: None (pure calculation)
_update_strength_of_schedule(world_state, year, season_results, college_index, config)
```

New function at end of file:

```gdscript
func _update_strength_of_schedule(
  world_state: Dictionary,
  year: int,
  season_results: Dictionary,
  college_index: Dictionary,
  config: Dictionary
) -> void:
  var colleges: Array = world_state.get("colleges", [])

  for college in colleges:
    var c: Dictionary = college
    var college_id := String(c.get("id", ""))

    var sos := ConferenceService.calculate_strength_of_schedule(
      college_id,
      season_results,
      college_index
    )

    c["strength_of_schedule"] = sos
```

---

## Engineer Task Decomposition

### Engineer 1: CollegeStatsService Implementation

**Files to Create**:
- `scripts/world/CollegeStatsService.gd`
- `configs/sports/american_football/college_stats.json`

**Dependencies**: None (reads existing `player_career_stats`)

**Acceptance Criteria**:
- [ ] `calculate_efficiency_metrics()` computes position-specific metrics
- [ ] `analyze_production_trajectory()` detects rising/declining/stable trends
- [ ] `get_career_totals()` aggregates all seasons correctly
- [ ] `get_trajectory_draft_modifier()` returns proper multipliers
- [ ] All functions are static and pure (no state mutation)
- [ ] Config file validated and documented
- [ ] Passes `godot --headless --check-only --script`
- [ ] Unit tests written for key functions

### Engineer 2: ConferenceService Implementation

**Files to Create**:
- `scripts/world/ConferenceService.gd`

**Files to Modify**:
- `configs/sports/american_football/world/colleges.json` (add conferences section)

**Dependencies**: None

**Acceptance Criteria**:
- [ ] `assign_colleges_to_conferences()` assigns all 130 colleges properly
- [ ] Conference sizes are balanced (10-16 per P5, 10-14 per G5)
- [ ] `calculate_strength_of_schedule()` returns normalized 0.0-1.0 scores
- [ ] `get_conference_tier_multiplier()` returns correct multipliers
- [ ] All functions are static and deterministic
- [ ] Colleges have conference/conference_tier/strength_of_schedule fields
- [ ] Config file validated with proper JSON structure
- [ ] Passes `godot --headless --check-only --script`
- [ ] Unit tests written for assignment algorithm

### Architect Integration Tasks

**Files to Modify**:
- `scripts/world/CollegeSeason.gd` (add stat analysis and SOS updates)
- `scripts/world/CollegeGenerator.gd` (add conference assignment call)

**Responsibilities**:
- Integrate both services into simulation pipeline
- Ensure proper RNG threading (ConferenceService uses rng, CollegeStatsService is pure)
- Add helper functions to CollegeSeason for stat analysis and SOS updates
- Verify no breaking changes to existing simulation
- Run full test suite (BootstrapPreview.gd)
- Coordinate code review and merge

---

## Testing Strategy

### Layer 1: Syntax Check (MANDATORY)
```bash
godot --headless --check-only --script /home/user/workspaces/team-alpha/architect/scripts/world/CollegeStatsService.gd
godot --headless --check-only --script /home/user/workspaces/team-alpha/architect/scripts/world/ConferenceService.gd
```

### Layer 2: Unit Tests
Create:
- `scripts/tests/test_college_stats_service.gd`
- `scripts/tests/test_conference_service.gd`

### Layer 3: Integration Test (MANDATORY)
```bash
godot --headless -s /home/user/workspaces/team-alpha/architect/scripts/pipelines/BootstrapPreview.gd
```

Verify output shows:
- Colleges have conference assignments
- Players have stat analysis computed
- No crashes or null reference errors

### Layer 4: Full Suite
```bash
godot --headless -s /home/user/workspaces/team-alpha/architect/scripts/tests/TestRunner.gd
```

---

## Determinism Guarantees

### CollegeStatsService
- All functions are pure (no RNG, no state mutation)
- Same inputs always produce same outputs
- Thread-safe for parallel computation

### ConferenceService
- `assign_colleges_to_conferences()` uses explicit RNG parameter
- Conference assignment is deterministic with same seed
- SOS calculation is pure (no RNG)
- Results are reproducible across runs

---

## Performance Considerations

### CollegeStatsService
- Efficiency metrics: O(1) per player per season
- Trajectory analysis: O(years) per player (~4 years college)
- Career totals: O(years) per player
- Total: O(players × years) = O(500 × 4) = ~2000 operations per season

### ConferenceService
- Conference assignment: O(colleges × conferences) = O(130 × 11) = ~1430 operations (once at world gen)
- SOS calculation: O(colleges × games) = O(130 × 12) = ~1560 operations per season
- Both are negligible compared to game simulation

---

## Migration and Backward Compatibility

### Existing Saves
- Old saves without conference data: ConferenceService will detect and assign on first load
- Old saves without stat analysis: CollegeStatsService will compute on-demand
- No breaking changes to existing data structures

### Version Tracking
- Update `colleges.json` version to 3
- Add migration path in CollegeGenerator for version 2 → 3

---

## Success Metrics

### Phase 1 Complete When:
- [ ] All 500+ draft-eligible players have efficiency metrics computed
- [ ] Production trajectories detected correctly (rising/declining/stable)
- [ ] Career totals match hand-calculated values for sample players
- [ ] No performance regression (< 5% slowdown)

### Phase 2 Complete When:
- [ ] All 130 colleges assigned to conferences
- [ ] Conference distribution realistic (5 P5 conferences, 5 G5, 1 FCS catchall)
- [ ] Strength of schedule varies appropriately (P5 > G5 > FCS)
- [ ] Draft weight multipliers applied correctly
- [ ] No performance regression (< 5% slowdown)

---

## Open Questions

1. **Should stat analysis run every season or only for draft-eligible players?**
   - Recommendation: Every season for UI consistency, but cache results

2. **Should conference realignment be simulated over time?**
   - Phase 1: No, static assignment
   - Future: Could add realignment events

3. **How to handle independent schools (Notre Dame, BYU)?**
   - Add "fbs_independent" conference tier with appropriate multiplier

---

## References

- Existing code: `scripts/core/game_simulation/StatGenerator.gd`
- Existing code: `scripts/core/game_simulation/GameSimulator.gd`
- Existing code: `scripts/world/CollegeSeason.gd`
- Config: `configs/sports/american_football/world/colleges.json`
