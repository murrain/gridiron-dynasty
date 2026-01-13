extends RefCounted

const ConferenceService = preload("res://scripts/world/ConferenceService.gd")

func run(t) -> void:
	test_assign_colleges_to_conferences(t)
	test_assign_colleges_determinism(t)
	test_build_conference_index(t)
	test_calculate_strength_of_schedule(t)
	test_get_conference_tier_multiplier(t)

func test_assign_colleges_to_conferences(t) -> void:
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

	# Check that all colleges have conference assignments
	for college in colleges:
		var c: Dictionary = college
		t.assert_true(c.has("conference"), "college has conference assigned")
		t.assert_true(c.has("conference_tier"), "college has conference_tier assigned")
		t.assert_true(c.has("strength_of_schedule"), "college has strength_of_schedule initialized")

func test_assign_colleges_determinism(t) -> void:
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

	t.assert_eq(colleges1[0].get("conference"), colleges2[0].get("conference"), "conference assignment is deterministic")

func test_build_conference_index(t) -> void:
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

	t.assert_true(index.has("big_ten"), "index has big_ten")
	t.assert_true(index.has("sec"), "index has sec")

	var big_ten: Dictionary = index.get("big_ten", {})
	var members: Array = big_ten.get("members", [])
	t.assert_eq(members.size(), 2, "big_ten has 2 members")

func test_calculate_strength_of_schedule(t) -> void:
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
	t.assert_true(abs(sos - 0.5) < 0.01, "SOS calculated correctly as ~0.5")

	# No opponents
	var empty_results := {"college_1": {"opponents": []}}
	sos = ConferenceService.calculate_strength_of_schedule("college_1", empty_results, colleges)
	t.assert_eq(sos, 0.0, "SOS is 0 with no opponents")

func test_get_conference_tier_multiplier(t) -> void:
	var config := {
		"tier_weights": {
			"power_5": {"base_draft_multiplier": 1.05},
			"group_5": {"base_draft_multiplier": 0.95},
			"fcs": {"base_draft_multiplier": 0.85}
		}
	}

	var mult := ConferenceService.get_conference_tier_multiplier("power_5", config)
	t.assert_true(abs(mult - 1.05) < 0.001, "power_5 multiplier is 1.05")

	mult = ConferenceService.get_conference_tier_multiplier("group_5", config)
	t.assert_true(abs(mult - 0.95) < 0.001, "group_5 multiplier is 0.95")

	mult = ConferenceService.get_conference_tier_multiplier("fcs", config)
	t.assert_true(abs(mult - 0.85) < 0.001, "fcs multiplier is 0.85")
