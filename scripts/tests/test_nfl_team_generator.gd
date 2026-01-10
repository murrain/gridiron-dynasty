extends RefCounted

const NflTeamGenerator = preload("res://scripts/world/NflTeamGenerator.gd")

func run(t) -> void:
	var config = load("res://autoloads/Config.gd").new()
	var original_base = config.base_dir
	var original_save = config.save_dir
	var original_recurse = config.recurse

	config.configure("res://scripts/tests/fixtures/configs", "", false)
	var gen = NflTeamGenerator.new()
	var result = gen.generate(123, NflTeamGenerator.DEFAULT_CONFIG_KEY)
	var teams = result.get("teams", []) as Array
	t.assert_eq(teams.size(), 4, "generate should create requested teams")

	var first = teams[0] as Dictionary
	t.assert_true(first.has("id"), "team should have id")
	t.assert_true(first.has("name"), "team should have name")
	t.assert_true(first.has("region"), "team should have region")
	t.assert_true(first.has("cap_space"), "team should have cap_space")
	t.assert_true(first.has("roster"), "team should have roster")
	t.assert_true(first.has("draft_order"), "team should have draft_order")
	t.assert_eq(first.get("id"), "nfl_001", "first team should have correct id")
	t.assert_eq(first.get("cap_space"), 200.0, "team should have correct cap_space")
	t.assert_eq(first.get("draft_order"), 1, "first team should have draft_order 1")

	var regions_seen := {}
	for team in teams:
		var team_dict := team as Dictionary
		var region := String(team_dict.get("region", ""))
		if region != "":
			regions_seen[region] = true
	t.assert_true(regions_seen.size() > 0, "teams should be assigned to regions")

	_test_determinism(t, gen)
	_test_validation(t, gen)

	config.configure(original_base, original_save, original_recurse)

func _test_determinism(t, gen: NflTeamGenerator) -> void:
	var result1 = gen.generate(456)
	var result2 = gen.generate(456)
	var teams1 = result1.get("teams", []) as Array
	var teams2 = result2.get("teams", []) as Array
	t.assert_eq(teams1.size(), teams2.size(), "same seed should produce same team count")

	for i in range(teams1.size()):
		var team1 = teams1[i] as Dictionary
		var team2 = teams2[i] as Dictionary
		t.assert_eq(team1.get("id"), team2.get("id"), "team %d: same id" % i)
		t.assert_eq(team1.get("name"), team2.get("name"), "team %d: same name" % i)
		t.assert_eq(team1.get("region"), team2.get("region"), "team %d: same region" % i)
		t.assert_eq(team1.get("cap_space"), team2.get("cap_space"), "team %d: same cap_space" % i)
		t.assert_eq(team1.get("draft_order"), team2.get("draft_order"), "team %d: same draft_order" % i)

func _test_validation(t, gen: NflTeamGenerator) -> void:
	var bad_cfg_no_count = {"team_count": 0, "regions": [{"id": "test", "weight": 1.0}]}
	t.assert_true(not gen._validate_config(bad_cfg_no_count), "validate should reject team_count <= 0")

	var bad_cfg_no_regions = {"team_count": 32, "regions": []}
	t.assert_true(not gen._validate_config(bad_cfg_no_regions), "validate should reject empty regions")

	var bad_cfg_bad_weights = {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 0.5}]
	}
	t.assert_true(not gen._validate_config(bad_cfg_bad_weights), "validate should reject weights not summing to 1.0")

	var bad_cfg_roster_limits = {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"roster_limits": {"active": 0}
	}
	t.assert_true(not gen._validate_config(bad_cfg_roster_limits), "validate should reject roster_limits.active <= 0")

	var bad_cfg_draft = {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"draft": {"rounds": 0, "picks_per_round": 32}
	}
	t.assert_true(not gen._validate_config(bad_cfg_draft), "validate should reject draft.rounds <= 0")

	var good_cfg = {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"roster_limits": {"active": 53},
		"draft": {"rounds": 7, "picks_per_round": 32}
	}
	t.assert_true(gen._validate_config(good_cfg), "validate should accept valid config")
