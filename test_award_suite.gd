extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const AWARD_TEST_SCRIPTS := [
	"res://scripts/tests/test_a3_2_player_of_year_awards.gd",
	"res://scripts/tests/test_a3_3_all_pro_selections.gd",
	"res://scripts/tests/test_a3_4_pro_bowl_rosters.gd",
	"res://scripts/tests/test_a3_8_rookie_of_year.gd"
]

func _init() -> void:
	print("=== Running Award System Test Suite ===\n")

	var total_failures: Array = []
	var passed_count := 0

	for path in AWARD_TEST_SCRIPTS:
		print("Running: %s" % path.get_file())
		var script = load(path)
		if script == null:
			total_failures.append("Failed to load %s" % path)
			continue

		var test_instance = script.new()
		var helper = TestHelpers.new()
		test_instance.run(helper)

		if helper.failures.is_empty():
			print("  ✓ PASSED\n")
			passed_count += 1
		else:
			print("  ✗ FAILED")
			for failure in helper.failures:
				total_failures.append("%s: %s" % [path.get_file(), failure])
				print("    - %s" % failure)
			print("")

	print("============================================================")
	if total_failures.is_empty():
		print("SUCCESS: All %d award tests passed!" % AWARD_TEST_SCRIPTS.size())
		quit(0)
	else:
		print("FAILURES: %d of %d tests passed" % [passed_count, AWARD_TEST_SCRIPTS.size()])
		print("\nFailure details:")
		for failure in total_failures:
			print("  - %s" % failure)
		quit(1)
