extends RefCounted
class_name ContractStateMachine

## ContractStateMachine - Formal state machine for contract lifecycle transitions
##
## Single source of truth for valid contract state transitions and free agency period management.
## Ensures all transitions follow defined rules and provides clear lifecycle path.
##
## Usage:
##   # Check if transition is valid
##   if ContractStateMachine.can_transition_contract(contract_state, ContractState.RELEASED):
##       ContractStateMachine.transition_contract(contract, ContractState.RELEASED, "roster_cut")
##
##   # Check FA period transition
##   if ContractStateMachine.can_transition_fa_period(current_period, FAPeriod.MARKET_OPEN):
##       # Proceed with FA market opening
##
##   # Get valid next states
##   var next_states = ContractStateMachine.get_valid_next_contract_states(current_state)

## Contract lifecycle states
enum ContractState {
	UNSIGNED,          ## Player has no contract (draft eligible, UDFA, released)
	SIGNED,            ## Contract signed but not yet active (between signing and season start)
	ACTIVE,            ## Contract is currently in effect during season
	EXPIRED,           ## Contract has reached end of term naturally
	RELEASED,          ## Player was released before contract end
	FRANCHISE_TAGGED,  ## Player has franchise tag (special 1-year guaranteed contract)
	VOIDED,            ## Contract voided (rare: conduct issues, failed physical, etc.)
	RESTRUCTURED       ## Contract restructured (cap manipulation, not a terminal state)
}

## Free agency period states
enum FAPeriod {
	CLOSED,            ## No free agency activity (during season, off-season)
	PREP,              ## Preparing for FA (identifying FAs, evaluating needs)
	TAGS_APPLIED,      ## Franchise/transition tags have been applied
	MARKET_OPEN,       ## FA market is open for signings
	SIGNINGS_COMPLETE, ## Primary FA period closed (late signings still possible)
	YEAR_ROUND         ## Year-round FA (post-draft UDFA signings, mid-season replacements)
}

## Valid contract state transitions
## Each state maps to array of states it can transition to
const VALID_CONTRACT_TRANSITIONS := {
	ContractState.UNSIGNED: [
		ContractState.SIGNED,           # Sign FA contract
		ContractState.FRANCHISE_TAGGED, # Apply franchise tag to pending FA
	],
	ContractState.SIGNED: [
		ContractState.ACTIVE,           # Season starts, contract becomes active
		ContractState.RELEASED,         # Released before season starts (rare)
		ContractState.VOIDED,           # Contract voided (rare)
		ContractState.RESTRUCTURED      # Restructure before activation
	],
	ContractState.ACTIVE: [
		ContractState.EXPIRED,          # Contract term ends naturally
		ContractState.RELEASED,         # Player released mid-contract
		ContractState.RESTRUCTURED,     # Restructure during active term
		ContractState.VOIDED            # Contract voided (rare)
	],
	ContractState.EXPIRED: [
		ContractState.UNSIGNED,         # Player enters FA pool
		ContractState.SIGNED,           # Re-sign immediately (extension timing)
		ContractState.FRANCHISE_TAGGED  # Apply franchise tag
	],
	ContractState.RELEASED: [
		ContractState.UNSIGNED          # Released player becomes FA
	],
	ContractState.FRANCHISE_TAGGED: [
		ContractState.SIGNED,           # Sign long-term deal
		ContractState.ACTIVE,           # Tag year becomes active
		ContractState.EXPIRED           # Tag year ends
	],
	ContractState.VOIDED: [
		ContractState.UNSIGNED          # Voided contract returns to FA
	],
	ContractState.RESTRUCTURED: [
		ContractState.ACTIVE,           # Restructure completes, remains active
		ContractState.RELEASED,         # Released after restructure
		ContractState.EXPIRED           # Restructured contract expires
	]
}

## Valid FA period transitions
const VALID_FA_PERIOD_TRANSITIONS := {
	FAPeriod.CLOSED: [
		FAPeriod.PREP               # Begin FA preparation
	],
	FAPeriod.PREP: [
		FAPeriod.TAGS_APPLIED,      # Apply franchise tags
		FAPeriod.MARKET_OPEN        # Skip tags, open market directly
	],
	FAPeriod.TAGS_APPLIED: [
		FAPeriod.MARKET_OPEN        # Open FA market after tag deadline
	],
	FAPeriod.MARKET_OPEN: [
		FAPeriod.SIGNINGS_COMPLETE, # Close primary FA window
		FAPeriod.YEAR_ROUND         # Transition to year-round FA
	],
	FAPeriod.SIGNINGS_COMPLETE: [
		FAPeriod.YEAR_ROUND,        # Transition to year-round FA
		FAPeriod.CLOSED             # Close FA period entirely
	],
	FAPeriod.YEAR_ROUND: [
		FAPeriod.CLOSED             # Close year-round FA (rare)
	]
}

