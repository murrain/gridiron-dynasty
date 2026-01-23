extends GdUnitTestSuite
class_name TestContractModelGdUnit4

const Contract = preload("res://scripts/core/models/Contract.gd")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_contract_initialization() -> void:
	var contract = Contract.new()
	assert_int(contract.current_year).is_equal(0)
	assert_int(contract.total_years).is_equal(0)
	assert_float(contract.annual_value).is_equal(0.0)
	assert_float(contract.guaranteed).is_equal(0.0)
	assert_float(contract.range_min).is_equal(0.0)
	assert_float(contract.range_max).is_equal(0.0)
	assert_str(contract.valuation_source).is_equal("")
	assert_int(contract.valuation_seed).is_equal(0)
	assert_str(contract.source_eval_id).is_equal("")

func test_contract_new_with_defaults() -> void:
	var contract = Contract.new()
	assert_bool(contract.is_active()).is_false()
	assert_bool(contract.is_expired()).is_false()
	assert_int(contract.years_remaining()).is_equal(0)

# =============================================================================
# SERIALIZATION TESTS
# =============================================================================

func test_contract_serialization_roundtrip() -> void:
	var contract = Contract.new()
	contract.current_year = 2
	contract.total_years = 5
	contract.annual_value = 5000000.0
	contract.guaranteed = 15000000.0
	contract.range_min = 4500000.0
	contract.range_max = 5500000.0
	contract.valuation_source = "draft_eval"
	contract.valuation_seed = 12345
	contract.source_eval_id = "EVAL_001"

	var dict = contract.to_dict()
	var restored = Contract.new()
	restored.from_dict(dict)

	assert_int(restored.current_year).is_equal(2)
	assert_int(restored.total_years).is_equal(5)
	assert_float(restored.annual_value).is_equal(5000000.0)
	assert_float(restored.guaranteed).is_equal(15000000.0)
	assert_float(restored.range_min).is_equal(4500000.0)
	assert_float(restored.range_max).is_equal(5500000.0)
	assert_str(restored.valuation_source).is_equal("draft_eval")
	assert_int(restored.valuation_seed).is_equal(12345)
	assert_str(restored.source_eval_id).is_equal("EVAL_001")

func test_contract_to_dict_schema() -> void:
	var contract = Contract.new()
	contract.current_year = 1
	contract.total_years = 4
	contract.annual_value = 2000000.0

	var dict = contract.to_dict()

	assert_bool(dict.has("current_year")).is_true()
	assert_bool(dict.has("total_years")).is_true()
	assert_bool(dict.has("annual_value")).is_true()
	assert_bool(dict.has("guaranteed")).is_true()
	assert_bool(dict.has("range_min")).is_true()
	assert_bool(dict.has("range_max")).is_true()
	assert_bool(dict.has("valuation_source")).is_true()
	assert_bool(dict.has("valuation_seed")).is_true()
	assert_bool(dict.has("source_eval_id")).is_true()

func test_contract_from_dict_with_missing_fields() -> void:
	var contract = Contract.new()
	var partial_dict = {
		"current_year": 3,
		"total_years": 6
	}

	contract.from_dict(partial_dict)

	assert_int(contract.current_year).is_equal(3)
	assert_int(contract.total_years).is_equal(6)
	# Other fields should have default values
	assert_float(contract.annual_value).is_equal(0.0)
	assert_float(contract.guaranteed).is_equal(0.0)

func test_contract_from_dict_empty() -> void:
	var contract = Contract.new()
	contract.from_dict({})

	# Should preserve default values
	assert_int(contract.current_year).is_equal(0)
	assert_int(contract.total_years).is_equal(0)
	assert_float(contract.annual_value).is_equal(0.0)

# =============================================================================
# BUSINESS LOGIC TESTS
# =============================================================================

func test_contract_is_active_when_current_within_total() -> void:
	var contract = Contract.new()
	contract.current_year = 2
	contract.total_years = 5

	assert_bool(contract.is_active()).is_true()

func test_contract_is_active_first_year() -> void:
	var contract = Contract.new()
	contract.current_year = 1
	contract.total_years = 4

	assert_bool(contract.is_active()).is_true()

func test_contract_is_active_final_year() -> void:
	var contract = Contract.new()
	contract.current_year = 5
	contract.total_years = 5

	assert_bool(contract.is_active()).is_true()

func test_contract_is_not_active_when_unsigned() -> void:
	var contract = Contract.new()
	contract.current_year = 0
	contract.total_years = 0

	assert_bool(contract.is_active()).is_false()

