## GdUnit4 test suite for Player Growth Trajectories
##
## Verifies realistic player development over multi-year spans.
## Tests player progression through college and NFL phases.
##
## Migrated from test_player_growth_trajectories.gd
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

var _config: Dictionary


func before() -> void:
	_config = _load_test_config()


func _load_test_config() -> Dictionary:
	var positions_path := "res://configs/sports/american_football/positions.json"
	var main_path := "res://configs/sports/american_football/main.json"
	var stats_path := "res://configs/sports/american_football/stats.json"

	var positions_file := FileAccess.open(positions_path, FileAccess.READ)
	var positions_json := positions_file.get_as_text()
	positions_file.close()

	var main_file := FileAccess.open(main_path, FileAccess.READ)
	var main_json := main_file.get_as_text()
	main_file.close()

	var stats_file := FileAccess.open(stats_path, FileAccess.READ)
	var stats_json := stats_file.get_as_text()
	stats_file.close()

	return {
		"positions": JSON.parse_string(positions_json),
		"main": JSON.parse_string(main_json),
		"stats": JSON.parse_string(stats_json)
	}


func _create_rb_test_player(player_id: String, age: int, rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": "Test RB %s" % player_id,
		"position": "RB",
		"age": age,
		"stats": {
			"speed": rating,
			"agility": rating,
			"balance": rating,
			"acceleration": rating,
			"strength": rating - 5.0,
			"stamina": rating - 5.0
		},
		"potential": {
			"speed": rating + 15.0,
			"agility": rating + 15.0,
			"balance": rating + 15.0,
			"acceleration": rating + 15.0,
			"strength": rating + 10.0,
			"stamina": rating + 10.0
		},
		"development_history": [],
		"wear": {"snaps": 0, "collisions": 0, "injury_count": 0}
	}


func _create_qb_test_player(player_id: String, age: int, rating: float) -> Dictionary:
	return {
		"player_id": player_id,
		"name": "Test QB %s" % player_id,
		"position": "QB",
		"age": age,
		"stats": {
			"throw_power": rating,
			"throw_accuracy": rating,
			"awareness": rating,
			"decision_making": rating,
			"speed": rating - 8.0,
			"agility": rating - 8.0
		},
		"potential": {
			"throw_power": rating + 20.0,
			"throw_accuracy": rating + 20.0,
			"awareness": rating + 18.0,
			"decision_making": rating + 18.0,
			"speed": rating + 5.0,
			"agility": rating + 5.0
		},
		"development_history": [],
		"wear": {"snaps": 0, "collisions": 0, "injury_count": 0}
	}


func test_college_4year_progression() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := _create_rb_test_player("RB_TEST", 18, 48.0)
	player["potential"] = {
		"speed": 80.0, "agility": 80.0, "balance": 80.0, "acceleration": 80.0,
		"strength": 75.0, "stamina": 75.0
	}
	player["stats"] = {
		"speed": 48.0, "agility": 48.0, "balance": 48.0, "acceleration": 48.0,
		"strength": 45.0, "stamina": 45.0
	}

	var dev_context := {
		"program_quality": 0.8,
		"usage": 0.8,
		"competition_tier": 1.0,
		"coach_specialization": 1.0,
		"rehab_quality": 1.0
	}

	for year in range(4):
		var result := PlayerLifecycle.advance_one_year(
			[player],
			_config["positions"],
			_config["main"],
			_config["stats"],
			rng,
			dev_context
		)
		player = result["players"][0]
		player["age"] = 18 + year + 1

	var final_speed := float(player["stats"]["speed"])
	var final_agility := float(player["stats"]["agility"])
	var final_balance := float(player["stats"]["balance"])

	var avg_core := (final_speed + final_agility + final_balance) / 3.0
	var pct_of_potential := avg_core / 80.0

	assert_float(pct_of_potential).is_between(0.70, 0.90)


func test_nfl_5year_progression() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var player := _create_rb_test_player("RB_NFL", 22, 72.0)
	player["potential"] = {
		"speed": 85.0, "agility": 85.0, "balance": 85.0, "acceleration": 85.0,
		"strength": 80.0, "stamina": 80.0
	}
	player["stats"] = {
		"speed": 61.0, "agility": 61.0, "balance": 61.0, "acceleration": 61.0,
		"strength": 58.0, "stamina": 58.0
	}

	var dev_context := {
		"program_quality": 1.0,
		"usage": 0.9,
		"competition_tier": 1.1,
		"coach_specialization": 1.05,
		"rehab_quality": 1.0
	}

	var initial_avg := 61.0

	for year in range(5):
		var result := PlayerLifecycle.advance_one_year(
			[player],
			_config["positions"],
			_config["main"],
			_config["stats"],
			rng,
			dev_context
		)
		player = result["players"][0]
		player["age"] = 22 + year + 1

	var final_speed := float(player["stats"]["speed"])
	var final_agility := float(player["stats"]["agility"])
	var final_balance := float(player["stats"]["balance"])

	var avg_core := (final_speed + final_agility + final_balance) / 3.0
	var improvement := avg_core - initial_avg

	assert_float(improvement).is_greater(0.0)
	assert_float(avg_core).is_between(65.0, 78.0)


