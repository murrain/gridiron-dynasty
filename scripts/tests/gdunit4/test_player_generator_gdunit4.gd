## GdUnit4 test suite for PlayerGenerator
##
## Validates single player generation and dynamic freak assignment.
## Migrated from test_player_generator.gd
extends GdUnitTestSuite

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")


var _gen: PlayerGenerator


func before() -> void:
	_gen = PlayerGenerator.new()
	_gen.names_cfg = {"first_names": ["Alex"], "last_names": ["Lee"]}
	_gen.positions_data = {
		"QB": {
			"physicals": {"height_in": {"mu": 72, "sigma": 0, "min": 70, "max": 76}},
			"distributions": {"speed": {"mu": 50, "sigma": 0, "min": 40, "max": 60}}
		}
	}
	_gen.stats_cfg = {"stats": [
		{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60},
		{"name": "strength", "mu": 60, "sigma": 0, "min": 50, "max": 70}
	]}
	_gen.class_rules = {"position_weights": {"QB": 1.0}}


func test_make_single_player_uses_names_config() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	assert_str(String(player.get("name"))).is_equal("Alex Lee")


func test_make_single_player_picks_position() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	assert_str(String(player.get("position"))).is_equal("QB")


func test_make_single_player_includes_stats() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var player = _gen._make_single_player(1.0, rng)
	var stats = player.get("stats", {}) as Dictionary
	assert_bool(stats.has("speed")).is_true()


func test_assign_dynamic_freaks_respects_max() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var players = [
		{"position": "QB", "stats": {"speed": 80.0, "acceleration": 80.0, "agility": 80.0, "balance": 80.0, "vertical_jump": 80.0, "broad_jump": 80.0, "strength": 80.0}, "tags": []},
		{"position": "RB", "stats": {"speed": 70.0, "acceleration": 70.0, "agility": 70.0, "balance": 70.0, "vertical_jump": 70.0, "broad_jump": 70.0, "strength": 70.0}, "tags": []},
		{"position": "K", "stats": {"speed": 60.0, "acceleration": 60.0, "agility": 60.0, "balance": 60.0, "vertical_jump": 60.0, "broad_jump": 60.0, "strength": 60.0}, "tags": []}
	]
	_gen.assign_dynamic_freaks(players, 2, 0.0, 1.0, rng)

	var freak_count = 0
	for p in players:
		var tags = (p as Dictionary).get("tags", []) as Array
		if tags.has("PotentialSuperstar"):
			freak_count += 1

	assert_int(freak_count).is_less_equal(2)


func test_assign_dynamic_freaks_stats_stay_in_bounds() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var players = [
		{"position": "QB", "stats": {"speed": 80.0, "acceleration": 80.0, "agility": 80.0, "balance": 80.0, "vertical_jump": 80.0, "broad_jump": 80.0, "strength": 80.0}, "tags": []},
		{"position": "RB", "stats": {"speed": 70.0, "acceleration": 70.0, "agility": 70.0, "balance": 70.0, "vertical_jump": 70.0, "broad_jump": 70.0, "strength": 70.0}, "tags": []},
		{"position": "K", "stats": {"speed": 60.0, "acceleration": 60.0, "agility": 60.0, "balance": 60.0, "vertical_jump": 60.0, "broad_jump": 60.0, "strength": 60.0}, "tags": []}
	]
	_gen.assign_dynamic_freaks(players, 2, 0.0, 1.0, rng)

	for p in players:
		var tags = (p as Dictionary).get("tags", []) as Array
		if tags.has("PotentialSuperstar"):
			var st = (p as Dictionary).get("stats", {}) as Dictionary
			assert_float(float(st.get("speed", 0.0))).is_between(0.0, 100.0)
