extends RefCounted

const SportPlayer = preload("res://scripts/core/models/Player.gd")

func run(t) -> void:
	var player: SportPlayer = SportPlayer.new()
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
	player.wear = {"snaps": 120, "collisions": 45, "injury_count": 1}
	player.development_report = [{"age": 19, "wear": {"snaps": 120, "collisions": 45, "injury_count": 1}}]
	player.contract = {
		"current_year": 1,
		"total_years": 4,
		"annual_value": 2.5,
		"guaranteed": 1.0,
		"range_min": 2.0,
		"range_max": 3.0,
		"valuation_source": "v1",
		"valuation_seed": 999
	}

	var serialized: Dictionary = player.to_dict()
	var clone: SportPlayer = SportPlayer.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	t.assert_eq(round_trip.get("id", ""), "p-1", "id round-trips")
	t.assert_eq(round_trip.get("first_name", ""), "Jamie", "first_name round-trips")
	t.assert_eq(round_trip.get("position", ""), "QB", "position round-trips")
	t.assert_eq((round_trip.get("stats", {}) as Dictionary).get("speed", 0.0), 70.0, "stats round-trip")
	t.assert_eq((round_trip.get("potential", {}) as Dictionary).get("throw_accuracy", 0.0), 85.0, "potential round-trip")
	t.assert_eq((round_trip.get("derived", {}) as Dictionary).get("burst", 0.0), 1.2, "derived round-trip")
	t.assert_eq((round_trip.get("traits", []) as Array).size(), 1, "traits round-trip")
	t.assert_eq((round_trip.get("wear", {}) as Dictionary).get("snaps", 0), 120, "wear round-trip")
	t.assert_eq((round_trip.get("development_report", []) as Array).size(), 1, "development report round-trip")
	var contract: Dictionary = round_trip.get("contract", {}) as Dictionary
	t.assert_eq(contract.get("current_year"), 1, "contract current year round-trip")
	t.assert_eq(contract.get("total_years"), 4, "contract total years round-trip")
	t.assert_eq(contract.get("annual_value"), 2.5, "contract annual value round-trip")
	t.assert_eq(contract.get("guaranteed"), 1.0, "contract guaranteed round-trip")
	t.assert_eq(contract.get("range_min"), 2.0, "contract range min round-trip")
	t.assert_eq(contract.get("range_max"), 3.0, "contract range max round-trip")
	t.assert_eq(contract.get("valuation_source"), "v1", "contract valuation source round-trip")
	t.assert_eq(contract.get("valuation_seed"), 999, "contract valuation seed round-trip")
