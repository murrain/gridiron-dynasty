extends Node
class_name BootstrapWorld

const Config = preload("res://autoloads/Config.gd")
const Rand = preload("res://autoloads/Rand.gd")
const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

@export var years_back: int = 20

var _config_instance: Node = null

func _get_config() -> Node:
	if _config_instance == null:
		_config_instance = Config.new()
	return _config_instance

func run() -> Dictionary:
	var main_cfg: Dictionary = _get_config().get_config("main")
	var positions_cfg: Dictionary = _get_config().get_config("positions")
	var stats_cfg: Dictionary = _get_config().get_config("stats")
	var start_year := int(main_cfg.get("starting_year", 2025))
	var base_seed := int(main_cfg.get("random_seed", 0))

	var draft_gen := DraftClassGenerator.new()
	var active_players: Array = []
	var retired_players: Array = []
	var class_results: Array = []

	# OPTIMIZATION: Bootstrap-Specific Generation (from BACKWARD_CLASS_SIZING.md)
	# Purpose: Reduce bootstrap generation from 40,000 to ~10,288 players (74% reduction)
	# Strategy:
	#   Year 1: Generate full NFL-ready class (~2,688 players for 32 teams × 84 roster spots)
	#   Years 2-20: Generate only replacement needs (~400 players/year)
	# Expected impact: 74% faster bootstrap, 119MB memory savings

	# Check if bootstrap optimization is enabled
	var bootstrap_cfg: Dictionary = main_cfg.get("bootstrap", {}) as Dictionary
	var optimize_bootstrap := bool(bootstrap_cfg.get("optimize_generation", true))

	# Calculate target class sizes based on optimization mode
	var nfl_roster_size := 84  # 53 active + 16 practice squad + 15 IR per team
	var nfl_teams := 32
	var full_nfl_size := nfl_roster_size * nfl_teams  # ~2,688 players
	var replacement_per_year := 400  # Annual turnover (retirements + cuts)

	var first_year := start_year - years_back + 1
	for class_year in range(first_year, start_year + 1):
		var class_seed := _resolve_seed(base_seed, class_year)

		# Determine class size based on bootstrap optimization
		var target_class_size := -1  # -1 = use default from config
		if optimize_bootstrap:
			if class_year == first_year:
				# Year 1: Generate full NFL roster needs
				target_class_size = full_nfl_size
			else:
				# Years 2-20: Generate only replacement needs
				target_class_size = replacement_per_year

		var class_players := draft_gen.generate_for_year(class_year, class_seed, target_class_size)
		var years_to_advance := start_year - class_year
		if years_to_advance > 0:
			var rng := RandomNumberGenerator.new()
			rng.seed = Rand.splitmix64(class_seed ^ 0xB1C4A7)
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

func _resolve_seed(base_seed: int, class_year: int) -> int:
	if base_seed != 0:
		return Rand.splitmix64(base_seed ^ class_year)
	return Rand.splitmix64(class_year)
