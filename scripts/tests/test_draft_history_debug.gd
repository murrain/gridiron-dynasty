extends RefCounted

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Debug test to check draft history creation

func run(t) -> void:
	var config := ConfigService.new()
	var league_cfg := config.get_config("world/league")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var scouts_cfg := config.get_config("scouts")
	var main_cfg := config.get_config("main")

	var world_state := _make_world_state_with_draft_pool(300)
	print("Created world state with:")
	print("  nfl_teams: ", world_state["nfl_teams"].size())
	print("  draft_pool[2025]: ", world_state["draft_pool"][2025].size())

	var draft := NflDraft.new()
	var result := draft.run(world_state, 2025, 12345, league_cfg, positions_cfg, stats_cfg, scouts_cfg, main_cfg)

	print("Draft result:")
	print("  picks_count: ", result.get("picks_count", 0))
	print("  undrafted_count: ", result.get("undrafted_count", 0))

	print("World state after draft:")
	print("  has draft_history: ", world_state.has("draft_history"))
	if world_state.has("draft_history"):
		var draft_history: Dictionary = world_state["draft_history"]
		print("  draft_history keys: ", draft_history.keys())
		if draft_history.has(2025):
			var picks_2025: Array = draft_history[2025]
			print("  draft_history[2025] size: ", picks_2025.size())
			if picks_2025.size() > 0:
				print("  First pick: ", JSON.stringify(picks_2025[0], "  "))

func _make_world_state_with_draft_pool(pool_size: int) -> Dictionary:
	# Create NFL teams
	var teams: Array = []
	for i in range(32):
		teams.append({
			"id": "nfl_%03d" % (i + 1),
			"name": "Team %03d" % (i + 1),
			"region": "afc_east",
			"cap_space": 200.0,
			"roster": [],
			"draft_order": i + 1
		})

	# Create draft pool with deterministic ratings
	var draft_pool: Array = []
	var positions: Array[String] = ["QB", "RB", "WR", "TE", "OL", "DL", "EDGE", "LB", "CB", "S"]
	var pool_rng := RandomNumberGenerator.new()
	pool_rng.seed = 55555
	for i in range(pool_size):
		var pos: String = positions[i % positions.size()]
		draft_pool.append(_make_draft_player("dp_%04d" % (i + 1), pos, 70.0 + pool_rng.randf() * 20.0))

	return {
		"nfl_teams": teams,
		"nfl_rosters": {},
		"draft_pool": {2025: draft_pool}
	}

func _make_draft_player(player_id: String, pos: String, rating: float) -> Dictionary:
	var college_num: int = (hash(player_id) % 130) + 1
	return {
		"player_id": player_id,
		"name": player_id,
		"position": pos,
		"age": 22,
		"draft_eligible": true,
		"draft_year": 2025,
		"college_team_id": "college_%03d" % college_num,
		"stats": {"speed": rating, "acceleration": rating - 5.0, "agility": rating - 3.0},
		"potential": {"speed": rating + 5.0, "acceleration": rating, "agility": rating + 2.0},
		"composite_score": rating
	}
