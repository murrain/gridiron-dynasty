extends RefCounted

const WorldCalendar = preload("res://scripts/world/WorldCalendar.gd")

func run(t) -> void:
	var config = load("res://autoloads/Config.gd").new()
	var original_base = config.base_dir
	var original_save = config.save_dir
	var original_recurse = config.recurse

	config.configure("res://scripts/tests/fixtures/configs", "", false)
	var cal = WorldCalendar.new()
	var phases = cal.phases_for_year(2025, WorldCalendar.DEFAULT_CONFIG_KEY, config)
	t.assert_eq(phases.size(), 2, "phases_for_year returns phases")
	var first = phases[0] as Dictionary
	t.assert_eq(first.get("phase_id"), "preseason", "phase id matches")
	t.assert_eq(first.get("year"), 2025, "phase year matches")

	var invalid = {"phases": [{"id": "dup", "start_tick": 2, "end_tick": 1}]}
	t.assert_true(not cal._validate_calendar(invalid, false), "_validate_calendar rejects invalid")

	config.configure(original_base, original_save, original_recurse)
