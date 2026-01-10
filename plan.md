# World Simulation Roadmap - Active Work

For completed phases, see `COMPLETED.md`.

## Working Agreements (All Agents)
- Prefer explicit state transitions over hidden state.
- RNG must be passed explicitly; seeds logged or persisted per phase.
- Keep changes small and reviewable.
- Avoid UI unless required by simulation correctness.

## Bootstrap Loop (Reference)
Each simulated year runs these steps in order:
```
1. Generate players at NFL draft peak potential
2. De-age them to HS freshman level
3. Sort/assign them to high schools
4. Simulate HS season (advance all HS players)
5. Simulate college recruiting (HS grads → college commits)
6. Simulate college season (advance all college players)    ← MISSING
7. Simulate NFL draft (draft-eligible → NFL teams)          ← MISSING
8. Simulate NFL season (advance all NFL players)            ← MISSING
9. Repeat for ~20 years to build populated world
```
Steps 1-5 are implemented. Steps 6-8 need implementation.

---

# Parallel Work Tracks

Work is organized into independent tracks that can be developed simultaneously.
Each track has a designated Engineer. Dependencies between tracks are noted.

```
┌─────────────────┐     ┌─────────────────┐
│  TRACK A        │     │  TRACK B        │
│  College Season │     │  NFL Teams      │
│  (Engineer 1)   │     │  (Engineer 2)   │
└────────┬────────┘     └────────┬────────┘
         │                       │
         ▼                       ▼
┌─────────────────────────────────────────┐
│              TRACK C                     │
│           NFL Draft + Season             │
│            (Engineer 3)                  │
│   [Blocked by: Track A + Track B]        │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────┐
│              TRACK D                     │
│        Integration + Preview             │
│            (Engineer 4)                  │
│        [Blocked by: Track C]             │
└─────────────────────────────────────────┘
```

---

## Track A: College Season Pipeline
**Engineer 1** | No dependencies | Unblocks: Track C

### A1. Add college roster containers to world_state
Modify `scripts/pipelines/AdvanceWorldYear.gd`:
- In `_handle_college_recruiting`, after commitments are recorded:
  - Retrieve full player dicts from `hs_recruit_pool` (not just IDs)
  - Initialize `world_state.college_rosters[college_id]`:
    ```gdscript
    {
      "players": [player_dict, ...],
      "class_years": {1: [...], 2: [...], 3: [...], 4: [...]}
    }
    ```
  - Set on each player: `college_id`, `college_year: 1`,
    `college_eligibility_status: "freshman"`

### A2. Implement CollegeSeason.gd
Create `scripts/world/CollegeSeason.gd`:
```gdscript
func run(world_state: Dictionary, year: int, seed: int, config: Dictionary) -> Dictionary:
    # For each college roster:
    #   - Call PlayerLifecycle.advance_one_year with college development_context
    #   - Increment college_year (1→2→3→4)
    #   - Update college_eligibility_status (freshman→sophomore→junior→senior)
    #   - Check for early declarations (juniors with high ratings)
    #   - Seniors + early declares → draft_eligible status
    #   - Remove draft-eligible from roster, add to draft_pool[year]
    # Return: {rosters_updated, graduates, draft_eligible_count, step_seeds}
```

Development context for colleges (derive from college tier):
```gdscript
{
    "program_quality": college.eliteness / 100.0,
    "competition_tier": _tier_multiplier(college.tier),
    "usage": _roll_usage(rng),
    "season": "college",
    "year": year
}
```

### A3. Add early declaration logic
In CollegeSeason, for juniors (college_year == 3):
- Roll for early declaration based on player rating
- Config in `world/colleges.json`:
  ```json
  "early_declaration": {
    "min_year": 3,
    "rating_threshold": 85.0,
    "base_chance": 0.15,
    "rating_bonus_per_point": 0.01
  }
  ```

### A4. Wire college_season handler in AdvanceWorldYear.gd
- Add handler mapping: `"college_season": _handle_college_season`
- Implement `_handle_college_season`:
  ```gdscript
  func _handle_college_season(world_state, year, _seed, phase, year_seed) -> Dictionary:
      var step_seed := _derive_seed(year_seed, phase.phase_id, "college_season")
      var season := CollegeSeason.new()
      return season.run(world_state, year, step_seed, Config.get_config("world/colleges"))
  ```

### A5. Add test coverage
Create `scripts/tests/test_college_season.gd`:
- Verify roster advancement (year 1→2→3→4)
- Verify eligibility transitions
- Verify draft pool output includes seniors + early declares
- Assert determinism with fixed seed

**Files to create:** `scripts/world/CollegeSeason.gd`, `scripts/tests/test_college_season.gd`
**Files to modify:** `scripts/pipelines/AdvanceWorldYear.gd`, `configs/sports/american_football/world/colleges.json`

---

## Track B: NFL Teams Infrastructure
**Engineer 2** | No dependencies | Unblocks: Track C

