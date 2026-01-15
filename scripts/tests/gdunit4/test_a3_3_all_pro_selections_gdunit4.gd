## GdUnit4 test suite for A3.3: All-Pro Team Selections
##
## Validates that All-Pro First and Second Teams are correctly selected with proper position distribution.
extends GdUnitTestSuite

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")


func test_all_pro_teams_created() -> void:
	var year_stats := _create_sample_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	assert_bool(all_pro.has("first_team")).is_true()
	assert_bool(all_pro.has("second_team")).is_true()

	var first_team: Array = all_pro["first_team"]
	var second_team: Array = all_pro["second_team"]

	assert_int(first_team.size()).is_greater(0)
	assert_int(second_team.size()).is_greater(0)


func test_first_team_better_than_second_team() -> void:
	var year_stats := []

	# Create 4 QBs with different scores
	for i in range(4):
		year_stats.append({
			"player_id": "qb_%03d" % i,
			"position": "QB",
			"team_id": "team_%03d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000 + (i * 500),  # Better QBs have more yards
				"pass_tds": 30 + (i * 5),
				"interceptions": 10,
				"games_played": 16
			}
		})

	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]
	var second_team: Array = all_pro["second_team"]

	# Find QB in each team
	var first_qb := _find_position_in_team(first_team, "QB")
	var second_qb := _find_position_in_team(second_team, "QB")

	assert_str(first_qb.get("player_id", "")).is_not_empty()
	assert_str(second_qb.get("player_id", "")).is_not_empty()

	var first_score := float(first_qb.get("score", 0.0))
	var second_score := float(second_qb.get("score", 0.0))

	assert_float(first_score).is_greater(second_score)


func test_all_positions_represented() -> void:
	var year_stats := _create_comprehensive_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]

	# Check key positions are represented
	assert_bool(_has_position(first_team, "QB")).is_true()
	assert_bool(_has_position(first_team, "RB")).is_true()
	assert_bool(_has_position(first_team, "WR")).is_true()
	assert_bool(_has_position(first_team, "TE")).is_true()
	assert_bool(_has_position(first_team, "OL")).is_true()
	assert_bool(_has_position(first_team, "EDGE")).is_true()
	assert_bool(_has_position(first_team, "LB")).is_true()
	assert_bool(_has_position(first_team, "CB")).is_true()
	assert_bool(_has_position(first_team, "S")).is_true()


func test_correct_position_counts() -> void:
	var year_stats := _create_comprehensive_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]

	# Count positions
	assert_int(_count_position(first_team, "QB")).is_equal(1)
	assert_int(_count_position(first_team, "RB")).is_equal(2)
	assert_int(_count_position(first_team, "WR")).is_equal(3)
	assert_int(_count_position(first_team, "TE")).is_equal(1)
	assert_int(_count_position(first_team, "OL")).is_equal(5)
	assert_int(_count_position(first_team, "EDGE")).is_equal(2)
	assert_int(_count_position(first_team, "LB")).is_equal(3)
	assert_int(_count_position(first_team, "CB")).is_equal(2)
	assert_int(_count_position(first_team, "S")).is_equal(2)


func test_all_pro_stored_in_world_state() -> void:
	var world_state := {
		"player_career_stats": {},
		"nfl_rosters": {},
		"nfl_teams": []
	}

	# Add comprehensive stats
	var players := _create_comprehensive_players()
	for player in players:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		world_state["player_career_stats"][player_id] = {
			2025: p.get("stats", {})
		}
		# Merge position and team_id into stats
		world_state["player_career_stats"][player_id][2025]["position"] = p.get("position", "")
		world_state["player_career_stats"][player_id][2025]["team_id"] = p.get("team_id", "")

	# Add teams
	for i in range(32):
		var team_id := "team_%03d" % i
		world_state["nfl_teams"].append({"id": team_id, "region": "afc_east" if i < 16 else "nfc_west"})
		world_state["nfl_rosters"][team_id] = {"players": []}

	AwardSelector.select_all_awards(world_state, 2025)

	assert_bool(world_state.has("all_pro_teams")).is_true()
	assert_bool(world_state["all_pro_teams"].has(2025)).is_true()

	var all_pro: Dictionary = world_state["all_pro_teams"][2025]
	assert_bool(all_pro.has("first_team")).is_true()
	assert_bool(all_pro.has("second_team")).is_true()


