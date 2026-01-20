# Integration Tests for Pure Functional State Management

This directory contains comprehensive integration tests for the refactored pure functional state management infrastructure.

## Test Files

### 1. DraftIntegrationTest.gd
Tests the full draft flow using the refactored `NflDraft.gd` with `DraftStateManager`.

**Coverage:**
- Complete draft simulation produces valid results
- Determinism: Same RNG seed produces identical draft outcomes
- Different seeds produce different outcomes
- Draft state machine transitions (INITIALIZING → RUNNING → COMPLETED)
- Invalid state transitions are rejected
- Undrafted players stored correctly in `undrafted_pool`
- Draft history recorded correctly
- Pick trading/ownership works correctly
- Drafted players added to rosters with valid contracts
- Immutability: Configs not corrupted by draft operations

**Key Tests:**
- `test_complete_draft_simulation_produces_valid_results()`
- `test_same_seed_produces_identical_draft_outcomes()`
- `test_draft_state_machine_transitions_correctly()`
- `test_undrafted_players_stored_correctly()`
- `test_draft_history_recorded_correctly()`
- `test_pick_ownership_transfer_works()`
- `test_drafted_players_added_to_rosters_with_contracts()`

### 2. SeasonIntegrationTest.gd
Tests season simulation end-to-end using the refactored season files with `SeasonStateManager`.

**Coverage:**
- Game results update standings correctly (wins, losses, ties)
- Multiple game results accumulate correctly
- Season phase transitions work (PRE_SEASON → REGULAR_SEASON → PLAYOFFS)
- Invalid phase transitions are rejected
- NFL season completes successfully
- College season completes and generates draft-eligible players
- All three season levels (HS, College, NFL) run sequentially
- Roster preparation adds simulation fields correctly
- Determinism: Same seed produces same results
- Immutability: Configs not corrupted

**Key Tests:**
- `test_game_results_update_standings_correctly()`
- `test_season_phase_transitions_work()`
- `test_nfl_season_completes_successfully()`
- `test_nfl_season_determinism()`
- `test_college_season_draft_eligibility_processing()`
- `test_all_three_season_levels_complete_sequentially()`
- `test_roster_preparation_adds_simulation_fields()`

### 3. ContractIntegrationTest.gd
Tests contract operations end-to-end using the refactored `FreeAgency.gd` with `ContractStateManager`.

**Coverage:**
- Full free agency simulation completes successfully
- Signings update rosters correctly
- Signings update cap space correctly
- Signed players have valid contracts
- Franchise tags applied and stored correctly
- Player releases work correctly (roster removal, cap impact)
- Cap space accounting is accurate
- Cap space never goes negative
- UDFA signings work correctly
- Determinism: Same seed produces same signings
- Immutability: Configs not corrupted

**Key Tests:**
- `test_full_free_agency_simulation_completes()`
- `test_free_agency_determinism()`
- `test_signings_update_rosters_correctly()`
- `test_signings_update_cap_space_correctly()`
- `test_franchise_tags_applied_correctly()`
- `test_player_release_works_correctly()`
- `test_cap_space_never_goes_negative()`
- `test_udfa_signings_work_correctly()`

### 4. CrossSystemIntegrationTest.gd
Tests interactions between refactored systems to verify cross-system integration.

**Coverage:**
- Draft → Free Agency flow (UDFAs transition correctly)
- Season → Contract flow (expired contracts become free agents)
- Full year cycle: College Season → NFL Draft → Free Agency
- Player IDs remain consistent across system boundaries
- World state structure maintained across all operations
- Roster sizes remain valid throughout full cycle
- State machines coordinate correctly without conflicts
- Full cycle determinism (same seeds = same results across all systems)

**Key Tests:**
- `test_undrafted_players_flow_to_free_agency()`
- `test_season_expiration_creates_free_agents()`
- `test_full_year_cycle_season_draft_free_agency()`
- `test_full_year_cycle_determinism()`
- `test_player_ids_consistent_across_systems()`
- `test_world_state_structure_maintained_across_systems()`
- `test_roster_sizes_remain_valid_across_cycle()`
- `test_state_machines_coordinate_correctly()`

## Running the Tests

### Run All Integration Tests
```bash
# Using GdUnit4 CLI
gdunit4 tests/integration/

# Or run individual test files
gdunit4 tests/integration/DraftIntegrationTest.gd
gdunit4 tests/integration/SeasonIntegrationTest.gd
gdunit4 tests/integration/ContractIntegrationTest.gd
gdunit4 tests/integration/CrossSystemIntegrationTest.gd
```

### Run Specific Test
```bash
gdunit4 tests/integration/DraftIntegrationTest.gd::test_same_seed_produces_identical_draft_outcomes
```

## Test Architecture

### Test Structure
All integration tests follow this pattern:

