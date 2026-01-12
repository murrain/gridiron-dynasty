# Team 3: Game & Season Simulation - Architecture Design

## Status: Architecture Complete, Implementation Pending

## Overview
This document defines the architecture for 5 game simulation features, all designed to be FULLY INDEPENDENT with no cross-team dependencies.

## Feature 1: Playoff Bracket Simulation (CRITICAL)

### College Football Playoff (4-team)
**File**: `scripts/world/CollegeSeason.gd`

**New Function**: `_simulate_college_playoff()`
- Algorithm:
  1. Select top 4 teams using existing `_determine_college_playoff_teams()`
  2. Simulate semi-finals: #1 vs #4, #2 vs #3
  3. Simulate championship with winners
- RNG Pattern: 3 randf() calls (2 semis + 1 championship)
- Uses `GameSimulator.determine_winner()` for all games
- Stores results in `world_state["playoff_results"]["college"][year]`
- Config flag: `game_simulation.playoff_enabled` (default: true)

**Integration Point**: In `_simulate_college_season()`, replace simple "best record wins" logic with playoff simulation when enabled.

### NFL Playoffs (Full Bracket)
**File**: `scripts/world/NflSeason.gd`

**New Function**: `_simulate_nfl_playoffs()`
- Algorithm:
  1. Seed top 7 teams per conference (AFC/NFC)
  2. Wild Card Round: #2 vs #7, #3 vs #6, #4 vs #5 (6 games)
  3. Divisional Round: Re-seed, highest vs lowest (4 games)
  4. Conference Championships (2 games)
  5. Super Bowl (1 game)
- RNG Pattern: 13 randf() calls total
- Helper functions:
  - `_simulate_playoff_game()` - creates matchup dict and calls GameSimulator
  - `_reseed_teams()` - maintains seeding through rounds
  - `_build_seed_list()` - formats bracket for display
- Stores results in `world_state["playoff_results"]["nfl"][year]`

**Integration Point**: In `_simulate_nfl_season()`, replace "best record wins" with playoff simulation.

## Feature 2: Weather Effects (MEDIUM)

### Implementation
**File**: `scripts/core/game_simulation/GameSimulator.gd`

**Modified Function**: `determine_winner()`
- Add weather determination before winner calculation
- RNG Pattern Change: 2 calls (1 for weather + 1 for winner)
- Config flag: `game_simulation.weather_enabled` (default: false)

**New Functions**:
```gdscript
static func _determine_weather(rng: RandomNumberGenerator, cfg: Dictionary) -> String
```
- Weather types: clear (50%), rain (25%), snow (15%), wind (10%)
- Returns weather string
- Configurable via `cfg.weather_probabilities`

```gdscript
static func _calculate_weather_impact(weather: String, cfg: Dictionary) -> Dictionary
```
- Returns:
  - `upset_variance`: 0.0 (clear), 0.15 (rain), 0.30 (snow), 0.20 (wind)
  - `pass_modifier`: affects future stat generation
  - `kick_modifier`: affects future stat generation
  - `fumble_modifier`: affects future stat generation
- Configurable via `cfg.weather_effects`

**Game Result Changes**:
- Add `weather` field (string)
- Add `weather_impact` field (dict)

**Impact on Gameplay**:
Weather increases upset variance by moving win probability closer to 50%:
```gdscript
if upset_variance > 0.0:
    var diff_from_50 := home_win_prob - 0.5
    home_win_prob = 0.5 + (diff_from_50 * (1.0 - upset_variance))
```

## Feature 3: Rivalry Game System (MEDIUM)

### Implementation
**File**: `scripts/core/game_simulation/GameSimulator.gd`

**Modified Function**: `determine_winner()`
- Check `game_matchup.is_rivalry` flag
- Apply rivalry intensity modifier to upset variance
- Config: `game_simulation.rivalry_intensity` (default: 0.20)
- Combined variance: `upset_variance = weather_variance + rivalry_intensity`

**New Function**:
```gdscript
static func check_rivalry(team_a_id: String, team_b_id: String, rivalries: Array) -> bool
```
- Checks if two teams are rivals
- Rivalries defined in config/world_state:
```json
{
  "rivalries": [
    {"team_a": "team_001", "team_b": "team_002", "name": "The Iron Bowl"}
  ]
}
```

**Schedule Generation Usage**:
In `generate_college_schedule()` and `generate_nfl_schedule()`:
```gdscript
var is_rivalry := GameSimulator.check_rivalry(home_id, away_id, rivalries)
matchup["is_rivalry"] = is_rivalry
```

**Game Result Changes**:
- Add `is_rivalry` field (bool)

## Feature 4: Special Teams Impact (MEDIUM)

### Implementation
**File**: `scripts/core/game_simulation/GameSimulator.gd`

**Modified Function**: `determine_winner()`
- Detect close games: `home_win_prob between 0.40-0.60`
- Apply special teams bonus in close games
- Config flag: `game_simulation.special_teams_enabled` (default: false)

