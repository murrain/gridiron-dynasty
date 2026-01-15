## GdUnit4 test suite for Compensatory Picks
##
## Validates compensatory pick calculation, FA transaction tracking,
## and round assignment based on player value.
## Migrated from test_compensatory_picks.gd
extends GdUnitTestSuite

const NflDraft = preload("res://scripts/world/NflDraft.gd")


func test_track_fa_transactions_records_signings() -> void:
	var world_state := {}
	var year := 2024
	var signings := [
		{"player_id": "player1", "team_id": "CHI", "previous_team_id": "SF", "player_value": 80.0},
		{"player_id": "player2", "team_id": "NYJ", "previous_team_id": "SF", "player_value": 75.0}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	assert_bool(world_state.has("fa_transaction_tracking")).is_true()
	var tracking: Dictionary = world_state["fa_transaction_tracking"]
	assert_bool(tracking.has(year)).is_true()


func test_track_fa_transactions_sf_losses() -> void:
	var world_state := {}
	var year := 2024
	var signings := [
		{"player_id": "player1", "team_id": "CHI", "previous_team_id": "SF", "player_value": 80.0},
		{"player_id": "player2", "team_id": "NYJ", "previous_team_id": "SF", "player_value": 75.0}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var year_tracking: Dictionary = world_state["fa_transaction_tracking"][year]
	assert_bool(year_tracking.has("SF")).is_true()
	var sf_data: Dictionary = year_tracking["SF"]
	var sf_losses: Array = sf_data.get("losses", [])
	assert_int(sf_losses.size()).is_equal(2)


func test_track_fa_transactions_chi_gains() -> void:
	var world_state := {}
	var year := 2024
	var signings := [
		{"player_id": "player1", "team_id": "CHI", "previous_team_id": "SF", "player_value": 80.0}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var year_tracking: Dictionary = world_state["fa_transaction_tracking"][year]
	assert_bool(year_tracking.has("CHI")).is_true()
	var chi_data: Dictionary = year_tracking["CHI"]
	var chi_gains: Array = chi_data.get("gains", [])
	assert_int(chi_gains.size()).is_equal(1)

	var chi_gain: Dictionary = chi_gains[0]
	assert_str(String(chi_gain.get("player_id"))).is_equal("player1")
	assert_str(String(chi_gain.get("origin_team"))).is_equal("SF")


func test_track_fa_transactions_skips_rookies() -> void:
	var world_state := {}
	var year := 2024
	var signings := [
		{"player_id": "rookie1", "team_id": "CHI", "previous_team_id": "UNDRAFTED", "player_value": 60.0},
		{"player_id": "rookie2", "team_id": "NYJ", "previous_team_id": "", "player_value": 55.0}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var tracking: Dictionary = world_state.get("fa_transaction_tracking", {})
	var year_tracking: Dictionary = tracking.get(year, {})
	assert_bool(not year_tracking.has("UNDRAFTED")).is_true()
	assert_bool(year_tracking.is_empty()).is_true()


func test_track_fa_transactions_skips_resignings() -> void:
	var world_state := {}
	var year := 2024
	var signings := [
		{"player_id": "player1", "team_id": "SF", "previous_team_id": "SF", "player_value": 80.0}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var tracking: Dictionary = world_state.get("fa_transaction_tracking", {})
	var year_tracking: Dictionary = tracking.get(year, {})
	assert_bool(year_tracking.is_empty()).is_true()


func test_calculate_comp_picks_net_loss() -> void:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [{"player_id": "player1", "value": 80.0, "destination_team": "CHI"}],
					"gains": []
				}
			}
		}
	}
	var year := 2025
	var league_cfg := _make_league_config()

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	assert_int(comp_picks.size()).is_equal(1)

	var pick: Dictionary = comp_picks[0]
	assert_str(String(pick.get("team_id"))).is_equal("SF")
	assert_int(int(pick.get("year"))).is_equal(2025)
	assert_int(int(pick.get("round"))).is_equal(3)
	assert_str(String(pick.get("player_lost_id"))).is_equal("player1")
	assert_bool(bool(pick.get("compensatory"))).is_true()


func test_calculate_comp_picks_threshold() -> void:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [{"player_id": "player1", "value": 65.0, "destination_team": "CHI"}],
					"gains": [{"player_id": "player2", "value": 60.0, "origin_team": "NYJ"}]
				}
			}
		}
	}
	var year := 2025
	var league_cfg := _make_league_config()

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Net loss = 65 - 60 = 5, below threshold of 50
	assert_bool(comp_picks.is_empty()).is_true()


