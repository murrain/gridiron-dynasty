extends SceneTree
## Standalone test to verify timing capture does not alter simulation results.
##
## Usage:
##   godot --headless -s res://scripts/tests/verify_timing_capture.gd

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func _init() -> void:
	print("=".repeat(80))
	print("TIMING CAPTURE DETERMINISM TEST")
	print("=".repeat(80))
	print("")

	var seed := 888
	var years := 2

	print("Running bootstrap WITHOUT timing capture...")
	var bootstrap_no_timing := BootstrapGameWorld.new()
	bootstrap_no_timing.years_to_simulate = years
	var result_no_timing := bootstrap_no_timing.run(seed, false)
	var summary_no_timing: Dictionary = result_no_timing.get("summary", {})

	print("Running bootstrap WITH timing capture...")
	var bootstrap_with_timing := BootstrapGameWorld.new()
	bootstrap_with_timing.years_to_simulate = years
	var result_with_timing := bootstrap_with_timing.run(seed, true)
	var summary_with_timing: Dictionary = result_with_timing.get("summary", {})

	print("")
	print("Verification Results:")
	print("-".repeat(80))

	# Check timing field presence
	var timing_present := result_with_timing.has("world_generation")
	var timing_absent := not result_no_timing.has("world_generation")
	print("  [%s] Timing field present when capture_timing=true" % ("PASS" if timing_present else "FAIL"))
	print("  [%s] Timing field absent when capture_timing=false" % ("PASS" if timing_absent else "FAIL"))

	# Compare summary counts
	var all_match := true
	var checks := [
		"hs_schools",
		"hs_players",
		"colleges",
		"college_players",
		"nfl_teams",
		"nfl_players",
		"retired_players",
		"draft_pool_years"
	]

	for key in checks:
		var no_timing: int = int(summary_no_timing.get(key, 0))
		var with_timing: int = int(summary_with_timing.get(key, 0))
		var is_match: bool = (no_timing == with_timing)
		all_match = all_match and is_match
		var status := "PASS" if is_match else "FAIL"
		print("  [%s] %s: %d vs %d" % [status, key, no_timing, with_timing])

	# Display timing data if present
	if timing_present:
		print("")
		print("Captured Timing Data:")
		print("-".repeat(80))
		var world_gen: Dictionary = result_with_timing.get("world_generation", {})
		var phase_timings_ms: Dictionary = world_gen.get("total_phase_timings_ms", {})

		# Sort phases by time
		var phases: Array = []
		for phase_id in phase_timings_ms.keys():
			phases.append({"id": phase_id, "ms": phase_timings_ms[phase_id]})
		phases.sort_custom(func(a, b): return a["ms"] > b["ms"])

		for phase_data in phases:
			var phase_dict: Dictionary = phase_data
			var phase_id: String = phase_dict["id"]
			var ms: float = phase_dict["ms"]
			print("  %-30s %.2f ms" % [phase_id + ":", ms])

	print("")
	print("=".repeat(80))

	if all_match and timing_present and timing_absent:
		print("RESULT: ALL TESTS PASSED")
		print("Timing capture does not alter simulation results!")
		quit(0)
	else:
		print("RESULT: SOME TESTS FAILED")
		print("Timing capture may be altering simulation results!")
		quit(1)
