extends RefCounted

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")

## Integration test: Verify college eligibility filtering works in full pipeline
func run(t) -> void:
	test_filter_integration_with_pipeline(t)
	test_determinism_across_runs(t)
	test_output_tracking(t)

func test_filter_integration_with_pipeline(t) -> void:
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
	t.assert_eq(eligible.size(), 60, "threshold 40 filters to 60 eligible players")

	# Verify all eligible players have rating >= 40
	for player in eligible:
		var p: Dictionary = player
		var rating := float(p.get("composite_score", 0.0))
		t.assert_true(rating >= 40.0, "eligible player %s has rating >= 40" % p.get("player_id"))

	# Verify player data is preserved
	var first_eligible: Dictionary = eligible[0]
	t.assert_true(first_eligible.has("player_id"), "player_id preserved")
	t.assert_true(first_eligible.has("name"), "name preserved")
	t.assert_true(first_eligible.has("position"), "position preserved")
	t.assert_true(first_eligible.has("home_region"), "home_region preserved")

func test_determinism_across_runs(t) -> void:
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
	t.assert_eq(result1.size(), result2.size(), "filter determinism: size match run 1-2")
	t.assert_eq(result2.size(), result3.size(), "filter determinism: size match run 2-3")

	# Verify player order is consistent
	for i in range(result1.size()):
		var p1: Dictionary = result1[i]
		var p2: Dictionary = result2[i]
		var p3: Dictionary = result3[i]
		t.assert_eq(p1.get("player_id"), p2.get("player_id"), "same player at index %d (run 1-2)" % i)
		t.assert_eq(p2.get("player_id"), p3.get("player_id"), "same player at index %d (run 2-3)" % i)

func test_output_tracking(t) -> void:
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

	t.assert_eq(total, 100, "total graduates tracked")
	t.assert_eq(college_eligible, 60, "college eligible count correct")
	t.assert_eq(ineligible, 40, "ineligible count correct")
	t.assert_eq(college_eligible + ineligible, total, "counts sum to total")
