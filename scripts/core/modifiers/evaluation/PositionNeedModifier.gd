## PositionNeedModifier - Adjusts evaluation based on roster needs
##
## Teams value players at positions where they have gaps.
## Returns 0.0 multiplier for positions at hard cap (can't add more).
##
## Multiplier ranges:
##   - 0.0: Position at hard cap (blocked)
##   - 0.1-0.4: Position overstocked
##   - 0.95-1.0: Position at ideal depth
##   - 1.0-1.5: Position below ideal
extends "res://scripts/core/modifiers/Modifier.gd"

const RosterComposition = preload("res://scripts/core/roster/RosterComposition.gd")


func get_id() -> String:
	return "position_need"


func get_display_name() -> String:
	return "Position Need"


func get_description() -> String:
	return "Adjusts evaluation based on team's roster needs at position"


func get_target() -> Target:
	return Target.TEAM_EVALUATION


func get_contexts() -> Array:
	return [Context.DRAFT, Context.FREE_AGENCY, Context.TRADE]


func get_priority() -> int:
	return 40  # Before scheme/coach modifiers


func get_tags() -> Array:
	return ["roster", "evaluation", "team_specific"]


func is_applicable(context_data: Dictionary) -> bool:
	var position := String(context_data.get("position", ""))
	return not position.is_empty()


func calculate(context_data: Dictionary) -> ModifierResult:
	var position := String(context_data.get("position", ""))
	var roster: Dictionary = context_data.get("roster", {}) as Dictionary
	var phase := String(context_data.get("phase", "draft"))

	var by_position: Dictionary = roster.get("by_position", {}) as Dictionary
	var current_count := (by_position.get(position, []) as Array).size()
	var ideal := RosterComposition.get_ideal_depth(position)
	var max_allowed := RosterComposition.get_max_depth(position)

	var multiplier := 1.0
	var reason := ""

	# HARD CAP: At or above max = blocked (0.0)
	if current_count >= max_allowed:
		multiplier = 0.0
		reason = "Position at hard cap (%d/%d)" % [current_count, max_allowed]
		return ModifierResult.new(multiplier, 0.0, reason, {
			"current": current_count,
			"ideal": ideal,
			"max": max_allowed,
			"blocked": true
		})

	# OVERSTOCKED: Above ideal but below cap
	if current_count > ideal:
		var excess := current_count - ideal
		var slots_to_cap := max_allowed - ideal
		if slots_to_cap > 0:
			var ratio := float(excess) / float(slots_to_cap)
			multiplier = 0.4 - (ratio * 0.3)  # 0.4 → 0.1
		else:
			multiplier = 0.1
		reason = "Position overstocked (%d/%d ideal)" % [current_count, ideal]

	# CRITICAL NEED: No players at position
	elif current_count == 0:
		multiplier = 1.5
		reason = "Critical need - no %s on roster" % position

	# BELOW IDEAL: Need more players
	elif current_count < ideal:
		var deficit := ideal - current_count
		multiplier = 1.0 + (float(deficit) / float(ideal)) * 0.3
		reason = "Below ideal depth (%d/%d)" % [current_count, ideal]

	# AT IDEAL: Neutral
	else:
		multiplier = 0.95
		reason = "At ideal depth"

	# Apply phase-specific weighting
	# Draft early rounds: Need is minor (Best Player Available)
	# Draft late rounds + FA: Need is more important
	var draft_round := int(context_data.get("draft_round", 0))
	if phase == "draft" and draft_round > 0:
		var need_weight := 0.15 if draft_round <= 2 else 0.30
		# Scale multiplier toward 1.0 based on weight
		multiplier = 1.0 + (multiplier - 1.0) * need_weight
		if draft_round <= 2:
			reason += " (BPA philosophy in early rounds)"

	return ModifierResult.new(multiplier, 0.0, reason, {
		"current": current_count,
		"ideal": ideal,
		"max": max_allowed,
		"blocked": false,
		"draft_round": draft_round
	})
