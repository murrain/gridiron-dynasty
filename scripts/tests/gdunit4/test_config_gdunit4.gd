## GdUnit4 test suite for Config autoload
##
## Validates configuration loading, merging, and retrieval.
## Migrated from test_config.gd
extends GdUnitTestSuite


func test_config_loads_base_config() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	# JSON parses integers as floats, so cast to int for comparison
	assert_int(int(merged.get("version"))).is_equal(1)


func test_config_preserves_nested_base_values() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	var nested = merged.get("nested", {}) as Dictionary
	# JSON parses integers as floats, so cast to int for comparison
	assert_int(int(nested.get("a"))).is_equal(1)


func test_config_merges_nested_override_values() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	var nested = merged.get("nested", {}) as Dictionary
	# JSON parses integers as floats, so cast to int for comparison
	assert_int(int(nested.get("b"))).is_equal(5)


func test_config_adds_nested_override_keys() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	var nested = merged.get("nested", {}) as Dictionary
	# JSON parses integers as floats, so cast to int for comparison
	assert_int(int(nested.get("c"))).is_equal(9)


func test_config_adds_top_level_override_keys() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	assert_bool(merged.get("extra")).is_true()


func test_get_all_returns_all_configs() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var all = cfg.get_all()
	assert_bool(all.has("alpha")).is_true()
	assert_bool(all.has("beta")).is_true()


func test_list_keys_returns_sorted_keys() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var keys = cfg.list_keys()
	assert_array(keys).is_equal(["alpha", "beta"])


func test_require_returns_found_config() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var required_names: Array[String] = ["alpha", "missing"]
	var required = cfg.require(required_names, false)
	assert_bool(required.has("alpha")).is_true()


func test_require_includes_missing_keys() -> void:
	var cfg = load("res://autoloads/Config.gd").new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var required_names: Array[String] = ["alpha", "missing"]
	var required = cfg.require(required_names, false)
	assert_bool(required.has("missing")).is_true()
