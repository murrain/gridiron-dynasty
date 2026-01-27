## GdUnit4 test suite for ConfigLoader
##
## Validates ConfigLoader configuration loading and merging.
## Migrated from test_config_loader.gd
extends GdUnitTestSuite

const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")


func test_config_loader_merges_override() -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var merged = cfg.get_config("alpha")
	var nested = merged.get("nested", {}) as Dictionary
	# JSON parses integers as floats, so cast to int for comparison
	assert_int(int(nested.get("b"))).is_equal(5)


func test_config_loader_get_all_includes_alpha() -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var all = cfg.get_all()
	assert_bool(all.has("alpha")).is_true()


func test_config_loader_list_keys_sorted() -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var keys = cfg.list_keys()
	assert_array(keys).is_equal(["alpha", "beta"])


func test_config_loader_require_returns_found() -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var required_names: Array[String] = ["beta", "missing"]
	var required = cfg.require(required_names, false)
	assert_bool(required.has("beta")).is_true()


func test_config_loader_require_includes_missing() -> void:
	var cfg = ConfigLoader.new()
	cfg.configure("res://scripts/tests/fixtures/configs", "res://scripts/tests/fixtures/configs_override", false)

	var required_names: Array[String] = ["beta", "missing"]
	var required = cfg.require(required_names, false)
	assert_bool(required.has("missing")).is_true()
