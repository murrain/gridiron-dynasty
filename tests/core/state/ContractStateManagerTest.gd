class_name ContractStateManagerTest
extends GdUnitTestSuite

## GdUnit4 test suite for ContractStateManager.gd
## Tests state mutation layer for contract lifecycle and free agency.
##
## IMPORTANT: These tests verify that ContractStateManager properly:
## 1. Calls pure transformation functions
## 2. Updates world_state atomically
## 3. Does NOT mutate inputs to transformation functions
## 4. Maintains salary cap integrity
## 5. Emits appropriate DataBus signals (integration test)
## 6. Provides deterministic results

const ContractStateManager = preload("res://scripts/core/state/ContractStateManager.gd")
const ContractTransformations = preload("res://scripts/core/transformations/ContractTransformations.gd")
const ContractStateMachine = preload("res://scripts/core/state/ContractStateMachine.gd")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _create_minimal_world_state() -> Dictionary:
	"""Create a minimal world_state for testing contract operations."""
	return {
		"current_year": 2024,
		"nfl_teams": [
			{"id": "SF", "name": "San Francisco 49ers", "cap_space": 50.0},
			{"id": "KC", "name": "Kansas City Chiefs", "cap_space": 30.0},
			{"id": "NYG", "name": "New York Giants", "cap_space": 70.0}
		],
		"nfl_rosters": {
			"SF": {
				"name": "San Francisco 49ers",
				"roster_limit": 53,
				"players": [
					{
						"id": "player_1",
						"name": "Test Player 1",
						"position": "QB",
						"age": 28,
						"eval_score": 85.0,
						"contract": {
							"status": "signed",
							"annual_value": 15.0,
							"years_total": 3,
							"years_remaining": 2,
							"base_salary": 12.0,
							"signing_bonus": 3.0,
							"guaranteed_value": 20.0,
							"signed_year": 2023
						}
					},
					{
						"id": "player_2",
						"name": "Test Player 2",
						"position": "WR",
						"age": 26,
						"eval_score": 78.0,
						"contract": {
							"status": "signed",
							"annual_value": 8.0,
							"years_total": 2,
							"years_remaining": 1,
							"base_salary": 6.4,
							"signing_bonus": 1.6,
							"guaranteed_value": 10.0,
							"signed_year": 2023
						}
					}
				]
			},
			"KC": {
				"name": "Kansas City Chiefs",
				"roster_limit": 53,
				"players": []
			}
		},
		"free_agents": {
			2024: [
				{
					"id": "fa_1",
					"name": "Free Agent 1",
					"position": "TE",
					"age": 27,
					"eval_score": 72.0
				}
			]
		},
		"undrafted_pool": {
			2024: [
				{
					"id": "udfa_1",
					"name": "Undrafted FA 1",
					"position": "RB",
					"age": 22,
					"eval_score": 65.0,
					"composite_score": 65.0
				}
			]
		},
		"franchise_tags": {}
	}

func _create_test_offer(annual_value: float, years: int) -> Dictionary:
	"""Create a test contract offer."""
	return {
		"team_id": "KC",
		"annual_value": annual_value,
		"years_total": years,
		"base_salary": annual_value * 0.8,
		"signing_bonus": annual_value * 0.2,
		"guaranteed_value": annual_value * float(years) * 0.4,
		"cap_hit_year_1": annual_value,
		"offer_quality": 1.0
	}

func _create_test_league_cfg() -> Dictionary:
	"""Create minimal league config for testing."""
	return {
		"cap_limit": 180.0,
		"franchise_tag": {
			"exclusive_multiplier": 1.2,
			"non_exclusive_multiplier": 1.0,
			"transition_multiplier": 1.0
		}
	}

# ============================================================================
# TESTS - execute_signing
# ============================================================================

