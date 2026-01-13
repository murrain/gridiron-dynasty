extends RefCounted

## Unit tests for Feature 4: Compensatory Picks
##
## Tests compensatory pick calculation and insertion based on FA losses.
## All tests verify deterministic behavior and proper round assignment.

const NflDraft = preload("res://scripts/world/NflDraft.gd")
const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

## Test: track_free_agent_transactions records signings correctly
static func test_track_fa_transactions() -> Dictionary:
	var world_state := {}
	var year := 2024
	var signings := [
		{
			"player_id": "player1",
			"team_id": "CHI",
			"previous_team_id": "SF",
			"player_value": 80.0
		},
		{
			"player_id": "player2",
			"team_id": "NYJ",
			"previous_team_id": "SF",
			"player_value": 75.0
		}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	# Verify structure
	assert(world_state.has("fa_transaction_tracking"), "Should create tracking structure")
	var tracking: Dictionary = world_state["fa_transaction_tracking"]
	assert(tracking.has(year), "Should have year entry")

	var year_tracking: Dictionary = tracking[year]

	# Verify SF losses
	assert(year_tracking.has("SF"), "SF should have tracking entry")
	var sf_data: Dictionary = year_tracking["SF"]
	var sf_losses: Array = sf_data.get("losses", [])
	assert(sf_losses.size() == 2, "SF should have 2 losses")

	# Verify CHI gains
	assert(year_tracking.has("CHI"), "CHI should have tracking entry")
	var chi_data: Dictionary = year_tracking["CHI"]
	var chi_gains: Array = chi_data.get("gains", [])
	assert(chi_gains.size() == 1, "CHI should have 1 gain")
	var chi_gain: Dictionary = chi_gains[0]
	assert(chi_gain.get("player_id") == "player1", "CHI gained player1")
	assert(chi_gain.get("origin_team") == "SF", "Came from SF")

	return {"passed": true, "message": "track_free_agent_transactions works correctly"}


## Test: track_free_agent_transactions skips rookie FAs
static func test_track_fa_transactions_skips_rookies() -> Dictionary:
	var world_state := {}
	var year := 2024
	var signings := [
		{
			"player_id": "rookie1",
			"team_id": "CHI",
			"previous_team_id": "UNDRAFTED",
			"player_value": 60.0
		},
		{
			"player_id": "rookie2",
			"team_id": "NYJ",
			"previous_team_id": "",
			"player_value": 55.0
		}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var tracking: Dictionary = world_state.get("fa_transaction_tracking", {})
	var year_tracking: Dictionary = tracking.get(year, {})

	# Should not track UNDRAFTED or empty previous teams
	assert(not year_tracking.has("UNDRAFTED"), "Should not track UNDRAFTED")
	assert(year_tracking.is_empty(), "Should have no tracking for rookies")

	return {"passed": true, "message": "Skips tracking for rookie free agents"}


## Test: track_free_agent_transactions skips re-signings
static func test_track_fa_transactions_skips_resignings() -> Dictionary:
	var world_state := {}
	var year := 2024
	var signings := [
		{
			"player_id": "player1",
			"team_id": "SF",
			"previous_team_id": "SF",
			"player_value": 80.0
		}
	]

	NflDraft.track_free_agent_transactions(world_state, year, signings)

	var tracking: Dictionary = world_state.get("fa_transaction_tracking", {})
	var year_tracking: Dictionary = tracking.get(year, {})

	# Should not track when player re-signs with same team
	assert(year_tracking.is_empty(), "Should not track re-signings")

	return {"passed": true, "message": "Skips tracking for re-signings"}


## Test: calculate_compensatory_picks awards picks for net losses
static func test_calculate_comp_picks_net_loss() -> Dictionary:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [
						{"player_id": "player1", "value": 80.0, "destination_team": "CHI"}
					],
					"gains": []
				}
			}
		}
	}
	var year := 2025  # Comp picks awarded year after FA
	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"elite_comp_round": 3,
			"starter_comp_round": 4,
			"depth_comp_round": 5,
			"max_per_team": 4
		}
	}

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	assert(comp_picks.size() == 1, "Should award 1 comp pick")

	var pick: Dictionary = comp_picks[0]
	assert(pick.get("team_id") == "SF", "Pick awarded to SF")
	assert(pick.get("year") == 2025, "Pick for 2025 draft")
	assert(pick.get("round") == 3, "Elite player (80+) = Round 3")
	assert(pick.get("player_lost_id") == "player1", "For losing player1")
	assert(pick.get("compensatory") == true, "Marked as compensatory")

	return {"passed": true, "message": "Calculates comp picks for net losses"}


## Test: calculate_compensatory_picks respects net loss threshold
static func test_calculate_comp_picks_threshold() -> Dictionary:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [
						{"player_id": "player1", "value": 65.0, "destination_team": "CHI"}
					],
					"gains": [
						{"player_id": "player2", "value": 60.0, "origin_team": "NYJ"}
					]
				}
			}
		}
	}
	var year := 2025
	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"max_per_team": 4
		}
	}

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Net loss = 65 - 60 = 5, below threshold of 50
	assert(comp_picks.is_empty(), "No comp picks for net loss below threshold")

	return {"passed": true, "message": "Respects net loss threshold"}


