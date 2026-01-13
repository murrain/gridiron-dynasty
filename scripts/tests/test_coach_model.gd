extends RefCounted

const Coach = preload("res://scripts/core/models/Coach.gd")

func run(t) -> void:
	test_default_values(t)
	test_full_serialization_round_trip(t)
	test_type_conversion_edge_cases(t)

func test_default_values(t) -> void:
	var coach: Coach = Coach.new()

	# Test default identity values
	t.assert_eq(coach.id, "", "default id is empty string")
	t.assert_eq(coach.first_name, "", "default first_name is empty string")
	t.assert_eq(coach.last_name, "", "default last_name is empty string")
	t.assert_eq(coach.role, "", "default role is empty string")

	# Test default coaching attributes
	t.assert_eq(coach.coaching_ability, 50.0, "default coaching_ability is 50.0")
	t.assert_eq(coach.recruiting_skill, 50.0, "default recruiting_skill is 50.0")
	t.assert_eq(coach.player_development, 50.0, "default player_development is 50.0")

	# Test default experience & background
	t.assert_eq(coach.experience_years, 0, "default experience_years is 0")
	t.assert_eq(coach.specialty_position, "", "default specialty_position is empty string")
	t.assert_eq(coach.scheme_preference, "", "default scheme_preference is empty string")

	# Test default player evaluation philosophy
	t.assert_eq(coach.character_tolerance, "moderate", "default character_tolerance is moderate")
	t.assert_eq(coach.medical_tolerance, "cautious", "default medical_tolerance is cautious")

func test_full_serialization_round_trip(t) -> void:
	var coach: Coach = Coach.new()
	coach.id = "coach-001"
	coach.first_name = "John"
	coach.last_name = "Smith"
	coach.role = "Head Coach"
	coach.coaching_ability = 85.5
	coach.recruiting_skill = 72.3
	coach.player_development = 90.1
	coach.experience_years = 15
	coach.specialty_position = "Defense"
	coach.scheme_preference = "spread"
	coach.character_tolerance = "strict"
	coach.medical_tolerance = "aggressive"

	var serialized: Dictionary = coach.to_dict()
	var clone: Coach = Coach.new()
	clone.from_dict(serialized)
	var round_trip: Dictionary = clone.to_dict()

	# Test identity round-trips
	t.assert_eq(round_trip.get("id", ""), "coach-001", "id round-trips")
	t.assert_eq(round_trip.get("first_name", ""), "John", "first_name round-trips")
	t.assert_eq(round_trip.get("last_name", ""), "Smith", "last_name round-trips")
	t.assert_eq(round_trip.get("role", ""), "Head Coach", "role round-trips")

	# Test coaching attributes round-trips
	t.assert_eq(round_trip.get("coaching_ability", 0.0), 85.5, "coaching_ability round-trips")
	t.assert_eq(round_trip.get("recruiting_skill", 0.0), 72.3, "recruiting_skill round-trips")
	t.assert_eq(round_trip.get("player_development", 0.0), 90.1, "player_development round-trips")

	# Test experience & background round-trips
	t.assert_eq(round_trip.get("experience_years", 0), 15, "experience_years round-trips")
	t.assert_eq(round_trip.get("specialty_position", ""), "Defense", "specialty_position round-trips")
	t.assert_eq(round_trip.get("scheme_preference", ""), "spread", "scheme_preference round-trips")

	# Test player evaluation philosophy round-trips
	t.assert_eq(round_trip.get("character_tolerance", ""), "strict", "character_tolerance round-trips")
	t.assert_eq(round_trip.get("medical_tolerance", ""), "aggressive", "medical_tolerance round-trips")

func test_type_conversion_edge_cases(t) -> void:
	var coach: Coach = Coach.new()

	# Test conversion from string numbers to proper types
	var data: Dictionary = {
		"id": "123",  # string id
		"first_name": "Test",
		"coaching_ability": 75.5,
		"recruiting_skill": 80,  # int instead of float (should convert)
		"player_development": 65.0,
		"experience_years": 10,
		"specialty_position": "Defense",
		"scheme_preference": "west_coast"
	}

	coach.from_dict(data)

	# Test type conversions handled gracefully
	t.assert_eq(coach.id, "123", "id as string works")
	t.assert_eq(coach.first_name, "Test", "first_name as string works")
	t.assert_eq(coach.coaching_ability, 75.5, "coaching_ability as float works")
	t.assert_eq(coach.recruiting_skill, 80.0, "recruiting_skill converts int to float")
	t.assert_eq(coach.experience_years, 10, "experience_years as int works")
	t.assert_eq(coach.specialty_position, "Defense", "specialty_position as string works")
	t.assert_eq(coach.scheme_preference, "west_coast", "scheme_preference as string works")

	# Test partial dictionary (missing keys use defaults)
	var partial_data: Dictionary = {
		"id": "coach-002",
		"first_name": "Jane"
		# All other fields missing
	}

	var partial_coach: Coach = Coach.new()
	partial_coach.from_dict(partial_data)

	t.assert_eq(partial_coach.id, "coach-002", "partial dict: id is set")
	t.assert_eq(partial_coach.first_name, "Jane", "partial dict: first_name is set")
	t.assert_eq(partial_coach.coaching_ability, 50.0, "partial dict: coaching_ability uses default")
	t.assert_eq(partial_coach.experience_years, 0, "partial dict: experience_years uses default")
	t.assert_eq(partial_coach.character_tolerance, "moderate", "partial dict: character_tolerance uses default")
	t.assert_eq(partial_coach.medical_tolerance, "cautious", "partial dict: medical_tolerance uses default")

	# Test empty dictionary (all fields use defaults)
	var empty_coach: Coach = Coach.new()
	empty_coach.from_dict({})

	t.assert_eq(empty_coach.id, "", "empty dict: id uses default")
	t.assert_eq(empty_coach.coaching_ability, 50.0, "empty dict: coaching_ability uses default")
	t.assert_eq(empty_coach.experience_years, 0, "empty dict: experience_years uses default")
