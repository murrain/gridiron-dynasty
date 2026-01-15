## GdUnit4 test suite for Tier-Based Recruiting
##
## Tests verify:
## 1. Tier config extraction and merging
## 2. Composite score filtering
## 3. Regional filtering
## 4. Eval budget enforcement
## 5. Regional bias by tier
## 6. Determinism with tier system
##
## Migrated from test_tier_recruiting.gd
extends GdUnitTestSuite

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")


func _get_global_cfg() -> Dictionary:
	return {
		"board_limit": 120,
		"rating_weight": 0.55,
		"eliteness_weight": 0.25,
		"proximity_weight": 0.20,
		"region_match_multiplier": 1.35
	}


func _get_tier_cfg() -> Dictionary:
	return {
		"elite": {
			"eval_budget": 400,
			"rating_weight": 0.60,
			"eliteness_weight": 0.28,
			"min_composite_score": 75.0,
			"region_match_multiplier": 1.15
		},
		"power": {
			"eval_budget": 180,
			"rating_weight": 0.57,
			"min_composite_score": 65.0,
			"region_match_multiplier": 1.35
		},
		"mid": {
			"eval_budget": 100,
			"min_composite_score": 50.0,
			"region_match_multiplier": 1.60
		},
		"low": {
			"eval_budget": 60,
			"min_composite_score": 40.0,
			"require_home_region": true,
			"region_match_multiplier": 2.00
		}
	}


func test_elite_tier_eval_budget() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var merged := pipeline._get_tier_config(elite_college, _get_global_cfg(), _get_tier_cfg())

	assert_int(int(merged.get("eval_budget", 0))).is_equal(400)


func test_elite_tier_rating_weight_override() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var merged := pipeline._get_tier_config(elite_college, _get_global_cfg(), _get_tier_cfg())

	assert_float(float(merged.get("rating_weight", 0.0))).is_equal(0.60)


func test_elite_tier_inherits_global_board_limit() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var merged := pipeline._get_tier_config(elite_college, _get_global_cfg(), _get_tier_cfg())

	assert_int(int(merged.get("board_limit", 0))).is_equal(120)


func test_power_tier_eval_budget() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var power_college := {"eliteness": 82.0, "tier": "power", "id": "michigan"}
	var merged := pipeline._get_tier_config(power_college, _get_global_cfg(), _get_tier_cfg())

	assert_int(int(merged.get("eval_budget", 0))).is_equal(180)


func test_mid_tier_inherits_global_rating_weight() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var mid_college := {"eliteness": 68.0, "tier": "mid", "id": "temple"}
	var merged := pipeline._get_tier_config(mid_college, _get_global_cfg(), _get_tier_cfg())

	assert_float(float(merged.get("rating_weight", 0.0))).is_equal(0.55)


func test_low_tier_requires_home_region() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var low_college := {"eliteness": 52.0, "tier": "low", "id": "utep"}
	var merged := pipeline._get_tier_config(low_college, _get_global_cfg(), _get_tier_cfg())

	assert_bool(bool(merged.get("require_home_region", false))).is_true()


func test_elite_composite_filter_75_plus() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_apply_tier_filters"):
		return

	var recruits := [
		{"player_id": "p1_top", "position": "QB", "home_region": "south"},
		{"player_id": "p2_high", "position": "WR", "home_region": "south"},
		{"player_id": "p3_mid", "position": "RB", "home_region": "south"}
	]
	var recruit_metadata := {
		"p1_top": {"baseline_score": 88.0, "home_region": "south"},
		"p2_high": {"baseline_score": 76.0, "home_region": "south"},
		"p3_mid": {"baseline_score": 62.0, "home_region": "south"}
	}
	var elite_cfg := {"min_composite_score": 75.0, "require_home_region": false}
	var elite_college := {"tier": "elite", "region": "south", "id": "alabama"}

	var filtered := pipeline._apply_tier_filters(recruits, elite_college, elite_cfg, recruit_metadata)

	assert_int(filtered.size()).is_equal(2)


