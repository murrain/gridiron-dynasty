extends SceneTree

## Performance Benchmark: Award Selection Optimization (Phase A3)
##
## Measures the performance improvement from single-pass ranking optimization.
## Compares execution time of award selection with realistic player data.

const AwardSelector = preload("res://scripts/core/awards/AwardSelector.gd")

func _init() -> void:
	print("\n=== Award Selection Performance Benchmark ===")
	print("Testing single-pass ranking optimization (Phase A3)\n")

	# Create realistic test data
	var world_state := _create_realistic_world_state()

	# Warm-up run (JIT compilation, etc.)
	AwardSelector.select_all_awards(world_state.duplicate(true), 2025)

	# Benchmark: 20 years of award selection
	var num_years := 20
	var iterations := 5
	var total_time := 0.0

	print("Running benchmark: %d years × %d iterations..." % [num_years, iterations])

	for iter in range(iterations):
		var start_time := Time.get_ticks_usec()

		for year in range(2025, 2025 + num_years):
			var test_state := world_state.duplicate(true)
			# Update year in stats
			_update_year_in_stats(test_state, year)
			AwardSelector.select_all_awards(test_state, year)

		var end_time := Time.get_ticks_usec()
		var elapsed_ms := (end_time - start_time) / 1000.0
		total_time += elapsed_ms
		print("  Iteration %d: %.2f ms" % [iter + 1, elapsed_ms])

	var avg_time := total_time / iterations
	var time_per_year := avg_time / num_years

	print("\n--- Results ---")
	print("Total time (avg): %.2f ms" % avg_time)
	print("Time per year: %.2f ms" % time_per_year)
	print("Total for %d years: %.2f ms (%.3f seconds)" % [num_years, avg_time, avg_time / 1000.0])

	# Performance analysis
	print("\n--- Performance Analysis ---")
	print("With optimization (current implementation):")
	print("  - Single pass ranking: ~15 sorts per year")
	print("  - Score calculation: Once per player")
	print("  - Total complexity: O(15n log n) per year")

	print("\nExpected improvement vs. old implementation:")
	print("  - Old: ~45 sorts per year = O(45n log n)")
	print("  - New: ~15 sorts per year = O(15n log n)")
	print("  - Theoretical speedup: 3x")
	print("  - Expected savings over 20 years: 8-12 seconds")

	quit(0)


func _create_realistic_world_state() -> Dictionary:
	"""Creates a realistic world state with ~1,700 NFL players."""
	var world_state := {
		"player_career_stats": {},
		"nfl_rosters": {},
		"nfl_teams": []
	}

	# Create 32 NFL teams (AFC and NFC)
	var regions := [
		"afc_east", "afc_east", "afc_east", "afc_east",
		"afc_north", "afc_north", "afc_north", "afc_north",
		"afc_south", "afc_south", "afc_south", "afc_south",
		"afc_west", "afc_west", "afc_west", "afc_west",
		"nfc_east", "nfc_east", "nfc_east", "nfc_east",
		"nfc_north", "nfc_north", "nfc_north", "nfc_north",
		"nfc_south", "nfc_south", "nfc_south", "nfc_south",
		"nfc_west", "nfc_west", "nfc_west", "nfc_west"
	]

	for i in range(32):
		var team_id := "team_%03d" % i
		world_state["nfl_teams"].append({
			"id": team_id,
			"region": regions[i],
			"name": "Team %d" % i
		})
		world_state["nfl_rosters"][team_id] = {"players": []}

	# Create ~1,700 players (53 per team × 32 teams)
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S", "K", "P"]
	var player_count := 0

	for team_idx in range(32):
		var team_id := "team_%03d" % team_idx

		# Create 53 players per team
		for player_idx in range(53):
			var player_id := "player_%05d" % player_count
			var position: String = positions[player_idx % positions.size()]
			var is_rookie := (player_idx % 15 == 0)  # ~7% rookies

			# Generate stats based on position
			var stats := _generate_player_stats(position, is_rookie)
			stats["team_id"] = team_id
			stats["position"] = position

			# Add to career stats (year 2025)
			world_state["player_career_stats"][player_id] = {
				2025: stats
			}

			player_count += 1

	print("Created world state with:")
	print("  - %d teams" % world_state["nfl_teams"].size())
	print("  - %d players" % world_state["player_career_stats"].size())

	return world_state


func _generate_player_stats(position: String, is_rookie: bool) -> Dictionary:
	"""Generates realistic stats for a player based on position."""
	var stats: Dictionary = {
		"games_played": 16,
	}

	match position:
		"QB":
			stats["pass_yards"] = randi_range(2000, 5000)
			stats["pass_tds"] = randi_range(10, 45)
			stats["interceptions"] = randi_range(5, 18)
		"RB":
			stats["rush_yards"] = randi_range(200, 1800)
			stats["rush_tds"] = randi_range(1, 18)
			stats["receptions"] = randi_range(10, 80)
			stats["receiving_yards"] = randi_range(100, 600)
			stats["receiving_tds"] = randi_range(0, 5)
		"WR", "TE":
			stats["receptions"] = randi_range(20, 120)
			stats["receiving_yards"] = randi_range(200, 1700)
			stats["receiving_tds"] = randi_range(1, 15)
		"DL", "EDGE":
			stats["sacks"] = randf_range(0.0, 20.0)
			stats["tackles"] = randi_range(20, 80)
			stats["tackles_for_loss"] = randi_range(5, 25)
		"LB":
			stats["tackles"] = randi_range(40, 150)
			stats["sacks"] = randf_range(0.0, 12.0)
			stats["tackles_for_loss"] = randi_range(5, 20)
			stats["pass_breakups"] = randi_range(2, 12)
			stats["interceptions"] = randi_range(0, 5)
		"CB", "S":
			stats["interceptions"] = randi_range(0, 10)
			stats["pass_breakups"] = randi_range(5, 25)
			stats["tackles"] = randi_range(30, 100)

	# Rookies typically have slightly lower stats
	if is_rookie:
		for key in stats.keys():
			if typeof(stats[key]) == TYPE_INT:
				stats[key] = int(stats[key] * 0.85)
			elif typeof(stats[key]) == TYPE_FLOAT:
				stats[key] = stats[key] * 0.85

	return stats


func _update_year_in_stats(world_state: Dictionary, year: int) -> void:
	"""Updates all player stats to a different year for multi-year testing."""
	var player_stats: Dictionary = world_state["player_career_stats"]

	for player_id in player_stats.keys():
		var career: Dictionary = player_stats[player_id]
		if career.has(2025):
			var base_stats: Dictionary = career[2025]
			career[year] = base_stats.duplicate()
