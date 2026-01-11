extends RefCounted

## Test A3.4: Pro Bowl Roster Selections
##
## Validates that Pro Bowl rosters are correctly selected with AFC/NFC splits and proper position distribution.

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")

func run(t) -> void:
	_test_pro_bowl_rosters_created(t)
	_test_afc_nfc_split_correct(t)
	_test_correct_position_counts_per_conference(t)
	_test_conference_assignment_accurate(t)
	_test_pro_bowl_stored_in_world_state(t)
	_test_top_players_selected_per_conference(t)
	_test_no_cross_conference_contamination(t)


func _test_pro_bowl_rosters_created(t) -> void:
	var year_stats := _create_sample_stats()
	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)

	t.assert_true(pro_bowl.has("afc"), "Pro Bowl should have AFC roster")
	t.assert_true(pro_bowl.has("nfc"), "Pro Bowl should have NFC roster")

	var afc_roster: Array = pro_bowl["afc"]
	var nfc_roster: Array = pro_bowl["nfc"]

	t.assert_true(afc_roster.size() > 0, "AFC roster should have players")
	t.assert_true(nfc_roster.size() > 0, "NFC roster should have players")


func _test_afc_nfc_split_correct(t) -> void:
	var year_stats := []

	# Create AFC players
	for i in range(5):
		year_stats.append({
			"player_id": "afc_qb_%03d" % i,
			"position": "QB",
			"team_id": "team_afc_%03d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000 + (i * 100),
				"pass_tds": 30 + i,
				"interceptions": 10,
				"games_played": 16
			}
		})

	# Create NFC players
	for i in range(5):
		year_stats.append({
			"player_id": "nfc_qb_%03d" % i,
			"position": "QB",
			"team_id": "team_nfc_%03d" % i,
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {
				"pass_yards": 3800 + (i * 100),
				"pass_tds": 28 + i,
				"interceptions": 12,
				"games_played": 16
			}
		})

	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)

	var afc_roster: Array = pro_bowl["afc"]
	var nfc_roster: Array = pro_bowl["nfc"]

	# Verify AFC roster only has AFC players
	for player in afc_roster:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		t.assert_true(player_id.begins_with("afc_"), "AFC roster should only have AFC players: %s" % player_id)

	# Verify NFC roster only has NFC players
	for player in nfc_roster:
		var p: Dictionary = player
		var player_id := String(p.get("player_id", ""))
		t.assert_true(player_id.begins_with("nfc_"), "NFC roster should only have NFC players: %s" % player_id)


func _test_correct_position_counts_per_conference(t) -> void:
	var year_stats := _create_comprehensive_stats()
	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)

	var afc_roster: Array = pro_bowl["afc"]

	# Count AFC positions
	var qb_count := _count_position(afc_roster, "QB")
	var rb_count := _count_position(afc_roster, "RB")
	var wr_count := _count_position(afc_roster, "WR")
	var te_count := _count_position(afc_roster, "TE")
	var edge_count := _count_position(afc_roster, "EDGE")
	var lb_count := _count_position(afc_roster, "LB")
	var cb_count := _count_position(afc_roster, "CB")
	var s_count := _count_position(afc_roster, "S")

	t.assert_eq(qb_count, 3, "AFC should have 3 QBs")
	t.assert_eq(rb_count, 3, "AFC should have 3 RBs")
	t.assert_eq(wr_count, 4, "AFC should have 4 WRs")
	t.assert_eq(te_count, 2, "AFC should have 2 TEs")
	t.assert_eq(edge_count, 3, "AFC should have 3 EDGEs")
	t.assert_eq(lb_count, 4, "AFC should have 4 LBs")
	t.assert_eq(cb_count, 3, "AFC should have 3 CBs")
	t.assert_eq(s_count, 3, "AFC should have 3 Safeties")


