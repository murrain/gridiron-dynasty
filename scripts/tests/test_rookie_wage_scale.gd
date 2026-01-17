## Test suite for RookieWageScale service
##
## Tests cover:
## 1. Slot value calculation (Pick 1 vs Pick 262)
## 2. 5th year option only for picks 1-32
## 3. Cap hit calculation (total / years)
## 4. Contract breakdown includes all fields
## 5. CSV export generates correct data
## 6. UDFA contract structure is correct
##
extends RefCounted
class_name TestRookieWageScale

const RookieWageScale = preload("res://scripts/core/contracts/RookieWageScale.gd")

const CAP_LIMIT := 200.0  # Standard cap for testing


static func run_all_tests() -> Dictionary:
	var results := {
		"passed": 0,
		"failed": 0,
		"errors": []
	}

	# Run each test
	_run_test("test_slot_value_calculation", results)
	_run_test("test_fifth_year_option_first_round_only", results)
	_run_test("test_cap_hit_calculation", results)
	_run_test("test_contract_fields_complete", results)
	_run_test("test_csv_export_format", results)
	_run_test("test_udfa_contract_structure", results)

	print("\n=== RookieWageScale Test Results ===")
	print("Passed: %d" % results.passed)
	print("Failed: %d" % results.failed)
	if results.errors.size() > 0:
		print("Errors:")
		for error in results.errors:
			print("  - %s" % error)

	return results


static func _run_test(test_name: String, results: Dictionary) -> void:
	var success := false
	var error_msg := ""

	match test_name:
		"test_slot_value_calculation":
			var result := test_slot_value_calculation()
			success = result.success
			error_msg = result.message
		"test_fifth_year_option_first_round_only":
			var result := test_fifth_year_option_first_round_only()
			success = result.success
			error_msg = result.message
		"test_cap_hit_calculation":
			var result := test_cap_hit_calculation()
			success = result.success
			error_msg = result.message
		"test_contract_fields_complete":
			var result := test_contract_fields_complete()
			success = result.success
			error_msg = result.message
		"test_csv_export_format":
			var result := test_csv_export_format()
			success = result.success
			error_msg = result.message
		"test_udfa_contract_structure":
			var result := test_udfa_contract_structure()
			success = result.success
			error_msg = result.message

	if success:
		results.passed += 1
		print("[PASS] %s" % test_name)
	else:
		results.failed += 1
		results.errors.append("%s: %s" % [test_name, error_msg])
		print("[FAIL] %s: %s" % [test_name, error_msg])


## Test 1: Slot value calculation (Pick 1 vs Pick 262)
##
## Verifies that:
## - Pick 1 gets approximately 5% of cap ($10M on $200M cap)
## - Pick 262 gets approximately 0.2% of cap ($400K on $200M cap)
## - Value decays exponentially between picks
static func test_slot_value_calculation() -> Dictionary:
	var pick_1_value := RookieWageScale.get_slot_value(1, CAP_LIMIT)
	var pick_32_value := RookieWageScale.get_slot_value(32, CAP_LIMIT)
	var pick_262_value := RookieWageScale.get_slot_value(262, CAP_LIMIT)

	# Pick 1 should be 5% of cap = $10M
	if abs(pick_1_value - 10.0) > 0.01:
		return {"success": false, "message": "Pick 1 value %.3f != expected 10.0" % pick_1_value}

	# Pick 262 should be at minimum (0.2% of cap = $0.4M)
	var expected_min := CAP_LIMIT * 0.002
	if abs(pick_262_value - expected_min) > 0.01:
		return {"success": false, "message": "Pick 262 value %.3f != expected %.3f" % [pick_262_value, expected_min]}

	# Verify decay: Pick 1 > Pick 32 > Pick 262
	if not (pick_1_value > pick_32_value and pick_32_value > pick_262_value):
		return {"success": false, "message": "Value decay not working: P1=%.2f, P32=%.2f, P262=%.2f" % [pick_1_value, pick_32_value, pick_262_value]}

	return {"success": true, "message": ""}


