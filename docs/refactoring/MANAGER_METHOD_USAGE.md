# SeasonStateManager Method Usage by File

Quick reference for which season files use which manager methods.

## NflSeason.gd

### Currently Used
- **SeasonStateManager.record_game_results()** (line 868)
  - Purpose: Record all NFL game results for the season
  - Path: `["season_records", year]`
  - Input: Array of game results from GameSimulator
  - Output: Updated standings in world_state

### Not Yet Used (Future)
- **SeasonStateManager.advance_season_phase()**
  - Would track: PRE_SEASON → REGULAR_SEASON → PLAYOFFS → POST_SEASON → OFF_SEASON → DRAFT → FREE_AGENCY
  - Benefit: Formal state machine validation, better error detection

- **SeasonStateManager.update_roster_for_season()**
  - Would add: injury_status, stamina, morale, overall_rating
  - Current: Development context is applied separately (usage, competition_tier)
  - Decision: Keep separate for now, evaluate if both are needed

### Direct Mutations (Documented)
- **Roster updates** (lines 101-117)
  - Purpose: Apply NFL-specific development context
  - Reason: Preparatory work for PlayerStateManager
  - Status: Acceptable, documented

- **Free agents, retirements, trades**
  - Lines: 182-188, 213
  - Purpose: Collection-level updates
  - Status: Future candidates for manager methods

---

## CollegeSeason.gd

### Currently Used
- **SeasonStateManager.record_game_results()** (line 614)
  - Purpose: Record all college game results for the season
  - Path: `["season_records", year]`
  - Input: Array of game results from GameSimulator
  - Output: Updated standings in world_state

### Not Yet Used (Future)
- **SeasonStateManager.advance_season_phase()**
  - Would track: PRE_SEASON → REGULAR_SEASON → PLAYOFFS → POST_SEASON → OFF_SEASON
  - Benefit: Coordinate with recruiting cycles, bowl season

- **SeasonStateManager.process_draft_eligibility()**
  - Current: Custom logic for rating thresholds and early declaration
  - Blocker: Manager's method uses simpler rules (class year, age, opt-in chance)
  - Next Step: Extend manager to support custom eligibility validators
  - Lines: 129-178

### Direct Mutations (Documented)
- **Roster updates** (lines 96-109)
  - Purpose: Apply college-specific development context
  - Reason: Preparatory work for PlayerStateManager
  - Status: Acceptable, documented

- **Draft pool** (lines 186-192)
  - Purpose: Global collection assembly from multiple rosters
  - Reason: Cross-roster aggregation, not per-roster operation
  - Status: Acceptable, documented

- **Transfer portal, team history**
  - Lines: 438, 781
  - Purpose: Collection-level updates
  - Status: Future candidates for manager methods

---

## HighSchoolSeason.gd

### Currently Used
- **Pure Transformation Pattern**
  - **_apply_year_transition()** (lines 330-368)
  - Purpose: Calculate year advancement and graduation status
  - Pattern: Pure function that doesn't mutate input
  - Benefit: Testable, deterministic, follows manager principles

### Not Yet Used (Future)
- **SeasonStateManager methods**
  - Reason: HighSchoolSeason doesn't directly use world_state (uses temp_world_state)
  - Design: Different architecture from NFL/College seasons
  - Status: Pure function pattern already applied, manager not needed

### Direct Mutations (Documented)
- **Year transitions** (lines 64-90)
  - Purpose: Apply calculated transitions to players
  - Reason: Local transformations on temp_world_state
  - Status: Acceptable, uses pure function for calculation

---

## Summary Table

| File | record_game_results | advance_season_phase | update_roster_for_season | process_draft_eligibility |
|------|---------------------|----------------------|--------------------------|---------------------------|
| **NflSeason.gd** | ✅ Used (line 868) | ⏳ Future | 🤔 Evaluate | N/A |
| **CollegeSeason.gd** | ✅ Used (line 614) | ⏳ Future | 🤔 Evaluate | 🔧 Needs Extension |
| **HighSchoolSeason.gd** | N/A (no games) | N/A | N/A | N/A |

**Legend:**
- ✅ **Used**: Currently integrated
- ⏳ **Future**: Planned for future phases
- 🤔 **Evaluate**: Need to assess if this is the right fit
- 🔧 **Needs Extension**: Manager method needs enhancement to support use case
- **N/A**: Not applicable to this file's architecture

---

## Implementation Priority

### High Priority (Next Sprint)
1. **advance_season_phase()** in NFL and College seasons
   - Add phase tracking to season state
   - Use state machine for validation
   - Improve error detection

### Medium Priority (2-3 Sprints)
2. **process_draft_eligibility()** extension for College
   - Add custom validator support to manager
   - Refactor college draft eligibility to use manager
   - Maintain complex business logic

3. **Collection update methods** for free agents, retirements, trades
   - Create manager methods for these operations
   - Ensure DataBus notifications
   - Maintain consistency

### Low Priority (Backlog)
4. **update_roster_for_season()** evaluation
   - Determine if simulation fields are needed
   - Consider separating development context from simulation prep
   - Avoid duplicate work

---

## Code Patterns

### Pattern 1: Game Results (IMPLEMENTED)
```gdscript
# Use manager for batch game result recording
var standings_path := ["season_records", year]
var record_result := SeasonStateManager.record_game_results(
    world_state,
    standings_path,
    all_results
)

# Read back updated standings
var season_records: Dictionary = world_state.get("season_records", {})
var season_results: Dictionary = season_records.get(year, {})
```

### Pattern 2: Pure Transformations (IMPLEMENTED in HS)
```gdscript
# Calculate transition with pure function
var year_transition := _apply_year_transition(player, hs_years, underclass_years)

# Apply results to player
player["hs_year"] = year_transition["new_year"]
player["eligibility_status"] = year_transition["new_status"]
```

### Pattern 3: Phase Transitions (FUTURE)
```gdscript
# Track and validate phase transitions
var success := SeasonStateManager.advance_season_phase(
    world_state,
    ["nfl_season_state"],
    SeasonStateMachine.SeasonPhase.REGULAR_SEASON,
    SeasonStateMachine.SeasonPhase.PLAYOFFS
)

if not success:
    push_error("Invalid phase transition")
    return
```

### Pattern 4: Documented Direct Mutation (CURRENT)
```gdscript
# Apply league-specific development context
var prepared_players := _apply_development_context(players, context_rng, year)

# NOTE: Direct mutation is acceptable here because:
# 1. This is preparatory work for PlayerStateManager
# 2. Development context is league-specific
# 3. This is distinct from roster preparation (simulation fields)
roster["players"] = prepared_players
rosters[team_id] = roster
world_state["rosters"] = rosters
```

---

## Notes

- **Development Context vs. Roster Preparation**: These are two distinct operations that happen at different stages. Development context (usage, competition tier) is league-specific and happens before lifecycle simulation. Roster preparation (injury_status, stamina, morale) is generic and happens before game simulation.

- **DataBus Integration**: Manager methods automatically emit DataBus signals. Direct mutations bypass this, so they should be limited to preparatory work that doesn't need UI updates.

- **RNG Determinism**: All manager methods are designed to maintain RNG determinism. Pure transformation functions consume no RNG.

- **Backward Compatibility**: Manager methods are path-agnostic, so they can work with existing data structures (season_records vs. nfl_standings).
