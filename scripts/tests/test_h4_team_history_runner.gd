extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

func _init() -> void:
	var total_failures: Array = []

	var test_files := [
		"res://scripts/tests/test_h4_1_franchise_win_totals_accurate.gd",
		"res://scripts/tests/test_h4_2_championship_history_accurate.gd",
		"res://scripts/tests/test_h4_3_playoff_appearances_tracked.gd",
		"res://scripts/tests/test_h4_4_winning_streaks_tracked.gd",
		"res://scripts/tests/test_h4_6_drought_tracking_accurate.gd"
	]

	print("Running Team History Tests (H4.1-H4.6)...")
	print("")

	for path in test_files:
		var script = load(path)
		if script == null:
			print("Failed to load %s" % path)
			total_failures.append("%s: Failed to load" % path)
			continue

		var test_instance = script.new()
		var helper = TestHelpers.new()

		print("Running %s..." % path.get_file())
		test_instance.run(helper)

		if helper.failures.is_empty():
			print("  ✓ PASSED")
		else:
			print("  ✗ FAILED (%d assertions)" % helper.failures.size())
			for failure in helper.failures:
				total_failures.append("%s: %s" % [path.get_file(), failure])
		print("")

	print("============================================================")
	if total_failures.is_empty():
		print("All Team History Tests PASSED")
		quit(0)
		return

	print("FAILURES (%d):" % total_failures.size())
	for failure in total_failures:
		print("  - %s" % failure)
	quit(1)
