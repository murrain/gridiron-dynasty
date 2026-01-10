extends RefCounted

func run(t) -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	t.assert_eq(merged.get("version"), 1, "base config should load")
	var nested = merged.get("nested", {}) as Dictionary
	t.assert_eq(nested.get("a"), 1, "nested base value preserved")
	t.assert_eq(nested.get("b"), 5, "nested override value merged")
	t.assert_eq(nested.get("c"), 9, "nested override add")
	t.assert_eq(merged.get("extra"), true, "override top-level key")

	var all = cfg.get_all()
	t.assert_true(all.has("alpha"), "get_all returns alpha")
	t.assert_true(all.has("beta"), "get_all returns beta")

	var keys = cfg.list_keys()
	t.assert_eq(keys, ["alpha", "beta"], "list_keys sorted")

	var required_names: Array[String] = ["alpha", "missing"]
	var required = cfg.require(required_names, false)
	t.assert_true(required.has("alpha"), "require returns found config")
	t.assert_true(required.has("missing"), "require includes missing key")
