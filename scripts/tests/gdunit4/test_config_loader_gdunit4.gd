extends GdUnitTestSuite
class_name TestConfigLoaderGdUnit4

const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _loader: ConfigLoader = null

func before_test() -> void:
	_loader = ConfigLoader.new()

func after_test() -> void:
	_loader = null


# ============================================================================
# CONFIG LOADING TESTS
# ============================================================================

func test_loads_config_from_base_dir() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var main_cfg = _loader.get_config("main")

	assert_that(main_cfg).is_not_null()
	assert_that(main_cfg.size()).is_greater(0)
	assert_that(main_cfg).contains_key("starting_year")

func test_loads_positions_config() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var positions_cfg = _loader.get_config("positions")

	assert_that(positions_cfg).is_not_null()
	assert_that(positions_cfg.size()).is_greater(0)
	# Should have at least QB position
	assert_that(positions_cfg).contains_key("QB")

func test_loads_stats_config() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var stats_cfg = _loader.get_config("stats")

	assert_that(stats_cfg).is_not_null()
	assert_that(stats_cfg.size()).is_greater(0)
	assert_that(stats_cfg).contains_key("stats")

func test_loads_names_config() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var names_cfg = _loader.get_config("names")

	assert_that(names_cfg).is_not_null()
	assert_that(names_cfg.size()).is_greater(0)

func test_get_all_returns_multiple_configs() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var all_configs = _loader.get_all()

	assert_that(all_configs).is_not_null()
	assert_that(all_configs.size()).is_greater(3)

func test_list_keys_returns_config_names() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var keys = _loader.list_keys()

	assert_that(keys).is_not_null()
	assert_int(keys.size()).is_greater(0)
	# Should contain main config
	assert_bool("main" in keys).is_true()


# ============================================================================
# CACHING TESTS
# ============================================================================

func test_config_is_cached_after_first_load() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)

	var config1 = _loader.get_config("main")
	var config2 = _loader.get_config("main")

	# Should return same instance (cached)
	assert_that(config1).is_same(config2)

func test_clear_cache_invalidates_cache() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)

	var config1 = _loader.get_config("main")
	_loader.clear_cache()
	var config2 = _loader.get_config("main")

	# After clear_cache, should reload (different instance)
	assert_that(config1).is_not_same(config2)
	# But content should be the same
	assert_that(config1).is_equal(config2)

func test_set_base_dir_clears_cache() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)

	var config1 = _loader.get_config("main")
	_loader.set_base_dir("res://configs/sports/american_football")  # Same dir
	var config2 = _loader.get_config("main")

	# Setting base_dir should clear cache
	assert_that(config1).is_not_same(config2)


# ============================================================================
# FIXTURE CONFIG TESTS
# ============================================================================

func test_loads_fixture_config() -> void:
	_loader.configure("res://scripts/tests/fixtures/configs", "", false)
	var alpha_cfg = _loader.get_config("alpha")

	assert_that(alpha_cfg).is_not_null()
	assert_that(alpha_cfg.size()).is_greater(0)

func test_loads_fixture_beta_config() -> void:
	_loader.configure("res://scripts/tests/fixtures/configs", "", false)
	var beta_cfg = _loader.get_config("beta")

	assert_that(beta_cfg).is_not_null()
	assert_that(beta_cfg.size()).is_greater(0)


# ============================================================================
# EDGE CASES AND ERROR HANDLING
# ============================================================================

func test_returns_empty_dict_for_missing_config() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var missing = _loader.get_config("nonexistent_config_file_xyz")

	assert_that(missing).is_not_null()
	assert_int(missing.size()).is_equal(0)

func test_returns_empty_dict_for_invalid_base_dir() -> void:
	_loader.configure("res://invalid/path/does/not/exist", "", false)
	var config = _loader.get_config("main")

	assert_that(config).is_not_null()
	assert_int(config.size()).is_equal(0)

func test_handles_empty_base_dir() -> void:
	_loader.configure("", "", false)
	var all_configs = _loader.get_all()

	assert_that(all_configs).is_not_null()
	assert_int(all_configs.size()).is_equal(0)


# ============================================================================
# REQUIRE METHOD TESTS
# ============================================================================

func test_require_loads_multiple_configs() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var configs = _loader.require(["main", "positions", "stats"], false)

	assert_that(configs).is_not_null()
	assert_int(configs.size()).is_equal(3)
	assert_that(configs).contains_key("main")
	assert_that(configs).contains_key("positions")
	assert_that(configs).contains_key("stats")

func test_require_handles_missing_config_non_strict() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var configs = _loader.require(["main", "nonexistent"], false)

	assert_that(configs).is_not_null()
	assert_int(configs.size()).is_equal(2)
	assert_that(configs).contains_key("main")
	assert_that(configs).contains_key("nonexistent")
	# Nonexistent should be empty dict
	assert_int((configs["nonexistent"] as Dictionary).size()).is_equal(0)


# ============================================================================
# RECURSIVE LOADING TESTS
# ============================================================================

func test_loads_configs_recursively() -> void:
	_loader.configure("res://scripts/tests/fixtures/configs", "", true)
	var all_configs = _loader.get_all()

	# With recursive loading, should find configs in subdirectories
	assert_that(all_configs.size()).is_greater(0)

func test_loads_nested_world_config() -> void:
	_loader.configure("res://scripts/tests/fixtures/configs", "", true)
	var calendar = _loader.get_config("calendar")

	assert_that(calendar).is_not_null()
	# This config is in configs/world/calendar.json
	assert_that(calendar.size()).is_greater(0)


# ============================================================================
# CONFIG STRUCTURE VALIDATION
# ============================================================================

func test_main_config_has_required_fields() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var main_cfg = _loader.get_config("main")

	var required := ["starting_year", "random_seed"]
	TestHelpersGdUnit4.assert_schema(self, main_cfg, required, "main config")

func test_stats_config_has_stats_array() -> void:
	_loader.configure("res://configs/sports/american_football", "", false)
	var stats_cfg = _loader.get_config("stats")

	assert_that(stats_cfg).contains_key("stats")
	var stats_array = stats_cfg["stats"]
	assert_that(stats_array).is_instanceof(Array)
	assert_int((stats_array as Array).size()).is_greater(0)
