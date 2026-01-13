extends RefCounted
class_name HypeGenerator

## Hype Generation System
##
## Hype represents media attention, buzz, and perceived "heat" around a player.
## It affects EVALUATION (scout bias) but NOT actual performance.
##
## Key concepts:
## - Hype ranges 0-100, with 50 as neutral
## - High hype creates positive scout bias (overrating)
## - Low hype creates negative scout bias (underrating)
## - Hype is generated at key moments and decays over time
## - Hype affects contract demands and draft expectations
##
## RNG Usage: Multiple randf_range() calls per function - see docs for counts

## Generate initial hype when player enters high school/college recruiting
##
## RNG consumption: 4 randf_range() calls
##
## Parameters:
##   player: Player dictionary
##   star_rating: Recruiting star rating (2-5)
##   region: Geographic region (south, midwest, west, northeast)
##   school_media_tier: School's media market tier (0.0-1.0)
##   rng: RandomNumberGenerator instance
##
## Returns: Initial hype value (15-95 range)
static func generate_initial_hype(
	player: Dictionary,
	star_rating: int,
	region: String,
	school_media_tier: float,
	rng: RandomNumberGenerator
) -> float:
	var base_hype := 50.0  # Neutral starting point

	# Factor 1: Recruiting ranking creates initial buzz
	var recruiting_bonus := 0.0
	if star_rating == 5:
		recruiting_bonus = rng.randf_range(25.0, 35.0)  # 5-stars get major hype
	elif star_rating == 4:
		recruiting_bonus = rng.randf_range(10.0, 20.0)
	elif star_rating == 3:
		recruiting_bonus = rng.randf_range(-5.0, 8.0)
	else:  # 2-star or lower
		recruiting_bonus = rng.randf_range(-15.0, 0.0)  # Low-rated = low hype

	# Factor 2: School media market (normalized 0-1)
	var market_bonus := school_media_tier * rng.randf_range(8.0, 12.0)

	# Factor 3: Position visibility (QBs get more attention)
	var position := String(player.get("position", ""))
	var position_modifier := _get_position_hype_modifier(position)

	# Factor 4: Random "it factor" variance
	var it_factor := rng.randf_range(-8.0, 12.0)

	var total_hype := base_hype + recruiting_bonus + market_bonus + position_modifier + it_factor

	return clampf(total_hype, 15.0, 95.0)

## Apply hype change from a specific event
##
## RNG consumption: 1 randf_range() call
##
## Parameters:
##   current_hype: Player's current hype value
##   event_type: Type of event (see list below)
##   rng: RandomNumberGenerator instance
##
## Event types:
##   - heisman_finalist, conference_poy, bowl_mvp, viral_highlight,
##     natl_championship, major_injury, off_field_issue, underwhelming_season,
##     transfer_up, limited_snaps
##
## Returns: New hype value after event
static func apply_hype_event(
	current_hype: float,
	event_type: String,
	rng: RandomNumberGenerator
) -> float:
	var change := 0.0

	match event_type:
		"heisman_finalist":
			change = rng.randf_range(15.0, 25.0)
		"conference_poy":
			change = rng.randf_range(8.0, 12.0)
		"bowl_mvp":
			change = rng.randf_range(10.0, 18.0)
		"viral_highlight":
			change = rng.randf_range(5.0, 15.0)
		"natl_championship":
			change = rng.randf_range(8.0, 15.0)
		"major_injury":
			change = rng.randf_range(-20.0, -10.0)
		"off_field_issue":
			change = rng.randf_range(-30.0, -15.0)
		"underwhelming_season":
			change = rng.randf_range(-12.0, -5.0)
		"transfer_up":
			change = rng.randf_range(5.0, 12.0)
		"limited_snaps":
			change = rng.randf_range(-15.0, -8.0)
		_:
			push_warning("Unknown hype event type: " + event_type)
			return current_hype

	return clampf(current_hype + change, 10.0, 98.0)

