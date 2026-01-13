extends SceneTree

## Test script to verify team quality is properly integrated into scout generation
##
## Tests:
## 1. Team quality modifiers are applied to scouts
## 2. Elite teams (BAL) have better scouts than terrible teams (CLE)
## 3. Determinism is maintained (same seed = same scouts)

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const Rand = preload("res://autoloads/Rand.gd")

func _init() -> void:
	print("=== Team Quality Integration Test ===")
	print()

	# Create NflDraft instance
	var draft := NflDraft.new()

	# Create test teams
	var teams := [
		{"id": "BAL", "name": "Baltimore Ravens", "draft_order": 32},
		{"id": "CLE", "name": "Cleveland Browns", "draft_order": 1},
		{"id": "KC", "name": "Kansas City Chiefs", "draft_order": 16}
	]

	# Create test configuration
	var class_rules := {
		"draft_team_quality": {
			"enabled": true,
			"quality_tiers": {
				"elite": {
					"teams": ["BAL"],
					"base_quality": 0.75,
					"noise_modifier": 0.80,
					"skill_modifier": 1.15
				},
				"good": {
					"teams": ["KC"],
					"base_quality": 0.60,
					"noise_modifier": 0.95,
					"skill_modifier": 1.05
				},
				"terrible": {
					"teams": ["CLE"],
					"base_quality": 0.28,
					"noise_modifier": 1.35,
					"skill_modifier": 0.85
				}
			}
		}
	}

	var scouts_cfg := {
		"national_scouts": [
			{
				"base_skill": 0.55,
				"board_noise_sigma": 1.8,
				"tape_grinder": 0.25,
				"overrate_athletes": 0.0,
				"risk_aversion": 0.10,
				"stat_skill": {},
				"valuation_multipliers": {},
				"estimation_multipliers": {}
			}
		]
	}

	var stats_cfg := {}

	# Test 1: Generate team quality
	print("Test 1: Generating team quality...")
	var team_quality := NflDraft._generate_team_scouting_quality(teams, class_rules, 12345)

	for team_id in ["BAL", "CLE", "KC"]:
		var quality: Dictionary = team_quality.get(team_id, {})
		print("  %s: quality=%.2f, skill_mod=%.2f, noise_mod=%.2f, tier=%s" % [
			team_id,
			quality.get("base_quality", 0.0),
			quality.get("skill_modifier", 0.0),
			quality.get("noise_modifier", 0.0),
			quality.get("tier", "unknown")
		])

	assert(team_quality.has("BAL"), "BAL quality missing")
	assert(team_quality.has("CLE"), "CLE quality missing")
	assert(team_quality.has("KC"), "KC quality missing")
	print("  ✓ Team quality generated successfully")
	print()

	# Test 2: Generate scouts with quality modifiers
	print("Test 2: Generating scouts with quality modifiers...")
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)

	var team_scouts := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng, team_quality)

	for team_id in ["BAL", "CLE", "KC"]:
		var scout: Dictionary = team_scouts.get(team_id, {})
		print("  %s scout:" % team_id)
		print("    base_skill: %.3f" % scout.get("base_skill", 0.0))
		print("    board_noise_sigma: %.2f" % scout.get("board_noise_sigma", 0.0))
		print("    tape_grinder: %.3f" % scout.get("tape_grinder", 0.0))

	assert(team_scouts.has("BAL"), "BAL scout missing")
	assert(team_scouts.has("CLE"), "CLE scout missing")
	assert(team_scouts.has("KC"), "KC scout missing")
	print("  ✓ Scouts generated successfully")
	print()

	# Test 3: Verify quality differences
	print("Test 3: Verifying quality differences...")
	var bal_scout: Dictionary = team_scouts["BAL"]
	var cle_scout: Dictionary = team_scouts["CLE"]
	var kc_scout: Dictionary = team_scouts["KC"]

	var bal_skill := float(bal_scout.get("base_skill", 0.0))
	var cle_skill := float(cle_scout.get("base_skill", 0.0))
	var kc_skill := float(kc_scout.get("base_skill", 0.0))

	var bal_noise := float(bal_scout.get("board_noise_sigma", 0.0))
	var cle_noise := float(cle_scout.get("board_noise_sigma", 0.0))
	var kc_noise := float(kc_scout.get("board_noise_sigma", 0.0))

	print("  BAL skill (%.3f) > CLE skill (%.3f): %s" % [bal_skill, cle_skill, "✓" if bal_skill > cle_skill else "✗"])
	print("  BAL noise (%.2f) < CLE noise (%.2f): %s" % [bal_noise, cle_noise, "✓" if bal_noise < cle_noise else "✗"])
	print("  KC skill (%.3f) between BAL and CLE: %s" % [kc_skill, "✓" if (kc_skill > cle_skill and kc_skill < bal_skill) else "✗"])

	assert(bal_skill > cle_skill, "BAL should have better skill than CLE")
	assert(bal_noise < cle_noise, "BAL should have less noise than CLE")
	assert(kc_skill > cle_skill and kc_skill < bal_skill, "KC should be between BAL and CLE")
	print("  ✓ Quality differences verified")
	print()

	# Test 4: Determinism check
	print("Test 4: Verifying determinism...")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)
	var team_scouts2 := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng2, team_quality)

	var deterministic := true
	for team_id in ["BAL", "CLE", "KC"]:
		var scout1: Dictionary = team_scouts[team_id]
		var scout2: Dictionary = team_scouts2[team_id]

		if abs(float(scout1.get("base_skill", 0.0)) - float(scout2.get("base_skill", 0.0))) > 0.001:
			print("  ✗ base_skill differs for %s" % team_id)
			deterministic = false

		if abs(float(scout1.get("board_noise_sigma", 0.0)) - float(scout2.get("board_noise_sigma", 0.0))) > 0.001:
			print("  ✗ board_noise_sigma differs for %s" % team_id)
			deterministic = false

		if abs(float(scout1.get("tape_grinder", 0.0)) - float(scout2.get("tape_grinder", 0.0))) > 0.001:
			print("  ✗ tape_grinder differs for %s" % team_id)
			deterministic = false

	if deterministic:
		print("  ✓ Determinism verified (same seed produces identical scouts)")
	else:
		print("  ✗ Determinism broken!")
		assert(false, "Determinism check failed")

	print()
	print("=== All Tests Passed ===")
	quit()