func test_calculate_comp_picks_round_assignment() -> void:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [
						{"player_id": "elite", "value": 85.0, "destination_team": "CHI"},
						{"player_id": "starter", "value": 75.0, "destination_team": "NYJ"},
						{"player_id": "depth", "value": 65.0, "destination_team": "GB"}
					],
					"gains": []
				}
			}
		}
	}
	var year := 2025
	var league_cfg := _make_league_config()

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	assert_int(comp_picks.size()).is_equal(3)

	var elite_pick: Dictionary = comp_picks[0]
	assert_int(int(elite_pick.get("round"))).is_equal(3)

	var starter_pick: Dictionary = comp_picks[1]
	assert_int(int(starter_pick.get("round"))).is_equal(4)

	var depth_pick: Dictionary = comp_picks[2]
	assert_int(int(depth_pick.get("round"))).is_equal(5)


func test_calculate_comp_picks_max_cap() -> void:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [
						{"player_id": "p1", "value": 80.0, "destination_team": "CHI"},
						{"player_id": "p2", "value": 78.0, "destination_team": "NYJ"},
						{"player_id": "p3", "value": 76.0, "destination_team": "GB"},
						{"player_id": "p4", "value": 74.0, "destination_team": "DAL"},
						{"player_id": "p5", "value": 72.0, "destination_team": "NE"}
					],
					"gains": []
				}
			}
		}
	}
	var year := 2025
	var league_cfg := _make_league_config()

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Should cap at 4 despite 5 losses
	assert_int(comp_picks.size()).is_equal(4)


func test_calculate_comp_picks_ignores_low_value() -> void:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [{"player_id": "scrub", "value": 55.0, "destination_team": "CHI"}],
					"gains": []
				}
			}
		}
	}
	var year := 2025
	var league_cfg := _make_league_config()

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Player value 55 is below depth threshold (60), no comp pick
	assert_bool(comp_picks.is_empty()).is_true()


func test_insert_comp_picks() -> void:
	var world_state := {}
	var round_picks := [
		{"pick_number": 1, "original_team_id": "SF", "current_owner_id": "SF", "traded": false},
		{"pick_number": 2, "original_team_id": "CHI", "current_owner_id": "CHI", "traded": false}
	]
	var comp_picks := [
		{
			"team_id": "BAL",
			"year": 2025,
			"round": 3,
			"reason": "fa_loss_player1",
			"player_lost_value": 80.0,
			"compensatory": true
		}
	]
	var year := 2025
	var round_num := 3

	var modified_picks := NflDraft.insert_compensatory_picks(
		round_picks, comp_picks, year, round_num, world_state
	)

	assert_int(modified_picks.size()).is_equal(3)

	var comp_pick: Dictionary = modified_picks[2]
	assert_int(int(comp_pick.get("pick_number"))).is_equal(3)
	assert_str(String(comp_pick.get("current_owner_id"))).is_equal("BAL")
	assert_bool(bool(comp_pick.get("compensatory"))).is_true()
	assert_bool(bool(comp_pick.get("traded"))).is_false()


func test_insert_comp_picks_filters_by_round() -> void:
	var world_state := {}
	var round_picks := [
		{"pick_number": 1, "original_team_id": "SF", "current_owner_id": "SF", "traded": false}
	]
	var comp_picks := [
		{"team_id": "BAL", "year": 2025, "round": 3, "compensatory": true},
		{"team_id": "CLE", "year": 2025, "round": 4, "compensatory": true}
	]
	var year := 2025
	var round_num := 3

	var modified_picks := NflDraft.insert_compensatory_picks(
		round_picks, comp_picks, year, round_num, world_state
	)

	# Should only insert round 3 comp pick
	assert_int(modified_picks.size()).is_equal(2)

	var comp_pick: Dictionary = modified_picks[1]
	assert_str(String(comp_pick.get("current_owner_id"))).is_equal("BAL")


func test_comp_picks_determinism() -> void:
	var tracking := {
		2024: {
			"SF": {
				"losses": [{"player_id": "p1", "value": 80.0, "destination_team": "CHI"}],
				"gains": []
			}
		}
	}

	var world_state1 := {"fa_transaction_tracking": tracking.duplicate(true)}
	var world_state2 := {"fa_transaction_tracking": tracking.duplicate(true)}

	var league_cfg := _make_league_config()

	var comp_picks1 := NflDraft.calculate_compensatory_picks(world_state1, 2025, league_cfg)
	var comp_picks2 := NflDraft.calculate_compensatory_picks(world_state2, 2025, league_cfg)

	assert_int(comp_picks1.size()).is_equal(comp_picks2.size())
	assert_str(String(comp_picks1[0].get("team_id"))).is_equal(String(comp_picks2[0].get("team_id")))
	assert_int(int(comp_picks1[0].get("round"))).is_equal(int(comp_picks2[0].get("round")))


# --- Helper functions ---

func _make_league_config() -> Dictionary:
	return {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"elite_comp_round": 3,
			"starter_comp_round": 4,
			"depth_comp_round": 5,
			"max_per_team": 4
		}
	}
