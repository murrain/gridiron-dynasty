extends RefCounted

const ScoutFactory = preload("res://scripts/generation/ScoutFactory.gd")

func run(t) -> void:
	var stats_cfg := Config.get_config("stats")
	var scouts_cfg := Config.get_config("scouts")

	var factory := ScoutFactory.new()
	factory.setup(stats_cfg, scouts_cfg)

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var scout_a := factory.create_random_scout("Test Scout", rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var scout_b := factory.create_random_scout("Test Scout", rng_b)

	var stat_name := String(((stats_cfg.get("stats", []) as Array)[0] as Dictionary).get("name", ""))

	t.assert_approx(scout_a.base_skill, scout_b.base_skill, 0.0001, "random scout uses deterministic seed")
	t.assert_approx(scout_a.tape_grinder, scout_b.tape_grinder, 0.0001, "tape grinder matches for same seed")
	t.assert_approx(float(scout_a.stat_skill.get(stat_name, 0.0)), float(scout_b.stat_skill.get(stat_name, 0.0)), 0.0001, "stat skill matches for same seed")

	var stat_count := (stats_cfg.get("stats", []) as Array).size()
	t.assert_eq((scout_a.stat_skill as Dictionary).size(), stat_count, "stat skills cover all stats")

	var rng_team := RandomNumberGenerator.new()
	rng_team.seed = 9001
	var team_scouts := factory.create_team_scouts("Dragons", 2, rng_team)
	t.assert_eq(team_scouts.size(), 2, "create_team_scouts returns requested count")
	for scout in team_scouts:
		t.assert_eq(String((scout as Resource).get("role")), "Team", "team scouts use Team role")
