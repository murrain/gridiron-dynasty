## RookieWageScale - Stateless service for NFL rookie contract calculations
##
## ARCHITECTURAL PATTERN: Stateless RefCounted Service
##
## This service provides deterministic calculations for rookie contracts based
## on draft position. It follows the NFL's slotted rookie wage scale where:
## - Pick 1 gets the highest contract value
## - Each subsequent pick gets progressively less
## - First-round picks get a 5th year team option (round determined by picks_per_round)
## - UDFAs get minimum contracts with no bonus or options
##
## Contract Types:
## - "drafted_rookie": 4 years, signing bonus, 5th year option (if 1st round), guarantees
## - "udfa_rookie": 3 years, no bonus, no option, no guarantees
##
## Key Formulas:
## - Slot value uses exponential decay: cap_limit * max_pct * (decay_rate ^ (pick - 1))
## - Signing bonus is 60% of total value for drafted players
## - 5th year option estimated at 30% of slot value (150-200% of year 4 salary)
##
## RNG Usage: None - all calculations are fully deterministic
##
## Usage:
##   var contract = RookieWageScale.get_contract_for_pick(1, 200.0)
##   var udfa_contract = RookieWageScale.create_udfa_contract(2035, 200.0)
##
extends RefCounted
class_name RookieWageScale

# Wage scale constants - these define the shape of the rookie pay curve
const MAX_SALARY_PCT := 0.05        # Pick 1 = 5% of cap (e.g., $10M on $200M cap)
const MIN_SALARY_PCT := 0.002       # Pick 262 = 0.2% of cap (e.g., $400K on $200M cap)
const DECAY_RATE := 0.97            # Each pick is 3% less valuable than previous
const SIGNING_BONUS_PCT := 0.60     # 60% of total value as signing bonus
const FIFTH_YEAR_OPTION_PCT := 0.30 # 5th year option ~30% of slot value
const UDFA_SALARY_PCT := 0.001      # UDFA = 0.1% of cap (~$200K on $200M cap)

const DRAFTED_ROOKIE_YEARS := 4
const UDFA_ROOKIE_YEARS := 3


## Get the full contract details for a specific draft pick
##
## @param pick_number: Overall pick number (1-262)
## @param cap_limit: Salary cap in millions (e.g., 200.0 for $200M)
## @param year: The year the contract is signed (optional, defaults to 2035)
## @param picks_per_round: Number of picks per round (default 32)
## @return: Contract dictionary with all details
static func get_contract_for_pick(
	pick_number: int,
	cap_limit: float,
	year: int = 2035,
	picks_per_round: int = 32
) -> Dictionary:
	if pick_number < 1:
		push_error("RookieWageScale: Invalid pick number %d" % pick_number)
		return {}

	# Calculate which round this pick is in
	var round := ((pick_number - 1) / picks_per_round) + 1

	var slot_value := get_slot_value(pick_number, cap_limit)
	var years := DRAFTED_ROOKIE_YEARS
	var signing_bonus := slot_value * SIGNING_BONUS_PCT
	var base_salary_per_year := (slot_value - signing_bonus) / float(years)
	var bonus_per_year := signing_bonus / float(years)
	var annual_cap_hit := base_salary_per_year + bonus_per_year

	# First round picks (round 1) get a 5th year team option
	var has_fifth_year_option := round == 1
	var fifth_year_value := _estimate_fifth_year_value(slot_value) if has_fifth_year_option else 0.0

	# Calculate guaranteed money (signing bonus + portion of base salary)
	# Earlier picks get more guaranteed base salary
	var gtd_base_pct := _get_guaranteed_base_pct(pick_number, picks_per_round)
	var gtd_remaining := signing_bonus + (base_salary_per_year * years * gtd_base_pct)

	return {
		# Contract identification
		"type": "drafted_rookie",
		"pick_number": pick_number,
		"round": _pick_to_round(pick_number, picks_per_round),
		"signed_year": year,

		# Value breakdown
		"total_value": slot_value,
		"signing_bonus": signing_bonus,
		"base_salary_per_year": base_salary_per_year,
		"annual_cap_hit": annual_cap_hit,

		# Contract structure
		"years_total": years,
		"years_remaining": years,

		# 5th year option (first round only)
		"fifth_year_option": has_fifth_year_option,
		"fifth_year_value": fifth_year_value,

		# Guarantees
		"gtd_remaining": gtd_remaining,

		# Year-by-year breakdown
		"year_breakdown": _build_year_breakdown(
			years, base_salary_per_year, signing_bonus, cap_limit
		)
	}


