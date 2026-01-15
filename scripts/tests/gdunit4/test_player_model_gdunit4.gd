## GdUnit4 test suite for Player Model
##
## Validates Player serialization, jersey numbers, and career awards.
## Migrated from test_player_model.gd
extends GdUnitTestSuite

const SportPlayer = preload("res://scripts/core/models/Player.gd")


func test_basic_serialization() -> void:
	var player: SportPlayer = SportPlayer.new()
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
	var clone: SportPlayer = SportPlayer.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	assert_str(String(round_trip.get("id", ""))).is_equal("p-1")
	assert_str(String(round_trip.get("first_name", ""))).is_equal("Jamie")
	assert_str(String(round_trip.get("position", ""))).is_equal("QB")
	assert_int(int(round_trip.get("jersey_number", 0))).is_equal(12)
	assert_float(float((round_trip.get("stats", {}) as Dictionary).get("speed", 0.0))).is_equal(70.0)
	assert_float(float((round_trip.get("potential", {}) as Dictionary).get("throw_accuracy", 0.0))).is_equal(85.0)
	assert_float(float((round_trip.get("derived", {}) as Dictionary).get("burst", 0.0))).is_equal(1.2)
	assert_int((round_trip.get("traits", []) as Array).size()).is_equal(1)
	assert_int(int((round_trip.get("wear", {}) as Dictionary).get("snaps", 0))).is_equal(120)
	assert_int((round_trip.get("development_report", []) as Array).size()).is_equal(1)

	var awards: Dictionary = round_trip.get("career_awards", {}) as Dictionary
	assert_int(int(awards.get("opoy", 0))).is_equal(1)
	assert_int(int(awards.get("dpoy", 0))).is_equal(0)
	assert_int(int(awards.get("all_pro_first", 0))).is_equal(3)
	assert_int(int(awards.get("all_pro_second", 0))).is_equal(2)
	assert_int(int(awards.get("pro_bowl", 0))).is_equal(5)
	assert_int(int(awards.get("rookie_of_year", 0))).is_equal(1)
	assert_int(int(awards.get("championships", 0))).is_equal(2)

	var contract: Dictionary = round_trip.get("contract", {}) as Dictionary
	assert_int(int(contract.get("current_year", 0))).is_equal(1)
	assert_int(int(contract.get("total_years", 0))).is_equal(4)
	assert_float(float(contract.get("annual_value", 0.0))).is_equal(2.5)
	assert_float(float(contract.get("guaranteed", 0.0))).is_equal(1.0)
	assert_float(float(contract.get("range_min", 0.0))).is_equal(2.0)
	assert_float(float(contract.get("range_max", 0.0))).is_equal(3.0)
	assert_str(String(contract.get("valuation_source", ""))).is_equal("v1")
	assert_int(int(contract.get("valuation_seed", 0))).is_equal(999)


func test_jersey_number_serialization() -> void:
	var player: SportPlayer = SportPlayer.new()
	player.jersey_number = 99
	var serialized := player.to_dict()
	var clone := SportPlayer.new()
	clone.from_dict(serialized)
	assert_int(clone.jersey_number).is_equal(99)

	player.jersey_number = 0
	serialized = player.to_dict()
	clone = SportPlayer.new()
	clone.from_dict(serialized)
	assert_int(clone.jersey_number).is_equal(0)

	var dict_with_negative := {"jersey_number": -5}
	player = SportPlayer.new()
	player.from_dict(dict_with_negative)
	assert_int(player.jersey_number).is_equal(0)

	var dict_with_large := {"jersey_number": 150}
	player = SportPlayer.new()
	player.from_dict(dict_with_large)
	assert_int(player.jersey_number).is_equal(99)


func test_career_awards_serialization() -> void:
	var player: SportPlayer = SportPlayer.new()
	player.career_awards = {
		"opoy": 2,
		"dpoy": 1,
		"all_pro_first": 5,
		"all_pro_second": 3,
		"pro_bowl": 8,
		"rookie_of_year": 1,
		"championships": 3
	}

	var serialized := player.to_dict()
	var clone := SportPlayer.new()
	clone.from_dict(serialized)
	var round_trip := clone.to_dict()

	var awards: Dictionary = round_trip.get("career_awards", {}) as Dictionary
	assert_int(int(awards.get("opoy", 0))).is_equal(2)
	assert_int(int(awards.get("dpoy", 0))).is_equal(1)
	assert_int(int(awards.get("all_pro_first", 0))).is_equal(5)
	assert_int(int(awards.get("all_pro_second", 0))).is_equal(3)
	assert_int(int(awards.get("pro_bowl", 0))).is_equal(8)
	assert_int(int(awards.get("rookie_of_year", 0))).is_equal(1)
	assert_int(int(awards.get("championships", 0))).is_equal(3)

	var dict_with_negative := {
		"career_awards": {
			"opoy": -1,
			"dpoy": -10,
			"pro_bowl": -5
		}
	}
	player = SportPlayer.new()
	player.from_dict(dict_with_negative)
	assert_int(int(player.career_awards.get("opoy", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("dpoy", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("pro_bowl", 0))).is_equal(0)


func test_default_values() -> void:
	var player: SportPlayer = SportPlayer.new()

	assert_int(player.jersey_number).is_equal(0)

	assert_int(int(player.career_awards.get("opoy", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("dpoy", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("all_pro_first", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("all_pro_second", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("pro_bowl", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("rookie_of_year", 0))).is_equal(0)
	assert_int(int(player.career_awards.get("championships", 0))).is_equal(0)
