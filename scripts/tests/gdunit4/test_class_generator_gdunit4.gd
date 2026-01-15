## GdUnit4 test suite for ClassGenerator
##
## Validates class generation, potential copying, and de-aging.
## Migrated from test_class_generator.gd
extends GdUnitTestSuite

const ClassGenerator = preload("res://scripts/generation/ClassGenerator.gd")
const ConfigService = preload("res://autoloads/Config.gd")


var _gen: ClassGenerator
var _class_rules: Dictionary


func before() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var positions_cfg := config.get_config("positions")
	var stats_cfg := config.get_config("stats")
	var names_cfg := config.get_config("names")
	var combine_cfg := config.get_config("combine_tests")

	_class_rules = (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	_class_rules["class_size"] = 6
	_class_rules["max_freaks_per_class"] = 1
	_class_rules["freak_percentile_min"] = 0.4
	_class_rules["freak_percentile_max"] = 0.6

	_gen = ClassGenerator.new()
	_gen.main_cfg = main_cfg
	_gen.positions_cfg = positions_cfg
	_gen.stats_cfg = stats_cfg
	_gen.names_cfg = names_cfg
	_gen.combine_tests_cfg = combine_cfg
	_gen.class_rules = _class_rules


func test_generate_only_returns_requested_size() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := _gen.generate_only(6, 0.6, rng)
	assert_int(players.size()).is_equal(6)


func test_generated_player_has_stats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := _gen.generate_only(6, 0.6, rng)
	var first := players[0] as Dictionary
	assert_bool(first.has("stats")).is_true()


func test_generated_player_has_combine_results() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := _gen.generate_only(6, 0.6, rng)
	var first := players[0] as Dictionary
	assert_bool(first.has("combine")).is_true()


func test_copy_potential_copies_baseline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := _gen.generate_only(6, 0.6, rng)
	_gen.copy_potential_only(players)

	for p in players:
		var d: Dictionary = p
		var pot: Dictionary = d.get("potential", {}) as Dictionary
		assert_bool(not pot.is_empty()).is_true()


func test_de_age_stats_remain_in_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var players := _gen.generate_only(6, 0.6, rng)
	_gen.copy_potential_only(players)

	var deage_rng := RandomNumberGenerator.new()
	deage_rng.seed = 222
	_gen.de_age_only(players, deage_rng)

	for p in players:
		var stats: Dictionary = (p as Dictionary).get("stats", {}) as Dictionary
		for key in stats.keys():
			var val := float(stats[key])
			assert_float(val).is_between(0.0, 100.0)
