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
		var seed := _resolve_seed(base_seed, target_year)
		var players := gen.generate_for_year(target_year, seed)
		var path := gen.save_class(players, target_year)
		results.append({"year": target_year, "count": players.size(), "path": path})

	return results

func _resolve_seed(base_seed: int, target_year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ target_year)
	return Rand.splitmix64(target_year)
