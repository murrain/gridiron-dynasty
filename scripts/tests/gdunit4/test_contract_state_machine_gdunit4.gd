extends GdUnitTestSuite
class_name TestContractStateMachine

const ContractStateMachine = preload("res://scripts/core/state/ContractStateMachine.gd")

# ============================================================================
# CONTRACT STATE TRANSITION TESTS
# ============================================================================

func test_unsigned_valid_transitions() -> void:
	# UNSIGNED can transition to SIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.SIGNED
	)).is_true()

	# UNSIGNED can transition to FRANCHISE_TAGGED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.FRANCHISE_TAGGED
	)).is_true()


func test_unsigned_invalid_transitions() -> void:
	# UNSIGNED cannot skip to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_false()

	# UNSIGNED cannot go to EXPIRED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.EXPIRED
	)).is_false()

	# UNSIGNED cannot go to RELEASED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.RELEASED
	)).is_false()


func test_signed_valid_transitions() -> void:
	# SIGNED can transition to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_true()

	# SIGNED can transition to RELEASED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.RELEASED
	)).is_true()

	# SIGNED can transition to VOIDED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.VOIDED
	)).is_true()

	# SIGNED can transition to RESTRUCTURED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.RESTRUCTURED
	)).is_true()


func test_active_valid_transitions() -> void:
	# ACTIVE can transition to EXPIRED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.EXPIRED
	)).is_true()

	# ACTIVE can transition to RELEASED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.RELEASED
	)).is_true()

	# ACTIVE can transition to RESTRUCTURED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.RESTRUCTURED
	)).is_true()

	# ACTIVE can transition to VOIDED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.VOIDED
	)).is_true()


func test_active_invalid_transitions() -> void:
	# ACTIVE cannot go back to SIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.SIGNED
	)).is_false()

	# ACTIVE cannot go back to UNSIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.UNSIGNED
	)).is_false()


func test_expired_transitions() -> void:
	# EXPIRED can transition to UNSIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.EXPIRED,
		ContractStateMachine.ContractState.UNSIGNED
	)).is_true()

	# EXPIRED can transition to SIGNED (re-sign)
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.EXPIRED,
		ContractStateMachine.ContractState.SIGNED
	)).is_true()

	# EXPIRED can transition to FRANCHISE_TAGGED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.EXPIRED,
		ContractStateMachine.ContractState.FRANCHISE_TAGGED
	)).is_true()


func test_released_transitions() -> void:
	# RELEASED can only transition to UNSIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.RELEASED,
		ContractStateMachine.ContractState.UNSIGNED
	)).is_true()

	# RELEASED cannot go to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.RELEASED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_false()


func test_franchise_tagged_transitions() -> void:
	# FRANCHISE_TAGGED can transition to SIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.FRANCHISE_TAGGED,
		ContractStateMachine.ContractState.SIGNED
	)).is_true()

	# FRANCHISE_TAGGED can transition to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.FRANCHISE_TAGGED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_true()

	# FRANCHISE_TAGGED can transition to EXPIRED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.FRANCHISE_TAGGED,
		ContractStateMachine.ContractState.EXPIRED
	)).is_true()


func test_voided_transitions() -> void:
	# VOIDED can only transition to UNSIGNED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.VOIDED,
		ContractStateMachine.ContractState.UNSIGNED
	)).is_true()

	# VOIDED cannot transition to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.VOIDED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_false()


func test_restructured_transitions() -> void:
	# RESTRUCTURED can transition to ACTIVE
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.RESTRUCTURED,
		ContractStateMachine.ContractState.ACTIVE
	)).is_true()

	# RESTRUCTURED can transition to RELEASED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.RESTRUCTURED,
		ContractStateMachine.ContractState.RELEASED
	)).is_true()

	# RESTRUCTURED can transition to EXPIRED
	assert_bool(ContractStateMachine.can_transition_contract(
		ContractStateMachine.ContractState.RESTRUCTURED,
		ContractStateMachine.ContractState.EXPIRED
	)).is_true()