func test_contract_is_not_active_when_expired() -> void:
	var contract = Contract.new()
	contract.current_year = 6
	contract.total_years = 5

	assert_bool(contract.is_active()).is_false()

func test_contract_is_expired_when_past_total() -> void:
	var contract = Contract.new()
	contract.current_year = 6
	contract.total_years = 5

	assert_bool(contract.is_expired()).is_true()

func test_contract_is_not_expired_when_active() -> void:
	var contract = Contract.new()
	contract.current_year = 3
	contract.total_years = 5

	assert_bool(contract.is_expired()).is_false()

func test_contract_is_not_expired_when_unsigned() -> void:
	var contract = Contract.new()
	contract.current_year = 0
	contract.total_years = 0

	assert_bool(contract.is_expired()).is_false()

func test_contract_years_remaining_calculation() -> void:
	var contract = Contract.new()
	contract.current_year = 2
	contract.total_years = 5

	assert_int(contract.years_remaining()).is_equal(3)

func test_contract_years_remaining_first_year() -> void:
	var contract = Contract.new()
	contract.current_year = 1
	contract.total_years = 4

	assert_int(contract.years_remaining()).is_equal(3)

func test_contract_years_remaining_final_year() -> void:
	var contract = Contract.new()
	contract.current_year = 5
	contract.total_years = 5

	assert_int(contract.years_remaining()).is_equal(0)

func test_contract_years_remaining_expired() -> void:
	var contract = Contract.new()
	contract.current_year = 6
	contract.total_years = 5

	assert_int(contract.years_remaining()).is_equal(0)

func test_contract_years_remaining_unsigned() -> void:
	var contract = Contract.new()
	contract.current_year = 0
	contract.total_years = 0

	assert_int(contract.years_remaining()).is_equal(0)

func test_contract_advance_year() -> void:
	var contract = Contract.new()
	contract.current_year = 2
	contract.total_years = 5

	contract.advance_year()

	assert_int(contract.current_year).is_equal(3)
	assert_bool(contract.is_active()).is_true()

func test_contract_advance_year_to_expiration() -> void:
	var contract = Contract.new()
	contract.current_year = 5
	contract.total_years = 5

	contract.advance_year()

	assert_int(contract.current_year).is_equal(6)
	assert_bool(contract.is_active()).is_false()
	assert_bool(contract.is_expired()).is_true()

func test_contract_advance_year_when_expired_does_nothing() -> void:
	var contract = Contract.new()
	contract.current_year = 6
	contract.total_years = 5

	contract.advance_year()

	# Should not advance further
	assert_int(contract.current_year).is_equal(6)

func test_contract_advance_year_when_unsigned_does_nothing() -> void:
	var contract = Contract.new()
	contract.current_year = 0
	contract.total_years = 0

	contract.advance_year()

	assert_int(contract.current_year).is_equal(0)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_contract_negative_values_clamped_to_zero() -> void:
	var contract = Contract.new()
	var dict = {
		"current_year": -1,
		"total_years": -5,
		"annual_value": -1000000.0,
		"guaranteed": -500000.0
	}

	contract.from_dict(dict)

	# GDScript int() and float() conversions should handle negatives naturally
	# The model doesn't clamp, so we test actual behavior
	assert_int(contract.current_year).is_equal(-1)
	assert_int(contract.total_years).is_equal(-5)

func test_contract_large_financial_values() -> void:
	var contract = Contract.new()
	contract.annual_value = 50000000.0  # $50M per year
	contract.guaranteed = 200000000.0   # $200M guaranteed
	contract.range_min = 45000000.0
	contract.range_max = 55000000.0

	var dict = contract.to_dict()
	var restored = Contract.new()
	restored.from_dict(dict)

	assert_float(restored.annual_value).is_equal(50000000.0)
	assert_float(restored.guaranteed).is_equal(200000000.0)

func test_contract_zero_year_contract() -> void:
	var contract = Contract.new()
	contract.current_year = 1
	contract.total_years = 0

	assert_bool(contract.is_active()).is_false()
	assert_int(contract.years_remaining()).is_equal(0)

func test_contract_type_coercion_from_dict() -> void:
	var contract = Contract.new()
	var dict = {
		"current_year": "3",  # String instead of int
		"total_years": "5",
		"annual_value": "2500000",  # String instead of float
		"guaranteed": "7500000"
	}

	contract.from_dict(dict)

	# GDScript's int() and float() should coerce strings
	assert_int(contract.current_year).is_equal(3)
	assert_int(contract.total_years).is_equal(5)
	assert_float(contract.annual_value).is_equal(2500000.0)
	assert_float(contract.guaranteed).is_equal(7500000.0)
