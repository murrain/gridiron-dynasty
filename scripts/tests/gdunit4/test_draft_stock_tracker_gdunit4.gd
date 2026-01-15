## GdUnit4 test suite for DraftStockTracker
##
## Validates draft stock initialization, movement tracking, and categorization.
## Migrated from test_draft_stock_tracker.gd
extends GdUnitTestSuite

const DraftStockTracker = preload("res://scripts/world/DraftStockTracker.gd")


func test_initialize_draft_stock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var draft_pool := [
		{"player_id": "p1", "stats": {"speed": 90, "strength": 85}},
		{"player_id": "p2", "stats": {"speed": 80, "strength": 80}},
		{"player_id": "p3", "stats": {"speed": 70, "strength": 75}}
	]

	DraftStockTracker.initialize_draft_stock(draft_pool, {}, rng)

	for player in draft_pool:
		var p: Dictionary = player
		assert_bool(p.has("draft_stock_timeline")).is_true()

		var timeline: Dictionary = p.get("draft_stock_timeline", {})
		assert_bool(timeline.has("pre_season_rank")).is_true()
		assert_bool(timeline.has("movement_events")).is_true()
		assert_int(int(timeline.get("total_movement", -1))).is_equal(0)


func test_initialize_draft_stock_determinism() -> void:
	var pool1 := [
		{"player_id": "p1", "stats": {"a": 80}},
		{"player_id": "p2", "stats": {"a": 90}},
		{"player_id": "p3", "stats": {"a": 70}}
	]
	var pool2 := [
		{"player_id": "p1", "stats": {"a": 80}},
		{"player_id": "p2", "stats": {"a": 90}},
		{"player_id": "p3", "stats": {"a": 70}}
	]

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 99999
	DraftStockTracker.initialize_draft_stock(pool1, {}, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99999
	DraftStockTracker.initialize_draft_stock(pool2, {}, rng2)

	for i in range(pool1.size()):
		var t1: Dictionary = pool1[i].get("draft_stock_timeline", {})
		var t2: Dictionary = pool2[i].get("draft_stock_timeline", {})
		assert_that(t1.get("pre_season_rank")).is_equal(t2.get("pre_season_rank"))


func test_update_draft_stock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"player_id": "test",
		"draft_stock_timeline": {
			"pre_season_rank": 10,
			"movement_events": [],
			"total_movement": 0
		},
		"pre_draft_process": {
			"combine_performance": {"overall_performance_grade": 0.08}
		}
	}

	var config := {
		"draft_stock_movement": {
			"event_impacts": {
				"combine_standout": [5, 15]
			}
		}
	}

	DraftStockTracker.update_draft_stock(player, "combine_standout", config, rng)

	var timeline: Dictionary = player.get("draft_stock_timeline", {})
	var events: Array = timeline.get("movement_events", [])

	assert_int(events.size()).is_greater(0)
	assert_int(int(timeline.get("total_movement", 0))).is_not_equal(0)


func test_calculate_consensus_ranking_positive() -> void:
	var player := {
		"draft_stock_timeline": {
			"pre_season_rank": 20,
			"total_movement": 10  # Moved up 10 spots
		}
	}

	var consensus := DraftStockTracker.calculate_consensus_ranking(player, {})

	# Expected: 20 - 10 = 10
	assert_int(consensus).is_equal(10)


func test_calculate_consensus_ranking_negative() -> void:
	var player := {
		"draft_stock_timeline": {
			"pre_season_rank": 20,
			"total_movement": -5  # Dropped 5 spots
		}
	}

	var consensus := DraftStockTracker.calculate_consensus_ranking(player, {})

	# Expected: 20 + 5 = 25
	assert_int(consensus).is_equal(25)


func test_finalize_draft_stock() -> void:
	var draft_pool := [
		{
			"player_id": "p1",
			"draft_stock_timeline": {
				"pre_season_rank": 1,
				"total_movement": 0
			}
		},
		{
			"player_id": "p2",
			"draft_stock_timeline": {
				"pre_season_rank": 10,
				"total_movement": 20  # Big riser
			}
		},
		{
			"player_id": "p3",
			"draft_stock_timeline": {
				"pre_season_rank": 5,
				"total_movement": -30  # Big faller
			}
		}
	]

	DraftStockTracker.finalize_draft_stock(draft_pool)

	for player in draft_pool:
		var p: Dictionary = player
		var timeline: Dictionary = p.get("draft_stock_timeline", {})
		assert_bool(timeline.has("final_rank")).is_true()
		assert_bool(timeline.has("movement_category")).is_true()


func test_categorize_movement_major_riser() -> void:
	var player := {
		"draft_stock_timeline": {"pre_season_rank": 50, "final_rank": 20}
	}
	assert_str(DraftStockTracker.categorize_movement(player, {})).is_equal("major_riser")


func test_categorize_movement_riser() -> void:
	var player := {
		"draft_stock_timeline": {"pre_season_rank": 30, "final_rank": 10}
	}
	assert_str(DraftStockTracker.categorize_movement(player, {})).is_equal("riser")


func test_categorize_movement_steady() -> void:
	var player := {
		"draft_stock_timeline": {"pre_season_rank": 15, "final_rank": 13}
	}
	assert_str(DraftStockTracker.categorize_movement(player, {})).is_equal("steady")


func test_categorize_movement_faller() -> void:
	var player := {
		"draft_stock_timeline": {"pre_season_rank": 10, "final_rank": 30}
	}
	assert_str(DraftStockTracker.categorize_movement(player, {})).is_equal("faller")


func test_categorize_movement_major_faller() -> void:
	var player := {
		"draft_stock_timeline": {"pre_season_rank": 5, "final_rank": 40}
	}
	assert_str(DraftStockTracker.categorize_movement(player, {})).is_equal("major_faller")
