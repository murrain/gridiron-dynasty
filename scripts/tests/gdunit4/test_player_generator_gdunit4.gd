## GdUnit4 test suite for PlayerGenerator
##
## Validates single player generation and dynamic freak assignment.
## Migrated from test_player_generator.gd
extends GdUnitTestSuite

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")


var _gen: PlayerGenerator


func before() -> void:
	_gen = PlayerGenerator.new()
	_gen.names_cfg = {"first_names": ["Alex"], "last_names": ["Lee"]}
	_gen.positions_data = {
		"QB": {
			"physicals": {"height_in": {"mu": 72, "sigma": 0, "min": 70, "max": 76}},
			"distributions": {"speed": {"mu": 50, "sigma": 0, "min": 40, "max": 60}}
		}
	}
	_gen.stats_cfg = {"stats": [
		{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60},
		{"name": "strength", "mu": 60, "sigma": 0, "min": 50, "max": 70}
	]}
	_gen.class_rules = {"position_weights": {"QB": 1.0}}


func test_make_single_player_uses_names_config() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	assert_str(String(player.get("name"))).is_equal("Alex Lee")


func test_make_single_player_picks_position() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	assert_str(String(player.get("position"))).is_equal("QB")


func test_make_single_player_includes_stats() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	var stats = player.get("stats", {}) as Dictionary
	assert_bool(stats.has("speed")).is_true()


func test_assign_dynamic_freaks_respects_max() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var players = [
		{"position": "QB", "stats": {"speed": 80.0, "acceleration": 80.0, "agility": 80.0, "balance": 80.0, "vertical_jump": 80.0, "broad_jump": 80.0, "strength": 80.0}, "tags": []},
		{"position": "RB", "stats": {"speed": 70.0, "acceleration": 70.0, "agility": 70.0, "balance": 70.0, "vertical_jump": 70.0, "broad_jump": 70.0, "strength": 70.0}, "tags": []},
		{"position": "K", "stats": {"speed": 60.0, "acceleration": 60.0, "agility": 60.0, "balance": 60.0, "vertical_jump": 60.0, "broad_jump": 60.0, "strength": 60.0}, "tags": []}
	]
	_gen.assign_dynamic_freaks(players, 2, 0.0, 1.0, rng)

	var freak_count = 0
	for p in players:
		var tags = (p as Dictionary).get("tags", []) as Array
		if tags.has("PotentialSuperstar"):
			freak_count += 1

	assert_int(freak_count).is_less_equal(2)


func test_assign_dynamic_freaks_stats_stay_in_bounds() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var players = [
		{"position": "QB", "stats": {"speed": 80.0, "acceleration": 80.0, "agility": 80.0, "balance": 80.0, "vertical_jump": 80.0, "broad_jump": 80.0, "strength": 80.0}, "tags": []},
		{"position": "RB", "stats": {"speed": 70.0, "acceleration": 70.0, "agility": 70.0, "balance": 70.0, "vertical_jump": 70.0, "broad_jump": 70.0, "strength": 70.0}, "tags": []},
		{"position": "K", "stats": {"speed": 60.0, "acceleration": 60.0, "agility": 60.0, "balance": 60.0, "vertical_jump": 60.0, "broad_jump": 60.0, "strength": 60.0}, "tags": []}
	]
	_gen.assign_dynamic_freaks(players, 2, 0.0, 1.0, rng)

	for p in players:
		var tags = (p as Dictionary).get("tags", []) as Array
		if tags.has("PotentialSuperstar"):
			var st = (p as Dictionary).get("stats", {}) as Dictionary
			assert_float(float(st.get("speed", 0.0))).is_between(0.0, 100.0)


# ============================================================================
# CHAOS GENERATION TESTS
# ============================================================================
# These tests validate the 20% chaos generation path (stats-first, then best-fit position).
# All tests use explicit seeds to ensure determinism.

const StatsHelper = preload("res://scripts/generation/helpers/StatsHelper.gd")


## Test that generation mode follows the expected 80/20 distribution.
## With CHAOS_GENERATION_PROBABILITY = 0.20, we expect ~20% chaos players.
## Allow 5% variance for statistical sampling (15-25% acceptable).
func test_generation_mode_split_follows_80_20_distribution() -> void:
	# Arrange: create generator with multiple positions for meaningful chaos selection
	var gen = PlayerGenerator.new()
	gen.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	gen.positions_data = _create_multi_position_config()
	gen.stats_cfg = _create_test_stats_cfg()
	gen.class_rules = {"position_weights": {"QB": 0.25, "RB": 0.25, "WR": 0.25, "OL": 0.25}}

	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Act: generate 1000 players
	var chaos_count := 0
	var templated_count := 0
	for i in range(1000):
		# Derive a unique seed per player to simulate realistic generation
		var player_seed = int(rng.randi())
		var player_rng = RandomNumberGenerator.new()
		player_rng.seed = player_seed
		var player = gen._make_single_player(0.75, player_rng)
		var mode = String(player.get("generation_mode", ""))
		if mode == "chaos":
			chaos_count += 1
		elif mode == "templated":
			templated_count += 1

	# Assert: verify ~20% chaos with 5% tolerance (150-250 chaos players)
	var chaos_pct = float(chaos_count) / 1000.0
	assert_float(chaos_pct).is_greater_equal(0.15)
	assert_float(chaos_pct).is_less_equal(0.25)
	assert_int(chaos_count + templated_count).is_equal(1000)