func test_determinism_multi_year_growth() -> void:
	var dev_context := {
		"program_quality": 0.85,
		"usage": 0.85,
		"competition_tier": 1.0,
		"coach_specialization": 1.0,
		"rehab_quality": 1.0
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 77777
	var player1 := _create_rb_test_player("RB_DET1", 18, 60.0)
	player1["potential"] = {"speed": 80.0, "agility": 80.0, "balance": 80.0, "acceleration": 80.0}
	player1["stats"] = {"speed": 48.0, "agility": 48.0, "balance": 48.0, "acceleration": 48.0}

	var result1 := PlayerLifecycle.advance_years(
		[player1], 5,
		_config["positions"],
		_config["main"],
		_config["stats"],
		rng1,
		dev_context
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 77777
	var player2 := _create_rb_test_player("RB_DET2", 18, 60.0)
	player2["potential"] = {"speed": 80.0, "agility": 80.0, "balance": 80.0, "acceleration": 80.0}
	player2["stats"] = {"speed": 48.0, "agility": 48.0, "balance": 48.0, "acceleration": 48.0}

	var result2 := PlayerLifecycle.advance_years(
		[player2], 5,
		_config["positions"],
		_config["main"],
		_config["stats"],
		rng2,
		dev_context
	)

	var final1: Dictionary = result1["players"][0]
	var final2: Dictionary = result2["players"][0]

	var speed1: float = float(final1["stats"]["speed"])
	var speed2: float = float(final2["stats"]["speed"])

	assert_float(speed1).is_equal(speed2)


func test_prime_phase_allows_growth() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44444

	var player := _create_rb_test_player("RB_PRIME", 23, 70.0)
	player["potential"] = {"speed": 88.0, "agility": 88.0, "balance": 88.0, "acceleration": 88.0}
	player["stats"] = {"speed": 62.0, "agility": 62.0, "balance": 62.0, "acceleration": 62.0}

	var dev_context := {
		"program_quality": 1.0,
		"usage": 1.0,
		"competition_tier": 1.0,
		"coach_specialization": 1.0,
		"rehab_quality": 1.0
	}

	var initial_avg := 62.0

	for year in range(3):
		var result := PlayerLifecycle.advance_one_year(
			[player],
			_config["positions"],
			_config["main"],
			_config["stats"],
			rng,
			dev_context
		)
		player = result["players"][0]
		player["age"] = 23 + year + 1

	var final_avg := (float(player["stats"]["speed"]) + float(player["stats"]["agility"]) +
					  float(player["stats"]["balance"])) / 3.0
	var total_growth := final_avg - initial_avg

	assert_float(total_growth).is_greater(0.5)


func test_multiplier_stacking_produces_growth() -> void:
	var dev_context := {
		"program_quality": 0.8,
		"usage": 0.8,
		"competition_tier": 0.8,
		"coach_specialization": 0.8,
		"rehab_quality": 0.8
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 33333
	var player := _create_rb_test_player("RB_POOR", 18, 60.0)
	player["potential"] = {"speed": 80.0, "agility": 80.0, "balance": 80.0, "acceleration": 80.0}
	player["stats"] = {"speed": 48.0, "agility": 48.0, "balance": 48.0, "acceleration": 48.0}

	for year in range(4):
		var result := PlayerLifecycle.advance_one_year(
			[player], _config["positions"], _config["main"], _config["stats"], rng, dev_context)
		player = result["players"][0]
		player["age"] = 18 + year + 1

	var avg := (float(player["stats"]["speed"]) + float(player["stats"]["agility"]) +
				float(player["stats"]["balance"])) / 3.0
	var growth := avg - 48.0

	assert_float(growth).is_greater(0.0)


func test_average_program_reaches_target_potential() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var player := _create_qb_test_player("QB_AVG", 18, 55.0)
	player["potential"] = {
		"throw_power": 85.0, "throw_accuracy": 85.0, "awareness": 85.0,
		"decision_making": 85.0, "speed": 70.0, "agility": 70.0
	}
	player["stats"] = {
		"throw_power": 47.0, "throw_accuracy": 47.0, "awareness": 47.0,
		"decision_making": 47.0, "speed": 39.0, "agility": 39.0
	}

	for year in range(4):
		var dev_context := {
			"program_quality": 0.85,
			"usage": 0.80,
			"competition_tier": 1.0,
			"coach_specialization": 1.0,
			"rehab_quality": 1.0
		}
		var result := PlayerLifecycle.advance_one_year(
			[player],
			_config["positions"],
			_config["main"],
			_config["stats"],
			rng,
			dev_context
		)
		player = result["players"][0]
		player["age"] = 18 + year + 1

	var final_power := float(player["stats"]["throw_power"])
	var final_accuracy := float(player["stats"]["throw_accuracy"])
	var final_awareness := float(player["stats"]["awareness"])
	var final_decision := float(player["stats"]["decision_making"])

	var avg_core := (final_power + final_accuracy + final_awareness + final_decision) / 4.0
	var pct_of_potential := avg_core / 85.0

	assert_float(pct_of_potential).is_greater_equal(0.75)