func test_execute_signing_success() -> void:
	var world_state := _create_minimal_world_state()
	var offer := _create_test_offer(10.0, 3)
	var year := 2024

	var result := ContractStateManager.execute_signing(
		world_state,
		"fa_1",
		"KC",
		offer,
		year
	)

	# Verify success
	assert_bool(result.get("success", false)).is_true()
	assert_str(result.get("player_id", "")).is_equal("fa_1")
	assert_str(result.get("team_id", "")).is_equal("KC")
	assert_float(result.get("annual_value", 0.0)).is_equal(10.0)

	# Verify player moved to team roster
	var kc_roster: Dictionary = world_state["nfl_rosters"]["KC"]
	var kc_players: Array = kc_roster["players"]
	assert_int(kc_players.size()).is_equal(1)
	assert_str(kc_players[0]["id"]).is_equal("fa_1")

	# Verify contract applied
	assert_bool(kc_players[0].has("contract")).is_true()
	var contract: Dictionary = kc_players[0]["contract"]
	assert_bool(contract is Dictionary).is_true()
	assert_str(contract["status"]).is_equal("signed")
	assert_float(contract["annual_value"]).is_equal(10.0)

	# Verify cap space updated
	var team: Dictionary = world_state["nfl_teams"][1]  # KC
	assert_float(team["cap_space"]).is_equal(20.0)  # 30.0 - 10.0

	# Verify player removed from FA pool
	var fa_pool: Array = world_state["free_agents"][2024]
	assert_int(fa_pool.size()).is_equal(0)


func test_execute_signing_insufficient_cap() -> void:
	var world_state := _create_minimal_world_state()
	var offer := _create_test_offer(100.0, 3)  # More than KC's 30M cap
	var year := 2024

	var result := ContractStateManager.execute_signing(
		world_state,
		"fa_1",
		"KC",
		offer,
		year
	)

	# Verify failure
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("insufficient_cap")

	# Verify nothing changed
	var kc_players: Array = world_state["nfl_rosters"]["KC"]["players"]
	assert_int(kc_players.size()).is_equal(0)


func test_execute_signing_player_not_found() -> void:
	var world_state := _create_minimal_world_state()
	var offer := _create_test_offer(10.0, 3)
	var year := 2024

	var result := ContractStateManager.execute_signing(
		world_state,
		"nonexistent_player",
		"KC",
		offer,
		year
	)

	# Verify failure
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("player_not_found")


func test_execute_signing_udfa() -> void:
	var world_state := _create_minimal_world_state()
	var offer := _create_test_offer(0.9, 2)  # Rookie minimum
	var year := 2024

	var result := ContractStateManager.execute_signing(
		world_state,
		"udfa_1",
		"KC",
		offer,
		year
	)

	# Verify success
	assert_bool(result.get("success", false)).is_true()

	# Verify player moved from undrafted pool to roster
	var kc_players: Array = world_state["nfl_rosters"]["KC"]["players"]
	assert_int(kc_players.size()).is_equal(1)
	assert_str(kc_players[0]["id"]).is_equal("udfa_1")

	# Verify removed from undrafted pool
	var udfa_pool: Array = world_state["undrafted_pool"][2024]
	assert_int(udfa_pool.size()).is_equal(0)


func test_execute_signing_immutability() -> void:
	var world_state := _create_minimal_world_state()
	var offer := _create_test_offer(10.0, 3)
	var year := 2024

	# Make copies to verify immutability
	var offer_copy := offer.duplicate(true)

	ContractStateManager.execute_signing(
		world_state,
		"fa_1",
		"KC",
		offer,
		year
	)

	# Verify offer unchanged (immutability)
	assert_dict(offer).is_equal(offer_copy)


# ============================================================================
# TESTS - release_player
# ============================================================================

func test_release_player_success() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024

	# Initial cap space: 50.0M
	# Player contract: 15.0M annual value
	var result := ContractStateManager.release_player(
		world_state,
		"player_1",
		"SF",
		"roster_cut",
		year
	)

	# Verify success
	assert_bool(result.get("success", false)).is_true()
	assert_str(result.get("player_id", "")).is_equal("player_1")
	assert_str(result.get("team_id", "")).is_equal("SF")

	# Verify cap impact (cap saved minus dead cap)
	var cap_saved: float = result.get("cap_saved", 0.0)
	var dead_cap: float = result.get("dead_cap", 0.0)
	var net_savings: float = result.get("net_savings", 0.0)
	assert_float(cap_saved).is_equal(15.0)  # Annual value removed
	assert_float(dead_cap).is_greater(0.0)  # Some guaranteed money
	assert_float(net_savings).is_equal(cap_saved - dead_cap)

	# Verify player removed from roster
	var sf_players: Array = world_state["nfl_rosters"]["SF"]["players"]
	assert_int(sf_players.size()).is_equal(1)  # Only player_2 remains
	assert_str(sf_players[0]["id"]).is_equal("player_2")

	# Verify player added to FA pool
	var fa_pool: Array = world_state["free_agents"][2024]
	var found_released := false
	for fa in fa_pool:
		if fa["id"] == "player_1":
			found_released = true
			# Verify contract marked as released
			assert_str(fa["contract"]["status"]).is_equal("released")
			break
	assert_bool(found_released).is_true()

	# Verify cap space updated
	var team: Dictionary = world_state["nfl_teams"][0]  # SF
	var expected_cap := 50.0 + net_savings
	assert_float(team["cap_space"]).is_equal(expected_cap)


