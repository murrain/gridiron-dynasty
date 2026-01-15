## GdUnit4 test suite for Team Quality Integration
##
## Tests:
## 1. Team quality modifiers are applied to scouts
## 2. Elite teams (BAL) have better scouts than terrible teams (CLE)
## 3. Determinism is maintained (same seed = same scouts)
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const Rand = preload("res://autoloads/Rand.gd")


func _create_test_teams() -> Array:
	return [
		{"id": "BAL", "name": "Baltimore Ravens", "draft_order": 32},
		{"id": "CLE", "name": "Cleveland Browns", "draft_order": 1},
		{"id": "KC", "name": "Kansas City Chiefs", "draft_order": 16}
	]


func _create_class_rules() -> Dictionary:
	return {
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


func _create_scouts_cfg() -> Dictionary:
	return {
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


func test_team_quality_generated() -> void:
	var teams := _create_test_teams()
	var class_rules := _create_class_rules()

	var team_quality := NflDraft._generate_team_scouting_quality(teams, class_rules, 12345)

	# Verify all teams have quality generated
	assert_bool(team_quality.has("BAL")).is_true()
	assert_bool(team_quality.has("CLE")).is_true()
	assert_bool(team_quality.has("KC")).is_true()

	# Verify quality structure
	var bal_quality: Dictionary = team_quality.get("BAL", {})
	assert_bool(bal_quality.has("base_quality")).is_true()
	assert_bool(bal_quality.has("skill_modifier")).is_true()
	assert_bool(bal_quality.has("noise_modifier")).is_true()
	assert_bool(bal_quality.has("tier")).is_true()


func test_scouts_generated_with_quality_modifiers() -> void:
	var draft := NflDraft.new()
	var teams := _create_test_teams()
	var class_rules := _create_class_rules()
	var scouts_cfg := _create_scouts_cfg()
	var stats_cfg := {}

	var team_quality := NflDraft._generate_team_scouting_quality(teams, class_rules, 12345)

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)

	var team_scouts := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng, team_quality)

	# Verify all teams have scouts
	assert_bool(team_scouts.has("BAL")).is_true()
	assert_bool(team_scouts.has("CLE")).is_true()
	assert_bool(team_scouts.has("KC")).is_true()

	# Verify scout structure
	var bal_scout: Dictionary = team_scouts.get("BAL", {})
	assert_bool(bal_scout.has("base_skill")).is_true()
	assert_bool(bal_scout.has("board_noise_sigma")).is_true()
	assert_bool(bal_scout.has("tape_grinder")).is_true()


func test_quality_differences() -> void:
	var draft := NflDraft.new()
	var teams := _create_test_teams()
	var class_rules := _create_class_rules()
	var scouts_cfg := _create_scouts_cfg()
	var stats_cfg := {}

	var team_quality := NflDraft._generate_team_scouting_quality(teams, class_rules, 12345)

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)

	var team_scouts := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng, team_quality)

	var bal_scout: Dictionary = team_scouts["BAL"]
	var cle_scout: Dictionary = team_scouts["CLE"]
	var kc_scout: Dictionary = team_scouts["KC"]

	var bal_skill := float(bal_scout.get("base_skill", 0.0))
	var cle_skill := float(cle_scout.get("base_skill", 0.0))
	var kc_skill := float(kc_scout.get("base_skill", 0.0))

	var bal_noise := float(bal_scout.get("board_noise_sigma", 0.0))
	var cle_noise := float(cle_scout.get("board_noise_sigma", 0.0))

	# BAL (elite) should have better skill than CLE (terrible)
	assert_float(bal_skill).is_greater(cle_skill)

	# BAL should have less noise than CLE
	assert_float(bal_noise).is_less(cle_noise)

	# KC should be between BAL and CLE
	assert_float(kc_skill).is_greater(cle_skill)
	assert_float(kc_skill).is_less(bal_skill)


func test_determinism() -> void:
	var draft := NflDraft.new()
	var teams := _create_test_teams()
	var class_rules := _create_class_rules()
	var scouts_cfg := _create_scouts_cfg()
	var stats_cfg := {}

	var team_quality := NflDraft._generate_team_scouting_quality(teams, class_rules, 12345)

	# Generate scouts twice with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)
	var team_scouts1 := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng1, team_quality)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = Rand.splitmix64(12345 ^ 0xD4AF7001)
	var team_scouts2 := draft._generate_team_scouts(teams, stats_cfg, scouts_cfg, rng2, team_quality)

	# Verify scouts are identical
	for team_id in ["BAL", "CLE", "KC"]:
		var scout1: Dictionary = team_scouts1[team_id]
		var scout2: Dictionary = team_scouts2[team_id]

		assert_float(float(scout1.get("base_skill", 0.0))).is_equal_approx(
			float(scout2.get("base_skill", 0.0)), 0.001)
		assert_float(float(scout1.get("board_noise_sigma", 0.0))).is_equal_approx(
			float(scout2.get("board_noise_sigma", 0.0)), 0.001)
		assert_float(float(scout1.get("tape_grinder", 0.0))).is_equal_approx(
			float(scout2.get("tape_grinder", 0.0)), 0.001)
