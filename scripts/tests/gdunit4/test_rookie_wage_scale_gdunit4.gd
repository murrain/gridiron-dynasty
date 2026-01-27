extends GdUnitTestSuite
class_name TestRookieWageScaleGdUnit4

const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")

## Test get_contract_for_pick first overall
func test_first_overall_pick() -> void:
	var cap_limit := 200.0
	var contract := RookieWageScale.get_contract_for_pick(1, cap_limit)

	assert_int(contract["pick_number"]).is_equal(1)
	assert_int(contract["round"]).is_equal(1)
	assert_bool(contract["fifth_year_option"]).is_true()
	assert_float(contract["total_value"]).is_greater(0.0)
	assert_int(contract["years_total"]).is_equal(4)

## Test first overall has highest value
func test_first_overall_highest_value() -> void:
	var cap_limit := 200.0

	var pick_1 := RookieWageScale.get_contract_for_pick(1, cap_limit)
	var pick_10 := RookieWageScale.get_contract_for_pick(10, cap_limit)
	var pick_32 := RookieWageScale.get_contract_for_pick(32, cap_limit)

	assert_float(pick_1["total_value"]).is_greater(pick_10["total_value"])
	assert_float(pick_10["total_value"]).is_greater(pick_32["total_value"])

## Test round 1 picks get 5th year option
func test_round_1_fifth_year_option() -> void:
	var cap_limit := 200.0

	var pick_1 := RookieWageScale.get_contract_for_pick(1, cap_limit)
	var pick_32 := RookieWageScale.get_contract_for_pick(32, cap_limit)

	assert_bool(pick_1["fifth_year_option"]).is_true()
	assert_bool(pick_32["fifth_year_option"]).is_true()
	assert_float(pick_1["fifth_year_value"]).is_greater(0.0)

## Test round 2 picks do not get 5th year option
func test_round_2_no_fifth_year_option() -> void:
	var cap_limit := 200.0

	var pick_33 := RookieWageScale.get_contract_for_pick(33, cap_limit)

	assert_int(pick_33["round"]).is_equal(2)
	assert_bool(pick_33["fifth_year_option"]).is_false()
	assert_float(pick_33["fifth_year_value"]).is_equal(0.0)

## Test get_slot_value decreases with pick number
func test_slot_value_decreases() -> void:
	var cap_limit := 200.0

	var value_1 := RookieWageScale.get_slot_value(1, cap_limit)
	var value_50 := RookieWageScale.get_slot_value(50, cap_limit)
	var value_100 := RookieWageScale.get_slot_value(100, cap_limit)
	var value_200 := RookieWageScale.get_slot_value(200, cap_limit)

	assert_float(value_1).is_greater(value_50)
	assert_float(value_50).is_greater(value_100)
	assert_float(value_100).is_greater(value_200)

## Test get_slot_value with different cap limits
func test_slot_value_scales_with_cap() -> void:
	var pick := 1

	var value_200 := RookieWageScale.get_slot_value(pick, 200.0)
	var value_300 := RookieWageScale.get_slot_value(pick, 300.0)

	# Value should scale proportionally with cap
	var ratio := value_300 / value_200
	assert_float(ratio).is_equal(1.5)

## Test contract structure has all required fields
func test_contract_structure() -> void:
	var contract := RookieWageScale.get_contract_for_pick(1, 200.0)

	# Identification
	assert_that(contract).contains_key("type")
	assert_that(contract).contains_key("pick_number")
	assert_that(contract).contains_key("round")
	assert_that(contract).contains_key("signed_year")

	# Value breakdown
	assert_that(contract).contains_key("total_value")
	assert_that(contract).contains_key("signing_bonus")
	assert_that(contract).contains_key("base_salary_per_year")
	assert_that(contract).contains_key("annual_cap_hit")

	# Contract structure
	assert_that(contract).contains_key("years_total")
	assert_that(contract).contains_key("years_remaining")

	# 5th year option
	assert_that(contract).contains_key("fifth_year_option")
	assert_that(contract).contains_key("fifth_year_value")

	# Guarantees
	assert_that(contract).contains_key("gtd_remaining")

	# Year breakdown
	assert_that(contract).contains_key("year_breakdown")

## Test signing bonus is 60% of total value
func test_signing_bonus_percentage() -> void:
	var contract := RookieWageScale.get_contract_for_pick(10, 200.0)

	var expected_bonus := contract["total_value"] * 0.6
	assert_float(contract["signing_bonus"]).is_equal(expected_bonus)

## Test annual cap hit calculation
func test_annual_cap_hit() -> void:
	var contract := RookieWageScale.get_contract_for_pick(15, 200.0)

	var signing_bonus := contract["signing_bonus"]
	var total_value := contract["total_value"]
	var years := contract["years_total"]

	var base_per_year := (total_value - signing_bonus) / float(years)
	var bonus_per_year := signing_bonus / float(years)
	var expected_cap_hit := base_per_year + bonus_per_year

	assert_float(contract["annual_cap_hit"]).is_equal(expected_cap_hit)

