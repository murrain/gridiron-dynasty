extends RefCounted

const NamesHelper = preload("res://scripts/generation/helpers/NamesHelper.gd")
const PositionHelper = preload("res://scripts/generation/helpers/PositionHelper.gd")
const PhysicalsHelper = preload("res://scripts/generation/helpers/PhysicalsHelper.gd")
const StatsHelper = preload("res://scripts/generation/helpers/StatsHelper.gd")

func run(t) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var names_cfg = {"first_names": ["Chris"], "last_names": ["Carter"]}
	var name = NamesHelper.random_full(names_cfg, rng)
	t.assert_eq(name, "Chris Carter", "NamesHelper should use provided lists")

	var pos = PositionHelper.pick_position({"QB": {}, "RB": {}}, {"position_weights": {"QB": 1.0, "RB": 0.0}}, rng)
	t.assert_eq(pos, "QB", "PositionHelper should respect weights")

	var phys = PhysicalsHelper.roll_for_position("QB", {"QB": {"physicals": {"height_in": {"mu": 72, "sigma": 0, "min": 70, "max": 76}}}}, rng)
	t.assert_eq(phys.get("height_in"), 72.0, "PhysicalsHelper should clamp when sigma is 0")

	var stats_cfg = {"stats": [
		{"name": "speed", "mu": 50, "sigma": 0, "min": 40, "max": 60, "default": 55},
		{"name": "awareness", "mu": 40, "sigma": 0, "min": 30, "max": 70}
	]}
	var positions_data = {"QB": {"distributions": {"speed": {"mu": 52, "sigma": 0, "min": 45, "max": 55}}}}
	var rolled = StatsHelper.roll_all(stats_cfg, "QB", positions_data, 1.0, rng)
	t.assert_eq(rolled.get("speed"), 52.0, "StatsHelper uses position override")
	var applied = StatsHelper.apply_defaults(rolled, stats_cfg, true)
	t.assert_eq(applied, 0, "StatsHelper defaults should not overwrite existing")
	rolled.erase("speed")
	var applied2 = StatsHelper.apply_defaults(rolled, stats_cfg, true)
	t.assert_eq(applied2, 1, "StatsHelper should fill missing default")
