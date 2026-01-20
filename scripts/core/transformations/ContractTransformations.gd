extends RefCounted
class_name ContractTransformations

## Pure function library for contract transformations.
## All functions are side-effect-free and deterministic.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.
##
## This module provides composable contract operations:
## - Contract creation (from offers, draft picks, extensions)
## - Contract signing (applying contracts to players)
## - Contract releases (removing contracts, calculating dead cap)
## - Franchise tagging (special 1-year guaranteed contracts)
## - Cap impact calculations (for salary cap management)
##
## Integration with ContractLifecycle:
## This module wraps and extends ContractLifecycle.gd transition functions,
## adding player-level transformations and cap accounting.

const ContractLifecycle = preload("res://scripts/world/ContractLifecycle.gd")
const ContractStateMachine = preload("res://scripts/core/state/ContractStateMachine.gd")

# ============================================================================
# PURE FUNCTIONS - Contract Creation
# ============================================================================

## Create a new contract from an offer (pure function).
##
## Creates a contract dictionary from a free agency or extension offer.
## Does NOT modify the offer or player - returns a new contract dictionary.
##
## RNG consumption: NONE (deterministic contract creation)
##
## @param offer: Offer dictionary with contract terms
##   Required keys: annual_value, years_total, base_salary, signing_bonus, guaranteed_value
## @param trigger: Trigger string ("free_agency_signed", "extension_signed", etc.)
## @param year: Year the contract is signed
## @return: NEW contract dictionary (status: "unsigned")
##
## Algorithm:
##   1. Extract contract terms from offer
##   2. Create contract dictionary with UNSIGNED status
##   3. Set signed_year and trigger for audit trail
##   4. Return new contract (offer unchanged!)
##
## Example:
##   var contract := ContractTransformations.create_contract(offer, "free_agency_signed", 2024)
##   assert(offer.has("annual_value"))  # Original unchanged
##   assert(contract["status"] == "unsigned")
##   assert(contract["signed_year"] == 2024)
static func create_contract(
	offer: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Validate offer has required fields
	if not offer.has("annual_value") or not offer.has("years_total"):
		push_error("ContractTransformations.create_contract: Invalid offer (missing annual_value or years_total)")
		return {}

	# Create new contract dictionary
	return {
		"status": "unsigned",  # Will transition to "signed" separately
		"annual_value": float(offer.get("annual_value", 0.0)),
		"years_total": int(offer.get("years_total", 1)),
		"years_remaining": int(offer.get("years_total", 1)),
		"base_salary": float(offer.get("base_salary", 0.0)),
		"signing_bonus": float(offer.get("signing_bonus", 0.0)),
		"guaranteed_value": float(offer.get("guaranteed_value", 0.0)),
		"cap_hit_year_1": float(offer.get("cap_hit_year_1", offer.get("annual_value", 0.0))),
		"signed_year": year,
		"trigger": trigger
	}


## Create a franchise tag contract (pure function).
##
## Creates a special 1-year guaranteed contract for franchise-tagged players.
##
## RNG consumption: NONE (deterministic calculation)
##
## @param tag_salary: Tag salary amount (calculated from position average)
## @param tag_type: Tag type ("exclusive", "non_exclusive", "transition")
## @param year: Year the tag is applied
## @param consecutive_years: Number of consecutive years tagged (affects salary)
## @return: NEW contract dictionary (status: "unsigned", will transition to "franchise_tagged")
##
## Example:
##   var tag_contract := ContractTransformations.create_franchise_tag_contract(15.0, "exclusive", 2024, 0)
##   assert(tag_contract["years_total"] == 1)  # Always 1-year
##   assert(tag_contract["guaranteed_value"] == tag_contract["annual_value"])  # Fully guaranteed
static func create_franchise_tag_contract(
	tag_salary: float,
	tag_type: String,
	year: int,
	consecutive_years: int
) -> Dictionary:
	return {
		"status": "unsigned",  # Will transition to "franchise_tagged"
		"annual_value": tag_salary,
		"years_total": 1,  # Franchise tags are always 1-year
		"years_remaining": 1,
		"base_salary": tag_salary * 0.8,  # 80% base, 20% bonus
		"signing_bonus": tag_salary * 0.2,
		"guaranteed_value": tag_salary,  # Fully guaranteed
		"cap_hit_year_1": tag_salary,
		"signed_year": year,
		"trigger": "franchise_tag",
		"tag_type": tag_type,
		"consecutive_years": consecutive_years + 1
	}


# ============================================================================
# PURE FUNCTIONS - Contract Signing
# ============================================================================

## Apply a contract to a player (pure function).
##
## Returns a NEW player dictionary with the contract applied.
## Does NOT modify the input player or contract.
##
## RNG consumption: NONE (deterministic application)
##
## @param player: Player dictionary (unchanged)
## @param contract: Contract dictionary to apply (unchanged)
## @return: NEW player dictionary with contract attached
##
## Algorithm:
##   1. Create deep copy of player
##   2. Attach contract to player["contract"]
##   3. Return new player (originals unchanged!)
##
## Example:
##   var new_player := ContractTransformations.apply_signing(player, contract)
##   assert(not player.has("contract"))  # Original unchanged
##   assert(new_player.has("contract"))  # New copy has contract
static func apply_signing(player: Dictionary, contract: Dictionary) -> Dictionary:
	var new_player := _immutable_copy(player)
	new_player["contract"] = _immutable_copy(contract)
	return new_player


## Transition contract to signed status using ContractLifecycle (pure function).
##
## Wraps ContractLifecycle.transition_unsigned_to_signed() and returns updated contract.
##
## RNG consumption: NONE (deterministic transition)
##
## @param contract: Contract dictionary (unchanged)
## @param trigger: Trigger string for audit trail
## @param year: Year of signing
## @return: Dictionary with {contract: Dictionary, cap_impact: Dictionary}
##
## Example:
##   var result := ContractTransformations.sign_contract(contract, "free_agency_signed", 2024)
##   assert(contract["status"] == "unsigned")  # Original unchanged
##   assert(result.contract["status"] == "signed")  # New contract signed
##   assert(result.cap_impact.annual_value_delta > 0.0)  # Cap hit applied
static func sign_contract(
	contract: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Use ContractLifecycle for transition logic
	return ContractLifecycle.transition_unsigned_to_signed(contract, trigger, year)


# ============================================================================
# PURE FUNCTIONS - Contract Release
# ============================================================================

## Apply contract release to player (pure function).
##
## Returns NEW player with contract marked as released and cap impact calculated.
##
## RNG consumption: NONE (deterministic release)
##
## @param player: Player dictionary (unchanged)
## @param trigger: Release reason ("roster_cut", "cap_casualty", etc.)
## @param year: Year of release
## @return: Dictionary with {player: Dictionary, cap_impact: Dictionary}
##
## Algorithm:
##   1. Create deep copy of player
##   2. Transition contract using ContractLifecycle
##   3. Calculate cap impact (remove annual value, add dead money)
##   4. Return new player with released contract (original unchanged!)
##
## Example:
##   var result := ContractTransformations.apply_release(player, "roster_cut", 2024)
##   assert(player["contract"]["status"] == "signed")  # Original unchanged
##   assert(result.player["contract"]["status"] == "released")  # New copy released
##   assert(result.cap_impact.annual_value_delta < 0.0)  # Cap hit removed
static func apply_release(
	player: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	var new_player := _immutable_copy(player)
	var contract: Dictionary = new_player.get("contract", {})

	if contract.is_empty():
		push_error("ContractTransformations.apply_release: Player has no contract")
		return {"player": new_player, "cap_impact": {}}

	# Use ContractLifecycle for transition logic
	var transition := ContractLifecycle.transition_signed_to_released(contract, trigger, year)

	# Update player with released contract
	new_player["contract"] = transition["contract"]
	new_player["last_team_id"] = new_player.get("team_id", "")
	new_player["release_year"] = year

	return {
		"player": new_player,
		"cap_impact": transition.get("cap_impact", {}),
		"transition": transition.get("transition", "")
	}


## Transition contract to expired status using ContractLifecycle (pure function).
##
## Wraps ContractLifecycle.transition_signed_to_expired() for contract expiration.
##
## RNG consumption: NONE (deterministic transition)
##
## @param contract: Contract dictionary (unchanged)
## @param trigger: Trigger string ("contract_end", "season_rollover")
## @param year: Year of expiration
## @return: Dictionary with {contract: Dictionary, cap_impact: Dictionary}
##
## Example:
##   var result := ContractTransformations.expire_contract(contract, "contract_end", 2024)
##   assert(contract["status"] == "signed")  # Original unchanged
##   assert(result.contract["status"] == "expired")  # New contract expired
##   assert(result.cap_impact.annual_value_delta < 0.0)  # Cap hit removed
static func expire_contract(
	contract: Dictionary,
	trigger: String,
	year: int
) -> Dictionary:
	# Use ContractLifecycle for transition logic
	return ContractLifecycle.transition_signed_to_expired(contract, trigger, year)


# ============================================================================
# PURE FUNCTIONS - Cap Impact Calculations
# ============================================================================

## Calculate cap impact of a contract operation (pure function).
##
## Computes the change in team cap space from contract operations.
## Positive values = cap hit increase (less cap space available)
## Negative values = cap savings (more cap space available)
##
## RNG consumption: NONE (deterministic calculation)
##
## @param operation: Operation type ("signing", "release", "expiration", "restructure")
## @param contract: Contract dictionary
## @return: Dictionary with cap impact breakdown
##   {
##     "annual_value_delta": float,  # Change in annual cap hit
##     "dead_money_delta": float,    # Change in dead money charge
##     "net_cap_delta": float,       # Net change (positive = more cap used)
##     "operation": String           # Echo of operation type
##   }
##
## Algorithm:
##   - Signing: +annual_value (new cap hit)
##   - Release: -annual_value (remove cap hit), +dead_money (guaranteed charges)
##   - Expiration: -annual_value (remove cap hit)
##   - Restructure: Complex calculation (future enhancement)
##
## Example:
##   var impact := ContractTransformations.calculate_cap_impact("signing", contract)
##   assert(impact.annual_value_delta > 0.0)  # Signing increases cap hit
##   assert(impact.net_cap_delta > 0.0)  # Less cap space available
static func calculate_cap_impact(operation: String, contract: Dictionary) -> Dictionary:
	var annual_value := float(contract.get("annual_value", 0.0))
	var guaranteed_value := float(contract.get("guaranteed_value", 0.0))

	match operation:
		"signing":
			return {
				"annual_value_delta": annual_value,
				"dead_money_delta": 0.0,
				"net_cap_delta": annual_value,
				"operation": "signing"
			}

		"release":
			# Calculate dead cap (simplified: full guaranteed value)
			# TODO: More sophisticated dead cap calculation with proration
			var dead_cap := guaranteed_value
			return {
				"annual_value_delta": -annual_value,
				"dead_money_delta": dead_cap,
				"net_cap_delta": dead_cap - annual_value,  # Often negative (cap savings)
				"operation": "release"
			}

		"expiration":
			return {
				"annual_value_delta": -annual_value,
				"dead_money_delta": 0.0,
				"net_cap_delta": -annual_value,  # Cap space freed
				"operation": "expiration"
			}

		"restructure":
			# TODO: Implement restructure cap impact
			push_warning("ContractTransformations.calculate_cap_impact: Restructure not yet implemented")
			return {
				"annual_value_delta": 0.0,
				"dead_money_delta": 0.0,
				"net_cap_delta": 0.0,
				"operation": "restructure"
			}

		_:
			push_warning("ContractTransformations.calculate_cap_impact: Unknown operation '%s'" % operation)
			return {
				"annual_value_delta": 0.0,
				"dead_money_delta": 0.0,
				"net_cap_delta": 0.0,
				"operation": "unknown"
			}


## Calculate dead cap charge for releasing a player (pure function).
##
## Computes the dead cap (guaranteed money that still counts against cap)
## when releasing a player mid-contract.
##
## RNG consumption: NONE (deterministic calculation)
##
## @param contract: Contract dictionary
## @return: float - Dead cap charge amount
##
## Algorithm (simplified for v1):
##   - Dead cap = remaining guaranteed value
##   - TODO: Add proration logic for signing bonuses
##   - TODO: Add restructure bonus accounting
##
## Example:
##   var dead_cap := ContractTransformations.calculate_dead_cap(contract)
##   assert(dead_cap <= contract["guaranteed_value"])
static func calculate_dead_cap(contract: Dictionary) -> float:
	# Simplified calculation: full guaranteed value becomes dead cap
	# TODO: More sophisticated calculation:
	#   - Prorate signing bonus over remaining years
	#   - Account for guarantees that haven't vested yet
	#   - Handle restructure bonuses
	var guaranteed_value := float(contract.get("guaranteed_value", 0.0))
	return guaranteed_value


# ============================================================================
# PURE FUNCTIONS - Franchise Tag Operations
# ============================================================================

## Apply franchise tag to player (pure function).
##
## Returns NEW player with franchise tag contract applied.
##
## RNG consumption: NONE (deterministic application)
##
## @param player: Player dictionary (unchanged)
## @param tag_salary: Tag salary amount
## @param tag_type: Tag type ("exclusive", "non_exclusive", "transition")
## @param year: Year of tag application
## @param consecutive_years: Number of consecutive years tagged
## @return: NEW player dictionary with franchise tag contract
##
## Algorithm:
##   1. Create franchise tag contract
##   2. Apply to player (create new player copy)
##   3. Return new player (original unchanged!)
##
## Example:
##   var tagged_player := ContractTransformations.apply_franchise_tag(player, 15.0, "exclusive", 2024, 0)
##   assert(not player.has("contract"))  # Original unchanged
##   assert(tagged_player["contract"]["trigger"] == "franchise_tag")
static func apply_franchise_tag(
	player: Dictionary,
	tag_salary: float,
	tag_type: String,
	year: int,
	consecutive_years: int
) -> Dictionary:
	# Create franchise tag contract
	var tag_contract := create_franchise_tag_contract(tag_salary, tag_type, year, consecutive_years)

	# Apply to player
	return apply_signing(player, tag_contract)


## Calculate franchise tag salary for position (pure function).
##
## Calculates the franchise tag salary as the average of top 5 salaries
## at the player's position, with tag type multiplier applied.
##
## RNG consumption: NONE (deterministic calculation)
##
## @param position: Player position (e.g., "QB", "EDGE", "WR")
## @param position_salaries: Array of annual salaries for this position (sorted desc)
## @param tag_type: Tag type ("exclusive", "non_exclusive", "transition")
## @return: float - Franchise tag salary
##
## Algorithm:
##   1. Take top 5 salaries from position_salaries
##   2. Calculate average
##   3. Apply tag type multiplier (1.2x for exclusive, 1.0x otherwise)
##   4. Return tag salary
##
## Example:
##   var qb_salaries := [45.0, 40.0, 38.0, 35.0, 32.0, 30.0]
##   var tag_salary := ContractTransformations.calculate_franchise_tag_salary("QB", qb_salaries, "exclusive")
##   assert(tag_salary == (45 + 40 + 38 + 35 + 32) / 5 * 1.2)  # Top 5 average * 1.2
static func calculate_franchise_tag_salary(
	position: String,
	position_salaries: Array,
	tag_type: String
) -> float:
	if position_salaries.is_empty():
		push_warning("ContractTransformations.calculate_franchise_tag_salary: No salaries for position %s, using default" % position)
		return 10.0  # Default minimum tag salary

	# Get top 5 salaries
	var sorted_salaries := position_salaries.duplicate()
	sorted_salaries.sort()
	sorted_salaries.reverse()

	var top_5_count := mini(5, sorted_salaries.size())
	var sum := 0.0
	for i in range(top_5_count):
		sum += float(sorted_salaries[i])

	var average := sum / float(top_5_count)

	# Apply tag type multiplier
	match tag_type:
		"exclusive":
			return average * 1.2  # 120% for exclusive tag
		"non_exclusive":
			return average * 1.0  # 100% for non-exclusive
		"transition":
			return average * 1.0  # 100% for transition tag
		_:
			push_warning("ContractTransformations.calculate_franchise_tag_salary: Unknown tag type '%s'" % tag_type)
			return average


# ============================================================================
# PURE FUNCTIONS - Contract Queries
# ============================================================================

## Check if player has an active contract (pure function).
##
## @param player: Player dictionary
## @return: bool - True if player has contract in active/signed/tagged status
static func has_active_contract(player: Dictionary) -> bool:
	var contract: Dictionary = player.get("contract", {})
	if contract.is_empty():
		return false

	var status := String(contract.get("status", ""))
	return status in ["signed", "active", "franchise_tagged"]


## Get years remaining on contract (pure function).
##
## @param contract: Contract dictionary
## @return: int - Years remaining, or 0 if no contract
static func get_years_remaining(contract: Dictionary) -> int:
	return int(contract.get("years_remaining", 0))


## Check if contract is expiring (pure function).
##
## @param contract: Contract dictionary
## @return: bool - True if contract has 1 or 0 years remaining
static func is_contract_expiring(contract: Dictionary) -> bool:
	return get_years_remaining(contract) <= 1


## Get contract annual value (pure function).
##
## @param contract: Contract dictionary
## @return: float - Annual value (cap hit per year)
static func get_annual_value(contract: Dictionary) -> float:
	return float(contract.get("annual_value", 0.0))


# ============================================================================
# IMMUTABILITY HELPERS - Pure Function Utilities
# ============================================================================

## Create a deep immutable copy of a dictionary.
##
## This prevents accidental mutation of input by creating a completely
## independent copy of all nested structures.
##
## Uses GDScript's duplicate(true) which performs recursive deep copy
## of all nested dictionaries and arrays.
##
## @param dict: Dictionary to copy
## @return: NEW dictionary (completely independent)
static func _immutable_copy(dict: Dictionary) -> Dictionary:
	# Deep copy entire structure (recursive)
	return dict.duplicate(true)
