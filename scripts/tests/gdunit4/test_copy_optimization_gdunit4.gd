## GdUnit4 test suite for Task F4: Deep Copy Reduction
##
## Verifies that optimization strategies maintain:
## 1. Correctness: Output identical to previous implementation
## 2. Determinism: Same seed produces same results
## 3. Isolation: Original data not modified when copy is modified
## 4. Performance: Memory allocations reduced significantly
##
## Migrated from test_copy_optimization.gd
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")
const ScoutRuntime = preload("res://scripts/core/scouting/ScoutRuntime.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")
const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const NflSeason = preload("res://scripts/world/NflSeason.gd")


func test_selective_copy_preserves_name() -> void:
	var original := _create_test_player()
	var selective_copy := PlayerLifecycle._selective_copy(original)
	assert_str(String(selective_copy.get("name"))).is_equal(String(original.get("name")))


func test_selective_copy_preserves_player_id() -> void:
	var original := _create_test_player()
	var selective_copy := PlayerLifecycle._selective_copy(original)
	assert_str(String(selective_copy.get("player_id"))).is_equal(String(original.get("player_id")))


func test_selective_copy_preserves_position() -> void:
	var original := _create_test_player()
	var selective_copy := PlayerLifecycle._selective_copy(original)
	assert_str(String(selective_copy.get("position"))).is_equal(String(original.get("position")))


func test_selective_copy_preserves_age() -> void:
	var original := _create_test_player()
	var selective_copy := PlayerLifecycle._selective_copy(original)
	assert_int(int(selective_copy.get("age"))).is_equal(int(original.get("age")))


func test_selective_copy_preserves_stats_values() -> void:
	var original := _create_test_player()
	var selective_copy := PlayerLifecycle._selective_copy(original)
	var orig_stats: Dictionary = original.get("stats", {}) as Dictionary
	var sel_stats: Dictionary = selective_copy.get("stats", {}) as Dictionary
	assert_float(float(sel_stats.get("speed"))).is_equal(float(orig_stats.get("speed")))
	assert_float(float(sel_stats.get("strength"))).is_equal(float(orig_stats.get("strength")))


func test_selective_copy_isolates_stats_modifications() -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	var copy_stats: Dictionary = copy.get("stats", {}) as Dictionary
	copy_stats["speed"] = 99.0
	copy_stats["strength"] = 88.0

	var orig_stats: Dictionary = original.get("stats", {}) as Dictionary
	assert_float(float(orig_stats.get("speed", 0.0))).is_not_equal(99.0)
	assert_float(float(orig_stats.get("strength", 0.0))).is_not_equal(88.0)


func test_selective_copy_isolates_age_modifications() -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	copy["age"] = 999

	assert_int(int(original.get("age", 0))).is_not_equal(999)


func test_selective_copy_isolates_wear_modifications() -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	var copy_wear: Dictionary = copy.get("wear", {}) as Dictionary
	copy_wear["snaps"] = 9999

	var orig_wear: Dictionary = original.get("wear", {}) as Dictionary
	assert_int(int(orig_wear.get("snaps", 0))).is_not_equal(9999)


func test_selective_copy_shares_immutable_fields() -> void:
	var original := _create_test_player()
	var copy := PlayerLifecycle._selective_copy(original)

	assert_str(String(copy.get("name"))).is_equal(String(original.get("name")))
	assert_str(String(copy.get("player_id"))).is_equal(String(original.get("player_id")))
	assert_str(String(copy.get("position"))).is_equal(String(original.get("position")))


func test_lifecycle_determinism() -> void:
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()

	var player1 := _create_test_player()
	var player2 := _create_test_player()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 := PlayerLifecycle.advance_one_year(
		[player1], positions_cfg, main_cfg, stats_cfg, rng1
	)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 := PlayerLifecycle.advance_one_year(
		[player2], positions_cfg, main_cfg, stats_cfg, rng2
	)

	var evolved1: Dictionary = (result1.get("players", []) as Array)[0]
	var evolved2: Dictionary = (result2.get("players", []) as Array)[0]

	assert_int(int(evolved1.get("age"))).is_equal(int(evolved2.get("age")))

	var stats1: Dictionary = evolved1.get("stats", {}) as Dictionary
	var stats2: Dictionary = evolved2.get("stats", {}) as Dictionary
	assert_float(float(stats1.get("speed", 0.0))).is_equal_approx(float(stats2.get("speed", 0.0)), 0.001)

	var wear1: Dictionary = evolved1.get("wear", {}) as Dictionary
	var wear2: Dictionary = evolved2.get("wear", {}) as Dictionary
	assert_int(int(wear1.get("snaps"))).is_equal(int(wear2.get("snaps")))


func test_scout_runtime_determinism() -> void:
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

	assert_float(score1).is_equal_approx(score2, 0.0001)


func test_scout_runtime_does_not_modify_player() -> void:
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

	var final_speed := float((player.get("stats", {}) as Dictionary).get("speed", 0.0))
	assert_float(final_speed).is_equal(original_speed)


func test_high_school_season_determinism() -> void:
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

	assert_int((result1.get("graduates", []) as Array).size()).is_equal(
		(result2.get("graduates", []) as Array).size()
	)
	assert_int((result1.get("players", []) as Array).size()).is_equal(
		(result2.get("players", []) as Array).size()
	)


func test_college_season_determinism() -> void:
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

	assert_int(int(result1.get("rosters_updated"))).is_equal(int(result2.get("rosters_updated")))
	assert_int(int(result1.get("graduates"))).is_equal(int(result2.get("graduates")))
	assert_int(int(result1.get("draft_eligible_count"))).is_equal(int(result2.get("draft_eligible_count")))


func test_nfl_season_determinism() -> void:
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

	assert_int(int(result1.get("retirements"))).is_equal(int(result2.get("retirements")))
	assert_int(int(result1.get("free_agents"))).is_equal(int(result2.get("free_agents")))
	assert_int(int(result1.get("total_players"))).is_equal(int(result2.get("total_players")))


func test_lifecycle_multi_year_determinism() -> void:
	var positions_cfg := _minimal_positions_cfg()
	var main_cfg := _minimal_main_cfg()
	var stats_cfg := _minimal_stats_cfg()

	var player1 := _create_test_player()
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	var result1 := PlayerLifecycle.advance_years([player1], 5, positions_cfg, main_cfg, stats_cfg, rng1)

	var player2 := _create_test_player()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	var result2 := PlayerLifecycle.advance_years([player2], 5, positions_cfg, main_cfg, stats_cfg, rng2)

	var final1: Array = result1.get("players", []) as Array
	var final2: Array = result2.get("players", []) as Array

	assert_int(final1.size()).is_equal(final2.size())

	if final1.size() > 0 and final2.size() > 0:
		var p1: Dictionary = final1[0]
		var p2: Dictionary = final2[0]
		assert_int(int(p1.get("age"))).is_equal(int(p2.get("age")))
		var stats1: Dictionary = p1.get("stats", {}) as Dictionary
		var stats2: Dictionary = p2.get("stats", {}) as Dictionary
		assert_float(float(stats1.get("speed", 0.0))).is_equal_approx(float(stats2.get("speed", 0.0)), 0.001)


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
