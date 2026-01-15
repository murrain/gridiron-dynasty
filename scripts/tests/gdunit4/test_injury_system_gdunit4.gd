## GdUnit4 test suite for InjurySystem
##
## Tests injury type selection, determinism, career-ending injuries, and position modifiers.
## Migrated from test_injury_system.gd
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")


func test_config_structure() -> void:
	var main_cfg := _make_main_cfg()
	var injury_cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary

	assert_bool(not injury_cfg.is_empty()).is_true()
	assert_bool(injury_cfg.has("base_chance")).is_true()
	assert_bool(injury_cfg.has("types")).is_true()
	assert_bool(injury_cfg.has("position_multipliers")).is_true()
	assert_bool(injury_cfg.has("durability_trait_modifiers")).is_true()

	var types: Array = injury_cfg.get("types", []) as Array
	assert_int(types.size()).is_equal(4)


func test_injury_type_selection() -> void:
	var main_cfg := _make_main_cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var test_player := {
		"player_id": "test_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 50.0, "speed": 85.0, "agility": 82.0},
		"injuries": []
	}

	var injury_counts := {}
	var total_injuries := 0
	var trials := 1000

	for _i in range(trials):
		var test_player_copy := test_player.duplicate(true)
		var rng_copy := RandomNumberGenerator.new()
		rng_copy.seed = rng.randi()
		var report := PlayerLifecycle._apply_injury(test_player_copy, main_cfg, rng_copy)
		if report.get("injured", false):
			total_injuries += 1
			var injury: Dictionary = report.get("injury", {}) as Dictionary
			var type := String(injury.get("type", "unknown"))
			injury_counts[type] = int(injury_counts.get(type, 0)) + 1

	assert_int(total_injuries).is_greater(0)
	assert_int(injury_counts.size()).is_greater(0)


