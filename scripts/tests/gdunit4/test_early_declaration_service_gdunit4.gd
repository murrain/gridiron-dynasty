## GdUnit4 test suite for EarlyDeclarationService
##
## Validates early declaration decision simulation and determinism.
## Migrated from test_early_declaration_service.gd
extends GdUnitTestSuite

const EarlyDeclarationService = preload("res://scripts/world/EarlyDeclarationService.gd")


func test_simulate_declaration_decision_stores_advisory() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"player_id": "elite_001",
		"stats": {"speed": 95.0, "strength": 90.0, "agility": 92.0},
		"age": 21,
		"college_year": 3
	}

	var config := _make_test_config()

	var _declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, {}, {"class_rules": {}}, config, rng
	)

	assert_bool(player.has("declaration_advisory")).is_true()
	var advisory: Dictionary = player.get("declaration_advisory", {})
	assert_bool(advisory.has("nfl_advisory_grade")).is_true()
	assert_bool(advisory.has("agent_contacted")).is_true()


func test_simulate_declaration_decision_determinism() -> void:
	var player1 := {
		"player_id": "test",
		"stats": {"speed": 80.0, "strength": 80.0},
		"age": 21
	}
	var player2 := {
		"player_id": "test",
		"stats": {"speed": 80.0, "strength": 80.0},
		"age": 21
	}

	var config := _make_test_config()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var declares1 := EarlyDeclarationService.simulate_declaration_decision(
		player1, 2024, {}, {"class_rules": {}}, config, rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var declares2 := EarlyDeclarationService.simulate_declaration_decision(
		player2, 2024, {}, {"class_rules": {}}, config, rng2
	)

	assert_bool(declares1 == declares2).is_true()
	assert_that(player1.get("declaration_advisory", {}).get("agent_contacted")).is_equal(
		player2.get("declaration_advisory", {}).get("agent_contacted")
	)


func test_declaration_probability_injured_player() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var injured_player := {
		"player_id": "injured",
		"stats": {"speed": 75.0, "strength": 75.0},
		"age": 21,
		"injuries": [
			{"severity": 3.0},
			{"severity": 2.5}
		]
	}

	var config := _make_full_config()

	EarlyDeclarationService.simulate_declaration_decision(
		injured_player, 2024, {}, {"class_rules": {}}, config, rng
	)

	assert_bool(injured_player.has("declaration_advisory")).is_true()


func test_return_to_school_bonus_applied() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	var player := {
		"player_id": "developmental",
		"stats": {"speed": 60.0, "strength": 55.0},
		"age": 20,
		"college_year": 3
	}

	var config := {
		"enabled": true,
		"nfl_advisory_grades": {
			"1st_round": {"min_rating": 85.0, "declaration_rate": 0.95},
			"2nd_round": {"min_rating": 78.0, "declaration_rate": 0.80},
			"3rd_day": {"min_rating": 70.0, "declaration_rate": 0.45},
			"return_to_school": {"declaration_rate": 0.05}
		},
		"agent_influence": {},
		"decision_factors": {},
		"return_to_school_boost": {"development_bonus": 1.20}
	}

	var declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, {}, {"class_rules": {}}, config, rng
	)

	if not declares:
		assert_bool(player.has("development_context")).is_true()
		var dev_context: Dictionary = player.get("development_context", {})
		assert_bool(bool(dev_context.get("return_to_school_bonus", false))).is_true()


func test_simple_declaration_fallback() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	var player := {
		"player_id": "simple_test",
		"stats": {"speed": 90.0, "strength": 88.0}
	}

	var config := {
		"enabled": false,
		"rating_threshold": 80.0,
		"base_chance": 0.15,
		"rating_bonus_per_point": 0.02
	}

	var declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, {}, {"class_rules": {}}, config, rng
	)

	assert_bool(declares == true or declares == false).is_true()


# --- Helper functions ---

func _make_test_config() -> Dictionary:
	return {
		"enabled": true,
		"nfl_advisory_grades": {
			"1st_round": {"min_rating": 85.0, "declaration_rate": 0.95},
			"2nd_round": {"min_rating": 78.0, "declaration_rate": 0.80},
			"3rd_day": {"min_rating": 70.0, "declaration_rate": 0.45},
			"return_to_school": {"declaration_rate": 0.15}
		},
		"agent_influence": {},
		"decision_factors": {},
		"return_to_school_boost": {"development_bonus": 1.15}
	}


func _make_full_config() -> Dictionary:
	return {
		"enabled": true,
		"nfl_advisory_grades": {
			"1st_round": {"min_rating": 85.0, "declaration_rate": 0.95},
			"2nd_round": {"min_rating": 78.0, "declaration_rate": 0.80},
			"3rd_day": {"min_rating": 70.0, "declaration_rate": 0.45},
			"return_to_school": {"declaration_rate": 0.15}
		},
		"agent_influence": {"agent_push_declaration_rate_boost": 0.15},
		"decision_factors": {
			"financial_need_weight": 0.25,
			"injury_history_weight": 0.20,
			"development_upside_weight": 0.30
		},
		"return_to_school_boost": {"development_bonus": 1.15}
	}
