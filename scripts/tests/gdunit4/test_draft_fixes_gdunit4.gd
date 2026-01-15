## GdUnit4 test suite for draft fixes
##
## Validates elite rescue constant, prospect floor, and QB urgency multipliers.
## Migrated from test_draft_fixes.gd
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const Config = preload("res://autoloads/Config.gd")


var _positions_cfg: Dictionary
var _class_rules: Dictionary


func before() -> void:
	var config = Config.new()
	_positions_cfg = config.get_config("positions")
	var main_cfg = config.get_config("main")
	_class_rules = main_cfg.get("class_rules", {})


func test_elite_rescue_constant() -> void:
	assert_float(NflDraft.ELITE_RESCUE_SCORE).is_equal(999.0)


func test_elite_prospect_floor() -> void:
	# Create a mock 78+ rated player - WR core stats: speed, agility, route_running, catching
	var elite_player = {
		"player_id": "elite1",
		"position": "WR",
		"age": 22,
		"speed": 82,
		"agility": 80,
		"route_running": 78,
		"catching": 76
	}

	var rating = PlayerRatingCalculator.calculate_overall_rating(elite_player, _positions_cfg, _class_rules)
	assert_float(rating).is_greater_equal(78.0)


func test_desperate_qb_urgency() -> void:
	var empty_roster = {"by_position": {}, "players": []}
	var qb_urgency = NflDraft._evaluate_qb_urgency(empty_roster, _positions_cfg, _class_rules)

	assert_str(String(qb_urgency.get("level"))).is_equal("desperate")


func test_desperate_qb_urgency_multiplier() -> void:
	var empty_roster = {"by_position": {}, "players": []}
	var qb_urgency = NflDraft._evaluate_qb_urgency(empty_roster, _positions_cfg, _class_rules)

	var qb_cfg = _class_rules.get("draft_qb_urgency", {})
	var expected_mult = float(qb_cfg.get("desperate_multiplier", 2.8))
	assert_float(float(qb_urgency.get("multiplier"))).is_equal_approx(expected_mult, 0.01)


func test_stable_qb_urgency() -> void:
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
	var stable_urgency = NflDraft._evaluate_qb_urgency(stable_roster, _positions_cfg, _class_rules)

	assert_str(String(stable_urgency.get("level"))).is_equal("stable")


func test_stable_qb_urgency_multiplier() -> void:
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
	var stable_urgency = NflDraft._evaluate_qb_urgency(stable_roster, _positions_cfg, _class_rules)

	assert_float(float(stable_urgency.get("multiplier"))).is_equal_approx(1.0, 0.01)


func test_moderate_qb_urgency() -> void:
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
	var moderate_urgency = NflDraft._evaluate_qb_urgency(aging_roster, _positions_cfg, _class_rules)

	assert_str(String(moderate_urgency.get("level"))).is_equal("moderate")


func test_moderate_qb_urgency_multiplier() -> void:
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
	var moderate_urgency = NflDraft._evaluate_qb_urgency(aging_roster, _positions_cfg, _class_rules)

	var qb_cfg = _class_rules.get("draft_qb_urgency", {})
	var expected_mult = float(qb_cfg.get("moderate_multiplier", 1.6))
	assert_float(float(moderate_urgency.get("multiplier"))).is_equal_approx(expected_mult, 0.01)
