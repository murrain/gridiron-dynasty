## EconomicOpportunityCostModifier - Adjusts evaluation based on FA market economics
##
## Models real NFL draft strategy by considering:
## 1. FA Market Cost: What would this talent cost in free agency?
## 2. FA Market Availability: How many quality FAs at this position?
## 3. Positional Impact Curves: How much does OVR matter at each position?
##
## Economic Logic:
## - Expensive + Scarce + High Impact = DRAFT IT (QB, EDGE, OT)
## - Cheap + Available + Lower Impact = SIGN IN FA (RB, G, LB)
##
## Example strategy this enables:
## - Team needs RB (68 OVR) and EDGE (68 OVR) equally
## - 68 OVR RB in FA = decent, cheap (~$2M/year)
## - 68 OVR EDGE in FA = liability, expensive for quality (~$12M/year)
## - Decision: Draft high-upside EDGE, sign RB in FA
##
## This modifier ADJUSTS the team need bonus based on opportunity cost.
## It does NOT replace need - it modulates how need translates to draft priority.
##
## RNG Usage: None (deterministic calculation based on position economics)
##
## Priority: 26 (runs immediately after TeamNeedModifierV2 at 25)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"

## Path to draft evaluation config file
const DRAFT_EVALUATION_CONFIG_PATH := "res://configs/sports/american_football/draft_evaluation.json"

## Cached config for performance (loaded once)
static var _config_cache: Dictionary = {}
static var _config_loaded: bool = false

## FA Market Cost (annual salary in millions for a 70 OVR player)
## Higher = more expensive to acquire quality in free agency
## Source: Modeled after NFL FA market dynamics
const FA_MARKET_COST := {
	"QB": 15.0,    # Extremely expensive - even mediocre QBs get paid
	"EDGE": 12.0,  # Very expensive - premier pass rushers command top dollar
	"OT": 10.0,    # Expensive - blind side protection is critical
	"CB": 8.0,     # Expensive - coverage skills are premium
	"WR": 6.0,     # Moderate - decent depth in FA market
	"DL": 5.0,     # Moderate - interior linemen more available
	"LB": 4.0,     # Cheaper - good LBs available in FA
	"TE": 4.0,     # Cheaper - blocking TEs are findable
	"S": 3.5,      # Cheaper - safeties more fungible
	"OL": 3.0,     # Cheaper - guards/centers more available (OL generic)
	"G": 3.0,      # Cheaper - interior OL depth exists
	"C": 3.0,      # Cheaper - centers available
	"RB": 2.0,     # Cheapest - highly replaceable position
	"K": 1.0,      # Minimal - specialists rarely command big money
	"P": 1.0       # Minimal - punters are fungible
}

## FA Market Availability (probability of finding 70+ OVR FA in a given year)
## Higher = easier to find quality in free agency
## 1.0 = always available, 0.0 = never available
const FA_AVAILABILITY := {
	"QB": 0.15,    # Rare - quality QBs almost never hit FA in prime
	"EDGE": 0.25,  # Scarce - elite pass rushers get tagged/extended
	"OT": 0.30,    # Limited - good tackles rarely available
	"CB": 0.40,    # Moderate - some quality CBs hit market
	"WR": 0.60,    # Good - receivers more available
	"DL": 0.55,    # Moderate-good - interior linemen cycle through
	"LB": 0.70,    # High - solid LBs frequently available
	"TE": 0.65,    # Good - decent TE market exists
	"S": 0.75,     # High - safeties more available
	"OL": 0.80,    # Very high - guards/centers plentiful
	"G": 0.85,     # Very high - interior OL depth
	"C": 0.80,     # Very high - centers available
	"RB": 0.90,    # Extremely high - RBs everywhere in FA
	"K": 0.95,     # Nearly always - specialists always available
	"P": 0.95      # Nearly always - punters fungible
}