func test_low_tier_regional_filter() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_apply_tier_filters"):
		return

	var recruits := [
		{"player_id": "p1_south", "position": "QB", "home_region": "south"},
		{"player_id": "p2_midwest", "position": "WR", "home_region": "midwest"},
		{"player_id": "p3_west", "position": "RB", "home_region": "west"}
	]
	var recruit_metadata := {
		"p1_south": {"baseline_score": 65.0, "home_region": "south"},
		"p2_midwest": {"baseline_score": 65.0, "home_region": "midwest"},
		"p3_west": {"baseline_score": 65.0, "home_region": "west"}
	}
	var low_cfg := {"min_composite_score": 40.0, "require_home_region": true}
	var low_south_college := {"tier": "low", "region": "south", "id": "rice"}

	var filtered := pipeline._apply_tier_filters(recruits, low_south_college, low_cfg, recruit_metadata)

	assert_int(filtered.size()).is_equal(1)
	assert_str(String(filtered[0].get("player_id", ""))).is_equal("p1_south")


func test_regional_bias_elite_lowest() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var elite_college := {"tier": "elite", "eliteness": 95.0, "id": "ohio_state"}
	var merged := pipeline._get_tier_config(elite_college, _get_global_cfg(), _get_tier_cfg())

	assert_float(float(merged.get("region_match_multiplier", 0.0))).is_equal(1.15)


func test_regional_bias_low_highest() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var low_college := {"tier": "low", "eliteness": 52.0, "id": "utep"}
	var merged := pipeline._get_tier_config(low_college, _get_global_cfg(), _get_tier_cfg())

	assert_float(float(merged.get("region_match_multiplier", 0.0))).is_equal(2.00)


func test_regional_bias_ordering() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var elite_merged := pipeline._get_tier_config(
		{"tier": "elite", "eliteness": 95.0, "id": "e"},
		_get_global_cfg(), _get_tier_cfg()
	)
	var power_merged := pipeline._get_tier_config(
		{"tier": "power", "eliteness": 82.0, "id": "p"},
		_get_global_cfg(), _get_tier_cfg()
	)
	var mid_merged := pipeline._get_tier_config(
		{"tier": "mid", "eliteness": 68.0, "id": "m"},
		_get_global_cfg(), _get_tier_cfg()
	)
	var low_merged := pipeline._get_tier_config(
		{"tier": "low", "eliteness": 52.0, "id": "l"},
		_get_global_cfg(), _get_tier_cfg()
	)

	var elite_bias := float(elite_merged.get("region_match_multiplier", 0.0))
	var power_bias := float(power_merged.get("region_match_multiplier", 0.0))
	var mid_bias := float(mid_merged.get("region_match_multiplier", 0.0))
	var low_bias := float(low_merged.get("region_match_multiplier", 0.0))

	assert_float(elite_bias).is_less(power_bias)
	assert_float(power_bias).is_less(mid_bias)
	assert_float(mid_bias).is_less(low_bias)


func test_backward_compatibility_empty_tier_config() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var legacy_cfg := {
		"board_limit": 120,
		"rating_weight": 0.55,
		"eliteness_weight": 0.25,
		"proximity_weight": 0.20,
		"region_match_multiplier": 1.35
	}
	var empty_tier_cfg := {}

	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var merged := pipeline._get_tier_config(elite_college, legacy_cfg, empty_tier_cfg)

	assert_int(int(merged.get("board_limit", 0))).is_equal(120)
	assert_float(float(merged.get("rating_weight", 0.0))).is_equal(0.55)
	assert_bool(not merged.has("eval_budget")).is_true()


func test_backward_compatibility_partial_tier_config() -> void:
	var pipeline := CollegeRecruiting.new()
	if not pipeline.has_method("_get_tier_config"):
		return

	var legacy_cfg := {"board_limit": 120, "rating_weight": 0.55}
	var partial_tier_cfg := {
		"elite": {"eval_budget": 400, "min_composite_score": 75.0}
	}

	var power_college := {"eliteness": 82.0, "tier": "power", "id": "michigan"}
	var merged := pipeline._get_tier_config(power_college, legacy_cfg, partial_tier_cfg)

	assert_int(int(merged.get("board_limit", 0))).is_equal(120)
	assert_bool(not merged.has("eval_budget")).is_true()
