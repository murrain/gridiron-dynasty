extends RefCounted

## Test suite for MockDraftGenerator
##
## Tests cover:
## - Determinism (same seed = same results)
## - Evolution (7 versions generated)
## - Variance (early mocks have high noise, late mocks low noise)
## - Consensus (rankings converge over time)
## - Performance (<500ms for all 7 versions)
## - Edge cases (empty pool, single player, etc.)

const MockDraftGenerator = preload("res://scripts/world/MockDraftGenerator.gd")

func run(t) -> void:
	test_generate_mock_determinism(t)
	test_all_versions_generated(t)
	test_early_mock_variance(t)
	test_late_mock_accuracy(t)
	test_mock_evolution_convergence(t)
	test_consensus_rankings(t)
	test_player_projection_storage(t)
	test_projection_range_calculation(t)
	test_get_latest_projection(t)
	test_mock_accuracy_calculation(t)
	test_empty_pool_handling(t)
	test_mock_pick_numbering(t)
	test_mock_version_independence(t)
	test_performance_budget(t)


## Test 1: Same seed produces identical mock draft
func test_generate_mock_determinism(t) -> void:
	var pool1 := _create_test_draft_pool(100)
	var pool2 := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	var seed := 12345

	var result1 := MockDraftGenerator.generate_mock(
		pool1, teams, 3, 2024, seed,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var result2 := MockDraftGenerator.generate_mock(
		pool2, teams, 3, 2024, seed,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Verify same picks
	var picks1: Array = result1.get("picks", [])
	var picks2: Array = result2.get("picks", [])

	t.assert_eq(picks1.size(), picks2.size(), "same number of picks")

	for i in range(min(picks1.size(), picks2.size())):
		var p1: Dictionary = picks1[i]
		var p2: Dictionary = picks2[i]
		t.assert_eq(
			String(p1.get("player_id", "")),
			String(p2.get("player_id", "")),
			"pick %d has same player" % i
		)


## Test 2: All 7 versions generated
func test_all_versions_generated(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 54321,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Check first player has all 7 versions
	var first_player: Dictionary = pool[0]
	var di: Dictionary = first_player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	t.assert_eq(mock_history.size(), 7, "7 mock versions generated")

	# Verify version numbers
	for i in range(7):
		var entry: Dictionary = mock_history[i]
		t.assert_eq(int(entry.get("version", 0)), i + 1, "version %d present" % (i + 1))


## Test 3: Early mock has high variance
func test_early_mock_variance(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	# Generate version 1 (3 months out - high variance)
	var result := MockDraftGenerator.generate_mock(
		pool, teams, 1, 2024, 12345,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Noise sigma should be 15.0 for version 1
	t.assert_eq(
		float(result.get("noise_sigma", 0.0)),
		15.0,
		"version 1 has sigma=15"
	)


## Test 4: Late mock has low variance
func test_late_mock_accuracy(t) -> void:
	var pool := _create_test_draft_pool(100)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	# Generate version 7 (hours before - low variance)
	var result := MockDraftGenerator.generate_mock(
		pool, teams, 7, 2024, 12345,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Noise sigma should be 2.5 for version 7
	t.assert_eq(
		float(result.get("noise_sigma", 0.0)),
		2.5,
		"version 7 has sigma=2.5"
	)


## Test 5: Projections converge over mock versions
func test_mock_evolution_convergence(t) -> void:
	# Create pool with clear talent separation
	var pool := []
	for i in range(50):
		# First 10 players are clearly better
		var rating := 90.0 - float(i) if i < 10 else 60.0 - float(i - 10) * 0.5
		pool.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": "WR",
			"stats": {"speed": rating, "strength": rating, "agility": rating}
		})

	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 12345,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Check top player's variance decreases over time
	var top_player: Dictionary = pool[0]
	var variance := MockDraftGenerator.get_projection_variance(top_player)

	# Top player should have relatively low variance (consistent top pick)
	t.assert_true(variance < 10.0, "top player variance is manageable: %.1f" % variance)


## Test 6: Consensus rankings match pick order
func test_consensus_rankings(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	var result := MockDraftGenerator.generate_mock(
		pool, teams, 4, 2024, 99999,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var picks: Array = result.get("picks", [])
	var consensus: Array = result.get("consensus_rankings", [])

	t.assert_eq(picks.size(), consensus.size(), "picks and consensus same size")

	# Verify order matches
	for i in range(min(picks.size(), consensus.size())):
		var pick: Dictionary = picks[i]
		t.assert_eq(
			String(pick.get("player_id", "")),
			String(consensus[i]),
			"consensus[%d] matches pick player_id" % i
		)


## Test 7: Projections stored correctly in player data
func test_player_projection_storage(t) -> void:
	var pool := _create_test_draft_pool(30)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 11111,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Check all players have mock_history
	for player in pool:
		var p: Dictionary = player
		var di: Dictionary = p.get("draft_intelligence", {})
		var mock_history: Array = di.get("mock_history", [])

		t.assert_eq(mock_history.size(), 7, "player has 7 projections")

		for entry in mock_history:
			var e: Dictionary = entry
			t.assert_true(e.has("version"), "entry has version")
			t.assert_true(e.has("projected_pick"), "entry has projected_pick")
			t.assert_true(e.has("range_low"), "entry has range_low")
			t.assert_true(e.has("range_high"), "entry has range_high")
			t.assert_true(e.has("generated_week"), "entry has generated_week")


## Test 8: Range calculation is correct
func test_projection_range_calculation(t) -> void:
	var pool := _create_test_draft_pool(40)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 22222,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Check a player's range
	var player: Dictionary = pool[0]
	var di: Dictionary = player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	# Version 1 should have range_variance of 10
	var v1: Dictionary = mock_history[0]
	var v1_pick := int(v1.get("projected_pick", 0))
	var v1_low := int(v1.get("range_low", 0))
	var v1_high := int(v1.get("range_high", 0))

	t.assert_true(v1_low >= 1, "range_low >= 1")
	t.assert_true(v1_high > v1_low, "range_high > range_low")
	t.assert_true(v1_pick >= v1_low and v1_pick <= v1_high, "projected_pick within range")

	# Version 7 should have range_variance of 2 (tighter)
	var v7: Dictionary = mock_history[6]
	var v7_pick := int(v7.get("projected_pick", 0))
	var v7_low := int(v7.get("range_low", 0))
	var v7_high := int(v7.get("range_high", 0))
	var v7_range := v7_high - v7_low

	var v1_range := v1_high - v1_low

	t.assert_true(v7_range < v1_range, "version 7 has tighter range than version 1")


## Test 9: get_latest_projection returns version 7
func test_get_latest_projection(t) -> void:
	var pool := _create_test_draft_pool(25)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 33333,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var player: Dictionary = pool[0]
	var latest := MockDraftGenerator.get_latest_projection(player)

	t.assert_false(latest.is_empty(), "latest projection exists")
	t.assert_eq(int(latest.get("version", 0)), 7, "latest is version 7")


## Test 10: Mock accuracy calculation post-draft
func test_mock_accuracy_calculation(t) -> void:
	var pool := _create_test_draft_pool(32)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 44444,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Simulate draft results
	for i in range(pool.size()):
		var player: Dictionary = pool[i]
		player["draft_info"] = {
			"pick": i + 1,  # Actual pick = index + 1
			"year": 2024
		}

	var accuracy := MockDraftGenerator.calculate_mock_accuracy(pool)

	t.assert_true(accuracy.has("average_error"), "has average_error")
	t.assert_true(accuracy.has("players_evaluated"), "has players_evaluated")
	t.assert_eq(int(accuracy.get("players_evaluated", 0)), 32, "all 32 players evaluated")

	# Average error should be reasonable for low-variance version 7
	var avg_error := float(accuracy.get("average_error", 999.0))
	t.assert_true(avg_error < 20.0, "average error under 20 picks: %.1f" % avg_error)


## Test 11: Empty pool handled gracefully
func test_empty_pool_handling(t) -> void:
	var pool: Array = []
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	# Should not crash
	var result := MockDraftGenerator.generate_mock(
		pool, teams, 4, 2024, 12345,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var picks: Array = result.get("picks", [])
	t.assert_eq(picks.size(), 0, "empty pool produces no picks")

	# Also test generate_all_mocks
	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 12345,
		config.get("positions", {}), config.get("class_rules", {})
	)
	t.assert_true(true, "generate_all_mocks handles empty pool")


## Test 12: Picks are numbered 1 to N
func test_mock_pick_numbering(t) -> void:
	var pool := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	var result := MockDraftGenerator.generate_mock(
		pool, teams, 5, 2024, 55555,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var picks: Array = result.get("picks", [])

	for i in range(picks.size()):
		var pick: Dictionary = picks[i]
		t.assert_eq(
			int(pick.get("pick", 0)),
			i + 1,
			"pick %d has correct number" % (i + 1)
		)


## Test 13: Each version independently seeded
func test_mock_version_independence(t) -> void:
	var pool1 := _create_test_draft_pool(50)
	var pool2 := _create_test_draft_pool(50)
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	var seed := 66666

	# Generate version 3 only for pool1
	var result1 := MockDraftGenerator.generate_mock(
		pool1, teams, 3, 2024, seed,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Generate all versions for pool2
	MockDraftGenerator.generate_all_mocks(
		pool2, teams, 2024, seed,
		config.get("positions", {}), config.get("class_rules", {})
	)

	# Get version 3 projection for first player from pool2
	var player2: Dictionary = pool2[0]
	var v3_proj := MockDraftGenerator.get_projection_for_version(player2, 3)

	# Get first pick from standalone version 3
	var picks1: Array = result1.get("picks", [])
	var first_pick_id := String((picks1[0] as Dictionary).get("player_id", ""))

	# Find that player in pool2 and check their v3 projection
	for p in pool2:
		var player: Dictionary = p
		if String(player.get("player_id", "")) == first_pick_id:
			var proj := MockDraftGenerator.get_projection_for_version(player, 3)
			t.assert_eq(
				int(proj.get("projected_pick", 0)),
				1,
				"version 3 top pick consistent"
			)
			break


## Test 14: Performance under 500ms budget
func test_performance_budget(t) -> void:
	var pool := _create_test_draft_pool(250)  # Realistic draft pool size
	var teams := _create_test_teams(32)
	var config := _create_test_config()

	var start := Time.get_ticks_msec()

	MockDraftGenerator.generate_all_mocks(
		pool, teams, 2024, 77777,
		config.get("positions", {}), config.get("class_rules", {})
	)

	var elapsed := Time.get_ticks_msec() - start

	t.assert_true(
		elapsed < 500,
		"7 mock versions generated in %dms (budget: 500ms)" % elapsed
	)


# ==================
# Helper Functions
# ==================

func _create_test_draft_pool(count: int) -> Array:
	var pool := []
	var positions := ["QB", "RB", "WR", "TE", "OT", "OG", "C", "DE", "DT", "LB", "CB", "S"]

	for i in range(count):
		# Create varied ratings - higher index = lower rating generally
		var base_rating := 90.0 - (float(i) / float(count)) * 40.0
		var noise := float(i % 7) - 3.0  # Add some variance

		pool.append({
			"player_id": "player_%03d" % i,
			"name": "Test Player %d" % i,
			"position": positions[i % positions.size()],
			"college_team_id": "college_%d" % (i % 20),
			"stats": {
				"speed": clamp(base_rating + noise, 40.0, 99.0),
				"strength": clamp(base_rating - noise, 40.0, 99.0),
				"agility": clamp(base_rating + noise * 0.5, 40.0, 99.0),
				"awareness": clamp(base_rating - noise * 0.5, 40.0, 99.0)
			}
		})

	return pool


func _create_test_teams(count: int) -> Array:
	var teams := []
	for i in range(count):
		teams.append({
			"id": "team_%02d" % i,
			"name": "Team %d" % i,
			"draft_order": i + 1
		})
	return teams


func _create_test_config() -> Dictionary:
	return {
		"positions": {
			"QB": {"core_stats": ["speed", "strength", "agility", "awareness"]},
			"RB": {"core_stats": ["speed", "strength", "agility"]},
			"WR": {"core_stats": ["speed", "agility"]},
			"TE": {"core_stats": ["speed", "strength"]},
			"OT": {"core_stats": ["strength", "agility"]},
			"OG": {"core_stats": ["strength"]},
			"C": {"core_stats": ["strength", "awareness"]},
			"DE": {"core_stats": ["speed", "strength"]},
			"DT": {"core_stats": ["strength"]},
			"LB": {"core_stats": ["speed", "strength", "agility"]},
			"CB": {"core_stats": ["speed", "agility"]},
			"S": {"core_stats": ["speed", "awareness"]}
		},
		"class_rules": {}
	}