# ============================================================================
# GET VALID NEXT STATES TESTS
# ============================================================================

func test_get_valid_next_states_unsigned() -> void:
	var next_states = ContractStateMachine.get_valid_next_contract_states(
		ContractStateMachine.ContractState.UNSIGNED
	)
	assert_array(next_states).contains([
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.FRANCHISE_TAGGED
	])
	assert_int(next_states.size()).is_equal(2)


func test_get_valid_next_states_active() -> void:
	var next_states = ContractStateMachine.get_valid_next_contract_states(
		ContractStateMachine.ContractState.ACTIVE
	)
	assert_array(next_states).contains([
		ContractStateMachine.ContractState.EXPIRED,
		ContractStateMachine.ContractState.RELEASED,
		ContractStateMachine.ContractState.RESTRUCTURED,
		ContractStateMachine.ContractState.VOIDED
	])
	assert_int(next_states.size()).is_equal(4)


func test_get_valid_next_states_returns_copy() -> void:
	var next_states1 = ContractStateMachine.get_valid_next_contract_states(
		ContractStateMachine.ContractState.UNSIGNED
	)
	var next_states2 = ContractStateMachine.get_valid_next_contract_states(
		ContractStateMachine.ContractState.UNSIGNED
	)

	# Modify first array
	next_states1.append(ContractStateMachine.ContractState.ACTIVE)

	# Second array should be unchanged
	assert_int(next_states2.size()).is_equal(2)


# ============================================================================
# TERMINAL STATE TESTS
# ============================================================================

func test_no_terminal_contract_states() -> void:
	# No contract states are terminal in this system
	assert_bool(ContractStateMachine.is_terminal_contract_state(
		ContractStateMachine.ContractState.UNSIGNED
	)).is_false()

	assert_bool(ContractStateMachine.is_terminal_contract_state(
		ContractStateMachine.ContractState.RELEASED
	)).is_false()

	assert_bool(ContractStateMachine.is_terminal_contract_state(
		ContractStateMachine.ContractState.VOIDED
	)).is_false()


# ============================================================================
# STRING CONVERSION TESTS
# ============================================================================

func test_contract_state_to_string() -> void:
	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.UNSIGNED
	)).is_equal("UNSIGNED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.SIGNED
	)).is_equal("SIGNED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.ACTIVE
	)).is_equal("ACTIVE")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.EXPIRED
	)).is_equal("EXPIRED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.RELEASED
	)).is_equal("RELEASED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.FRANCHISE_TAGGED
	)).is_equal("FRANCHISE_TAGGED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.VOIDED
	)).is_equal("VOIDED")

	assert_str(ContractStateMachine.contract_state_to_string(
		ContractStateMachine.ContractState.RESTRUCTURED
	)).is_equal("RESTRUCTURED")


func test_string_to_contract_state() -> void:
	assert_int(ContractStateMachine.string_to_contract_state("UNSIGNED")).is_equal(
		ContractStateMachine.ContractState.UNSIGNED
	)

	assert_int(ContractStateMachine.string_to_contract_state("SIGNED")).is_equal(
		ContractStateMachine.ContractState.SIGNED
	)

	assert_int(ContractStateMachine.string_to_contract_state("ACTIVE")).is_equal(
		ContractStateMachine.ContractState.ACTIVE
	)

	assert_int(ContractStateMachine.string_to_contract_state("FRANCHISE_TAGGED")).is_equal(
		ContractStateMachine.ContractState.FRANCHISE_TAGGED
	)


func test_string_to_contract_state_case_insensitive() -> void:
	assert_int(ContractStateMachine.string_to_contract_state("unsigned")).is_equal(
		ContractStateMachine.ContractState.UNSIGNED
	)

	assert_int(ContractStateMachine.string_to_contract_state("Signed")).is_equal(
		ContractStateMachine.ContractState.SIGNED
	)

	assert_int(ContractStateMachine.string_to_contract_state("AcTiVe")).is_equal(
		ContractStateMachine.ContractState.ACTIVE
	)