### B1. Expand league.json with team definitions
Modify `configs/sports/american_football/world/league.json`:
```json
{
  "version": 2,
  "cap_limit": 200.0,
  "team_count": 32,
  "name_format": "Team %03d",
  "regions": [
    {"id": "afc_east", "weight": 0.125},
    {"id": "afc_north", "weight": 0.125},
    {"id": "afc_south", "weight": 0.125},
    {"id": "afc_west", "weight": 0.125},
    {"id": "nfc_east", "weight": 0.125},
    {"id": "nfc_north", "weight": 0.125},
    {"id": "nfc_south", "weight": 0.125},
    {"id": "nfc_west", "weight": 0.125}
  ],
  "roster_limits": {
    "active": 53,
    "practice_squad": 16,
    "injured_reserve": 15
  },
  "draft": {
    "rounds": 7,
    "picks_per_round": 32
  }
}
```

### B2. Implement NflTeamGenerator.gd
Create `scripts/world/NflTeamGenerator.gd`:
```gdscript
func generate(seed: int, config_key: String = "world/league") -> Dictionary:
    # Load config, validate
    # Generate team_count teams with:
    #   - id: "nfl_%03d" % (i + 1)
    #   - name: from name_format
    #   - region: weighted pick from regions
    #   - cap_space: from cap_limit
    #   - roster: empty array
    #   - draft_order: i + 1 (initial, will be updated by standings)
    # Return: {teams: [...], config: {...}}
```

### B3. Wire nfl_team_generation handler in AdvanceWorldYear.gd
- Add `nfl_team_generation` phase to calendar.json (after college_generation)
- Add handler mapping: `"nfl_team_generation": _handle_nfl_team_generation`
- Implement handler to generate teams once (like colleges):
  ```gdscript
  func _handle_nfl_team_generation(world_state, year, _seed, phase, year_seed) -> Dictionary:
      var teams: Array = world_state.get("nfl_teams", [])
      if not teams.is_empty():
          return {"year": year, "count": teams.size(), "cached": true}
      var step_seed := _derive_seed(year_seed, phase.phase_id, "nfl_team_generation")
      var generator := NflTeamGenerator.new()
      var result := generator.generate(step_seed)
      world_state["nfl_teams"] = result.get("teams", [])
      world_state["nfl_rosters"] = {}  # Initialize empty rosters
      return {"year": year, "count": result.teams.size(), "step_seeds": {phase.phase_id: step_seed}}
  ```

### B4. Update calendar.json
Add phase after college_generation:
```json
{
  "id": "nfl_team_generation",
  "label": "NFL team generation",
  "start_tick": 4,
  "end_tick": 4,
  "tags": ["nfl"],
  "placeholder": false
}
```
(Renumber subsequent phases)

### B5. Add test coverage
Create `scripts/tests/test_nfl_team_generator.gd`:
- Verify team_count teams generated
- Verify deterministic IDs and region distribution
- Verify roster_limits loaded correctly
- Assert determinism with fixed seed

**Files to create:** `scripts/world/NflTeamGenerator.gd`, `scripts/tests/test_nfl_team_generator.gd`
**Files to modify:** `configs/sports/american_football/world/league.json`, `configs/sports/american_football/world/calendar.json`, `scripts/pipelines/AdvanceWorldYear.gd`

---

## Track C: NFL Draft + Season
**Engineer 3** | Blocked by: Track A, Track B | Unblocks: Track D

### C1. Implement NflDraft.gd
Create `scripts/world/NflDraft.gd`:
```gdscript
func run(world_state: Dictionary, year: int, seed: int, config: Dictionary) -> Dictionary:
    var draft_pool: Array = world_state.get("draft_pool", {}).get(year, [])
    var teams: Array = world_state.get("nfl_teams", [])
    var rosters: Dictionary = world_state.get("nfl_rosters", {})

    # Sort teams by draft_order
    # For each round (1-7):
    #   For each team in draft order:
    #     - Create team scout (or use cached)
    #     - Rate remaining draft pool
    #     - Select best available (with position need weighting)
    #     - Add to team roster with rookie contract
    #     - Remove from draft pool
    #
    # world_state["nfl_rosters"] = updated rosters
    # world_state["undrafted_pool"][year] = remaining players
    # Return: {picks: [...], undrafted_count, step_seeds}
```

Draft selection logic:
- Scout rates all available players
- Weight by team positional needs (simple: positions with < 2 players)
- Select highest weighted score
- Assign rookie contract based on pick number

### C2. Implement NflSeason.gd
Create `scripts/world/NflSeason.gd`:
```gdscript
func run(world_state: Dictionary, year: int, seed: int, config: Dictionary) -> Dictionary:
    var teams: Array = world_state.get("nfl_teams", [])
    var rosters: Dictionary = world_state.get("nfl_rosters", {})
    var retired: Array = world_state.get("retired_players", [])

    # For each team:
    #   - Get roster from nfl_rosters[team_id]
    #   - Call PlayerLifecycle.advance_one_year with NFL development_context
    #   - Check for retirements (age > retirement_age or rating drop)
    #   - Track contract expirations
    #   - Update roster
    #
    # world_state["nfl_rosters"] = updated rosters
    # world_state["retired_players"] = retired + new_retirees
    # world_state["free_agents"][year] = expired contracts
    # Return: {roster_counts, retirements, free_agents, step_seeds}
```

