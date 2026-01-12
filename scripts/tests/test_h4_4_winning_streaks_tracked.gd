extends RefCounted

## Test H4.4: Winning Streak Tracking
##
## Validates that longest_win_streak, longest_loss_streak, current_win_streak,
## and current_loss_streak are correctly tracked across seasons.

const CollegeSeason = preload("res://scripts/world/CollegeSeason.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_winning_streak_accumulates(t)
	_test_losing_streak_accumulates(t)
	_test_streak_resets_on_change(t)
	_test_longest_streaks_updated(t)


func _test_winning_streak_accumulates(t) -> void:
	var world_state := _create_test_world_with_dynasty()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 77777

	# Simulate 5 seasons - dynasty team should have multiple winning seasons
	for year_offset in range(5):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	# Check dynasty team's streak
	var team_history: Dictionary = world_state.get("team_history", {})
	var dynasty_history: Dictionary = team_history.get("college_000", {})

	var current_win_streak := int(dynasty_history.get("current_win_streak", 0))
	var longest_win_streak := int(dynasty_history.get("longest_win_streak", 0))

	# Dynasty should have winning streak (at least 2 consecutive winning seasons)
	t.assert_true(longest_win_streak >= 2, "Dynasty team should have winning streak >= 2 (got %d)" % longest_win_streak)
	t.assert_true(current_win_streak >= 0, "Current win streak should be >= 0 (got %d)" % current_win_streak)


func _test_losing_streak_accumulates(t) -> void:
	var world_state := _create_test_world_with_weak_team()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 88888

	# Simulate 5 seasons - weak team should have losing seasons
	for year_offset in range(5):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	# Check weak team's losing streak
	var team_history: Dictionary = world_state.get("team_history", {})
	var weak_history: Dictionary = team_history.get("college_007", {})

	var current_loss_streak := int(weak_history.get("current_loss_streak", 0))
	var longest_loss_streak := int(weak_history.get("longest_loss_streak", 0))

	# Weak team should likely have losing streak
	t.assert_true(longest_loss_streak >= 1, "Weak team should have some losing streak (got %d)" % longest_loss_streak)


func _test_streak_resets_on_change(t) -> void:
	# Create a controlled scenario by manually updating world_state
	var world_state := {
		"team_history": {
			"team_001": {
				"team_id": "team_001",
				"all_time_wins": 0,
				"all_time_losses": 0,
				"first_season": 2025,
				"last_season": 2025,
				"championship_count": 0,
				"championship_years": [],
				"playoff_appearances": 0,
				"playoff_years": [],
				"longest_win_streak": 0,
				"longest_loss_streak": 0,
				"current_win_streak": 3,  # Had 3-season winning streak
				"current_loss_streak": 0,
				"years_since_championship": -1
			}
		}
	}

	# Simulate a season where team has losing record
	var season_results := {
		"team_001": {
			"team_id": "team_001",
			"wins": 4,
			"losses": 8,  # Losing season
			"year": 2026
		}
	}

	# Manually call update function to test streak reset logic
	var cs := CollegeSeason.new()
	cs._update_team_history(world_state, 2026, season_results, "other_team")

	var history: Dictionary = world_state["team_history"]["team_001"]
	var current_win_streak := int(history["current_win_streak"])
	var current_loss_streak := int(history["current_loss_streak"])

	# Winning streak should reset to 0, losing streak should be 1
	t.assert_eq(current_win_streak, 0, "Win streak should reset to 0 after losing season")
	t.assert_eq(current_loss_streak, 1, "Loss streak should be 1 after losing season")


func _test_longest_streaks_updated(t) -> void:
	var world_state := _create_test_world()
	var config := _create_test_config()
	var positions_cfg := {"QB": {"core_stats": []}}
	var main_cfg := {"class_rules": {}}
	var stats_cfg := {}

	var base_seed := 99999

	# Simulate 3 seasons
	for year_offset in range(3):
		var year := 2025 + year_offset
		var year_seed := Rand.splitmix64(base_seed + year_offset)

		CollegeSeason.new().run(
			world_state,
			year,
			year_seed,
			config,
			positions_cfg,
			main_cfg,
			stats_cfg
		)

	# Verify longest streaks are reasonable
	var team_history: Dictionary = world_state.get("team_history", {})

	for team_id in team_history.keys():
		var history: Dictionary = team_history[team_id]
		var longest_win := int(history.get("longest_win_streak", 0))
		var longest_loss := int(history.get("longest_loss_streak", 0))
		var current_win := int(history.get("current_win_streak", 0))
		var current_loss := int(history.get("current_loss_streak", 0))

		# Longest should be >= current
		t.assert_true(longest_win >= current_win, "Team %s longest_win_streak should be >= current" % team_id)
		t.assert_true(longest_loss >= current_loss, "Team %s longest_loss_streak should be >= current" % team_id)

		# Can't have both current streaks active
		if current_win > 0:
			t.assert_eq(current_loss, 0, "Team %s can't have both win and loss streak active" % team_id)
		if current_loss > 0:
			t.assert_eq(current_win, 0, "Team %s can't have both loss and win streak active" % team_id)


func _create_test_world() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(8):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": 60.0 + randf() * 15.0,
				"stats": {},
				"age": 18
			})

		rosters[college_id] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_world_with_dynasty() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(8):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		# Dynasty team gets much stronger players
		var base_strength := 85.0 if i == 0 else 55.0

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": base_strength + randf() * 8.0,
				"stats": {},
				"age": 18
			})

		rosters[college_id] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_world_with_weak_team() -> Dictionary:
	var colleges := []
	var rosters := {}

	for i in range(8):
		var college_id := "college_%03d" % i
		colleges.append({"id": college_id, "tier": "mid", "eliteness": 50.0})

		# Weak team (007) gets much weaker players
		var base_strength := 40.0 if i == 7 else 65.0

		var players := []
		for j in range(10):
			players.append({
				"player_id": "%s_player_%d" % [college_id, j],
				"position": "QB" if j == 0 else "RB",
				"college_year": 1,
				"composite_score": base_strength + randf() * 8.0,
				"stats": {},
				"age": 18
			})

		rosters[college_id] = {"players": players}

	return {
		"colleges": colleges,
		"college_rosters": rosters,
		"draft_pool": {}
	}


func _create_test_config() -> Dictionary:
	return {
		"game_simulation": {
			"enabled": true,
			"regular_season_weeks": 12,
			"home_field_advantage": 3.0,
			"strength_sensitivity": 0.1,
			"upset_threshold": 5.0
		},
		"early_declaration": {
			"min_year": 3,
			"rating_threshold": 85.0
		},
		"draft_declaration": {
			"rating_threshold": 65.0
		}
	}
