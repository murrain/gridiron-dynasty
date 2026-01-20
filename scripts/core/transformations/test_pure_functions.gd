extends RefCounted

## Simple verification test for pure function layer
## Verifies immutability, determinism, and basic functionality

static func run_tests() -> void:
	print("=== Testing Pure Function Layer ===\n")

	test_age_functions()
	test_growth_functions()
	test_stage_pipeline()

	print("\n=== All Tests Passed! ===")


static func test_age_functions() -> void:
	print("Testing AgeFunctions...")

	# Test increment_age immutability
	var player := {"age": 22, "name": "John Doe"}
	var new_player := AgeFunctions.increment_age(player)

	assert(player["age"] == 22, "Original player age should be unchanged")
	assert(new_player["age"] == 23, "New player age should be incremented")
	assert(player["name"] == "John Doe", "Other fields should be preserved")

	# Test get_lifecycle_phase
	var configs := {
		"positions": {
			"QB": {
				"development": {
					"peak_age": 28,
					"decline_start": 33
				}
			}
		}
	}

	assert(AgeFunctions.get_lifecycle_phase(24, "QB", configs) == "growth")
	assert(AgeFunctions.get_lifecycle_phase(30, "QB", configs) == "prime")
	assert(AgeFunctions.get_lifecycle_phase(35, "QB", configs) == "decline")

	print("  ✓ AgeFunctions tests passed")


static func test_growth_functions() -> void:
	print("Testing GrowthFunctions...")

	# Create minimal test player
	var player := {
		"age": 22,
		"position": "WR",
		"stats": {
			"speed": 70.0,
			"acceleration": 75.0
		},
		"potential": {
			"speed": 85.0,
			"acceleration": 90.0
		}
	}

	# Minimal configs
	var configs := {
		"positions": {
			"WR": {
				"development": {
					"peak_age": 27,
					"decline_start": 30,
					"curve": "mid"
				}
			}
		},
		"main": {
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"development": {
				"curve_multipliers": {
					"mid": {
						"growth": 1.0,
						"prime": 0.35,
						"decline": 1.0
					}
				}
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "type": "base"},
				{"name": "acceleration", "type": "base"}
			]
		}
	}

	var context := {"program_quality": 1.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Apply development
	var result := GrowthFunctions.apply_development(player, context, configs, rng)

	# Verify immutability
	assert(player["stats"]["speed"] == 70.0, "Original player stats unchanged")
	assert(result.player["stats"]["speed"] > 70.0, "New player stats increased")

	# Verify report structure
	assert(result.has("report"), "Should return report")
	assert(result.report.has("phase"), "Report should have phase")
	assert(result.report["phase"] == "growth", "22-year-old WR should be in growth phase")

	print("  ✓ GrowthFunctions tests passed")


static func test_stage_pipeline() -> void:
	print("Testing StagePipeline...")

	# Create test player with minimal data
	var player := {
		"age": 22,
		"position": "RB",
		"stage": 4,  # NFL_VETERAN
		"stats": {
			"speed": 80.0,
			"strength": 75.0,
			"injury_proneness": 50.0
		},
		"potential": {
			"speed": 88.0,
			"strength": 82.0,
			"injury_proneness": 50.0
		},
		"injuries": [],
		"wear": {
			"snaps": 0,
			"collisions": 0,
			"injury_count": 0
		}
	}

	# Minimal configs
	var configs := {
		"positions": {
			"RB": {
				"development": {
					"peak_age": 26,
					"decline_start": 29,
					"curve": "fast"
				},
				"core_stats": ["speed", "strength"]
			}
		},
		"main": {
			"annual_base_progress_min": 1.0,
			"annual_base_progress_max": 4.0,
			"annual_progress_cap": 6.0,
			"development": {
				"curve_multipliers": {
					"fast": {
						"growth": 1.2,
						"prime": 0.35,
						"decline": 1.3
					}
				}
			},
			"injury": {
				"base_chance": 0.12,
				"proneness_slope": 0.15,
				"position_multipliers": {"RB": 1.3},
				"types": []
			},
			"retirement": {
				"min_age": 27,
				"soft_cap_age": 30,
				"max_age": 35,
				"base_chance": 0.02,
				"age_chance_per_year": 0.04,
				"low_rating_threshold": 55.0,
				"low_rating_boost": 0.08
			},
			"wear": {
				"decline_snaps_scale": 8000.0,
				"decline_collisions_scale": 2600.0,
				"decline_injuries_scale": 6.0,
				"decline_per_wear": 0.2,
				"decline_min_multiplier": 1.0,
				"decline_max_multiplier": 1.6
			}
		},
		"stats": {
			"stats": [
				{"name": "speed", "type": "base"},
				{"name": "strength", "type": "base"},
				{"name": "injury_proneness", "type": "base"}
			]
		}
	}

	var context := {"program_quality": 1.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Test advance_one_year
	var result := StagePipeline.advance_one_year(player, context, configs, rng)

	# Verify immutability
	assert(player["age"] == 22, "Original player age unchanged")
	assert(result.player["age"] == 23, "New player age incremented")

	# Verify return structure
	assert(result.has("player"), "Should return player")
	assert(result.has("retired"), "Should return retired flag")
	assert(result.has("report"), "Should return report")
	assert(result.report.has("development"), "Report should have development data")
	assert(result.report.has("injury"), "Report should have injury data")

	# Test determinism - same seed should produce same results
	rng.seed = 12345
	var result2 := StagePipeline.advance_one_year(player, context, configs, rng)
	assert(result.player["age"] == result2.player["age"], "Deterministic age")

	# Test transition_stage
	var transitioned := StagePipeline.transition_stage(player, 5)  # NFL_FREE_AGENT
	assert(player["stage"] == 4, "Original stage unchanged")
	assert(transitioned["stage"] == 5, "New stage updated")

	# Test compose
	var pipeline := StagePipeline.compose([
		func(p): return AgeFunctions.increment_age(p),
		func(p): return AgeFunctions.increment_age(p)
	])
	var aged := pipeline.call(player)
	assert(aged["age"] == 24, "Composed functions should apply sequentially")

	print("  ✓ StagePipeline tests passed")