## Primary contract lifecycle path (standard progression)
const PRIMARY_CONTRACT_LIFECYCLE := [
	ContractState.UNSIGNED,
	ContractState.SIGNED,
	ContractState.ACTIVE,
	ContractState.EXPIRED,
	ContractState.UNSIGNED  # Cycles back to unsigned for FA
]

## Primary FA period path (standard progression)
const PRIMARY_FA_PERIOD_PATH := [
	FAPeriod.CLOSED,
	FAPeriod.PREP,
	FAPeriod.TAGS_APPLIED,
	FAPeriod.MARKET_OPEN,
	FAPeriod.SIGNINGS_COMPLETE,
	FAPeriod.YEAR_ROUND
]

# ============================================================================
# CONTRACT STATE TRANSITIONS
# ============================================================================

## Check if a contract state transition is valid
##
## @param from: Current contract state
## @param to: Desired target state
## @return bool: True if transition is valid, false otherwise
static func can_transition_contract(from: ContractState, to: ContractState) -> bool:
	if not VALID_CONTRACT_TRANSITIONS.has(from):
		return false

	var valid_next: Array = VALID_CONTRACT_TRANSITIONS.get(from, [])
	return to in valid_next


## Get valid next contract states from current state
##
## @param current: Current contract state
## @return Array: Array of valid next ContractState values
static func get_valid_next_contract_states(current: ContractState) -> Array:
	if not VALID_CONTRACT_TRANSITIONS.has(current):
		return []

	return VALID_CONTRACT_TRANSITIONS.get(current, []).duplicate()


## Check if a contract state is terminal (no valid transitions out)
##
## Note: In contract lifecycle, no states are truly terminal since
## even RELEASED/EXPIRED lead back to UNSIGNED. Returns false for all states.
##
## @param state: State to check
## @return bool: True if state is terminal (no valid next states)
static func is_terminal_contract_state(state: ContractState) -> bool:
	var valid_next := get_valid_next_contract_states(state)
	return valid_next.is_empty()


## Convert ContractState enum to readable string
##
## @param state: ContractState enum value
## @return String: Human-readable state name
static func contract_state_to_string(state: ContractState) -> String:
	match state:
		ContractState.UNSIGNED:
			return "UNSIGNED"
		ContractState.SIGNED:
			return "SIGNED"
		ContractState.ACTIVE:
			return "ACTIVE"
		ContractState.EXPIRED:
			return "EXPIRED"
		ContractState.RELEASED:
			return "RELEASED"
		ContractState.FRANCHISE_TAGGED:
			return "FRANCHISE_TAGGED"
		ContractState.VOIDED:
			return "VOIDED"
		ContractState.RESTRUCTURED:
			return "RESTRUCTURED"
		_:
			return "UNKNOWN"


## Convert string to ContractState enum (for deserialization)
##
## @param state_str: State name as string
## @return ContractState: Enum value, or UNSIGNED if not recognized
static func string_to_contract_state(state_str: String) -> ContractState:
	match state_str.to_upper():
		"UNSIGNED":
			return ContractState.UNSIGNED
		"SIGNED":
			return ContractState.SIGNED
		"ACTIVE":
			return ContractState.ACTIVE
		"EXPIRED":
			return ContractState.EXPIRED
		"RELEASED":
			return ContractState.RELEASED
		"FRANCHISE_TAGGED":
			return ContractState.FRANCHISE_TAGGED
		"VOIDED":
			return ContractState.VOIDED
		"RESTRUCTURED":
			return ContractState.RESTRUCTURED
		_:
			push_warning("Unknown contract state string: %s, defaulting to UNSIGNED" % state_str)
			return ContractState.UNSIGNED


# ============================================================================
# FREE AGENCY PERIOD TRANSITIONS
# ============================================================================

## Check if a FA period transition is valid
##
## @param from: Current FA period
## @param to: Desired target period
## @return bool: True if transition is valid, false otherwise
static func can_transition_fa_period(from: FAPeriod, to: FAPeriod) -> bool:
	if not VALID_FA_PERIOD_TRANSITIONS.has(from):
		return false

	var valid_next: Array = VALID_FA_PERIOD_TRANSITIONS.get(from, [])
	return to in valid_next


## Get valid next FA periods from current period
##
## @param current: Current FA period
## @return Array: Array of valid next FAPeriod values
static func get_valid_next_fa_periods(current: FAPeriod) -> Array:
	if not VALID_FA_PERIOD_TRANSITIONS.has(current):
		return []

	return VALID_FA_PERIOD_TRANSITIONS.get(current, []).duplicate()


## Convert FAPeriod enum to readable string
##
## @param period: FAPeriod enum value
## @return String: Human-readable period name
static func fa_period_to_string(period: FAPeriod) -> String:
	match period:
		FAPeriod.CLOSED:
			return "CLOSED"
		FAPeriod.PREP:
			return "PREP"
		FAPeriod.TAGS_APPLIED:
			return "TAGS_APPLIED"
		FAPeriod.MARKET_OPEN:
			return "MARKET_OPEN"
		FAPeriod.SIGNINGS_COMPLETE:
			return "SIGNINGS_COMPLETE"
		FAPeriod.YEAR_ROUND:
			return "YEAR_ROUND"
		_:
			return "UNKNOWN"


