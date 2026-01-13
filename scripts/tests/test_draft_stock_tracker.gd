extends RefCounted

const DraftStockTracker = preload("res://scripts/world/DraftStockTracker.gd")

func run(t) -> void:
	test_initialize_draft_stock(t)
	test_initialize_draft_stock_determinism(t)
	test_update_draft_stock(t)
	test_calculate_consensus_ranking(t)
	test_finalize_draft_stock(t)
	test_categorize_movement(t)

func test_initialize_draft_stock(t) -> void:
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
		t.assert_true(p.has("draft_stock_timeline"), "player has draft_stock_timeline")

		var timeline: Dictionary = p.get("draft_stock_timeline", {})
		t.assert_true(timeline.has("pre_season_rank"), "timeline has pre_season_rank")
		t.assert_true(timeline.has("movement_events"), "timeline has movement_events")
		t.assert_eq(int(timeline.get("total_movement", -1)), 0, "total_movement starts at 0")

func test_initialize_draft_stock_determinism(t) -> void:
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
		t.assert_eq(t1.get("pre_season_rank"), t2.get("pre_season_rank"), "rankings are deterministic")

func test_update_draft_stock(t) -> void:
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

	t.assert_true(events.size() > 0, "movement event was added")
	t.assert_true(int(timeline.get("total_movement", 0)) != 0, "total_movement updated")

func test_calculate_consensus_ranking(t) -> void:
	var player := {
		"draft_stock_timeline": {
			"pre_season_rank": 20,
			"total_movement": 10  # Moved up 10 spots
		}
	}

	var consensus := DraftStockTracker.calculate_consensus_ranking(player, {})

	# Expected: 20 - 10 = 10
	t.assert_eq(consensus, 10, "consensus ranking calculated correctly")

	# Test negative movement
	player["draft_stock_timeline"]["total_movement"] = -5  # Dropped 5 spots
	consensus = DraftStockTracker.calculate_consensus_ranking(player, {})
	t.assert_eq(consensus, 25, "consensus reflects negative movement")

func test_finalize_draft_stock(t) -> void:
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
		t.assert_true(timeline.has("final_rank"), "player has final_rank")
		t.assert_true(timeline.has("movement_category"), "player has movement_category")

func test_categorize_movement(t) -> void:
	# Major riser (+25 or more)
	var major_riser := {
		"draft_stock_timeline": {"pre_season_rank": 50, "final_rank": 20}
	}
	t.assert_eq(DraftStockTracker.categorize_movement(major_riser, {}), "major_riser", "+30 = major_riser")

	# Riser (+15 to +24)
	var riser := {
		"draft_stock_timeline": {"pre_season_rank": 30, "final_rank": 10}
	}
	t.assert_eq(DraftStockTracker.categorize_movement(riser, {}), "riser", "+20 = riser")

	# Steady (-4 to +4)
	var steady := {
		"draft_stock_timeline": {"pre_season_rank": 15, "final_rank": 13}
	}
	t.assert_eq(DraftStockTracker.categorize_movement(steady, {}), "steady", "+2 = steady")

	# Faller (-15 to -24)
	var faller := {
		"draft_stock_timeline": {"pre_season_rank": 10, "final_rank": 30}
	}
	t.assert_eq(DraftStockTracker.categorize_movement(faller, {}), "faller", "-20 = faller")

	# Major faller (-25 or more)
	var major_faller := {
		"draft_stock_timeline": {"pre_season_rank": 5, "final_rank": 40}
	}
	t.assert_eq(DraftStockTracker.categorize_movement(major_faller, {}), "major_faller", "-35 = major_faller")
