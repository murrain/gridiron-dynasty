extends SceneTree

## Performance Test: 20-Year World Bootstrap with Profiling
##
## Runs a full 20-year simulation with timing capture enabled to measure
## performance impact of all Phase 1 features and identify bottlenecks.

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func _init():
	print("=" .repeat(80))
	print("PERFORMANCE TEST: 20-Year World Bootstrap")
	print("=" .repeat(80))
	print()

	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 20

	var seed := 42  # Fixed seed for reproducibility

	print("Starting 20-year simulation with profiling enabled...")
	print("Seed: %d" % seed)
	print("Years: %d" % bootstrap.years_to_simulate)
	print()

	var start_time := Time.get_ticks_msec()
	var result := bootstrap.run(seed, true)  # capture_timing = true
	var total_time_ms := Time.get_ticks_msec() - start_time

	print()
	print("=".repeat(80))
	print("SIMULATION COMPLETE")
	print("=".repeat(80))
	print()

	# Overall timing
	print("Total Time: %.2f seconds (%.0f ms)" % [total_time_ms / 1000.0, total_time_ms])
	print("Time per Year: %.2f seconds" % [total_time_ms / 1000.0 / 20.0])
	print()

	# Summary statistics
	var summary: Dictionary = result.get("summary", {})
	print("=".repeat(80))
	print("WORLD POPULATION")
	print("=".repeat(80))
	print("High Schools: %d" % summary.get("hs_schools", 0))
	print("HS Players: %d" % summary.get("hs_players", 0))
	print("Colleges: %d" % summary.get("colleges", 0))
	print("College Players: %d" % summary.get("college_players", 0))
	print("NFL Teams: %d" % summary.get("nfl_teams", 0))
	print("NFL Players: %d" % summary.get("nfl_players", 0))
	print("Retired Players: %d" % summary.get("retired_players", 0))
	print("Draft Pool Years: %d" % summary.get("draft_pool_years", 0))
	print()

	# Phase timing breakdown
	if result.has("world_generation"):
		var world_gen: Dictionary = result["world_generation"]
		if world_gen.has("total_phase_timings_ms"):
			_print_simplified_timing(world_gen["total_phase_timings_ms"], bootstrap.years_to_simulate)

	# Performance assessment
	print()
	print("=".repeat(80))
	print("PERFORMANCE ASSESSMENT")
	print("=".repeat(80))

	var target_time_sec := 90.0
	var actual_time_sec := total_time_ms / 1000.0

	if actual_time_sec <= target_time_sec:
		var margin := target_time_sec - actual_time_sec
		print("✓ PASSED: Completed in %.2fs (%.2fs under target)" % [actual_time_sec, margin])
	else:
		var overrun := actual_time_sec - target_time_sec
		print("✗ FAILED: Completed in %.2fs (%.2fs over target)" % [actual_time_sec, overrun])

	print("Target: <%.0f seconds" % target_time_sec)
	print()

	quit(0)

## Print simplified timing breakdown from actual BootstrapGameWorld timing data
func _print_simplified_timing(phase_timings_ms: Dictionary, year_count: int) -> void:
	print("=".repeat(80))
	print("PER-YEAR TIMING BREAKDOWN")
	print("=".repeat(80))
	print()

	# Calculate total
	var total_ms := 0.0
	for value in phase_timings_ms.values():
		total_ms += value

	var avg_ms_per_year := total_ms / year_count

	print("Average per year (across %d years): %.2f ms/year" % [year_count, avg_ms_per_year])
	print()

	# Sort phases by time (descending)
	var sorted_phases := phase_timings_ms.keys()
	sorted_phases.sort_custom(func(a, b): return phase_timings_ms[a] > phase_timings_ms[b])

	for phase_id in sorted_phases:
		var phase_total_ms: float = phase_timings_ms[phase_id]
		var phase_avg_ms: float = phase_total_ms / year_count
		var percentage: float = (phase_total_ms / total_ms * 100.0) if total_ms > 0 else 0.0
		var label: String = String(phase_id).replace("_", " ").capitalize()
		print("  %-25s: %8.2f ms/year  (%5.1f%%)" % [label, phase_avg_ms, percentage])

	print("  " + ("-".repeat(56)))
	print("  %-25s: %8.2f ms/year" % ["Total", avg_ms_per_year])
	print()