## Get the slot value for a specific pick
##
## Uses exponential decay: slot_value = cap * max_pct * (decay ^ (pick - 1))
## Clamped between max_pct and min_pct of cap.
##
## @param pick_number: Overall pick number (1-262)
## @param cap_limit: Salary cap in millions
## @return: Slot value in millions
static func get_slot_value(pick_number: int, cap_limit: float) -> float:
	if pick_number < 1:
		return 0.0

	var decay := pow(DECAY_RATE, float(pick_number - 1))
	var pct: float = clamp(MAX_SALARY_PCT * decay, MIN_SALARY_PCT, MAX_SALARY_PCT)
	return cap_limit * pct


## Estimate the 5th year option value
##
## The 5th year option is typically 150-200% of the 4th year salary.
## We estimate it at ~30% of the total slot value.
##
## @param slot_value: The total 4-year slot value
## @return: Estimated 5th year option value
static func _estimate_fifth_year_value(slot_value: float) -> float:
	return slot_value * FIFTH_YEAR_OPTION_PCT


## Create a UDFA (undrafted free agent) contract
##
## UDFA contracts are minimum-salary deals with:
## - 3 years (not 4)
## - No signing bonus
## - No 5th year option
## - No guaranteed money
##
## @param year: Contract year
## @param cap_limit: Salary cap in millions
## @return: UDFA contract dictionary
static func create_udfa_contract(year: int, cap_limit: float) -> Dictionary:
	var base_salary := cap_limit * UDFA_SALARY_PCT

	return {
		"type": "udfa_rookie",
		"years_total": UDFA_ROOKIE_YEARS,
		"years_remaining": UDFA_ROOKIE_YEARS,
		"base_salary": base_salary,
		"signing_bonus": 0.0,
		"annual_value": base_salary,
		"fifth_year_option": false,
		"gtd_remaining": 0.0,
		"signed_year": year
	}


## Compare two draft picks in terms of cost
##
## Useful for trade value calculations and decision making.
##
## @param pick_a: First pick number
## @param pick_b: Second pick number
## @param cap_limit: Salary cap in millions
## @param picks_per_round: Number of picks per round (default 32)
## @return: Comparison dictionary with savings information
static func compare_picks(pick_a: int, pick_b: int, cap_limit: float, picks_per_round: int = 32) -> Dictionary:
	var contract_a := get_contract_for_pick(pick_a, cap_limit, 2035, picks_per_round)
	var contract_b := get_contract_for_pick(pick_b, cap_limit, 2035, picks_per_round)

	if contract_a.is_empty() or contract_b.is_empty():
		return {"error": "Invalid pick numbers"}

	var savings_total := float(contract_a.get("total_value", 0)) - float(contract_b.get("total_value", 0))
	var savings_per_year := float(contract_a.get("annual_cap_hit", 0)) - float(contract_b.get("annual_cap_hit", 0))

	var comparison_text := ""
	if savings_total > 0:
		comparison_text = "Pick %d costs $%.2fM MORE than Pick %d ($%.2fM/yr)" % [
			pick_a, savings_total, pick_b, savings_per_year
		]
	elif savings_total < 0:
		comparison_text = "Pick %d costs $%.2fM LESS than Pick %d ($%.2fM/yr)" % [
			pick_a, abs(savings_total), pick_b, abs(savings_per_year)
		]
	else:
		comparison_text = "Pick %d and Pick %d have the same cost" % [pick_a, pick_b]

	return {
		"pick_a": pick_a,
		"pick_b": pick_b,
		"contract_a": contract_a,
		"contract_b": contract_b,
		"savings_total": savings_total,
		"savings_per_year": savings_per_year,
		"comparison_text": comparison_text
	}


## Export the full wage scale to CSV format
##
## Useful for analysis and verification.
##
## @param cap_limit: Salary cap in millions
## @param max_picks: Number of picks to export (default 262 for full draft)
## @param picks_per_round: Number of picks per round (default 32)
## @return: CSV string with all pick contracts
static func export_to_csv(cap_limit: float, max_picks: int = 262, picks_per_round: int = 32) -> String:
	var lines := PackedStringArray()
	lines.append("Pick,Round,Total Value ($M),Annual Cap Hit ($M),Signing Bonus ($M),Base Salary/Yr ($M),5th Year Option,5th Year Value ($M)")

	for pick in range(1, max_picks + 1):
		var contract := get_contract_for_pick(pick, cap_limit, 2035, picks_per_round)
		var fifth_year_str := "Yes" if contract.get("fifth_year_option", false) else "No"
		var fifth_year_val := float(contract.get("fifth_year_value", 0))

		lines.append("%d,%d,%.3f,%.3f,%.3f,%.3f,%s,%.3f" % [
			pick,
			contract.get("round", 0),
			contract.get("total_value", 0),
			contract.get("annual_cap_hit", 0),
			contract.get("signing_bonus", 0),
			contract.get("base_salary_per_year", 0),
			fifth_year_str,
			fifth_year_val
		])

	return "\n".join(lines)


