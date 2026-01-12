extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const Config = preload("res://autoloads/Config.gd")

func run(t) -> void:
	var config = Config.new()
	var positions_cfg = config.get_config("positions")
	var main_cfg = config.get_config("main")
	var class_rules = main_cfg.get("class_rules", {})

	_test_elite_rescue_constant(t)
	_test_elite_prospect_floor(t, positions_cfg, class_rules)
	_test_qb_urgency_multipliers(t, positions_cfg, class_rules)

func _test_elite_rescue_constant(t) -> void:
	# Verify constant exists and has expected value
	t.assert_eq(NflDraft.ELITE_RESCUE_SCORE, 999.0, "ELITE_RESCUE_SCORE should be 999.0")

func _test_elite_prospect_floor(t, positions_cfg: Dictionary, class_rules: Dictionary) -> void:
	# Create a mock 78+ rated player (stats are on player directly, not nested)
	# WR core stats: speed, agility, route_running, catching
	var elite_player = {
		"player_id": "elite1",
		"position": "WR",
		"age": 22,
		"speed": 82,
		"agility": 80,
		"route_running": 78,
		"catching": 76
	}

	var rating = PlayerRatingCalculator.calculate_overall_rating(elite_player, positions_cfg, class_rules)
	t.assert_true(rating >= 78.0, "Elite player should have rating >= 78 (actual: %.1f)" % rating)

func _test_qb_urgency_multipliers(t, positions_cfg: Dictionary, class_rules: Dictionary) -> void:
	# Test desperate team (no QB)
	var empty_roster = {"by_position": {}, "players": []}
	var qb_urgency = NflDraft._evaluate_qb_urgency(empty_roster, positions_cfg, class_rules)

	t.assert_eq(qb_urgency.get("level"), "desperate", "Empty roster should be desperate")

	var qb_cfg = class_rules.get("draft_qb_urgency", {})
	var expected_mult = float(qb_cfg.get("desperate_multiplier", 2.8))
	t.assert_approx(float(qb_urgency.get("multiplier")), expected_mult, 0.01, "Desperate multiplier should match config")

	# Test stable team (franchise QB) - stats are on player directly, not nested
	var franchise_qb = {
		"player_id": "qb1",
		"position": "QB",
		"age": 28,
		"throw_power": 80,
		"throw_accuracy": 78,
		"awareness": 75,
		"decision_making": 75
	}
	var stable_roster = {
		"by_position": {"QB": ["qb1"]},
		"players": [franchise_qb]
	}
	var stable_urgency = NflDraft._evaluate_qb_urgency(stable_roster, positions_cfg, class_rules)

	t.assert_eq(stable_urgency.get("level"), "stable", "Roster with franchise QB should be stable (level: %s, rating: %.1f)" % [
		stable_urgency.get("level", "unknown"),
		PlayerRatingCalculator.calculate_overall_rating(franchise_qb, positions_cfg, class_rules)
	])
	t.assert_approx(float(stable_urgency.get("multiplier")), 1.0, 0.01, "Stable multiplier should be 1.0")

	# Test moderate team (aging QB without succession) - stats are on player directly, not nested
	var aging_qb = {
		"player_id": "qb2",
		"position": "QB",
		"age": 35,
		"throw_power": 75,
		"throw_accuracy": 72,
		"awareness": 73,
		"decision_making": 78
	}
	var aging_roster = {
		"by_position": {"QB": ["qb2"]},
		"players": [aging_qb]
	}
	var moderate_urgency = NflDraft._evaluate_qb_urgency(aging_roster, positions_cfg, class_rules)

	t.assert_eq(moderate_urgency.get("level"), "moderate", "Aging QB roster should be moderate (level: %s, rating: %.1f)" % [
		moderate_urgency.get("level", "unknown"),
		PlayerRatingCalculator.calculate_overall_rating(aging_qb, positions_cfg, class_rules)
	])
	var expected_moderate_mult = float(qb_cfg.get("moderate_multiplier", 1.6))
	t.assert_approx(float(moderate_urgency.get("multiplier")), expected_moderate_mult, 0.01, "Moderate multiplier should match config")
