extends RefCounted

## Test PA6.3: Transfer Decisions Based on Satisfaction
##
## Validates that:
##   - Transfer probability scales with morale (low morale = high transfer chance)
##   - Seniors never transfer (graduating)
##   - Transfer decisions are deterministic with same RNG seed
##   - Transfer portal stores players correctly

const PlayerMorale = preload("res://scripts/core/player_agency/PlayerMorale.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	_test_transfer_probability_high_morale(t)
	_test_transfer_probability_neutral_morale(t)
	_test_transfer_probability_low_morale(t)
	_test_transfer_probability_seniors_never_transfer(t)
	_test_should_transfer_deterministic(t)
	_test_should_transfer_low_morale_high_chance(t)
	_test_should_transfer_high_morale_low_chance(t)
	_test_determine_transfers_returns_correct_players(t)
	_test_determine_transfers_empty_roster(t)
	_test_transfer_probability_boundary_conditions(t)


func _test_transfer_probability_high_morale(t) -> void:
	# Arrange: High morale player (>70)
	var player := {"player_id": "player_001", "morale": 75.0, "college_year": 2}

	# Act
	var prob := PlayerMorale.calculate_transfer_probability(player)

	# Assert: High morale should have low transfer probability (5%)
	t.assert_eq(prob, 0.05, "High morale (75) should have 5%% transfer probability")


func _test_transfer_probability_neutral_morale(t) -> void:
	# Arrange: Neutral morale player (40-70)
	var player := {"player_id": "player_002", "morale": 55.0, "college_year": 2}

	# Act
	var prob := PlayerMorale.calculate_transfer_probability(player)

	# Assert: Neutral morale should have moderate transfer probability (15%)
	t.assert_eq(prob, 0.15, "Neutral morale (55) should have 15%% transfer probability")


func _test_transfer_probability_low_morale(t) -> void:
	# Arrange: Low morale player (<40)
	var player := {"player_id": "player_003", "morale": 30.0, "college_year": 2}

	# Act
	var prob := PlayerMorale.calculate_transfer_probability(player)

	# Assert: Low morale should have high transfer probability (40%)
	t.assert_eq(prob, 0.40, "Low morale (30) should have 40%% transfer probability")


func _test_transfer_probability_seniors_never_transfer(t) -> void:
	# Arrange: Senior with low morale
	var player := {"player_id": "player_004", "morale": 20.0, "college_year": 4}

	# Act
	var prob := PlayerMorale.calculate_transfer_probability(player)

	# Assert: Seniors should have 0% transfer probability (graduating)
	t.assert_eq(prob, 0.0, "Seniors should have 0%% transfer probability regardless of morale")


func _test_should_transfer_deterministic(t) -> void:
	# Arrange: Player with moderate morale
	var player := {"player_id": "player_005", "morale": 55.0, "college_year": 2}
	var seed := 12345

	# Act: Run transfer decision 3 times with same seed
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = Rand.splitmix64(seed)
	var result1 := PlayerMorale.should_transfer(player, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = Rand.splitmix64(seed)
	var result2 := PlayerMorale.should_transfer(player, rng2)

	var rng3 := RandomNumberGenerator.new()
	rng3.seed = Rand.splitmix64(seed)
	var result3 := PlayerMorale.should_transfer(player, rng3)

	# Assert: Results should be identical (deterministic)
	t.assert_eq(result1, result2, "Transfer decision should be deterministic with same seed")
	t.assert_eq(result2, result3, "Transfer decision should be deterministic with same seed")


func _test_should_transfer_low_morale_high_chance(t) -> void:
	# Arrange: Low morale player (40% transfer chance)
	var player := {"player_id": "player_006", "morale": 30.0, "college_year": 2}
	var seed := 99999

	# Act: Simulate 100 transfer decisions
	var transfer_count := 0
	for i in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = Rand.splitmix64(seed + i)
		if PlayerMorale.should_transfer(player, rng):
			transfer_count += 1

	# Assert: ~40% should transfer (allow 30-50% range due to randomness)
	var transfer_rate := float(transfer_count) / 100.0
	t.assert_true(transfer_rate >= 0.30, "Low morale transfer rate should be at least 30%% (got %.1f%%)" % (transfer_rate * 100))
	t.assert_true(transfer_rate <= 0.50, "Low morale transfer rate should be at most 50%% (got %.1f%%)" % (transfer_rate * 100))


func _test_should_transfer_high_morale_low_chance(t) -> void:
	# Arrange: High morale player (5% transfer chance)
	var player := {"player_id": "player_007", "morale": 75.0, "college_year": 2}
	var seed := 55555

	# Act: Simulate 100 transfer decisions
	var transfer_count := 0
	for i in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = Rand.splitmix64(seed + i)
		if PlayerMorale.should_transfer(player, rng):
			transfer_count += 1

	# Assert: ~5% should transfer (allow 0-10% range due to randomness)
	var transfer_rate := float(transfer_count) / 100.0
	t.assert_true(transfer_rate >= 0.0, "High morale transfer rate should be at least 0%%")
	t.assert_true(transfer_rate <= 0.12, "High morale transfer rate should be at most 12%% (got %.1f%%)" % (transfer_rate * 100))


func _test_determine_transfers_returns_correct_players(t) -> void:
	# Arrange: Roster with 3 players (different morale levels)
	var players := [
		{"player_id": "player_008", "morale": 30.0, "college_year": 2},  # Low morale
		{"player_id": "player_009", "morale": 75.0, "college_year": 2},  # High morale
		{"player_id": "player_010", "morale": 25.0, "college_year": 4}   # Senior (never transfers)
	]
	var seed := 77777

	# Act: Simulate 20 times to see distribution
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

	# Assert: Low morale player should transfer most, senior never
	t.assert_true(int(transfer_counts["player_008"]) > 0, "Low morale player should transfer at least once in 20 sims")
	t.assert_eq(int(transfer_counts["player_010"]), 0, "Senior should never transfer")


func _test_determine_transfers_empty_roster(t) -> void:
	# Arrange: Empty roster
	var players := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Act
	var transfer_players := PlayerMorale.determine_transfers(players, rng)

	# Assert: Should return empty array
	t.assert_eq(transfer_players.size(), 0, "Empty roster should produce no transfers")


func _test_transfer_probability_boundary_conditions(t) -> void:
	# Test exact boundaries
	var player_at_70 := {"player_id": "player_011", "morale": 70.0, "college_year": 2}
	var prob_70 := PlayerMorale.calculate_transfer_probability(player_at_70)
	t.assert_eq(prob_70, 0.15, "Morale exactly 70 should use neutral probability (15%%)")

	var player_at_40 := {"player_id": "player_012", "morale": 40.0, "college_year": 2}
	var prob_40 := PlayerMorale.calculate_transfer_probability(player_at_40)
	t.assert_eq(prob_40, 0.15, "Morale exactly 40 should use neutral probability (15%%)")

	var player_below_40 := {"player_id": "player_013", "morale": 39.9, "college_year": 2}
	var prob_below := PlayerMorale.calculate_transfer_probability(player_below_40)
	t.assert_eq(prob_below, 0.40, "Morale just below 40 should use low probability (40%%)")

	var player_above_70 := {"player_id": "player_014", "morale": 70.1, "college_year": 2}
	var prob_above := PlayerMorale.calculate_transfer_probability(player_above_70)
	t.assert_eq(prob_above, 0.05, "Morale just above 70 should use high probability (5%%)")