## Get all contracts for a specific round
##
## @param round_number: Round number (1-7)
## @param cap_limit: Salary cap in millions
## @param picks_per_round: Number of picks per round (default 32)
## @return: Array of contract dictionaries for the round
static func get_round_contracts(
	round_number: int,
	cap_limit: float,
	picks_per_round: int = 32
) -> Array:
	if round_number < 1 or round_number > 7:
		return []

	var contracts: Array = []
	var start_pick := (round_number - 1) * picks_per_round + 1
	var end_pick := round_number * picks_per_round

	for pick in range(start_pick, end_pick + 1):
		contracts.append(get_contract_for_pick(pick, cap_limit, 2035, picks_per_round))

	return contracts


## Get summary statistics for the wage scale
##
## @param cap_limit: Salary cap in millions
## @param picks_per_round: Number of picks per round (default 32)
## @return: Dictionary with summary stats
static func get_wage_scale_summary(cap_limit: float, picks_per_round: int = 32) -> Dictionary:
	var pick_1 := get_contract_for_pick(1, cap_limit, 2035, picks_per_round)
	var pick_last_round_1 := get_contract_for_pick(picks_per_round, cap_limit, 2035, picks_per_round)
	var pick_last_round_2 := get_contract_for_pick(picks_per_round * 2, cap_limit, 2035, picks_per_round)
	var pick_224 := get_contract_for_pick(224, cap_limit, 2035, picks_per_round)

	var total_round_1 := 0.0
	for pick in range(1, picks_per_round + 1):
		total_round_1 += get_slot_value(pick, cap_limit)

	return {
		"cap_limit": cap_limit,
		"pick_1_value": pick_1.get("total_value", 0),
		"pick_last_round_1_value": pick_last_round_1.get("total_value", 0),
		"pick_last_round_2_value": pick_last_round_2.get("total_value", 0),
		"pick_224_value": pick_224.get("total_value", 0),
		"round_1_total": total_round_1,
		"udfa_value": cap_limit * UDFA_SALARY_PCT * UDFA_ROOKIE_YEARS
	}


## Convert drafted rookie contract to the format used by InteractiveDraft
##
## This provides backward compatibility with existing contract storage format.
##
## @param pick_number: Overall pick number
## @param cap_limit: Salary cap in millions
## @param year: Contract year
## @param picks_per_round: Number of picks per round (default 32)
## @return: Contract in legacy format
static func to_legacy_contract_format(
	pick_number: int,
	cap_limit: float,
	year: int,
	picks_per_round: int = 32
) -> Dictionary:
	var contract := get_contract_for_pick(pick_number, cap_limit, year, picks_per_round)
	if contract.is_empty():
		return {}

	return {
		"type": "rookie",
		"years_total": contract.get("years_total", 4),
		"years_remaining": contract.get("years_remaining", 4),
		"base_salary": float(contract.get("base_salary_per_year", 0)) * 4,
		"signing_bonus": contract.get("signing_bonus", 0),
		"annual_value": contract.get("annual_cap_hit", 0),
		"fifth_year_option": contract.get("fifth_year_option", false),
		"gtd_remaining": contract.get("gtd_remaining", 0),
		"signed_year": year
	}


# =============================================================================
# PRIVATE HELPER METHODS
# =============================================================================

## Convert pick number to round number
static func _pick_to_round(pick_number: int, picks_per_round: int = 32) -> int:
	if pick_number < 1:
		return 0
	return ((pick_number - 1) / picks_per_round) + 1


## Get the guaranteed base salary percentage based on pick position
##
## Earlier picks get more guaranteed base salary.
static func _get_guaranteed_base_pct(pick_number: int, picks_per_round: int = 32) -> float:
	var round := ((pick_number - 1) / picks_per_round) + 1

	if pick_number <= 10:
		return 0.50  # Top 10 picks: 50% of base guaranteed
	elif round == 1:
		return 0.35  # Rest of round 1: 35% guaranteed
	elif round == 2:
		return 0.20  # Round 2: 20% guaranteed
	elif round == 3:
		return 0.10  # Round 3: 10% guaranteed
	else:
		return 0.0   # Rounds 4-7: No base salary guaranteed


## Build year-by-year breakdown of the contract
static func _build_year_breakdown(
	years: int,
	base_salary_per_year: float,
	signing_bonus: float,
	_cap_limit: float
) -> Array:
	var breakdown: Array = []
	var bonus_per_year := signing_bonus / float(years)

	for year in range(1, years + 1):
		breakdown.append({
			"year": year,
			"base_salary": base_salary_per_year,
			"bonus_proration": bonus_per_year,
			"cap_hit": base_salary_per_year + bonus_per_year
		})

	return breakdown
