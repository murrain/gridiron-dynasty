extends RefCounted

func run(t: TestHelpers) -> void:
	var original_base := Config.base_dir
	var original_save := Config.save_dir
	var original_recurse := Config.recurse

	Config.configure("res://scripts/tests/fixtures/configs", "", false)
	var cal := WorldCalendar.new()
	var phases := cal.phases_for_year(2025)
	t.assert_eq(phases.size(), 2, "phases_for_year returns phases")
	var first := phases[0] as Dictionary
	t.assert_eq(first.get("phase_id"), "preseason", "phase id matches")
	t.assert_eq(first.get("year"), 2025, "phase year matches")

	var invalid := {"phases": [{"id": "dup", "start_tick": 2, "end_tick": 1}]}
	t.assert_true(not cal._validate_calendar(invalid), "_validate_calendar rejects invalid")

	Config.configure(original_base, original_save, original_recurse)
