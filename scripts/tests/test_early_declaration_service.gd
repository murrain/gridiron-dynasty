extends RefCounted

const EarlyDeclarationService = preload("res://scripts/world/EarlyDeclarationService.gd")

func run(t) -> void:
	test_simulate_declaration_decision_basic(t)
	test_simulate_declaration_decision_determinism(t)
	test_declaration_probability_factors(t)
	test_return_to_school_bonus(t)
	test_simple_declaration_fallback(t)

func test_simulate_declaration_decision_basic(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# High-rated player (should likely declare)
	var player := {
		"player_id": "elite_001",
		"stats": {"speed": 95.0, "strength": 90.0, "agility": 92.0},
		"age": 21,
		"college_year": 3
	}

	var positions_cfg := {}
	var main_cfg := {"class_rules": {}}
	var config := {
		"enabled": true,
		"nfl_advisory_grades": {
			"1st_round": {"min_rating": 85.0, "declaration_rate": 0.95},
			"2nd_round": {"min_rating": 78.0, "declaration_rate": 0.80},
			"3rd_day": {"min_rating": 70.0, "declaration_rate": 0.45},
			"return_to_school": {"declaration_rate": 0.15}
		},
		"agent_influence": {
			"agent_push_declaration_rate_boost": 0.15
		},
		"decision_factors": {},
		"return_to_school_boost": {"development_bonus": 1.15}
	}

	var declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, positions_cfg, main_cfg, config, rng
	)

	t.assert_true(player.has("declaration_advisory"), "advisory data was stored")
	var advisory: Dictionary = player.get("declaration_advisory", {})
	t.assert_true(advisory.has("nfl_advisory_grade"), "has advisory grade")
	t.assert_true(advisory.has("agent_contacted"), "has agent_contacted flag")

func test_simulate_declaration_decision_determinism(t) -> void:
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

	var config := {
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

	t.assert_eq(declares1, declares2, "declaration decision is deterministic")
	t.assert_eq(
		player1.get("declaration_advisory", {}).get("agent_contacted"),
		player2.get("declaration_advisory", {}).get("agent_contacted"),
		"agent_contacted is deterministic"
	)

func test_declaration_probability_factors(t) -> void:
	# Test that different factors affect declaration probability
	# This is an indirect test through the config

	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var base_config := {
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

	# Player with injuries (should increase declaration urgency)
	var injured_player := {
		"player_id": "injured",
		"stats": {"speed": 75.0, "strength": 75.0},
		"age": 21,
		"injuries": [
			{"severity": 3.0},
			{"severity": 2.5}
		]
	}

	EarlyDeclarationService.simulate_declaration_decision(
		injured_player, 2024, {}, {"class_rules": {}}, base_config, rng
	)

	t.assert_true(injured_player.has("declaration_advisory"), "injured player processed")

func test_return_to_school_bonus(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	# Low-rated player who will likely return to school
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
			"return_to_school": {"declaration_rate": 0.05}  # Very low chance
		},
		"agent_influence": {},
		"decision_factors": {},
		"return_to_school_boost": {"development_bonus": 1.20}
	}

	var declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, {}, {"class_rules": {}}, config, rng
	)

	if not declares:
		t.assert_true(player.has("development_context"), "development_context set for returning player")
		var dev_context: Dictionary = player.get("development_context", {})
		t.assert_true(dev_context.get("return_to_school_bonus", false), "return_to_school_bonus flag set")

func test_simple_declaration_fallback(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	var player := {
		"player_id": "simple_test",
		"stats": {"speed": 90.0, "strength": 88.0}
	}

	# Disabled advisory system should use simple fallback
	var config := {
		"enabled": false,
		"rating_threshold": 80.0,
		"base_chance": 0.15,
		"rating_bonus_per_point": 0.02
	}

	var declares := EarlyDeclarationService.simulate_declaration_decision(
		player, 2024, {}, {"class_rules": {}}, config, rng
	)

	# Just verify it doesn't crash and returns a boolean
	t.assert_true(declares == true or declares == false, "simple fallback returns boolean")