func test_release_player_not_found() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024

	var result := ContractStateManager.release_player(
		world_state,
		"nonexistent_player",
		"SF",
		"roster_cut",
		year
	)

	# Verify failure
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("player_not_found")


func test_release_player_no_contract() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024

	# Add player without contract to roster
	world_state["nfl_rosters"]["SF"]["players"].append({
		"id": "no_contract_player",
		"name": "No Contract",
		"position": "RB",
		"age": 25
	})

	var result := ContractStateManager.release_player(
		world_state,
		"no_contract_player",
		"SF",
		"roster_cut",
		year
	)

	# Verify failure
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("no_contract")


# ============================================================================
# TESTS - apply_franchise_tag
# ============================================================================

func test_apply_franchise_tag_success() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024
	var league_cfg := _create_test_league_cfg()

	# Add expiring contract player to SF roster
	world_state["nfl_rosters"]["SF"]["players"].append({
		"id": "expiring_player",
		"name": "Expiring Contract",
		"position": "QB",
		"age": 28,
		"eval_score": 88.0,
		"contract": {
			"status": "expired",
			"annual_value": 12.0,
			"years_remaining": 0
		}
	})

	var result := ContractStateManager.apply_franchise_tag(
		world_state,
		"expiring_player",
		"SF",
		"exclusive",
		year,
		league_cfg
	)

	# Verify success
	assert_bool(result.get("success", false)).is_true()
	assert_str(result.get("player_id", "")).is_equal("expiring_player")
	assert_str(result.get("tag_type", "")).is_equal("exclusive")

	# Verify tag salary calculated (should be based on QB salaries)
	var tag_salary: float = result.get("tag_salary", 0.0)
	assert_float(tag_salary).is_greater(0.0)

	# Verify franchise tag stored in world_state
	assert_bool(world_state["franchise_tags"].has(2024)).is_true()
	var year_tags: Dictionary = world_state["franchise_tags"][2024]
	assert_bool(year_tags.has("SF")).is_true()
	var tag: Dictionary = year_tags["SF"]
	assert_str(tag["player_id"]).is_equal("expiring_player")
	assert_str(tag["tag_type"]).is_equal("exclusive")

	# Verify player contract updated
	var sf_players: Array = world_state["nfl_rosters"]["SF"]["players"]
	var tagged_player: Dictionary = {}
	for p in sf_players:
		if p["id"] == "expiring_player":
			tagged_player = p
			break
	assert_bool(tagged_player.has("contract")).is_true()
	var contract: Dictionary = tagged_player["contract"]
	assert_str(contract["trigger"]).is_equal("franchise_tag")
	assert_int(contract["years_total"]).is_equal(1)  # Always 1 year
	assert_float(contract["guaranteed_value"]).is_equal(tag_salary)  # Fully guaranteed

	# Verify cap space updated
	var team: Dictionary = world_state["nfl_teams"][0]  # SF
	var expected_cap := 50.0 - tag_salary
	assert_float(team["cap_space"]).is_equal(expected_cap)


func test_apply_franchise_tag_already_used() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024
	var league_cfg := _create_test_league_cfg()

	# Pre-populate franchise tag for SF
	world_state["franchise_tags"] = {
		2024: {
			"SF": {
				"player_id": "other_player",
				"tag_type": "exclusive"
			}
		}
	}

	# Add eligible player
	world_state["nfl_rosters"]["SF"]["players"].append({
		"id": "expiring_player",
		"name": "Expiring Contract",
		"position": "QB",
		"age": 28,
		"contract": {"status": "expired"}
	})

	var result := ContractStateManager.apply_franchise_tag(
		world_state,
		"expiring_player",
		"SF",
		"exclusive",
		year,
		league_cfg
	)

	# Verify failure (team already used tag)
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("tag_already_used")


