extends RefCounted

const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")

func run(t) -> void:
	var config = load("res://autoloads/Config.gd").new()
	var original_base = config.base_dir
	var original_save = config.save_dir
	var original_recurse = config.recurse

	config.configure("res://scripts/tests/fixtures/configs", "", false)
	var gen = HighSchoolGenerator.new()
	var result = gen.generate(123, HighSchoolGenerator.DEFAULT_CONFIG_KEY, config)
	var schools = result.get("schools", []) as Array
	t.assert_eq(schools.size(), 3, "generate should create requested schools")
	var first = schools[0] as Dictionary
	t.assert_true(first.has("capacity"), "default capacity applied")

	var bad_cfg = {"school_count": 0, "regions": [], "eliteness_tiers": []}
	t.assert_true(not gen._validate_config(bad_cfg, false), "validate should reject missing data")

	config.configure(original_base, original_save, original_recurse)
