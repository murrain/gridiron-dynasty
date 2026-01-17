## PositionTierModifier - Adjusts evaluation based on draft round position value tiers
##
## Implements tier-based draft strategy:
## - Premium positions (QB, EDGE, OT, CB) boosted in early rounds
## - Devalued positions (RB, S) penalized in rounds 1-2
## - Converges to neutral in later rounds
extends "res://scripts/core/evaluation/EvaluationModifier.gd"


func get_id() -> String:
	return "position_tier"


func get_display_name() -> String:
	return "Position Tier (Draft)"


func get_description() -> String:
	return "Adjusts evaluation based on position value tier and draft round"


func get_priority() -> int:
	return 10


func get_bounds() -> Dictionary:
	return {"min": 0.6, "max": 1.4}


func get_tags() -> Array:
	return ["draft", "position", "tier"]


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
	var premium: Array = premium_tier.get("positions", []) as Array
	var devalued: Array = devalued_tier.get("positions", []) as Array

	var multiplier := 1.0
	var reason := ""

	# Premium positions in early rounds
	if position in premium:
		if round_num <= 2:
			multiplier = 1.3
			reason = "%s is premium in round %d" % [position, round_num]
		elif round_num <= 4:
			multiplier = 1.15
			reason = "%s has elevated value in round %d" % [position, round_num]
		else:
			multiplier = 1.0
			reason = "Neutral tier value in later rounds"

	# Devalued positions in early rounds
	elif position in devalued:
		if round_num <= 2:
			multiplier = 0.7
			reason = "%s devalued in round %d (luxury pick)" % [position, round_num]
		elif round_num <= 4:
			multiplier = 0.85
			reason = "%s slightly devalued in round %d" % [position, round_num]
		else:
			multiplier = 1.0
			reason = "Good value in later rounds"

	else:
		multiplier = 1.0
		reason = "Standard position tier"

	return ModifierResult.new(multiplier, reason, {
		"round": round_num,
		"tier": "premium" if position in premium else ("devalued" if position in devalued else "standard")
	})
