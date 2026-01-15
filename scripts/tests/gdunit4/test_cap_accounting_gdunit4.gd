## GdUnit4 test suite for CapAccounting
##
## Validates salary cap calculations.
## Migrated from test_cap_accounting.gd
extends GdUnitTestSuite

const CapAccounting = preload("res://scripts/core/finance/CapAccounting.gd")


func test_cap_used_sums_contract_cap_fields() -> void:
	var roster := [
		{
			"name": "QB1",
			"contract": {
				"base_salary": 2.0,
				"signing_bonus_proration": 1.0,
				"guaranteed": 0.25,
				"incentives": 0.0
			}
		},
		{
			"name": "RB1",
			"contract": {
				"base_salary": 1.0,
				"signing_bonus_proration": 0.5,
				"guaranteed": 0.0,
				"incentives": 0.25
			}
		},
		{
			"name": "LB1",
			"contract": {
				"base_salary": 2.0,
				"signing_bonus_proration": 0.0,
				"guaranteed": 0.0,
				"incentives": 0.0
			}
		}
	]

	var cap_used := CapAccounting.cap_used(roster)
	assert_float(cap_used).is_equal_approx(7.0, 0.0001)
