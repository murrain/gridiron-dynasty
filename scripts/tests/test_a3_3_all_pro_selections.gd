extends RefCounted

## Test A3.3: All-Pro Team Selections
##
## Validates that All-Pro First and Second Teams are correctly selected with proper position distribution.

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")

func run(t) -> void:
	_test_all_pro_teams_created(t)
	_test_first_team_better_than_second_team(t)
	_test_all_positions_represented(t)
	_test_correct_position_counts(t)
	_test_all_pro_stored_in_world_state(t)
	_test_position_mapping(t)
	_test_insufficient_players_graceful(t)


func _test_all_pro_teams_created(t) -> void:
	var year_stats := _create_sample_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	t.assert_true(all_pro.has("first_team"), "All-Pro should have first_team")
	t.assert_true(all_pro.has("second_team"), "All-Pro should have second_team")

	var first_team: Array = all_pro["first_team"]
	var second_team: Array = all_pro["second_team"]

	t.assert_true(first_team.size() > 0, "First team should have players")
	t.assert_true(second_team.size() > 0, "Second team should have players")


func _test_first_team_better_than_second_team(t) -> void:
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

	t.assert_ne(first_qb.get("player_id", ""), "", "First team should have QB")
	t.assert_ne(second_qb.get("player_id", ""), "", "Second team should have QB")

	var first_score := float(first_qb.get("score", 0.0))
	var second_score := float(second_qb.get("score", 0.0))

	t.assert_true(first_score > second_score, "First team QB should have higher score than second team QB")


func _test_all_positions_represented(t) -> void:
	var year_stats := _create_comprehensive_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]

	# Check key positions are represented
	var has_qb := _has_position(first_team, "QB")
	var has_rb := _has_position(first_team, "RB")
	var has_wr := _has_position(first_team, "WR")
	var has_te := _has_position(first_team, "TE")
	var has_ol := _has_position(first_team, "OL")
	var has_edge := _has_position(first_team, "EDGE")
	var has_lb := _has_position(first_team, "LB")
	var has_cb := _has_position(first_team, "CB")
	var has_s := _has_position(first_team, "S")

	t.assert_true(has_qb, "First team should have QB")
	t.assert_true(has_rb, "First team should have RB")
	t.assert_true(has_wr, "First team should have WR")
	t.assert_true(has_te, "First team should have TE")
	t.assert_true(has_ol, "First team should have OL")
	t.assert_true(has_edge, "First team should have EDGE")
	t.assert_true(has_lb, "First team should have LB")
	t.assert_true(has_cb, "First team should have CB")
	t.assert_true(has_s, "First team should have S")


func _test_correct_position_counts(t) -> void:
	var year_stats := _create_comprehensive_stats()
	var all_pro := AwardSelector.select_all_pro_teams(year_stats)

	var first_team: Array = all_pro["first_team"]

	# Count positions
	var qb_count := _count_position(first_team, "QB")
	var rb_count := _count_position(first_team, "RB")
	var wr_count := _count_position(first_team, "WR")
	var te_count := _count_position(first_team, "TE")
	var ol_count := _count_position(first_team, "OL")
	var edge_count := _count_position(first_team, "EDGE")
	var lb_count := _count_position(first_team, "LB")
	var cb_count := _count_position(first_team, "CB")
	var s_count := _count_position(first_team, "S")

	t.assert_eq(qb_count, 1, "First team should have 1 QB")
	t.assert_eq(rb_count, 2, "First team should have 2 RBs")
	t.assert_eq(wr_count, 3, "First team should have 3 WRs")
	t.assert_eq(te_count, 1, "First team should have 1 TE")
	t.assert_eq(ol_count, 5, "First team should have 5 OL")
	t.assert_eq(edge_count, 2, "First team should have 2 EDGEs")
	t.assert_eq(lb_count, 3, "First team should have 3 LBs")
	t.assert_eq(cb_count, 2, "First team should have 2 CBs")
	t.assert_eq(s_count, 2, "First team should have 2 Safeties")


func _test_all_pro_stored_in_world_state(t) -> void:
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

	t.assert_true(world_state.has("all_pro_teams"), "world_state should have all_pro_teams")
	t.assert_true(world_state["all_pro_teams"].has(2025), "All-Pro teams should exist for 2025")

	var all_pro: Dictionary = world_state["all_pro_teams"][2025]
	t.assert_true(all_pro.has("first_team"), "2025 should have first_team")
	t.assert_true(all_pro.has("second_team"), "2025 should have second_team")


func _test_position_mapping(t) -> void:
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

	t.assert_eq(ol_count, 3, "OT, OG, C should all map to OL")


func _test_insufficient_players_graceful(t) -> void:
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
	t.assert_eq(first_team.size(), 1, "First team should have 1 player")

	# Second team should be empty (no more QBs)
	t.assert_eq(second_team.size(), 0, "Second team should be empty when insufficient players")


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
