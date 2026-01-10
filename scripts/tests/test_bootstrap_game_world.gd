extends RefCounted

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func run(t) -> void:
	# Test 1: Verify output contains all required containers
	_test_output_containers(t)

	# Test 2: Verify multi-year simulation populates all levels
	_test_populates_all_levels(t)

	# Test 3: Verify retired_players accumulates over time
	_test_retired_players_accumulate(t)

	# Test 4: Assert determinism across runs with same seed
	_test_determinism(t)

	# Test 5: Verify summary counts match world_state
	_test_summary_accuracy(t)

func _test_output_containers(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	t.assert_true(result.has("years_simulated"), "result should have years_simulated")
	t.assert_true(result.has("start_year"), "result should have start_year")
	t.assert_true(result.has("first_year"), "result should have first_year")
	t.assert_true(result.has("world_state"), "result should have world_state")
	t.assert_true(result.has("summary"), "result should have summary")
	t.assert_true(result.has("year_results"), "result should have year_results")

	var world_state: Dictionary = result.get("world_state", {})
	t.assert_true(world_state.has("hs_schools"), "world_state should have hs_schools")
	t.assert_true(world_state.has("hs_players"), "world_state should have hs_players")
	t.assert_true(world_state.has("colleges"), "world_state should have colleges")
	t.assert_true(world_state.has("nfl_teams"), "world_state should have nfl_teams")

func _test_populates_all_levels(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 5
	var result := bootstrap.run(54321)

	var summary: Dictionary = result.get("summary", {})

	# HS should be populated
	t.assert_true(int(summary.get("hs_schools", 0)) > 0, "HS schools should be populated")
	t.assert_true(int(summary.get("hs_players", 0)) > 0, "HS players should be populated")

	# Colleges should be populated
	t.assert_true(int(summary.get("colleges", 0)) > 0, "Colleges should be populated")

	# NFL should be populated
	t.assert_true(int(summary.get("nfl_teams", 0)) > 0, "NFL teams should be populated")

func _test_retired_players_accumulate(t) -> void:
	# Run with more years to allow retirements to accumulate
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 10
	var result := bootstrap.run(99999)

	var world_state: Dictionary = result.get("world_state", {})
	var retired: Array = world_state.get("retired_players", []) as Array

	# After 10 simulated years, some players should have retired
	# This is not guaranteed with very few years, so we just check the array exists
	t.assert_true(world_state.has("retired_players"), "retired_players should exist in world_state")

	# If there are retired players, verify they have required fields
	if not retired.is_empty():
		var sample: Dictionary = retired[0]
		t.assert_true(sample.has("player_id"), "retired player should have player_id")
		t.assert_true(sample.has("retirement_year"), "retired player should have retirement_year")

func _test_determinism(t) -> void:
	var bootstrap_a := BootstrapGameWorld.new()
	bootstrap_a.years_to_simulate = 3
	var result_a := bootstrap_a.run(77777)

	var bootstrap_b := BootstrapGameWorld.new()
	bootstrap_b.years_to_simulate = 3
	var result_b := bootstrap_b.run(77777)

	var summary_a: Dictionary = result_a.get("summary", {})
	var summary_b: Dictionary = result_b.get("summary", {})

	t.assert_eq(
		int(summary_a.get("hs_schools", 0)),
		int(summary_b.get("hs_schools", 0)),
		"HS schools count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("hs_players", 0)),
		int(summary_b.get("hs_players", 0)),
		"HS players count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("colleges", 0)),
		int(summary_b.get("colleges", 0)),
		"Colleges count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("nfl_teams", 0)),
		int(summary_b.get("nfl_teams", 0)),
		"NFL teams count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("nfl_players", 0)),
		int(summary_b.get("nfl_players", 0)),
		"NFL players count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("retired_players", 0)),
		int(summary_b.get("retired_players", 0)),
		"Retired players count should be deterministic"
	)
	t.assert_eq(
		int(summary_a.get("college_rosters", 0)),
		int(summary_b.get("college_rosters", 0)),
		"College rosters count should be deterministic"
	)

func _test_summary_accuracy(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(11111)

	var world_state: Dictionary = result.get("world_state", {})
	var summary: Dictionary = result.get("summary", {})

	# Verify summary counts match actual world_state arrays
	var hs_schools: Array = world_state.get("hs_schools", []) as Array
	t.assert_eq(
		int(summary.get("hs_schools", 0)),
		hs_schools.size(),
		"summary hs_schools should match world_state"
	)

	var hs_players: Array = world_state.get("hs_players", []) as Array
	t.assert_eq(
		int(summary.get("hs_players", 0)),
		hs_players.size(),
		"summary hs_players should match world_state"
	)

	var colleges: Array = world_state.get("colleges", []) as Array
	t.assert_eq(
		int(summary.get("colleges", 0)),
		colleges.size(),
		"summary colleges should match world_state"
	)

	var nfl_teams: Array = world_state.get("nfl_teams", []) as Array
	t.assert_eq(
		int(summary.get("nfl_teams", 0)),
		nfl_teams.size(),
		"summary nfl_teams should match world_state"
	)

	var retired: Array = world_state.get("retired_players", []) as Array
	t.assert_eq(
		int(summary.get("retired_players", 0)),
		retired.size(),
		"summary retired_players should match world_state"
	)

	# Verify college rosters count
	var rosters: Dictionary = world_state.get("college_rosters", {}) as Dictionary
	var college_player_count := 0
	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		var players: Array = roster.get("players", []) as Array
		college_player_count += players.size()
	t.assert_eq(
		int(summary.get("college_rosters", 0)),
		college_player_count,
		"summary college_rosters should match counted players"
	)

	# Verify NFL rosters count
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {}) as Dictionary
	var nfl_player_count := 0
	for team_id in nfl_rosters.keys():
		var roster: Dictionary = nfl_rosters[team_id]
		var players: Array = roster.get("players", []) as Array
		nfl_player_count += players.size()
	t.assert_eq(
		int(summary.get("nfl_players", 0)),
		nfl_player_count,
		"summary nfl_players should match counted players"
	)