## Test create_udfa_contract
func test_create_udfa_contract() -> void:
	var contract := RookieWageScale.create_udfa_contract(2025, 200.0)

	assert_string(contract["type"]).is_equal("udfa_rookie")
	assert_int(contract["years_total"]).is_equal(3)
	assert_float(contract["signing_bonus"]).is_equal(0.0)
	assert_bool(contract["fifth_year_option"]).is_false()
	assert_float(contract["gtd_remaining"]).is_equal(0.0)

## Test UDFA value is much lower than drafted
func test_udfa_lower_than_drafted() -> void:
	var drafted := RookieWageScale.get_contract_for_pick(262, 200.0)  # Mr. Irrelevant
	var udfa := RookieWageScale.create_udfa_contract(2025, 200.0)

	# UDFA should be worth less than even the last pick
	assert_float(udfa["base_salary"] * 3).is_less(drafted["total_value"])

## Test compare_picks
func test_compare_picks() -> void:
	var comparison := RookieWageScale.compare_picks(1, 32, 200.0)

	assert_that(comparison).contains_key("pick_a")
	assert_that(comparison).contains_key("pick_b")
	assert_that(comparison).contains_key("contract_a")
	assert_that(comparison).contains_key("contract_b")
	assert_that(comparison).contains_key("savings_total")
	assert_that(comparison).contains_key("savings_per_year")
	assert_that(comparison).contains_key("comparison_text")

	# Pick 1 should cost more than pick 32
	assert_float(comparison["savings_total"]).is_greater(0.0)

## Test compare_picks savings calculation
func test_compare_picks_savings() -> void:
	var comparison := RookieWageScale.compare_picks(10, 20, 200.0)

	var contract_a := comparison["contract_a"]
	var contract_b := comparison["contract_b"]

	var expected_savings := contract_a["total_value"] - contract_b["total_value"]
	assert_float(comparison["savings_total"]).is_equal(expected_savings)

## Test get_round_contracts
func test_get_round_contracts() -> void:
	var round_1 := RookieWageScale.get_round_contracts(1, 200.0)

	assert_int(round_1.size()).is_equal(32)
	# All should be round 1
	for contract in round_1:
		assert_int(contract["round"]).is_equal(1)

## Test get_round_contracts for different rounds
func test_get_round_contracts_multiple_rounds() -> void:
	var round_1 := RookieWageScale.get_round_contracts(1, 200.0)
	var round_2 := RookieWageScale.get_round_contracts(2, 200.0)
	var round_7 := RookieWageScale.get_round_contracts(7, 200.0)

	# Round 1 should be more valuable than round 2
	assert_float(round_1[0]["total_value"]).is_greater(round_2[0]["total_value"])
	# Round 2 should be more valuable than round 7
	assert_float(round_2[0]["total_value"]).is_greater(round_7[0]["total_value"])

## Test get_round_contracts invalid round
func test_get_round_contracts_invalid() -> void:
	var invalid := RookieWageScale.get_round_contracts(0, 200.0)
	assert_that(invalid).is_empty()

	var invalid2 := RookieWageScale.get_round_contracts(8, 200.0)
	assert_that(invalid2).is_empty()

## Test get_wage_scale_summary
func test_get_wage_scale_summary() -> void:
	var summary := RookieWageScale.get_wage_scale_summary(200.0)

	assert_that(summary).contains_key("cap_limit")
	assert_that(summary).contains_key("pick_1_value")
	assert_that(summary).contains_key("pick_last_round_1_value")
	assert_that(summary).contains_key("pick_last_round_2_value")
	assert_that(summary).contains_key("round_1_total")

	assert_float(summary["cap_limit"]).is_equal(200.0)
	assert_float(summary["pick_1_value"]).is_greater(0.0)

## Test to_legacy_contract_format
func test_to_legacy_contract_format() -> void:
	var legacy := RookieWageScale.to_legacy_contract_format(1, 200.0, 2025)

	assert_string(legacy["type"]).is_equal("rookie")
	assert_that(legacy).contains_key("years_total")
	assert_that(legacy).contains_key("years_remaining")
	assert_that(legacy).contains_key("base_salary")
	assert_that(legacy).contains_key("signing_bonus")
	assert_that(legacy).contains_key("annual_value")
	assert_that(legacy).contains_key("fifth_year_option")
	assert_that(legacy).contains_key("gtd_remaining")
	assert_that(legacy).contains_key("signed_year")

