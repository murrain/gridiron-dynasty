extends RefCounted

const Player = preload("res://scripts/core/models/Player.gd")

func run(t) -> void:
	test_basic_serialization(t)
	test_jersey_number_serialization(t)
	test_career_awards_serialization(t)
	test_default_values(t)

func test_basic_serialization(t) -> void:
	var player: Player = Player.new()
	player.id = "p-1"
	player.first_name = "Jamie"
	player.last_name = "Taylor"
	player.position = "QB"
	player.age = 19
	player.class_tag = "CLASS_OF_2030"
	player.jersey_number = 12
	player.height_in = 74.0
	player.weight_lb = 210.0
	player.stats = {"speed": 70.0, "throw_accuracy": 78.0}
	player.potential = {"speed": 78.0, "throw_accuracy": 85.0}
	player.derived = {"burst": 1.2}
	player.traits = ["Leader"]
	player.wear = {"snaps": 120, "collisions": 45, "injury_count": 1}
	player.development_report = [{"age": 19, "wear": {"snaps": 120, "collisions": 45, "injury_count": 1}}]
	player.career_awards = {
		"opoy": 1,
		"dpoy": 0,
		"all_pro_first": 3,
		"all_pro_second": 2,
		"pro_bowl": 5,
		"rookie_of_year": 1,
		"championships": 2
	}
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
	var clone: Player = Player.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	t.assert_eq(round_trip.get("id", ""), "p-1", "id round-trips")
	t.assert_eq(round_trip.get("first_name", ""), "Jamie", "first_name round-trips")
	t.assert_eq(round_trip.get("position", ""), "QB", "position round-trips")
	t.assert_eq(round_trip.get("jersey_number", 0), 12, "jersey_number round-trips")
	t.assert_eq((round_trip.get("stats", {}) as Dictionary).get("speed", 0.0), 70.0, "stats round-trip")
	t.assert_eq((round_trip.get("potential", {}) as Dictionary).get("throw_accuracy", 0.0), 85.0, "potential round-trip")
	t.assert_eq((round_trip.get("derived", {}) as Dictionary).get("burst", 0.0), 1.2, "derived round-trip")
	t.assert_eq((round_trip.get("traits", []) as Array).size(), 1, "traits round-trip")
	t.assert_eq((round_trip.get("wear", {}) as Dictionary).get("snaps", 0), 120, "wear round-trip")
	t.assert_eq((round_trip.get("development_report", []) as Array).size(), 1, "development report round-trip")

	var awards: Dictionary = round_trip.get("career_awards", {}) as Dictionary
	t.assert_eq(awards.get("opoy"), 1, "career_awards opoy round-trips")
	t.assert_eq(awards.get("dpoy"), 0, "career_awards dpoy round-trips")
	t.assert_eq(awards.get("all_pro_first"), 3, "career_awards all_pro_first round-trips")
	t.assert_eq(awards.get("all_pro_second"), 2, "career_awards all_pro_second round-trips")
	t.assert_eq(awards.get("pro_bowl"), 5, "career_awards pro_bowl round-trips")
	t.assert_eq(awards.get("rookie_of_year"), 1, "career_awards rookie_of_year round-trips")
	t.assert_eq(awards.get("championships"), 2, "career_awards championships round-trips")

	var contract: Dictionary = round_trip.get("contract", {}) as Dictionary
	t.assert_eq(contract.get("current_year"), 1, "contract current year round-trip")
	t.assert_eq(contract.get("total_years"), 4, "contract total years round-trip")
	t.assert_eq(contract.get("annual_value"), 2.5, "contract annual value round-trip")
	t.assert_eq(contract.get("guaranteed"), 1.0, "contract guaranteed round-trip")
	t.assert_eq(contract.get("range_min"), 2.0, "contract range min round-trip")
	t.assert_eq(contract.get("range_max"), 3.0, "contract range max round-trip")
	t.assert_eq(contract.get("valuation_source"), "v1", "contract valuation source round-trip")
	t.assert_eq(contract.get("valuation_seed"), 999, "contract valuation seed round-trip")