```gdscript
extends GdUnitTestSuite

# Setup
func before_test() -> void:
    world_state = _create_test_world_state()
    test_configs = _create_test_configs()

func after_test() -> void:
    world_state.clear()
    test_configs.clear()

# Test methods
func test_feature_works_correctly() -> void:
    # Arrange
    var year := 2025
    var seed := 12345

    # Act
    var result := System.run(world_state, year, seed, ...)

    # Assert
    assert_that(result["success"]).is_true()
```

### Helper Functions
Each test file provides helper functions to create minimal valid test data:

- `_create_test_world_state()` - Minimal valid world state
- `_create_test_configs()` - Minimal valid configuration
- `_create_test_teams()` - Test NFL teams
- `_create_test_players()` - Test player data
- `_create_test_rosters()` - Test roster data

## Key Testing Principles

### 1. Determinism Verification
Every system must produce identical results with the same seed:

```gdscript
func test_determinism() -> void:
    var result_1 := run_with_seed(12345)
    var result_2 := run_with_seed(12345)
    assert_that(result_2).is_equal(result_1)
```

### 2. Immutability Verification
Config objects must not be mutated:

```gdscript
func test_immutability() -> void:
    var config_copy := config.duplicate(true)
    var config_hash := hash(config)

    run_system(config)

    assert_that(hash(config)).is_equal(config_hash)
```

### 3. State Machine Verification
Valid transitions succeed, invalid transitions fail:

```gdscript
func test_state_machine() -> void:
    # Valid transition
    var success := advance_phase(PHASE_A, PHASE_B)
    assert_that(success).is_true()

    # Invalid transition
    success = advance_phase(PHASE_A, PHASE_Z)
    assert_that(success).is_false()
```

### 4. Cross-System Verification
Data flows correctly between systems:

```gdscript
func test_cross_system_flow() -> void:
    run_draft(world_state)
    assert_that(world_state.has("undrafted_pool")).is_true()

    run_free_agency(world_state)
    # Verify UDFAs were processed
```

## Expected Behavior

### All Tests Should Pass
These integration tests verify that the refactored pure functional state management infrastructure:

1. **Works correctly** - All systems complete successfully
2. **Is deterministic** - Same seeds always produce same results
3. **Maintains immutability** - Configs and pure function inputs are not mutated
4. **Validates state** - State machines reject invalid transitions
5. **Integrates cleanly** - Systems work together without conflicts
6. **Preserves data** - Player IDs, roster sizes, world state structure remain valid

### Regression Detection
These tests will catch:

- Breaking changes to state management APIs
- Determinism violations (RNG leaks, order dependencies)
- State machine bugs (invalid transitions, stuck states)
- Cross-system integration issues (data format mismatches)
- Immutability violations (configs or inputs being mutated)
- Cap space accounting errors
- Roster integrity issues

## Test Maintenance

### Adding New Tests
When adding new features:

1. Add unit tests to `tests/core/state/` for state manager methods
2. Add integration tests here for end-to-end flows
3. Update `CrossSystemIntegrationTest.gd` if the feature spans multiple systems

### Updating Existing Tests
When refactoring systems:

1. Update helper functions if world state structure changes
2. Update assertions if output format changes
3. Keep determinism tests - they're critical for regression detection

## Related Documentation

- **Unit Tests**: `tests/core/state/` - Tests for individual state manager methods
- **Architecture**: `docs/architecture/pure-functional-state-management.md`
- **Engineer Protocols**: `docs/agents/ENGINEER_PROTOCOLS.md`
- **State Managers**: `scripts/core/state/` - Implementation files

## Troubleshooting

### Test Failures

**Determinism failures** (same seed produces different results):
- Check for RNG leaks (new RNG instances mid-simulation)
- Check for order dependencies (dictionary iteration, unsorted arrays)
- Check for timestamp usage (Time.get_ticks_msec())

**State machine failures** (invalid transitions accepted/rejected incorrectly):
- Check StateMachine implementation
- Check StateManager transition validation
- Check that world_state is being updated correctly

**Cross-system failures** (data doesn't flow between systems):
- Check field name consistency (`player_id` vs `id`)
- Check world state structure (arrays vs dictionaries)
- Check that intermediate state is being stored correctly

**Immutability failures** (configs are being mutated):
- Check that `.duplicate(true)` is used when copying
- Check that pure functions return new objects
- Check that StateManager doesn't mutate inputs

### Performance Issues

If tests are slow:
- Reduce test data size (fewer teams, players, games)
- Skip expensive operations (trades, detailed simulation)
- Use `options: {"skip_trades": true}` for season tests

## Success Criteria

✅ All 40+ integration tests pass
✅ Determinism verified across all systems
✅ Immutability verified for all configs
✅ State machines validated
✅ Cross-system integration verified
✅ No regression from refactoring
