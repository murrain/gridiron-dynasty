extends RefCounted

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")

func run(t) -> void:
	var gen = PlayerGenerator.new()
	gen.names_cfg = {"first_names": ["Alex"], "last_names": ["Lee"]}
	gen.positions_data = {
		"QB": {
			"physicals": {"height_in": {"mu": 72, "sigma": 0, "min": 70, "max": 76}},
			"distributions": {"speed": {"mu": 50, "sigma": 0, "min": 40, "max": 60}}
		}
	}
	gen.stats_cfg = {"stats": [
		{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60},
		{"name": "strength", "mu": 60, "sigma": 0, "min": 50, "max": 70}
	]}
	gen.class_rules = {"position_weights": {"QB": 1.0}}
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = gen._make_single_player(1.0, rng)
	t.assert_eq(player.get("name"), "Alex Lee", "_make_single_player should use names config")
	t.assert_eq(player.get("position"), "QB", "_make_single_player should pick position")
	var stats = player.get("stats", {}) as Dictionary
	t.assert_true(stats.has("speed"), "_make_single_player should include stats")

	var players = [
		{"position": "QB", "stats": {"speed": 80.0, "acceleration": 80.0, "agility": 80.0, "balance": 80.0, "vertical_jump": 80.0, "broad_jump": 80.0, "strength": 80.0}, "tags": []},
		{"position": "RB", "stats": {"speed": 70.0, "acceleration": 70.0, "agility": 70.0, "balance": 70.0, "vertical_jump": 70.0, "broad_jump": 70.0, "strength": 70.0}, "tags": []},
		{"position": "K", "stats": {"speed": 60.0, "acceleration": 60.0, "agility": 60.0, "balance": 60.0, "vertical_jump": 60.0, "broad_jump": 60.0, "strength": 60.0}, "tags": []}
	]
	gen.assign_dynamic_freaks(players, 2, 0.0, 1.0, rng)
	var freak_count = 0
	for p in players:
		var tags = (p as Dictionary).get("tags", []) as Array
		if tags.has("PotentialSuperstar"):
			freak_count += 1
			var st = (p as Dictionary).get("stats", {}) as Dictionary
			t.assert_between(float(st.get("speed", 0.0)), 0.0, 100.0, "freak stats should stay in bounds")
	t.assert_true(freak_count <= 2, "assign_dynamic_freaks should respect max")
