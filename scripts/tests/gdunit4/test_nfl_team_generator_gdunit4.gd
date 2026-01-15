## GdUnit4 test suite for NflTeamGenerator
##
## Validates NFL team generation, determinism, and config validation.
## Migrated from test_nfl_team_generator.gd
extends GdUnitTestSuite

const NflTeamGenerator = preload("res://scripts/world/NflTeamGenerator.gd")


func test_team_generation_basic() -> void:
	var gen := NflTeamGenerator.new()
	var result := gen.generate(123, NflTeamGenerator.DEFAULT_CONFIG_KEY)
	var teams := result.get("teams", []) as Array

	assert_int(teams.size()).is_greater(0)

	var first := teams[0] as Dictionary
	assert_bool(first.has("id")).is_true()
	assert_bool(first.has("name")).is_true()
	assert_bool(first.has("region")).is_true()
	assert_bool(first.has("cap_space")).is_true()
	assert_bool(first.has("roster")).is_true()
	assert_bool(first.has("draft_order")).is_true()


func test_team_generation_structure() -> void:
	var gen := NflTeamGenerator.new()
	var result := gen.generate(123, NflTeamGenerator.DEFAULT_CONFIG_KEY)
	var teams := result.get("teams", []) as Array

	if teams.size() > 0:
		var first := teams[0] as Dictionary
		assert_str(String(first.get("id", ""))).is_equal("nfl_001")
		assert_float(float(first.get("cap_space", 0.0))).is_equal(200.0)
		assert_int(int(first.get("draft_order", 0))).is_equal(1)


func test_team_regions_assigned() -> void:
	var gen := NflTeamGenerator.new()
	var result := gen.generate(123, NflTeamGenerator.DEFAULT_CONFIG_KEY)
	var teams := result.get("teams", []) as Array

	var regions_seen := {}
	for team in teams:
		var team_dict := team as Dictionary
		var region := String(team_dict.get("region", ""))
		if region != "":
			regions_seen[region] = true

	assert_int(regions_seen.size()).is_greater(0)


func test_determinism() -> void:
	var gen := NflTeamGenerator.new()

	var result1 := gen.generate(456)
	var result2 := gen.generate(456)

	var teams1 := result1.get("teams", []) as Array
	var teams2 := result2.get("teams", []) as Array

	assert_int(teams1.size()).is_equal(teams2.size())

	for i in range(teams1.size()):
		var team1 := teams1[i] as Dictionary
		var team2 := teams2[i] as Dictionary
		assert_that(team1.get("id")).is_equal(team2.get("id"))
		assert_that(team1.get("name")).is_equal(team2.get("name"))
		assert_that(team1.get("region")).is_equal(team2.get("region"))
		assert_that(team1.get("cap_space")).is_equal(team2.get("cap_space"))
		assert_that(team1.get("draft_order")).is_equal(team2.get("draft_order"))


func test_validation_rejects_zero_team_count() -> void:
	var gen := NflTeamGenerator.new()
	var bad_cfg := {"team_count": 0, "regions": [{"id": "test", "weight": 1.0}]}
	assert_bool(not gen._validate_config(bad_cfg)).is_true()


func test_validation_rejects_empty_regions() -> void:
	var gen := NflTeamGenerator.new()
	var bad_cfg := {"team_count": 32, "regions": []}
	assert_bool(not gen._validate_config(bad_cfg)).is_true()


func test_validation_rejects_bad_weights() -> void:
	var gen := NflTeamGenerator.new()
	var bad_cfg := {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 0.5}]
	}
	assert_bool(not gen._validate_config(bad_cfg)).is_true()


func test_validation_rejects_invalid_roster_limits() -> void:
	var gen := NflTeamGenerator.new()
	var bad_cfg := {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"roster_limits": {"active": 0}
	}
	assert_bool(not gen._validate_config(bad_cfg)).is_true()


func test_validation_rejects_invalid_draft_config() -> void:
	var gen := NflTeamGenerator.new()
	var bad_cfg := {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"draft": {"rounds": 0, "picks_per_round": 32}
	}
	assert_bool(not gen._validate_config(bad_cfg)).is_true()


func test_validation_accepts_valid_config() -> void:
	var gen := NflTeamGenerator.new()
	var good_cfg := {
		"team_count": 32,
		"regions": [{"id": "test", "weight": 1.0}],
		"roster_limits": {"active": 53},
		"draft": {"rounds": 7, "picks_per_round": 32}
	}
	assert_bool(gen._validate_config(good_cfg)).is_true()
