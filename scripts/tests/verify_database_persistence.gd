extends SceneTree
## Quick verification script for DatabasePersistence save/load functionality

const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")
const DatabasePersistence = preload("res://scripts/persistence/DatabasePersistence.gd")

func _init() -> void:
	print("=== DatabasePersistence Verification ===\n")

	# Load a small snapshot
	print("Loading 5-year snapshot...")
	var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 0, 0x12345)

	if world_state.is_empty():
		print("ERROR: Failed to load snapshot")
		quit(1)
		return

	var players: Array = world_state.get("nfl_players", [])
	var teams: Array = world_state.get("nfl_teams", [])
	print("  Players: %d" % players.size())
	print("  Teams: %d" % teams.size())

	# Save to database
	print("\nSaving to database...")
	var db_persistence := DatabasePersistence.new()
	var save_result := db_persistence.save_world_state(world_state, "test_save")

	if not save_result:
		print("ERROR: Failed to save world state")
		quit(1)
		return

	print("  Save successful!")

	# Load from database
	print("\nLoading from database...")
	var loaded_state := db_persistence.load_world_state("test_save")

	if loaded_state.is_empty():
		print("ERROR: Failed to load world state")
		quit(1)
		return

	var loaded_players: Array = loaded_state.get("nfl_players", [])
	var loaded_teams: Array = loaded_state.get("nfl_teams", [])
	print("  Loaded Players: %d" % loaded_players.size())
	print("  Loaded Teams: %d" % loaded_teams.size())

	# Verify counts match
	if players.size() != loaded_players.size():
		print("ERROR: Player count mismatch! Original: %d, Loaded: %d" % [players.size(), loaded_players.size()])
		quit(1)
		return

	if teams.size() != loaded_teams.size():
		print("ERROR: Team count mismatch! Original: %d, Loaded: %d" % [teams.size(), loaded_teams.size()])
		quit(1)
		return

	# Spot check: verify first player has same basic data
	if players.size() > 0 and loaded_players.size() > 0:
		var orig_p: Dictionary = players[0]
		var load_p: Dictionary = loaded_players[0]

		if orig_p.get("id") != load_p.get("id"):
			print("ERROR: First player ID mismatch! Original: %s, Loaded: %s" % [orig_p.get("id"), load_p.get("id")])
			quit(1)
			return

		print("\n  Spot check first player:")
		print("    ID: %s" % orig_p.get("id"))
		print("    Name: %s %s" % [orig_p.get("first_name"), orig_p.get("last_name")])
		print("    Position: %s" % orig_p.get("position"))
		print("    Age: %d" % orig_p.get("age"))
		print("    ✓ Basic data matches")

	print("\n=== All Verifications PASSED ===")
	quit(0)
