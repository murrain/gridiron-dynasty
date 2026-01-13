extends RefCounted

const PreDraftProcess = preload("res://scripts/world/PreDraftProcess.gd")

func run(t) -> void:
	test_run_basic(t)
	test_run_determinism(t)
	test_combine_invitee_selection(t)
	test_all_star_game_selection(t)

func test_run_basic(t) -> void:
	var world_state := {
		"draft_pool": {
			2024: _create_test_draft_pool(50)
		},
		"nfl_teams": _create_test_teams(32)
	}

	var config := _create_test_config()

	var result := PreDraftProcess.run(world_state, 2024, 12345, config)

	t.assert_eq(result.get("year"), 2024, "result has correct year")
	t.assert_true(int(result.get("combine_invites", 0)) > 0, "some combine invites")
	t.assert_true(result.has("step_seeds"), "result has step_seeds for reproducibility")

func test_run_determinism(t) -> void:
	var world_state1 := {
		"draft_pool": {2024: _create_test_draft_pool(30)},
		"nfl_teams": _create_test_teams(32)
	}
	var world_state2 := {
		"draft_pool": {2024: _create_test_draft_pool(30)},
		"nfl_teams": _create_test_teams(32)
	}

	var config := _create_test_config()

	var result1 := PreDraftProcess.run(world_state1, 2024, 99999, config)
	var result2 := PreDraftProcess.run(world_state2, 2024, 99999, config)

	t.assert_eq(result1.get("combine_invites"), result2.get("combine_invites"), "combine invites deterministic")
	t.assert_eq(result1.get("all_star_participants"), result2.get("all_star_participants"), "all_star deterministic")

func test_combine_invitee_selection(t) -> void:
	# Create pool with varying ratings
	var draft_pool := []
	for i in range(400):
		var rating := 50.0 + float(i) * 0.1  # Ratings from 50 to 90
		draft_pool.append({
			"player_id": "player_%d" % i,
			"position": "QB" if i % 10 == 0 else "RB",
			"stats": {"rating": rating}
		})

	var world_state := {
		"draft_pool": {2024: draft_pool},
		"nfl_teams": _create_test_teams(32)
	}

	var config := _create_test_config()
	config["pre_draft_process"]["combine"]["invite_count"] = 100

	var result := PreDraftProcess.run(world_state, 2024, 12345, config)

	# Check that players have pre_draft_process data
	var invited_count := 0
	for player in draft_pool:
		var p: Dictionary = player
		if p.has("pre_draft_process"):
			var pre_draft: Dictionary = p.get("pre_draft_process", {})
			if pre_draft.get("combine_invited", false):
				invited_count += 1

	t.assert_eq(invited_count, int(result.get("combine_invites", 0)), "invited count matches result")

func test_all_star_game_selection(t) -> void:
	var draft_pool := _create_test_draft_pool(200)

	var world_state := {
		"draft_pool": {2024: draft_pool},
		"nfl_teams": _create_test_teams(32)
	}

	var config := _create_test_config()

	PreDraftProcess.run(world_state, 2024, 54321, config)

	# Check that some players have all-star game data
	var all_star_count := 0
	for player in draft_pool:
		var p: Dictionary = player
		if p.has("pre_draft_process"):
			var pre_draft: Dictionary = p.get("pre_draft_process", {})
			var games: Array = pre_draft.get("all_star_games", [])
			if not games.is_empty():
				all_star_count += 1

	t.assert_true(all_star_count > 0, "some players have all-star game participation")


# Helper functions

func _create_test_draft_pool(count: int) -> Array:
	var pool := []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]

	for i in range(count):
		var rating := 60.0 + float(i % 40)
		pool.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": positions[i % positions.size()],
			"college_id": "college_%d" % (i % 10),
			"hype": 50.0 + float(i % 30),
			"stats": {
				"speed": rating,
				"strength": rating - 5.0,
				"agility": rating + 3.0
			}
		})

	return pool

func _create_test_teams(count: int) -> Array:
	var teams := []
	for i in range(count):
		teams.append({
			"id": "team_%d" % i,
			"name": "Team %d" % i
		})
	return teams

func _create_test_config() -> Dictionary:
	return {
		"pre_draft_process": {
			"combine": {
				"invite_count": 50,
				"invite_criteria": {"min_rating_threshold": 60.0}
			},
			"all_star_games": {
				"senior_bowl": {
					"invite_count": 30,
					"min_rating": 70.0,
					"draft_boost_range": [0.02, 0.06]
				},
				"east_west_shrine": {
					"invite_count": 25,
					"min_rating": 60.0,
					"draft_boost_range": [0.01, 0.03]
				}
			},
			"team_visits": {
				"max_per_player": 30,
				"visit_impact_range": [-0.03, 0.05]
			}
		},
		"combine_tests": {},
		"combine_tuning": {
			"performance_impact": {
				"elite_performance_boost": {
					"threshold_percentile": 90.0,
					"draft_boost": 0.08
				},
				"poor_performance_penalty": {
					"threshold_percentile": 25.0,
					"draft_penalty": 0.05
				}
			}
		}
	}