## Convert string to FAPeriod enum (for deserialization)
##
## @param period_str: Period name as string
## @return FAPeriod: Enum value, or CLOSED if not recognized
static func string_to_fa_period(period_str: String) -> FAPeriod:
	match period_str.to_upper():
		"CLOSED":
			return FAPeriod.CLOSED
		"PREP":
			return FAPeriod.PREP
		"TAGS_APPLIED":
			return FAPeriod.TAGS_APPLIED
		"MARKET_OPEN":
			return FAPeriod.MARKET_OPEN
		"SIGNINGS_COMPLETE":
			return FAPeriod.SIGNINGS_COMPLETE
		"YEAR_ROUND":
			return FAPeriod.YEAR_ROUND
		_:
			push_warning("Unknown FA period string: %s, defaulting to CLOSED" % period_str)
			return FAPeriod.CLOSED


# ============================================================================
# VALIDATION HELPERS
# ============================================================================

## Validate that contract transition follows expected phase/trigger
##
## Checks if the transition is being performed by the expected trigger.
## Useful for catching bugs where transitions happen at wrong times.
##
## @param from_state: Source state
## @param to_state: Target state
## @param trigger: Trigger/phase attempting the transition
## @return bool: True if trigger is appropriate for this transition
static func validate_contract_transition_trigger(
	from_state: ContractState,
	to_state: ContractState,
	trigger: String
) -> bool:
	# Define expected triggers for common transitions
	var expected_triggers := {
		# Signing transitions
		"UNSIGNED->SIGNED": ["free_agency_signed", "draft_pick_signed", "extension_signed", "trade_acquisition"],
		"UNSIGNED->FRANCHISE_TAGGED": ["franchise_tag_applied"],

		# Activation transitions
		"SIGNED->ACTIVE": ["season_start", "contract_activation"],
		"FRANCHISE_TAGGED->ACTIVE": ["season_start", "tag_activation"],

		# Termination transitions
		"ACTIVE->EXPIRED": ["contract_end", "season_rollover"],
		"ACTIVE->RELEASED": ["roster_cut", "cap_casualty", "performance", "injury_settlement"],
		"SIGNED->RELEASED": ["preseason_cut", "failed_physical"],

		# Post-contract transitions
		"EXPIRED->UNSIGNED": ["free_agency_entry"],
		"RELEASED->UNSIGNED": ["free_agency_entry"],
		"EXPIRED->FRANCHISE_TAGGED": ["franchise_tag_applied"],

		# Special transitions
		"ACTIVE->RESTRUCTURED": ["cap_restructure"],
		"SIGNED->RESTRUCTURED": ["contract_restructure"],
		"RESTRUCTURED->ACTIVE": ["restructure_complete"],
	}

	var transition_key := "%s->%s" % [
		contract_state_to_string(from_state),
		contract_state_to_string(to_state)
	]

	if not expected_triggers.has(transition_key):
		# No expected triggers defined - allow any trigger
		return true

	var valid_triggers: Array = expected_triggers[transition_key]
	if trigger in valid_triggers:
		return true

	push_warning("Contract transition %s triggered by '%s' but expected one of: %s" % [
		transition_key,
		trigger,
		", ".join(valid_triggers)
	])
	return false


## Check if a contract is eligible for franchise tag
##
## Players can be franchise tagged if they are:
## - Currently UNSIGNED (pending FA)
## - Currently EXPIRED (contract just ended)
##
## @param contract_state: Current contract state
## @return bool: True if eligible for franchise tag
static func is_eligible_for_franchise_tag(contract_state: ContractState) -> bool:
	return contract_state in [ContractState.UNSIGNED, ContractState.EXPIRED]


## Check if a contract can be released (creates cap savings/dead cap)
##
## Contracts can be released if they are:
## - SIGNED (before season starts)
## - ACTIVE (during season or off-season)
## - RESTRUCTURED (after restructure)
##
## @param contract_state: Current contract state
## @return bool: True if contract can be released
static func can_release_contract(contract_state: ContractState) -> bool:
	return contract_state in [
		ContractState.SIGNED,
		ContractState.ACTIVE,
		ContractState.RESTRUCTURED
	]


## Check if a contract can be restructured (cap manipulation)
##
## Contracts can be restructured if they are:
## - SIGNED (before activation)
## - ACTIVE (during active term)
##
## @param contract_state: Current contract state
## @return bool: True if contract can be restructured
static func can_restructure_contract(contract_state: ContractState) -> bool:
	return contract_state in [ContractState.SIGNED, ContractState.ACTIVE]
