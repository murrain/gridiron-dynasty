## GdUnit4 test suite for Coach model
##
## Validates Coach model defaults, serialization, and type conversion.
## Migrated from test_coach_model.gd
extends GdUnitTestSuite

const Coach = preload("res://scripts/core/models/Coach.gd")


func test_default_identity_values() -> void:
	var coach: Coach = Coach.new()

	assert_str(coach.id).is_equal("")
	assert_str(coach.first_name).is_equal("")
	assert_str(coach.last_name).is_equal("")
	assert_str(coach.role).is_equal("")


func test_default_coaching_attributes() -> void:
	var coach: Coach = Coach.new()

	assert_float(coach.coaching_ability).is_equal(50.0)
	assert_float(coach.recruiting_skill).is_equal(50.0)
	assert_float(coach.player_development).is_equal(50.0)


func test_default_experience_values() -> void:
	var coach: Coach = Coach.new()

	assert_int(coach.experience_years).is_equal(0)
	assert_str(coach.specialty_position).is_equal("")
	assert_str(coach.scheme_preference).is_equal("")


func test_default_evaluation_philosophy() -> void:
	var coach: Coach = Coach.new()

	assert_str(coach.character_tolerance).is_equal("moderate")
	assert_str(coach.medical_tolerance).is_equal("cautious")


func test_identity_round_trips() -> void:
	var coach: Coach = Coach.new()
	coach.id = "coach-001"
	coach.first_name = "John"
	coach.last_name = "Smith"
	coach.role = "Head Coach"

	var serialized: Dictionary = coach.to_dict()
	var clone: Coach = Coach.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	assert_str(String(round_trip.get("id", ""))).is_equal("coach-001")
	assert_str(String(round_trip.get("first_name", ""))).is_equal("John")
	assert_str(String(round_trip.get("last_name", ""))).is_equal("Smith")
	assert_str(String(round_trip.get("role", ""))).is_equal("Head Coach")


func test_coaching_attributes_round_trip() -> void:
	var coach: Coach = Coach.new()
	coach.coaching_ability = 85.5
	coach.recruiting_skill = 72.3
	coach.player_development = 90.1

	var serialized: Dictionary = coach.to_dict()
	var clone: Coach = Coach.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	assert_float(float(round_trip.get("coaching_ability", 0.0))).is_equal(85.5)
	assert_float(float(round_trip.get("recruiting_skill", 0.0))).is_equal(72.3)
	assert_float(float(round_trip.get("player_development", 0.0))).is_equal(90.1)


func test_experience_round_trips() -> void:
	var coach: Coach = Coach.new()
	coach.experience_years = 15
	coach.specialty_position = "Defense"
	coach.scheme_preference = "spread"

	var serialized: Dictionary = coach.to_dict()
	var clone: Coach = Coach.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	assert_int(int(round_trip.get("experience_years", 0))).is_equal(15)
	assert_str(String(round_trip.get("specialty_position", ""))).is_equal("Defense")
	assert_str(String(round_trip.get("scheme_preference", ""))).is_equal("spread")


func test_evaluation_philosophy_round_trips() -> void:
	var coach: Coach = Coach.new()
	coach.character_tolerance = "strict"
	coach.medical_tolerance = "aggressive"

	var serialized: Dictionary = coach.to_dict()
	var clone: Coach = Coach.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	assert_str(String(round_trip.get("character_tolerance", ""))).is_equal("strict")
	assert_str(String(round_trip.get("medical_tolerance", ""))).is_equal("aggressive")


func test_string_id_conversion() -> void:
	var coach: Coach = Coach.new()
	var data: Dictionary = {"id": "123", "first_name": "Test"}
	coach.from_dict(data)

	assert_str(coach.id).is_equal("123")
	assert_str(coach.first_name).is_equal("Test")


func test_float_type_conversion() -> void:
	var coach: Coach = Coach.new()
	var data: Dictionary = {"coaching_ability": 75.5}
	coach.from_dict(data)

	assert_float(coach.coaching_ability).is_equal(75.5)


func test_int_to_float_conversion() -> void:
	var coach: Coach = Coach.new()
	var data: Dictionary = {"recruiting_skill": 80}  # int instead of float
	coach.from_dict(data)

	assert_float(coach.recruiting_skill).is_equal(80.0)


func test_int_type_conversion() -> void:
	var coach: Coach = Coach.new()
	var data: Dictionary = {"experience_years": 10}
	coach.from_dict(data)

	assert_int(coach.experience_years).is_equal(10)


func test_partial_dict_uses_defaults() -> void:
	var partial_data: Dictionary = {
		"id": "coach-002",
		"first_name": "Jane"
	}

	var partial_coach: Coach = Coach.new()
	partial_coach.from_dict(partial_data)

	assert_str(partial_coach.id).is_equal("coach-002")
	assert_str(partial_coach.first_name).is_equal("Jane")
	assert_float(partial_coach.coaching_ability).is_equal(50.0)
	assert_int(partial_coach.experience_years).is_equal(0)
	assert_str(partial_coach.character_tolerance).is_equal("moderate")
	assert_str(partial_coach.medical_tolerance).is_equal("cautious")


func test_empty_dict_uses_all_defaults() -> void:
	var empty_coach: Coach = Coach.new()
	empty_coach.from_dict({})

	assert_str(empty_coach.id).is_equal("")
	assert_float(empty_coach.coaching_ability).is_equal(50.0)
	assert_int(empty_coach.experience_years).is_equal(0)
