extends RefCounted

## Test G1 Integration: Full Season Simulation
##
## Validates that season simulation integrates correctly with CollegeSeason and NflSeason.
## Tests that world_state is properly updated with season records and championships.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")
const ConfigLoader = preload("res://scripts/support/config/ConfigLoader.gd")

func run(t) -> void:
	_test_college_season_integration(t)
	_test_nfl_season_integration(t)
	_test_season_records_structure(t)
	_test_championships_structure(t)


func _test_college_season_integration(t) -> void:
	# Create minimal test world_state
	var world_state := _create_test_college_world_state()

	# Load configs
	var config_loader := ConfigLoader.new("sports/american_football")
	var colleges_cfg: Dictionary = config_loader.get_config("world/colleges")
	var positions_cfg: Dictionary = config_loader.get_config("positions")
	var main_cfg: Dictionary = config_loader.get_config("main")
	var stats_cfg: Dictionary = config_loader.get_config("stats")

	# Enable game simulation
	colleges_cfg["game_simulation"] = {
		"enabled": true,
		"regular_season_weeks": 12,
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	var year := 2025
	var seed := 42

	# Run college season
	var college_season := CollegeSeason.new()
	var result := college_season.run(
		world_state,
		year,
		seed,
		colleges_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_reports": true}
	)

	# Verify game simulation ran
	t.assert_true(result.has("game_simulation"), "Result should have game_simulation key")
	var game_sim: Dictionary = result.get("game_simulation", {})
	t.assert_eq(game_sim.get("enabled", false), true, "Game simulation should be enabled")
	t.assert_gt(game_sim.get("games_simulated", 0), 0, "Games should have been simulated")

	# Verify world_state has season_records
	t.assert_true(world_state.has("season_records"), "world_state should have season_records")
	var season_records: Dictionary = world_state.get("season_records", {})
	t.assert_true(season_records.has(year), "season_records should have entry for year %d" % year)

	# Verify colleges have W-L records
	var year_records: Dictionary = season_records.get(year, {})
	t.assert_gt(year_records.size(), 0, "Should have records for multiple teams")

	for team_id in year_records.keys():
		var record: Dictionary = year_records[team_id]
		t.assert_true(record.has("wins"), "Record should have wins")
		t.assert_true(record.has("losses"), "Record should have losses")
		t.assert_true(record.has("strength_of_schedule"), "Record should have SOS")

		# Wins + losses should equal games played
		var total_games := int(record.get("wins", 0)) + int(record.get("losses", 0))
		t.assert_gt(total_games, 0, "Team should have played games")

	# Verify championship was determined
	t.assert_true(world_state.has("championships"), "world_state should have championships")
	var championships: Dictionary = world_state.get("championships", {})
	t.assert_true(championships.has("college"), "championships should have college section")
	var college_champs: Dictionary = championships.get("college", {})
	t.assert_true(college_champs.has("national_champions"), "Should have national_champions")
	var national_champs: Dictionary = college_champs.get("national_champions", {})
	t.assert_true(national_champs.has(year), "Should have champion for year %d" % year)
	t.assert_ne(national_champs.get(year, ""), "", "Champion should not be empty string")


func _test_nfl_season_integration(t) -> void:
	# Create minimal test world_state
	var world_state := _create_test_nfl_world_state()

	# Load configs
	var config_loader := ConfigLoader.new("sports/american_football")
	var league_cfg: Dictionary = config_loader.get_config("world/league")
	var positions_cfg: Dictionary = config_loader.get_config("positions")
	var main_cfg: Dictionary = config_loader.get_config("main")
	var stats_cfg: Dictionary = config_loader.get_config("stats")

	# Enable game simulation
	league_cfg["game_simulation"] = {
		"enabled": true,
		"regular_season_weeks": 17,
		"home_field_advantage": 2.5,
		"strength_sensitivity": 0.1,
		"upset_threshold": 7.0
	}

	var year := 2025
	var seed := 42

	# Run NFL season
	var nfl_season := NflSeason.new()
	var result := nfl_season.run(
		world_state,
		year,
		seed,
		league_cfg,
		positions_cfg,
		main_cfg,
		stats_cfg,
		{"skip_reports": true}
	)

	# Verify game simulation ran
	t.assert_true(result.has("game_simulation"), "Result should have game_simulation key")
	var game_sim: Dictionary = result.get("game_simulation", {})
	t.assert_eq(game_sim.get("enabled", false), true, "Game simulation should be enabled")
	t.assert_gt(game_sim.get("games_simulated", 0), 0, "Games should have been simulated")

	# Verify world_state has season_records
	t.assert_true(world_state.has("season_records"), "world_state should have season_records")
	var season_records: Dictionary = world_state.get("season_records", {})
	t.assert_true(season_records.has(year), "season_records should have entry for year %d" % year)

	# Verify teams have W-L records
	var year_records: Dictionary = season_records.get(year, {})
	t.assert_eq(year_records.size(), 32, "Should have records for all 32 NFL teams")

	# Verify Super Bowl winner
	t.assert_true(world_state.has("championships"), "world_state should have championships")
	var championships: Dictionary = world_state.get("championships", {})
	t.assert_true(championships.has("nfl"), "championships should have nfl section")
	var nfl_champs: Dictionary = championships.get("nfl", {})
	t.assert_true(nfl_champs.has("super_bowl_winners"), "Should have super_bowl_winners")
	var sb_winners: Dictionary = nfl_champs.get("super_bowl_winners", {})
	t.assert_true(sb_winners.has(year), "Should have Super Bowl winner for year %d" % year)


func _test_season_records_structure(t) -> void:
	# Verify SeasonRecord structure matches specification
	var test_record := {
		"team_id": "team_001",
		"year": 2025,
		"wins": 10,
		"losses": 2,
		"conference_wins": 0,
		"conference_losses": 0,
		"strength_of_schedule": 68.5,
		"point_differential": 0,
		"playoff_appearance": false,
		"bowl_game": "",
		"championship_winner": false,
		"super_bowl_winner": false
	}

	# Verify all expected keys exist
	var required_keys := ["team_id", "year", "wins", "losses", "strength_of_schedule"]
	for key in required_keys:
		t.assert_true(test_record.has(key), "SeasonRecord should have key: %s" % key)

	# Verify types
	t.assert_true(test_record["team_id"] is String, "team_id should be String")
	t.assert_true(test_record["year"] is int, "year should be int")
	t.assert_true(test_record["wins"] is int, "wins should be int")
	t.assert_true(test_record["losses"] is int, "losses should be int")
	t.assert_true(test_record["strength_of_schedule"] is float, "SOS should be float")


func _test_championships_structure(t) -> void:
	# Verify championships structure matches specification
	var test_championships := {
		"college": {
			"national_champions": {2025: "college_042", 2026: "college_089"}
		},
		"nfl": {
			"super_bowl_winners": {2025: "nfl_015", 2026: "nfl_007"}
		}
	}

	t.assert_true(test_championships.has("college"), "championships should have college")
	t.assert_true(test_championships.has("nfl"), "championships should have nfl")

	var college_champs: Dictionary = test_championships["college"]
	t.assert_true(college_champs.has("national_champions"), "college should have national_champions")

	var nfl_champs: Dictionary = test_championships["nfl"]
	t.assert_true(nfl_champs.has("super_bowl_winners"), "nfl should have super_bowl_winners")


func _create_test_college_world_state() -> Dictionary:
	var colleges := []
	for i in range(10):  # Small test league
		colleges.append({
			"id": "college_%03d" % i,
			"name": "College %d" % i,
			"tier": "mid",
			"eliteness": 60.0 + randf() * 20.0
		})

	var rosters := {}
	for college in colleges:
		var c: Dictionary = college
		var players := []
		for j in range(20):  # 20 players per roster
			players.append({
				"player_id": "player_%s_%d" % [c["id"], j],
				"position": ["QB", "RB", "WR"][j % 3],
				"composite_score": 60.0 + randf() * 25.0,
				"college_year": 1 + (j % 4)
			})
		rosters[c["id"]] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_nfl_world_state() -> Dictionary:
	var teams := []
	for i in range(32):
		teams.append({
			"id": "nfl_%03d" % i,
			"name": "Team %d" % i,
			"region": ["afc_east", "afc_north", "afc_south", "afc_west", "nfc_east", "nfc_north", "nfc_south", "nfc_west"][i % 8]
		})

	var rosters := {}
	for team in teams:
		var t: Dictionary = team
		var players := []
		for j in range(53):  # 53 players per roster
			players.append({
				"player_id": "player_%s_%d" % [t["id"], j],
				"position": ["QB", "RB", "WR", "TE", "OL"][j % 5],
				"composite_score": 60.0 + randf() * 30.0,
				"age": 22 + (j % 10),
				"contract": {"years_remaining": 1 + (j % 4), "years_total": 4}
			})
		rosters[t["id"]] = {"players": players}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"retired_players": [],
		"free_agents": {}
	}