func test_string_to_contract_state_unknown_defaults_to_unsigned() -> void:
	assert_int(ContractStateMachine.string_to_contract_state("INVALID")).is_equal(
		ContractStateMachine.ContractState.UNSIGNED
	)

	assert_int(ContractStateMachine.string_to_contract_state("")).is_equal(
		ContractStateMachine.ContractState.UNSIGNED
	)


func test_contract_state_string_round_trip() -> void:
	var states := [
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.EXPIRED,
		ContractStateMachine.ContractState.RELEASED,
		ContractStateMachine.ContractState.FRANCHISE_TAGGED,
		ContractStateMachine.ContractState.VOIDED,
		ContractStateMachine.ContractState.RESTRUCTURED
	]

	for state in states:
		var state_str := ContractStateMachine.contract_state_to_string(state)
		var state_back := ContractStateMachine.string_to_contract_state(state_str)
		assert_int(state_back).is_equal(state)


# ============================================================================
# FREE AGENCY PERIOD TRANSITION TESTS
# ============================================================================

func test_fa_period_valid_transitions() -> void:
	# CLOSED can transition to PREP
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.CLOSED,
		ContractStateMachine.FAPeriod.PREP
	)).is_true()

	# PREP can transition to TAGS_APPLIED
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.PREP,
		ContractStateMachine.FAPeriod.TAGS_APPLIED
	)).is_true()

	# PREP can skip to MARKET_OPEN
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.PREP,
		ContractStateMachine.FAPeriod.MARKET_OPEN
	)).is_true()

	# MARKET_OPEN can transition to SIGNINGS_COMPLETE
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.MARKET_OPEN,
		ContractStateMachine.FAPeriod.SIGNINGS_COMPLETE
	)).is_true()


func test_fa_period_invalid_transitions() -> void:
	# CLOSED cannot skip to MARKET_OPEN
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.CLOSED,
		ContractStateMachine.FAPeriod.MARKET_OPEN
	)).is_false()

	# TAGS_APPLIED cannot go back to PREP
	assert_bool(ContractStateMachine.can_transition_fa_period(
		ContractStateMachine.FAPeriod.TAGS_APPLIED,
		ContractStateMachine.FAPeriod.PREP
	)).is_false()


func test_get_valid_next_fa_periods() -> void:
	var next_periods = ContractStateMachine.get_valid_next_fa_periods(
		ContractStateMachine.FAPeriod.PREP
	)
	assert_array(next_periods).contains([
		ContractStateMachine.FAPeriod.TAGS_APPLIED,
		ContractStateMachine.FAPeriod.MARKET_OPEN
	])
	assert_int(next_periods.size()).is_equal(2)


func test_fa_period_to_string() -> void:
	assert_str(ContractStateMachine.fa_period_to_string(
		ContractStateMachine.FAPeriod.CLOSED
	)).is_equal("CLOSED")

	assert_str(ContractStateMachine.fa_period_to_string(
		ContractStateMachine.FAPeriod.MARKET_OPEN
	)).is_equal("MARKET_OPEN")

	assert_str(ContractStateMachine.fa_period_to_string(
		ContractStateMachine.FAPeriod.YEAR_ROUND
	)).is_equal("YEAR_ROUND")


func test_string_to_fa_period() -> void:
	assert_int(ContractStateMachine.string_to_fa_period("CLOSED")).is_equal(
		ContractStateMachine.FAPeriod.CLOSED
	)

	assert_int(ContractStateMachine.string_to_fa_period("MARKET_OPEN")).is_equal(
		ContractStateMachine.FAPeriod.MARKET_OPEN
	)


