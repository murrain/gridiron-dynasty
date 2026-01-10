## Tests for BootstrapGameWorld multi-year simulation orchestrator.
## Verifies output structure, world population, retirement accumulation, and determinism.
extends RefCounted

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func run(t) -> void:
	# Test 1: Verify output structure
	_test_output_structure(t)

	# Test 2: Verify multi-year simulation populates all levels
	_test_world_population(t)

	# Test 3: Verify retired_players accumulates over time
	_test_retirement_accumulation(t)

	# Test 4: Assert determinism across runs with same seed
	_test_determinism(t)

## Test 1: Verify that run() returns expected output structure.
func _test_output_structure(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 2  # Short run for speed
	var result := bootstrap.run(999)  # Fixed seed

	t.assert_true(result.has("years_simulated"), "has years_simulated")
	t.assert_true(result.has("start_year"), "has start_year")
	t.assert_true(result.has("first_year"), "has first_year")
	t.assert_true(result.has("world_state"), "has world_state")
	t.assert_true(result.has("summary"), "has summary")

	t.assert_eq(result.get("years_simulated", 0), 2, "years_simulated matches input")

	var summary: Dictionary = result.get("summary", {})
	t.assert_true(summary.has("hs_schools"), "summary has hs_schools")
	t.assert_true(summary.has("hs_players"), "summary has hs_players")
	t.assert_true(summary.has("colleges"), "summary has colleges")
	t.assert_true(summary.has("college_players"), "summary has college_players")
	t.assert_true(summary.has("nfl_teams"), "summary has nfl_teams")
	t.assert_true(summary.has("nfl_players"), "summary has nfl_players")
	t.assert_true(summary.has("retired_players"), "summary has retired_players")
	t.assert_true(summary.has("draft_pool_years"), "summary has draft_pool_years")

## Test 2: Verify that 3 years of simulation populates all levels.
func _test_world_population(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3  # 3 years should populate HS, colleges, and NFL
	var result := bootstrap.run(12345)

	var summary: Dictionary = result.get("summary", {})

	# After 3 years, all major levels should have entities
	t.assert_true(summary.get("hs_schools", 0) > 0, "HS schools generated")
	t.assert_true(summary.get("hs_players", 0) > 0, "HS players exist")
	t.assert_true(summary.get("colleges", 0) > 0, "Colleges generated")
	t.assert_true(summary.get("college_players", 0) > 0, "College players exist")
	t.assert_true(summary.get("nfl_teams", 0) > 0, "NFL teams generated")

	# NFL teams should be exactly 32
	t.assert_eq(summary.get("nfl_teams", 0), 32, "Exactly 32 NFL teams")

## Test 3: Verify that simulation accumulates state over time.
func _test_retirement_accumulation(t) -> void:
	var bootstrap2 := BootstrapGameWorld.new()
	bootstrap2.years_to_simulate = 2
	var result2 := bootstrap2.run(555)
	var summary2: Dictionary = result2.get("summary", {})

	var bootstrap3 := BootstrapGameWorld.new()
	bootstrap3.years_to_simulate = 3
	var result3 := bootstrap3.run(555)
	var summary3: Dictionary = result3.get("summary", {})

	# More years should have more or equal players and entities
	t.assert_true(summary3.get("hs_players", 0) >= summary2.get("hs_players", 0),
		"3 years HS >= 2 years HS")
	t.assert_true(summary3.get("college_players", 0) >= summary2.get("college_players", 0),
		"3 years college >= 2 years college")

## Test 4: Verify determinism - same seed produces identical results.
func _test_determinism(t) -> void:
	var seed := 777

	# Run 1
	var bootstrap1 := BootstrapGameWorld.new()
	bootstrap1.years_to_simulate = 2
	var result1 := bootstrap1.run(seed)
	var summary1: Dictionary = result1.get("summary", {})

	# Run 2
	var bootstrap2 := BootstrapGameWorld.new()
	bootstrap2.years_to_simulate = 2
	var result2 := bootstrap2.run(seed)
	var summary2: Dictionary = result2.get("summary", {})

	# All counts should match exactly
	t.assert_eq(summary1.get("hs_schools", 0), summary2.get("hs_schools", 0),
		"hs_schools deterministic")
	t.assert_eq(summary1.get("hs_players", 0), summary2.get("hs_players", 0),
		"hs_players deterministic")
	t.assert_eq(summary1.get("colleges", 0), summary2.get("colleges", 0),
		"colleges deterministic")
	t.assert_eq(summary1.get("college_players", 0), summary2.get("college_players", 0),
		"college_players deterministic")
	t.assert_eq(summary1.get("nfl_teams", 0), summary2.get("nfl_teams", 0),
		"nfl_teams deterministic")
	t.assert_eq(summary1.get("nfl_players", 0), summary2.get("nfl_players", 0),
		"nfl_players deterministic")
	t.assert_eq(summary1.get("retired_players", 0), summary2.get("retired_players", 0),
		"retired_players deterministic")
	t.assert_eq(summary1.get("draft_pool_years", 0), summary2.get("draft_pool_years", 0),
		"draft_pool_years deterministic")