func test_position_mapping() -> void:
	# Test that OT, OG, C all map to OL
	var year_stats := [
		{
			"player_id": "ot_001",
			"position": "OT",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {"games_played": 16}
		},
		{
			"player_id": "og_001",
			"position": "OG",
			"team_id": "team_002",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {"games_played": 16}
		},
		{
			"player_id": "c_001",
			"position": "C",
			"team_id": "team_003",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {"games_played": 16}
		}
	]

	var all_pro := AwardSelector.select_all_pro_teams(year_stats)
	var first_team: Array = all_pro["first_team"]

	# All should be mapped to OL position
	var ol_count := 0
	for player in first_team:
		var p: Dictionary = player
		if p.get("position", "") == "OL":
			ol_count += 1

	assert_int(ol_count).is_equal(3)


func test_insufficient_players_graceful() -> void:
	# Only 1 QB available but need 2 teams
	var year_stats := [
		{
			"player_id": "qb_001",
			"position": "QB",
			"team_id": "team_001",
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000,
				"pass_tds": 30,
				"interceptions": 10,
				"games_played": 16
			}
		}
	]

	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]
	var second_team: Array = all_pro["second_team"]

	# First team should have the QB
	assert_int(first_team.size()).is_equal(1)

	# Second team should be empty (no more QBs)
	assert_int(second_team.size()).is_equal(0)


## HELPER FUNCTIONS

func _create_sample_stats() -> Array:
	var stats := []

	# Add enough players for basic All-Pro teams
	for i in range(5):
		stats.append({
			"player_id": "qb_%03d" % i,
			"position": "QB",
			"team_id": "team_%03d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000 + (i * 100),
				"pass_tds": 30 + i,
				"interceptions": 10,
				"games_played": 16
			}
		})

	for i in range(6):
		stats.append({
			"player_id": "rb_%03d" % i,
			"position": "RB",
			"team_id": "team_%03d" % (i + 10),
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {
				"rush_yards": 1200 + (i * 100),
				"rush_tds": 10 + i,
				"receptions": 40,
				"receiving_yards": 300,
				"games_played": 16
			}
		})

	return stats