## Apply combine/pro day hype modifiers
##
## RNG consumption: 4-8 randf_range() calls (varies by position and results)
##
## Parameters:
##   current_hype: Player's current hype
##   player: Player dictionary with measurables and stats
##   position: Position string
##   rng: RandomNumberGenerator instance
##
## Returns: New hype value after combine performance
static func apply_combine_hype(
	current_hype: float,
	player: Dictionary,
	position: String,
	rng: RandomNumberGenerator
) -> float:
	var combine_modifier := 0.0

	# Factor 1: 40-yard dash (all positions care about speed)
	var speed := float(player.get("stats", {}).get("speed", 50.0))
	var expected_speed := _get_expected_speed_for_position(position)
	if speed >= expected_speed + 10.0:  # Elite speed
		combine_modifier += rng.randf_range(8.0, 18.0)  # "He ran a 4.3!"
	elif speed < expected_speed - 10.0:  # Slow
		combine_modifier += rng.randf_range(-12.0, -5.0)  # "Slower than expected"

	# Factor 2: Strength tests for OL/DL/TE positions
	if position in ["OL", "DL", "TE", "EDGE"]:
		var strength := float(player.get("stats", {}).get("strength", 50.0))
		if strength >= 85.0:  # Elite strength
			combine_modifier += rng.randf_range(3.0, 8.0)
		elif strength < 40.0:  # Weak
			combine_modifier += rng.randf_range(-5.0, -2.0)

	# Factor 3: Agility for skill positions
	if position in ["WR", "CB", "RB", "S"]:
		var agility := float(player.get("stats", {}).get("agility", 50.0))
		if agility >= 85.0:  # Elite explosion!
			combine_modifier += rng.randf_range(5.0, 12.0)

	# Factor 4: Interview presence (charisma-based)
	var charisma := float(player.get("stats", {}).get("charisma", 50.0))
	var interview_score := charisma + rng.randf_range(-10.0, 10.0)
	if interview_score >= 75.0:
		combine_modifier += rng.randf_range(3.0, 8.0)  # "Great kid, coaches love him"
	elif interview_score < 40.0:
		combine_modifier += rng.randf_range(-8.0, -3.0)  # "Personality concerns"

	return clampf(current_hype + combine_modifier, 10.0, 98.0)

## Calculate hype decay over time
##
## RNG consumption: None (deterministic decay)
##
## Hype naturally decays toward neutral (50.0) if not reinforced.
## Rookies maintain hype, veterans' hype fades toward neutral.
##
## Parameters:
##   current_hype: Current hype value
##   years_in_league: Number of years since entering league
##
## Returns: Decayed hype value
static func decay_hype(current_hype: float, years_in_league: int) -> float:
	# No decay in first year
	if years_in_league == 0:
		return current_hype

	# Decay rate increases with years
	var decay_rate := 0.15 * float(years_in_league)
	var neutral := 50.0

	return lerpf(current_hype, neutral, minf(decay_rate, 0.8))

## Calculate "boring prospect penalty" - legitimately good players with low hype
##
## RNG consumption: 4 randf_range() calls
##
## Some good players have low hype due to:
## - Small school (no TV exposure)
## - "Pro style" game that doesn't create highlights
## - Quiet personality
## - Position that doesn't get attention
##
## Parameters:
##   player: Player dictionary
##   school_media_tier: School's media tier (0.0-1.0)
##   play_style: Playing style ("pro_style", "explosive", etc.)
##   rng: RandomNumberGenerator instance
##
## Returns: Hype penalty (negative value)
static func calculate_boring_prospect_penalty(
	player: Dictionary,
	school_media_tier: float,
	play_style: String,
	rng: RandomNumberGenerator
) -> float:
	var penalty := 0.0

	# Small school penalty
	if school_media_tier < 0.3:  # Small/unknown school
		penalty -= rng.randf_range(8.0, 15.0)

	# "Pro style" players don't pop on tape
	if play_style == "pro_style":
		penalty -= rng.randf_range(3.0, 8.0)

	# Low charisma = no media buzz
	var charisma := float(player.get("stats", {}).get("charisma", 50.0))
	if charisma < 40.0:
		penalty -= rng.randf_range(5.0, 10.0)

	# Position visibility
	var position := String(player.get("position", ""))
	if position in ["OL", "S", "K", "P"]:
		penalty -= rng.randf_range(3.0, 8.0)

	return penalty

## Private helper: Get position hype modifier
static func _get_position_hype_modifier(position: String) -> float:
	var modifiers := {
		"QB": 12.0,
		"RB": 6.0,
		"WR": 5.0,
		"TE": 2.0,
		"OL": -3.0,
		"DL": 1.0,
		"EDGE": 4.0,
		"LB": 2.0,
		"CB": 3.0,
		"S": 1.0,
		"K": -8.0,
		"P": -10.0
	}
	return modifiers.get(position, 0.0)

## Private helper: Get expected speed for a position (for combine comparison)
static func _get_expected_speed_for_position(position: String) -> float:
	var expected_speeds := {
		"WR": 84.0,
		"CB": 86.0,
		"RB": 78.0,
		"S": 78.0,
		"TE": 60.0,
		"LB": 62.0,
		"QB": 55.0,
		"EDGE": 72.0,
		"DL": 40.0,
		"OL": 38.0,
		"K": 45.0,
		"P": 52.0
	}
	return expected_speeds.get(position, 50.0)
