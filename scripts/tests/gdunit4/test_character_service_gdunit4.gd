## GdUnit4 test suite for CharacterService
##
## Validates discipline events, character grades, and team evaluation.
## Migrated from test_character_service.gd
extends GdUnitTestSuite

const CharacterService = preload("res://scripts/world/CharacterService.gd")


func test_apply_discipline_events_basic() -> void:
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

	assert_bool(not event.is_empty()).is_true()
	assert_str(String(event.get("type"))).is_equal("academic")
	assert_bool(player.has("character_profile")).is_true()
	assert_bool(player.has("history")).is_true()
	assert_float(float(player.get("hype", 50.0))).is_less(50.0)


func test_apply_discipline_events_determinism() -> void:
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

	assert_str(String(event1.get("type"))).is_equal(String(event2.get("type")))
	assert_that(event1.get("games")).is_equal(event2.get("games"))


func test_evaluate_character_grade_exemplary() -> void:
	var config := {
		"character_grades": {
			"red_flag": {"triggers": ["legal_trouble", "multiple_major", "pattern"]},
			"concern": {"max_incidents": 2, "max_severity": "minor"},
			"clean": {"max_incidents": 1, "max_severity": "minor"}
		}
	}

	var player_clean := {"character_profile": {"discipline_record": []}}
	var grade := CharacterService.evaluate_character_grade(player_clean, config)

	assert_str(grade).is_equal("exemplary")


func test_evaluate_character_grade_red_flag() -> void:
	var config := {
		"character_grades": {
			"red_flag": {"triggers": ["legal_trouble", "multiple_major", "pattern"]},
			"concern": {"max_incidents": 2, "max_severity": "minor"},
			"clean": {"max_incidents": 1, "max_severity": "minor"}
		}
	}

	var player_legal := {
		"character_profile": {
			"discipline_record": [{"type": "legal_trouble", "severity": "severe"}]
		}
	}

	var grade := CharacterService.evaluate_character_grade(player_legal, config)

	assert_str(grade).is_equal("red_flag")


func test_evaluate_character_grade_clean() -> void:
	var config := {
		"character_grades": {
			"red_flag": {"triggers": ["legal_trouble", "multiple_major", "pattern"]},
			"concern": {"max_incidents": 2, "max_severity": "minor"},
			"clean": {"max_incidents": 1, "max_severity": "minor"}
		}
	}

	var player_minor := {
		"character_profile": {
			"discipline_record": [{"type": "academic", "severity": "minor"}]
		}
	}

	var grade := CharacterService.evaluate_character_grade(player_minor, config)

	assert_str(grade).is_equal("clean")


func test_calculate_decayed_hype_modifier_no_decay() -> void:
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

	var modifier := CharacterService.calculate_decayed_hype_modifier(player, 2024)

	assert_float(modifier).is_equal_approx(-10.0, 0.01)


func test_calculate_decayed_hype_modifier_half_decay() -> void:
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

	var modifier := CharacterService.calculate_decayed_hype_modifier(player, 2025)

	assert_float(modifier).is_equal_approx(-5.0, 0.01)


func test_calculate_decayed_hype_modifier_quarter_decay() -> void:
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

	var modifier := CharacterService.calculate_decayed_hype_modifier(player, 2026)

	assert_float(modifier).is_equal_approx(-2.5, 0.01)


func test_evaluate_for_team_exemplary_strict() -> void:
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

	var score := CharacterService.evaluate_for_team(player, strict_team, config)

	assert_float(score).is_greater_equal(90.0)


func test_evaluate_for_team_exemplary_lenient() -> void:
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
	var lenient_team := {"character_tolerance": "lenient"}

	var score := CharacterService.evaluate_for_team(player, lenient_team, config)

	assert_float(score).is_greater_equal(90.0)
