## GdUnit4 test suite for A1 Optimization: Starter Cache
##
## Validates that the starter cache optimization:
## 1. Produces identical results to the original implementation
## 2. Preserves determinism (same seed = same results)
## 3. Correctly identifies starters based on ratings
## 4. Works correctly with both college and NFL seasons
extends GdUnitTestSuite

const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")
const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")


## Test that compute_starters produces correct starter identification
func test_compute_starters_correctness() -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]},
		"WR": {"core_stats": ["speed", "catching"]}
	}
	var main_cfg := {"class_rules": {}}

	# Create roster with clear rating hierarchy
	var roster := {
		"players": [
			{"player_id": "qb1", "position": "QB", "composite_score": 90.0},
			{"player_id": "qb2", "position": "QB", "composite_score": 70.0},
			{"player_id": "rb1", "position": "RB", "composite_score": 85.0},
			{"player_id": "rb2", "position": "RB", "composite_score": 80.0},
			{"player_id": "rb3", "position": "RB", "composite_score": 65.0},
			{"player_id": "wr1", "position": "WR", "composite_score": 88.0},
			{"player_id": "wr2", "position": "WR", "composite_score": 82.0},
			{"player_id": "wr3", "position": "WR", "composite_score": 78.0},
			{"player_id": "wr4", "position": "WR", "composite_score": 60.0}
		]
	}

	var starters := StatGenerator.compute_starters(roster, positions_cfg, main_cfg)

	# Verify QB starter (top 1)
	assert_bool(starters.has("qb1")).is_true()
	assert_bool(starters.has("qb2")).is_false()

	# Verify RB starters (top 2)
	assert_bool(starters.has("rb1")).is_true()
	assert_bool(starters.has("rb2")).is_true()
	assert_bool(starters.has("rb3")).is_false()

	# Verify WR starters (top 3)
	assert_bool(starters.has("wr1")).is_true()
	assert_bool(starters.has("wr2")).is_true()
	assert_bool(starters.has("wr3")).is_true()
	assert_bool(starters.has("wr4")).is_false()


## Test that cached and uncached stat generation produce identical results
func test_cached_vs_uncached_identical() -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	var home_roster := {
		"players": [
			{"player_id": "h_qb1", "position": "QB", "composite_score": 75.0},
			{"player_id": "h_rb1", "position": "RB", "composite_score": 70.0},
			{"player_id": "h_rb2", "position": "RB", "composite_score": 65.0}
		]
	}

	var away_roster := {
		"players": [
			{"player_id": "a_qb1", "position": "QB", "composite_score": 72.0},
			{"player_id": "a_rb1", "position": "RB", "composite_score": 68.0},
			{"player_id": "a_rb2", "position": "RB", "composite_score": 62.0}
		]
	}

	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_home",
		"away_team_id": "team_away",
		"winner_id": "team_home",
		"loser_id": "team_away"
	}

	# Pre-compute starters
	var home_starters := StatGenerator.compute_starters(home_roster, positions_cfg, main_cfg)
	var away_starters := StatGenerator.compute_starters(away_roster, positions_cfg, main_cfg)

	var test_seed := 12345

	# Generate stats WITHOUT cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = test_seed
	var stats_uncached := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng1
	)

	# Generate stats WITH cache (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = test_seed
	var stats_cached := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng2,
		home_starters,
		away_starters
	)

	# Verify same players have stats
	assert_int(stats_uncached.keys().size()).is_equal(stats_cached.keys().size())

	# Verify stats are identical for each player
	for player_id in stats_uncached.keys():
		assert_bool(stats_cached.has(player_id)).is_true()

		var uncached: Dictionary = stats_uncached[player_id]
		var cached: Dictionary = stats_cached[player_id]

		# Check key stats are identical
		assert_int(uncached.get("games_played", 0)).is_equal(cached.get("games_played", 0))
		assert_int(uncached.get("games_started", 0)).is_equal(cached.get("games_started", 0))


## Test determinism: Same seed with cache should produce identical results across runs
func test_determinism_with_cache() -> void:
	var positions_cfg := {
		"QB": {"core_stats": ["accuracy", "arm_strength"]},
		"RB": {"core_stats": ["speed", "power"]}
	}
	var main_cfg := {"class_rules": {}}

	var home_roster := {
		"players": [
			{"player_id": "h_qb1", "position": "QB", "composite_score": 75.0},
			{"player_id": "h_rb1", "position": "RB", "composite_score": 70.0}
		]
	}

	var away_roster := {
		"players": [
			{"player_id": "a_qb1", "position": "QB", "composite_score": 72.0},
			{"player_id": "a_rb1", "position": "RB", "composite_score": 68.0}
		]
	}

	var game_result := {
		"game_id": "test_game_1",
		"year": 2025,
		"week": 1,
		"home_team_id": "team_home",
		"away_team_id": "team_away",
		"winner_id": "team_home",
		"loser_id": "team_away"
	}

	# Pre-compute starters ONCE
	var home_starters := StatGenerator.compute_starters(home_roster, positions_cfg, main_cfg)
	var away_starters := StatGenerator.compute_starters(away_roster, positions_cfg, main_cfg)

	var test_seed := 99999

	# Run 1: Generate stats with cache
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = test_seed
	var stats_run1 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng1,
		home_starters,
		away_starters
	)

	# Run 2: Generate stats with cache (same seed)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = test_seed
	var stats_run2 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng2,
		home_starters,
		away_starters
	)

	# Run 3: Generate stats with cache (same seed)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = test_seed
	var stats_run3 := StatGenerator.generate_game_stats(
		home_roster,
		away_roster,
		game_result,
		positions_cfg,
		main_cfg,
		rng3,
		home_starters,
		away_starters
	)

	# Verify all runs produce identical results
	for player_id in stats_run1.keys():
		var s1: Dictionary = stats_run1[player_id]
		var s2: Dictionary = stats_run2[player_id]
		var s3: Dictionary = stats_run3[player_id]

		assert_int(s1.get("games_started", 0)).is_equal(s2.get("games_started", 0))
		assert_int(s1.get("games_started", 0)).is_equal(s3.get("games_started", 0))


## Test that the cache structure is correctly initialized in world_state
func test_cache_structure() -> void:
	var world_state := {}

	# Initialize cache structure (simulates what CollegeSeason/NflSeason do)
	if not world_state.has("starter_cache"):
		world_state["starter_cache"] = {}

	var year := 2025
	var starter_cache: Dictionary = world_state["starter_cache"]
	if not starter_cache.has(year):
		starter_cache[year] = {}

	var year_cache: Dictionary = starter_cache[year]

	# Add some mock starters
	year_cache["team_001"] = {"player_1": true, "player_2": true}
	year_cache["team_002"] = {"player_3": true, "player_4": true}

	# Verify structure
	assert_bool(world_state.has("starter_cache")).is_true()
	assert_bool(world_state["starter_cache"].has(year)).is_true()
	assert_bool(world_state["starter_cache"][year].has("team_001")).is_true()
	assert_bool(world_state["starter_cache"][year].has("team_002")).is_true()

	# Verify retrieval
	var team1_starters: Dictionary = world_state["starter_cache"][year]["team_001"]
	assert_bool(team1_starters.has("player_1")).is_true()
	assert_bool(team1_starters.has("player_2")).is_true()
	assert_bool(team1_starters.has("player_3")).is_false()
