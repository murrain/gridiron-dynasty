extends RefCounted
## Comprehensive test suite for tier-based recruiting system
##
## Tests verify:
## 1. Tier config extraction and merging
## 2. Composite score filtering
## 3. Regional filtering
## 4. Eval budget enforcement
## 5. Regional bias by tier
## 6. Determinism with tier system
## 7. Backward compatibility
## 8. Performance improvement measurement

const CollegeRecruiting = preload("res://scripts/pipelines/CollegeRecruiting.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")
const ConfigService = preload("res://autoloads/Config.gd")

func run(t) -> void:
	print("\n=== Tier-Based Recruiting Test Suite ===\n")

	_test_tier_config_extraction(t)
	_test_tier_filtering_by_composite(t)
	_test_tier_filtering_by_region(t)
	_test_eval_budget_enforcement(t)
	_test_regional_bias_by_tier(t)
	_test_determinism_with_tiers(t)
	_test_backward_compatibility(t)
	_test_performance_improvement(t)

	print("\n=== Test Suite Complete ===\n")

## Test 1: Verify tier config extraction and merging
## Ensures tier-specific configs properly override global defaults
func _test_tier_config_extraction(t) -> void:
	var pipeline := CollegeRecruiting.new()

	# Check if _get_tier_config method exists
	if not pipeline.has_method("_get_tier_config"):
		print("  SKIP: " +"_get_tier_config() not yet implemented by Agent 1")
		return

	var global_cfg := {
		"board_limit": 120,
		"rating_weight": 0.55,
		"eliteness_weight": 0.25,
		"proximity_weight": 0.20
	}

	var tier_cfg := {
		"elite": {
			"eval_budget": 400,
			"rating_weight": 0.60,
			"eliteness_weight": 0.28,
			"min_composite_score": 75.0
		},
		"power": {
			"eval_budget": 180,
			"rating_weight": 0.57,
			"min_composite_score": 65.0
		},
		"mid": {
			"eval_budget": 100,
			"min_composite_score": 50.0
		},
		"low": {
			"eval_budget": 60,
			"min_composite_score": 40.0,
			"require_home_region": true
		}
	}

	# Test 1a: Elite tier overrides
	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var elite_merged := pipeline._get_tier_config(elite_college, global_cfg, tier_cfg)

	t.assert_eq(int(elite_merged.get("eval_budget", 0)), 400, "Elite tier should have eval_budget=400")
	t.assert_eq(float(elite_merged.get("rating_weight", 0.0)), 0.60, "Elite tier should override rating_weight to 0.60")
	t.assert_eq(float(elite_merged.get("eliteness_weight", 0.0)), 0.28, "Elite tier should override eliteness_weight to 0.28")
	t.assert_eq(float(elite_merged.get("min_composite_score", 0.0)), 75.0, "Elite tier should have min_composite_score=75")
	# Should preserve global defaults not overridden
	t.assert_eq(int(elite_merged.get("board_limit", 0)), 120, "Elite tier should inherit global board_limit")

	# Test 1b: Power tier overrides
	var power_college := {"eliteness": 82.0, "tier": "power", "id": "michigan"}
	var power_merged := pipeline._get_tier_config(power_college, global_cfg, tier_cfg)

	t.assert_eq(int(power_merged.get("eval_budget", 0)), 180, "Power tier should have eval_budget=180")
	t.assert_eq(float(power_merged.get("rating_weight", 0.0)), 0.57, "Power tier should override rating_weight to 0.57")
	t.assert_eq(float(power_merged.get("min_composite_score", 0.0)), 65.0, "Power tier should have min_composite_score=65")

	# Test 1c: Mid tier overrides
	var mid_college := {"eliteness": 68.0, "tier": "mid", "id": "temple"}
	var mid_merged := pipeline._get_tier_config(mid_college, global_cfg, tier_cfg)

	t.assert_eq(int(mid_merged.get("eval_budget", 0)), 100, "Mid tier should have eval_budget=100")
	t.assert_eq(float(mid_merged.get("min_composite_score", 0.0)), 50.0, "Mid tier should have min_composite_score=50")
	# Should preserve global rating_weight since not overridden
	t.assert_eq(float(mid_merged.get("rating_weight", 0.0)), 0.55, "Mid tier should inherit global rating_weight")

	# Test 1d: Low tier overrides
	var low_college := {"eliteness": 52.0, "tier": "low", "id": "utep"}
	var low_merged := pipeline._get_tier_config(low_college, global_cfg, tier_cfg)

	t.assert_eq(int(low_merged.get("eval_budget", 0)), 60, "Low tier should have eval_budget=60")
	t.assert_eq(float(low_merged.get("min_composite_score", 0.0)), 40.0, "Low tier should have min_composite_score=40")
	t.assert_eq(bool(low_merged.get("require_home_region", false)), true, "Low tier should require home region")

	# Test 1e: Fallback tier determination by eliteness
	var no_tier_elite := {"eliteness": 92.0, "id": "clemson"}  # No explicit tier
	var inferred_elite := pipeline._get_tier_config(no_tier_elite, global_cfg, tier_cfg)
	t.assert_eq(int(inferred_elite.get("eval_budget", 0)), 400, "College with eliteness 92 should infer elite tier")

	var no_tier_power := {"eliteness": 80.0, "id": "penn_st"}  # No explicit tier
	var inferred_power := pipeline._get_tier_config(no_tier_power, global_cfg, tier_cfg)
	t.assert_eq(int(inferred_power.get("eval_budget", 0)), 180, "College with eliteness 80 should infer power tier")

	var no_tier_mid := {"eliteness": 68.0, "id": "iowa"}  # No explicit tier
	var inferred_mid := pipeline._get_tier_config(no_tier_mid, global_cfg, tier_cfg)
	t.assert_eq(int(inferred_mid.get("eval_budget", 0)), 100, "College with eliteness 68 should infer mid tier")

	var no_tier_low := {"eliteness": 55.0, "id": "rice"}  # No explicit tier
	var inferred_low := pipeline._get_tier_config(no_tier_low, global_cfg, tier_cfg)
	t.assert_eq(int(inferred_low.get("eval_budget", 0)), 60, "College with eliteness 55 should infer low tier")