func _test_conference_assignment_accurate(t) -> void:
	var year_stats := []

	# AFC East
	year_stats.append({
		"player_id": "afc_east_qb",
		"position": "QB",
		"team_id": "team_001",
		"conference": "afc_east",
		"is_rookie": false,
		"stats": {"pass_yards": 4500, "pass_tds": 35, "interceptions": 10, "games_played": 16}
	})

	# AFC North
	year_stats.append({
		"player_id": "afc_north_qb",
		"position": "QB",
		"team_id": "team_002",
		"conference": "afc_north",
		"is_rookie": false,
		"stats": {"pass_yards": 4400, "pass_tds": 34, "interceptions": 11, "games_played": 16}
	})

	# AFC South
	year_stats.append({
		"player_id": "afc_south_qb",
		"position": "QB",
		"team_id": "team_003",
		"conference": "afc_south",
		"is_rookie": false,
		"stats": {"pass_yards": 4300, "pass_tds": 33, "interceptions": 12, "games_played": 16}
	})

	# AFC West
	year_stats.append({
		"player_id": "afc_west_qb",
		"position": "QB",
		"team_id": "team_004",
		"conference": "afc_west",
		"is_rookie": false,
		"stats": {"pass_yards": 4200, "pass_tds": 32, "interceptions": 13, "games_played": 16}
	})

	# NFC East
	year_stats.append({
		"player_id": "nfc_east_qb",
		"position": "QB",
		"team_id": "team_005",
		"conference": "nfc_east",
		"is_rookie": false,
		"stats": {"pass_yards": 4100, "pass_tds": 31, "interceptions": 14, "games_played": 16}
	})

	# NFC North
	year_stats.append({
		"player_id": "nfc_north_qb",
		"position": "QB",
		"team_id": "team_006",
		"conference": "nfc_north",
		"is_rookie": false,
		"stats": {"pass_yards": 4000, "pass_tds": 30, "interceptions": 15, "games_played": 16}
	})

	# NFC South
	year_stats.append({
		"player_id": "nfc_south_qb",
		"position": "QB",
		"team_id": "team_007",
		"conference": "nfc_south",
		"is_rookie": false,
		"stats": {"pass_yards": 3900, "pass_tds": 29, "interceptions": 16, "games_played": 16}
	})

	# NFC West
	year_stats.append({
		"player_id": "nfc_west_qb",
		"position": "QB",
		"team_id": "team_008",
		"conference": "nfc_west",
		"is_rookie": false,
		"stats": {"pass_yards": 3800, "pass_tds": 28, "interceptions": 17, "games_played": 16}
	})

	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)

	var afc_roster: Array = pro_bowl["afc"]
	var nfc_roster: Array = pro_bowl["nfc"]

	# All 4 AFC division QBs should be in AFC roster (need 3, but we have 4 good ones)
	t.assert_eq(afc_roster.size(), 3, "AFC should have 3 QBs")
	t.assert_eq(nfc_roster.size(), 3, "NFC should have 3 QBs")


func _test_pro_bowl_stored_in_world_state(t) -> void:
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

	# Add teams with proper conferences
	for i in range(32):
		var team_id := "team_%03d" % i
		var conference := "afc_east" if i < 8 else ("afc_north" if i < 16 else ("nfc_east" if i < 24 else "nfc_west"))
		world_state["nfl_teams"].append({"id": team_id, "region": conference})
		world_state["nfl_rosters"][team_id] = {"players": []}

	AwardSelector.select_all_awards(world_state, 2025)

	t.assert_true(world_state.has("pro_bowl_rosters"), "world_state should have pro_bowl_rosters")
	t.assert_true(world_state["pro_bowl_rosters"].has(2025), "Pro Bowl rosters should exist for 2025")

	var pro_bowl: Dictionary = world_state["pro_bowl_rosters"][2025]
	t.assert_true(pro_bowl.has("afc"), "2025 should have AFC roster")
	t.assert_true(pro_bowl.has("nfc"), "2025 should have NFC roster")


func _test_top_players_selected_per_conference(t) -> void:
	var year_stats := []

	# Create AFC QBs with varying performance
	for i in range(5):
		year_stats.append({
			"player_id": "afc_qb_%d" % i,
			"position": "QB",
			"team_id": "team_afc_%d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 5000 - (i * 500),  # Best QB first
				"pass_tds": 45 - (i * 5),
				"interceptions": 8 + i,
				"games_played": 16
			}
		})

	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)
	var afc_roster: Array = pro_bowl["afc"]

	# Should select top 3 QBs
	t.assert_eq(afc_roster.size(), 3, "Should select 3 QBs for Pro Bowl")

	# Find the selected QBs
	var selected_ids := []
	for player in afc_roster:
		var p: Dictionary = player
		selected_ids.append(String(p.get("player_id", "")))

	# Top 3 should be afc_qb_0, afc_qb_1, afc_qb_2
	t.assert_true("afc_qb_0" in selected_ids, "Best QB should be selected")
	t.assert_true("afc_qb_1" in selected_ids, "Second best QB should be selected")
	t.assert_true("afc_qb_2" in selected_ids, "Third best QB should be selected")
	t.assert_true(not ("afc_qb_3" in selected_ids), "Fourth best QB should not be selected")
	t.assert_true(not ("afc_qb_4" in selected_ids), "Fifth best QB should not be selected")


func _test_no_cross_conference_contamination(t) -> void:
	var year_stats := []

	# Create elite AFC QB
	year_stats.append({
		"player_id": "afc_elite",
		"position": "QB",
		"team_id": "team_afc",
		"conference": "afc_east",
		"is_rookie": false,
		"stats": {"pass_yards": 5500, "pass_tds": 50, "interceptions": 5, "games_played": 16}
	})

	# Create mediocre NFC QBs
	for i in range(3):
		year_stats.append({
			"player_id": "nfc_qb_%d" % i,
			"position": "QB",
			"team_id": "team_nfc_%d" % i,
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {"pass_yards": 3000 + (i * 100), "pass_tds": 20 + i, "interceptions": 15, "games_played": 16}
		})

	var pro_bowl := AwardSelector.select_pro_bowl_rosters(year_stats)

	var afc_roster: Array = pro_bowl["afc"]
	var nfc_roster: Array = pro_bowl["nfc"]

	# AFC elite should be in AFC, not NFC
	var afc_has_elite := false
	for player in afc_roster:
		var p: Dictionary = player
		if p.get("player_id", "") == "afc_elite":
			afc_has_elite = true

	var nfc_has_elite := false
	for player in nfc_roster:
		var p: Dictionary = player
		if p.get("player_id", "") == "afc_elite":
			nfc_has_elite = true

	t.assert_true(afc_has_elite, "AFC elite QB should be in AFC roster")
	t.assert_true(not (nfc_has_elite), "AFC elite QB should NOT be in NFC roster")

	# NFC should have its own QBs even if they're worse
	t.assert_eq(nfc_roster.size(), 3, "NFC should have 3 QBs from NFC conference")