func test_jersey_number_serialization(t) -> void:
	# Test valid jersey numbers
	var player: Player = Player.new()
	player.jersey_number = 99
	var serialized = player.to_dict()
	var clone = Player.new()
	clone.from_dict(serialized)
	t.assert_eq(clone.jersey_number, 99, "jersey_number 99 round-trips")

	# Test 0 (unassigned)
	player.jersey_number = 0
	serialized = player.to_dict()
	clone = Player.new()
	clone.from_dict(serialized)
	t.assert_eq(clone.jersey_number, 0, "jersey_number 0 (unassigned) round-trips")

	# Test edge case: negative number should clamp to 0
	var dict_with_negative = {"jersey_number": -5}
	player = Player.new()
	player.from_dict(dict_with_negative)
	t.assert_eq(player.jersey_number, 0, "jersey_number -5 clamps to 0")

	# Test edge case: number > 99 should clamp to 99
	var dict_with_large = {"jersey_number": 150}
	player = Player.new()
	player.from_dict(dict_with_large)
	t.assert_eq(player.jersey_number, 99, "jersey_number 150 clamps to 99")

func test_career_awards_serialization(t) -> void:
	var player: Player = Player.new()
	player.career_awards = {
		"opoy": 2,
		"dpoy": 1,
		"all_pro_first": 5,
		"all_pro_second": 3,
		"pro_bowl": 8,
		"rookie_of_year": 1,
		"championships": 3
	}

	var serialized = player.to_dict()
	var clone = Player.new()
	clone.from_dict(serialized)
	var round_trip = clone.to_dict()

	var awards: Dictionary = round_trip.get("career_awards", {}) as Dictionary
	t.assert_eq(awards.get("opoy"), 2, "career_awards with opoy=2 round-trips")
	t.assert_eq(awards.get("dpoy"), 1, "career_awards with dpoy=1 round-trips")
	t.assert_eq(awards.get("all_pro_first"), 5, "career_awards with all_pro_first=5 round-trips")
	t.assert_eq(awards.get("all_pro_second"), 3, "career_awards with all_pro_second=3 round-trips")
	t.assert_eq(awards.get("pro_bowl"), 8, "career_awards with pro_bowl=8 round-trips")
	t.assert_eq(awards.get("rookie_of_year"), 1, "career_awards with rookie_of_year=1 round-trips")
	t.assert_eq(awards.get("championships"), 3, "career_awards with championships=3 round-trips")

	# Test negative values clamp to 0
	var dict_with_negative = {
		"career_awards": {
			"opoy": -1,
			"dpoy": -10,
			"pro_bowl": -5
		}
	}
	player = Player.new()
	player.from_dict(dict_with_negative)
	t.assert_eq(player.career_awards.get("opoy"), 0, "negative opoy clamps to 0")
	t.assert_eq(player.career_awards.get("dpoy"), 0, "negative dpoy clamps to 0")
	t.assert_eq(player.career_awards.get("pro_bowl"), 0, "negative pro_bowl clamps to 0")

func test_default_values(t) -> void:
	var player: Player = Player.new()

	# Test default jersey_number
	t.assert_eq(player.jersey_number, 0, "default jersey_number is 0")

	# Test default career_awards
	t.assert_eq(player.career_awards.get("opoy"), 0, "default career_awards opoy is 0")
	t.assert_eq(player.career_awards.get("dpoy"), 0, "default career_awards dpoy is 0")
	t.assert_eq(player.career_awards.get("all_pro_first"), 0, "default career_awards all_pro_first is 0")
	t.assert_eq(player.career_awards.get("all_pro_second"), 0, "default career_awards all_pro_second is 0")
	t.assert_eq(player.career_awards.get("pro_bowl"), 0, "default career_awards pro_bowl is 0")
	t.assert_eq(player.career_awards.get("rookie_of_year"), 0, "default career_awards rookie_of_year is 0")
	t.assert_eq(player.career_awards.get("championships"), 0, "default career_awards championships is 0")
