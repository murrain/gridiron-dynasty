## GdUnit4 test suite for WorldHistoryPreview
##
## Tests world history preview generation and determinism.
extends GdUnitTestSuite

const WorldHistoryPreview = preload("res://scripts/pipelines/WorldHistoryPreview.gd")


func test_preview_returns_requested_years() -> void:
	var preview := WorldHistoryPreview.new()
	preview.history_years = 2

	var result: Dictionary = preview.run()

	assert_int(int(result.get("years", 0))).is_equal(2)


func test_preview_determinism() -> void:
	var preview := WorldHistoryPreview.new()
	preview.history_years = 2

	var first_run: Dictionary = preview.run()
	var second_run: Dictionary = preview.run()

	assert_int(int(first_run.get("current_year", -1))).is_equal(int(second_run.get("current_year", -2)))
	assert_int(int(first_run.get("first_year", -1))).is_equal(int(second_run.get("first_year", -2)))


func test_recruit_bucket_summary_determinism() -> void:
	var preview := WorldHistoryPreview.new()
	preview.history_years = 2

	var first_run: Dictionary = preview.run()
	var second_run: Dictionary = preview.run()

	var buckets_a: Dictionary = first_run.get("recruit_buckets", {}) as Dictionary
	var buckets_b: Dictionary = second_run.get("recruit_buckets", {}) as Dictionary

	assert_str(JSON.stringify(buckets_a)).is_equal(JSON.stringify(buckets_b))


func test_pro_snapshot_determinism() -> void:
	var preview := WorldHistoryPreview.new()
	preview.history_years = 2

	var first_run: Dictionary = preview.run()
	var second_run: Dictionary = preview.run()

	var pro_a: Dictionary = first_run.get("pro_snapshot", {}) as Dictionary
	var pro_b: Dictionary = second_run.get("pro_snapshot", {}) as Dictionary

	assert_int(int(pro_a.get("pro_ready_count", -1))).is_equal(int(pro_b.get("pro_ready_count", -2)))
	assert_int(int(pro_a.get("active_count", 0))).is_greater(0)