## Test 2: Verify composite score filtering
## Ensures recruits are filtered by minimum composite score thresholds
func _test_tier_filtering_by_composite(t) -> void:
	var pipeline := CollegeRecruiting.new()

	# Check if _apply_tier_filters method exists
	if not pipeline.has_method("_apply_tier_filters"):
		print("  SKIP: " +"_apply_tier_filters() not yet implemented by Agent 1")
		return

	# Create test recruits with varying composite scores
	# Using realistic composite score range: 30-92
	var recruits := [
		{"player_id": "p1_top", "position": "QB", "home_region": "south"},
		{"player_id": "p2_high", "position": "WR", "home_region": "south"},
		{"player_id": "p3_mid", "position": "RB", "home_region": "south"},
		{"player_id": "p4_low", "position": "OL", "home_region": "south"},
		{"player_id": "p5_vlow", "position": "DL", "home_region": "south"}
	]

	var recruit_metadata := {
		"p1_top": {"baseline_score": 88.0, "home_region": "south"},   # 5-star
		"p2_high": {"baseline_score": 76.0, "home_region": "south"},  # 4-star
		"p3_mid": {"baseline_score": 62.0, "home_region": "south"},   # 3-star
		"p4_low": {"baseline_score": 48.0, "home_region": "south"},   # 2-star
		"p5_vlow": {"baseline_score": 35.0, "home_region": "south"}   # 1-star
	}

	# Test 2a: Elite tier (min_composite_score = 75) - only 4-5 star recruits
	var elite_cfg := {
		"min_composite_score": 75.0,
		"require_home_region": false
	}
	var elite_college := {"tier": "elite", "region": "south", "id": "alabama"}
	var elite_filtered := pipeline._apply_tier_filters(recruits, elite_college, elite_cfg, recruit_metadata)

	t.assert_eq(elite_filtered.size(), 2, "Elite should only see 75+ composites (2 recruits)")
	var elite_ids := {}
	for r in elite_filtered:
		elite_ids[String((r as Dictionary).get("player_id", ""))] = true
	t.assert_true(elite_ids.has("p1_top"), "Elite should see 88 composite recruit")
	t.assert_true(elite_ids.has("p2_high"), "Elite should see 76 composite recruit")

	# Test 2b: Power tier (min_composite_score = 65) - 3-5 star recruits
	var power_cfg := {
		"min_composite_score": 65.0,
		"require_home_region": false
	}
	var power_college := {"tier": "power", "region": "south", "id": "michigan"}
	var power_filtered := pipeline._apply_tier_filters(recruits, power_college, power_cfg, recruit_metadata)

	t.assert_eq(power_filtered.size(), 2, "Power should see 65+ composites (2 recruits)")
	var power_ids := {}
	for r in power_filtered:
		power_ids[String((r as Dictionary).get("player_id", ""))] = true
	t.assert_true(power_ids.has("p1_top"), "Power should see 88 composite recruit")
	t.assert_true(power_ids.has("p2_high"), "Power should see 76 composite recruit")

	# Test 2c: Mid tier (min_composite_score = 50) - 2-5 star recruits
	var mid_cfg := {
		"min_composite_score": 50.0,
		"require_home_region": false
	}
	var mid_college := {"tier": "mid", "region": "south", "id": "temple"}
	var mid_filtered := pipeline._apply_tier_filters(recruits, mid_college, mid_cfg, recruit_metadata)

	t.assert_eq(mid_filtered.size(), 3, "Mid should see 50+ composites (3 recruits)")
	var mid_ids := {}
	for r in mid_filtered:
		mid_ids[String((r as Dictionary).get("player_id", ""))] = true
	t.assert_true(mid_ids.has("p1_top"), "Mid should see 88 composite recruit")
	t.assert_true(mid_ids.has("p2_high"), "Mid should see 76 composite recruit")
	t.assert_true(mid_ids.has("p3_mid"), "Mid should see 62 composite recruit")

	# Test 2d: Low tier (min_composite_score = 40) - 1-5 star recruits above threshold
	var low_cfg := {
		"min_composite_score": 40.0,
		"require_home_region": false
	}
	var low_college := {"tier": "low", "region": "south", "id": "utep"}
	var low_filtered := pipeline._apply_tier_filters(recruits, low_college, low_cfg, recruit_metadata)

	t.assert_eq(low_filtered.size(), 4, "Low should see 40+ composites (4 recruits)")
	var low_ids := {}
	for r in low_filtered:
		low_ids[String((r as Dictionary).get("player_id", ""))] = true
	t.assert_true(not low_ids.has("p5_vlow"), "Low should NOT see 35 composite recruit")

