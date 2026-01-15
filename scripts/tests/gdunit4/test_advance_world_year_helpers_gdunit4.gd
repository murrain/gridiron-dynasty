## GdUnit4 test suite for AdvanceWorldYear helper functions
##
## Tests seed derivation, HS player field initialization, and recruit profile building.
extends GdUnitTestSuite

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")


func test_derive_seed_deterministic() -> void:
	var pipeline := AdvanceWorldYear.new()

	var seed_a := pipeline._derive_seed(123, "hs_generation", "hs_school_gen")
	var seed_b := pipeline._derive_seed(123, "hs_generation", "hs_school_gen")

	assert_int(seed_a).is_equal(seed_b)


func test_derive_seed_different_steps() -> void:
	var pipeline := AdvanceWorldYear.new()

	var seed_a := pipeline._derive_seed(123, "hs_generation", "hs_school_gen")
	var seed_c := pipeline._derive_seed(123, "hs_generation", "hs_player_gen")

	assert_int(seed_a).is_not_equal(seed_c)


func test_apply_hs_player_fields() -> void:
	var pipeline := AdvanceWorldYear.new()

	var cfg := {
		"eligibility": {"hs_years": 4},
		"regions": [
			{"id": "north", "weight": 1.0},
			{"id": "south", "weight": 1.0}
		],
		"assignment": {"proximity_bias_min": 0.4, "proximity_bias_max": 0.6}
	}
	var players := [
		{"name": "A"},
		{"name": "B"}
	]

	pipeline._apply_hs_player_fields(players, 2025, cfg, 999)

	for p in players:
		var d: Dictionary = p
		assert_int(int(d.get("hs_year", 0))).is_equal(1)
		assert_int(int(d.get("hs_grad_year", 0))).is_equal(2028)
		assert_str(String(d.get("eligibility_status", ""))).is_equal("hs_underclass")
		assert_bool(String(d.get("home_region", "")) in ["north", "south"]).is_true()

		var bias := float(d.get("proximity_bias", 0.0))
		assert_float(bias).is_between(0.4, 0.6)


func test_build_recruit_profiles() -> void:
	var pipeline := AdvanceWorldYear.new()

	var graduates := [
		{
			"player_id": "hs-2025-0001",
			"name": "Prospect One",
			"position": "QB",
			"home_region": "north",
			"hs_school_id": "north-1",
			"eligibility_status": "hs_grad",
			"hs_grad_year": 2028,
			"hs_stats": {"score": 1},
			"stats": {"speed": 70.0},
			"potential": {"speed": 75.0},
			"physicals": {"weight_lb": 200.0},
			"composite_score": 80.0,
			"star_score": 85.0,
			"core_avg": 75.0
		}
	]

	var profiles := pipeline._build_recruit_profiles(graduates, 2025)

	assert_int(profiles.size()).is_equal(1)

	var profile: Dictionary = profiles[0]
	assert_str(profile.get("player_id", "")).is_equal("hs-2025-0001")
	assert_int(int(profile.get("source_year", 0))).is_equal(2025)


func test_derive_seed_with_different_base_seeds() -> void:
	var pipeline := AdvanceWorldYear.new()

	var seed_1 := pipeline._derive_seed(100, "hs_generation", "hs_school_gen")
	var seed_2 := pipeline._derive_seed(200, "hs_generation", "hs_school_gen")

	assert_int(seed_1).is_not_equal(seed_2)


func test_build_recruit_profiles_multiple() -> void:
	var pipeline := AdvanceWorldYear.new()

	var graduates := []
	for i in range(5):
		graduates.append({
			"player_id": "hs-2025-%04d" % i,
			"name": "Prospect %d" % i,
			"position": "QB" if i == 0 else "WR",
			"home_region": "north",
			"hs_school_id": "north-%d" % i,
			"eligibility_status": "hs_grad",
			"hs_grad_year": 2028,
			"hs_stats": {"score": i},
			"stats": {"speed": 70.0 + i},
			"potential": {"speed": 75.0 + i},
			"physicals": {"weight_lb": 200.0 + i * 5},
			"composite_score": 80.0 + i,
			"star_score": 85.0 + i,
			"core_avg": 75.0 + i
		})

	var profiles := pipeline._build_recruit_profiles(graduates, 2025)

	assert_int(profiles.size()).is_equal(5)

	for i in range(5):
		var profile: Dictionary = profiles[i]
		assert_str(profile.get("player_id", "")).is_equal("hs-2025-%04d" % i)
		assert_int(int(profile.get("source_year", 0))).is_equal(2025)
