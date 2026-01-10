extends RefCounted

const WorldHistoryPreview = preload("res://scripts/pipelines/WorldHistoryPreview.gd")

func run(t) -> void:
	var preview := WorldHistoryPreview.new()
	preview.history_years = 2

	var first_run: Dictionary = preview.run()
	var second_run: Dictionary = preview.run()

	t.assert_eq(int(first_run.get("years", 0)), 2, "Preview returns requested history years")
	t.assert_eq(first_run.get("current_year", -1), second_run.get("current_year", -2), "Preview current year is deterministic")
	t.assert_eq(first_run.get("first_year", -1), second_run.get("first_year", -2), "Preview first year is deterministic")

	var buckets_a: Dictionary = first_run.get("recruit_buckets", {}) as Dictionary
	var buckets_b: Dictionary = second_run.get("recruit_buckets", {}) as Dictionary
	t.assert_eq(buckets_a, buckets_b, "Recruit bucket summary is deterministic")

	var pro_a: Dictionary = first_run.get("pro_snapshot", {}) as Dictionary
	var pro_b: Dictionary = second_run.get("pro_snapshot", {}) as Dictionary
	t.assert_eq(pro_a.get("pro_ready_count", -1), pro_b.get("pro_ready_count", -2), "Pro-ready count is deterministic")
	t.assert_true(int(pro_a.get("active_count", 0)) > 0, "Pro snapshot includes active players")