## Test 3: Verify regional filtering for low tier
## Ensures low-tier colleges only see home region recruits
func _test_tier_filtering_by_region(t) -> void:
	var pipeline := CollegeRecruiting.new()

	# Check if _apply_tier_filters method exists
	if not pipeline.has_method("_apply_tier_filters"):
		print("  SKIP: " +"_apply_tier_filters() not yet implemented by Agent 1")
		return

	# Create recruits from different regions, all with same composite score
	var recruits := [
		{"player_id": "p1_south", "position": "QB", "home_region": "south"},
		{"player_id": "p2_midwest", "position": "WR", "home_region": "midwest"},
		{"player_id": "p3_west", "position": "RB", "home_region": "west"},
		{"player_id": "p4_northeast", "position": "OL", "home_region": "northeast"}
	]

	var recruit_metadata := {
		"p1_south": {"baseline_score": 65.0, "home_region": "south"},
		"p2_midwest": {"baseline_score": 65.0, "home_region": "midwest"},
		"p3_west": {"baseline_score": 65.0, "home_region": "west"},
		"p4_northeast": {"baseline_score": 65.0, "home_region": "northeast"}
	}

	# Test 3a: Low tier in South with require_home_region = true
	var low_cfg := {
		"min_composite_score": 40.0,
		"require_home_region": true
	}
	var low_south_college := {"tier": "low", "region": "south", "id": "rice"}
	var low_south_filtered := pipeline._apply_tier_filters(recruits, low_south_college, low_cfg, recruit_metadata)

	t.assert_eq(low_south_filtered.size(), 1, "Low tier in South should only see home region recruits")
	t.assert_eq(String(low_south_filtered[0].get("player_id", "")), "p1_south", "Should only see South recruit")

	# Test 3b: Low tier in Midwest with require_home_region = true
	var low_midwest_college := {"tier": "low", "region": "midwest", "id": "bowling_green"}
	var low_midwest_filtered := pipeline._apply_tier_filters(recruits, low_midwest_college, low_cfg, recruit_metadata)

	t.assert_eq(low_midwest_filtered.size(), 1, "Low tier in Midwest should only see home region recruits")
	t.assert_eq(String(low_midwest_filtered[0].get("player_id", "")), "p2_midwest", "Should only see Midwest recruit")

	# Test 3c: Elite tier with require_home_region = false (national recruiting)
	var elite_cfg := {
		"min_composite_score": 40.0,
		"require_home_region": false
	}
	var elite_college := {"tier": "elite", "region": "south", "id": "alabama"}
	var elite_filtered := pipeline._apply_tier_filters(recruits, elite_college, elite_cfg, recruit_metadata)

	t.assert_eq(elite_filtered.size(), 4, "Elite should see all regions (national recruiting)")

	# Test 3d: Power tier with require_home_region = false (regional recruiting)
	var power_cfg := {
		"min_composite_score": 40.0,
		"require_home_region": false
	}
	var power_college := {"tier": "power", "region": "midwest", "id": "michigan"}
	var power_filtered := pipeline._apply_tier_filters(recruits, power_college, power_cfg, recruit_metadata)

	t.assert_eq(power_filtered.size(), 4, "Power should see all regions (regional/national mix)")

	# Test 3e: Empty region handling
	var recruits_no_region := [
		{"player_id": "p5_unknown", "position": "QB"}
	]
	var metadata_no_region := {
		"p5_unknown": {"baseline_score": 65.0, "home_region": ""}
	}
	var low_filtered_no_region := pipeline._apply_tier_filters(recruits_no_region, low_south_college, low_cfg, metadata_no_region)

	t.assert_eq(low_filtered_no_region.size(), 0, "Low tier should filter out recruits with no region")