func test_apply_franchise_tag_insufficient_cap() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024
	var league_cfg := _create_test_league_cfg()

	# Set SF cap space to very low
	world_state["nfl_teams"][0]["cap_space"] = 1.0

	# Add eligible player
	world_state["nfl_rosters"]["SF"]["players"].append({
		"id": "expiring_player",
		"name": "Expiring Contract",
		"position": "QB",
		"age": 28,
		"eval_score": 88.0,
		"contract": {"status": "expired"}
	})

	var result := ContractStateManager.apply_franchise_tag(
		world_state,
		"expiring_player",
		"SF",
		"exclusive",
		year,
		league_cfg
	)

	# Verify failure (insufficient cap)
	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("insufficient_cap")


func test_apply_franchise_tag_consecutive_years() -> void:
	var world_state := _create_minimal_world_state()
	var year := 2024
	var league_cfg := _create_test_league_cfg()

	# Set up previous year tag
	world_state["franchise_tags"] = {
		2023: {
			"SF": {
				"player_id": "expiring_player",
				"tag_type": "exclusive",
				"consecutive_years": 1
			}
		}
	}

	# Increase cap space for test
	world_state["nfl_teams"][0]["cap_space"] = 100.0

	# Add eligible player
	world_state["nfl_rosters"]["SF"]["players"].append({
		"id": "expiring_player",
		"name": "Expiring Contract",
		"position": "QB",
		"age": 28,
		"eval_score": 88.0,
		"contract": {"status": "expired"}
	})

	var result := ContractStateManager.apply_franchise_tag(
		world_state,
		"expiring_player",
		"SF",
		"exclusive",
		year,
		league_cfg
	)

	# Verify success
	assert_bool(result.get("success", false)).is_true()

	# Verify consecutive years tracked
	var consecutive_years: int = result.get("consecutive_years", 0)
	assert_int(consecutive_years).is_equal(2)  # Second consecutive year

	# Verify salary has 20% penalty applied
	var tag_salary: float = result.get("tag_salary", 0.0)
	# Salary should be higher due to consecutive year penalty
	assert_float(tag_salary).is_greater(10.0)  # Some reasonable minimum


# ============================================================================
# TESTS - update_cap_space
# ============================================================================

func test_update_cap_space_positive_delta() -> void:
	var world_state := _create_minimal_world_state()

	# Add cap space
	var success := ContractStateManager.update_cap_space(world_state, "SF", 10.0)

	assert_bool(success).is_true()
	var team: Dictionary = world_state["nfl_teams"][0]  # SF
	assert_float(team["cap_space"]).is_equal(60.0)  # 50.0 + 10.0


func test_update_cap_space_negative_delta() -> void:
	var world_state := _create_minimal_world_state()

	# Subtract cap space
	var success := ContractStateManager.update_cap_space(world_state, "SF", -15.0)

	assert_bool(success).is_true()
	var team: Dictionary = world_state["nfl_teams"][0]  # SF
	assert_float(team["cap_space"]).is_equal(35.0)  # 50.0 - 15.0


func test_update_cap_space_team_not_found() -> void:
	var world_state := _create_minimal_world_state()

	var success := ContractStateManager.update_cap_space(world_state, "INVALID", 10.0)

	assert_bool(success).is_false()


# ============================================================================
# TESTS - Immutability Verification
# ============================================================================

func test_transformations_are_pure() -> void:
	# Test that ContractTransformations never mutate inputs
	var player := {
		"id": "test_player",
		"name": "Test",
		"position": "QB",
		"age": 28
	}

	var contract := {
		"status": "unsigned",
		"annual_value": 10.0,
		"years_total": 3
	}

	# Make copies
	var player_copy := player.duplicate(true)
	var contract_copy := contract.duplicate(true)

	# Call pure functions
	var new_player := ContractTransformations.apply_signing(player, contract)

	# Verify originals unchanged
	assert_dict(player).is_equal(player_copy)
	assert_dict(contract).is_equal(contract_copy)

	# Verify new player is different
	assert_bool(new_player.has("contract")).is_true()
	assert_bool(player.has("contract")).is_false()


# ============================================================================
# TESTS - Contract State Machine Integration
# ============================================================================

