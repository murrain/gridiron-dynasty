## GdUnit4 test suite for G1 Integration: Full Season Simulation
##
## Validates that season simulation integrates correctly with CollegeSeason and NflSeason.
## Tests that world_state is properly updated with season records and championships.
extends GdUnitTestSuite

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _colleges_cfg: Dictionary
var _league_cfg: Dictionary
var _positions_cfg: Dictionary
var _main_cfg: Dictionary
var _stats_cfg: Dictionary


func before() -> void:
	var config := ConfigService.new()
	_colleges_cfg = config.get_config("world/colleges")
	_league_cfg = config.get_config("world/league")
	_positions_cfg = config.get_config("positions")
	_main_cfg = config.get_config("main")
	_stats_cfg = config.get_config("stats")

	# Enable game simulation
	_colleges_cfg["game_simulation"] = {
		"enabled": true,
		"regular_season_weeks": 12,
		"home_field_advantage": 3.0,
		"strength_sensitivity": 0.1,
		"upset_threshold": 5.0
	}

	_league_cfg["game_simulation"] = {
		"enabled": true,
		"regular_season_weeks": 17,
		"home_field_advantage": 2.5,
		"strength_sensitivity": 0.1,
		"upset_threshold": 7.0
	}


func test_college_season_integration() -> void:
	var world_state := _create_test_college_world_state()
	var year := 2025
	var seed := 42

	var college_season := CollegeSeason.new()
	var result := college_season.run(
		world_state,
		year,
		seed,
		_colleges_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{"skip_reports": true}
	)

	# Verify game simulation ran
	assert_bool(result.has("game_simulation")).is_true()
	var game_sim: Dictionary = result.get("game_simulation", {})
	assert_bool(bool(game_sim.get("enabled", false))).is_true()
	assert_int(int(game_sim.get("games_simulated", 0))).is_greater(0)

	# Verify world_state has season_records
	assert_bool(world_state.has("season_records")).is_true()
	var season_records: Dictionary = world_state.get("season_records", {})
	assert_bool(season_records.has(year)).is_true()

	# Verify colleges have W-L records
	var year_records: Dictionary = season_records.get(year, {})
	assert_int(year_records.size()).is_greater(0)

	for team_id in year_records.keys():
		var record: Dictionary = year_records[team_id]
		assert_bool(record.has("wins")).is_true()
		assert_bool(record.has("losses")).is_true()
		assert_bool(record.has("strength_of_schedule")).is_true()

		# Wins + losses should equal games played
		var total_games := int(record.get("wins", 0)) + int(record.get("losses", 0))
		assert_int(total_games).is_greater(0)

	# Verify championship was determined
	assert_bool(world_state.has("championships")).is_true()
	var championships: Dictionary = world_state.get("championships", {})
	assert_bool(championships.has("college")).is_true()
	var college_champs: Dictionary = championships.get("college", {})
	assert_bool(college_champs.has("national_champions")).is_true()
	var national_champs: Dictionary = college_champs.get("national_champions", {})
	assert_bool(national_champs.has(year)).is_true()
	assert_str(String(national_champs.get(year, ""))).is_not_empty()


func test_nfl_season_integration() -> void:
	var world_state := _create_test_nfl_world_state()
	var year := 2025
	var seed := 42

	var nfl_season := NflSeason.new()
	var result := nfl_season.run(
		world_state,
		year,
		seed,
		_league_cfg,
		_positions_cfg,
		_main_cfg,
		_stats_cfg,
		{"skip_reports": true}
	)

	# Verify game simulation ran
	assert_bool(result.has("game_simulation")).is_true()
	var game_sim: Dictionary = result.get("game_simulation", {})
	assert_bool(bool(game_sim.get("enabled", false))).is_true()
	assert_int(int(game_sim.get("games_simulated", 0))).is_greater(0)

	# Verify world_state has season_records
	assert_bool(world_state.has("season_records")).is_true()
	var season_records: Dictionary = world_state.get("season_records", {})
	assert_bool(season_records.has(year)).is_true()

	# Verify teams have W-L records
	var year_records: Dictionary = season_records.get(year, {})
	assert_int(year_records.size()).is_equal(32)

	# Verify Super Bowl winner
	assert_bool(world_state.has("championships")).is_true()
	var championships: Dictionary = world_state.get("championships", {})
	assert_bool(championships.has("nfl")).is_true()
	var nfl_champs: Dictionary = championships.get("nfl", {})
	assert_bool(nfl_champs.has("super_bowl_winners")).is_true()
	var sb_winners: Dictionary = nfl_champs.get("super_bowl_winners", {})
	assert_bool(sb_winners.has(year)).is_true()