## Test 2: 5th year option only for picks 1-32
##
## Verifies that:
## - Picks 1-32 (first round) have fifth_year_option = true
## - Picks 33+ have fifth_year_option = false
static func test_fifth_year_option_first_round_only() -> Dictionary:
	# Test first round picks have option
	for pick in [1, 16, 32]:
		var contract := RookieWageScale.get_contract_for_pick(pick, CAP_LIMIT)
		if not contract.get("fifth_year_option", false):
			return {"success": false, "message": "Pick %d should have 5th year option" % pick}

	# Test non-first-round picks do NOT have option
	for pick in [33, 64, 100, 200]:
		var contract := RookieWageScale.get_contract_for_pick(pick, CAP_LIMIT)
		if contract.get("fifth_year_option", false):
			return {"success": false, "message": "Pick %d should NOT have 5th year option" % pick}

	return {"success": true, "message": ""}


## Test 3: Cap hit calculation (total / years)
##
## Verifies that:
## - annual_cap_hit = total_value / 4 years
## - Cap hit matches base salary + prorated bonus
static func test_cap_hit_calculation() -> Dictionary:
	var contract := RookieWageScale.get_contract_for_pick(1, CAP_LIMIT)

	var total := float(contract.get("total_value", 0))
	var years := int(contract.get("years_total", 0))
	var annual_hit := float(contract.get("annual_cap_hit", 0))
	var base_per_year := float(contract.get("base_salary_per_year", 0))
	var signing_bonus := float(contract.get("signing_bonus", 0))

	# Annual cap hit should equal total / years
	var expected_hit := total / float(years)
	if abs(annual_hit - expected_hit) > 0.01:
		return {"success": false, "message": "Annual hit %.3f != expected %.3f" % [annual_hit, expected_hit]}

	# Annual cap hit should equal base + (bonus / years)
	var calc_hit := base_per_year + (signing_bonus / float(years))
	if abs(annual_hit - calc_hit) > 0.01:
		return {"success": false, "message": "Cap hit calculation mismatch: %.3f != %.3f" % [annual_hit, calc_hit]}

	return {"success": true, "message": ""}


## Test 4: Contract breakdown includes all fields
##
## Verifies that all required contract fields are present
static func test_contract_fields_complete() -> Dictionary:
	var contract := RookieWageScale.get_contract_for_pick(1, CAP_LIMIT)

	var required_fields := [
		"type", "pick_number", "round", "signed_year",
		"total_value", "signing_bonus", "base_salary_per_year", "annual_cap_hit",
		"years_total", "years_remaining",
		"fifth_year_option", "fifth_year_value",
		"gtd_remaining", "year_breakdown"
	]

	for field in required_fields:
		if not contract.has(field):
			return {"success": false, "message": "Missing required field: %s" % field}

	# Verify year_breakdown is an array with 4 entries
	var breakdown: Array = contract.get("year_breakdown", [])
	if breakdown.size() != 4:
		return {"success": false, "message": "Year breakdown should have 4 entries, has %d" % breakdown.size()}

	# Verify each year entry has required fields
	for entry in breakdown:
		var e: Dictionary = entry
		if not e.has("year") or not e.has("base_salary") or not e.has("cap_hit"):
			return {"success": false, "message": "Year breakdown entry missing fields"}

	return {"success": true, "message": ""}


## Test 5: CSV export generates correct data
##
## Verifies that:
## - CSV has header row
## - CSV has 262 data rows (full draft)
## - Values are properly formatted
static func test_csv_export_format() -> Dictionary:
	var csv := RookieWageScale.export_to_csv(CAP_LIMIT, 10)  # Just test first 10 picks
	var lines := csv.split("\n")

	# Should have header + 10 data rows
	if lines.size() != 11:
		return {"success": false, "message": "CSV should have 11 lines (header + 10), has %d" % lines.size()}

	# Check header
	var header := lines[0]
	if not header.contains("Pick") or not header.contains("Total Value"):
		return {"success": false, "message": "CSV header missing expected columns"}

	# Check first data row (Pick 1)
	var row_1 := lines[1]
	if not row_1.begins_with("1,"):
		return {"success": false, "message": "First data row should start with '1,'"}

	# Verify values are numeric (no NaN or INF)
	if row_1.contains("nan") or row_1.contains("inf"):
		return {"success": false, "message": "CSV contains invalid numeric values"}

	return {"success": true, "message": ""}


