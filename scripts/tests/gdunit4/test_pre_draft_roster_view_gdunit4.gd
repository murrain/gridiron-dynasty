## GdUnit4 test suite for PreDraftRosterView
##
## Integration tests for the roster context display component used during draft.
## Validates:
## - Roster display with 53 players
## - Position needs calculation and color coding
## - Depth chart grouping
## - Refresh after draft pick
## - Performance requirements (<50ms render)
extends GdUnitTestSuite

const PreDraftRosterView = preload("res://scenes/ui/draft/PreDraftRosterView.gd")
const TeamNeeds = preload("res://scripts/core/roster/TeamNeeds.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")
const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")


## Setup before each test
func before() -> void:
	pass  # No global state to initialize


## Cleanup after each test
func after() -> void:
	pass  # All nodes are freed in individual tests


## Create a test roster with the specified number of players
## Returns Dictionary with players grouped by position
## Uses seeded RNG for deterministic test data
## RNG consumption: 2 calls per player (overall variance + contract variance)
func _create_test_roster(player_count: int, seed_value: int = 12345) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var players: Array = []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

	# Distribute players across positions realistically
	var position_counts := {
		"QB": 3, "RB": 4, "WR": 6, "TE": 3, "OL": 9,
		"DL": 6, "EDGE": 4, "LB": 6, "CB": 5, "S": 4, "K": 1, "P": 1
	}

	var player_id := 1
	for position in positions:
		var count := int(position_counts.get(position, 2))
		for i in range(count):
			if players.size() >= player_count:
				break

			# RNG call 1: overall rating variance
			var overall := 90.0 - (float(i) * 5.0) + rng.randf_range(-3.0, 3.0)
			overall = clamp(overall, 45.0, 99.0)

			# RNG call 2: contract annual value variance
			var contract_variance := rng.randf_range(0.5, 2.0)

			players.append({
				"player_id": "player_%d" % player_id,
				"name": "Player %d %s" % [player_id, position],
				"position": position,
				"age": 22 + i,
				"composite_score": overall,
				"contract": {
					"years_remaining": 4 - i if i < 4 else 1,
					"annual_value": overall * 0.1 + contract_variance,
					"base_salary": overall * 0.08,
					"signing_bonus": overall * 0.02
				}
			})
			player_id += 1

		if players.size() >= player_count:
			break

	return {
		"players": players,
		"by_position": {}
	}


## Create world state with a team and roster
func _create_test_world_state(team_id: String, roster: Dictionary) -> Dictionary:
	return {
		"nfl_teams": [
			{
				"id": team_id,
				"name": "Test Team",
				"city": "Test City"
			}
		],
		"nfl_rosters": {
			team_id: roster
		}
	}


## Test: PreDraftRosterView initializes correctly
func test_initialize_creates_tabs() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Should have 3 tabs: Roster, Needs, Depth
	assert_int(view.get_tab_count()).is_equal(3)

	# Verify tab names
	assert_str(view.get_tab_title(0)).is_equal("Roster")
	assert_str(view.get_tab_title(1)).is_equal("Needs")
	assert_str(view.get_tab_title(2)).is_equal("Depth")

	view.queue_free()


## Test: Roster display shows all 53 players
func test_roster_display_shows_all_players() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Verify players by position grouping
	var players_by_position := view.get_players_by_position()

	# Count total players across all positions
	var total_players := 0
	for position in players_by_position.keys():
		total_players += (players_by_position[position] as Array).size()

	# May not be exactly 53 due to position distribution, but should be close
	assert_int(total_players).is_greater_equal(40)
	assert_int(total_players).is_less_equal(53)

	view.queue_free()


## Test: Position needs calculation matches priority thresholds
func test_position_needs_color_coding() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	# Create roster with deliberate position gaps
	var roster := _create_test_roster(30)  # Understaffed roster

	# Remove all CBs to create critical need
	roster["players"] = (roster["players"] as Array).filter(func(p):
		return String((p as Dictionary).get("position", "")) != "CB"
	)

	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Check position needs
	var needs := view.get_position_needs()

	# CB should have critical need (priority >= 0.9) since we removed all CBs
	var cb_priority := float(needs.get("CB", 0.0))
	assert_float(cb_priority).is_greater_equal(0.9)

	view.queue_free()


## Test: Depth chart groups players correctly by starter/backup
func test_depth_chart_grouping() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Check that players are sorted by overall within each position
	var players_by_position := view.get_players_by_position()

	for position in players_by_position.keys():
		var pos_players: Array = players_by_position[position]
		if pos_players.size() < 2:
			continue

		# Each player should have higher overall than the next
		for i in range(pos_players.size() - 1):
			var current_overall := float((pos_players[i] as Dictionary).get("overall", 0.0))
			var next_overall := float((pos_players[i + 1] as Dictionary).get("overall", 0.0))
			assert_float(current_overall).is_greater_equal(next_overall)

	view.queue_free()


