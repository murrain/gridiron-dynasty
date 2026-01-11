extends SceneTree

## Test script for A2 and A4 optimizations determinism verification
##
## Validates that:
## 1. A2 (Pre-compute Team Strengths) produces identical results
## 2. A4 (Batch Morale Updates) produces identical morale/satisfaction values
## 3. Both optimizations preserve determinism across multiple runs
##
## Usage: godot --headless -s res://scripts/tests/test_a2_a4_optimizations.gd

const GameSimulator = preload("res://scripts/core/game_simulation/GameSimulator.gd")
const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")

func _initialize():
	print("=" .repeat(80))
	print("Testing A2 and A4 Optimizations - Determinism Verification")
	print("=" .repeat(80))

	var all_tests_passed := true

	# Test A2: Team Strength Caching
	print("\n[Test 1] A2: Team Strength Pre-computation")
	if not test_team_strength_caching():
		all_tests_passed = false
		print("❌ FAILED: Team strength caching produces different results")
	else:
		print("✓ PASSED: Team strength caching is deterministic")

	# Test A4: Batch Morale Updates
	print("\n[Test 2] A4: Batch Morale Updates")
	if not test_batch_morale_updates():
		all_tests_passed = false
		print("❌ FAILED: Batch morale updates produce different results")
	else:
		print("✓ PASSED: Batch morale updates are deterministic")

	# Summary
	print("\n" + "=" .repeat(80))
	if all_tests_passed:
		print("✓ ALL TESTS PASSED - Optimizations preserve determinism")
	else:
		print("❌ SOME TESTS FAILED - Review implementation")
	print("=" .repeat(80))

	quit(0 if all_tests_passed else 1)


## Test A2: Team strength pre-computation produces identical results
func test_team_strength_caching() -> bool:
	# Create mock data
	var positions_cfg := {
		"QB": {"attributes": ["throwing_power", "throwing_accuracy"]},
		"RB": {"attributes": ["speed", "strength"]},
		"WR": {"attributes": ["speed", "catching"]}
	}

	var main_cfg := {
		"class_rules": {
			"freshman": {"eligibility": true},
			"sophomore": {"eligibility": true}
		}
	}

	# Create mock rosters
	var rosters := {
		"team1": {
			"players": [
				{"player_id": "p1", "position": "QB", "throwing_power": 80, "throwing_accuracy": 85, "college_year": 2},
				{"player_id": "p2", "position": "RB", "speed": 75, "strength": 70, "college_year": 1}
			]
		},
		"team2": {
			"players": [
				{"player_id": "p3", "position": "QB", "throwing_power": 70, "throwing_accuracy": 75, "college_year": 3},
				{"player_id": "p4", "position": "WR", "speed": 85, "catching": 80, "college_year": 2}
			]
		}
	}

	var team_ids := ["team1", "team2"]

	# Run batch calculation multiple times
	var results := []
	for i in range(3):
		var strengths := GameSimulator.calculate_all_team_strengths(
			team_ids,
			rosters,
			positions_cfg,
			main_cfg
		)
		results.append(strengths)

	# Verify all results are identical
	for i in range(1, results.size()):
		if not _compare_dictionaries(results[0], results[i]):
			print("  Mismatch between run 0 and run %d" % i)
			print("  Run 0: %s" % str(results[0]))
			print("  Run %d: %s" % [i, str(results[i])])
			return false

	print("  Team strengths consistent across 3 runs")
	return true


## Test A4: Batch morale updates produce identical results to original method
func test_batch_morale_updates() -> bool:
	# Create mock player data
	var players := [
		{
			"player_id": "p1",
			"position": "QB",
			"college_year": 2,
			"morale": 50.0,
			"satisfaction": 50.0
		},
		{
			"player_id": "p2",
			"position": "RB",
			"college_year": 1,
			"morale": 60.0,
			"satisfaction": 55.0
		}
	]

	var year := 2024

	# Mock player career stats
	var player_career_stats := {
		"p1": {
			"2024": {
				"games_played": 12,
				"games_started": 10,
				"position": "QB",
				"team_id": "team1"
			}
		},
		"p2": {
			"2024": {
				"games_played": 8,
				"games_started": 2,
				"position": "RB",
				"team_id": "team1"
			}
		}
	}

	# Mock awards structure
	var awards := {
		"awards": {
			"2024": {
				"opoy": {"player_id": "p1"},
				"dpoy": {"player_id": ""},
				"oroy": {"player_id": ""},
				"droy": {"player_id": ""}
			}
		},
		"all_pro_teams": {
			"2024": {
				"first_team": [{"player_id": "p1"}],
				"second_team": []
			}
		},
		"pro_bowl_rosters": {
			"2024": {
				"afc": [],
				"nfc": []
			}
		}
	}

	# Mock team record
	var team_record := {
		"wins": 10,
		"losses": 2,
		"is_champion": true,
		"playoff_appearance": true
	}

	# Test 1: Original method
	var players_original := []
	for p in players:
		players_original.append(p.duplicate(true))

	var result_original := PlayerMorale.update_team_morale(
		players_original,
		year,
		player_career_stats,
		awards,
		team_record
	)

	# Test 2: Batched method
	var players_batched := []
	for p in players:
		players_batched.append(p.duplicate(true))

	var batched_data := PlayerMorale.prepare_team_batched_data(
		players_batched,
		year,
		player_career_stats,
		awards,
		team_record
	)

	var result_batched := PlayerMorale.update_team_morale_batched(
		players_batched,
		year,
		batched_data
	)

	# Compare results
	var results_match := true

	# Check summary stats
	if not _compare_floats(result_original["avg_satisfaction"], result_batched["avg_satisfaction"]):
		print("  Avg satisfaction mismatch: %f vs %f" % [result_original["avg_satisfaction"], result_batched["avg_satisfaction"]])
		results_match = false

	if not _compare_floats(result_original["avg_morale"], result_batched["avg_morale"]):
		print("  Avg morale mismatch: %f vs %f" % [result_original["avg_morale"], result_batched["avg_morale"]])
		results_match = false

	# Check individual player values
	for i in range(players.size()):
		var orig: Dictionary = players_original[i]
		var batch: Dictionary = players_batched[i]

		if not _compare_floats(float(orig["satisfaction"]), float(batch["satisfaction"])):
			print("  Player %s satisfaction mismatch: %f vs %f" % [orig["player_id"], orig["satisfaction"], batch["satisfaction"]])
			results_match = false

		if not _compare_floats(float(orig["morale"]), float(batch["morale"])):
			print("  Player %s morale mismatch: %f vs %f" % [orig["player_id"], orig["morale"], batch["morale"]])
			results_match = false

	if results_match:
		print("  Original and batched methods produce identical results")
		print("  Player 1 (OPOY winner): satisfaction=%.2f, morale=%.2f" % [players_batched[0]["satisfaction"], players_batched[0]["morale"]])
		print("  Player 2 (backup): satisfaction=%.2f, morale=%.2f" % [players_batched[1]["satisfaction"], players_batched[1]["morale"]])

	return results_match


## Helper: Compare two dictionaries for equality
func _compare_dictionaries(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false

	for key in a.keys():
		if not b.has(key):
			return false

		var val_a = a[key]
		var val_b = b[key]

		if typeof(val_a) == TYPE_FLOAT or typeof(val_a) == TYPE_INT:
			if not _compare_floats(float(val_a), float(val_b)):
				return false
		elif val_a != val_b:
			return false

	return true


## Helper: Compare two floats with epsilon tolerance
func _compare_floats(a: float, b: float, epsilon: float = 0.0001) -> bool:
	return abs(a - b) < epsilon