## HELPER FUNCTIONS


func _create_sample_stats() -> Array:
	var stats := []

	# AFC players
	for i in range(10):
		stats.append({
			"player_id": "afc_player_%03d" % i,
			"position": "QB" if i < 3 else ("RB" if i < 6 else "WR"),
			"team_id": "team_afc_%03d" % i,
			"conference": "afc_east",
			"is_rookie": false,
			"stats": {
				"pass_yards": 4000 + (i * 100),
				"pass_tds": 30 + i,
				"rush_yards": 1000 + (i * 50),
				"rush_tds": 8 + i,
				"receptions": 70 + (i * 3),
				"receiving_yards": 900 + (i * 40),
				"receiving_tds": 6 + i,
				"games_played": 16
			}
		})

	# NFC players
	for i in range(10):
		stats.append({
			"player_id": "nfc_player_%03d" % i,
			"position": "QB" if i < 3 else ("RB" if i < 6 else "WR"),
			"team_id": "team_nfc_%03d" % i,
			"conference": "nfc_west",
			"is_rookie": false,
			"stats": {
				"pass_yards": 3800 + (i * 100),
				"pass_tds": 28 + i,
				"rush_yards": 950 + (i * 50),
				"rush_tds": 7 + i,
				"receptions": 65 + (i * 3),
				"receiving_yards": 850 + (i * 40),
				"receiving_tds": 5 + i,
				"games_played": 16
			}
		})

	return stats


func _create_comprehensive_stats() -> Array:
	var stats := []

	# Create players for each position, split between AFC and NFC
	var positions: Array[String] = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]

	for pos_idx in range(positions.size()):
		var pos: String = positions[pos_idx]
		var count := 8  # Create 8 of each position (4 AFC, 4 NFC)

		for i in range(count):
			var conference := "afc_east" if i < 4 else "nfc_west"
			stats.append({
				"player_id": "%s_%03d" % [pos.to_lower(), i],
				"position": pos,
				"team_id": "team_%03d" % (pos_idx * 10 + i),
				"conference": conference,
				"is_rookie": false,
				"stats": _generate_position_stats(pos, i)
			})

	return stats


func _generate_position_stats(position: String, rank: int) -> Dictionary:
	# Generate position-specific stats based on rank
	if position == "QB":
		return {
			"pass_yards": 4500 - (rank * 200),
			"pass_tds": 35 - (rank * 2),
			"interceptions": 8 + rank,
			"games_played": 16
		}
	elif position == "RB":
		return {
			"rush_yards": 1400 - (rank * 100),
			"rush_tds": 12 - rank,
			"receptions": 50 - (rank * 3),
			"receiving_yards": 400 - (rank * 30),
			"games_played": 16
		}
	elif position == "WR":
		return {
			"receptions": 95 - (rank * 5),
			"receiving_yards": 1350 - (rank * 80),
			"receiving_tds": 10 - rank,
			"games_played": 16
		}
	elif position == "TE":
		return {
			"receptions": 75 - (rank * 4),
			"receiving_yards": 900 - (rank * 50),
			"receiving_tds": 7 - rank,
			"games_played": 16
		}
	elif position == "EDGE":
		return {
			"sacks": 15.0 - rank,
			"tackles_for_loss": 18 - rank,
			"tackles": 55 - (rank * 3),
			"games_played": 16
		}
	elif position == "LB":
		return {
			"tackles": 120 - (rank * 10),
			"sacks": 4.0 - (rank * 0.5),
			"pass_breakups": 6 - rank,
			"games_played": 16
		}
	elif position == "CB":
		return {
			"interceptions": 6 - rank,
			"pass_breakups": 15 - rank,
			"tackles": 55 - (rank * 3),
			"games_played": 16
		}
	elif position == "S":
		return {
			"interceptions": 5 - rank,
			"pass_breakups": 10 - rank,
			"tackles": 80 - (rank * 5),
			"games_played": 16
		}
	else:
		return {"games_played": 16}


func _create_comprehensive_players() -> Array:
	return _create_comprehensive_stats()


func _count_position(roster: Array, position: String) -> int:
	var count := 0
	for player in roster:
		var p: Dictionary = player
		if p.get("position", "") == position:
			count += 1
	return count