## Positional Impact Curve Steepness
## How much does the gap between average and elite matter at this position?
## Higher = bigger performance gap between 70 OVR and 85 OVR
## 2.0 = massive difference, 0.5 = minimal difference
const IMPACT_CURVE_STEEPNESS := {
	"QB": 2.0,     # Massive - elite QB vs average = night and day
	"EDGE": 1.8,   # Very high - elite pass rush transforms defense
	"OT": 1.6,     # High - pass protection quality is binary (sack or not)
	"CB": 1.5,     # High - coverage busts are catastrophic
	"WR": 1.3,     # Moderate-high - separation matters but scheme helps
	"DL": 1.2,     # Moderate - interior pressure valuable but less dramatic
	"LB": 1.0,     # Baseline - more forgiving position, scheme dependent
	"TE": 1.0,     # Baseline - blocking/receiving balance
	"S": 0.9,      # Below baseline - range matters but less volatile
	"OL": 0.9,     # Below baseline - interior OL more forgiving than OT
	"G": 0.85,     # Lower - guards can be coached up
	"C": 0.85,     # Lower - centers scheme-dependent
	"RB": 0.7,     # Low - scheme and OL matter more than RB talent
	"K": 0.5,      # Very low - kickers are kickers (mostly)
	"P": 0.4       # Lowest - punting variance is minimal
}


func get_id() -> String:
	return "economic_opportunity_cost"


func get_display_name() -> String:
	return "Economic Opportunity Cost"


func get_description() -> String:
	return "Adjusts need bonus based on FA market economics - draft expensive/scarce positions, sign cheap/available ones in FA"


func get_priority() -> int:
	# Run immediately after TeamNeedModifierV2 (priority 25)
	# This modifier adjusts the effective need based on economics
	return 26


## Bounds for additive adjustment: -3 to +3 OVR points
## This is a MODIFIER of the need bonus, not a replacement
func get_bounds() -> Dictionary:
	return {"min": -3.0, "max": 3.0}


