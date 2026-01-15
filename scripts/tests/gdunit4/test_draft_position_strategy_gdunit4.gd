## GdUnit4 test suite for DraftPositionStrategy
##
## Validates position tier-based draft strategy produces realistic NFL draft patterns.
## Migrated from test_draft_position_strategy.gd
extends GdUnitTestSuite

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")


func test_premium_positions_dominate_round_1() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 10
	var result := bootstrap.run(12345)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var premium_count := 0
	var total_round1_picks := 0

	var premium_positions := ["QB", "EDGE", "OL", "CB"]

	for year in draft_history.keys():
		if int(year) < 2020:
			continue
		var picks: Array = draft_history.get(year, [])
		for i in range(min(32, picks.size())):
			var pick: Dictionary = picks[i]
			var position := String(pick.get("position", ""))
			total_round1_picks += 1

			if position in premium_positions:
				premium_count += 1

	assert_int(total_round1_picks).is_greater(0)

	var premium_pct := (float(premium_count) / float(total_round1_picks)) * 100.0

	assert_float(premium_pct).is_greater_equal(60.0)
	assert_float(premium_pct).is_less_equal(85.0)


func test_devalued_positions_rare_in_round_1() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 10
	var result := bootstrap.run(54321)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var devalued_count := 0
	var total_round1_picks := 0

	var devalued_positions := ["RB", "TE", "S"]

	for year in draft_history.keys():
		if int(year) < 2020:
			continue
		var picks: Array = draft_history.get(year, [])
		for i in range(min(32, picks.size())):
			var pick: Dictionary = picks[i]
			var position := String(pick.get("position", ""))
			total_round1_picks += 1

			if position in devalued_positions:
				devalued_count += 1

	assert_int(total_round1_picks).is_greater(0)

	var devalued_pct := (float(devalued_count) / float(total_round1_picks)) * 100.0

	assert_float(devalued_pct).is_less_equal(15.0)


func test_generational_talent_overcomes_penalty() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 20
	var result := bootstrap.run(99999)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var draft_pool_all: Dictionary = world_state.get("draft_pool", {})

	var devalued_positions := ["RB", "TE", "S"]

	var generational_devalued_found := 0
	var generational_devalued_drafted_r1 := 0

	for year in draft_history.keys():
		if int(year) < 2020:
			continue

		var picks: Array = draft_history.get(year, [])
		var pool: Array = draft_pool_all.get(year, [])

		for player in pool:
			var p: Dictionary = player
			var position := String(p.get("position", ""))
			if position not in devalued_positions:
				continue

			var player_id := String(p.get("player_id", ""))
			var drafted_in_r1 := false

			for i in range(min(32, picks.size())):
				var pick: Dictionary = picks[i]
				if String(pick.get("player_id", "")) == player_id:
					drafted_in_r1 = true
					break

			var stats: Dictionary = p.get("stats", {})
			if stats.is_empty():
				continue

			var core_sum := 0.0
			var core_count := 0
			for stat_name in stats.keys():
				var stat_value := float(stats.get(stat_name, 0.0))
				if stat_value > 0:
					core_sum += stat_value
					core_count += 1

			if core_count > 0:
				var avg_stat := core_sum / float(core_count)
				if avg_stat >= 85.0:
					generational_devalued_found += 1
					if drafted_in_r1:
						generational_devalued_drafted_r1 += 1

	if generational_devalued_found > 0:
		assert_int(generational_devalued_drafted_r1).is_greater(0)
	else:
		assert_bool(true).is_true()


func test_position_distribution_by_round() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 10
	var result := bootstrap.run(77777)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})

	var premium_positions := ["QB", "EDGE", "OL", "CB"]

	var round_data := {
		1: {"premium": 0, "total": 0},
		3: {"premium": 0, "total": 0},
		7: {"premium": 0, "total": 0}
	}

	for year in draft_history.keys():
		if int(year) < 2020:
			continue
		var picks: Array = draft_history.get(year, [])

		for pick_dict in picks:
			var pick: Dictionary = pick_dict
			var round := int(pick.get("round", 0))
			var position := String(pick.get("position", ""))

			if round in [1, 3, 7]:
				round_data[round]["total"] += 1
				if position in premium_positions:
					round_data[round]["premium"] += 1

	if round_data[1]["total"] > 0:
		var r1_premium_pct := (float(round_data[1]["premium"]) / float(round_data[1]["total"])) * 100.0
		assert_float(r1_premium_pct).is_greater_equal(60.0)

	if round_data[3]["total"] > 0:
		var r3_premium_pct := (float(round_data[3]["premium"]) / float(round_data[3]["total"])) * 100.0
		assert_float(r3_premium_pct).is_between(25.0, 65.0)

	if round_data[7]["total"] > 0:
		var r7_premium_pct := (float(round_data[7]["premium"]) / float(round_data[7]["total"])) * 100.0
		assert_float(r7_premium_pct).is_between(15.0, 55.0)


func test_special_teams_never_early() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 10
	var result := bootstrap.run(88888)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var special_teams := ["K", "P"]
	var early_specialist_count := 0

	for year in draft_history.keys():
		if int(year) < 2020:
			continue
		var picks: Array = draft_history.get(year, [])

		for i in range(min(96, picks.size())):
			var pick: Dictionary = picks[i]
			var position := String(pick.get("position", ""))

			if position in special_teams:
				early_specialist_count += 1

	assert_int(early_specialist_count).is_equal(0)


func test_determinism() -> void:
	var bootstrap_a := BootstrapGameWorld.new()
	bootstrap_a.years_to_simulate = 5
	var result_a := bootstrap_a.run(55555)

	var bootstrap_b := BootstrapGameWorld.new()
	bootstrap_b.years_to_simulate = 5
	var result_b := bootstrap_b.run(55555)

	var world_state_a: Dictionary = result_a.get("world_state", {})
	var world_state_b: Dictionary = result_b.get("world_state", {})
	var draft_history_a: Dictionary = world_state_a.get("draft_history", {})
	var draft_history_b: Dictionary = world_state_b.get("draft_history", {})

	assert_int(draft_history_a.keys().size()).is_equal(draft_history_b.keys().size())

	for year in draft_history_a.keys():
		assert_bool(draft_history_b.has(year)).is_true()

		var picks_a: Array = draft_history_a.get(year, [])
		var picks_b: Array = draft_history_b.get(year, [])

		assert_int(picks_a.size()).is_equal(picks_b.size())

		for i in range(min(picks_a.size(), picks_b.size())):
			var pick_a: Dictionary = picks_a[i]
			var pick_b: Dictionary = picks_b[i]

			assert_str(String(pick_a.get("player_id", ""))).is_equal(String(pick_b.get("player_id", "")))
			assert_str(String(pick_a.get("team_id", ""))).is_equal(String(pick_b.get("team_id", "")))
			assert_str(String(pick_a.get("position", ""))).is_equal(String(pick_b.get("position", "")))
			assert_int(int(pick_a.get("round", 0))).is_equal(int(pick_b.get("round", 0)))
