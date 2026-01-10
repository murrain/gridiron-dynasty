extends RefCounted

const ClassGenerator = preload("res://scripts/generation/ClassGenerator.gd")

func run(t) -> void:
	var main_cfg := Config.get_config("main")
	var positions_cfg := Config.get_config("positions")
	var stats_cfg := Config.get_config("stats")
	var names_cfg := Config.get_config("names")
	var combine_cfg := Config.get_config("combine_tests")

	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 6
	class_rules["max_freaks_per_class"] = 1
	class_rules["freak_percentile_min"] = 0.4
	class_rules["freak_percentile_max"] = 0.6

	var gen := ClassGenerator.new()
	gen.main_cfg = main_cfg
	gen.positions_cfg = positions_cfg
	gen.stats_cfg = stats_cfg
	gen.names_cfg = names_cfg
	gen.combine_tests_cfg = combine_cfg
	gen.class_rules = class_rules

	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := gen.generate_only(6, 0.6, rng)
	t.assert_eq(players.size(), 6, "generate_only returns requested size")

	var first := players[0] as Dictionary
	t.assert_true(first.has("stats"), "generated player has stats")
	t.assert_true(first.has("combine"), "generated player has combine results")

	gen.copy_potential_only(players)
	for p in players:
		var d: Dictionary = p
		var pot: Dictionary = d.get("potential", {}) as Dictionary
		t.assert_true(not pot.is_empty(), "potential baseline copied")

	var deage_rng := RandomNumberGenerator.new()
	deage_rng.seed = 222
	gen.de_age_only(players, deage_rng)
	for p in players:
		var stats: Dictionary = (p as Dictionary).get("stats", {}) as Dictionary
		for key in stats.keys():
			var val := float(stats[key])
			t.assert_between(val, 0.0, 100.0, "de-aged stats remain in bounds")
