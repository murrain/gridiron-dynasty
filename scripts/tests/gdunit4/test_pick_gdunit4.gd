extends GdUnitTestSuite
class_name TestPickGdUnit4

const Pick = preload("res://scripts/core/trades/Pick.gd")

## Test creating a new Pick instance
func test_create_pick() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 1
	pick.slot = 15
	pick.original_team_id = "TEAM_A"
	pick.current_owner_id = "TEAM_B"

	assert_int(pick.year).is_equal(2025)
	assert_int(pick.round).is_equal(1)
	assert_int(pick.slot).is_equal(15)
	assert_string(pick.original_team_id).is_equal("TEAM_A")
	assert_string(pick.current_owner_id).is_equal("TEAM_B")

## Test to_dict serialization
func test_to_dict() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 2
	pick.slot = 10
	pick.original_team_id = "TEAM_C"
	pick.current_owner_id = "TEAM_D"

	var dict := pick.to_dict()

	assert_int(dict["year"]).is_equal(2025)
	assert_int(dict["round"]).is_equal(2)
	assert_int(dict["slot"]).is_equal(10)
	assert_string(dict["original_team_id"]).is_equal("TEAM_C")
	assert_string(dict["current_owner_id"]).is_equal("TEAM_D")

## Test from_dict deserialization
func test_from_dict() -> void:
	var dict := {
		"year": 2026,
		"round": 3,
		"slot": 5,
		"original_team_id": "TEAM_E",
		"current_owner_id": "TEAM_F"
	}

	var pick = Pick.from_dict(dict)

	assert_int(pick.year).is_equal(2026)
	assert_int(pick.round).is_equal(3)
	assert_int(pick.slot).is_equal(5)
	assert_string(pick.original_team_id).is_equal("TEAM_E")
	assert_string(pick.current_owner_id).is_equal("TEAM_F")

## Test round-trip serialization
func test_round_trip_serialization() -> void:
	var original := Pick.new()
	original.year = 2025
	original.round = 1
	original.slot = 1
	original.original_team_id = "TEAM_A"
	original.current_owner_id = "TEAM_B"

	var dict := original.to_dict()
	var restored = Pick.from_dict(dict)

	assert_int(restored.year).is_equal(original.year)
	assert_int(restored.round).is_equal(original.round)
	assert_int(restored.slot).is_equal(original.slot)
	assert_string(restored.original_team_id).is_equal(original.original_team_id)
	assert_string(restored.current_owner_id).is_equal(original.current_owner_id)

## Test Pick with default values
func test_pick_defaults() -> void:
	var pick := Pick.new()

	assert_int(pick.year).is_equal(0)
	assert_int(pick.round).is_equal(0)
	assert_int(pick.slot).is_equal(0)
	assert_string(pick.original_team_id).is_equal("")
	assert_string(pick.current_owner_id).is_equal("")

## Test from_dict with missing fields uses defaults
func test_from_dict_missing_fields() -> void:
	var dict := {}

	var pick = Pick.from_dict(dict)

	assert_int(pick.year).is_equal(0)
	assert_int(pick.round).is_equal(0)
	assert_int(pick.slot).is_equal(0)
	assert_string(pick.original_team_id).is_equal("")
	assert_string(pick.current_owner_id).is_equal("")

## Test from_dict with partial data
func test_from_dict_partial() -> void:
	var dict := {
		"year": 2025,
		"round": 1
	}

	var pick = Pick.from_dict(dict)

	assert_int(pick.year).is_equal(2025)
	assert_int(pick.round).is_equal(1)
	assert_int(pick.slot).is_equal(0)
	assert_string(pick.original_team_id).is_equal("")
	assert_string(pick.current_owner_id).is_equal("")

## Test first overall pick
func test_first_overall_pick() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 1
	pick.slot = 1
	pick.original_team_id = "TEAM_WORST"
	pick.current_owner_id = "TEAM_WORST"

	assert_int(pick.round).is_equal(1)
	assert_int(pick.slot).is_equal(1)

## Test late round pick
func test_late_round_pick() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 7
	pick.slot = 32
	pick.original_team_id = "TEAM_BEST"
	pick.current_owner_id = "TEAM_BEST"

	assert_int(pick.round).is_equal(7)
	assert_int(pick.slot).is_equal(32)

## Test traded pick (different owner)
func test_traded_pick() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 1
	pick.slot = 10
	pick.original_team_id = "TEAM_A"
	pick.current_owner_id = "TEAM_B"  # Different owner

	assert_string(pick.original_team_id).is_not_equal(pick.current_owner_id)

## Test pick ownership transfer
func test_pick_ownership_transfer() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 1
	pick.slot = 15
	pick.original_team_id = "TEAM_A"
	pick.current_owner_id = "TEAM_A"

	# Trade the pick
	pick.current_owner_id = "TEAM_B"

	assert_string(pick.original_team_id).is_equal("TEAM_A")
	assert_string(pick.current_owner_id).is_equal("TEAM_B")

## Test multiple picks with different values
func test_multiple_picks() -> void:
	var pick1 := Pick.new()
	pick1.round = 1
	pick1.slot = 1

	var pick2 := Pick.new()
	pick2.round = 1
	pick2.slot = 32

	var pick3 := Pick.new()
	pick3.round = 7
	pick3.slot = 32

	# First overall is round 1, slot 1
	assert_int(pick1.round).is_equal(1)
	assert_int(pick1.slot).is_equal(1)

	# Last pick of round 1
	assert_int(pick2.round).is_equal(1)
	assert_int(pick2.slot).is_equal(32)

	# Mr. Irrelevant
	assert_int(pick3.round).is_equal(7)
	assert_int(pick3.slot).is_equal(32)

## Test future year pick
func test_future_year_pick() -> void:
	var pick := Pick.new()
	pick.year = 2027  # Future year
	pick.round = 1
	pick.slot = 10
	pick.original_team_id = "TEAM_A"
	pick.current_owner_id = "TEAM_B"

	assert_int(pick.year).is_equal(2027)

## Test compensatory pick (e.g., slot 33)
func test_compensatory_pick() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 3
	pick.slot = 33  # Compensatory pick after standard 32
	pick.original_team_id = "NFL"
	pick.current_owner_id = "TEAM_A"

	assert_int(pick.slot).is_equal(33)

## Test to_dict creates a copy
func test_to_dict_creates_copy() -> void:
	var pick := Pick.new()
	pick.year = 2025
	pick.round = 1
	pick.slot = 1
	pick.original_team_id = "TEAM_A"
	pick.current_owner_id = "TEAM_A"

	var dict := pick.to_dict()

	# Modify dict
	dict["year"] = 2026
	dict["round"] = 2

	# Original pick should be unchanged
	assert_int(pick.year).is_equal(2025)
	assert_int(pick.round).is_equal(1)