## Test year_breakdown has correct structure
func test_year_breakdown() -> void:
	var contract := RookieWageScale.get_contract_for_pick(15, 200.0)
	var breakdown: Array = contract["year_breakdown"]

	assert_int(breakdown.size()).is_equal(4)

	for i in range(breakdown.size()):
		var year_data: Dictionary = breakdown[i]
		assert_that(year_data).contains_key("year")
		assert_that(year_data).contains_key("base_salary")
		assert_that(year_data).contains_key("bonus_proration")
		assert_that(year_data).contains_key("cap_hit")

		assert_int(year_data["year"]).is_equal(i + 1)

## Test guaranteed money for top picks
func test_guaranteed_money_top_picks() -> void:
	var pick_1 := RookieWageScale.get_contract_for_pick(1, 200.0)
	var pick_5 := RookieWageScale.get_contract_for_pick(5, 200.0)
	var pick_20 := RookieWageScale.get_contract_for_pick(20, 200.0)

	# Top picks should have substantial guaranteed money
	assert_float(pick_1["gtd_remaining"]).is_greater(pick_20["gtd_remaining"])
	assert_float(pick_5["gtd_remaining"]).is_greater(0.0)

## Test late round picks have less guarantee
func test_late_round_lower_guarantee() -> void:
	var round_1 := RookieWageScale.get_contract_for_pick(32, 200.0)
	var round_5 := RookieWageScale.get_contract_for_pick(150, 200.0)

	assert_float(round_1["gtd_remaining"]).is_greater(round_5["gtd_remaining"])

## Test calculations are deterministic
func test_calculations_deterministic() -> void:
	var contract1 := RookieWageScale.get_contract_for_pick(15, 200.0)
	var contract2 := RookieWageScale.get_contract_for_pick(15, 200.0)
	var contract3 := RookieWageScale.get_contract_for_pick(15, 200.0)

	assert_float(contract1["total_value"]).is_equal(contract2["total_value"])
	assert_float(contract2["total_value"]).is_equal(contract3["total_value"])
	assert_float(contract1["signing_bonus"]).is_equal(contract2["signing_bonus"])

## Test pick 1 is approximately 5% of cap
func test_pick_1_cap_percentage() -> void:
	var cap_limit := 200.0
	var contract := RookieWageScale.get_contract_for_pick(1, cap_limit)

	# Total value should be approximately 5% of cap (200 * 0.05 = 10)
	var expected_total := cap_limit * 0.05 * 4  # 4 years
	assert_float(contract["total_value"]).is_greater(expected_total * 0.8)
	assert_float(contract["total_value"]).is_less(expected_total * 1.2)

## Test export_to_csv produces valid output
func test_export_to_csv() -> void:
	var csv := RookieWageScale.export_to_csv(200.0, 10)

	# Should have header + 10 picks
	var lines := csv.split("\n")
	assert_int(lines.size()).is_equal(11)

	# First line should be header
	assert_bool(lines[0].contains("Pick")).is_true()
	assert_bool(lines[0].contains("Round")).is_true()
	assert_bool(lines[0].contains("Total Value")).is_true()

## Test invalid pick number returns empty
func test_invalid_pick_number() -> void:
	var contract := RookieWageScale.get_contract_for_pick(0, 200.0)
	assert_that(contract).is_empty()

	var contract2 := RookieWageScale.get_contract_for_pick(-1, 200.0)
	assert_that(contract2).is_empty()

## Test slot value for invalid pick is zero
func test_slot_value_invalid_pick() -> void:
	var value := RookieWageScale.get_slot_value(0, 200.0)
	assert_float(value).is_equal(0.0)

	var value2 := RookieWageScale.get_slot_value(-5, 200.0)
	assert_float(value2).is_equal(0.0)

## Test contract type is correct
func test_contract_type() -> void:
	var drafted := RookieWageScale.get_contract_for_pick(50, 200.0)
	assert_string(drafted["type"]).is_equal("drafted_rookie")

	var udfa := RookieWageScale.create_udfa_contract(2025, 200.0)
	assert_string(udfa["type"]).is_equal("udfa_rookie")

## Test years_total equals years_remaining for new contract
func test_years_total_equals_remaining() -> void:
	var contract := RookieWageScale.get_contract_for_pick(25, 200.0)

	assert_int(contract["years_total"]).is_equal(contract["years_remaining"])
	assert_int(contract["years_total"]).is_equal(4)

## Test realistic scenario - trading up cost
func test_realistic_trading_up_cost() -> void:
	var pick_5 := RookieWageScale.get_contract_for_pick(5, 200.0)
	var pick_15 := RookieWageScale.get_contract_for_pick(15, 200.0)

	# Trading from 15 to 5 saves significant cap space
	var savings := pick_5["annual_cap_hit"] - pick_15["annual_cap_hit"]
	assert_float(savings).is_greater(0.0)