func get_tags() -> Array:
	return ["draft", "economic", "opportunity_cost", "additive"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies during draft phase
	if ctx.phase != "draft":
		return false
	# Need valid position
	if ctx.position.is_empty():
		return false
	# Need draft round for context
	if ctx.draft_round <= 0:
		return false
	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var position := ctx.position
	var round_num := ctx.draft_round
	var base_rating := ctx.base_rating

	# Get economic factors for this position (explicit float cast for type safety)
	var fa_cost: float = float(FA_MARKET_COST.get(position, 5.0))
	var fa_availability: float = float(FA_AVAILABILITY.get(position, 0.5))
	var impact_curve: float = float(IMPACT_CURVE_STEEPNESS.get(position, 1.0))

	# Calculate draft priority score
	# Higher cost + lower availability + steeper impact = MORE reason to draft
	# Formula: priority = (cost/max_cost) * (1 - availability) * impact_curve
	#
	# Example calculations:
	# QB:   (15/15) * (1 - 0.15) * 2.0 = 1.0 * 0.85 * 2.0 = 1.70 (high priority)
	# EDGE: (12/15) * (1 - 0.25) * 1.8 = 0.8 * 0.75 * 1.8 = 1.08 (high priority)
	# RB:   (2/15)  * (1 - 0.90) * 0.7 = 0.13 * 0.10 * 0.7 = 0.009 (low priority)
	# LB:   (4/15)  * (1 - 0.70) * 1.0 = 0.27 * 0.30 * 1.0 = 0.08 (low priority)
	var max_cost: float = 15.0  # QB is the baseline maximum
	var cost_factor: float = fa_cost / max_cost
	var scarcity_factor: float = 1.0 - fa_availability
	var draft_priority: float = cost_factor * scarcity_factor * impact_curve

	# draft_priority ranges approximately:
	# - QB: ~1.7 (highest)
	# - EDGE: ~1.08
	# - OT: ~0.75
	# - CB: ~0.48
	# - WR: ~0.21
	# - RB: ~0.009 (lowest)

	# Convert to adjustment multiplier
	# We want to BOOST positions with high draft priority
	# and REDUCE positions with low draft priority (sign in FA instead)
	#
	# Neutral point is ~0.4 (middle of the range)
	# Above 0.4 = positive adjustment (draft it)
	# Below 0.4 = negative adjustment (sign in FA)
	var neutral_priority: float = 0.4
	var priority_deviation: float = draft_priority - neutral_priority

	# Scale the deviation to OVR adjustment
	# Max adjustment is +/- 3 OVR
	# A QB (priority 1.7) gets: (1.7 - 0.4) * 2.3 = +3.0 OVR
	# A RB (priority 0.01) gets: (0.01 - 0.4) * 2.3 = -0.9 OVR
	var adjustment_scale: float = 2.3  # Tuned to give ~+3 for QB, ~-1 for RB
	var raw_adjustment: float = priority_deviation * adjustment_scale

	# Apply round scaling - economics matter MORE in early rounds
	# In late rounds, you're just filling roster spots
	var round_scale: float = _get_round_scale(round_num)
	var scaled_adjustment: float = raw_adjustment * round_scale

	# Clamp to bounds
	var final_adjustment := clampf(scaled_adjustment, -3.0, 3.0)

	# Build explanation
	var reason := ""
	if final_adjustment > 0.5:
		reason = "%s is expensive/scarce in FA (+%.1f OVR draft priority)" % [position, final_adjustment]
	elif final_adjustment < -0.5:
		reason = "%s is cheap/available in FA (%.1f OVR, consider FA signing)" % [position, final_adjustment]
	else:
		reason = "%s has neutral FA market economics" % position

	return ModifierResult.create_additive(final_adjustment, reason, {
		"position": position,
		"round": round_num,
		"fa_cost_millions": fa_cost,
		"fa_availability_pct": fa_availability * 100.0,
		"impact_curve": impact_curve,
		"draft_priority_score": draft_priority,
		"raw_adjustment": raw_adjustment,
		"round_scale": round_scale,
		"final_adjustment": final_adjustment
	})


## Get round scaling factor
## Economics matter more in early rounds where you're investing premium capital
## In late rounds, roster filling takes precedence over economics
func _get_round_scale(round_num: int) -> float:
	match round_num:
		1:
			return 1.0   # Full economic consideration in R1
		2:
			return 0.9   # 90% in R2
		3:
			return 0.75  # 75% in R3
		4:
			return 0.6   # 60% in R4
		5:
			return 0.4   # 40% in R5
		6:
			return 0.25  # 25% in R6
		_:
			return 0.15  # 15% in R7+ (roster filling mode)


## Load and cache configuration (for future config-driven tuning)
func _get_config() -> Dictionary:
	if _config_loaded:
		return _config_cache

	var config := _load_config_file()
	if config.is_empty():
		_config_cache = {}
	else:
		_config_cache = config

	_config_loaded = true
	return _config_cache


## Load config file directly using FileAccess
## Returns empty dictionary on failure
static func _load_config_file() -> Dictionary:
	var file := FileAccess.open(DRAFT_EVALUATION_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		return {}

	return json.data


## Clear config cache (for testing)
static func clear_cache() -> void:
	_config_cache.clear()
	_config_loaded = false


## Get the draft priority score for a position (for external use/testing)
## Returns a value roughly in range 0.0 to 2.0
## Higher = more important to draft vs sign in FA
static func get_draft_priority_for_position(position: String) -> float:
	var fa_cost := float(FA_MARKET_COST.get(position, 5.0))
	var fa_availability := float(FA_AVAILABILITY.get(position, 0.5))
	var impact_curve := float(IMPACT_CURVE_STEEPNESS.get(position, 1.0))

	var max_cost := 15.0
	var cost_factor := fa_cost / max_cost
	var scarcity_factor := 1.0 - fa_availability

	return cost_factor * scarcity_factor * impact_curve


## Get all positions sorted by draft priority (highest first)
## Useful for debugging and validation
static func get_positions_by_draft_priority() -> Array:
	var positions_with_priority: Array = []

	for position in FA_MARKET_COST.keys():
		var priority := get_draft_priority_for_position(position)
		positions_with_priority.append({
			"position": position,
			"priority": priority,
			"fa_cost": FA_MARKET_COST.get(position, 0),
			"fa_availability": FA_AVAILABILITY.get(position, 0),
			"impact_curve": IMPACT_CURVE_STEEPNESS.get(position, 0)
		})

	# Sort by priority descending
	positions_with_priority.sort_custom(func(a, b):
		return float(a["priority"]) > float(b["priority"])
	)

	return positions_with_priority
