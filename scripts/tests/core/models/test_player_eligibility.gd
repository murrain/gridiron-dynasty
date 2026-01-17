## Tests for Player draft eligibility methods
##
## Tests the following Player.gd methods:
##   - is_draft_eligible() - derived property for draft pool inclusion
##   - is_underclassman() - check for remaining eligibility
##   - years_remaining serialization and backward compatibility
##   - declared_for_draft serialization
##
## Test count: 8 tests as specified in DRAFT-002

extends RefCounted

const Player = preload("res://scripts/core/models/Player.gd")


func run(t) -> void:
	test_is_draft_eligible_declared_underclassman(t)
	test_is_draft_eligible_exhausted_senior(t)
	test_is_draft_eligible_stage_already_eligible(t)
	test_is_draft_eligible_returning_underclassman(t)
	test_is_underclassman_true_cases(t)
	test_is_underclassman_false_cases(t)
	test_years_remaining_backward_compatibility(t)
	test_draft_eligibility_serialization_round_trip(t)


## Test 1: Underclassman who has declared for draft should be eligible
func test_is_draft_eligible_declared_underclassman(t) -> void:
	var player := Player.new()
	player.stage = Player.PlayerStage.COLLEGE
	player.years_remaining = 2  # Sophomore with 2 years left
	player.declared_for_draft = true

	t.assert_eq(player.is_draft_eligible(), true,
		"Declared underclassman should be draft eligible")


## Test 2: Senior who has exhausted eligibility should be auto-eligible
func test_is_draft_eligible_exhausted_senior(t) -> void:
	var player := Player.new()
	player.stage = Player.PlayerStage.COLLEGE
	player.years_remaining = 0  # Senior, no years left
	player.declared_for_draft = false  # Not explicitly declared

	t.assert_eq(player.is_draft_eligible(), true,
		"Senior with exhausted eligibility should be auto-eligible")


## Test 3: Player already in DRAFT_ELIGIBLE stage should be eligible
func test_is_draft_eligible_stage_already_eligible(t) -> void:
	var player := Player.new()
	player.stage = Player.PlayerStage.DRAFT_ELIGIBLE
	player.years_remaining = 1
	player.declared_for_draft = false

	t.assert_eq(player.is_draft_eligible(), true,
		"Player with DRAFT_ELIGIBLE stage should be eligible")


## Test 4: Underclassman who has NOT declared should NOT be eligible
func test_is_draft_eligible_returning_underclassman(t) -> void:
	var player := Player.new()
	player.stage = Player.PlayerStage.COLLEGE
	player.years_remaining = 2  # Has years left
	player.declared_for_draft = false  # Not declared

	t.assert_eq(player.is_draft_eligible(), false,
		"Non-declared underclassman should NOT be draft eligible")


## Test 5: is_underclassman returns true for college players with years left
func test_is_underclassman_true_cases(t) -> void:
	# Junior with 1 year left
	var junior := Player.new()
	junior.stage = Player.PlayerStage.COLLEGE
	junior.years_remaining = 1
	t.assert_eq(junior.is_underclassman(), true,
		"Junior with 1 year should be underclassman")

	# Sophomore with 2 years left
	var sophomore := Player.new()
	sophomore.stage = Player.PlayerStage.COLLEGE
	sophomore.years_remaining = 2
	t.assert_eq(sophomore.is_underclassman(), true,
		"Sophomore with 2 years should be underclassman")

	# Freshman with 3 years left
	var freshman := Player.new()
	freshman.stage = Player.PlayerStage.COLLEGE
	freshman.years_remaining = 3
	t.assert_eq(freshman.is_underclassman(), true,
		"Freshman with 3 years should be underclassman")


## Test 6: is_underclassman returns false for non-eligible cases
func test_is_underclassman_false_cases(t) -> void:
	# Senior with no years left
	var senior := Player.new()
	senior.stage = Player.PlayerStage.COLLEGE
	senior.years_remaining = 0
	t.assert_eq(senior.is_underclassman(), false,
		"Senior with 0 years should NOT be underclassman")

	# NFL player
	var nfl_player := Player.new()
	nfl_player.stage = Player.PlayerStage.NFL_ROOKIE
	nfl_player.years_remaining = 0
	t.assert_eq(nfl_player.is_underclassman(), false,
		"NFL player should NOT be underclassman")

	# High school player
	var hs_player := Player.new()
	hs_player.stage = Player.PlayerStage.HIGH_SCHOOL
	hs_player.years_remaining = 4
	t.assert_eq(hs_player.is_underclassman(), false,
		"HS player should NOT be underclassman (not in COLLEGE stage)")


## Test 7: years_remaining backward compatibility inference from age
func test_years_remaining_backward_compatibility(t) -> void:
	# Old save without years_remaining field
	# Should infer from age

	# Age 19 (freshman) -> years_remaining = 4
	var data_freshman := {"age": 19}
	var p1 := Player.new()
	p1.from_dict(data_freshman)
	t.assert_eq(p1.years_remaining, 4,
		"Age 19 should infer years_remaining = 4")

	# Age 20 (sophomore) -> years_remaining = 3
	var data_sophomore := {"age": 20}
	var p2 := Player.new()
	p2.from_dict(data_sophomore)
	t.assert_eq(p2.years_remaining, 3,
		"Age 20 should infer years_remaining = 3")

	# Age 21 (junior) -> years_remaining = 2
	var data_junior := {"age": 21}
	var p3 := Player.new()
	p3.from_dict(data_junior)
	t.assert_eq(p3.years_remaining, 2,
		"Age 21 should infer years_remaining = 2")

	# Age 22 (senior) -> years_remaining = 1
	var data_senior := {"age": 22}
	var p4 := Player.new()
	p4.from_dict(data_senior)
	t.assert_eq(p4.years_remaining, 1,
		"Age 22 should infer years_remaining = 1")

	# Age 23+ (exhausted) -> years_remaining = 0
	var data_exhausted := {"age": 23}
	var p5 := Player.new()
	p5.from_dict(data_exhausted)
	t.assert_eq(p5.years_remaining, 0,
		"Age 23+ should infer years_remaining = 0")


## Test 8: Draft eligibility fields round-trip serialization
func test_draft_eligibility_serialization_round_trip(t) -> void:
	var player := Player.new()
	player.id = "p-test-eligibility"
	player.position = "QB"
	player.age = 21
	player.stage = Player.PlayerStage.COLLEGE
	player.years_remaining = 2
	player.declared_for_draft = true
	player.declaration_year = 2025

	var serialized := player.to_dict()
	var clone := Player.new()
	clone.from_dict(serialized)
	var round_trip := clone.to_dict()

	t.assert_eq(round_trip.get("years_remaining"), 2,
		"years_remaining round-trips correctly")
	t.assert_eq(round_trip.get("declared_for_draft"), true,
		"declared_for_draft round-trips correctly")
	t.assert_eq(round_trip.get("declaration_year"), 2025,
		"declaration_year round-trips correctly")

	# Verify the clone has correct derived property
	t.assert_eq(clone.is_draft_eligible(), true,
		"is_draft_eligible works correctly after deserialization")
