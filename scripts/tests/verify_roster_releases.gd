extends SceneTree

## Verification that roster releases execute correctly in cap crunch scenarios

const RosterManagement = preload("res://scripts/world/RosterManagement.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("ROSTER RELEASE EXECUTION VERIFICATION")
	print("=".repeat(80))

	# Load configuration
	var cfg_path := "res://configs/sports/american_football/main.json"
	var cfg_file := FileAccess.open(cfg_path, FileAccess.READ)
	if not cfg_file:
		push_error("Cannot open config file: " + cfg_path)
		quit(1)
		return

	var main_cfg: Dictionary = JSON.parse_string(cfg_file.get_as_text())
	cfg_file.close()

	# Create test world state with CAP CRUNCH (high cap usage)
	print("\n[CREATING CAP CRUNCH SCENARIO]")
	var players: Array = []

	# Add 50 players with expensive contracts to create cap pressure
	for i in range(50):
		var age: int = 26 + (i % 10)  # Ages 26-35
		var eval_score: float = 60.0 + (i % 30)  # Ratings 60-90
		var is_overpaid: bool = (i % 3) == 0  # Every 3rd player is overpaid

		var annual_value: float = 0.0
		if is_overpaid:
			# Overpaid: earning way more than value
			annual_value = 15.0 + randf() * 10.0  # $15-25M
		else:
			# Fair contracts
			annual_value = 3.0 + randf() * 5.0  # $3-8M

		players.append({
			"player_id": "p%d" % i,
			"position": ["QB", "RB", "WR", "TE", "OL"][i % 5],
			"age": age,
			"eval_score": eval_score,
			"draft_year": 2010 + (i / 5),
			"contract": {
				"annual_value": annual_value,
				"signed_year": 2015 + (i % 8),
				"years_remaining": 1 + (i % 4),
				"years_total": 4
			}
		})

	var total_cap_used: float = 0.0
	for player in players:
		var p: Dictionary = player
		total_cap_used += p["contract"]["annual_value"]

	print("  Created roster with 50 players")
	print("  Total cap used: $%.2fM" % total_cap_used)
	print("  Cap limit: $200.0M")
	print("  Cap space available: $%.2fM" % (200.0 - total_cap_used))
	print("  Target FA budget: $30-50M")

	var needs_releases: bool = (200.0 - total_cap_used) < 50.0
	print("  %s" % ("✓ Team needs releases" if needs_releases else "✗ Team has enough space"))

	var world_state: Dictionary = {
		"nfl_teams": [
			{"id": "team_001", "name": "Test Team"}
		],
		"nfl_rosters": {
			"team_001": {
				"players": players
			}
		},
		"league": {
			"cap_limit": 200.0
		},
		"free_agents": {},
		"player_releases": {}
	}

	# Run roster management
	print("\n[RUNNING ROSTER MANAGEMENT]")
	var result: Dictionary = RosterManagement.run(
		world_state,
		2024,
		12345,  # seed
		main_cfg
	)

	print("\n[RESULTS]")
	print("  Teams processed: %d" % result.get("teams_processed", 0))
	print("  Total releases: %d" % result.get("total_releases", 0))
	print("  Cap saved: $%.2fM" % result.get("total_cap_saved", 0.0))

	var releases_by_team: Dictionary = result.get("releases_by_team", {})
	if releases_by_team.has("team_001"):
		var num_releases: int = releases_by_team["team_001"]
		print("  ✓ SUCCESS: %d players released" % num_releases)

		# Check released players were moved to FA pool
		var fa_pool: Dictionary = world_state.get("free_agents", {})
		var fa_2024: Array = fa_pool.get(2024, [])
		print("  ✓ %d players added to free agent pool" % fa_2024.size())

	else:
		print("  ✗ FAILURE: No releases occurred")
		print("  This suggests the system isn't executing releases even when needed")

	# Verify roster size decreased
	var roster_after: Array = world_state["nfl_rosters"]["team_001"]["players"]
	var roster_size_before: int = 50
	var roster_size_after: int = roster_after.size()
	print("\n[ROSTER SIZE]")
	print("  Before: %d players" % roster_size_before)
	print("  After: %d players" % roster_size_after)
	print("  Released: %d players" % (roster_size_before - roster_size_after))

	if roster_size_after < roster_size_before:
		print("  ✓ Roster size decreased (releases executed)")
	else:
		print("  ✗ Roster size unchanged (releases may not have executed)")

	# Calculate cap space after releases
	var cap_used_after: float = 0.0
	for player in roster_after:
		var p: Dictionary = player
		cap_used_after += p["contract"]["annual_value"]

	var cap_space_after: float = 200.0 - cap_used_after
	print("\n[CAP SPACE]")
	print("  Before releases: $%.2fM" % (200.0 - total_cap_used))
	print("  After releases: $%.2fM" % cap_space_after)
	print("  Cap freed: $%.2fM" % (cap_space_after - (200.0 - total_cap_used)))

	if cap_space_after > (200.0 - total_cap_used):
		print("  ✓ Cap space increased (releases freed money)")
	else:
		print("  ✗ Cap space unchanged")

	print("\n" + "=".repeat(80))
	if result.get("total_releases", 0) > 0:
		print("✓ VERIFICATION SUCCESSFUL - Releases are working!")
	else:
		print("✗ VERIFICATION FAILED - No releases occurred")
	print("=".repeat(80) + "\n")

	quit()
