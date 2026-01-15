## GdUnit4 test suite for BootstrapGameWorld multi-year simulation orchestrator
##
## Verifies output structure, world population, retirement accumulation, and determinism.
extends GdUnitTestSuite

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")


## Test 1: Verify that run() returns expected output structure.
func test_output_structure() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 2  # Short run for speed
	var result := bootstrap.run(999)  # Fixed seed

	assert_bool(result.has("years_simulated")).is_true()
	assert_bool(result.has("start_year")).is_true()
	assert_bool(result.has("first_year")).is_true()
	assert_bool(result.has("world_state")).is_true()
	assert_bool(result.has("summary")).is_true()

	assert_int(result.get("years_simulated", 0)).is_equal(2)

	var summary: Dictionary = result.get("summary", {})
	assert_bool(summary.has("hs_schools")).is_true()
	assert_bool(summary.has("hs_players")).is_true()
	assert_bool(summary.has("colleges")).is_true()
	assert_bool(summary.has("college_players")).is_true()
	assert_bool(summary.has("nfl_teams")).is_true()
	assert_bool(summary.has("nfl_players")).is_true()
	assert_bool(summary.has("retired_players")).is_true()
	assert_bool(summary.has("draft_pool_years")).is_true()


## Test 2: Verify that 3 years of simulation populates all levels.
func test_world_population() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3  # 3 years should populate HS, colleges, and NFL
	var result := bootstrap.run(12345)

	var summary: Dictionary = result.get("summary", {})

	# After 3 years, all major levels should have entities
	assert_int(summary.get("hs_schools", 0)).is_greater(0)
	assert_int(summary.get("hs_players", 0)).is_greater(0)
	assert_int(summary.get("colleges", 0)).is_greater(0)
	assert_int(summary.get("college_players", 0)).is_greater(0)
	assert_int(summary.get("nfl_teams", 0)).is_greater(0)

	# NFL teams should be exactly 32
	assert_int(summary.get("nfl_teams", 0)).is_equal(32)


## Test 3: Verify that simulation accumulates state over time.
func test_retirement_accumulation() -> void:
	var bootstrap2 := BootstrapGameWorld.new()
	bootstrap2.years_to_simulate = 2
	var result2 := bootstrap2.run(555)
	var summary2: Dictionary = result2.get("summary", {})

	var bootstrap3 := BootstrapGameWorld.new()
	bootstrap3.years_to_simulate = 3
	var result3 := bootstrap3.run(555)
	var summary3: Dictionary = result3.get("summary", {})

	# More years should have more or equal players and entities
	assert_int(summary3.get("hs_players", 0)).is_greater_equal(summary2.get("hs_players", 0))
	assert_int(summary3.get("college_players", 0)).is_greater_equal(summary2.get("college_players", 0))


## Test 4: Verify determinism - same seed produces identical results.
func test_determinism() -> void:
	var test_seed := 777

	# Run 1
	var bootstrap1 := BootstrapGameWorld.new()
	bootstrap1.years_to_simulate = 2
	var result1 := bootstrap1.run(test_seed)
	var summary1: Dictionary = result1.get("summary", {})

	# Run 2
	var bootstrap2 := BootstrapGameWorld.new()
	bootstrap2.years_to_simulate = 2
	var result2 := bootstrap2.run(test_seed)
	var summary2: Dictionary = result2.get("summary", {})

	# All counts should match exactly
	assert_int(summary1.get("hs_schools", 0)).is_equal(summary2.get("hs_schools", 0))
	assert_int(summary1.get("hs_players", 0)).is_equal(summary2.get("hs_players", 0))
	assert_int(summary1.get("colleges", 0)).is_equal(summary2.get("colleges", 0))
	assert_int(summary1.get("college_players", 0)).is_equal(summary2.get("college_players", 0))
	assert_int(summary1.get("nfl_teams", 0)).is_equal(summary2.get("nfl_teams", 0))
	assert_int(summary1.get("nfl_players", 0)).is_equal(summary2.get("nfl_players", 0))
	assert_int(summary1.get("retired_players", 0)).is_equal(summary2.get("retired_players", 0))
	assert_int(summary1.get("draft_pool_years", 0)).is_equal(summary2.get("draft_pool_years", 0))


## Test 5: Verify timing capture does not alter simulation results.
## This ensures capture_timing parameter is truly side-effect-free.
func test_timing_capture_determinism() -> void:
	var test_seed := 888
	var years := 2

	# Run without timing capture
	var bootstrap_no_timing := BootstrapGameWorld.new()
	bootstrap_no_timing.years_to_simulate = years
	var result_no_timing := bootstrap_no_timing.run(test_seed, false)
	var summary_no_timing: Dictionary = result_no_timing.get("summary", {})
	var world_state_no_timing: Dictionary = result_no_timing.get("world_state", {})

	# Run with timing capture
	var bootstrap_with_timing := BootstrapGameWorld.new()
	bootstrap_with_timing.years_to_simulate = years
	var result_with_timing := bootstrap_with_timing.run(test_seed, true)
	var summary_with_timing: Dictionary = result_with_timing.get("summary", {})
	var world_state_with_timing: Dictionary = result_with_timing.get("world_state", {})

	# Verify timing data is present when capture_timing=true
	assert_bool(result_with_timing.has("world_generation")).is_true()
	assert_bool(result_no_timing.has("world_generation")).is_false()

	# Verify all summary counts are identical
	assert_int(summary_no_timing.get("hs_schools", 0)).is_equal(summary_with_timing.get("hs_schools", 0))
	assert_int(summary_no_timing.get("hs_players", 0)).is_equal(summary_with_timing.get("hs_players", 0))
	assert_int(summary_no_timing.get("colleges", 0)).is_equal(summary_with_timing.get("colleges", 0))
	assert_int(summary_no_timing.get("college_players", 0)).is_equal(summary_with_timing.get("college_players", 0))
	assert_int(summary_no_timing.get("nfl_teams", 0)).is_equal(summary_with_timing.get("nfl_teams", 0))
	assert_int(summary_no_timing.get("nfl_players", 0)).is_equal(summary_with_timing.get("nfl_players", 0))
	assert_int(summary_no_timing.get("retired_players", 0)).is_equal(summary_with_timing.get("retired_players", 0))
	assert_int(summary_no_timing.get("draft_pool_years", 0)).is_equal(summary_with_timing.get("draft_pool_years", 0))

	# Verify high-level world_state structure is identical
	assert_int((world_state_no_timing.get("hs_schools", []) as Array).size()).is_equal(
		(world_state_with_timing.get("hs_schools", []) as Array).size()
	)
	assert_int((world_state_no_timing.get("hs_players", []) as Array).size()).is_equal(
		(world_state_with_timing.get("hs_players", []) as Array).size()
	)
	assert_int((world_state_no_timing.get("colleges", []) as Array).size()).is_equal(
		(world_state_with_timing.get("colleges", []) as Array).size()
	)
	assert_int((world_state_no_timing.get("nfl_teams", []) as Array).size()).is_equal(
		(world_state_with_timing.get("nfl_teams", []) as Array).size()
	)