**Mechanism**:
```gdscript
if is_close_game and special_teams_enabled:
    special_teams_bonus = float(game_matchup.get("home_special_teams_advantage", 0.0))
    home_win_prob = clamp(home_win_prob + special_teams_bonus, 0.01, 0.99)
```

**Future Enhancement**:
Calculate `home_special_teams_advantage` from K/P/returner ratings:
- Kicker accuracy: affects FG success in close games
- Punter: affects field position
- Return specialists: create big play opportunities

## Feature 5: Situational Game States (LOW)

### Implementation
**File**: `scripts/core/game_simulation/GameSimulator.gd`

**Modified Function**: `determine_winner()`
- Calculate situational flags after winner determined
- No RNG consumption (pure calculation)

**New Game Result Fields**:
```gdscript
"is_close_game": bool  // strength_differential < 7 AND win_prob 40-60%
"is_clutch": bool      // close game with upset or special teams impact
"is_comeback": bool    // underdog won in close game
```

**Usage**:
These flags can be used for:
- Narrative generation
- Player clutch stats
- Team performance tracking
- Post-season analysis

## Configuration Schema

### College Season Config
```json
{
  "game_simulation": {
    "enabled": true,
    "playoff_enabled": true,
    "regular_season_weeks": 12,
    "home_field_advantage": 3.0,
    "strength_sensitivity": 0.1,
    "upset_threshold": 5.0,
    "weather_enabled": false,
    "rivalry_intensity": 0.20,
    "special_teams_enabled": false
  }
}
```

### NFL Season Config
```json
{
  "game_simulation": {
    "enabled": true,
    "playoff_enabled": true,
    "regular_season_weeks": 17,
    "home_field_advantage": 2.5,
    "strength_sensitivity": 0.1,
    "upset_threshold": 7.0,
    "weather_enabled": false,
    "rivalry_intensity": 0.20,
    "special_teams_enabled": false
  }
}
```

## RNG Consumption Summary

### Original (Per Game)
- 1 randf() call for winner determination

### With All Features Enabled (Per Game)
- 1 randf() call for weather determination
- 1 randf() call for winner determination
- **Total: 2 randf() calls per game**

### Playoff Additions
- College: +3 randf() calls per season
- NFL: +13 randf() calls per season

## Testing Requirements

### Unit Tests Needed
1. `test_college_playoff_bracket.gd` - Test 4-team CFP simulation
2. `test_nfl_playoff_bracket.gd` - Test full NFL playoff bracket
3. `test_weather_effects.gd` - Test weather determination and impact
4. `test_rivalry_system.gd` - Test rivalry detection and intensity
5. `test_special_teams.gd` - Test special teams impact on close games
6. `test_situational_states.gd` - Test close game flag calculation

### Integration Tests Needed
1. Full season simulation with all features enabled
2. Determinism test (same seed = same results)
3. Performance test (ensure < 5% overhead)

## Backward Compatibility

All features are **fully backward compatible**:
- Default config flags disable new features
- Existing tests continue to pass with defaults
- New fields in game results are additive (don't break existing code)
- RNG consumption change is documented and intentional

## Performance Impact

Expected impact with all features enabled:
- Weather: +1 randf() call per game (~0.1% overhead)
- Rivalry: Negligible (simple flag check)
- Special teams: Negligible (conditional calculation)
- Situational states: Negligible (post-game calculation)
- **Total: < 1% performance impact**

Playoff simulation:
- College: 3 extra games per season (negligible)
- NFL: 13 extra games per season (< 0.5% of total games)

## Implementation Checklist

- [ ] Implement college playoff bracket in CollegeSeason.gd
- [ ] Implement NFL playoff bracket in NflSeason.gd
- [ ] Add weather system to GameSimulator.gd
- [ ] Add rivalry system to GameSimulator.gd
- [ ] Add special teams impact to GameSimulator.gd
- [ ] Add situational states to GameSimulator.gd
- [ ] Write unit tests for all features
- [ ] Write integration tests
- [ ] Update config files with new flags
- [ ] Run code-quality-reviewer (target: 9.5+/10)
- [ ] Create PR with all changes

## Architecture Review

**Complexity**: Low-Medium
- Features are independent and additive
- No architectural changes to existing systems
- Config-driven feature flags allow gradual rollout

**Maintainability**: High
- Clear separation of concerns
- Well-documented RNG consumption
- Explicit function signatures
- Backward compatible

**Determinism**: Preserved
- All RNG is explicit and documented
- Same seed produces same results
- RNG consumption is deterministic and counted

**Extensibility**: High
- Weather modifiers support future stat generation
- Special teams foundation for detailed position effects
- Rivalry system supports unlimited rivalry definitions
- Situational states support narrative generation

## Approved By
Architecture Guardian (this session)

## Next Steps
1. Set up proper workspace at `/home/user/gridiron-dynasty/workspaces/team-gamesim`
2. Implement all features following this architecture
3. Run code-quality-reviewer
4. Submit completion report to Director with 9.5+ score
