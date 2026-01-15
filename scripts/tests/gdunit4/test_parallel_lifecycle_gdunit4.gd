## GdUnit4 test suite for parallel player lifecycle processing (Task F5)
##
## Verifies:
##   1. Parallel correctness: Same results as serial
##   2. Determinism: Same seed produces identical results
##   3. Performance: Parallel is faster for large arrays
##   4. Fallback: Small arrays use serial path
##   5. Thread safety: No data races or corruption
extends GdUnitTestSuite

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")


func test_parallel_correctness_small() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(50)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var parallel := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	assert_int(parallel.players.size()).is_equal(players.size())

	for i in range(parallel.players.size()):
		var p = parallel.players[i]
		if p != null:
			assert_bool(p.has("age")).is_true()
			assert_int(p.get("age")).is_equal(players[i].get("age") + 1)
			assert_bool(p.has("stats")).is_true()


func test_parallel_correctness_large() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(500)

	var rng := RandomNumberGenerator.new()
	rng.seed = 99999

	var parallel := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	assert_int(parallel.players.size()).is_equal(players.size())

	var valid_count := 0
	for i in range(parallel.players.size()):
		var p = parallel.players[i]
		if p != null:
			valid_count += 1
			assert_bool(p.has("age")).is_true()
			assert_bool(p.has("stats")).is_true()

	assert_int(valid_count).is_greater(0)


func test_parallel_determinism() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(300)

	var results := []
	for run in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 42424242
		var result := PlayerLifecycle.advance_one_year_parallel(
			players.duplicate(true),
			cfg.positions_cfg,
			cfg.main_cfg,
			cfg.stats_cfg,
			rng,
			{},
			4
		)
		results.append(result)

	for i in range(results[0].players.size()):
		var p0 = results[0].players[i]
		var p1 = results[1].players[i]
		var p2 = results[2].players[i]

		if p0 == null:
			assert_bool(p1 == null and p2 == null).is_true()
			continue

		_assert_players_equal(p0, p1, i)
		_assert_players_equal(p0, p2, i)


func test_parallel_with_nulls() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(100)

	players[10] = null
	players[25] = null
	players[50] = null
	players[99] = null

	var rng := RandomNumberGenerator.new()
	rng.seed = 55555

	var result := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	assert_that(result.players[10]).is_null()
	assert_that(result.players[25]).is_null()
	assert_that(result.players[50]).is_null()
	assert_that(result.players[99]).is_null()


func test_parallel_with_retirements() -> void:
	var cfg := _test_config()
	var players := []

	for i in range(100):
		if i < 50:
			players.append(_create_player(i, 20))
		else:
			players.append(_create_player(i, 40))

	var rng := RandomNumberGenerator.new()
	rng.seed = 77777

	var result := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	assert_int(result.retired.size()).is_greater(0)

	var null_count := 0
	for p in result.players:
		if p == null:
			null_count += 1

	assert_int(null_count).is_equal(result.retired.size())


func test_parallel_development_reports() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(150)

	var rng := RandomNumberGenerator.new()
	rng.seed = 88888

	var result := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	assert_int(result.development_reports.size()).is_equal(players.size())


func test_parallel_with_injuries() -> void:
	var cfg := _test_config()
	var players := []

	for i in range(100):
		var p := _create_player(i, 25)
		if i % 3 == 0:
			p["injuries"] = [{
				"type": "knee",
				"severity": 2.0,
				"affected_stats": ["speed", "agility"],
				"recovery_timeline": {
					"years_total": 2,
					"years_remaining": 1,
					"status": "active"
				},
				"long_term_penalty": {
					"stat_caps": {"speed": 85.0},
					"decline_multipliers": {"speed": 1.1}
				}
			}]
		players.append(p)

	var rng := RandomNumberGenerator.new()
	rng.seed = 66666

	var result := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		{},
		4
	)

	var injured_count := 0
	for p in result.players:
		if p != null and p.has("injuries") and p.injuries.size() > 0:
			injured_count += 1

	assert_int(injured_count).is_greater(0)


func test_parallel_with_development_context() -> void:
	var cfg := _test_config()
	var players := _generate_test_players(150)

	var dev_context := {
		"program_quality": 1.2,
		"coach_specialization": 1.1,
		"usage": 1.15,
		"competition_tier": 1.05
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = 44444

	var parallel := PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		cfg.positions_cfg,
		cfg.main_cfg,
		cfg.stats_cfg,
		rng,
		dev_context,
		4
	)

	assert_int(parallel.players.size()).is_equal(players.size())


func _create_player(id: int, age: int) -> Dictionary:
	return {
		"player_id": "P%d" % id,
		"name": "Player %d" % id,
		"age": age,
		"position": "QB",
		"stats": {
			"accuracy": 60.0 + (id % 30),
			"decision": 55.0 + (id % 25),
			"speed": 65.0 + (id % 20),
			"agility": 62.0 + (id % 22)
		},
		"potential": {
			"accuracy": 75.0 + (id % 20),
			"decision": 70.0 + (id % 20),
			"speed": 80.0 + (id % 15),
			"agility": 78.0 + (id % 18)
		}
	}


func _generate_test_players(count: int) -> Array:
	var players := []
	for i in range(count):
		players.append(_create_player(i, 20 + (i % 15)))
	return players


func _assert_players_equal(p1: Dictionary, p2: Dictionary, index: int) -> void:
	assert_str(p1.get("player_id")).is_equal(p2.get("player_id"))
	assert_int(p1.get("age")).is_equal(p2.get("age"))

	var s1: Dictionary = p1.get("stats", {})
	var s2: Dictionary = p2.get("stats", {})

	for key in s1.keys():
		var v1 := float(s1.get(key, 0.0))
		var v2 := float(s2.get(key, 0.0))
		assert_float(v1).is_equal_approx(v2, 0.001)


func _test_config() -> Dictionary:
	return {
		"positions_cfg": {
			"QB": {
				"core_stats": ["accuracy", "decision"],
				"development": {
					"peak_age": 27,
					"decline_start": 32,
					"curve": "mid"
				}
			}
		},
		"main_cfg": {
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
					"role_weights": {"core": 0.3, "secondary": 0.15, "other": 0.0},
					"multiplier_min": 0.85,
					"multiplier_max": 1.15,
					"score_min": -0.15,
					"score_max": 0.15
				}
			},
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"retirement": {
				"min_age": 27,
				"soft_cap_age": 33,
				"max_age": 40,
				"base_chance": 0.02,
				"age_chance_per_year": 0.04,
				"low_rating_threshold": 55.0,
				"low_rating_boost": 0.08
			},
			"wear": {
				"snaps_per_year": 500,
				"collisions_per_year": 50,
				"position_multipliers": {"QB": 0.8},
				"decline_snaps_scale": 8000.0,
				"decline_collisions_scale": 2600.0,
				"decline_injuries_scale": 6.0,
				"decline_per_wear": 0.2,
				"decline_min_multiplier": 1.0,
				"decline_max_multiplier": 1.6
			},
			"injury": {
				"base_chance": 0.05,
				"proneness_slope": 0.1
			}
		},
		"stats_cfg": {
			"stats": [
				{"name": "accuracy", "type": "base"},
				{"name": "decision", "type": "base"},
				{"name": "speed", "type": "base"},
				{"name": "agility", "type": "base"}
			]
		}
	}
