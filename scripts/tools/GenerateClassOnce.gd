extends Node
# Optional: run in editor via the "play scene" button
# @tool

func run() -> void:
	# 1) Load configs
	var loader := ConfigLoader.new()
	var main_cfg: Dictionary = loader.load_main()                  # res://configs/sports/american_football/main.json
	var positions: Dictionary = loader.load_positions()            # res://configs/sports/american_football/positions.json
	var stats_cfg: Dictionary = loader.load_stats()                # res://configs/sports/american_football/stats.json
	var names_cfg: Dictionary = loader.load_names()                # res://configs/sports/american_football/names.json

	# 2) Create & wire the generator
	var gen := PlayerGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_data = positions
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.class_rules = main_cfg.get("class_rules", {})

	# Optional: seed RNG if present
	if main_cfg.has("random_seed"):
		seed(int(main_cfg["random_seed"]))
	else:
		randomize()

	# 3) Pull knobs from class rules
	var class_size: int = int(gen.class_rules.get("class_size", 2000))
	var gaussian_share: float = float(gen.class_rules.get("gaussian_share", 0.75))
	var max_freaks: int = int(gen.class_rules.get("max_freaks_per_class", 5))
	var freak_min: float = float(gen.class_rules.get("freak_percentile_min", 0.80))
	var freak_max: float = float(gen.class_rules.get("freak_percentile_max", 0.90))

	# 4) Generate the finished products (quota → gauss → chaos)
	var players: Array = gen.generate_class(class_size, gaussian_share)

	# 5) Inject dynamic freaks
	gen.assign_dynamic_freaks(players, max_freaks, freak_min, freak_max)

	# 6) Copy finished → potential, then de-age to HS stats
	for p in players:
		if not p.has("potential") or (p["potential"] as Dictionary).is_empty():
			p["potential"] = (p["stats"] as Dictionary).duplicate(true)
	gen.de_age_players(players, gen.positions_data, main_cfg.get("deage", {}))

	# 7) Save as CLASS_OF_%Y.json (HS 4y + College 4y)
	var current_year: int = int(main_cfg.get("starting_year", 2025))
	var college_grad_year: int = current_year + 8
	var out_path: String = "res://configs/sports/american_football/CLASS_OF_%d.json" % college_grad_year
	gen.save_to_json(out_path, players)

	# 8) Log a quick preview
	print("✅ Generated ", players.size(), " prospects → ", out_path)
	for i in min(5, players.size()):
		var p: Dictionary = players[i]
		print("  - [", p["position"], "] ", p["name"])

func _ready() -> void:
	# Auto-run when the scene plays
	run()
