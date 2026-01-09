extends Node
class_name BootstrapWorld

@export var years_back: int = 20

func run() -> Dictionary:
	var main_cfg: Dictionary = Config.get_config("main")
	var positions_cfg: Dictionary = Config.get_config("positions")
	var stats_cfg: Dictionary = Config.get_config("stats")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var base_seed := int(main_cfg.get("random_seed", 0))

	var draft_gen := DraftClassGenerator.new()
	var active_players: Array = []
	var retired_players: Array = []
	var class_results: Array = []

	var first_year := start_year - years_back + 1
	for class_year in range(first_year, start_year + 1):
		var seed_override := base_seed + class_year if base_seed != 0 else 0
		var class_players := draft_gen.generate_for_year(class_year, seed_override)
		var years_to_advance := start_year - class_year
		if years_to_advance > 0:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(seed_override) if seed_override != 0 else randi()
			var progressed := PlayerLifecycle.advance_years(
				class_players,
				years_to_advance,
				positions_cfg,
				main_cfg,
				stats_cfg,
				rng
			)
			class_players = progressed.get("players", []) as Array
			retired_players.append_array(progressed.get("retired", []) as Array)

		active_players.append_array(class_players)
		class_results.append({"year": class_year, "count": class_players.size()})

	return {
		"active_players": active_players,
		"retired_players": retired_players,
		"classes": class_results,
		"current_year": start_year
	}
