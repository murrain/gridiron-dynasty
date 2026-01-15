## GdUnit4 test suite for Team Quality Function
##
## Tests that _apply_team_quality_to_scout works correctly with elite and
## terrible team quality modifiers, including clamping and determinism.
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")


func _create_base_scout() -> Dictionary:
	return {
		"base_skill": 0.55,
		"board_noise_sigma": 1.8,
		"tape_grinder": 0.25,
		"overrate_athletes": 0.0,
		"risk_aversion": 0.10
	}


func _create_elite_quality() -> Dictionary:
	return {
		"base_quality": 0.75,
		"noise_modifier": 0.80,
		"skill_modifier": 1.15,
		"tier": "elite"
	}


func _create_terrible_quality() -> Dictionary:
	return {
		"base_quality": 0.28,
		"noise_modifier": 1.35,
		"skill_modifier": 0.85,
		"tier": "terrible"
	}


func test_elite_quality_increases_base_skill() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_elite_quality(), rng)

	assert_float(float(scout.get("base_skill", 0.0))).is_greater(0.6)


func test_elite_quality_decreases_noise() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_elite_quality(), rng)

	assert_float(float(scout.get("board_noise_sigma", 0.0))).is_less(1.8)


func test_elite_quality_increases_tape_grinder() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_elite_quality(), rng)

	assert_float(float(scout.get("tape_grinder", 0.0))).is_greater(0.25)


func test_terrible_quality_decreases_base_skill() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_terrible_quality(), rng)

	assert_float(float(scout.get("base_skill", 0.0))).is_less(0.55)


func test_terrible_quality_increases_noise() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_terrible_quality(), rng)

	assert_float(float(scout.get("board_noise_sigma", 0.0))).is_greater(1.8)


func test_terrible_quality_no_tape_grinder_bonus() -> void:
	var scout := _create_base_scout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, _create_terrible_quality(), rng)

	assert_float(float(scout.get("tape_grinder", 0.0))).is_equal(0.25)


func test_skill_clamping_at_maximum() -> void:
	var scout := {
		"base_skill": 0.85,
		"board_noise_sigma": 3.0,
		"tape_grinder": 0.90
	}
	var extreme_quality := {
		"base_quality": 0.80,
		"noise_modifier": 0.70,
		"skill_modifier": 1.20,
		"tier": "elite"
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, extreme_quality, rng)

	assert_float(float(scout.get("base_skill", 0.0))).is_less_equal(0.9)


func test_noise_clamping_at_minimum() -> void:
	var scout := {
		"base_skill": 0.85,
		"board_noise_sigma": 1.0,
		"tape_grinder": 0.90
	}
	var extreme_quality := {
		"base_quality": 0.80,
		"noise_modifier": 0.70,
		"skill_modifier": 1.20,
		"tier": "elite"
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	NflDraft._apply_team_quality_to_scout(scout, extreme_quality, rng)

	assert_float(float(scout.get("board_noise_sigma", 0.0))).is_greater_equal(0.8)


func test_determinism_same_seed_same_output() -> void:
	var scout_a := _create_base_scout()
	var scout_b := _create_base_scout()
	var quality := _create_elite_quality()

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99999
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99999

	NflDraft._apply_team_quality_to_scout(scout_a, quality, rng_a)
	NflDraft._apply_team_quality_to_scout(scout_b, quality, rng_b)

	assert_float(float(scout_a.get("base_skill", 0.0))).is_equal_approx(float(scout_b.get("base_skill", 0.0)), 0.0001)
	assert_float(float(scout_a.get("board_noise_sigma", 0.0))).is_equal_approx(float(scout_b.get("board_noise_sigma", 0.0)), 0.0001)
	assert_float(float(scout_a.get("tape_grinder", 0.0))).is_equal_approx(float(scout_b.get("tape_grinder", 0.0)), 0.0001)


func test_different_seeds_different_output() -> void:
	var scout_a := _create_base_scout()
	var scout_b := _create_base_scout()
	var quality := _create_elite_quality()

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 11111
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 22222

	NflDraft._apply_team_quality_to_scout(scout_a, quality, rng_a)
	NflDraft._apply_team_quality_to_scout(scout_b, quality, rng_b)

	# At least one value should differ (with high probability for different seeds)
	var skill_same: bool = abs(float(scout_a.get("base_skill", 0.0)) - float(scout_b.get("base_skill", 0.0))) < 0.0001
	var noise_same: bool = abs(float(scout_a.get("board_noise_sigma", 0.0)) - float(scout_b.get("board_noise_sigma", 0.0))) < 0.0001
	var grinder_same: bool = abs(float(scout_a.get("tape_grinder", 0.0)) - float(scout_b.get("tape_grinder", 0.0))) < 0.0001

	# It's statistically extremely unlikely all three match with different seeds
	var all_same: bool = skill_same and noise_same and grinder_same
	assert_bool(all_same).is_false()
