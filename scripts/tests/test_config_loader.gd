extends RefCounted

const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")

func run(t) -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	var nested = merged.get("nested", {}) as Dictionary
	t.assert_eq(nested.get("b"), 5, "ConfigLoader merges override")

	var all = cfg.get_all()
	t.assert_true(all.has("alpha"), "ConfigLoader get_all includes alpha")

	var keys = cfg.list_keys()
	t.assert_eq(keys, ["alpha", "beta"], "ConfigLoader list_keys sorted")

	var required_names: Array[String] = ["beta", "missing"]
	var required = cfg.require(required_names, false)
	t.assert_true(required.has("beta"), "ConfigLoader require returns found config")
	t.assert_true(required.has("missing"), "ConfigLoader require includes missing key")
