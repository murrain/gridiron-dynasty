## GdUnit4 test suite for Draft Order and Rookie Contracts
##
## Tests draft order calculation and rookie contract AAV assignment.
extends GdUnitTestSuite

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")


func test_bootstrap_creates_season_records() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	var world_state: Dictionary = result.get("world_state", {})
	var season_records: Dictionary = world_state.get("season_records", {})

	assert_int(season_records.keys().size()).is_greater(0)


func test_draft_history_created() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	var world_state: Dictionary = result.get("world_state", {})
	var draft_history: Dictionary = world_state.get("draft_history", {})

	assert_int(draft_history.keys().size()).is_greater(0)


func test_draft_picks_have_contracts() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	var world_state: Dictionary = result.get("world_state", {})
	var draft_history: Dictionary = world_state.get("draft_history", {})

	for year in draft_history.keys():
		var picks: Array = draft_history[year]
		if picks.size() > 0:
			var first_pick: Dictionary = picks[0]
			var player: Dictionary = first_pick.get("player", {})
			var contract: Dictionary = player.get("contract", {})

			# First pick should have a contract
			assert_bool(contract.is_empty()).is_false()


func test_rookie_contract_aav_nonzero() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	var world_state: Dictionary = result.get("world_state", {})
	var draft_history: Dictionary = world_state.get("draft_history", {})

	var all_aav_valid := true
	for year in draft_history.keys():
		var picks: Array = draft_history[year]
		for pick in picks:
			var player: Dictionary = pick.get("player", {})
			var contract: Dictionary = player.get("contract", {})
			var aav := float(contract.get("annual_value", 0.0))

			if aav <= 0.0:
				all_aav_valid = false

	assert_bool(all_aav_valid).is_true()


func test_draft_order_determinism() -> void:
	var test_seed := 99999

	# Run 1
	var bootstrap1 := BootstrapGameWorld.new()
	bootstrap1.years_to_simulate = 2
	var result1 := bootstrap1.run(test_seed)
	var world_state_1: Dictionary = result1.get("world_state", {})
	var draft_history_1: Dictionary = world_state_1.get("draft_history", {})

	# Run 2
	var bootstrap2 := BootstrapGameWorld.new()
	bootstrap2.years_to_simulate = 2
	var result2 := bootstrap2.run(test_seed)
	var world_state_2: Dictionary = result2.get("world_state", {})
	var draft_history_2: Dictionary = world_state_2.get("draft_history", {})

	# Draft histories should have same years
	assert_int(draft_history_1.keys().size()).is_equal(draft_history_2.keys().size())

	# First pick of each year should match
	for year in draft_history_1.keys():
		var picks_1: Array = draft_history_1[year]
		var picks_2: Array = draft_history_2[year]

		assert_int(picks_1.size()).is_equal(picks_2.size())

		if picks_1.size() > 0:
			var first_pick_1: Dictionary = picks_1[0]
			var first_pick_2: Dictionary = picks_2[0]
			assert_str(String(first_pick_1.get("team_id", ""))).is_equal(String(first_pick_2.get("team_id", "")))


func test_higher_picks_have_higher_aav() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 3
	var result := bootstrap.run(12345)

	var world_state: Dictionary = result.get("world_state", {})
	var draft_history: Dictionary = world_state.get("draft_history", {})

	for year in draft_history.keys():
		var picks: Array = draft_history[year]
		if picks.size() >= 32:
			var pick_1: Dictionary = picks[0]
			var pick_32: Dictionary = picks[31]

			var player_1: Dictionary = pick_1.get("player", {})
			var player_32: Dictionary = pick_32.get("player", {})

			var contract_1: Dictionary = player_1.get("contract", {})
			var contract_32: Dictionary = player_32.get("contract", {})

			var aav_1 := float(contract_1.get("annual_value", 0.0))
			var aav_32 := float(contract_32.get("annual_value", 0.0))

			# First overall pick should have higher AAV than pick 32
			assert_float(aav_1).is_greater(aav_32)
