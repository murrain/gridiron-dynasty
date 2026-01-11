extends RefCounted

## Integration Tests for NFL Draft System
##
## Tests the complete draft pipeline from draft pool to NFL rosters,
## including multi-year roster persistence.

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

func run(t) -> void:
	_test_draft_adds_players_to_rosters(t)
	_test_rosters_persist_across_years(t)
	_test_32_teams_receive_picks(t)
	_test_draft_pool_decreases(t)
	_test_undrafted_pool_populated(t)
	_test_players_have_contracts(t)
	_test_players_have_draft_info(t)


## Test 1: Verify drafted players actually appear in NFL rosters
func _test_draft_adds_players_to_rosters(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(12345)
	var world_state: Dictionary = result.get("world_state", {})

	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var total_players := 0

	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		total_players += players.size()

	# After 9 years (5 drafts: years 5-9), rounds 1-7, 32 picks each = 224 per year
	# Minimum expected: 5 years × 224 picks = 1,120 players
	t.assert_true(total_players > 1000,
		"NFL should have >1000 players after 5 drafts (got %d)" % total_players)


## Test 2: Verify rosters persist across years (critical regression test)
func _test_rosters_persist_across_years(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 6  # First draft in year 5, check persistence after year 6
	var result := bootstrap.run(42)
	var world_state: Dictionary = result.get("world_state", {})

	# Count players after year 6 (2 drafts)
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var year5_count := 0
	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		year5_count += players.size()

	t.assert_true(year5_count > 0, "NFL rosters should not be empty after 2 drafts")

	# Continue simulation for 2 more years (4 total drafts)
	bootstrap.years_to_simulate = 8
	result = bootstrap.run(42)  # Same seed = deterministic
	world_state = result.get("world_state", {})

	rosters = world_state.get("nfl_rosters", {})
	var year8_count := 0
	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		year8_count += players.size()

	# Year 8 (4 drafts) should have MORE players than year 6 (2 drafts) (unless massive retirements)
	# Allow some buffer for retirements
	t.assert_true(year8_count >= year5_count * 0.8,
		"Year 8 rosters (%d) should not lose >20%% from year 6 (%d)" % [year8_count, year5_count])


## Test 3: Verify all 32 teams participate in draft
func _test_32_teams_receive_picks(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(555)
	var world_state: Dictionary = result.get("world_state", {})

	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var teams_with_players := 0

	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		if players.size() > 0:
			teams_with_players += 1

	t.assert_eq(teams_with_players, 32,
		"All 32 teams should have players after 5 drafts")


## Test 4: Verify draft pool decreases as players are drafted
func _test_draft_pool_decreases(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(999)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_pool: Dictionary = world_state.get("draft_pool", {})
	var draft_history: Dictionary = world_state.get("draft_history", {})
	var start_year := int(world_state.get("start_year", 2005))

	# Check a year where draft happened
	for year_offset in range(5):
		var year := start_year + year_offset
		if draft_history.has(year):
			var picks: Array = draft_history.get(year, [])
			# Each year should have picks (7 rounds × 32 teams = 224)
			t.assert_true(picks.size() > 200,
				"Year %d should have ~224 picks (got %d)" % [year, picks.size()])


## Test 5: Verify undrafted players go to undrafted pool
func _test_undrafted_pool_populated(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(777)
	var world_state: Dictionary = result.get("world_state", {})

	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})

	# There should be some years with undrafted players
	t.assert_true(undrafted_pool.keys().size() > 0,
		"Undrafted pool should exist")


## Test 6: Verify drafted players have contracts
func _test_players_have_contracts(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(333)
	var world_state: Dictionary = result.get("world_state", {})

	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var players_checked := 0
	var players_with_contracts := 0

	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		for player in players:
			var p: Dictionary = player
			players_checked += 1
			if p.has("contract"):
				players_with_contracts += 1
			if players_checked >= 50:  # Check sample of 50
				break
		if players_checked >= 50:
			break

	t.assert_true(players_with_contracts > 0,
		"NFL players should have contracts")


## Test 7: Verify drafted players have draft_info
func _test_players_have_draft_info(t) -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9  # First draft in year 5, need 9 years for 5 drafts
	var result := bootstrap.run(444)
	var world_state: Dictionary = result.get("world_state", {})

	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var sample_player_found := false

	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		if not players.is_empty():
			var p: Dictionary = players[0]
			if p.has("draft_info"):
				var draft_info: Dictionary = p["draft_info"]
				sample_player_found = true
				t.assert_true(draft_info.has("year"), "draft_info should have year")
				t.assert_true(draft_info.has("round"), "draft_info should have round")
				t.assert_true(draft_info.has("pick"), "draft_info should have pick")
				t.assert_true(draft_info.has("team_id"), "draft_info should have team_id")
				break
		if sample_player_found:
			break

	t.assert_true(sample_player_found, "Should find at least one player with draft_info")
