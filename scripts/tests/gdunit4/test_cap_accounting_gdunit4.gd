extends GdUnitTestSuite
class_name TestCapAccountingGdUnit4

const CapAccounting = preload("res://scripts/core/finance/CapAccounting.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

## Test cap_used with empty roster
func test_cap_used_empty_roster() -> void:
	var roster := []
	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(0.0)

## Test cap_used with single player
func test_cap_used_single_player() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 5.0,
				"signing_bonus_proration": 1.0,
				"guaranteed": 2.0,
				"incentives": 0.5
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# 5 + 1 + 2 + 0.5 = 8.5
	assert_float(used).is_equal(8.5)

## Test cap_used with multiple players
func test_cap_used_multiple_players() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 10.0,
				"signing_bonus_proration": 2.0,
				"guaranteed": 3.0,
				"incentives": 1.0
			}
		},
		{
			"contract": {
				"base_salary": 8.0,
				"signing_bonus_proration": 1.5,
				"guaranteed": 2.5,
				"incentives": 0.5
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# Player 1: 10 + 2 + 3 + 1 = 16
	# Player 2: 8 + 1.5 + 2.5 + 0.5 = 12.5
	# Total: 28.5
	assert_float(used).is_equal(28.5)

## Test cap_used with cap_exempt player
func test_cap_used_with_exempt_player() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 10.0,
				"signing_bonus_proration": 2.0,
				"guaranteed": 3.0,
				"incentives": 1.0
			}
		},
		{
			"cap_exempt": true,
			"contract": {
				"base_salary": 5.0,
				"signing_bonus_proration": 1.0,
				"guaranteed": 1.5,
				"incentives": 0.5
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# Only first player counts (16.0)
	assert_float(used).is_equal(16.0)

## Test cap_used with missing contract fields defaults to zero
func test_cap_used_missing_contract_fields() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 10.0
				# Other fields missing
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# Only base_salary counts
	assert_float(used).is_equal(10.0)

## Test cap_used with no contract
func test_cap_used_no_contract() -> void:
	var roster := [
		{
			"name": "Player1"
			# No contract field
		}
	]

	var used := CapAccounting.cap_used(roster)
	# Should count as 0
	assert_float(used).is_equal(0.0)

## Test cap_used with zero values
func test_cap_used_zero_values() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 0.0,
				"signing_bonus_proration": 0.0,
				"guaranteed": 0.0,
				"incentives": 0.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(0.0)

## Test cap_used with base_salary only
func test_cap_used_base_salary_only() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 15.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(15.0)

## Test cap_used with signing bonus only
func test_cap_used_signing_bonus_only() -> void:
	var roster := [
		{
			"contract": {
				"signing_bonus_proration": 5.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(5.0)

## Test cap_used with guaranteed only
func test_cap_used_guaranteed_only() -> void:
	var roster := [
		{
			"contract": {
				"guaranteed": 8.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(8.0)

## Test cap_used with incentives only
func test_cap_used_incentives_only() -> void:
	var roster := [
		{
			"contract": {
				"incentives": 2.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(2.0)

## Test realistic NFL roster
func test_realistic_nfl_roster() -> void:
	var roster := []

	# Star QB
	roster.append({
		"contract": {
			"base_salary": 35.0,
			"signing_bonus_proration": 8.0,
			"guaranteed": 10.0,
			"incentives": 2.0
		}
	})

	# Star WR
	roster.append({
		"contract": {
			"base_salary": 20.0,
			"signing_bonus_proration": 5.0,
			"guaranteed": 8.0,
			"incentives": 1.0
		}
	})

	# Veterans (x5)
	for i in range(5):
		roster.append({
			"contract": {
				"base_salary": 8.0,
				"signing_bonus_proration": 1.0,
				"guaranteed": 2.0,
				"incentives": 0.5
			}
		})

	# Rookies (x10)
	for i in range(10):
		roster.append({
			"contract": {
				"base_salary": 1.0,
				"signing_bonus_proration": 0.2,
				"guaranteed": 0.5,
				"incentives": 0.0
			}
		})

	var used := CapAccounting.cap_used(roster)

	# QB: 55, WR: 34, Veterans: 57.5, Rookies: 17
	# Total: 163.5
	assert_float(used).is_equal(163.5)

## Test cap_used with practice squad players (exempt)
func test_cap_used_practice_squad() -> void:
	var roster := [
		# Active roster
		{
			"contract": {
				"base_salary": 5.0,
				"signing_bonus_proration": 1.0,
				"guaranteed": 1.0,
				"incentives": 0.5
			}
		},
		# Practice squad (exempt)
		{
			"cap_exempt": true,
			"contract": {
				"base_salary": 0.2,
				"signing_bonus_proration": 0.0,
				"guaranteed": 0.0,
				"incentives": 0.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# Only active roster player counts
	assert_float(used).is_equal(7.5)

## Test cap_used is deterministic
func test_cap_used_deterministic() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 10.0,
				"signing_bonus_proration": 2.0,
				"guaranteed": 3.0,
				"incentives": 1.0
			}
		}
	]

	var used1 := CapAccounting.cap_used(roster)
	var used2 := CapAccounting.cap_used(roster)
	var used3 := CapAccounting.cap_used(roster)

	assert_float(used1).is_equal(used2)
	assert_float(used2).is_equal(used3)

## Test cap_used with large roster (53 players)
func test_cap_used_full_roster() -> void:
	var roster := []

	for i in range(53):
		roster.append({
			"contract": {
				"base_salary": 2.0,
				"signing_bonus_proration": 0.5,
				"guaranteed": 0.5,
				"incentives": 0.2
			}
		})

	var used := CapAccounting.cap_used(roster)
	# 53 * (2.0 + 0.5 + 0.5 + 0.2) = 53 * 3.2 = 169.6
	assert_float(used).is_equal(169.6)

## Test cap_used with mixed exempt and non-exempt
func test_cap_used_mixed_exempt() -> void:
	var roster := [
		{"contract": {"base_salary": 10.0}},
		{"cap_exempt": true, "contract": {"base_salary": 5.0}},
		{"contract": {"base_salary": 8.0}},
		{"cap_exempt": true, "contract": {"base_salary": 3.0}},
		{"contract": {"base_salary": 12.0}}
	]

	var used := CapAccounting.cap_used(roster)
	# Non-exempt: 10 + 8 + 12 = 30
	assert_float(used).is_equal(30.0)

## Test cap_used with fractional values
func test_cap_used_fractional_values() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 5.75,
				"signing_bonus_proration": 1.25,
				"guaranteed": 2.33,
				"incentives": 0.67
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# 5.75 + 1.25 + 2.33 + 0.67 = 10.0
	assert_float(used).is_equal(10.0)

## Test cap_used with very large values
func test_cap_used_large_values() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 50.0,
				"signing_bonus_proration": 20.0,
				"guaranteed": 30.0,
				"incentives": 5.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	assert_float(used).is_equal(105.0)

## Test cap_used with negative values (shouldn't happen but handle)
func test_cap_used_negative_values() -> void:
	var roster := [
		{
			"contract": {
				"base_salary": 10.0,
				"signing_bonus_proration": -2.0,  # Dead cap credit?
				"guaranteed": 3.0,
				"incentives": 1.0
			}
		}
	]

	var used := CapAccounting.cap_used(roster)
	# 10 - 2 + 3 + 1 = 12
	assert_float(used).is_equal(12.0)