## Test 6: UDFA contract structure
##
## Verifies that UDFA contracts have:
## - type = "udfa_rookie"
## - 3 years (not 4)
## - No signing bonus ($0)
## - No 5th year option
## - No guaranteed money ($0)
static func test_udfa_contract_structure() -> Dictionary:
	var contract := RookieWageScale.create_udfa_contract(2035, CAP_LIMIT)

	# Check type
	if contract.get("type", "") != "udfa_rookie":
		return {"success": false, "message": "UDFA type should be 'udfa_rookie'"}

	# Check years
	if int(contract.get("years_total", 0)) != 3:
		return {"success": false, "message": "UDFA should be 3 years, not %d" % contract.get("years_total", 0)}

	# Check no signing bonus
	if float(contract.get("signing_bonus", -1)) != 0.0:
		return {"success": false, "message": "UDFA should have $0 signing bonus"}

	# Check no 5th year option
	if contract.get("fifth_year_option", true):
		return {"success": false, "message": "UDFA should NOT have 5th year option"}

	# Check no guaranteed money
	if float(contract.get("gtd_remaining", -1)) != 0.0:
		return {"success": false, "message": "UDFA should have $0 guaranteed"}

	# Check base salary is reasonable (around 0.1% of cap = $0.2M)
	var base_salary := float(contract.get("base_salary", 0))
	if base_salary < 0.1 or base_salary > 0.5:
		return {"success": false, "message": "UDFA salary %.3f outside expected range" % base_salary}

	return {"success": true, "message": ""}


## Additional test: Determinism verification
##
## Verifies that same inputs always produce same outputs
static func test_determinism() -> Dictionary:
	# Run calculations multiple times
	var results: Array = []
	for _i in range(3):
		var contract := RookieWageScale.get_contract_for_pick(15, CAP_LIMIT)
		results.append(contract)

	# Verify all results are identical
	for i in range(1, results.size()):
		var prev: Dictionary = results[i - 1]
		var curr: Dictionary = results[i]
		if prev.get("total_value", 0) != curr.get("total_value", 0):
			return {"success": false, "message": "Non-deterministic: different values across calls"}

	return {"success": true, "message": ""}


## Additional test: Compare picks utility
static func test_compare_picks() -> Dictionary:
	var comparison := RookieWageScale.compare_picks(1, 32, CAP_LIMIT)

	if comparison.has("error"):
		return {"success": false, "message": "Comparison returned error"}

	# Pick 1 should cost more than Pick 32
	var savings := float(comparison.get("savings_total", 0))
	if savings <= 0:
		return {"success": false, "message": "Pick 1 should cost more than Pick 32"}

	# Comparison text should exist
	if String(comparison.get("comparison_text", "")).is_empty():
		return {"success": false, "message": "Missing comparison text"}

	return {"success": true, "message": ""}


## Additional test: Legacy format compatibility
static func test_legacy_format() -> Dictionary:
	var legacy := RookieWageScale.to_legacy_contract_format(1, CAP_LIMIT, 2035)

	# Check legacy fields exist
	var required := ["type", "years_total", "years_remaining", "base_salary",
					  "signing_bonus", "annual_value", "fifth_year_option",
					  "gtd_remaining", "signed_year"]

	for field in required:
		if not legacy.has(field):
			return {"success": false, "message": "Legacy format missing field: %s" % field}

	# Type should be "rookie" (not "drafted_rookie")
	if legacy.get("type", "") != "rookie":
		return {"success": false, "message": "Legacy type should be 'rookie'"}

	return {"success": true, "message": ""}
