extends SceneTree

const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func _init():
	print("Testing parallel lifecycle basic functionality...")

	var positions_cfg = {
		"QB": {
			"core_stats": ["accuracy", "decision"],
			"development": {"peak_age": 27, "decline_start": 32, "curve": "mid"}
		}
	}
	var main_cfg = {
		"development": {
			"curve_multipliers": {"mid": {"growth": 1.0, "prime": 0.35, "decline": 1.0}},
			"prime_growth_min": 0.2,
			"prime_growth_max": 0.8,
			"decline_min": 0.4,
			"decline_max": 1.6
		},
		"development_context": {
			"scheme_fit": {
				"role_weights": {"core": 0.3, "secondary": 0.15, "other": 0.0},
				"multiplier_min": 0.85,
				"multiplier_max": 1.15
			}
		},
		"annual_base_progress_min": 1.0,
		"annual_base_progress_max": 4.0,
		"annual_progress_cap": 6.0,
		"retirement": {"min_age": 27, "soft_cap_age": 33, "max_age": 40, "base_chance": 0.02},
		"wear": {
			"snaps_per_year": 500,
			"collisions_per_year": 50,
			"position_multipliers": {"QB": 0.8},
			"decline_snaps_scale": 8000.0,
			"decline_collisions_scale": 2600.0,
			"decline_injuries_scale": 6.0,
			"decline_per_wear": 0.2,
			"decline_min_multiplier": 1.0,
			"decline_max_multiplier": 1.6
		},
		"injury": {"base_chance": 0.05, "proneness_slope": 0.1}
	}
	var stats_cfg = {"stats": [
		{"name": "accuracy", "type": "base"},
		{"name": "decision", "type": "base"}
	]}

	var players = []
	for i in range(150):
		players.append({
			"player_id": "P%d" % i,
			"name": "Player %d" % i,
			"age": 25,
			"position": "QB",
			"stats": {"accuracy": 60.0 + (i % 30), "decision": 55.0 + (i % 25)},
			"potential": {"accuracy": 75.0 + (i % 20), "decision": 70.0 + (i % 20)}
		})

	var rng1 = RandomNumberGenerator.new()
	var rng2 = RandomNumberGenerator.new()
	rng1.seed = 12345
	rng2.seed = 12345

	print("Running serial version...")
	var serial = PlayerLifecycle.advance_one_year(
		players.duplicate(true),
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng1
	)

	print("Running parallel version...")
	var parallel = PlayerLifecycle.advance_one_year_parallel(
		players.duplicate(true),
		positions_cfg,
		main_cfg,
		stats_cfg,
		rng2,
		{},
		4
	)

	print("Serial players: %d, retired: %d" % [serial.players.size(), serial.retired.size()])
	print("Parallel players: %d, retired: %d" % [parallel.players.size(), parallel.retired.size()])

	# Quick validation
	var matches = true
	for i in range(min(serial.players.size(), parallel.players.size())):
		var s = serial.players[i]
		var p = parallel.players[i]
		if (s == null) != (p == null):
			print("MISMATCH at index %d: null difference" % i)
			matches = false
			break
		if s != null and p != null:
			if s.get("age") != p.get("age"):
				print("MISMATCH at index %d: age difference" % i)
				matches = false
				break
			var s_acc = s.get("stats", {}).get("accuracy", 0.0)
			var p_acc = p.get("stats", {}).get("accuracy", 0.0)
			if not is_equal_approx(s_acc, p_acc):
				print("MISMATCH at index %d: accuracy difference (%.3f vs %.3f)" % [i, s_acc, p_acc])
				matches = false
				break

	if matches:
		print("SUCCESS: Serial and parallel produce matching results!")
	else:
		print("FAILURE: Results differ!")

	quit(0 if matches else 1)
