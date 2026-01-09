extends Node
class_name GenerateFutureDraftClasses

@export var years_ahead: int = 4

func run() -> Array:
	var main_cfg: Dictionary = Config.get_config("main")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var offset := int(main_cfg.get("draft_class_year_offset", 8))
	var base_seed := int(main_cfg.get("random_seed", 0))

	var gen := DraftClassGenerator.new()
	var results: Array = []
	for i in range(years_ahead):
		var target_year := start_year + offset + i
		var seed_override := base_seed + target_year if base_seed != 0 else 0
		var players := gen.generate_for_year(target_year, seed_override)
		var path := gen.save_class(players, target_year)
		results.append({"year": target_year, "count": players.size(), "path": path})

	return results
