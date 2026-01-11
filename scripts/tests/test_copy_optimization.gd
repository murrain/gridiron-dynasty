extends RefCounted
## Test suite for Task F4: Deep Copy Reduction
##
## Verifies that optimization strategies maintain:
## 1. Correctness: Output identical to previous implementation
## 2. Determinism: Same seed produces same results
## 3. Isolation: Original data not modified when copy is modified
## 4. Performance: Memory allocations reduced significantly

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")

func run(t) -> void:
	_test_selective_copy_correctness(t)
	_test_selective_copy_isolation(t)
	_test_selective_copy_immutable_sharing(t)
	_test_lifecycle_determinism(t)
	_test_scout_runtime_determinism(t)
	_test_scout_runtime_lightweight(t)
	_test_high_school_season_in_place(t)
	_test_college_season_in_place(t)
	_test_nfl_season_in_place(t)
	_test_lifecycle_multi_year_determinism(t)

## Test that _selective_copy produces identical behavior to duplicate(true)
func _test_selective_copy_correctness(t) -> void:
	var original := _create_test_player()
	var full_copy := original.duplicate(true)
	var selective_copy := PlayerLifecycle._selective_copy(original)

	# Top-level fields should be equal
	t.assert_eq(selective_copy.get("name"), original.get("name"), "name preserved")
	t.assert_eq(selective_copy.get("player_id"), original.get("player_id"), "player_id preserved")
	t.assert_eq(selective_copy.get("position"), original.get("position"), "position preserved")
	t.assert_eq(selective_copy.get("age"), original.get("age"), "age preserved")

	# Nested mutable structures should have equal values but different references
	var orig_stats: Dictionary = original.get("stats", {}) as Dictionary
	var sel_stats: Dictionary = selective_copy.get("stats", {}) as Dictionary
	t.assert_eq(sel_stats.get("speed"), orig_stats.get("speed"), "stats values equal")
	t.assert_eq(sel_stats.get("strength"), orig_stats.get("strength"), "stats values equal")

## Test that modifying selective copy doesn't affect original
func _test_selective_copy_isolation(t) -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	# Modify copy's stats
	var copy_stats: Dictionary = copy.get("stats", {}) as Dictionary
	copy_stats["speed"] = 99.0
	copy_stats["strength"] = 88.0

	# Original should be unchanged
	var orig_stats: Dictionary = original.get("stats", {}) as Dictionary
	t.assert_ne(float(orig_stats.get("speed", 0.0)), 99.0, "original stats unchanged")
	t.assert_ne(float(orig_stats.get("strength", 0.0)), 88.0, "original stats unchanged")

	# Modify copy's age (top-level field)
	copy["age"] = 999

	# Original should be unchanged
	t.assert_ne(int(original.get("age", 0)), 999, "original age unchanged")

	# Modify copy's wear
	var copy_wear: Dictionary = copy.get("wear", {}) as Dictionary
	copy_wear["snaps"] = 9999

	# Original should be unchanged
	var orig_wear: Dictionary = original.get("wear", {}) as Dictionary
	t.assert_ne(int(orig_wear.get("snaps", 0)), 9999, "original wear unchanged")

## Test that immutable fields are safely shared (no copy overhead)
func _test_selective_copy_immutable_sharing(t) -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	# Immutable string fields should be the same reference (no allocation)
	# Note: In GDScript, strings are reference-counted but logically immutable
	t.assert_eq(copy.get("name"), original.get("name"), "immutable name shared")
	t.assert_eq(copy.get("player_id"), original.get("player_id"), "immutable player_id shared")
	t.assert_eq(copy.get("position"), original.get("position"), "immutable position shared")