## Print phase timing breakdown with percentages
func _print_phase_timing(timing_data: Dictionary, section_name: String) -> void:
	print("=".repeat(80))
	print(section_name.to_upper())
	print("=".repeat(80))

	var total_ms := 0.0
	for key in timing_data.keys():
		if key.ends_with("_ms"):
			var value = timing_data.get(key, 0.0)
			if value is float or value is int:
				total_ms += value

	var phases := [
		{"key": "hs_schools_ms", "label": "HS School Generation"},
		{"key": "hs_players_ms", "label": "HS Player Generation"},
		{"key": "colleges_ms", "label": "College Generation"},
		{"key": "nfl_teams_ms", "label": "NFL Team Generation"},
		{"key": "college_rosters_ms", "label": "College Roster Population"},
		{"key": "nfl_rosters_ms", "label": "NFL Roster Population"}
	]

	for phase in phases:
		var time_ms: float = timing_data.get(phase["key"], 0.0)
		var percentage: float = (time_ms / total_ms * 100.0) if total_ms > 0 else 0.0
		print("  %-30s: %8.2f ms  (%5.1f%%)" % [phase["label"], time_ms, percentage])

	print("  " + ("-".repeat(56)))
	print("  %-30s: %8.2f ms" % ["Total", total_ms])
	print()

## Print per-year timing breakdown
func _print_yearly_timing(year_timings: Array) -> void:
	print("=".repeat(80))
	print("PER-YEAR TIMING BREAKDOWN")
	print("=".repeat(80))

	# Aggregate timings across all years
	var aggregated := {
		"hs_generation_ms": 0.0,
		"college_season_ms": 0.0,
		"nfl_draft_ms": 0.0,
		"nfl_season_ms": 0.0,
		"total_ms": 0.0
	}

	var year_count := year_timings.size()

	for year_data in year_timings:
		var yd: Dictionary = year_data
		aggregated["hs_generation_ms"] += yd.get("hs_generation_ms", 0.0)
		aggregated["college_season_ms"] += yd.get("college_season_ms", 0.0)
		aggregated["nfl_draft_ms"] += yd.get("nfl_draft_ms", 0.0)
		aggregated["nfl_season_ms"] += yd.get("nfl_season_ms", 0.0)
		aggregated["total_ms"] += yd.get("total_ms", 0.0)

	# Print average per year
	print("Average per year (across %d years):" % year_count)
	print()

	var phases := [
		{"key": "hs_generation_ms", "label": "HS Generation"},
		{"key": "college_season_ms", "label": "College Season"},
		{"key": "nfl_draft_ms", "label": "NFL Draft"},
		{"key": "nfl_season_ms", "label": "NFL Season"}
	]

	for phase in phases:
		var phase_key: String = phase["key"]
		var phase_label: String = phase["label"]
		var avg_ms: float = aggregated[phase_key] / year_count
		var percentage: float = (aggregated[phase_key] / aggregated["total_ms"] * 100.0) if aggregated["total_ms"] > 0 else 0.0
		print("  %-20s: %8.2f ms/year  (%5.1f%% of yearly time)" % [phase_label, avg_ms, percentage])

	print("  " + ("-".repeat(56)))
	print("  %-20s: %8.2f ms/year" % ["Total", aggregated["total_ms"] / year_count])
	print()

	# Show detailed phase timing if college/nfl seasons have sub-phases
	_print_phase_details("College Season", year_timings, "college_season_breakdown")
	_print_phase_details("NFL Season", year_timings, "nfl_season_breakdown")

## Print detailed phase breakdown if available
func _print_phase_details(phase_name: String, year_timings: Array, breakdown_key: String) -> void:
	# Check if any year has this breakdown
	var has_breakdown := false
	for year_data in year_timings:
		var yd: Dictionary = year_data
		if yd.has(breakdown_key):
			has_breakdown = true
			break

	if not has_breakdown:
		return

	print("-".repeat(80))
	print("%s Detailed Breakdown:" % phase_name)
	print()

	# Aggregate all sub-phases
	var sub_phases := {}
	var year_count := 0

	for year_data in year_timings:
		var yd: Dictionary = year_data
		if not yd.has(breakdown_key):
			continue

		year_count += 1
		var breakdown: Dictionary = yd[breakdown_key]

		for key in breakdown.keys():
			if not sub_phases.has(key):
				sub_phases[key] = 0.0
			sub_phases[key] += breakdown.get(key, 0.0)

	# Calculate total
	var total := 0.0
	for value in sub_phases.values():
		total += value

	# Print sorted by time (descending)
	var sorted_keys := sub_phases.keys()
	sorted_keys.sort_custom(func(a, b): return sub_phases[a] > sub_phases[b])

	for key in sorted_keys:
		var key_str: String = key
		var key_value: float = sub_phases[key]
		var avg_ms: float = key_value / year_count
		var percentage: float = (key_value / total * 100.0) if total > 0 else 0.0
		var label: String = key_str.replace("_ms", "").replace("_", " ").capitalize()
		print("  %-30s: %8.2f ms/year  (%5.1f%%)" % [label, avg_ms, percentage])

	print()
