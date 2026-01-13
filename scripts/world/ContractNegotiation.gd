## Contract Negotiation Module
##
## Purpose: Generate realistic contract offers and evaluate player demands for free agency.
##
## Architecture: All functions are pure and deterministic - no RNG is used. Contract
## valuations are based on PlayerValue calculations with age curves, position markets,
## and performance tiers applied algorithmically.
##
## Integration:
## - Uses PlayerValue.calculate() for market value baseline
## - Integrates with FreeAgency for offer generation
## - Follows ContractLifecycle patterns for contract structure
##
## Determinism: All calculations are deterministic. No RNG calls.
extends RefCounted
class_name ContractNegotiation

const PlayerValue = preload("res://scripts/core/valuation/PlayerValue.gd")


## Calculate what a player expects to be paid in free agency.
##
## This function determines a player's financial expectations based on their
## market value, age, position, and performance tier. The demand represents
## the minimum acceptable contract the player will sign.
##
## Algorithm:
## 1. Calculate base market value using PlayerValue.calculate()
## 2. Apply age curve modifier (peak ages get full value, young/old discounted)
## 3. Apply position market multiplier (QB premium, RB discount, etc.)
## 4. Apply performance tier multiplier (elite get premium, depth discounted)
## 5. Calculate desired contract structure (years, guarantees)
##
## @param player: Player dictionary with required keys:
##   - id: Unique player identifier
##   - position: Position code (e.g., "QB", "WR")
##   - age: Player age in years
##   - eval_score: Evaluation score (0-100 scale)
##   - Any additional keys required by PlayerValue.calculate()
##
## @param positions_cfg: Positions configuration (from positions.json)
##
## @param main_cfg: Main configuration (from main.json)
##
## @return: Dictionary with demand structure:
##   {
##     "minimum_annual_value": float,  # Minimum AAV player will accept (millions)
##     "desired_years": int,            # Preferred contract length
##     "guaranteed_demand": float       # Minimum guaranteed money (millions)
##   }
static func generate_player_demand(
	player: Dictionary,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var position := String(player.get("position", "ATH"))
	var age := int(player.get("age", 22))
	var eval_score := float(player.get("eval_score", 50.0))

	# 1. Calculate base market value
	# Note: PlayerValue requires context and config; we'll use minimal context
	# for free agent valuation (no team roster context yet)
	var valuation_context := {}
	var valuation_cfg := _build_valuation_config(positions_cfg, main_cfg)
	var rng := RandomNumberGenerator.new()  # Not used by PlayerValue.calculate()

	var valuation := PlayerValue.calculate(player, valuation_context, valuation_cfg, rng)
	var base_value := float(valuation.get("market_value", 1.0))

	# 2. Apply age curve modifier
	# Peak ages (25-28) get full value, younger/older get discounts
	var age_modifier := _calculate_age_modifier(age, position, positions_cfg)

	# 3. Apply position market multiplier
	# Some positions command premium salaries in free agency
	var position_multiplier := _get_position_market_multiplier(position)

	# 4. Apply performance tier multiplier
	# Elite players get premiums, depth players get discounts
	var tier_multiplier := _get_performance_tier_multiplier(eval_score)

	# Calculate final minimum annual value
	var minimum_annual_value := base_value * age_modifier * position_multiplier * tier_multiplier

	# Ensure reasonable floor (even camp bodies need minimum wage)
	minimum_annual_value = max(minimum_annual_value, 0.5)

	# 5. Calculate desired contract structure
	var desired_years := _calculate_desired_years(age, eval_score, position, positions_cfg)
	var guaranteed_pct := _calculate_guaranteed_percentage(eval_score, position)
	var guaranteed_demand := minimum_annual_value * desired_years * guaranteed_pct

	return {
		"minimum_annual_value": minimum_annual_value,
		"desired_years": desired_years,
		"guaranteed_demand": guaranteed_demand
	}


## Generate a contract offer from a team to a player.
##
## Creates a realistic contract offer based on the player's demands, team
## circumstances (cap space, needs), and team aggression level. The offer
## may exceed or fall short of player demands based on these factors.
##
## Algorithm:
## 1. Calculate base offer using demand * aggression
## 2. Apply team circumstance modifiers (cap space, need urgency)
## 3. Calculate contract structure (base salary, signing bonus, years)
## 4. Validate cap compliance
## 5. Return structured offer
##
## @param team: Team dictionary with keys:
##   - id: Team identifier
##   - cap_space: Available cap space (millions)
##   - Additional context for aggression calculation
##
## @param player: Player dictionary (see generate_player_demand)
##
## @param demand: Demand dictionary from generate_player_demand()
##
## @param aggression: Team aggression factor (0.8-1.3 typical range)
##   - 1.0 = neutral (meet demand exactly)
##   - >1.0 = aggressive (exceed demand to secure player)
##   - <1.0 = conservative (below-market offer)
##
## @return: Contract offer dictionary:
##   {
##     "team_id": String,
##     "player_id": String,
##     "base_salary": float,         # Annual base salary (millions)
##     "signing_bonus": float,       # Upfront signing bonus (millions)
##     "years_total": int,            # Contract length
##     "guaranteed_value": float,    # Total guaranteed money (millions)
##     "annual_value": float,         # Average annual value (millions)
##     "cap_hit_year_1": float,       # Year 1 cap impact (millions)
##     "offer_quality": float         # % of demand met (0.0-2.0+)
##   }
##   Returns empty dict if team cannot afford offer
static func generate_offer(
	team: Dictionary,
	player: Dictionary,
	demand: Dictionary,
	aggression: float
) -> Dictionary:
	var team_id := String(team.get("id", ""))
	var player_id := String(player.get("id", ""))
	var cap_space := float(team.get("cap_space", 0.0))

	var minimum_aav := float(demand.get("minimum_annual_value", 1.0))
	var desired_years := int(demand.get("desired_years", 3))
	var guaranteed_demand := float(demand.get("guaranteed_demand", 0.0))

	# 1. Calculate base offer value
	var offer_aav := minimum_aav * aggression

	# 2. Calculate contract structure
	# Typical NFL contracts are 70% base salary, 30% signing bonus
	var base_salary := offer_aav * 0.7
	var signing_bonus := offer_aav * 0.3

	# Years: match player desire or adjust for team strategy
	var years_total := desired_years
	years_total = clampi(years_total, 1, 5)  # NFL contracts typically 1-5 years

	# Guaranteed money: typically 40-60% of total value for free agents
	# Elite players get higher guarantee percentages
	var eval_score := float(player.get("eval_score", 50.0))
	var guarantee_pct := 0.5
	if eval_score >= 80.0:
		guarantee_pct = 0.6  # Elite players get 60% guaranteed
	elif eval_score >= 70.0:
		guarantee_pct = 0.5  # Starters get 50% guaranteed
	else:
		guarantee_pct = 0.4  # Depth players get 40% guaranteed

	var guaranteed_value := offer_aav * years_total * guarantee_pct

	# 3. Calculate cap impact
	# Year 1 cap hit = base salary + (signing bonus / years)
	var cap_hit_year_1 := base_salary + (signing_bonus / years_total)

	# 4. Validate cap compliance
	if cap_hit_year_1 > cap_space:
		# Team cannot afford this offer
		return {}

	# 5. Calculate offer quality (how well it meets player demands)
	var offer_quality := offer_aav / minimum_aav

	return {
		"team_id": team_id,
		"player_id": player_id,
		"base_salary": base_salary,
		"signing_bonus": signing_bonus,
		"years_total": years_total,
		"guaranteed_value": guaranteed_value,
		"annual_value": offer_aav,
		"cap_hit_year_1": cap_hit_year_1,
		"offer_quality": offer_quality
	}


## Evaluate whether an offer meets player expectations.
##
## Determines if a player will accept an offer based on how well it meets
## their financial demands. Considers annual value, guaranteed money, and
## contract length.
##
## Algorithm:
## 1. Calculate annual value ratio (offer AAV / demand AAV)
## 2. Calculate guaranteed money ratio (offer guaranteed / demand guaranteed)
## 3. Check years match (within 1 year tolerance)
## 4. Calculate acceptance score (weighted average)
## 5. Accept if score >= 0.85 (85% threshold)
##
## @param offer: Contract offer dictionary from generate_offer()
##
## @param demand: Player demand dictionary from generate_player_demand()
##
## @return: Evaluation dictionary:
##   {
##     "accept": bool,           # Whether player accepts offer
##     "score": float,           # Acceptance score (0.0-2.0+)
##     "reason": String          # "accepted", "insufficient_value", "low_guarantees"
##   }
static func evaluate_offer(
	offer: Dictionary,
	demand: Dictionary
) -> Dictionary:
	# Check if offer is valid
	if offer.is_empty():
		return {
			"accept": false,
			"score": 0.0,
			"reason": "no_offer"
		}

	var offer_aav := float(offer.get("annual_value", 0.0))
	var offer_guaranteed := float(offer.get("guaranteed_value", 0.0))
	var offer_years := int(offer.get("years_total", 0))

	var demand_aav := float(demand.get("minimum_annual_value", 1.0))
	var demand_guaranteed := float(demand.get("guaranteed_demand", 0.0))
	var demand_years := int(demand.get("desired_years", 3))

	# 1. Calculate annual value ratio
	var aav_ratio := offer_aav / demand_aav if demand_aav > 0.0 else 0.0

	# 2. Calculate guaranteed ratio
	var guaranteed_ratio := offer_guaranteed / demand_guaranteed if demand_guaranteed > 0.0 else 1.0

	# 3. Check years match (tolerance of +/- 1 year)
	var years_match: bool = abs(offer_years - demand_years) <= 1
	var years_penalty := 0.0 if years_match else -0.1

	# 4. Calculate acceptance score
	# Weight: 70% AAV, 30% guarantees, with years penalty
	var base_score := (aav_ratio * 0.7) + (guaranteed_ratio * 0.3)
	var final_score := base_score + years_penalty

	# 5. Determine acceptance
	var acceptance_threshold := 0.85  # 85% of demands must be met
	var accept := final_score >= acceptance_threshold

	var reason := ""
	if accept:
		reason = "accepted"
	elif aav_ratio < 0.85:
		reason = "insufficient_value"
	elif guaranteed_ratio < 0.85:
		reason = "low_guarantees"
	elif not years_match:
		reason = "years_mismatch"
	else:
		reason = "overall_insufficient"

	return {
		"accept": accept,
		"score": final_score,
		"reason": reason
	}


## INTERNAL: Calculate age-based modifier for contract value.
##
## Players at peak age command full market value. Younger players get discounts
## due to inexperience, older players get discounts due to declining careers.
##
## @param age: Player age
## @param position: Player position
## @param positions_cfg: Positions configuration
## @return: Age modifier (0.7-1.0)
static func _calculate_age_modifier(age: int, position: String, positions_cfg: Dictionary) -> float:
	# Get position-specific peak age from config
	var pos_config := positions_cfg.get(position, {}) as Dictionary
	var development := pos_config.get("development", {}) as Dictionary
	var peak_age := int(development.get("peak_age", 26))
	var decline_start := int(development.get("decline_start", 30))

	# Peak window (typically 3-4 years)
	if age >= peak_age and age < decline_start:
		return 1.0  # Full value during peak

	# Young players (pre-peak)
	if age < peak_age:
		var years_before_peak := peak_age - age
		if years_before_peak <= 2:
			return 0.95  # 1-2 years before peak: minor discount
		else:
			return 0.85  # 3+ years before peak: upside discount

	# Declining players (post-peak)
	var years_past_peak := age - decline_start
	if years_past_peak <= 2:
		return 0.85  # Early decline: moderate discount
	elif years_past_peak <= 4:
		return 0.75  # Mid decline: significant discount
	else:
		return 0.65  # Late career: major discount


## INTERNAL: Get position market multiplier.
##
## Some positions command premium salaries due to scarcity and importance.
## Based on real NFL free agency market trends.
##
## @param position: Player position
## @return: Position market multiplier (0.7-1.5)
static func _get_position_market_multiplier(position: String) -> float:
	# Premium positions (high demand, scarce talent)
	if position == "QB":
		return 1.5  # QBs command highest premiums
	if position in ["EDGE", "CB"]:
		return 1.2  # Pass rushers and corners get premiums
	if position in ["OL", "DL"]:
		return 1.1  # Trenches get slight premiums

	# Standard positions
	if position in ["WR", "LB", "TE"]:
		return 1.0  # Market rate

	# Devalued positions (abundant talent, short careers)
	if position == "RB":
		return 0.8  # RBs devalued in modern NFL
	if position == "S":
		return 0.85  # Safeties less valued than corners

	# Special teams
	if position in ["K", "P"]:
		return 0.7  # Specialists get minimum contracts

	return 1.0  # Default


## INTERNAL: Get performance tier multiplier.
##
## Elite players command premiums, depth players accept discounts.
##
## @param eval_score: Player evaluation score (0-100)
## @return: Performance tier multiplier (0.4-1.3)
static func _get_performance_tier_multiplier(eval_score: float) -> float:
	if eval_score >= 85.0:
		return 1.3  # Elite (All-Pro level): 30% premium
	elif eval_score >= 80.0:
		return 1.2  # Star (Pro Bowl level): 20% premium
	elif eval_score >= 70.0:
		return 1.0  # Starter: Market rate
	elif eval_score >= 60.0:
		return 0.7  # Depth: 30% discount
	else:
		return 0.4  # Camp body: 60% discount (league minimum)


## INTERNAL: Calculate desired contract length.
##
## Younger players want longer deals for security, older players want shorter
## deals to preserve flexibility. Elite players want longer deals to maximize
## guaranteed money.
##
## @param age: Player age
## @param eval_score: Player evaluation score
## @param position: Player position
## @param positions_cfg: Positions configuration
## @return: Desired years (1-5)
static func _calculate_desired_years(
	age: int,
	eval_score: float,
	position: String,
	positions_cfg: Dictionary
) -> int:
	var pos_config := positions_cfg.get(position, {}) as Dictionary
	var development := pos_config.get("development", {}) as Dictionary
	var decline_start := int(development.get("decline_start", 30))

	# Elite players want longer deals for max guaranteed money
	if eval_score >= 80.0:
		if age < decline_start:
			return 5  # Elite in prime: max length deal
		else:
			return 3  # Elite declining: shorter deal

	# Starters balance security and flexibility
	if eval_score >= 70.0:
		if age < 26:
			return 4  # Young starters: prove-it extension
		elif age < decline_start:
			return 4  # Peak starters: long-term security
		else:
			return 2  # Declining starters: short deal

	# Depth players take what they can get
	if age < 26:
		return 3  # Young depth: development deal
	else:
		return 2  # Older depth: short deal


## INTERNAL: Calculate guaranteed money percentage.
##
## Elite players can demand higher guarantee percentages. Depth players
## accept lower guarantees.
##
## @param eval_score: Player evaluation score
## @param position: Player position
## @return: Guaranteed percentage (0.3-0.65)
static func _calculate_guaranteed_percentage(eval_score: float, position: String) -> float:
	# Base guarantee percentage by tier
	var base_pct := 0.5
	if eval_score >= 85.0:
		base_pct = 0.65  # Elite: 65% guaranteed
	elif eval_score >= 80.0:
		base_pct = 0.6   # Star: 60% guaranteed
	elif eval_score >= 70.0:
		base_pct = 0.5   # Starter: 50% guaranteed
	elif eval_score >= 60.0:
		base_pct = 0.4   # Depth: 40% guaranteed
	else:
		base_pct = 0.3   # Camp body: 30% guaranteed

	# Position adjustments
	# QBs get higher guarantees due to importance
	if position == "QB":
		base_pct += 0.05
	# RBs get lower guarantees due to injury risk
	elif position == "RB":
		base_pct -= 0.05

	return clampf(base_pct, 0.3, 0.7)


## INTERNAL: Build minimal valuation config for PlayerValue.calculate()
##
## Creates a temporary valuation config from positions and main config.
## This is needed because PlayerValue requires full valuation.json structure.
##
## @param positions_cfg: Positions configuration
## @param main_cfg: Main configuration
## @return: Valuation config dictionary
static func _build_valuation_config(positions_cfg: Dictionary, main_cfg: Dictionary) -> Dictionary:
	# Build minimal valuation config structure
	# In production, this should come from valuation.json
	# For now, we construct minimal required structure

	return {
		"value_curve": {
			"tiers": [
				{"max_vor": 10.0, "slope": 0.5},
				{"max_vor": 30.0, "slope": 1.0},
				{"max_vor": 50.0, "slope": 2.0},
				{"max_vor": 999.0, "slope": 3.0}
			],
			"elite_threshold": 70.0,
			"elite_multiplier_boost": 1.3
		},
		"replacement_levels": {
			"QB": 50.0, "RB": 45.0, "WR": 48.0, "TE": 47.0,
			"OL": 50.0, "DL": 48.0, "EDGE": 50.0, "LB": 47.0,
			"CB": 50.0, "S": 46.0, "K": 40.0, "P": 40.0
		},
		"scarcity": {
			"scarcity_min": 0.7,
			"scarcity_max": 1.5,
			"starter_slots": {
				"QB": 32, "RB": 64, "WR": 96, "TE": 64,
				"OL": 160, "DL": 96, "EDGE": 64, "LB": 96,
				"CB": 96, "S": 64, "K": 32, "P": 32
			}
		},
		"team_impact": {
			"no_backup_multiplier": 1.5,
			"thin_depth_multiplier": 1.2,
			"position_win_impacts": {
				"QB": 2.0, "EDGE": 1.5, "CB": 1.4, "OL": 1.3,
				"WR": 1.2, "DL": 1.2, "LB": 1.1, "TE": 1.0,
				"S": 1.0, "RB": 0.9, "K": 0.5, "P": 0.5
			}
		},
		"market": {
			"range_spread_pct": 0.18
		},
		"age_multipliers": [
			{"age": 22, "mult": 0.9},
			{"age": 25, "mult": 1.0},
			{"age": 28, "mult": 1.0},
			{"age": 30, "mult": 0.95},
			{"age": 32, "mult": 0.85},
			{"age": 35, "mult": 0.7}
		]
	}
