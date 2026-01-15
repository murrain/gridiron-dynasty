## GdUnit4 test suite for WorldCalendar
##
## Tests calendar phase generation and validation.
extends GdUnitTestSuite

const WorldCalendar = preload("res://scripts/world/WorldCalendar.gd")
const ConfigService = preload("res://autoloads/Config.gd")


func test_phases_for_year() -> void:
	var config := ConfigService.new()
	var original_base := config.base_dir
	var original_save := config.save_dir
	var original_recurse := config.recurse

	config.configure("res://scripts/tests/fixtures/configs", "", false)
	var cal := WorldCalendar.new()
	var phases := cal.phases_for_year(2025, WorldCalendar.DEFAULT_CONFIG_KEY, config)

	assert_int(phases.size()).is_equal(2)

	var first := phases[0] as Dictionary
	assert_str(String(first.get("phase_id"))).is_equal("preseason")
	assert_int(int(first.get("year"))).is_equal(2025)

	config.configure(original_base, original_save, original_recurse)


func test_validate_calendar_rejects_invalid() -> void:
	var cal := WorldCalendar.new()

	var invalid := {"phases": [{"id": "dup", "start_tick": 2, "end_tick": 1}]}
	assert_bool(cal._validate_calendar(invalid, false)).is_false()