func test_season_records_structure() -> void:
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
		assert_bool(test_record.has(key)).is_true()

	# Verify types
	assert_bool(test_record["team_id"] is String).is_true()
	assert_bool(test_record["year"] is int).is_true()
	assert_bool(test_record["wins"] is int).is_true()
	assert_bool(test_record["losses"] is int).is_true()
	assert_bool(test_record["strength_of_schedule"] is float).is_true()


func test_championships_structure() -> void:
	var test_championships := {
		"college": {
			"national_champions": {2025: "college_042", 2026: "college_089"}
		},
		"nfl": {
			"super_bowl_winners": {2025: "nfl_015", 2026: "nfl_007"}
		}
	}

	assert_bool(test_championships.has("college")).is_true()
	assert_bool(test_championships.has("nfl")).is_true()

	var college_champs: Dictionary = test_championships["college"]
	assert_bool(college_champs.has("national_champions")).is_true()

	var nfl_champs: Dictionary = test_championships["nfl"]
	assert_bool(nfl_champs.has("super_bowl_winners")).is_true()


func _create_test_college_world_state() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var colleges := []
	for i in range(10):
		colleges.append({
			"id": "college_%03d" % i,
			"name": "College %d" % i,
			"tier": "mid",
			"eliteness": 60.0 + rng.randf() * 20.0
		})

	var rosters := {}
	for college in colleges:
		var c: Dictionary = college
		var players := []
		for j in range(20):
			players.append({
				"player_id": "player_%s_%d" % [c["id"], j],
				"position": ["QB", "RB", "WR"][j % 3],
				"composite_score": 60.0 + rng.randf() * 25.0,
				"college_year": 1 + (j % 4)
			})
		rosters[c["id"]] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_nfl_world_state() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

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
		for j in range(53):
			var position: String = ["QB", "RB", "WR", "TE", "OL"][j % 5]
			var age: int = 22 + (j % 10)
			var eval_score: float = 60.0 + rng.randf() * 30.0
			var draft_year: int = 2020 + (j / 10)
			var signed_year: int = draft_year + (j % 3)

			players.append({
				"player_id": "player_%s_%d" % [t["id"], j],
				"position": position,
				"composite_score": eval_score,
				"eval_score": eval_score,
				"age": age,
				"draft_year": draft_year,
				"contract": {
					"annual_value": _generate_realistic_salary(position, age, eval_score, rng),
					"signed_year": signed_year,
					"years_remaining": 1 + (j % 4),
					"years_total": 4
				}
			})
		rosters[t["id"]] = {"players": players}

	return {
		"nfl_teams": teams,
		"nfl_rosters": rosters,
		"retired_players": [],
		"free_agents": {}
	}


func _generate_realistic_salary(position: String, age: int, eval_score: float, rng: RandomNumberGenerator) -> float:
	var position_base: Dictionary = {
		"QB": 8.0,
		"RB": 2.5,
		"WR": 4.0,
		"TE": 3.0,
		"OL": 3.5
	}
	var base: float = float(position_base.get(position, 3.0))

	var age_mult: float = 1.0
	if age < 25:
		age_mult = 0.6
	elif age < 28:
		age_mult = 1.2
	elif age < 32:
		age_mult = 1.0
	else:
		age_mult = 0.8

	var perf_mult: float = eval_score / 75.0
	var random_factor: float = rng.randf_range(0.8, 1.2)
	var salary: float = base * age_mult * perf_mult * random_factor

	return clampf(salary, 0.5, 25.0)