func _create_comprehensive_stats() -> Array:
	var stats := []

	# QB (need 2)
	for i in range(3):
		stats.append({
			"player_id": "qb_%03d" % i,
			"position": "QB",
			"team_id": "team_%03d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {"pass_yards": 4000 + (i * 200), "pass_tds": 30 + i, "interceptions": 10, "games_played": 16}
		})

	# RB (need 4)
	for i in range(5):
		stats.append({
			"player_id": "rb_%03d" % i,
			"position": "RB",
			"team_id": "team_%03d" % (i + 3),
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {"rush_yards": 1200 + (i * 100), "rush_tds": 10 + i, "games_played": 16}
		})

	# WR (need 6)
	for i in range(7):
		stats.append({
			"player_id": "wr_%03d" % i,
			"position": "WR",
			"team_id": "team_%03d" % (i + 8),
			"conference": "afc_west",
			"is_rookie": false,
			"stats": {"receptions": 80 + (i * 5), "receiving_yards": 1100 + (i * 50), "receiving_tds": 8 + i, "games_played": 16}
		})

	# TE (need 2)
	for i in range(3):
		stats.append({
			"player_id": "te_%03d" % i,
			"position": "TE",
			"team_id": "team_%03d" % (i + 15),
			"conference": "nfc_north",
			"is_rookie": false,
			"stats": {"receptions": 70 + (i * 5), "receiving_yards": 800 + (i * 50), "receiving_tds": 6 + i, "games_played": 16}
		})

	# OL (need 10 - various sub-positions)
	for i in range(12):
		var pos := "OL"
		if i < 4:
			pos = "OT"
		elif i < 8:
			pos = "OG"
		elif i < 10:
			pos = "C"
		stats.append({
			"player_id": "ol_%03d" % i,
			"position": pos,
			"team_id": "team_%03d" % (i + 18),
			"conference": "afc_south",
			"is_rookie": false,
			"stats": {"games_played": 16}
		})

	# DL (need 4)
	for i in range(5):
		stats.append({
			"player_id": "dl_%03d" % i,
			"position": "DL",
			"team_id": "team_%03d" % i,
			"conference": "nfc_east",
			"is_rookie": false,
			"stats": {"sacks": 8.0 + i, "tackles_for_loss": 12 + i, "tackles": 40 + (i * 5), "games_played": 16}
		})

	# EDGE (need 4)
	for i in range(5):
		stats.append({
			"player_id": "edge_%03d" % i,
			"position": "EDGE",
			"team_id": "team_%03d" % (i + 5),
			"conference": "afc_north",
			"is_rookie": false,
			"stats": {"sacks": 12.0 + i, "tackles_for_loss": 15 + i, "tackles": 50 + (i * 3), "games_played": 16}
		})

	# LB (need 6)
	for i in range(7):
		stats.append({
			"player_id": "lb_%03d" % i,
			"position": "LB",
			"team_id": "team_%03d" % (i + 10),
			"conference": "nfc_south",
			"is_rookie": false,
			"stats": {"tackles": 100 + (i * 10), "sacks": 3.0 + i, "pass_breakups": 5 + i, "games_played": 16}
		})

	# CB (need 4)
	for i in range(5):
		stats.append({
			"player_id": "cb_%03d" % i,
			"position": "CB",
			"team_id": "team_%03d" % (i + 17),
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {"interceptions": 4 + i, "pass_breakups": 12 + i, "tackles": 50 + (i * 3), "games_played": 16}
		})

	# S (need 4)
	for i in range(5):
		stats.append({
			"player_id": "s_%03d" % i,
			"position": "S",
			"team_id": "team_%03d" % (i + 22),
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {"interceptions": 5 + i, "pass_breakups": 8 + i, "tackles": 70 + (i * 5), "games_played": 16}
		})

	# K (need 2)
	for i in range(3):
		stats.append({
			"player_id": "k_%03d" % i,
			"position": "K",
			"team_id": "team_%03d" % (i + 27),
			"conference": "afc_west",
			"is_rookie": false,
			"stats": {"field_goals_made": 25 + i, "games_played": 16}
		})

	# P (need 2)
	for i in range(3):
		stats.append({
			"player_id": "p_%03d" % i,
			"position": "P",
			"team_id": "team_%03d" % (i + 30),
			"conference": "nfc_north",
			"is_rookie": false,
			"stats": {"punts": 60 + i, "punt_average": 45.0 + i, "games_played": 16}
		})

	return stats


func _create_comprehensive_players() -> Array:
	# Similar to _create_comprehensive_stats but returns player dictionaries
	return _create_comprehensive_stats()


func _find_position_in_team(team: Array, position: String) -> Dictionary:
	for player in team:
		var p: Dictionary = player
		if p.get("position", "") == position:
			return p
	return {}


func _has_position(team: Array, position: String) -> bool:
	for player in team:
		var p: Dictionary = player
		if p.get("position", "") == position:
			return true
	return false


func _count_position(team: Array, position: String) -> int:
	var count := 0
	for player in team:
		var p: Dictionary = player
		if p.get("position", "") == position:
			count += 1
	return count
