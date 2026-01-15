## GdUnit4 test suite for ConferenceService
##
## Validates conference assignment, indexing, and strength of schedule calculation.
## Migrated from test_conference_service.gd
extends GdUnitTestSuite

const ConferenceService = preload("res://scripts/world/ConferenceService.gd")


func test_assign_colleges_to_conferences() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var colleges := [
		{"id": "college_1", "region": "midwest", "eliteness": 90.0},
		{"id": "college_2", "region": "southeast", "eliteness": 85.0},
		{"id": "college_3", "region": "west", "eliteness": 50.0}
	]

	var config := {
		"conferences": [
			{
				"id": "big_ten",
				"name": "Big Ten",
				"tier": "power_5",
				"draft_weight_multiplier": 1.1,
				"preferred_regions": ["midwest"],
				"region_weight": 0.5,
				"min_eliteness": 70.0,
				"size_min": 1,
				"size_max": 2
			},
			{
				"id": "fcs_independent",
				"name": "FCS Independent",
				"tier": "fcs",
				"draft_weight_multiplier": 0.8,
				"size_min": 0,
				"size_max": 100
			}
		]
	}

	ConferenceService.assign_colleges_to_conferences(colleges, config, rng)

	for college in colleges:
		var c: Dictionary = college
		assert_bool(c.has("conference")).is_true()
		assert_bool(c.has("conference_tier")).is_true()
		assert_bool(c.has("strength_of_schedule")).is_true()


func test_assign_colleges_determinism() -> void:
	var colleges1 := [
		{"id": "c1", "region": "midwest", "eliteness": 80.0},
		{"id": "c2", "region": "southeast", "eliteness": 75.0}
	]
	var colleges2 := [
		{"id": "c1", "region": "midwest", "eliteness": 80.0},
		{"id": "c2", "region": "southeast", "eliteness": 75.0}
	]

	var config := {
		"conferences": [
			{"id": "conf1", "tier": "power_5", "draft_weight_multiplier": 1.0, "size_min": 1, "size_max": 2},
			{"id": "fcs_independent", "tier": "fcs", "draft_weight_multiplier": 0.8, "size_min": 0, "size_max": 100}
		]
	}

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 54321
	ConferenceService.assign_colleges_to_conferences(colleges1, config, rng1)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	ConferenceService.assign_colleges_to_conferences(colleges2, config, rng2)

	assert_that(colleges1[0].get("conference")).is_equal(colleges2[0].get("conference"))


func test_build_conference_index() -> void:
	var colleges := [
		{"id": "college_1", "conference": "big_ten"},
		{"id": "college_2", "conference": "big_ten"},
		{"id": "college_3", "conference": "sec"}
	]

	var config := {
		"conferences": [
			{"id": "big_ten", "name": "Big Ten", "tier": "power_5", "draft_weight_multiplier": 1.1},
			{"id": "sec", "name": "SEC", "tier": "power_5", "draft_weight_multiplier": 1.15}
		]
	}

	var index := ConferenceService.build_conference_index(colleges, config)

	assert_bool(index.has("big_ten")).is_true()
	assert_bool(index.has("sec")).is_true()

	var big_ten: Dictionary = index.get("big_ten", {})
	var members: Array = big_ten.get("members", [])
	assert_int(members.size()).is_equal(2)


func test_calculate_strength_of_schedule() -> void:
	var colleges := [
		{"id": "college_1", "conference_tier": "power_5"},
		{"id": "college_2", "conference_tier": "power_5"},
		{"id": "college_3", "conference_tier": "group_5"},
		{"id": "college_4", "conference_tier": "fcs"}
	]

	var season_results := {
		"college_1": {
			"opponents": ["college_2", "college_3", "college_4"]
		}
	}

	var sos := ConferenceService.calculate_strength_of_schedule(
		"college_1", season_results, colleges
	)

	# power_5=1.0, group_5=0.5, fcs=0.0 -> avg = (1.0 + 0.5 + 0.0) / 3 = 0.5
	assert_float(sos).is_equal_approx(0.5, 0.01)


func test_calculate_sos_no_opponents() -> void:
	var colleges := [{"id": "college_1", "conference_tier": "power_5"}]
	var empty_results := {"college_1": {"opponents": []}}

	var sos := ConferenceService.calculate_strength_of_schedule("college_1", empty_results, colleges)

	assert_float(sos).is_equal(0.0)


func test_get_conference_tier_multiplier_power_5() -> void:
	var config := {
		"tier_weights": {
			"power_5": {"base_draft_multiplier": 1.05},
			"group_5": {"base_draft_multiplier": 0.95},
			"fcs": {"base_draft_multiplier": 0.85}
		}
	}

	var mult := ConferenceService.get_conference_tier_multiplier("power_5", config)

	assert_float(mult).is_equal_approx(1.05, 0.001)


func test_get_conference_tier_multiplier_group_5() -> void:
	var config := {
		"tier_weights": {
			"power_5": {"base_draft_multiplier": 1.05},
			"group_5": {"base_draft_multiplier": 0.95},
			"fcs": {"base_draft_multiplier": 0.85}
		}
	}

	var mult := ConferenceService.get_conference_tier_multiplier("group_5", config)

	assert_float(mult).is_equal_approx(0.95, 0.001)


func test_get_conference_tier_multiplier_fcs() -> void:
	var config := {
		"tier_weights": {
			"power_5": {"base_draft_multiplier": 1.05},
			"group_5": {"base_draft_multiplier": 0.95},
			"fcs": {"base_draft_multiplier": 0.85}
		}
	}

	var mult := ConferenceService.get_conference_tier_multiplier("fcs", config)

	assert_float(mult).is_equal_approx(0.85, 0.001)
