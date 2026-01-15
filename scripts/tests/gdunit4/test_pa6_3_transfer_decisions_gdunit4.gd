## GdUnit4 test suite for PA6.3: Transfer Decisions Based on Satisfaction
##
## Validates that:
##   - Transfer probability scales with morale (low morale = high transfer chance)
##   - Seniors never transfer (graduating)
##   - Transfer decisions are deterministic with same RNG seed
##   - Transfer portal stores players correctly
extends GdUnitTestSuite

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")
const Rand = preload("res://autoloads/Rand.gd")


func test_transfer_probability_high_morale() -> void:
	var player := {"player_id": "player_001", "morale": 75.0, "college_year": 2}

	var prob := PlayerMorale.calculate_transfer_probability(player)

	assert_float(prob).is_equal(0.05)


func test_transfer_probability_neutral_morale() -> void:
	var player := {"player_id": "player_002", "morale": 55.0, "college_year": 2}

	var prob := PlayerMorale.calculate_transfer_probability(player)

	assert_float(prob).is_equal(0.15)


func test_transfer_probability_low_morale() -> void:
	var player := {"player_id": "player_003", "morale": 30.0, "college_year": 2}

	var prob := PlayerMorale.calculate_transfer_probability(player)

	assert_float(prob).is_equal(0.40)


func test_transfer_probability_seniors_never_transfer() -> void:
	var player := {"player_id": "player_004", "morale": 20.0, "college_year": 4}

	var prob := PlayerMorale.calculate_transfer_probability(player)

	assert_float(prob).is_equal(0.0)


func test_should_transfer_deterministic() -> void:
	var player := {"player_id": "player_005", "morale": 55.0, "college_year": 2}
	var seed := 12345

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = Rand.splitmix64(seed)
	var result1 := PlayerMorale.should_transfer(player, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = Rand.splitmix64(seed)
	var result2 := PlayerMorale.should_transfer(player, rng2)

	var rng3 := RandomNumberGenerator.new()
	rng3.seed = Rand.splitmix64(seed)
	var result3 := PlayerMorale.should_transfer(player, rng3)

	assert_bool(result1).is_equal(result2)
	assert_bool(result2).is_equal(result3)


func test_should_transfer_low_morale_high_chance() -> void:
	var player := {"player_id": "player_006", "morale": 30.0, "college_year": 2}
	var seed := 99999

	var transfer_count := 0
	for i in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = Rand.splitmix64(seed + i)
		if PlayerMorale.should_transfer(player, rng):
			transfer_count += 1

	var transfer_rate := float(transfer_count) / 100.0
	assert_float(transfer_rate).is_greater_equal(0.30)
	assert_float(transfer_rate).is_less_equal(0.50)


func test_should_transfer_high_morale_low_chance() -> void:
	var player := {"player_id": "player_007", "morale": 75.0, "college_year": 2}
	var seed := 55555

	var transfer_count := 0
	for i in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = Rand.splitmix64(seed + i)
		if PlayerMorale.should_transfer(player, rng):
			transfer_count += 1

	var transfer_rate := float(transfer_count) / 100.0
	assert_float(transfer_rate).is_greater_equal(0.0)
	assert_float(transfer_rate).is_less_equal(0.12)


func test_determine_transfers_returns_correct_players() -> void:
	var players := [
		{"player_id": "player_008", "morale": 30.0, "college_year": 2},  # Low morale
		{"player_id": "player_009", "morale": 75.0, "college_year": 2},  # High morale
		{"player_id": "player_010", "morale": 25.0, "college_year": 4}   # Senior (never transfers)
	]
	var seed := 77777

	var transfer_counts := {"player_008": 0, "player_009": 0, "player_010": 0}
	for i in range(20):
		var rng := RandomNumberGenerator.new()
		rng.seed = Rand.splitmix64(seed + i)
		var transfer_players := PlayerMorale.determine_transfers(players, rng)

		for player in transfer_players:
			var p: Dictionary = player
			var pid := String(p.get("player_id", ""))
			if transfer_counts.has(pid):
				transfer_counts[pid] += 1

	assert_int(int(transfer_counts["player_008"])).is_greater(0)
	assert_int(int(transfer_counts["player_010"])).is_equal(0)


func test_determine_transfers_empty_roster() -> void:
	var players := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var transfer_players := PlayerMorale.determine_transfers(players, rng)

	assert_int(transfer_players.size()).is_equal(0)


func test_transfer_probability_boundary_conditions() -> void:
	var player_at_70 := {"player_id": "player_011", "morale": 70.0, "college_year": 2}
	var prob_70 := PlayerMorale.calculate_transfer_probability(player_at_70)
	assert_float(prob_70).is_equal(0.15)

	var player_at_40 := {"player_id": "player_012", "morale": 40.0, "college_year": 2}
	var prob_40 := PlayerMorale.calculate_transfer_probability(player_at_40)
	assert_float(prob_40).is_equal(0.15)

	var player_below_40 := {"player_id": "player_013", "morale": 39.9, "college_year": 2}
	var prob_below := PlayerMorale.calculate_transfer_probability(player_below_40)
	assert_float(prob_below).is_equal(0.40)

	var player_above_70 := {"player_id": "player_014", "morale": 70.1, "college_year": 2}
	var prob_above := PlayerMorale.calculate_transfer_probability(player_above_70)
	assert_float(prob_above).is_equal(0.05)
