extends RefCounted
class_name ConferenceService

## Conference Management Service
##
## Manages college conference assignments and strength of schedule:
## - Assign colleges to conferences during world generation
## - Calculate strength of schedule based on opponents' conference tiers
## - Provide draft weight multipliers for conference quality
##
## RNG Pattern:
##   assign_colleges_to_conferences(): Uses explicit rng parameter
##   All other functions: Pure calculations (no RNG)
##
## Data Model:
##   Modifies: world_state["colleges"][i] - adds conference fields
##   Creates: world_state["conferences"] - conference index
##
## Integration:
##   Called from CollegeGenerator during world generation
##   Called from CollegeSeason for strength of schedule updates


## Assign colleges to conferences during world generation
##
## RNG: Uses explicit rng parameter for conference selection
## Performance: O(colleges × conferences) = O(130 × 11) = ~1430 operations
##
## Algorithm:
##   1. Load conference definitions from config
##   2. Sort conferences by prestige (Power 5 first)
##   3. For each conference, calculate fit scores for all unassigned colleges
##   4. Assign best-fit colleges to fill conference to target size
##   5. Remaining colleges go to catch-all independent conference
##
## Parameters:
##   colleges: Array - List of college dictionaries to assign
##   config: Dictionary - Configuration with conference definitions
##   rng: RandomNumberGenerator - Explicit RNG for deterministic assignment
##
## Side Effects:
##   Modifies each college dictionary in-place:
##   - Adds "conference" field (conference ID)
##   - Adds "conference_tier" field (power_5, group_5, fcs)
##   - Initializes "strength_of_schedule" field to 0.0
static func assign_colleges_to_conferences(
	colleges: Array,
	config: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var conferences_cfg: Array = config.get("conferences", [])

	if conferences_cfg.is_empty():
		push_error("ConferenceService: No conferences defined in config")
		return

	# Sort conferences by draft weight (highest first = most prestigious)
	var sorted_conferences: Array = conferences_cfg.duplicate()
	sorted_conferences.sort_custom(func(a, b):
		return float((a as Dictionary).get("draft_weight_multiplier", 1.0)) > \
		       float((b as Dictionary).get("draft_weight_multiplier", 1.0))
	)

	# Track which colleges have been assigned
	var unassigned: Array = []
	for college in colleges:
		unassigned.append(college)

	# Assign colleges to each conference (highest prestige first)
	for conf in sorted_conferences:
		var conf_dict: Dictionary = conf
		var conf_id := String(conf_dict.get("id", ""))

		# Skip catch-all independent conferences until the end
		if conf_id == "fcs_independent" or conf_id == "independent":
			continue

		var size_min := int(conf_dict.get("size_min", 10))
		var size_max := int(conf_dict.get("size_max", 14))
		var target_size := int((size_min + size_max) / 2)

		# Calculate fit scores for all unassigned colleges
		var fit_scores: Array = []
		for college in unassigned:
			var c: Dictionary = college
			var fit := _calculate_conference_fit(c, conf_dict, config)
			fit_scores.append({
				"college": c,
				"fit": fit
			})

		# Sort by fit score (highest first)
		fit_scores.sort_custom(func(a, b):
			return float((a as Dictionary).get("fit", 0.0)) > \
			       float((b as Dictionary).get("fit", 0.0))
		)

		# Assign top colleges to this conference
		var assigned_count := 0
		for i in range(min(target_size, fit_scores.size())):
			var entry: Dictionary = fit_scores[i]
			var college: Dictionary = entry["college"]

			# Assign conference
			college["conference"] = conf_id
			college["conference_tier"] = String(conf_dict.get("tier", "group_5"))
			college["strength_of_schedule"] = 0.0

			# Remove from unassigned
			unassigned.erase(college)
			assigned_count += 1

	# Assign any remaining colleges to independent conference
	var independent_tier := "fcs"
	for college in unassigned:
		var c: Dictionary = college
		c["conference"] = "fcs_independent"
		c["conference_tier"] = independent_tier
		c["strength_of_schedule"] = 0.0


## Build conference index from assigned colleges
##
## RNG: None (pure aggregation)
## Performance: O(colleges)
##
## Parameters:
##   colleges: Array - List of college dictionaries with conference assignments
##   config: Dictionary - Configuration with conference definitions
##
## Returns:
##   Dictionary: conference_id -> conference_data with members list
static func build_conference_index(
	colleges: Array,
	config: Dictionary
) -> Dictionary:
	var conferences_cfg: Array = config.get("conferences", [])
	var conferences := {}

	# Initialize conference structures
	for conf in conferences_cfg:
		var conf_dict: Dictionary = conf
		var conf_id := String(conf_dict.get("id", ""))

		conferences[conf_id] = {
			"id": conf_id,
			"name": String(conf_dict.get("name", "")),
			"tier": String(conf_dict.get("tier", "group_5")),
			"draft_weight_multiplier": float(conf_dict.get("draft_weight_multiplier", 1.0)),
			"members": []
		}

	# Add colleges to their conferences
	for college in colleges:
		var c: Dictionary = college
		var conf_id := String(c.get("conference", ""))

		if conferences.has(conf_id):
			var members: Array = conferences[conf_id]["members"]
			members.append(String(c.get("id", "")))

	return conferences


## Calculate strength of schedule for a college based on season results
##
## RNG: None (pure calculation)
## Performance: O(games) per college
##
## Algorithm:
##   1. Look up all games played by this college
##   2. For each opponent, get their conference tier
##   3. Calculate average opponent conference strength
##   4. Normalize to 0.0-1.0 scale
##
## Parameters:
##   college_id: String - College identifier
##   season_results: Dictionary - Season records (team_id -> record)
##   colleges: Array - List of all colleges with conference assignments
##
## Returns:
##   float: Strength of schedule score (0.0-1.0)
##   Higher = tougher schedule
static func calculate_strength_of_schedule(
	college_id: String,
	season_results: Dictionary,
	colleges: Array
) -> float:
	# Build college lookup index
	var college_index := {}
	for college in colleges:
		var c: Dictionary = college
		var id := String(c.get("id", ""))
		if not id.is_empty():
			college_index[id] = c

	# Get this college's record to find opponents
	var record: Dictionary = season_results.get(college_id, {})
	var opponents: Array = record.get("opponents", [])

	if opponents.is_empty():
		return 0.0

	# Calculate average opponent conference strength
	var total_strength := 0.0
	var valid_opponents := 0

	for opp_id in opponents:
		var opponent: Dictionary = college_index.get(opp_id, {})
		if opponent.is_empty():
			continue

		var opp_tier := String(opponent.get("conference_tier", "fcs"))
		var tier_strength := _get_tier_strength(opp_tier)

		total_strength += tier_strength
		valid_opponents += 1

	if valid_opponents == 0:
		return 0.0

	var avg_opponent_strength := total_strength / float(valid_opponents)

	# Normalize to 0.0-1.0 scale
	# power_5 = 1.0, group_5 = 0.5, fcs = 0.0
	return clamp(avg_opponent_strength, 0.0, 1.0)


## Calculate strength of schedule (alternative implementation using college_index)
##
## This version uses a college_index Dictionary for faster lookups
## Preferred for performance when calling multiple times
##
## RNG: None (pure calculation)
## Performance: O(opponents) per college
static func calculate_strength_of_schedule_indexed(
	college_id: String,
	season_results: Dictionary,
	college_index: Dictionary
) -> float:
	# Get this college's record to find opponents
	var record: Dictionary = season_results.get(college_id, {})
	var opponents: Array = record.get("opponents", [])

	if opponents.is_empty():
		return 0.0

	# Calculate average opponent conference strength
	var total_strength := 0.0
	var valid_opponents := 0

	for opp_id in opponents:
		var opponent: Dictionary = college_index.get(opp_id, {})
		if opponent.is_empty():
			continue

		var opp_tier := String(opponent.get("conference_tier", "fcs"))
		var tier_strength := _get_tier_strength(opp_tier)

		total_strength += tier_strength
		valid_opponents += 1

	if valid_opponents == 0:
		return 0.0

	var avg_opponent_strength := total_strength / float(valid_opponents)

	# Normalize to 0.0-1.0 scale
	return clamp(avg_opponent_strength, 0.0, 1.0)


## Get draft weight multiplier for a conference tier
##
## RNG: None (config lookup)
## Performance: O(1)
##
## Parameters:
##   conference_tier: String - "power_5", "group_5", or "fcs"
##   config: Dictionary - Configuration with tier weights
##
## Returns:
##   float: Multiplier to apply to draft grades (0.80 - 1.10)
static func get_conference_tier_multiplier(
	conference_tier: String,
	config: Dictionary
) -> float:
	var tier_weights: Dictionary = config.get("tier_weights", {})
	var tier_cfg: Dictionary = tier_weights.get(conference_tier, {})

	return float(tier_cfg.get("base_draft_multiplier", 1.0))


## Get conference data by ID
##
## RNG: None (lookup)
## Performance: O(1)
##
## Parameters:
##   conference_id: String - Conference identifier
##   conferences: Dictionary - Conference index from build_conference_index()
##
## Returns:
##   Dictionary: Conference data or empty dict if not found
static func get_conference(
	conference_id: String,
	conferences: Dictionary
) -> Dictionary:
	return conferences.get(conference_id, {})


# =========================
# Helper Functions
# =========================

## Calculate how well a college fits a conference
##
## RNG: None (pure calculation)
## Performance: O(1) per college-conference pair
##
## Factors:
##   - Region match (conference prefers certain regions)
##   - Eliteness match (conference has minimum eliteness requirement)
##   - Random noise for variety
##
## Returns:
##   float: Fit score (0.0-100.0), higher = better fit
static func _calculate_conference_fit(
	college: Dictionary,
	conference: Dictionary,
	config: Dictionary
) -> float:
	var college_region := String(college.get("region", ""))
	var college_eliteness := float(college.get("eliteness", 50.0))

	var preferred_regions: Array = conference.get("preferred_regions", [])
	var region_weight := float(conference.get("region_weight", 0.5))
	var min_eliteness := float(conference.get("min_eliteness", 0.0))

	var score := 0.0

	# Region match bonus
	if not preferred_regions.is_empty():
		if college_region in preferred_regions:
			score += region_weight * 50.0

	# Eliteness match
	if college_eliteness >= min_eliteness:
		# Bonus for exceeding minimum
		var eliteness_bonus := (college_eliteness - min_eliteness) / 10.0
		score += eliteness_bonus
	else:
		# Penalty for being below minimum
		var eliteness_penalty := (min_eliteness - college_eliteness)
		score -= eliteness_penalty

	# Base score for any match
	score += 25.0

	return max(score, 0.0)


## Get normalized strength value for a conference tier
##
## RNG: None (lookup)
## Performance: O(1)
##
## Returns:
##   float: Strength value (1.0 = power_5, 0.5 = group_5, 0.0 = fcs)
static func _get_tier_strength(tier: String) -> float:
	match tier:
		"power_5":
			return 1.0
		"group_5":
			return 0.5
		"fcs":
			return 0.0
		_:
			return 0.5  # Default to group_5 strength
