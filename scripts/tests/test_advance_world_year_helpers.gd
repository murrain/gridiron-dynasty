extends RefCounted

const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")

func run(t) -> void:
	var pipeline := AdvanceWorldYear.new()

	var seed_a := pipeline._derive_seed(123, "hs_generation", "hs_school_gen")
	var seed_b := pipeline._derive_seed(123, "hs_generation", "hs_school_gen")
	var seed_c := pipeline._derive_seed(123, "hs_generation", "hs_player_gen")
	
	t.assert_eq(seed_a, seed_b, "derive_seed is deterministic")
	t.assert_ne(seed_a, seed_c, "different step ids produce different seeds")

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
		t.assert_eq(int(d.get("hs_year", 0)), 1, "hs_year initialized")
		t.assert_eq(int(d.get("hs_grad_year", 0)), 2028, "hs_grad_year set from config")
		t.assert_eq(String(d.get("eligibility_status", "")), "hs_underclass", "eligibility set")
		t.assert_true(String(d.get("home_region", "")) in ["north", "south"], "home_region assigned")
		var bias := float(d.get("proximity_bias", 0.0))
		t.assert_between(bias, 0.4, 0.6, "proximity_bias within bounds")

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
	t.assert_eq(profiles.size(), 1, "recruit profiles generated")
	var profile: Dictionary = profiles[0]
	t.assert_eq(profile.get("player_id", ""), "hs-2025-0001", "profile keeps player_id")
	t.assert_eq(int(profile.get("source_year", 0)), 2025, "profile includes source_year")