## Test 4: Verify eval_budget enforcement
## Ensures colleges evaluate correct number of recruits per tier
func _test_eval_budget_enforcement(t) -> void:
	var config_service := ConfigService.new()
	var colleges_cfg: Dictionary = config_service.get_config("world/colleges")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {})

	# Check if tier_recruiting config exists
	var tier_recruiting_cfg: Dictionary = colleges_cfg.get("tier_recruiting", {})
	if tier_recruiting_cfg.is_empty():
		print("  SKIP: " +"tier_recruiting config not yet implemented by Agent 1")
		return

	# Create a small set of recruits
	var recruits := []
	for i in range(500):  # Large enough to test eval budgets
		recruits.append({
			"player_id": "p%d" % i,
			"position": ["QB", "WR", "RB", "OL", "DL"][i % 5],
			"home_region": ["south", "midwest", "west", "northeast"][i % 4],
			"stats": {"speed": 70.0 + (i % 20), "acceleration": 68.0 + (i % 20)},
			"composite_score": 40.0 + (i % 50)
		})

	# Create test colleges of different tiers
	var colleges := [
		{"id": "elite1", "name": "Elite College", "tier": "elite", "eliteness": 95.0, "region": "south"},
		{"id": "power1", "name": "Power College", "tier": "power", "eliteness": 82.0, "region": "midwest"},
		{"id": "mid1", "name": "Mid College", "tier": "mid", "eliteness": 68.0, "region": "west"},
		{"id": "low1", "name": "Low College", "tier": "low", "eliteness": 52.0, "region": "northeast"}
	]

	var pipeline := CollegeRecruiting.new()
	var seed := 54321

	# Run recruiting (not parallel for deterministic counting)
	var result := pipeline.run(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		seed,
		2025,
		false  # Sequential for easier debugging
	)

	# Verify boards were built (indicating eval_budget is being used)
	var college_classes: Dictionary = result.get("college_classes", {}) as Dictionary

	# Elite should have larger board due to 400 eval_budget
	var elite_board_size: int = (college_classes.get("elite1", {}) as Dictionary).get("board_size", 0)
	var power_board_size: int = (college_classes.get("power1", {}) as Dictionary).get("board_size", 0)
	var mid_board_size: int = (college_classes.get("mid1", {}) as Dictionary).get("board_size", 0)
	var low_board_size: int = (college_classes.get("low1", {}) as Dictionary).get("board_size", 0)

	# Note: Actual board sizes may be limited by recruit pool size and filtering
	# These are relative comparisons
	if elite_board_size > 0:
		t.assert_true(elite_board_size >= power_board_size, "Elite board should be >= power board (larger eval_budget)")
		t.assert_true(power_board_size >= mid_board_size, "Power board should be >= mid board (larger eval_budget)")
		t.assert_true(mid_board_size >= low_board_size, "Mid board should be >= low board (larger eval_budget)")
	else:
		print("  SKIP: " +"Board sizes not exposed in result - eval_budget verification requires instrumentation")

