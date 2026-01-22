## PositionTierModifier - Adjusts evaluation based on draft round position value tiers
##
## Implements tier-based draft strategy using ADDITIVE bonuses:
## - Premium positions (QB, EDGE, OL, CB) get +3 OVR in early rounds
## - Devalued positions (RB, TE, S) get -3 OVR penalty in rounds 1-2
## - Special teams (K, P) get severe penalties
## - Converges to neutral in later rounds
##
## Design rationale:
## Using additive bonuses ensures player quality (OVR) dominates over position.
## A +3 OVR bonus is meaningful but won't let a 73 OVR player beat an 88 OVR player.
## Example: 73 OVR EDGE + 3 bonus = 76, still loses to 88 OVR WR + 0 bonus = 88
extends "res://scripts/core/evaluation/EvaluationModifier.gd"


func get_id() -> String:
	return "position_tier"


func get_display_name() -> String:
	return "Position Tier (Draft)"


func get_description() -> String:
	return "Adjusts evaluation based on position value tier and draft round (additive OVR bonus)"


func get_priority() -> int:
	return 10


## Bounds for additive bonus: -5 to +5 OVR points
func get_bounds() -> Dictionary:
	return {"min": -5.0, "max": 5.0}


func get_tags() -> Array:
	return ["draft", "position", "tier", "additive"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies in draft phase
	if ctx.phase != "draft":
		return false

	# Need draft_strategy and draft_round
	if ctx.draft_round <= 0:
		return false

	if ctx.draft_strategy.is_empty():
		return false

	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var position := ctx.position
	var round_num := ctx.draft_round
	var draft_strategy: Dictionary = ctx.draft_strategy

	# Get position tiers from strategy
	var tiers: Dictionary = draft_strategy.get("position_tiers", {}) as Dictionary
	var premium_tier: Dictionary = tiers.get("premium", {}) as Dictionary
	var devalued_tier: Dictionary = tiers.get("devalued", {}) as Dictionary
	var special_teams_tier: Dictionary = tiers.get("special_teams", {}) as Dictionary
	var premium: Array = premium_tier.get("positions", []) as Array
	var devalued: Array = devalued_tier.get("positions", []) as Array
	var special_teams: Array = special_teams_tier.get("positions", []) as Array

	# Additive bonus constants (OVR points)
	# These are intentionally modest so player quality dominates
	const PREMIUM_ROUND_1_BONUS := 3.0   # +3 OVR for premium in round 1
	const PREMIUM_ROUND_2_BONUS := 2.0   # +2 OVR for premium in round 2
	const PREMIUM_ROUND_3_4_BONUS := 1.0 # +1 OVR for premium in rounds 3-4

	const DEVALUED_ROUND_1_PENALTY := -3.0  # -3 OVR for devalued in round 1
	const DEVALUED_ROUND_2_PENALTY := -2.0  # -2 OVR for devalued in round 2
	const DEVALUED_ROUND_3_4_PENALTY := -1.0 # -1 OVR for devalued in rounds 3-4

	# Special teams get severe penalties in early rounds (rarely drafted high)
	const SPECIAL_TEAMS_ROUND_1_PENALTY := -20.0  # Essentially never pick K/P in round 1
	const SPECIAL_TEAMS_ROUND_2_PENALTY := -15.0  # Very rare in round 2
	const SPECIAL_TEAMS_ROUND_3_4_PENALTY := -8.0 # Uncommon in rounds 3-4
	const SPECIAL_TEAMS_ROUND_5_PLUS_PENALTY := -3.0 # Slight penalty even late

	var bonus := 0.0
	var reason := ""
	var tier := "standard"

	# Premium positions (QB, EDGE, OL, CB) - boosted in early rounds
	if position in premium:
		tier = "premium"
		if round_num == 1:
			bonus = PREMIUM_ROUND_1_BONUS
			reason = "%s is premium in round 1 (+%.0f OVR)" % [position, bonus]
		elif round_num == 2:
			bonus = PREMIUM_ROUND_2_BONUS
			reason = "%s is premium in round 2 (+%.0f OVR)" % [position, bonus]
		elif round_num <= 4:
			bonus = PREMIUM_ROUND_3_4_BONUS
			reason = "%s has elevated value in rounds 3-4 (+%.0f OVR)" % [position, bonus]
		else:
			bonus = 0.0
			reason = "Neutral tier value in later rounds"

	# Devalued positions (RB, TE, S) - penalized in early rounds
	elif position in devalued:
		tier = "devalued"
		if round_num == 1:
			bonus = DEVALUED_ROUND_1_PENALTY
			reason = "%s devalued in round 1 (luxury pick, %.0f OVR)" % [position, bonus]
		elif round_num == 2:
			bonus = DEVALUED_ROUND_2_PENALTY
			reason = "%s devalued in round 2 (%.0f OVR)" % [position, bonus]
		elif round_num <= 4:
			bonus = DEVALUED_ROUND_3_4_PENALTY
			reason = "%s slightly devalued in rounds 3-4 (%.0f OVR)" % [position, bonus]
		else:
			bonus = 0.0
			reason = "Good value in later rounds"

	# Special teams (K, P) - severely penalized, almost never drafted early
	elif position in special_teams:
		tier = "special_teams"
		if round_num == 1:
			bonus = SPECIAL_TEAMS_ROUND_1_PENALTY
			reason = "%s rarely drafted in round 1 (%.0f OVR)" % [position, bonus]
		elif round_num == 2:
			bonus = SPECIAL_TEAMS_ROUND_2_PENALTY
			reason = "%s rarely drafted in round 2 (%.0f OVR)" % [position, bonus]
		elif round_num <= 4:
			bonus = SPECIAL_TEAMS_ROUND_3_4_PENALTY
			reason = "%s uncommon in rounds 3-4 (%.0f OVR)" % [position, bonus]
		else:
			bonus = SPECIAL_TEAMS_ROUND_5_PLUS_PENALTY
			reason = "%s typically drafted late (%.0f OVR)" % [position, bonus]

	# Standard positions (WR, DL, LB) - neutral
	else:
		tier = "standard"
		bonus = 0.0
		reason = "Standard position tier (neutral)"

	# Return additive modifier result
	return ModifierResult.create_additive(bonus, reason, {
		"round": round_num,
		"tier": tier,
		"bonus_ovr": bonus
	})
