extends RefCounted

const SportPlayer = preload("res://scripts/core/models/Player.gd")

func run(t) -> void:
	var player := SportPlayer.new()
	player.id = "p-1"
	player.first_name = "Jamie"
	player.last_name = "Taylor"
	player.position = "QB"
	player.age = 19
	player.class_tag = "CLASS_OF_2030"
	player.height_in = 74.0
	player.weight_lb = 210.0
	player.stats = {"speed": 70.0, "throw_accuracy": 78.0}
	player.potential = {"speed": 78.0, "throw_accuracy": 85.0}
	player.derived = {"burst": 1.2}
	player.traits = ["Leader"]

	var serialized := player.to_dict()
	var clone := SportPlayer.new()
	clone.from_dict(serialized)
	var round_trip := clone.to_dict()

	t.assert_eq(round_trip.get("id", ""), "p-1", "id round-trips")
	t.assert_eq(round_trip.get("first_name", ""), "Jamie", "first_name round-trips")
	t.assert_eq(round_trip.get("position", ""), "QB", "position round-trips")
	t.assert_eq((round_trip.get("stats", {}) as Dictionary).get("speed", 0.0), 70.0, "stats round-trip")
	t.assert_eq((round_trip.get("potential", {}) as Dictionary).get("throw_accuracy", 0.0), 85.0, "potential round-trip")
	t.assert_eq((round_trip.get("derived", {}) as Dictionary).get("burst", 0.0), 1.2, "derived round-trip")
	t.assert_eq((round_trip.get("traits", []) as Array).size(), 1, "traits round-trip")
