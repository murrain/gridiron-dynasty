extends Node
class_name DraftClassGenerator

const CLASS_FILE_PATTERN := "res://configs/sports/american_football/CLASS_OF_%d.json"

var main_cfg: Dictionary
var positions_cfg: Dictionary
var stats_cfg: Dictionary
var names_cfg: Dictionary
var scouts_cfg: Dictionary
var combine_tests_cfg: Dictionary
var class_rules: Dictionary

func generate_for_year(target_year: int, seed_override: int = 0) -> Array:
	_load_cfg_if_needed()

	if seed_override != 0:
		seed(seed_override)
	elif main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))
	else:
		randomize()

	var class_size := int(class_rules.get("class_size", 2000))
	var gaussian_share := float(class_rules.get("gaussian_share", 0.75))
	var players: Array = _generate_class(class_size, gaussian_share)

	_assign_dynamic_freaks(
		players,
		int(class_rules.get("max_freaks_per_class", 5)),
		float(class_rules.get("freak_percentile_min", 0.80)),
		float(class_rules.get("freak_percentile_max", 0.90))
	)

	_rate_and_rank(players)
	_copy_potential_to_baseline(players)
	_de_age_players(players)
	_tag_class(players, target_year)

	return players

func save_class(players: Array, target_year: int) -> String:
	var path := CLASS_FILE_PATTERN % target_year
	var gen := PlayerGenerator.new()
	gen.save_to_json(path, players)
	return path

func _load_cfg_if_needed() -> void:
	if main_cfg.is_empty():
		main_cfg = Config.get_config("main")
	if positions_cfg.is_empty():
		positions_cfg = Config.get_config("positions")
	if stats_cfg.is_empty():
		stats_cfg = Config.get_config("stats")
	if names_cfg.is_empty():
		names_cfg = Config.get_config("names")
	if scouts_cfg.is_empty():
		scouts_cfg = Config.get_config("scouts")
	if combine_tests_cfg.is_empty():
		combine_tests_cfg = Config.get_config("combine_tests")
	if class_rules.is_empty():
		class_rules = main_cfg.get("class_rules", {})

func _generate_class(class_size:int, gaussian_share:float) -> Array:
	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions_cfg
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = class_rules
	gen.combine_tests = combine_tests_cfg
	gen.combine_tuning = combine_tests_cfg.get("defaults", {})
	return gen.generate_class(class_size, gaussian_share)

func _assign_dynamic_freaks(players:Array, max_freaks:int, pmin:float, pmax:float) -> void:
	var gen := PlayerGenerator.new()
	gen.positions_data = positions_cfg
	gen.class_rules = class_rules
	gen.assign_dynamic_freaks(players, max_freaks, pmin, pmax)

func _rate_and_rank(players:Array) -> void:
	var rater := RecruitRater.new()
	rater.rate_and_rank(players, positions_cfg, class_rules)

func _copy_potential_to_baseline(players:Array) -> void:
	var copied := ThreadPool.map(players, func(p):
		if p == null:
			return p
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p.get("stats", {}) as Dictionary).duplicate(true)
		return p
	, App.threads_count())
	for i in players.size():
		players[i] = copied[i]

func _de_age_players(players:Array) -> void:
	var threads := App.threads_count()
	var deaged := ThreadPool.map(players, func(p):
		return DeAger.de_age(p, positions_cfg, main_cfg.get("deage", {}), stats_cfg)
	, threads)
	for i in players.size():
		players[i] = deaged[i]

func _tag_class(players: Array, target_year: int) -> void:
	var tag := "CLASS_OF_%d" % target_year
	for i in players.size():
		var p: Dictionary = players[i]
		p["class_tag"] = tag
		p["draft_year"] = target_year
		players[i] = p