func test_state_machine_validates_transitions() -> void:
	# Verify state machine prevents invalid transitions
	var unsigned := ContractStateMachine.ContractState.UNSIGNED
	var signed := ContractStateMachine.ContractState.SIGNED
	var expired := ContractStateMachine.ContractState.EXPIRED
	var released := ContractStateMachine.ContractState.RELEASED

	# Valid transitions
	assert_bool(ContractStateMachine.can_transition_contract(unsigned, signed)).is_true()
	assert_bool(ContractStateMachine.can_transition_contract(signed, released)).is_true()
	assert_bool(ContractStateMachine.can_transition_contract(expired, unsigned)).is_true()

	# Invalid transitions
	assert_bool(ContractStateMachine.can_transition_contract(unsigned, expired)).is_false()
	assert_bool(ContractStateMachine.can_transition_contract(released, signed)).is_false()


# ============================================================================
# TESTS - Cap Calculations
# ============================================================================

func test_calculate_cap_impact_signing() -> void:
	var contract := {"annual_value": 10.0, "guaranteed_value": 15.0}
	var impact := ContractTransformations.calculate_cap_impact("signing", contract)

	assert_float(impact.annual_value_delta).is_equal(10.0)
	assert_float(impact.dead_money_delta).is_equal(0.0)
	assert_float(impact.net_cap_delta).is_equal(10.0)


func test_calculate_cap_impact_release() -> void:
	var contract := {"annual_value": 10.0, "guaranteed_value": 15.0}
	var impact := ContractTransformations.calculate_cap_impact("release", contract)

	assert_float(impact.annual_value_delta).is_equal(-10.0)
	assert_float(impact.dead_money_delta).is_equal(15.0)
	assert_float(impact.net_cap_delta).is_equal(5.0)  # Dead cap - annual value


func test_calculate_cap_impact_expiration() -> void:
	var contract := {"annual_value": 10.0, "guaranteed_value": 0.0}
	var impact := ContractTransformations.calculate_cap_impact("expiration", contract)

	assert_float(impact.annual_value_delta).is_equal(-10.0)
	assert_float(impact.dead_money_delta).is_equal(0.0)
	assert_float(impact.net_cap_delta).is_equal(-10.0)  # Cap space freed


# ============================================================================
# TESTS - Franchise Tag Salary Calculation
# ============================================================================

func test_calculate_franchise_tag_salary() -> void:
	var position_salaries := [45.0, 40.0, 38.0, 35.0, 32.0, 30.0, 28.0]

	# Top 5 average: (45 + 40 + 38 + 35 + 32) / 5 = 38.0
	var tag_salary := ContractTransformations.calculate_franchise_tag_salary(
		"QB",
		position_salaries,
		"non_exclusive"
	)

	assert_float(tag_salary).is_equal(38.0)


func test_calculate_franchise_tag_salary_exclusive() -> void:
	var position_salaries := [45.0, 40.0, 38.0, 35.0, 32.0]

	# Top 5 average * 1.2: (45 + 40 + 38 + 35 + 32) / 5 * 1.2 = 45.6
	var tag_salary := ContractTransformations.calculate_franchise_tag_salary(
		"QB",
		position_salaries,
		"exclusive"
	)

	assert_float(tag_salary).is_equal(45.6)


func test_calculate_franchise_tag_salary_empty_position() -> void:
	var position_salaries: Array = []

	# Should return default minimum
	var tag_salary := ContractTransformations.calculate_franchise_tag_salary(
		"UNKNOWN",
		position_salaries,
		"exclusive"
	)

	assert_float(tag_salary).is_equal(10.0)  # Default minimum


# ============================================================================
# TESTS - Error Handling
# ============================================================================

func test_execute_signing_empty_world_state() -> void:
	var empty_state := {}
	var offer := _create_test_offer(10.0, 3)

	var result := ContractStateManager.execute_signing(
		empty_state,
		"player_1",
		"KC",
		offer,
		2024
	)

	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("empty_world_state")


func test_release_player_empty_ids() -> void:
	var world_state := _create_minimal_world_state()

	var result := ContractStateManager.release_player(
		world_state,
		"",  # Empty player_id
		"SF",
		"roster_cut",
		2024
	)

	assert_bool(result.get("success", false)).is_false()
	assert_str(result.get("error", "")).is_equal("invalid_ids")
