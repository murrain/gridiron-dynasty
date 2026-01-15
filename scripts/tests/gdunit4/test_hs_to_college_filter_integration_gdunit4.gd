## GdUnit4 test suite for HS to College Filter Integration
##
## Tests the college eligibility filtering in the full pipeline.
extends GdUnitTestSuite

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")


func test_filter_integration_with_pipeline() -> void:
	# Create a minimal world state with HS graduates
	var graduates := []
	for i in range(100):
		graduates.append({
			"player_id": "hs-2025-%04d" % i,
			"name": "Player %d" % i,
			"position": "QB",
			"composite_score": float(i),  # Ratings from 0-99
			"home_region": "south",
			"hs_school_id": "school-1",
			"eligibility_status": "hs_grad",
			"hs_grad_year": 2025,
			"stats": {},
			"potential": {},
			"physicals": {}
		})

	var positions_cfg := {
		"QB": {"core_stats": ["speed", "awareness"]}
	}
	var main_cfg := {
		"class_rules": {}
	}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 40.0
		}
	}

	# Apply filter
	var eligible := AdvanceWorldYear._filter_college_eligible(
		graduates,
		positions_cfg,
		main_cfg,
		hs_cfg
	)

	# Verify threshold works correctly
	# Players 40-99 should pass (60 players)
	assert_int(eligible.size()).is_equal(60)

	# Verify all eligible players have rating >= 40
	for player in eligible:
		var p: Dictionary = player
		var rating := float(p.get("composite_score", 0.0))
		assert_float(rating).is_greater_equal(40.0)


func test_determinism_across_runs() -> void:
	var graduates := []
	for i in range(50):
		graduates.append({
			"player_id": "p%d" % i,
			"composite_score": float(i * 2)
		})

	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 50.0
		}
	}

	# Run filter 3 times
	var result1 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var result2 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)
	var result3 := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	# All runs should produce identical results
	assert_int(result1.size()).is_equal(result2.size())
	assert_int(result2.size()).is_equal(result3.size())

	# Verify player order is consistent
	for i in range(result1.size()):
		var p1: Dictionary = result1[i]
		var p2: Dictionary = result2[i]
		var p3: Dictionary = result3[i]
		assert_str(p1.get("player_id")).is_equal(p2.get("player_id"))
		assert_str(p2.get("player_id")).is_equal(p3.get("player_id"))


func test_output_tracking() -> void:
	# Test that output includes correct tracking fields
	var graduates := []
	for i in range(100):
		graduates.append({
			"player_id": "p%d" % i,
			"composite_score": float(i)
		})

	var positions_cfg := {}
	var main_cfg := {}
	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 40.0
		}
	}

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, positions_cfg, main_cfg, hs_cfg)

	var total := graduates.size()
	var college_eligible := eligible.size()
	var ineligible := total - college_eligible

	assert_int(total).is_equal(100)
	assert_int(college_eligible).is_equal(60)
	assert_int(ineligible).is_equal(40)
	assert_int(college_eligible + ineligible).is_equal(total)


func test_player_data_preserved() -> void:
	var graduates := []
	for i in range(100):
		graduates.append({
			"player_id": "hs-2025-%04d" % i,
			"name": "Player %d" % i,
			"position": "QB",
			"composite_score": float(i),
			"home_region": "south",
			"hs_school_id": "school-1"
		})

	var hs_cfg := {
		"recruiting": {
			"college_eligibility_threshold": 40.0
		}
	}

	var eligible := AdvanceWorldYear._filter_college_eligible(graduates, {}, {}, hs_cfg)

	# Verify player data is preserved
	var first_eligible: Dictionary = eligible[0]
	assert_bool(first_eligible.has("player_id")).is_true()
	assert_bool(first_eligible.has("name")).is_true()
	assert_bool(first_eligible.has("position")).is_true()
	assert_bool(first_eligible.has("home_region")).is_true()