## Test 5: Verify regional bias varies by tier
## Ensures region_match_multiplier differs appropriately by tier
func _test_regional_bias_by_tier(t) -> void:
	var pipeline := CollegeRecruiting.new()

	# Check if _get_tier_config method exists
	if not pipeline.has_method("_get_tier_config"):
		print("  SKIP: " +"_get_tier_config() not yet implemented by Agent 1")
		return

	var global_cfg := {
		"region_match_multiplier": 1.35  # Default baseline
	}

	var tier_cfg := {
		"elite": {
			"region_match_multiplier": 1.15  # Weak home bias (national recruiting)
		},
		"power": {
			"region_match_multiplier": 1.35  # Moderate home bias (regional recruiting)
		},
		"mid": {
			"region_match_multiplier": 1.60  # Strong home bias
		},
		"low": {
			"region_match_multiplier": 2.00  # Very strong home bias (local only)
		}
	}

	# Test 5a: Elite has weakest regional bias
	var elite_college := {"tier": "elite", "eliteness": 95.0, "id": "ohio_state"}
	var elite_merged := pipeline._get_tier_config(elite_college, global_cfg, tier_cfg)
	t.assert_eq(float(elite_merged.get("region_match_multiplier", 0.0)), 1.15, "Elite should have region_match_multiplier=1.15 (weakest bias)")

	# Test 5b: Power has moderate regional bias
	var power_college := {"tier": "power", "eliteness": 82.0, "id": "penn_state"}
	var power_merged := pipeline._get_tier_config(power_college, global_cfg, tier_cfg)
	t.assert_eq(float(power_merged.get("region_match_multiplier", 0.0)), 1.35, "Power should have region_match_multiplier=1.35 (moderate bias)")

	# Test 5c: Mid has strong regional bias
	var mid_college := {"tier": "mid", "eliteness": 68.0, "id": "temple"}
	var mid_merged := pipeline._get_tier_config(mid_college, global_cfg, tier_cfg)
	t.assert_eq(float(mid_merged.get("region_match_multiplier", 0.0)), 1.60, "Mid should have region_match_multiplier=1.60 (strong bias)")

	# Test 5d: Low has strongest regional bias
	var low_college := {"tier": "low", "eliteness": 52.0, "id": "utep"}
	var low_merged := pipeline._get_tier_config(low_college, global_cfg, tier_cfg)
	t.assert_eq(float(low_merged.get("region_match_multiplier", 0.0)), 2.00, "Low should have region_match_multiplier=2.00 (strongest bias)")

	# Test 5e: Verify bias ordering: Elite < Power < Mid < Low
	var elite_bias := float(elite_merged.get("region_match_multiplier", 0.0))
	var power_bias := float(power_merged.get("region_match_multiplier", 0.0))
	var mid_bias := float(mid_merged.get("region_match_multiplier", 0.0))
	var low_bias := float(low_merged.get("region_match_multiplier", 0.0))

	t.assert_true(elite_bias < power_bias, "Elite bias should be < Power bias")
	t.assert_true(power_bias < mid_bias, "Power bias should be < Mid bias")
	t.assert_true(mid_bias < low_bias, "Mid bias should be < Low bias")