## Test that chaos generation is deterministic - same seed produces identical players.
func test_chaos_generation_is_deterministic() -> void:
	# Arrange
	var all_stats = ["speed", "strength", "agility", "throw_power", "throw_accuracy"]
	var positions_cfg = _create_multi_position_config()

	# Act: generate chaos player twice with same seed
	var rng1 = RandomNumberGenerator.new()
	rng1.seed = 12345
	var result1 = StatsHelper.generate_chaos_player(all_stats, positions_cfg, rng1)

	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 12345
	var result2 = StatsHelper.generate_chaos_player(all_stats, positions_cfg, rng2)

	# Assert: results must be identical
	assert_str(String(result1["position"])).is_equal(String(result2["position"]))
	assert_str(String(result1["generation_mode"])).is_equal(String(result2["generation_mode"]))

	var stats1 = result1["stats"] as Dictionary
	var stats2 = result2["stats"] as Dictionary
	for stat_name in all_stats:
		assert_float(float(stats1[stat_name])).is_equal(float(stats2[stat_name]))


## Test that chaos players meet viability minimums for their assigned position.
func test_chaos_players_meet_viability_minimums() -> void:
	# Arrange: position config with explicit viability minimums
	var positions_cfg = {
		"QB": {
			"core_stats": ["throw_power", "throw_accuracy"],
			"distributions": {
				"throw_power": {"mu": 70, "sigma": 10, "viability_min": 40},
				"throw_accuracy": {"mu": 65, "sigma": 10, "viability_min": 35}
			}
		},
		"RB": {
			"core_stats": ["speed", "agility"],
			"distributions": {
				"speed": {"mu": 75, "sigma": 8, "viability_min": 50},
				"agility": {"mu": 70, "sigma": 8, "viability_min": 45}
			}
		}
	}
	var all_stats = ["speed", "strength", "agility", "throw_power", "throw_accuracy"]

	# Act: generate multiple chaos players
	var rng = RandomNumberGenerator.new()
	rng.seed = 99999
	for i in range(50):
		var result = StatsHelper.generate_chaos_player(all_stats, positions_cfg, rng)
		var stats = result["stats"] as Dictionary
		var position = String(result["position"])

		# Assert: player meets viability minimums for their assigned position
		var pos_cfg = positions_cfg.get(position, {}) as Dictionary
		var dists = pos_cfg.get("distributions", {}) as Dictionary
		for stat_name in dists.keys():
			var dist = dists[stat_name] as Dictionary
			if dist.has("viability_min"):
				var min_val = float(dist["viability_min"])
				var actual_val = float(stats.get(stat_name, 0.0))
				assert_float(actual_val).override_failure_message(
					"Player %d: stat '%s' (%.1f) below viability_min (%.1f) for position %s" %
					[i, stat_name, actual_val, min_val, position]
				).is_greater_equal(min_val)


## Test that _find_best_fit_position selects the position with highest core stat scores.
func test_best_fit_position_selects_highest_core_stats() -> void:
	# Arrange: player with stats strongly favoring QB
	var stats = {
		"throw_power": 90.0,
		"throw_accuracy": 85.0,
		"speed": 50.0,
		"agility": 45.0,
		"strength": 40.0
	}
	var positions_cfg = {
		"QB": {"core_stats": ["throw_power", "throw_accuracy"]},
		"RB": {"core_stats": ["speed", "agility"]},
		"OL": {"core_stats": ["strength"]}
	}

	# Act
	var best_position = StatsHelper._find_best_fit_position(stats, positions_cfg)

	# Assert: QB should be selected (90+85=175 > 50+45=95 > 40)
	assert_str(best_position).is_equal("QB")


## Test that viability adjustment is deterministic - same seed produces identical adjustments.
func test_viability_adjustment_maintains_determinism() -> void:
	# Arrange: stats that will need viability bumps
	var stats1 = {"throw_power": 30.0, "speed": 60.0}
	var stats2 = {"throw_power": 30.0, "speed": 60.0}
	var position = "QB"
	var positions_cfg = {
		"QB": {
			"distributions": {
				"throw_power": {"viability_min": 40}
			}
		}
	}

	# Act: run viability adjustment with same seed
	var rng1 = RandomNumberGenerator.new()
	rng1.seed = 77777
	var result1 = StatsHelper._ensure_viability(stats1, position, positions_cfg, rng1)

	var rng2 = RandomNumberGenerator.new()
	rng2.seed = 77777
	var result2 = StatsHelper._ensure_viability(stats2, position, positions_cfg, rng2)

	# Assert: results must be identical
	assert_float(float(result1["throw_power"])).is_equal(float(result2["throw_power"]))
	assert_float(float(result1["speed"])).is_equal(float(result2["speed"]))

	# Also verify the throw_power was bumped to meet viability
	assert_float(float(result1["throw_power"])).is_greater_equal(40.0)


