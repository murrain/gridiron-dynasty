extends RefCounted

func run(t: TestHelpers) -> void:
	var original_base := Config.base_dir
	var original_save := Config.save_dir
	var original_recurse := Config.recurse

	Config.configure("res://scripts/tests/fixtures/configs", "", false)
	var gen := HighSchoolGenerator.new()
	var result := gen.generate(123)
	var schools := result.get("schools", []) as Array
	t.assert_eq(schools.size(), 3, "generate should create requested schools")
	var first := schools[0] as Dictionary
	t.assert_true(first.has("capacity"), "default capacity applied")

	var bad_cfg := {"school_count": 0, "regions": [], "eliteness_tiers": []}
	t.assert_true(not gen._validate_config(bad_cfg), "validate should reject missing data")

	Config.configure(original_base, original_save, original_recurse)
