extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

const TEST_SCRIPTS := [
	"res://scripts/tests/test_draft_history_debug.gd",
	"res://scripts/tests/test_d5_1_draft_history_all_picks_recorded.gd",
	"res://scripts/tests/test_d5_1_draft_history_correct_pick_order.gd",
	"res://scripts/tests/test_d5_5_draft_trades_schema_ready.gd"
]

func _init() -> void:
	var total_failures: Array = []
	for path in TEST_SCRIPTS:
		print("\nRunning: %s" % path)
		var script = load(path)
		if script == null:
			total_failures.append("Failed to load %s" % path)
			continue
		var test_instance = script.new()
		var helper = TestHelpers.new()
		test_instance.run(helper)
		for failure in helper.failures:
			total_failures.append("%s: %s" % [path, failure])

	print("\n" + "=".repeat(60))
	if total_failures.is_empty():
		print("All draft history tests passed (%d)." % TEST_SCRIPTS.size())
		quit(0)
		return

	print("Failures (%d):" % total_failures.size())
	for failure in total_failures:
		print("- %s" % failure)
	quit(1)