## Test that chaos generation handles empty config gracefully without crashing.
func test_chaos_generation_handles_empty_config() -> void:
	# Arrange: empty positions config
	var all_stats = ["speed", "strength"]
	var empty_positions_cfg: Dictionary = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = 11111

	# Act: generate chaos player with empty config
	var result = StatsHelper.generate_chaos_player(all_stats, empty_positions_cfg, rng)

	# Assert: should return empty position, not crash
	assert_str(String(result.get("position", "MISSING"))).is_equal("")
	assert_str(String(result.get("generation_mode", "MISSING"))).is_equal("chaos")

	# Stats should still be generated
	var stats = result.get("stats", {}) as Dictionary
	assert_bool(stats.has("speed")).is_true()
	assert_bool(stats.has("strength")).is_true()


## Test that generation_mode field is recorded on all generated players.
func test_generation_mode_recorded_on_player() -> void:
	# Arrange
	var gen = PlayerGenerator.new()
	gen.names_cfg = {"first_names": ["Test"], "last_names": ["Player"]}
	gen.positions_data = _create_multi_position_config()
	gen.stats_cfg = _create_test_stats_cfg()
	gen.class_rules = {"position_weights": {"QB": 1.0}}

	# Act: generate players with different seeds to get both modes
	var found_chaos := false
	var found_templated := false

	for seed_val in range(1, 100):
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_val
		var player = gen._make_single_player(0.75, rng)

		# Assert: generation_mode field must always be present
		assert_bool(player.has("generation_mode")).override_failure_message(
			"Player generated with seed %d missing generation_mode field" % seed_val
		).is_true()

		var mode = String(player.get("generation_mode", ""))
		assert_bool(mode == "chaos" or mode == "templated").override_failure_message(
			"Invalid generation_mode '%s' for seed %d" % [mode, seed_val]
		).is_true()

		if mode == "chaos":
			found_chaos = true
		elif mode == "templated":
			found_templated = true

		if found_chaos and found_templated:
			break

	# Assert: should find both modes given 100 attempts
	assert_bool(found_chaos).override_failure_message(
		"No chaos players found in 100 generations"
	).is_true()
	assert_bool(found_templated).override_failure_message(
		"No templated players found in 100 generations"
	).is_true()


# ============================================================================
# TEST FIXTURE HELPERS
# ============================================================================

## Create a multi-position config for chaos testing.
## Includes core_stats and viability_min requirements.
func _create_multi_position_config() -> Dictionary:
	return {
		"QB": {
			"core_stats": ["throw_power", "throw_accuracy"],
			"physicals": {"height_in": {"mu": 74, "sigma": 2, "min": 70, "max": 78}},
			"distributions": {
				"throw_power": {"mu": 70, "sigma": 8, "viability_min": 40},
				"throw_accuracy": {"mu": 65, "sigma": 8, "viability_min": 35},
				"speed": {"mu": 55, "sigma": 10}
			}
		},
		"RB": {
			"core_stats": ["speed", "agility"],
			"physicals": {"height_in": {"mu": 70, "sigma": 2, "min": 66, "max": 74}},
			"distributions": {
				"speed": {"mu": 75, "sigma": 8, "viability_min": 50},
				"agility": {"mu": 70, "sigma": 8, "viability_min": 45},
				"strength": {"mu": 60, "sigma": 10}
			}
		},
		"WR": {
			"core_stats": ["speed", "agility"],
			"physicals": {"height_in": {"mu": 72, "sigma": 3, "min": 68, "max": 78}},
			"distributions": {
				"speed": {"mu": 78, "sigma": 6, "viability_min": 55},
				"agility": {"mu": 72, "sigma": 7, "viability_min": 50}
			}
		},
		"OL": {
			"core_stats": ["strength"],
			"physicals": {"height_in": {"mu": 76, "sigma": 2, "min": 72, "max": 80}},
			"distributions": {
				"strength": {"mu": 75, "sigma": 8, "viability_min": 55},
				"speed": {"mu": 45, "sigma": 8}
			}
		}
	}


## Create a test stats config with all stats needed for chaos generation.
func _create_test_stats_cfg() -> Dictionary:
	return {"stats": [
		{"name": "speed", "mu": 60, "sigma": 12, "min": 25, "max": 95},
		{"name": "strength", "mu": 60, "sigma": 12, "min": 25, "max": 95},
		{"name": "agility", "mu": 60, "sigma": 12, "min": 25, "max": 95},
		{"name": "throw_power", "mu": 55, "sigma": 15, "min": 20, "max": 95},
		{"name": "throw_accuracy", "mu": 55, "sigma": 15, "min": 20, "max": 95}
	]}
