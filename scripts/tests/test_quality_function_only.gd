extends SceneTree

## Minimal test to verify _apply_team_quality_to_scout works correctly

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const Rand = preload("res://autoloads/Rand.gd")

func _init() -> void:
	print("=== Quality Function Unit Test ===")
	print()

	# Test the static function directly
	var scout := {
		"base_skill": 0.55,
		"board_noise_sigma": 1.8,
		"tape_grinder": 0.25,
		"overrate_athletes": 0.0,
		"risk_aversion": 0.10
	}

	var elite_quality := {
		"base_quality": 0.75,
		"noise_modifier": 0.80,
		"skill_modifier": 1.15,
		"tier": "elite"
	}

	var terrible_quality := {
		"base_quality": 0.28,
		"noise_modifier": 1.35,
		"skill_modifier": 0.85,
		"tier": "terrible"
	}

	print("Test 1: Elite team quality modifiers")
	var elite_scout := scout.duplicate(true)
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345

	NflDraft._apply_team_quality_to_scout(elite_scout, elite_quality, rng1)

	print("  base_skill: %.3f (should be ~0.63, clamped to 0.3-0.9)" % elite_scout.get("base_skill", 0.0))
	print("  board_noise_sigma: %.2f (should be ~1.44, clamped to 0.8-3.5)" % elite_scout.get("board_noise_sigma", 0.0))
	print("  tape_grinder: %.3f (should be >0.25 for elite)" % elite_scout.get("tape_grinder", 0.0))

	assert(elite_scout.get("base_skill", 0.0) > 0.6, "Elite base_skill should increase")
	assert(elite_scout.get("board_noise_sigma", 0.0) < 1.8, "Elite noise should decrease")
	assert(elite_scout.get("tape_grinder", 0.0) > 0.25, "Elite tape_grinder should increase")
	print("  ✓ Elite modifiers applied correctly")
	print()

	print("Test 2: Terrible team quality modifiers")
	var terrible_scout := scout.duplicate(true)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345

	NflDraft._apply_team_quality_to_scout(terrible_scout, terrible_quality, rng2)

	print("  base_skill: %.3f (should be ~0.47, clamped to 0.3-0.9)" % terrible_scout.get("base_skill", 0.0))
	print("  board_noise_sigma: %.2f (should be ~2.43, clamped to 0.8-3.5)" % terrible_scout.get("board_noise_sigma", 0.0))
	print("  tape_grinder: %.3f (should be 0.25, no bonus for terrible)" % terrible_scout.get("tape_grinder", 0.0))

	assert(terrible_scout.get("base_skill", 0.0) < 0.55, "Terrible base_skill should decrease")
	assert(terrible_scout.get("board_noise_sigma", 0.0) > 1.8, "Terrible noise should increase")
	assert(terrible_scout.get("tape_grinder", 0.0) == 0.25, "Terrible tape_grinder should not change")
	print("  ✓ Terrible modifiers applied correctly")
	print()

	print("Test 3: Clamping verification")
	var extreme_scout := {
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

	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 12345

	NflDraft._apply_team_quality_to_scout(extreme_scout, extreme_quality, rng3)

	var final_skill := float(extreme_scout.get("base_skill", 0.0))
	var final_noise := float(extreme_scout.get("board_noise_sigma", 0.0))

	print("  base_skill: %.3f (clamped to max 0.9)" % final_skill)
	print("  board_noise_sigma: %.2f (clamped to min 0.8)" % final_noise)

	assert(final_skill <= 0.9, "base_skill should be clamped to 0.9")
	assert(final_noise >= 0.8, "board_noise_sigma should be clamped to 0.8")
	print("  ✓ Clamping works correctly")
	print()

	print("Test 4: Determinism check")
	var scout_a := scout.duplicate(true)
	var scout_b := scout.duplicate(true)

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 99999
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 99999

	NflDraft._apply_team_quality_to_scout(scout_a, elite_quality, rng_a)
	NflDraft._apply_team_quality_to_scout(scout_b, elite_quality, rng_b)

	var deterministic := true
	for key in ["base_skill", "board_noise_sigma", "tape_grinder"]:
		if abs(float(scout_a.get(key, 0.0)) - float(scout_b.get(key, 0.0))) > 0.0001:
			print("  ✗ %s differs" % key)
			deterministic = false

	if deterministic:
		print("  ✓ Determinism verified (same seed = same output)")
	else:
		assert(false, "Determinism broken")

	print()
	print("=== All Tests Passed ===")
	quit()