func test_determinism_same_seed() -> void:
	var main_cfg := _make_main_cfg()
	var positions_cfg := _make_positions_cfg()
	var stats_cfg := _make_stats_cfg()

	var test_player := {
		"player_id": "det_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 60.0, "speed": 85.0, "agility": 82.0, "acceleration": 83.0, "strength": 80.0},
		"potential": {"speed": 90.0, "agility": 87.0, "acceleration": 88.0, "strength": 85.0},
		"injuries": [],
		"wear": {"snaps": 0, "collisions": 0, "injury_count": 0},
		"development_context": {}
	}

	var seed := 99999
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = seed
	var result1 := PlayerLifecycle.advance_one_year(
		[test_player.duplicate(true)],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed
	var result2 := PlayerLifecycle.advance_one_year(
		[test_player.duplicate(true)],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2
	)

	var player1: Dictionary = (result1["players"] as Array)[0]
	var player2: Dictionary = (result2["players"] as Array)[0]
	var injuries1: Array = player1.get("injuries", [])
	var injuries2: Array = player2.get("injuries", [])

	assert_int(injuries1.size()).is_equal(injuries2.size())

	if injuries1.size() > 0 and injuries2.size() > 0:
		var inj1: Dictionary = injuries1[0] as Dictionary
		var inj2: Dictionary = injuries2[0] as Dictionary
		assert_that(inj1.get("type")).is_equal(inj2.get("type"))


func test_career_ending_injury_forces_retirement() -> void:
	var main_cfg := _make_main_cfg()
	var positions_cfg := _make_positions_cfg()
	var stats_cfg := _make_stats_cfg()

	var test_player := {
		"player_id": "career_end_001",
		"position": "RB",
		"age": 28,
		"stats": {"injury_proneness": 50.0, "speed": 85.0, "agility": 82.0, "strength": 80.0},
		"potential": {"speed": 90.0, "agility": 87.0, "strength": 85.0},
		"injuries": [
			{
				"type": "back",
				"severity": 2.5,
				"affected_stats": ["strength", "speed", "agility"],
				"recovery_timeline": {
					"years_total": 1,
					"years_remaining": 1,
					"status": "active"
				},
				"long_term_penalty": {
					"stat_caps": {},
					"decline_multipliers": {}
				},
				"career_ending": true
			}
		],
		"wear": {"snaps": 0, "collisions": 0, "injury_count": 0},
		"development_context": {}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 54321

	var result := PlayerLifecycle.advance_one_year(
		[test_player],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng
	)

	var retired: Array = result.get("retired", []) as Array
	assert_int(retired.size()).is_equal(1)


func test_position_multipliers() -> void:
	var main_cfg := _make_main_cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11111

	var rb_player := {
		"player_id": "rb_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 50.0},
		"injuries": []
	}

	var rb_report := PlayerLifecycle._apply_injury(rb_player, main_cfg, rng)
	var rb_mult := float(rb_report.get("position_mult", 1.0))

	var k_player := {
		"player_id": "k_001",
		"position": "K",
		"age": 24,
		"stats": {"injury_proneness": 50.0},
		"injuries": []
	}

	rng.seed = 11111
	var k_report := PlayerLifecycle._apply_injury(k_player, main_cfg, rng)
	var k_mult := float(k_report.get("position_mult", 1.0))

	assert_float(rb_mult).is_greater(1.0)
	assert_float(k_mult).is_less(1.0)
	assert_float(rb_mult).is_greater(k_mult)


func test_durability_traits() -> void:
	var main_cfg := _make_main_cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = 22222

	var prone_player := {
		"player_id": "prone_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 50.0},
		"hidden_traits": ["injury_prone"],
		"injuries": []
	}

	var prone_report := PlayerLifecycle._apply_injury(prone_player, main_cfg, rng)
	var prone_mult := float(prone_report.get("trait_mult", 1.0))

	var durable_player := {
		"player_id": "durable_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 50.0},
		"hidden_traits": ["durable"],
		"injuries": []
	}

	rng.seed = 22222
	var durable_report := PlayerLifecycle._apply_injury(durable_player, main_cfg, rng)
	var durable_mult := float(durable_report.get("trait_mult", 1.0))

	assert_float(prone_mult).is_greater(1.0)
	assert_float(durable_mult).is_less(1.0)


func test_injury_generation_structure() -> void:
	var main_cfg := _make_main_cfg()
	var injury_cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary
	var rng := RandomNumberGenerator.new()
	rng.seed = 33333

	var test_player := {
		"player_id": "struct_001",
		"position": "RB",
		"stats": {"speed": 85.0, "agility": 82.0, "acceleration": 83.0},
		"injuries": []
	}

	var injury: Variant = PlayerLifecycle._generate_injury(test_player, injury_cfg, rng)

	if injury != null:
		assert_bool(injury.has("type")).is_true()
		assert_bool(injury.has("severity")).is_true()
		assert_bool(injury.has("affected_stats")).is_true()
		assert_bool(injury.has("recovery_timeline")).is_true()
		assert_bool(injury.has("long_term_penalty")).is_true()
		assert_bool(injury.has("career_ending")).is_true()

		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary
		assert_bool(timeline.has("years_total")).is_true()
		assert_bool(timeline.has("years_remaining")).is_true()
		assert_bool(timeline.has("status")).is_true()

		var penalty: Dictionary = injury.get("long_term_penalty", {}) as Dictionary
		assert_bool(penalty.has("stat_caps")).is_true()
		assert_bool(penalty.has("decline_multipliers")).is_true()


func test_fallback_with_empty_config() -> void:
	var empty_cfg := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 44444

	var test_player := {
		"player_id": "fallback_001",
		"position": "RB",
		"age": 24,
		"stats": {"injury_proneness": 50.0},
		"injuries": []
	}

	var report := PlayerLifecycle._apply_injury(test_player, empty_cfg, rng)

	assert_bool(report.has("injured")).is_true()
	assert_bool(report.has("roll")).is_true()
	assert_bool(report.has("final_chance")).is_true()

	var base := float(report.get("base_chance", 0.0))
	assert_float(base).is_equal_approx(0.12, 0.01)


# --- Helper functions ---

func _make_injury_cfg() -> Dictionary:
	return {
		"base_chance": 0.12,
		"proneness_slope": 0.15,
		"types": [
			{
				"type": "hamstring",
				"weight": 0.20,
				"severity_min": 1.0,
				"severity_max": 2.0,
				"affected_stats": ["speed", "acceleration", "agility"],
				"recovery_years_min": 0,
				"recovery_years_max": 1,
				"long_term_cap": 0.95,
				"long_term_decline_mult": 1.05
			},
			{
				"type": "knee",
				"weight": 0.15,
				"severity_min": 2.0,
				"severity_max": 3.0,
				"affected_stats": ["speed", "agility", "acceleration", "strength"],
				"recovery_years_min": 1,
				"recovery_years_max": 2,
				"long_term_cap": 0.90,
				"long_term_decline_mult": 1.10
			},
			{
				"type": "back",
				"weight": 0.08,
				"severity_min": 1.5,
				"severity_max": 3.0,
				"affected_stats": ["strength", "speed", "agility"],
				"recovery_years_min": 1,
				"recovery_years_max": 2,
				"long_term_cap": 0.88,
				"long_term_decline_mult": 1.15,
				"career_ending_chance": 0.03
			},
			{
				"type": "minor",
				"weight": 0.57,
				"severity_min": 0.3,
				"severity_max": 1.0,
				"affected_stats": [],
				"recovery_years_min": 0,
				"recovery_years_max": 0,
				"long_term_cap": 1.0,
				"long_term_decline_mult": 1.0
			}
		],
		"position_multipliers": {
			"RB": 1.25,
			"WR": 1.10,
			"QB": 0.85,
			"K": 0.30
		},
		"durability_trait_modifiers": {
			"injury_prone": 1.40,
			"durable": 0.65,
			"iron_man": 0.40
		}
	}


func _make_main_cfg() -> Dictionary:
	return {
		"injury": _make_injury_cfg(),
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {
			"min_age": 27,
			"soft_cap_age": 33,
			"max_age": 40,
			"base_chance": 0.02,
			"age_chance_per_year": 0.04,
			"low_rating_threshold": 55.0,
			"low_rating_boost": 0.08
		},
		"wear": {
			"snaps_per_year": 650,
			"collisions_per_year": 220,
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		}
	}


func _make_positions_cfg() -> Dictionary:
	return {
		"RB": {
			"core_stats": ["speed", "agility", "strength"],
			"development": {"peak_age": 26, "decline_start": 28, "curve": "mid"}
		},
		"QB": {
			"core_stats": ["throw_accuracy", "decision_making"],
			"development": {"peak_age": 28, "decline_start": 32, "curve": "mid"}
		},
		"K": {
			"core_stats": ["kick_power", "kick_accuracy"],
			"development": {"peak_age": 30, "decline_start": 35, "curve": "mid"}
		}
	}


func _make_stats_cfg() -> Dictionary:
	return {
		"stats": [
			{"name": "speed", "type": "base"},
			{"name": "agility", "type": "base"},
			{"name": "strength", "type": "base"},
			{"name": "acceleration", "type": "base"},
			{"name": "injury_proneness", "type": "base"}
		]
	}