func test_fa_period_string_round_trip() -> void:
	var periods := [
		ContractStateMachine.FAPeriod.CLOSED,
		ContractStateMachine.FAPeriod.PREP,
		ContractStateMachine.FAPeriod.TAGS_APPLIED,
		ContractStateMachine.FAPeriod.MARKET_OPEN,
		ContractStateMachine.FAPeriod.SIGNINGS_COMPLETE,
		ContractStateMachine.FAPeriod.YEAR_ROUND
	]

	for period in periods:
		var period_str := ContractStateMachine.fa_period_to_string(period)
		var period_back := ContractStateMachine.string_to_fa_period(period_str)
		assert_int(period_back).is_equal(period)


# ============================================================================
# VALIDATION HELPER TESTS
# ============================================================================

func test_is_eligible_for_franchise_tag() -> void:
	# UNSIGNED is eligible
	assert_bool(ContractStateMachine.is_eligible_for_franchise_tag(
		ContractStateMachine.ContractState.UNSIGNED
	)).is_true()

	# EXPIRED is eligible
	assert_bool(ContractStateMachine.is_eligible_for_franchise_tag(
		ContractStateMachine.ContractState.EXPIRED
	)).is_true()

	# ACTIVE is not eligible
	assert_bool(ContractStateMachine.is_eligible_for_franchise_tag(
		ContractStateMachine.ContractState.ACTIVE
	)).is_false()

	# SIGNED is not eligible
	assert_bool(ContractStateMachine.is_eligible_for_franchise_tag(
		ContractStateMachine.ContractState.SIGNED
	)).is_false()


func test_can_release_contract() -> void:
	# SIGNED can be released
	assert_bool(ContractStateMachine.can_release_contract(
		ContractStateMachine.ContractState.SIGNED
	)).is_true()

	# ACTIVE can be released
	assert_bool(ContractStateMachine.can_release_contract(
		ContractStateMachine.ContractState.ACTIVE
	)).is_true()

	# RESTRUCTURED can be released
	assert_bool(ContractStateMachine.can_release_contract(
		ContractStateMachine.ContractState.RESTRUCTURED
	)).is_true()

	# UNSIGNED cannot be released
	assert_bool(ContractStateMachine.can_release_contract(
		ContractStateMachine.ContractState.UNSIGNED
	)).is_false()

	# EXPIRED cannot be released
	assert_bool(ContractStateMachine.can_release_contract(
		ContractStateMachine.ContractState.EXPIRED
	)).is_false()


func test_can_restructure_contract() -> void:
	# SIGNED can be restructured
	assert_bool(ContractStateMachine.can_restructure_contract(
		ContractStateMachine.ContractState.SIGNED
	)).is_true()

	# ACTIVE can be restructured
	assert_bool(ContractStateMachine.can_restructure_contract(
		ContractStateMachine.ContractState.ACTIVE
	)).is_true()

	# UNSIGNED cannot be restructured
	assert_bool(ContractStateMachine.can_restructure_contract(
		ContractStateMachine.ContractState.UNSIGNED
	)).is_false()

	# EXPIRED cannot be restructured
	assert_bool(ContractStateMachine.can_restructure_contract(
		ContractStateMachine.ContractState.EXPIRED
	)).is_false()


func test_validate_contract_transition_trigger() -> void:
	# Valid trigger for UNSIGNED->SIGNED
	assert_bool(ContractStateMachine.validate_contract_transition_trigger(
		ContractStateMachine.ContractState.UNSIGNED,
		ContractStateMachine.ContractState.SIGNED,
		"free_agency_signed"
	)).is_true()

	# Valid trigger for SIGNED->ACTIVE
	assert_bool(ContractStateMachine.validate_contract_transition_trigger(
		ContractStateMachine.ContractState.SIGNED,
		ContractStateMachine.ContractState.ACTIVE,
		"season_start"
	)).is_true()

	# Valid trigger for ACTIVE->RELEASED
	assert_bool(ContractStateMachine.validate_contract_transition_trigger(
		ContractStateMachine.ContractState.ACTIVE,
		ContractStateMachine.ContractState.RELEASED,
		"roster_cut"
	)).is_true()
