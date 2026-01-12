extends SceneTree

## Simple test to verify draft runs with team quality integration
##
## NOTE: This test is currently disabled because World.gd does not exist.
## TODO: Re-enable this test when World.gd is implemented.

# const World = preload("res://scripts/world/World.gd")
const Rand = preload("res://autoloads/Rand.gd")

func _init() -> void:
	print("=== Draft with Team Quality Test ===")
	print()
	print("NOTE: This test is currently disabled because World.gd does not exist.")
	print("TODO: Re-enable this test when World.gd is implemented.")
	print()
	print("=== Test Skipped ===")
	quit(0)


# The following code is commented out until World.gd exists:

# func _init_original() -> void:
# 	print("=== Draft with Team Quality Test ===")
# 	print()
#
# 	# Load all configs
# 	var configs_dir := "res://configs/sports/american_football/"
# 	var main_cfg: Dictionary = _load_json_config(configs_dir + "main.json")
# 	var positions_cfg: Dictionary = _load_json_config(configs_dir + "positions.json")
# 	var stats_cfg: Dictionary = _load_json_config(configs_dir + "stats.json")
# 	var scouts_cfg: Dictionary = _load_json_config(configs_dir + "scouts.json")
# 	var league_cfg: Dictionary = _load_json_config(configs_dir + "league.json")
#
# 	if main_cfg.is_empty() or positions_cfg.is_empty() or stats_cfg.is_empty():
# 		print("ERROR: Failed to load configs")
# 		quit(1)
# 		return
#
# 	print("✓ Configs loaded")
#
# 	# Create world
# 	var world := World.new()
# 	var seed := 12345
# 	var result: Dictionary = world.bootstrap(seed, main_cfg, positions_cfg, stats_cfg, scouts_cfg, league_cfg)
#
# 	if not result.get("success", false):
# 		print("ERROR: Bootstrap failed: %s" % result.get("error", "unknown"))
# 		quit(1)
# 		return
#
# 	print("✓ World bootstrapped (seed=%d)" % seed)
#
# 	# Verify team quality was generated
# 	var state: Dictionary = world.get_state()
# 	var team_quality: Dictionary = state.get("nfl_scouting_quality", {})
#
# 	if team_quality.is_empty():
# 		print("ERROR: Team quality not generated")
# 		quit(1)
# 		return
#
# 	print("✓ Team quality cached (%d teams)" % team_quality.size())
#
# 	# Show sample team qualities
# 	for team_id in ["BAL", "CLE", "KC"]:
# 		if team_quality.has(team_id):
# 			var q: Dictionary = team_quality[team_id]
# 			print("  %s: tier=%s, skill=%.2f, noise=%.2f" % [
# 				team_id,
# 				q.get("tier", "unknown"),
# 				q.get("skill_modifier", 0.0),
# 				q.get("noise_modifier", 0.0)
# 			])
#
# 	# Simulate to year 8 (first draft)
# 	print()
# 	print("Simulating to year 8 (first draft)...")
# 	while world.current_year < 8:
# 		var sim_result: Dictionary = world.simulate_year()
# 		if not sim_result.get("success", false):
# 			print("ERROR: Simulation failed: %s" % sim_result.get("error", "unknown"))
# 			quit(1)
# 			return
#
# 	print("✓ Reached year 8")
#
# 	# Check draft results
# 	var draft_history: Dictionary = state.get("draft_history", {})
# 	if not draft_history.has(8):
# 		print("ERROR: No draft history for year 8")
# 		quit(1)
# 		return
#
# 	var picks: Array = draft_history[8]
# 	print("✓ Draft executed (%d picks)" % picks.size())
#
# 	# Verify picks look reasonable
# 	if picks.size() < 200:
# 		print("WARNING: Only %d picks (expected ~224)" % picks.size())
#
# 	var first_pick: Dictionary = picks[0] if not picks.is_empty() else {}
# 	var last_pick: Dictionary = picks[-1] if not picks.is_empty() else {}
#
# 	print("  First pick: %s to %s (round %d)" % [
# 		first_pick.get("position", "unknown"),
# 		first_pick.get("team_id", "unknown"),
# 		first_pick.get("round", 0)
# 	])
# 	print("  Last pick: %s to %s (round %d)" % [
# 		last_pick.get("position", "unknown"),
# 		last_pick.get("team_id", "unknown"),
# 		last_pick.get("round", 0)
# 	])
#
# 	print()
# 	print("=== Test Passed ===")
# 	print("Team quality is properly integrated into draft execution")
# 	quit()


func _load_json_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		print("ERROR: Failed to open %s" % path)
		return {}

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		print("ERROR: Failed to parse %s" % path)
		return {}

	return json.data as Dictionary
