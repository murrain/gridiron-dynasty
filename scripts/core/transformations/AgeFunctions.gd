extends RefCounted
class_name AgeFunctions

## Pure functions for player age-related transformations.
## All functions are side-effect-free and deterministic.
##
## CRITICAL: All functions are PURE - they never modify input dictionaries.
## They always return NEW dictionaries with the updated values.

# ============================================================================
# PURE FUNCTIONS - Age Transformations
# ============================================================================

## Increment a player's age by one year (pure function).
##
## This is a trivial transformation but encapsulated here for consistency
## and to ensure immutability guarantees.
##
## RNG consumption: NONE (deterministic computation)
##
## @param player: Player dictionary (unchanged)
## @return: NEW player dictionary with age incremented by 1
##
## Example:
##   var p := {"age": 22, "name": "John"}
##   var p2 := AgeFunctions.increment_age(p)
##   assert(p["age"] == 22)  # Original unchanged
##   assert(p2["age"] == 23)  # New copy modified
static func increment_age(player: Dictionary) -> Dictionary:
	# Create shallow copy (age is primitive, no nested mutation needed)
	var new_player := player.duplicate(false)

	# Extract current age with safe default
	var current_age := int(player.get("age", 18))

	# Increment age (capped at reasonable maximum for safety)
	new_player["age"] = mini(current_age + 1, 99)

	return new_player


## Get age-based modifier for stat development (pure function).
##
## Returns a multiplier based on player age and position-specific aging curves.
## Younger players in growth phase get positive modifiers, older players in
## decline phase get negative modifiers.
##
## RNG consumption: NONE (deterministic computation)
##
## @param age: Player's current age
## @param position: Player's position (for position-specific curves)
## @param configs: Configuration dictionary containing development settings
## @return: float multiplier in range [0.4, 1.6]
##
## Algorithm:
##   1. Extract position-specific peak_age and decline_start from configs
##   2. Determine phase: growth (< peak), prime (peak to decline), decline (> decline_start)
##   3. Return phase-specific multiplier
##
## Example:
##   var mod := AgeFunctions.get_age_modifier(24, "QB", configs)
##   # For QB with peak_age=28, returns ~1.0 (growth phase)
static func get_age_modifier(age: int, position: String, configs: Dictionary) -> float:
	# Extract position config with safe defaults
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary

	# Position-specific aging curve parameters
	var peak_age := int(dev_cfg.get("peak_age", 26))
	var decline_start := int(dev_cfg.get("decline_start", 30))

	# Determine lifecycle phase
	if age < peak_age:
		# Growth phase: younger players develop faster
		# Linear interpolation from 1.2 at age 18 to 1.0 at peak_age
		var years_to_peak := float(peak_age - age)
		var growth_bonus := years_to_peak * 0.02  # 2% per year below peak
		return clampf(1.0 + growth_bonus, 1.0, 1.4)
	elif age < decline_start:
		# Prime phase: stable performance
		return 1.0
	else:
		# Decline phase: older players decline faster
		# Linear interpolation from 1.0 at decline_start to 0.4 at age 40
		var years_past_decline := float(age - decline_start)
		var decline_penalty := years_past_decline * 0.06  # 6% per year past decline start
		return clampf(1.0 - decline_penalty, 0.4, 1.0)


## Calculate years until peak performance (pure function).
##
## Useful for development projections and scouting analysis.
##
## RNG consumption: NONE (deterministic computation)
##
## @param age: Player's current age
## @param position: Player's position
## @param configs: Configuration dictionary
## @return: int years until peak (negative if past peak)
##
## Example:
##   var years := AgeFunctions.years_to_peak(22, "WR", configs)
##   # For WR with peak_age=27, returns 5
static func years_to_peak(age: int, position: String, configs: Dictionary) -> int:
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
	var peak_age := int(dev_cfg.get("peak_age", 26))

	return peak_age - age


## Calculate years of remaining prime window (pure function).
##
## Returns number of years before entering decline phase.
## Useful for contract evaluation and roster planning.
##
## RNG consumption: NONE (deterministic computation)
##
## @param age: Player's current age
## @param position: Player's position
## @param configs: Configuration dictionary
## @return: int years until decline (0 if already in decline)
##
## Example:
##   var remaining := AgeFunctions.years_until_decline(28, "RB", configs)
##   # For RB with decline_start=30, returns 2
static func years_until_decline(age: int, position: String, configs: Dictionary) -> int:
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary
	var decline_start := int(dev_cfg.get("decline_start", 30))

	return maxi(0, decline_start - age)


## Determine lifecycle phase for a player (pure function).
##
## Returns one of: "growth", "prime", "decline"
##
## RNG consumption: NONE (deterministic computation)
##
## @param age: Player's current age
## @param position: Player's position
## @param configs: Configuration dictionary
## @return: String phase name ("growth", "prime", or "decline")
##
## Example:
##   var phase := AgeFunctions.get_lifecycle_phase(24, "LB", configs)
##   # For LB with peak_age=26, decline_start=30, returns "growth"
static func get_lifecycle_phase(age: int, position: String, configs: Dictionary) -> String:
	var positions_cfg: Dictionary = configs.get("positions", {}) as Dictionary
	var pos_cfg: Dictionary = positions_cfg.get(position, {}) as Dictionary
	var dev_cfg: Dictionary = pos_cfg.get("development", {}) as Dictionary

	var peak_age := int(dev_cfg.get("peak_age", 26))
	var decline_start := int(dev_cfg.get("decline_start", 30))

	if age < peak_age:
		return "growth"
	elif age < decline_start:
		return "prime"
	else:
		return "decline"