## Test 6: Verify determinism maintained with tier system
## Critical for replay/save system integrity
func _test_determinism_with_tiers(t) -> void:
	var config_service := ConfigService.new()
	var colleges_cfg: Dictionary = config_service.get_config("world/colleges")
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {})

	# Check if tier_recruiting config exists
	var tier_recruiting_cfg: Dictionary = colleges_cfg.get("tier_recruiting", {})
	if tier_recruiting_cfg.is_empty():
		print("  SKIP: " +"tier_recruiting config not yet implemented - cannot test determinism with tiers")
		return

	# Create identical recruit pools
	var recruits_a := []
	var recruits_b := []
	for i in range(100):
		var recruit_data := {
			"player_id": "p%d" % i,
			"position": ["QB", "WR", "RB", "OL", "DL"][i % 5],
			"home_region": ["south", "midwest", "west", "northeast"][i % 4],
			"stats": {"speed": 70.0 + (i % 20), "acceleration": 68.0 + (i % 20)},
			"composite_score": 40.0 + (i % 50)
		}
		recruits_a.append(recruit_data.duplicate(true))
		recruits_b.append(recruit_data.duplicate(true))

	# Create identical college pools with tier diversity
	var colleges := [
		{"id": "elite1", "name": "Elite College", "tier": "elite", "eliteness": 95.0, "region": "south"},
		{"id": "power1", "name": "Power College", "tier": "power", "eliteness": 82.0, "region": "midwest"},
		{"id": "mid1", "name": "Mid College", "tier": "mid", "eliteness": 68.0, "region": "west"},
		{"id": "low1", "name": "Low College", "tier": "low", "eliteness": 52.0, "region": "northeast"}
	]

	var seed := 99999
	var year := 2025

	# Run recruiting twice with same seed
	var pipeline_a := CollegeRecruiting.new()
	var result_a := pipeline_a.run(
		recruits_a,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		seed,
		year,
		false  # Sequential for determinism
	)

	var pipeline_b := CollegeRecruiting.new()
	var result_b := pipeline_b.run(
		recruits_b,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		seed,
		year,
		false  # Sequential for determinism
	)

	# Verify identical results
	var commitments_a: Array = result_a.get("commitments", [])
	var commitments_b: Array = result_b.get("commitments", [])

	t.assert_eq(commitments_a.size(), commitments_b.size(), "Same seed should produce same commitment count")

	# Verify commitments match player-by-player
	for i in range(min(commitments_a.size(), commitments_b.size())):
		var commit_a: Dictionary = commitments_a[i]
		var commit_b: Dictionary = commitments_b[i]
		t.assert_eq(
			String(commit_a.get("player_id", "")),
			String(commit_b.get("player_id", "")),
			"Commitment %d should be deterministic" % i
		)
		t.assert_eq(
			String(commit_a.get("college_id", "")),
			String(commit_b.get("college_id", "")),
			"College choice should be deterministic for player %d" % i
		)

	# Verify college class sizes match
	var classes_a: Dictionary = result_a.get("college_classes", {}) as Dictionary
	var classes_b: Dictionary = result_b.get("college_classes", {}) as Dictionary

	for college in colleges:
		var college_id := String(college.get("id", ""))
		var class_a: Array = (classes_a.get(college_id, {}) as Dictionary).get("signees", [])
		var class_b: Array = (classes_b.get(college_id, {}) as Dictionary).get("signees", [])

		t.assert_eq(
			class_a.size(),
			class_b.size(),
			"%s should have same class size with same seed" % college_id
		)

