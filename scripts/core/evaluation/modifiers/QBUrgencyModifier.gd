## QBUrgencyModifier - Applies urgency boost for elite QB prospects
##
## Teams without franchise QBs aggressively target elite QB prospects.
## Only applies to QBs rated 75+ to prevent reaching for mediocre prospects.
##
## Levels:
## - Desperate: 2.8x (no franchise QB)
## - Moderate: 1.6x (aging/uncertain QB situation)
## - None: 1.0x (franchise QB in place)
extends "res://scripts/core/evaluation/EvaluationModifier.gd"


func get_id() -> String:
	return "qb_urgency"


func get_display_name() -> String:
	return "QB Urgency"


func get_description() -> String:
	return "Boosts elite QB prospects for teams with urgent QB needs"


func get_priority() -> int:
	return 40


func get_bounds() -> Dictionary:
	return {"min": 1.0, "max": 2.8}


func get_tags() -> Array:
	return ["qb", "draft", "urgency"]


func is_applicable(ctx: EvaluationContext) -> bool:
	# Only applies to QB in draft phase
	if ctx.position != "QB":
		return false

	if ctx.phase != "draft":
		return false

	# Only applies to elite prospects (75+)
	if ctx.base_rating < 75.0:
		return false

	return true


func calculate(ctx: EvaluationContext) -> ModifierResult:
	var roster: Dictionary = ctx.roster
	var class_rules: Dictionary = ctx.class_rules

	# Evaluate QB urgency (use helper from NflDraft if needed)
	var urgency_data := _evaluate_qb_urgency(roster, ctx.positions_cfg, class_rules)
	var urgency_level := String(urgency_data.get("level", "none"))

	var qb_cfg: Dictionary = class_rules.get("draft_qb_urgency", {}) as Dictionary
	var multiplier := 1.0
	var reason := ""

	if urgency_level == "desperate":
		multiplier = float(qb_cfg.get("desperate_multiplier", 2.8))
		reason = "Desperate need for franchise QB"
	elif urgency_level == "moderate":
		multiplier = float(qb_cfg.get("moderate_multiplier", 1.6))
		reason = "Moderate QB need"
	else:
		multiplier = 1.0
		reason = "Franchise QB in place"

	return ModifierResult.new(multiplier, reason, {
		"urgency_level": urgency_level,
		"raw_multiplier": multiplier
	})


## Helper to evaluate QB urgency (copy from NflDraft.gd)
func _evaluate_qb_urgency(roster: Dictionary, positions_cfg: Dictionary, class_rules: Dictionary) -> Dictionary:
	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var qbs: Array = by_position.get("QB", []) as Array

	if qbs.is_empty():
		return {"level": "desperate", "reason": "No QB on roster"}

	# Check for franchise QB (starter quality, age < 33)
	var has_franchise_qb := false
	var players: Array = roster.get("players", []) as Array

	for qb_id in qbs:
		# Find the player in the players array
		var qb: Dictionary = {}
		for player in players:
			if player.get("player_id") == qb_id:
				qb = player
				break

		if qb.is_empty():
			continue

		var overall := float(qb.get("overall", 0.0))
		var age := int(qb.get("age", 40))

		if overall >= 75.0 and age < 33:
			has_franchise_qb = true
			break

	if not has_franchise_qb:
		return {"level": "desperate", "reason": "No franchise QB"}

	# Has franchise QB
	return {"level": "none", "reason": "Franchise QB in place"}
