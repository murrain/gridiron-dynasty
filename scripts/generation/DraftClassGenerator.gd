extends Node
class_name DraftClassGenerator

const ConfigService = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const DeAger = preload("res://scripts/generation/helpers/DeAger.gd")
const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const RecruitRater = preload("res://scripts/core/rating/RecruitRater.gd")
const Threader = preload("res://scripts/support/threading/Threader.gd")
const ThreadPool = preload("res://autoloads/ThreadPool.gd")

const CLASS_FILE_PATTERN := "res://configs/sports/american_football/CLASS_OF_%d.json"

var main_cfg: Dictionary
var positions_cfg: Dictionary
var stats_cfg: Dictionary
var names_cfg: Dictionary
var scouts_cfg: Dictionary
var combine_tests_cfg: Dictionary
var class_rules: Dictionary

func generate_for_year(target_year: int, seed_override: int = 0, class_size_override: int = -1) -> Array:
	_load_cfg_if_needed()

	var seed := _resolve_seed(target_year, seed_override)

	# Use override if provided, otherwise use config default
	var class_size := class_size_override if class_size_override > 0 else int(class_rules.get("class_size", 2000))
	var gaussian_share := float(class_rules.get("gaussian_share", 0.75))
	var players: Array = _generate_class(class_size, gaussian_share, _step_rng(seed, "generate"))

	_assign_dynamic_freaks(
		players,
		int(class_rules.get("max_freaks_per_class", 5)),
		float(class_rules.get("freak_percentile_min", 0.80)),
		float(class_rules.get("freak_percentile_max", 0.90)),
		_step_rng(seed, "freaks")
	)

	_rate_and_rank(players)
	_copy_potential_to_baseline(players)
	_de_age_players(players, _step_rng(seed, "de_age"))
	_tag_class(players, target_year)

	return players

func save_class(players: Array, target_year: int) -> String:
	var path := CLASS_FILE_PATTERN % target_year
	var gen: PlayerGenerator = PlayerGenerator.new()
	gen.save_to_json(path, players)
	return path

func _load_cfg_if_needed() -> void:
	var config := ConfigService.new()
	if main_cfg.is_empty():
		main_cfg = config.get_config("main")
	if positions_cfg.is_empty():
		positions_cfg = config.get_config("positions")
	if stats_cfg.is_empty():
		stats_cfg = config.get_config("stats")
	if names_cfg.is_empty():
		names_cfg = config.get_config("names")
	if scouts_cfg.is_empty():
		scouts_cfg = config.get_config("scouts")
	if combine_tests_cfg.is_empty():
		combine_tests_cfg = config.get_config("combine_tests")
	if class_rules.is_empty():
		class_rules = main_cfg.get("class_rules", {})

func _generate_class(class_size:int, gaussian_share:float, rng: RandomNumberGenerator) -> Array:
	var gen: PlayerGenerator = PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions_cfg
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = class_rules
	gen.combine_tests = combine_tests_cfg
	gen.combine_tuning = combine_tests_cfg.get("defaults", {})
	return gen.generate_class(class_size, gaussian_share, rng)

func _assign_dynamic_freaks(
	players:Array,
	max_freaks:int,
	pmin:float,
	pmax:float,
	rng: RandomNumberGenerator
) -> void:
	var gen: PlayerGenerator = PlayerGenerator.new()
	gen.positions_data = positions_cfg
	gen.class_rules = class_rules
	gen.assign_dynamic_freaks(players, max_freaks, pmin, pmax, rng)

func _rate_and_rank(players:Array) -> void:
	var rater: RecruitRater = RecruitRater.new()
	rater.rate_and_rank(players, positions_cfg, class_rules)

func _copy_potential_to_baseline(players:Array) -> void:
	var copied: Array = ThreadPool.map(players, func(p):
		if p == null:
			return p
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p.get("stats", {}) as Dictionary).duplicate(true)
		return p,
		Threader.default_threads()
	)
	for i in players.size():
		players[i] = copied[i]

func _de_age_players(players:Array, rng: RandomNumberGenerator) -> void:
	var threads := Threader.default_threads()
	var seeds := _derive_seeds(players.size(), rng, 0x5B9D1BAF)
	var items: Array = []
	items.resize(players.size())
	for i in range(players.size()):
		items[i] = {"player": players[i], "seed": seeds[i]}

	var deaged: Array = ThreadPool.map(items, func(item):
		var rng_local := RandomNumberGenerator.new()
		rng_local.seed = int(item["seed"])
		return DeAger.de_age(item["player"], positions_cfg, main_cfg.get("deage", {}), stats_cfg, rng_local),
		threads
	)
	for i in players.size():
		players[i] = deaged[i]

func _tag_class(players: Array, target_year: int) -> void:
	var tag := "CLASS_OF_%d" % target_year
	for i in players.size():
		var p: Dictionary = players[i]
		p["class_tag"] = tag
		p["draft_year"] = target_year
		players[i] = p

func _resolve_seed(target_year: int, seed_override: int) -> int:
	if seed_override != 0:
		return seed_override
	if main_cfg.has("random_seed"):
		return Rand.splitmix64(int(main_cfg["random_seed"]) ^ target_year)
	return Rand.splitmix64(target_year)

func _step_rng(seed: int, label: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ _fnv1a_64(label))
	return rng

func _fnv1a_64(text: String) -> int:
	var hash: int = -3750763034362895579
	var prime: int = 1099511628211
	for b in text.to_utf8_buffer():
		hash = int(hash ^ b) & -1
		hash = int(hash * prime) & -1
	return hash

func _derive_seeds(count: int, rng: RandomNumberGenerator, salt: int) -> Array:
	var seeds: Array = []
	seeds.resize(count)
	for i in count:
		seeds[i] = Rand.splitmix64(int(rng.randi()) ^ int(i * salt))
	return seeds