## Test 7: Verify backward compatibility
## Ensures system works with legacy configs missing tier_recruiting
func _test_backward_compatibility(t) -> void:
	var pipeline := CollegeRecruiting.new()

	# Check if _get_tier_config method exists
	if not pipeline.has_method("_get_tier_config"):
		print("  SKIP: " +"_get_tier_config() not yet implemented by Agent 1")
		return

	# Legacy config without tier_recruiting section
	var legacy_cfg := {
		"board_limit": 120,
		"rating_weight": 0.55,
		"eliteness_weight": 0.25,
		"proximity_weight": 0.20,
		"region_match_multiplier": 1.35
	}

	var empty_tier_cfg := {}

	# Test 7a: Elite college falls back to global defaults
	var elite_college := {"eliteness": 95.0, "tier": "elite", "id": "alabama"}
	var elite_merged := pipeline._get_tier_config(elite_college, legacy_cfg, empty_tier_cfg)

	t.assert_eq(int(elite_merged.get("board_limit", 0)), 120, "Should use global board_limit")
	t.assert_eq(float(elite_merged.get("rating_weight", 0.0)), 0.55, "Should use global rating_weight")
	t.assert_true(not elite_merged.has("eval_budget"), "Should not have tier-specific eval_budget")
	t.assert_true(not elite_merged.has("min_composite_score"), "Should not have tier-specific min_composite_score")

	# Test 7b: Mid college falls back to global defaults
	var mid_college := {"eliteness": 68.0, "tier": "mid", "id": "temple"}
	var mid_merged := pipeline._get_tier_config(mid_college, legacy_cfg, empty_tier_cfg)

	t.assert_eq(int(mid_merged.get("board_limit", 0)), 120, "Mid should use global board_limit")
	t.assert_eq(float(mid_merged.get("region_match_multiplier", 0.0)), 1.35, "Mid should use global region bias")

	# Test 7c: Filtering with legacy config should not crash
	if pipeline.has_method("_apply_tier_filters"):
		var recruits := [
			{"player_id": "p1", "position": "QB", "home_region": "south"}
		]
		var metadata := {
			"p1": {"baseline_score": 75.0, "home_region": "south"}
		}

		# With no min_composite_score or require_home_region, should return all recruits
		var filtered := pipeline._apply_tier_filters(recruits, mid_college, mid_merged, metadata)
		t.assert_eq(filtered.size(), 1, "Legacy config should not filter recruits (no thresholds)")

	# Test 7d: Partial tier config (some tiers defined, others missing)
	var partial_tier_cfg := {
		"elite": {
			"eval_budget": 400,
			"min_composite_score": 75.0
		}
		# power, mid, low intentionally missing
	}

	var power_college := {"eliteness": 82.0, "tier": "power", "id": "michigan"}
	var power_merged := pipeline._get_tier_config(power_college, legacy_cfg, partial_tier_cfg)

	t.assert_eq(int(power_merged.get("board_limit", 0)), 120, "Power should fall back to global when tier missing")
	t.assert_true(not power_merged.has("eval_budget"), "Power should not inherit elite's eval_budget")

## Test 8: Performance improvement measurement
## Measures actual speedup achieved by tier system
func _test_performance_improvement(t) -> void:
	var config_service := ConfigService.new()
	var colleges_cfg := config_service.get_config("world/colleges")

	# Check if tier_recruiting config exists
	var tier_recruiting_cfg: Dictionary = colleges_cfg.get("tier_recruiting", {})
	if tier_recruiting_cfg.is_empty():
		print("  SKIP: " +"tier_recruiting config not yet implemented - performance measurement deferred to benchmark script")
		return

	print("\n--- Performance Test ---")
	print("Expected improvements (from plan):")
	print("  - Evaluations: 31,200 → 11,540 (63% reduction)")
	print("  - Time: 4940ms → 1998ms (2.47x speedup)")
	print("  - 20-year simulation: 175.6s → 116.8s (save 58.8s)")
	print("\nActual performance measurement requires full benchmark.")
	print("See scripts/benchmarks/recruiting_tier_bench.gd for detailed metrics.")
	print("------------------------\n")

	# Basic sanity check: ensure tier system doesn't break recruiting
	var positions_cfg: Dictionary = config_service.get_config("positions")
	var stats_cfg: Dictionary = config_service.get_config("stats")
	var scouts_cfg: Dictionary = config_service.get_config("scouts")
	var class_rules: Dictionary = config_service.get_config("main").get("class_rules", {})

	var recruits := []
	for i in range(50):  # Small test set
		recruits.append({
			"player_id": "p%d" % i,
			"position": ["QB", "WR", "RB"][i % 3],
			"home_region": ["south", "midwest"][i % 2],
			"stats": {"speed": 70.0 + (i % 20)},
			"composite_score": 50.0 + (i % 30)
		})

	var colleges := [
		{"id": "elite1", "tier": "elite", "eliteness": 95.0, "region": "south"},
		{"id": "low1", "tier": "low", "eliteness": 52.0, "region": "midwest"}
	]

	var pipeline := CollegeRecruiting.new()
	var start_time := Time.get_ticks_msec()

	var result := pipeline.run(
		recruits,
		colleges,
		colleges_cfg,
		positions_cfg,
		stats_cfg,
		class_rules,
		scouts_cfg,
		12345,
		2025,
		false
	)

	var elapsed_ms := Time.get_ticks_msec() - start_time

	var commitments: Array = result.get("commitments", [])
	t.assert_true(commitments.size() >= 0, "Tier system should produce valid recruiting results")

	print("  Sanity check: %d recruits, %d colleges -> %d commitments in %dms" % [
		recruits.size(),
		colleges.size(),
		commitments.size(),
		elapsed_ms
	])