NFL development context:
```gdscript
{
    "program_quality": 1.0,  # NFL is top tier
    "competition_tier": 1.1,  # Highest competition
    "usage": _roll_nfl_usage(player, rng),
    "season": "nfl",
    "year": year
}
```

### C3. Wire handlers in AdvanceWorldYear.gd
- Replace placeholder for `nfl_draft` with `_handle_nfl_draft`
- Add `nfl_season` phase to calendar.json (after cap_validation)
- Add handler for `nfl_season`

### C4. Update calendar.json
Ensure phase ordering:
```
hs_generation → hs_assignment → hs_season →
college_generation → nfl_team_generation → college_recruiting →
college_season → draft_prep → nfl_draft → cap_validation → nfl_season
```

### C5. Add test coverage
Create `scripts/tests/test_nfl_draft.gd`:
- Verify all picks made (rounds × teams)
- Verify players assigned to correct rosters
- Verify undrafted pool contains remaining players
- Assert determinism

Create `scripts/tests/test_nfl_season.gd`:
- Verify roster advancement
- Verify retirement handling
- Verify contract expiration tracking
- Assert determinism

**Files to create:** `scripts/world/NflDraft.gd`, `scripts/world/NflSeason.gd`, `scripts/tests/test_nfl_draft.gd`, `scripts/tests/test_nfl_season.gd`
**Files to modify:** `scripts/pipelines/AdvanceWorldYear.gd`, `configs/sports/american_football/world/calendar.json`

---

## Track D: Integration + Preview
**Engineer 4** | Blocked by: Track C | Final integration

### D1. Implement BootstrapGameWorld.gd
Create `scripts/pipelines/BootstrapGameWorld.gd`:
```gdscript
extends Node
class_name BootstrapGameWorld

@export var years_to_simulate: int = 20

func run(base_seed: int = 0) -> Dictionary:
    var main_cfg := Config.get_config("main")
    var start_year := int(main_cfg.get("starting_year", 2025))
    var seed := base_seed if base_seed != 0 else int(main_cfg.get("random_seed", 0))

    var world_state: Dictionary = {}
    var advance := AdvanceWorldYear.new()

    var first_year := start_year - years_to_simulate + 1
    for year in range(first_year, start_year + 1):
        var year_seed := _resolve_year_seed(seed, year)
        var result := advance.run(world_state, year, year_seed)
        world_state = result.get("world_state", world_state)

    return {
        "years_simulated": years_to_simulate,
        "start_year": start_year,
        "first_year": first_year,
        "world_state": world_state,
        "summary": _build_summary(world_state)
    }

func _build_summary(world_state: Dictionary) -> Dictionary:
    return {
        "hs_schools": (world_state.get("hs_schools", []) as Array).size(),
        "hs_players": (world_state.get("hs_players", []) as Array).size(),
        "colleges": (world_state.get("colleges", []) as Array).size(),
        "college_rosters": _count_college_players(world_state),
        "nfl_teams": (world_state.get("nfl_teams", []) as Array).size(),
        "nfl_players": _count_nfl_players(world_state),
        "retired_players": (world_state.get("retired_players", []) as Array).size()
    }
```

### D2. Update BootstrapPreview.gd
Modify `scripts/pipelines/BootstrapPreview.gd`:
- Replace `BootstrapWorld.run()` with `BootstrapGameWorld.run()`
- Update output to show full world summary:
  ```
  🏈 Bootstrapped game world (20 years)
  HS Schools: 420 | HS Players: 1,680
  Colleges: 130 | College Players: 2,860
  NFL Teams: 32 | NFL Players: 1,696
  Retired: 4,230
  ```

### D3. Add test coverage
Create `scripts/tests/test_bootstrap_game_world.gd`:
- Verify output contains all required containers
- Verify multi-year simulation populates all levels (HS, college, NFL)
- Verify retired_players accumulates over time
- Assert determinism across runs with same seed

### D4. Register all new tests
Update `scripts/tests/TestRunner.gd` with all Track A-D tests.

**Files to create:** `scripts/pipelines/BootstrapGameWorld.gd`, `scripts/tests/test_bootstrap_game_world.gd`
**Files to modify:** `scripts/pipelines/BootstrapPreview.gd`, `scripts/tests/TestRunner.gd`

---

# Review Checklist (All Tracks)

After each track is complete, verify:

1. **Determinism**: All RNG is explicit, seeds logged, same seed = same output
2. **State transitions**: Player status changes are explicit and logged
3. **No data loss**: Roster operations preserve player data
4. **Config-driven**: Magic numbers extracted to config files
5. **Test coverage**: All new code has deterministic tests

# Final Phase Ordering (calendar.json)

After all tracks complete:
```
1. hs_generation
2. hs_assignment
3. hs_season
4. college_generation
5. nfl_team_generation    ← NEW (Track B)
6. college_recruiting
7. college_season         ← NEW (Track A)
8. draft_prep
9. nfl_draft              ← IMPLEMENTED (Track C)
10. cap_validation
11. nfl_season            ← NEW (Track C)
```