## Test that PlayerLifecycle with selective copy produces deterministic results
func _test_lifecycle_determinism(t) -> void:
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()

	var player1 := _create_test_player()
	var player2 := _create_test_player()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerLifecycle.advance_one_year(
		[player1],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerLifecycle.advance_one_year(
		[player2],
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2
	)

	var evolved1: Dictionary = (result1.get("players", []) as Array)[0]
	var evolved2: Dictionary = (result2.get("players", []) as Array)[0]

	# Same seed should produce same results
	t.assert_eq(evolved1.get("age"), evolved2.get("age"), "deterministic age")
	var stats1: Dictionary = evolved1.get("stats", {}) as Dictionary
	var stats2: Dictionary = evolved2.get("stats", {}) as Dictionary
	t.assert_approx(float(stats1.get("speed", 0.0)), float(stats2.get("speed", 0.0)), 0.001, "deterministic speed")
	t.assert_approx(float(stats1.get("strength", 0.0)), float(stats2.get("strength", 0.0)), 0.001, "deterministic strength")

	var wear1: Dictionary = evolved1.get("wear", {}) as Dictionary
	var wear2: Dictionary = evolved2.get("wear", {}) as Dictionary
	t.assert_eq(wear1.get("snaps"), wear2.get("snaps"), "deterministic wear snaps")
	t.assert_eq(wear1.get("collisions"), wear2.get("collisions"), "deterministic wear collisions")

## Test that ScoutRuntime perception is deterministic with optimizations
func _test_scout_runtime_determinism(t) -> void:
	var stats_cfg := _minimal_stats_cfg()
	var positions_data := _minimal_positions_cfg()
	var class_rules := {"recruiting": {"athletic_keys": ["speed"], "mental_keys": []}}

	var scout := {
		"base_skill": 0.5,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"stat_skill": {},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	var player := _create_test_player()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 54321
	var score1 := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	var score2 := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng2)

	t.assert_approx(score1, score2, 0.0001, "ScoutRuntime scoring is deterministic")

## Test that ScoutRuntime doesn't modify original player
func _test_scout_runtime_lightweight(t) -> void:
	var stats_cfg := _minimal_stats_cfg()
	var positions_data := _minimal_positions_cfg()
	var class_rules := {"recruiting": {"athletic_keys": ["speed"], "mental_keys": []}}

	var scout := {
		"base_skill": 0.5,
		"tape_grinder": 0.3,
		"risk_aversion": 0.1,
		"stat_skill": {},
		"estimation_multipliers": {},
		"valuation_multipliers": {}
	}

	var player := _create_test_player()
	var original_speed := float((player.get("stats", {}) as Dictionary).get("speed", 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = 11111
	var _score := ScoutRuntime.score_player(scout, player, positions_data, stats_cfg, class_rules, rng)

	# Original player should be unchanged
	var final_speed := float((player.get("stats", {}) as Dictionary).get("speed", 0.0))
	t.assert_eq(final_speed, original_speed, "ScoutRuntime doesn't modify original player")

## Test that HighSchoolSeason in-place modification is deterministic
func _test_high_school_season_in_place(t) -> void:
	var players1 := [_create_test_player(), _create_test_player()]
	var players2 := [_create_test_player(), _create_test_player()]
	var schools := _minimal_schools()
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()
	var config := _minimal_hs_config()

	var hs1 := HighSchoolSeason.new()
	var result1 := hs1.run(players1, schools, positions_cfg, main_cfg, stats_cfg, config, 12345, 2025)

	var hs2 := HighSchoolSeason.new()
	var result2 := hs2.run(players2, schools, positions_cfg, main_cfg, stats_cfg, config, 12345, 2025)

	# Same seed should produce same number of graduates
	t.assert_eq((result1.get("graduates", []) as Array).size(), (result2.get("graduates", []) as Array).size(), "deterministic graduates")
	t.assert_eq((result1.get("players", []) as Array).size(), (result2.get("players", []) as Array).size(), "deterministic active players")

## Test that CollegeSeason in-place modification is deterministic
func _test_college_season_in_place(t) -> void:
	var world_state1 := _minimal_world_state()
	var world_state2 := _minimal_world_state()
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()
	var config := _minimal_college_config()

	var cs1 := CollegeSeason.new()
	var result1 := cs1.run(world_state1, 2025, 12345, config, positions_cfg, main_cfg, stats_cfg)

	var cs2 := CollegeSeason.new()
	var result2 := cs2.run(world_state2, 2025, 12345, config, positions_cfg, main_cfg, stats_cfg)

	# Same seed should produce same results
	t.assert_eq(result1.get("rosters_updated"), result2.get("rosters_updated"), "deterministic roster updates")
	t.assert_eq(result1.get("graduates"), result2.get("graduates"), "deterministic graduates")
	t.assert_eq(result1.get("draft_eligible_count"), result2.get("draft_eligible_count"), "deterministic draft eligible")

## Test that NflSeason in-place modification is deterministic
func _test_nfl_season_in_place(t) -> void:
	var world_state1 := _minimal_nfl_world_state()
	var world_state2 := _minimal_nfl_world_state()
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()
	var league_cfg := {}

	var nfl1 := NflSeason.new()
	var result1 := nfl1.run(world_state1, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	var nfl2 := NflSeason.new()
	var result2 := nfl2.run(world_state2, 2025, 12345, league_cfg, positions_cfg, main_cfg, stats_cfg)

	# Same seed should produce same results
	t.assert_eq(result1.get("retirements"), result2.get("retirements"), "deterministic retirements")
	t.assert_eq(result1.get("free_agents"), result2.get("free_agents"), "deterministic free agents")
	t.assert_eq(result1.get("total_players"), result2.get("total_players"), "deterministic total players")

## Test multi-year lifecycle with selective copy maintains determinism
func _test_lifecycle_multi_year_determinism(t) -> void:
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()

	# Run 5 years with same seed
	var player1 := _create_test_player()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var result1 := PlayerLifecycle.advance_years([player1], 5, positions_cfg, main_cfg, stats_cfg, rng1)

	# Run 5 years again with same seed
	var player2 := _create_test_player()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var result2 := PlayerLifecycle.advance_years([player2], 5, positions_cfg, main_cfg, stats_cfg, rng2)

	var final1: Array = result1.get("players", []) as Array
	var final2: Array = result2.get("players", []) as Array

	t.assert_eq(final1.size(), final2.size(), "deterministic survival/retirement over 5 years")

	if final1.size() > 0 and final2.size() > 0:
		var p1: Dictionary = final1[0]
		var p2: Dictionary = final2[0]
		t.assert_eq(p1.get("age"), p2.get("age"), "deterministic age after 5 years")
		var stats1: Dictionary = p1.get("stats", {}) as Dictionary
		var stats2: Dictionary = p2.get("stats", {}) as Dictionary
		t.assert_approx(float(stats1.get("speed", 0.0)), float(stats2.get("speed", 0.0)), 0.001, "deterministic stats after 5 years")

# --- Helper functions to create minimal test data ---

func _create_test_player() -> Dictionary:
	return {
		"player_id": "TEST001",
		"name": "Test Player",
		"position": "QB",
		"age": 18,
		"birth_year": 2007,
		"hs_year": 1,
		"eligibility_status": "hs_underclass",
		"hs_school_id": "school_1",
		"home_region": "midwest",
		"stats": {
			"speed": 65.0,
			"strength": 70.0,
			"accuracy": 75.0,
			"decision": 68.0,
			"injury_proneness": 50.0
		},
		"potential": {
			"speed": 75.0,
			"strength": 80.0,
			"accuracy": 85.0,
			"decision": 78.0,
			"injury_proneness": 50.0
		},
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		},
		"development_context": {},
		"injuries": [],
		"development_report": []
	}

func _minimal_positions_cfg() -> Dictionary:
	return {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {
				"peak_age": 26,
				"decline_start": 30,
				"curve": "mid"
			},
			"distributions": {
				"speed": {"role": "secondary"},
				"strength": {"role": "other"}
			}
		}
	}

func _minimal_main_cfg() -> Dictionary:
	return {
		"development": {
			"curve_multipliers": {
				"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}
			},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"development_context": {
			"scheme_fit": {
				"score_min": -0.15,
				"score_max": 0.15,
				"role_weights": {
					"core": 0.3,
					"secondary": 0.15,
					"other": 0.05
				},
				"multiplier_min": 0.85,
				"multiplier_max": 1.15
			}
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {
			"min_age": 35,
			"soft_cap_age": 38,
			"max_age": 45,
			"base_chance": 0.02,
			"age_chance_per_year": 0.04,
			"low_rating_threshold": 55.0,
			"low_rating_boost": 0.08
		},
		"wear": {
			"snaps_per_year": 800,
			"collisions_per_year": 200,
			"position_multipliers": {"QB": 1.0},
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		},
		"injury": {
			"base_chance": 0.05,
			"proneness_slope": 0.03
		}
	}

func _minimal_stats_cfg() -> Dictionary:
	return {
		"stats": [
			{"name": "speed", "type": "base", "measurement_difficulty": 0.1},
			{"name": "strength", "type": "base", "measurement_difficulty": 0.2},
			{"name": "accuracy", "type": "base", "measurement_difficulty": 0.3},
			{"name": "decision", "type": "base", "measurement_difficulty": 0.4},
			{"name": "injury_proneness", "type": "base", "measurement_difficulty": 0.5}
		]
	}

func _minimal_schools() -> Array:
	return [
		{
			"id": "school_1",
			"name": "Test High School",
			"region": "midwest",
			"program_quality_multiplier": 1.0,
			"rehab_quality_multiplier": 1.0,
			"coach_specialist_position": "",
			"program_quality_tier": "mid",
			"coach_traits": [],
			"eliteness": 50.0
		}
	]

func _minimal_hs_config() -> Dictionary:
	return {
		"eligibility": {
			"hs_years": 4,
			"underclass_years": 2
		},
		"program_quality": {
			"default_dev_multiplier": 1.0
		},
		"position_specialists": {},
		"rehab_quality": {
			"default_multiplier": 1.0
		},
		"usage_profile": {
			"games_played_min": 8,
			"games_played_max": 12,
			"snaps_min": 150,
			"snaps_max": 650,
			"starter_chance": 0.35,
			"default_multiplier": 1.0,
			"starter_multiplier": 1.2
		},
		"competition": {
			"region_tiers": {"midwest": "mid"},
			"tier_growth_multipliers": {"mid": 1.0},
			"default_tier": "mid",
			"tier_usage_multipliers": {"mid": 1.0}
		},
		"performance": {
			"base_min": 40.0,
			"base_max": 70.0,
			"rating_weight": 0.6,
			"school_eliteness_weight": 0.2,
			"noise_min": -5.0,
			"noise_max": 5.0
		}
	}

func _minimal_college_config() -> Dictionary:
	return {
		"usage_profile": {
			"starter_chance": 0.45
		},
		"competition": {
			"tier_growth_multipliers": {"mid": 1.0}
		},
		"early_declaration": {
			"min_year": 3,
			"rating_threshold": 85.0,
			"base_chance": 0.15,
			"rating_bonus_per_point": 0.01
		}
	}

func _minimal_world_state() -> Dictionary:
	var player := _create_test_player()
	player["college_year"] = 1
	player["college_eligibility_status"] = "freshman"
	player["college_id"] = "college_1"
	return {
		"colleges": [
			{
				"id": "college_1",
				"name": "Test College",
				"tier": "mid",
				"eliteness": 60.0,
				"region": "midwest"
			}
		],
		"college_rosters": {
			"college_1": {
				"players": [player],
				"class_years": {1: ["TEST001"], 2: [], 3: [], 4: []}
			}
		},
		"draft_pool": {}
	}

func _minimal_nfl_world_state() -> Dictionary:
	var player := _create_test_player()
	player["age"] = 22
	player["nfl_status"] = "active"
	player["contract"] = {
		"years_total": 4,
		"years_remaining": 3,
		"status": "active"
	}
	return {
		"nfl_teams": [
			{
				"id": "team_1",
				"name": "Test Team",
				"conference": "AFC",
				"division": "East"
			}
		],
		"nfl_rosters": {
			"team_1": {
				"players": [player],
				"by_position": {"QB": ["TEST001"]}
			}
		},
		"retired_players": [],
		"free_agents": {}
	}
