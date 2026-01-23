extends GdUnitTestSuite
class_name TestRosterEntryModelGdUnit4

const RosterEntry = preload("res://scripts/core/models/RosterEntry.gd")
const RosterContract = preload("res://scripts/core/models/RosterContract.gd")
const Roster = preload("res://scripts/core/models/Roster.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_roster_entry_initialization() -> void:
	var entry = RosterEntry.new()
	assert_str(entry.player_id).is_equal("")
	assert_int(entry.status).is_equal(Roster.RosterStatus.ACTIVE)
	assert_bool(entry.cap_exempt).is_false()
	assert_str(entry.cap_exempt_reason).is_equal("")
	assert_int(entry.ir_eligible_week).is_equal(0)
	assert_object(entry.roster_contract).is_not_null()

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_roster_entry_serialization_roundtrip() -> void:
	var entry = RosterEntry.new()
	entry.player_id = "P001"
	entry.status = Roster.RosterStatus.ACTIVE
	entry.cap_exempt = false
	entry.roster_contract.base_salary = 1000000.0
	entry.roster_contract.signing_bonus_proration = 250000.0

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_str(restored.player_id).is_equal("P001")
	assert_int(restored.status).is_equal(Roster.RosterStatus.ACTIVE)
	assert_bool(restored.cap_exempt).is_false()
	assert_float(restored.roster_contract.base_salary).is_equal(1000000.0)
	assert_float(restored.roster_contract.signing_bonus_proration).is_equal(250000.0)

func test_roster_entry_to_dict_schema() -> void:
	var entry = RosterEntry.new()
	entry.player_id = "P001"

	var dict = entry.to_dict()

	assert_bool(dict.has("player_id")).is_true()
	assert_bool(dict.has("status")).is_true()
	assert_bool(dict.has("cap_exempt")).is_true()
	assert_bool(dict.has("cap_exempt_reason")).is_true()
	assert_bool(dict.has("ir_eligible_week")).is_true()
	assert_bool(dict.has("roster_contract")).is_true()

func test_roster_entry_status_serialized_as_string() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.PRACTICE_SQUAD

	var dict = entry.to_dict()

	assert_str(dict["status"]).is_equal("practice_squad")

func test_roster_entry_from_dict_legacy_contract_format() -> void:
	var entry = RosterEntry.new()
	var dict = {
		"player_id": "P001",
		"status": "active",
		"contract": {  # Legacy format uses "contract" key
			"base_salary": 500000.0,
			"guaranteed": 100000.0
		}
	}

	entry.from_dict(dict)

	assert_str(entry.player_id).is_equal("P001")
	assert_float(entry.roster_contract.base_salary).is_equal(500000.0)
	assert_float(entry.roster_contract.guaranteed).is_equal(100000.0)

func test_roster_entry_from_dict_new_contract_format() -> void:
	var entry = RosterEntry.new()
	var dict = {
		"player_id": "P002",
		"status": "active",
		"roster_contract": {  # New format uses "roster_contract" key
			"base_salary": 750000.0,
			"incentives": 50000.0
		}
	}

	entry.from_dict(dict)

	assert_str(entry.player_id).is_equal("P002")
	assert_float(entry.roster_contract.base_salary).is_equal(750000.0)
	assert_float(entry.roster_contract.incentives).is_equal(50000.0)

func test_roster_entry_from_dict_empty() -> void:
	var entry = RosterEntry.new()
	entry.from_dict({})

	# Should preserve default values
	assert_str(entry.player_id).is_equal("")
	assert_int(entry.status).is_equal(Roster.RosterStatus.ACTIVE)

# =============================================================================
# STATUS PARSING TESTS
# =============================================================================

func test_roster_entry_parse_status_string_variants() -> void:
	var entry = RosterEntry.new()

	var test_cases = [
		{"input": "active", "expected": Roster.RosterStatus.ACTIVE},
		{"input": "practice_squad", "expected": Roster.RosterStatus.PRACTICE_SQUAD},
		{"input": "practice squad", "expected": Roster.RosterStatus.PRACTICE_SQUAD},
		{"input": "ir", "expected": Roster.RosterStatus.INJURED_RESERVE},
		{"input": "injured_reserve", "expected": Roster.RosterStatus.INJURED_RESERVE},
		{"input": "injured reserve", "expected": Roster.RosterStatus.INJURED_RESERVE},
		{"input": "suspended", "expected": Roster.RosterStatus.SUSPENDED}
	]

	for test_case in test_cases:
		var dict = {"status": test_case["input"]}
		entry.from_dict(dict)
		assert_int(entry.status).is_equal(test_case["expected"])

func test_roster_entry_parse_status_case_insensitive() -> void:
	var entry = RosterEntry.new()
	var dict = {"status": "ACTIVE"}

	entry.from_dict(dict)

	assert_int(entry.status).is_equal(Roster.RosterStatus.ACTIVE)

func test_roster_entry_parse_status_unknown_defaults_to_active() -> void:
	var entry = RosterEntry.new()
	var dict = {"status": "unknown_status"}

	entry.from_dict(dict)

	assert_int(entry.status).is_equal(Roster.RosterStatus.ACTIVE)

func test_roster_entry_parse_status_enum_directly() -> void:
	var entry = RosterEntry.new()
	var dict = {"status": Roster.RosterStatus.INJURED_RESERVE}

	entry.from_dict(dict)

	assert_int(entry.status).is_equal(Roster.RosterStatus.INJURED_RESERVE)

# =============================================================================
# BUSINESS LOGIC TESTS
# =============================================================================

func test_roster_entry_is_active() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.ACTIVE

	assert_bool(entry.is_active()).is_true()

func test_roster_entry_is_not_active_when_practice_squad() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.PRACTICE_SQUAD

	assert_bool(entry.is_active()).is_false()

func test_roster_entry_is_on_ir() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.INJURED_RESERVE

	assert_bool(entry.is_on_ir()).is_true()

func test_roster_entry_is_not_on_ir_when_active() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.ACTIVE

	assert_bool(entry.is_on_ir()).is_false()

func test_roster_entry_counts_against_cap() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt = false

	assert_bool(entry.counts_against_cap()).is_true()

func test_roster_entry_does_not_count_against_cap_when_exempt() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt = true

	assert_bool(entry.counts_against_cap()).is_false()

func test_roster_entry_get_cap_charge() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt = false
	entry.roster_contract.base_salary = 1000000.0
	entry.roster_contract.signing_bonus_proration = 200000.0
	entry.roster_contract.guaranteed = 500000.0
	entry.roster_contract.incentives = 100000.0

	var charge = entry.get_cap_charge()
	assert_float(charge).is_equal(1800000.0)

func test_roster_entry_get_cap_charge_when_exempt() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt = true
	entry.roster_contract.base_salary = 1000000.0

	var charge = entry.get_cap_charge()
	assert_float(charge).is_equal(0.0)

func test_roster_entry_get_cap_charge_null_contract() -> void:
	var entry = RosterEntry.new()
	entry.roster_contract = null

	var charge = entry.get_cap_charge()
	assert_float(charge).is_equal(0.0)

# =============================================================================
# CAP EXEMPTION TESTS
# =============================================================================

func test_roster_entry_practice_squad_exemption() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.PRACTICE_SQUAD
	entry.cap_exempt = true
	entry.cap_exempt_reason = "Practice squad"

	assert_bool(entry.counts_against_cap()).is_false()

func test_roster_entry_ir_exemption() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.INJURED_RESERVE
	entry.cap_exempt = true
	entry.cap_exempt_reason = "Injured reserve"
	entry.ir_eligible_week = 8

	assert_bool(entry.counts_against_cap()).is_false()
	assert_int(entry.ir_eligible_week).is_equal(8)

func test_roster_entry_suspended_not_exempt() -> void:
	var entry = RosterEntry.new()
	entry.status = Roster.RosterStatus.SUSPENDED
	entry.cap_exempt = false

	assert_bool(entry.counts_against_cap()).is_true()

# =============================================================================
# EDGE CASES
# =============================================================================

func test_roster_entry_empty_player_id() -> void:
	var entry = RosterEntry.new()
	entry.player_id = ""

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_str(restored.player_id).is_equal("")

func test_roster_entry_negative_ir_week() -> void:
	var entry = RosterEntry.new()
	var dict = {
		"player_id": "P001",
		"ir_eligible_week": -5
	}

	entry.from_dict(dict)

	# Model doesn't clamp, so negative values are preserved
	assert_int(entry.ir_eligible_week).is_equal(-5)

func test_roster_entry_large_ir_week() -> void:
	var entry = RosterEntry.new()
	entry.ir_eligible_week = 999

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_int(restored.ir_eligible_week).is_equal(999)

func test_roster_entry_missing_contract_data() -> void:
	var entry = RosterEntry.new()
	var dict = {
		"player_id": "P001",
		"status": "active"
		# No contract data
	}

	entry.from_dict(dict)

	# Should create default contract
	assert_object(entry.roster_contract).is_not_null()
	assert_float(entry.roster_contract.base_salary).is_equal(0.0)

func test_roster_entry_special_characters_in_player_id() -> void:
	var entry = RosterEntry.new()
	entry.player_id = "P-001_X@2024"

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_str(restored.player_id).is_equal("P-001_X@2024")

func test_roster_entry_long_cap_exempt_reason() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt_reason = "Long exemption reason with multiple words explaining the situation in detail"

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_str(restored.cap_exempt_reason).is_equal("Long exemption reason with multiple words explaining the situation in detail")

func test_roster_entry_all_contract_fields() -> void:
	var entry = RosterEntry.new()
	entry.roster_contract.base_salary = 1000000.0
	entry.roster_contract.signing_bonus_proration = 250000.0
	entry.roster_contract.guaranteed = 500000.0
	entry.roster_contract.incentives = 100000.0
	entry.roster_contract.dead_money = 200000.0

	var dict = entry.to_dict()
	var restored = RosterEntry.new()
	restored.from_dict(dict)

	assert_float(restored.roster_contract.base_salary).is_equal(1000000.0)
	assert_float(restored.roster_contract.signing_bonus_proration).is_equal(250000.0)
	assert_float(restored.roster_contract.guaranteed).is_equal(500000.0)
	assert_float(restored.roster_contract.incentives).is_equal(100000.0)
	assert_float(restored.roster_contract.dead_money).is_equal(200000.0)

func test_roster_entry_dead_money_not_in_cap_charge() -> void:
	var entry = RosterEntry.new()
	entry.cap_exempt = false
	entry.roster_contract.base_salary = 1000000.0
	entry.roster_contract.dead_money = 500000.0  # Should not be included

	var charge = entry.get_cap_charge()
	assert_float(charge).is_equal(1000000.0)

func test_roster_entry_multiple_status_transitions() -> void:
	var entry = RosterEntry.new()
	entry.player_id = "P001"

	# Active -> IR
	entry.status = Roster.RosterStatus.INJURED_RESERVE
	entry.cap_exempt = true
	entry.cap_exempt_reason = "Injured reserve"

	var dict1 = entry.to_dict()

	# IR -> Active
	entry.status = Roster.RosterStatus.ACTIVE
	entry.cap_exempt = false
	entry.cap_exempt_reason = ""

	var dict2 = entry.to_dict()

	var restored1 = RosterEntry.new()
	restored1.from_dict(dict1)
	assert_int(restored1.status).is_equal(Roster.RosterStatus.INJURED_RESERVE)

	var restored2 = RosterEntry.new()
	restored2.from_dict(dict2)
	assert_int(restored2.status).is_equal(Roster.RosterStatus.ACTIVE)
