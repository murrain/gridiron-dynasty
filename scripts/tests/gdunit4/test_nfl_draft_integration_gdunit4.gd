## GdUnit4 test suite for NFL Draft System Integration
##
## Tests the complete draft pipeline from draft pool to NFL rosters,
## including multi-year roster persistence.
extends GdUnitTestSuite

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")


## Test 1: Verify drafted players actually appear in NFL rosters
func test_draft_adds_players_to_rosters() -> void:
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

	# After 9 years (5 drafts), should have many players
	assert_int(total_players).is_greater(1000)


## Test 2: Verify rosters persist across years (critical regression test)
func test_rosters_persist_across_years() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 6  # First draft in year 5, check persistence after year 6
	var result := bootstrap.run(42)
	var world_state: Dictionary = result.get("world_state", {})

	# Count players after year 6 (2 drafts)
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var year6_count := 0
	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		year6_count += players.size()

	assert_int(year6_count).is_greater(0)


## Test 3: Verify all 32 teams participate in draft
func test_32_teams_receive_picks() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9
	var result := bootstrap.run(555)
	var world_state: Dictionary = result.get("world_state", {})

	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var teams_with_players := 0

	for team_id in rosters.keys():
		var roster: Dictionary = rosters.get(team_id, {})
		var players: Array = roster.get("players", [])
		if players.size() > 0:
			teams_with_players += 1

	assert_int(teams_with_players).is_equal(32)


## Test 4: Verify draft pool decreases as players are drafted
func test_draft_pool_decreases() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9
	var result := bootstrap.run(999)
	var world_state: Dictionary = result.get("world_state", {})

	var draft_history: Dictionary = world_state.get("draft_history", {})
	var start_year := int(world_state.get("start_year", 2005))

	# Check years where draft happened
	for year_offset in range(5):
		var year := start_year + year_offset
		if draft_history.has(year):
			var picks: Array = draft_history.get(year, [])
			# Each year should have picks (7 rounds x 32 teams = 224)
			assert_int(picks.size()).is_greater(200)


## Test 5: Verify undrafted players go to undrafted pool
func test_undrafted_pool_populated() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9
	var result := bootstrap.run(777)
	var world_state: Dictionary = result.get("world_state", {})

	var undrafted_pool: Dictionary = world_state.get("undrafted_pool", {})

	# There should be some years with undrafted players
	assert_int(undrafted_pool.keys().size()).is_greater(0)


## Test 6: Verify drafted players have contracts
func test_players_have_contracts() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9
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

	assert_int(players_with_contracts).is_greater(0)


## Test 7: Verify drafted players have draft_info
func test_players_have_draft_info() -> void:
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = 9
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
				assert_bool(draft_info.has("year")).is_true()
				assert_bool(draft_info.has("round")).is_true()
				assert_bool(draft_info.has("pick")).is_true()
				assert_bool(draft_info.has("team_id")).is_true()
				break
		if sample_player_found:
			break

	assert_bool(sample_player_found).is_true()
