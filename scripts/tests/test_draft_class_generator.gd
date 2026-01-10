extends RefCounted

const DraftClassGenerator = preload("res://scripts/generation/DraftClassGenerator.gd")

func run(t) -> void:
	var main_cfg := Config.get_config("main")
	var class_rules := (main_cfg.get("class_rules", {}) as Dictionary).duplicate(true)
	class_rules["class_size"] = 8
	class_rules["max_freaks_per_class"] = 1
	class_rules["freak_percentile_min"] = 0.4
	class_rules["freak_percentile_max"] = 0.6

	var generator := DraftClassGenerator.new()
	generator.class_rules = class_rules

	var seed := 444
	var players := generator.generate_for_year(2030, seed)
	t.assert_eq(players.size(), 8, "generate_for_year uses class_size override")

	var sample := players[0] as Dictionary
	t.assert_eq(String(sample.get("class_tag", "")), "CLASS_OF_2030", "class_tag is assigned")
	t.assert_eq(int(sample.get("draft_year", 0)), 2030, "draft_year is assigned")
	var potential := sample.get("potential", {}) as Dictionary
	t.assert_true(not potential.is_empty(), "potential copied for draft class")

	var players_repeat := generator.generate_for_year(2030, seed)
	var name_a := String((players[0] as Dictionary).get("name", ""))
	var name_b := String((players_repeat[0] as Dictionary).get("name", ""))
	t.assert_eq(name_a, name_b, "seeded generation is deterministic")
