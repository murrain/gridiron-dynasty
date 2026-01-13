extends RefCounted

const CharacterService = preload("res://scripts/world/CharacterService.gd")

func run(t) -> void:
	test_apply_discipline_events_basic(t)
	test_apply_discipline_events_determinism(t)
	test_evaluate_character_grade(t)
	test_calculate_decayed_hype_modifier(t)
	test_evaluate_for_team(t)

func test_apply_discipline_events_basic(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"player_id": "test_player_001",
		"hype": 50.0
	}

	var config := {
		"discipline_events": {
			"base_chance_per_year": 1.0,  # Force event for testing
			"types": [
				{
					"type": "academic",
					"weight": 1.0,
					"games_range": [1, 2],
					"severity": "minor",
					"hype_impact": -5.0,
					"halflife_years": 0.5
				}
			]
		}
	}

	var event := CharacterService.apply_discipline_events(player, 2024, config, rng)

	t.assert_true(not event.is_empty(), "event was generated with 100% chance")
	t.assert_eq(event.get("type"), "academic", "event type is academic")
	t.assert_true(player.has("character_profile"), "character_profile was initialized")
	t.assert_true(player.has("history"), "history was initialized")
	t.assert_true(float(player.get("hype", 50.0)) < 50.0, "hype was reduced")

func test_apply_discipline_events_determinism(t) -> void:
	var config := {
		"discipline_events": {
			"base_chance_per_year": 1.0,
			"types": [
				{"type": "academic", "weight": 1.0, "games_range": [1, 2], "severity": "minor", "hype_impact": -5.0, "halflife_years": 0.5}
			]
		}
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var player1 := {"player_id": "test", "hype": 50.0}
	var event1 := CharacterService.apply_discipline_events(player1, 2024, config, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var player2 := {"player_id": "test", "hype": 50.0}
	var event2 := CharacterService.apply_discipline_events(player2, 2024, config, rng2)

	t.assert_eq(event1.get("type"), event2.get("type"), "event type is deterministic")
	t.assert_eq(event1.get("games"), event2.get("games"), "games suspended is deterministic")

func test_evaluate_character_grade(t) -> void:
	var config := {
		"character_grades": {
			"red_flag": {"triggers": ["legal_trouble", "multiple_major", "pattern"]},
			"concern": {"max_incidents": 2, "max_severity": "minor"},
			"clean": {"max_incidents": 1, "max_severity": "minor"}
		}
	}

	# No incidents = exemplary
	var player_clean := {"character_profile": {"discipline_record": []}}
	var grade := CharacterService.evaluate_character_grade(player_clean, config)
	t.assert_eq(grade, "exemplary", "no incidents = exemplary")

	# Legal trouble = red_flag
	var player_legal := {
		"character_profile": {
			"discipline_record": [{"type": "legal_trouble", "severity": "severe"}]
		}
	}
	grade = CharacterService.evaluate_character_grade(player_legal, config)
	t.assert_eq(grade, "red_flag", "legal trouble = red_flag")

	# One minor incident = clean
	var player_minor := {
		"character_profile": {
			"discipline_record": [{"type": "academic", "severity": "minor"}]
		}
	}
	grade = CharacterService.evaluate_character_grade(player_minor, config)
	t.assert_eq(grade, "clean", "one minor incident = clean")

func test_calculate_decayed_hype_modifier(t) -> void:
	var player := {
		"hype_modifiers": [
			{
				"source": "discipline",
				"year_applied": 2024,
				"initial_impact": -10.0,
				"halflife_years": 1.0
			}
		]
	}

	# At year of application
	var modifier := CharacterService.calculate_decayed_hype_modifier(player, 2024)
	t.assert_true(abs(modifier - (-10.0)) < 0.01, "no decay at year 0")

	# After 1 year (halflife)
	modifier = CharacterService.calculate_decayed_hype_modifier(player, 2025)
	t.assert_true(abs(modifier - (-5.0)) < 0.01, "half decay after 1 year")

	# After 2 years
	modifier = CharacterService.calculate_decayed_hype_modifier(player, 2026)
	t.assert_true(abs(modifier - (-2.5)) < 0.01, "quarter decay after 2 years")

func test_evaluate_for_team(t) -> void:
	var config := {
		"team_tolerance_levels": {
			"strict": {"penalty_multiplier": 1.5},
			"moderate": {"penalty_multiplier": 1.0},
			"lenient": {"penalty_multiplier": 0.5},
			"win_now": {"penalty_multiplier": 0.25}
		},
		"character_grades": {
			"red_flag": {"triggers": []},
			"concern": {"max_incidents": 2},
			"clean": {"max_incidents": 1}
		}
	}

	var player := {"character_profile": {"discipline_record": []}}  # exemplary

	var strict_team := {"character_tolerance": "strict"}
	var lenient_team := {"character_tolerance": "lenient"}

	var strict_score := CharacterService.evaluate_for_team(player, strict_team, config)
	var lenient_score := CharacterService.evaluate_for_team(player, lenient_team, config)

	# Exemplary player should score well with both teams
	t.assert_true(strict_score >= 90.0, "exemplary scores well with strict team")
	t.assert_true(lenient_score >= 90.0, "exemplary scores well with lenient team")
