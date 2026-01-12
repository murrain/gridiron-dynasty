extends RefCounted

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")

## Test configuration replicating production valuation.json
func _get_test_config() -> Dictionary:
	return {
		"value_curve": {
			"curve_type": "tiered_exponential",
			"base_value": 1.0,
			"tiers": [
				{"min": 0, "max": 60, "multiplier": 0.5, "exponent": 1.0},
				{"min": 60, "max": 75, "multiplier": 1.0, "exponent": 1.3},
				{"min": 75, "max": 85, "multiplier": 2.0, "exponent": 1.8},
				{"min": 85, "max": 92, "multiplier": 4.0, "exponent": 2.2},
				{"min": 92, "max": 100, "multiplier": 10.0, "exponent": 3.0}
			],
			"elite_threshold": 92,
			"elite_multiplier_boost": 1.5
		},
		"replacement_levels": {
			"QB": 55.0,
			"RB": 62.0,
			"WR": 58.0,
			"TE": 56.0,
			"OL": 54.0,
			"DL": 57.0,
			"EDGE": 52.0,
			"LB": 58.0,
			"CB": 53.0,
			"S": 57.0,
			"K": 65.0,
			"P": 65.0,
			"ATH": 55.0
		},
		"scarcity": {
			"scarcity_min": 0.7,
			"scarcity_max": 1.5
		},
		"team_impact": {
			"no_backup_multiplier": 1.4,
			"thin_depth_multiplier": 1.15,
			"position_win_impacts": {
				"QB": 2.5,
				"EDGE": 1.4,
				"CB": 1.3,
				"WR": 1.2,
				"OL": 1.1,
				"DL": 1.1,
				"LB": 1.0,
				"S": 0.95,
				"TE": 0.9,
				"RB": 0.8,
				"K": 0.5,
				"P": 0.4
			}
		},
		"age_multipliers": [
			{"min": 18, "max": 20, "mult": 1.12},
			{"min": 21, "max": 24, "mult": 1.05},
			{"min": 25, "max": 27, "mult": 1.00},
			{"min": 28, "max": 30, "mult": 0.90},
			{"min": 31, "max": 34, "mult": 0.80},
			{"min": 35, "max": 50, "mult": 0.65}
		],
		"range_spread_pct": 0.18,
		"market": {
			"range_spread_pct": 0.18
		}
	}


func run(t) -> void:
	_test_elite_player_premium(t)
	_test_positional_scarcity_impact(t)
	_test_age_multiplier_impact(t)
	_test_young_vs_old_players(t)


## Test that elite players (95+ rating) are worth 5-10x more than average (75 rating)
func _test_elite_player_premium(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Average player (75 rating)
	var avg_player := {
		"id": "player_avg",
		"position": "QB",
		"age": 25,
		"eval_score": 75.0
	}

	# Elite player (98 rating)
	var elite_player := {
		"id": "player_elite",
		"position": "QB",
		"age": 25,
		"eval_score": 98.0
	}

	var context := {
		"position_supply": {
			"QB": 32  # Normal supply (1 per team)
		}
	}

	var avg_result := PlayerValue.calculate(avg_player, context, config, rng)
	var elite_result := PlayerValue.calculate(elite_player, context, config, rng)

	var ratio: float = elite_result.market_value / maxf(avg_result.market_value, 0.001)

	# Elite player should be worth at least 5x average player (acceptance criteria)
	t.assert_true(ratio >= 5.0,
		"Elite player (98) should be worth at least 5x average (75), got %.2fx" % ratio)

	# Ratio should be reasonable (not absurdly high)
	t.assert_true(ratio <= 20.0,
		"Elite player premium should be reasonable (<20x), got %.2fx" % ratio)


## Test positional scarcity impact on valuation
func _test_positional_scarcity_impact(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var player := {
		"id": "player_001",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Scenario 1: High scarcity (low supply)
	var scarce_context := {
		"position_supply": {
			"QB": 20  # Only 20 QBs, need 32 starters
		}
	}

	var scarce_result := PlayerValue.calculate(player, scarce_context, config, rng)

	# Scenario 2: Abundant supply
	var abundant_context := {
		"position_supply": {
			"QB": 60  # 60 QBs, only need 32
		}
	}

	var abundant_result := PlayerValue.calculate(player, abundant_context, config, rng)

	# Scarce position should have higher market value
	t.assert_true(scarce_result.market_value > abundant_result.market_value,
		"Scarce position should have higher market value")

	# Verify scarcity multipliers are different
	t.assert_true(scarce_result.scarcity_multiplier > abundant_result.scarcity_multiplier,
		"Scarce position should have higher scarcity multiplier")


## Test age multiplier impact on valuation
func _test_age_multiplier_impact(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Young player (22 years old)
	var young_player := {
		"id": "player_young",
		"position": "QB",
		"age": 22,
		"eval_score": 85.0
	}

	# Prime age player (25 years old)
	var prime_player := {
		"id": "player_prime",
		"position": "QB",
		"age": 25,
		"eval_score": 85.0
	}

	# Older player (32 years old)
	var old_player := {
		"id": "player_old",
		"position": "QB",
		"age": 32,
		"eval_score": 85.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var young_result := PlayerValue.calculate(young_player, context, config, rng)
	var prime_result := PlayerValue.calculate(prime_player, context, config, rng)
	var old_result := PlayerValue.calculate(old_player, context, config, rng)

	# Young player should have premium over prime age
	t.assert_true(young_result.age_multiplier > prime_result.age_multiplier,
		"Young player should have age premium over prime")

	# Prime age should be better than older player
	t.assert_true(prime_result.age_multiplier > old_result.age_multiplier,
		"Prime age should have higher multiplier than older player")

	# Market values should reflect age differences
	t.assert_true(young_result.market_value > prime_result.market_value,
		"Young player should have higher market value (same skill, better age)")
	t.assert_true(prime_result.market_value > old_result.market_value,
		"Prime player should have higher market value than older player")


## Test young vs old player value comparison
func _test_young_vs_old_players(t) -> void:
	var config := _get_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# 22-year-old with good score
	var young := {
		"id": "young",
		"position": "QB",
		"age": 22,
		"eval_score": 82.0
	}

	# 33-year-old with better score (but old)
	var old := {
		"id": "old",
		"position": "QB",
		"age": 33,
		"eval_score": 88.0
	}

	var context := {
		"position_supply": {"QB": 32}
	}

	var young_result := PlayerValue.calculate(young, context, config, rng)
	var old_result := PlayerValue.calculate(old, context, config, rng)

	# Young player has age advantage (1.05 vs 0.80)
	t.assert_approx(young_result.age_multiplier, 1.05, 0.001, "Young player age mult")
	t.assert_approx(old_result.age_multiplier, 0.80, 0.001, "Old player age mult")

	# Despite lower eval_score, young player might be competitive due to age
	# This depends on the specific numbers, but we can verify the age impact
	var young_value_without_age: float = young_result.market_value / young_result.age_multiplier
	var old_value_without_age: float = old_result.market_value / old_result.age_multiplier

	# Old player should have higher base value (better eval_score)
	t.assert_true(old_value_without_age > young_value_without_age,
		"Higher eval_score produces higher base value")