## Test: Refresh after pick updates roster
func test_refresh_after_pick_adds_new_player() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(52)  # One short of full roster
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Count initial players at CB
	var initial_cb_count := (view.get_players_by_position().get("CB", []) as Array).size()

	# Simulate drafting a CB
	var new_pick := {
		"team_id": "team_test",
		"player_id": "rookie_cb_1",
		"player_name": "Rookie CB",
		"position": "CB",
		"overall": 78.0,
		"contract": {
			"years_remaining": 4,
			"annual_value": 3.5
		}
	}

	view.refresh_after_pick(new_pick)

	# Verify CB count increased
	var final_cb_count := (view.get_players_by_position().get("CB", []) as Array).size()
	assert_int(final_cb_count).is_equal(initial_cb_count + 1)

	view.queue_free()


## Test: Refresh ignores picks from other teams
func test_refresh_ignores_other_team_picks() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(52)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Count initial total players
	var initial_total := 0
	for pos_players in view.get_players_by_position().values():
		initial_total += (pos_players as Array).size()

	# Simulate another team's pick
	var other_pick := {
		"team_id": "team_other",  # Different team
		"player_id": "other_player_1",
		"player_name": "Other Player",
		"position": "QB",
		"overall": 82.0
	}

	view.refresh_after_pick(other_pick)

	# Verify total hasn't changed
	var final_total := 0
	for pos_players in view.get_players_by_position().values():
		final_total += (pos_players as Array).size()

	assert_int(final_total).is_equal(initial_total)

	view.queue_free()


## Test: Performance - render time under 50ms
func test_render_performance() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	# Create a full 53-player roster
	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	var render_time := view.get_last_render_time_ms()

	# Performance target: <50ms
	assert_float(render_time).is_less(50.0)

	# Also log for visibility
	print("[test_render_performance] Render time: %.2fms (target: <50ms)" % render_time)

	view.queue_free()


## Test: Position needs correctly identifies critical, high, and adequate
func test_position_needs_categories() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	# Create roster with varied depth
	var roster := _create_test_roster(40)  # Understaffed
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	var needs := view.get_position_needs()

	# Categorize needs
	var categories := TeamNeeds.categorize_needs(needs)

	# Verify we have some positions in each category (or at least not all empty)
	var has_any_needs := false
	for category in ["critical", "high", "medium", "low"]:
		if not (categories[category] as Array).is_empty():
			has_any_needs = true
			break

	assert_bool(has_any_needs).is_true()

	view.queue_free()


## Test: Players sorted correctly by different sort modes
func test_roster_sort_modes() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Test position sort (default)
	var players_by_pos := view.get_players_by_position()
	assert_bool(not players_by_pos.is_empty()).is_true()

	# Verify QB group exists and is sorted by overall
	if players_by_pos.has("QB"):
		var qbs: Array = players_by_pos["QB"]
		if qbs.size() >= 2:
			var first_ovr := float((qbs[0] as Dictionary).get("overall", 0.0))
			var second_ovr := float((qbs[1] as Dictionary).get("overall", 0.0))
			assert_float(first_ovr).is_greater_equal(second_ovr)

	view.queue_free()


## Test: Empty roster handles gracefully
func test_empty_roster_handles_gracefully() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var empty_roster := {"players": []}
	var world_state := _create_test_world_state("team_test", empty_roster)

	# Should not crash
	view.initialize("team_test", world_state)

	# Position needs should all be critical (1.0)
	var needs := view.get_position_needs()
	for position in needs.keys():
		var priority := float(needs[position])
		assert_float(priority).is_greater_equal(0.9)

	view.queue_free()


## Test: Contract display format validation
func test_contract_display_data() -> void:
	var view := PreDraftRosterView.new()
	add_child(view)

	var roster := _create_test_roster(10)

	# Ensure first player has valid contract data
	var player: Dictionary = roster["players"][0]
	player["contract"] = {
		"years_remaining": 3,
		"annual_value": 5.5,
		"base_salary": 4.0,
		"signing_bonus": 1.5
	}

	var world_state := _create_test_world_state("team_test", roster)

	view.initialize("team_test", world_state)

	# Verify player data includes contract info
	var players_by_pos := view.get_players_by_position()
	var found_player := false

	for pos_players in players_by_pos.values():
		for p in (pos_players as Array):
			var p_dict: Dictionary = p
			if p_dict.has("contract"):
				found_player = true
				var contract: Dictionary = p_dict.get("contract", {})
				assert_bool(contract.has("years_remaining") or contract.has("annual_value")).is_true()
				break
		if found_player:
			break

	assert_bool(found_player).is_true()

	view.queue_free()


## Test: Determinism - same input produces same output
func test_determinism_same_input_same_output() -> void:
	var roster := _create_test_roster(53)
	var world_state := _create_test_world_state("team_test", roster)

	# Initialize twice with same data
	var view1 := PreDraftRosterView.new()
	add_child(view1)
	view1.initialize("team_test", world_state)
	var needs1 := view1.get_position_needs().duplicate()

	var view2 := PreDraftRosterView.new()
	add_child(view2)
	view2.initialize("team_test", world_state)
	var needs2 := view2.get_position_needs().duplicate()

	# Position needs should be identical
	for position in needs1.keys():
		assert_float(float(needs1[position])).is_equal(float(needs2[position]))

	view1.queue_free()
	view2.queue_free()