## Test: calculate_compensatory_picks assigns correct rounds by value
static func test_calculate_comp_picks_round_assignment() -> Dictionary:
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
	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"elite_comp_round": 3,
			"starter_comp_round": 4,
			"depth_comp_round": 5,
			"max_per_team": 4
		}
	}

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	assert(comp_picks.size() == 3, "Should award 3 comp picks")

	# Verify round assignments
	var elite_pick: Dictionary = comp_picks[0]
	assert(elite_pick.get("round") == 3, "Elite (85) gets Round 3")

	var starter_pick: Dictionary = comp_picks[1]
	assert(starter_pick.get("round") == 4, "Starter (75) gets Round 4")

	var depth_pick: Dictionary = comp_picks[2]
	assert(depth_pick.get("round") == 5, "Depth (65) gets Round 5")

	return {"passed": true, "message": "Assigns comp pick rounds correctly by player value"}


## Test: calculate_compensatory_picks caps at max per team
static func test_calculate_comp_picks_max_cap() -> Dictionary:
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
	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"elite_comp_round": 3,
			"starter_comp_round": 4,
			"max_per_team": 4
		}
	}

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Should cap at 4 despite 5 losses
	assert(comp_picks.size() == 4, "Should cap at max_per_team (4)")

	return {"passed": true, "message": "Caps comp picks at max per team"}


## Test: calculate_compensatory_picks ignores low-value losses
static func test_calculate_comp_picks_ignores_low_value() -> Dictionary:
	var world_state := {
		"fa_transaction_tracking": {
			2024: {
				"SF": {
					"losses": [
						{"player_id": "scrub", "value": 55.0, "destination_team": "CHI"}
					],
					"gains": []
				}
			}
		}
	}
	var year := 2025
	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"depth_comp_round": 5,
			"max_per_team": 4
		}
	}

	var comp_picks := NflDraft.calculate_compensatory_picks(world_state, year, league_cfg)

	# Player value 55 is below depth threshold (60), no comp pick
	assert(comp_picks.is_empty(), "No comp picks for low-value losses (<60)")

	return {"passed": true, "message": "Ignores losses below minimum value threshold"}


## Test: insert_compensatory_picks adds picks to round
static func test_insert_comp_picks() -> Dictionary:
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

	# Should have original 2 picks + 1 comp pick
	assert(modified_picks.size() == 3, "Should have 3 total picks")

	# Comp pick should be at end
	var comp_pick: Dictionary = modified_picks[2]
	assert(comp_pick.get("pick_number") == 3, "Comp pick should be #3")
	assert(comp_pick.get("current_owner_id") == "BAL", "BAL owns comp pick")
	assert(comp_pick.get("compensatory") == true, "Marked as compensatory")
	assert(comp_pick.get("traded") == false, "Comp picks start untraded")

	return {"passed": true, "message": "insert_compensatory_picks works correctly"}


## Test: insert_compensatory_picks filters by round
static func test_insert_comp_picks_filters_by_round() -> Dictionary:
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
	assert(modified_picks.size() == 2, "Should have 1 regular + 1 round 3 comp")

	var comp_pick: Dictionary = modified_picks[1]
	assert(comp_pick.get("current_owner_id") == "BAL", "Only BAL's round 3 pick inserted")

	return {"passed": true, "message": "Filters comp picks by round correctly"}


## Test: Determinism - same FA tracking produces same comp picks
static func test_determinism() -> Dictionary:
	var tracking := {
		2024: {
			"SF": {
				"losses": [
					{"player_id": "p1", "value": 80.0, "destination_team": "CHI"}
				],
				"gains": []
			}
		}
	}

	var world_state1 := {"fa_transaction_tracking": tracking.duplicate(true)}
	var world_state2 := {"fa_transaction_tracking": tracking.duplicate(true)}

	var league_cfg := {
		"compensatory_picks": {
			"enabled": true,
			"net_loss_threshold": 50.0,
			"elite_comp_round": 3,
			"max_per_team": 4
		}
	}

	var comp_picks1 := NflDraft.calculate_compensatory_picks(world_state1, 2025, league_cfg)
	var comp_picks2 := NflDraft.calculate_compensatory_picks(world_state2, 2025, league_cfg)

	# Verify identical results
	assert(comp_picks1.size() == comp_picks2.size(), "Same size")
	assert(comp_picks1[0].get("team_id") == comp_picks2[0].get("team_id"), "Same team")
	assert(comp_picks1[0].get("round") == comp_picks2[0].get("round"), "Same round")

	return {"passed": true, "message": "Comp pick calculation is deterministic"}


## Run all tests
static func run_all_tests() -> Dictionary:
	var tests := [
		test_track_fa_transactions,
		test_track_fa_transactions_skips_rookies,
		test_track_fa_transactions_skips_resignings,
		test_calculate_comp_picks_net_loss,
		test_calculate_comp_picks_threshold,
		test_calculate_comp_picks_round_assignment,
		test_calculate_comp_picks_max_cap,
		test_calculate_comp_picks_ignores_low_value,
		test_insert_comp_picks,
		test_insert_comp_picks_filters_by_round,
		test_determinism
	]

	var results := []
	var passed := 0
	var failed := 0

	for test_func in tests:
		var result: Dictionary = test_func.call()
		results.append(result)
		if result.get("passed", false):
			passed += 1
		else:
			failed += 1
			print("FAILED: ", result.get("message", "Unknown test"))

	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"results": results
	}
