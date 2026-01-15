## GdUnit4 test suite for HighSchoolGenerator
##
## Validates high school generation and config validation.
## Migrated from test_high_school_generator.gd
extends GdUnitTestSuite

const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const ConfigService = preload("res://autoloads/Config.gd")

var _config: ConfigService


func before() -> void:
	_config = ConfigService.new()


func test_generate_creates_requested_schools() -> void:
	var gen := HighSchoolGenerator.new()
	var result := gen.generate(123, HighSchoolGenerator.DEFAULT_CONFIG_KEY, _config)
	var schools := result.get("schools", []) as Array

	assert_int(schools.size()).is_greater(0)


func test_schools_have_default_capacity() -> void:
	var gen := HighSchoolGenerator.new()
	var result := gen.generate(123, HighSchoolGenerator.DEFAULT_CONFIG_KEY, _config)
	var schools := result.get("schools", []) as Array

	if schools.size() > 0:
		var first := schools[0] as Dictionary
		assert_bool(first.has("capacity")).is_true()


func test_validation_rejects_zero_school_count() -> void:
	var gen := HighSchoolGenerator.new()
	var bad_cfg := {"school_count": 0, "regions": [], "eliteness_tiers": []}
	assert_bool(not gen._validate_config(bad_cfg, false)).is_true()


func test_validation_rejects_empty_regions() -> void:
	var gen := HighSchoolGenerator.new()
	var bad_cfg := {"school_count": 10, "regions": [], "eliteness_tiers": [{"min": 0, "max": 100}]}
	assert_bool(not gen._validate_config(bad_cfg, false)).is_true()


func test_validation_rejects_empty_eliteness_tiers() -> void:
	var gen := HighSchoolGenerator.new()
	var bad_cfg := {"school_count": 10, "regions": [{"id": "test", "weight": 1.0}], "eliteness_tiers": []}
	assert_bool(not gen._validate_config(bad_cfg, false)).is_true()


func test_determinism() -> void:
	var gen := HighSchoolGenerator.new()
	var result1 := gen.generate(456, HighSchoolGenerator.DEFAULT_CONFIG_KEY, _config)
	var result2 := gen.generate(456, HighSchoolGenerator.DEFAULT_CONFIG_KEY, _config)

	var schools1 := result1.get("schools", []) as Array
	var schools2 := result2.get("schools", []) as Array

	assert_int(schools1.size()).is_equal(schools2.size())

	for i in range(min(schools1.size(), 5)):
		var s1 := schools1[i] as Dictionary
		var s2 := schools2[i] as Dictionary
		assert_that(s1.get("id")).is_equal(s2.get("id"))
		assert_that(s1.get("region")).is_equal(s2.get("region"))
