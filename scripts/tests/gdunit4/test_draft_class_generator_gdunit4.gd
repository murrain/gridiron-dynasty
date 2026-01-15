## GdUnit4 test suite for DraftClassGenerator
##
## Validates draft class generation with class_tag assignment and determinism.
## Migrated from test_draft_class_generator.gd
extends GdUnitTestSuite

const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")
const ConfigService = preload("res://autoloads/Config.gd")


func test_generate_for_year_uses_class_size_override() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8
	class_rules["max_freaks_per_class"] = 1
	class_rules["freak_percentile_min"] = 0.4
	class_rules["freak_percentile_max"] = 0.6

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var players := generator.generate_for_year(2030, 444)
	assert_int(players.size()).is_equal(8)


func test_class_tag_is_assigned() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var players := generator.generate_for_year(2030, 444)
	var sample := players[0] as Dictionary
	assert_str(String(sample.get("class_tag", ""))).is_equal("CLASS_OF_2030")


func test_draft_year_is_assigned() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var players := generator.generate_for_year(2030, 444)
	var sample := players[0] as Dictionary
	assert_int(int(sample.get("draft_year", 0))).is_equal(2030)


func test_potential_is_copied_for_draft_class() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var players := generator.generate_for_year(2030, 444)
	var sample := players[0] as Dictionary
	var potential := sample.get("potential", {}) as Dictionary
	assert_bool(not potential.is_empty()).is_true()


func test_seeded_generation_is_deterministic() -> void:
	var config := ConfigService.new()
	var main_cfg := config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var seed := 444
	var players := generator.generate_for_year(2030, seed)
	var players_repeat := generator.generate_for_year(2030, seed)

	var name_a := String((players[0] as Dictionary).get("name", ""))
	var name_b := String((players_repeat[0] as Dictionary).get("name", ""))
	assert_str(name_a).is_equal(name_b)
