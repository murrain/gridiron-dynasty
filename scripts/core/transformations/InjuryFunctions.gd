extends RefCounted
class_name InjuryFunctions

## Pure functions for injury simulation.
## All functions are side-effect-free and deterministic.
##
## CRITICAL RNG MANAGEMENT:
## - All functions accept RNG as explicit parameter
## - RNG consumption patterns are documented per function
## - Same seed + same inputs = same outputs (guaranteed determinism)

const INJURY_SUPPRESSION_PER_SEVERITY := 0.25

# ============================================================================
# PUBLIC API - Pure Injury Functions
# ============================================================================

## Simulate injuries for a player for one year (pure function).
##
## RNG consumption pattern:
##   - 1 call: Injury occurrence roll (always)
##   - 3-4 additional calls if injured: type selection, severity, recovery, career-ending check
##   Total: 1-4 calls per invocation (deterministic for given seed)
##
## Algorithm:
##   1. Calculate injury risk based on proneness, position, and durability traits
##   2. Roll for injury occurrence
##   3. If injured, generate injury instance with type, severity, and recovery timeline
##   4. Return new player dict with injury appended (if occurred)
##
## Input: player dict (unchanged), configs dict, RNG instance
## Output: {player: Dictionary, report: Dictionary}
##
## Determinism guarantee:
##   - Same RNG state + same player = same injury outcome
##   - RNG calls occur in fixed order regardless of branching
static func simulate_injuries(
	player: Dictionary,
	configs: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var new_player := player.duplicate(true)
	var main_cfg := configs.get("main", {}) as Dictionary
	var cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary

	var base_chance := float(cfg.get("base_chance", 0.12))
	var proneness_slope := float(cfg.get("proneness_slope", 0.15))

	# Apply position multiplier
	var position := String(new_player.get("position", ""))
	var position_mults: Dictionary = cfg.get("position_multipliers", {}) as Dictionary
	var position_mult := float(position_mults.get(position, 1.0))

	# Apply durability trait modifiers
	var trait_mults: Dictionary = cfg.get("durability_trait_modifiers", {}) as Dictionary
	var trait_mult := 1.0
	var hidden_traits: Array = new_player.get("hidden_traits", []) as Array
	for i in range(hidden_traits.size()):
		var trait_name = hidden_traits[i]
		if trait_mults.has(trait_name):
			trait_mult *= float(trait_mults[trait_name])

	var stats: Dictionary = new_player.get("stats", {}) as Dictionary
	var proneness := float(stats.get("injury_proneness", 50.0))
	var chance := base_chance + ((proneness - 50.0) / 100.0) * proneness_slope
	chance *= position_mult * trait_mult
	chance = clamp(chance, 0.0, 0.95)

	# RNG Call 1: Injury occurrence roll
	var roll := rng.randf()
	var injured := roll < chance

	var report := {
		"base_chance": base_chance,
		"proneness": proneness,
		"proneness_slope": proneness_slope,
		"position_mult": position_mult,
		"trait_mult": trait_mult,
		"final_chance": chance,
		"roll": roll,
		"injured": injured
	}

	# Generate actual injury if roll succeeds
	if injured:
		# RNG Calls 2-5: Injury generation (type, severity, recovery, career-ending check)
		var injury: Variant = _generate_injury(new_player, cfg, rng)
		if injury != null:
			var injuries: Array = new_player.get("injuries", []) as Array
			injuries.append(injury)
			new_player["injuries"] = injuries
			report["injury"] = injury

	return {
		"player": new_player,
		"report": report
	}

## Apply a specific injury to a player (pure function).
##
## Creates a new injury instance and adds it to the player's injury list.
## Does NOT consume RNG - injury parameters are fully specified.
##
## Input: player dict, injury type string, severity float
## Output: new player dict with injury added
##
## Note: For procedurally generated injuries, use simulate_injuries() instead.
static func apply_injury(
	player: Dictionary,
	injury_type: String,
	severity: float
) -> Dictionary:
	var new_player := player.duplicate(true)
	var stats: Dictionary = new_player.get("stats", {}) as Dictionary

	# Build a minimal injury structure
	# For full injury generation with affected stats and recovery timeline,
	# caller should use simulate_injuries() or _generate_injury() directly
	var injury := {
		"type": injury_type,
		"severity": clamp(severity, 0.0, 5.0),
		"affected_stats": [],  # Caller should specify or use config lookup
		"recovery_timeline": {
			"years_total": 1,
			"years_remaining": 1,
			"status": "active"
		},
		"long_term_penalty": {
			"stat_caps": {},
			"decline_multipliers": {}
		},
		"career_ending": false
	}

	var injuries: Array = new_player.get("injuries", []) as Array
	injuries.append(injury)
	new_player["injuries"] = injuries

	return new_player

## Heal injuries by advancing recovery timeline (pure function).
##
## Reduces years_remaining for all active injuries by weeks_passed (converted to years).
## Updates injury status to "recovered" when years_remaining reaches 0.
##
## Input: player dict, weeks_passed (int, typically 16 for one season)
## Output: new player dict with updated injury timelines
##
## No RNG consumption - healing is deterministic based on time passage.
static func heal_injuries(
	player: Dictionary,
	weeks_passed: int
) -> Dictionary:
	var new_player := player.duplicate(true)
	var injuries: Array = new_player.get("injuries", []) as Array

	# Convert weeks to years (approximate: 16 weeks = 1 season)
	var years_passed := max(0, weeks_passed / 16)
	if years_passed == 0 and weeks_passed > 0:
		years_passed = 1  # At least advance by 1 year if any time passed

	var updated_injuries: Array = []
	for injury_entry in injuries:
		var injury: Dictionary = (injury_entry as Dictionary).duplicate(true)
		var timeline: Dictionary = injury.get("recovery_timeline", {}) as Dictionary

		if String(timeline.get("status", "active")) != "active":
			# Already recovered or inactive, keep as-is
			updated_injuries.append(injury)
			continue

		var years_remaining := int(timeline.get("years_remaining", 0))
		if years_remaining <= 0:
			# Already recovered
			timeline["status"] = "recovered"
			timeline["years_remaining"] = 0
			injury["recovery_timeline"] = timeline
			updated_injuries.append(injury)
			continue

		# Advance recovery
		years_remaining = max(0, years_remaining - years_passed)
		timeline["years_remaining"] = years_remaining

		if years_remaining == 0:
			timeline["status"] = "recovered"

		injury["recovery_timeline"] = timeline
		updated_injuries.append(injury)

	new_player["injuries"] = updated_injuries
	return new_player

## Calculate current injury risk for a player (pure function).
##
## Returns a probability value [0.0, 1.0] based on:
## - Base injury chance (from config)
## - Player's injury proneness stat
## - Position multiplier (high-contact positions more vulnerable)
## - Durability trait modifiers (injury_prone, durable, iron_man)
##
## Input: player dict, configs dict
## Output: float probability [0.0, 0.95] (capped at 95%)
##
## No RNG consumption - pure calculation.
static func _calculate_injury_risk(
	player: Dictionary,
	configs: Dictionary
) -> float:
	var main_cfg := configs.get("main", {}) as Dictionary
	var cfg: Dictionary = main_cfg.get("injury", {}) as Dictionary

	var base_chance := float(cfg.get("base_chance", 0.12))
	var proneness_slope := float(cfg.get("proneness_slope", 0.15))

	# Apply position multiplier
	var position := String(player.get("position", ""))
	var position_mults: Dictionary = cfg.get("position_multipliers", {}) as Dictionary
	var position_mult := float(position_mults.get(position, 1.0))

	# Apply durability trait modifiers
	var trait_mults: Dictionary = cfg.get("durability_trait_modifiers", {}) as Dictionary
	var trait_mult := 1.0
	var hidden_traits: Array = player.get("hidden_traits", []) as Array
	for i in range(hidden_traits.size()):
		var trait_name = hidden_traits[i]
		if trait_mults.has(trait_name):
			trait_mult *= float(trait_mults[trait_name])

	var stats: Dictionary = player.get("stats", {}) as Dictionary
	var proneness := float(stats.get("injury_proneness", 50.0))
	var chance := base_chance + ((proneness - 50.0) / 100.0) * proneness_slope
	chance *= position_mult * trait_mult
	chance = clamp(chance, 0.0, 0.95)

	return chance

# ============================================================================
# INTERNAL HELPERS - Private Pure Functions
# ============================================================================

## Generate a specific injury instance with type, severity, and recovery timeline (pure function).
##
## RNG consumption pattern:
##   - 1 call: Injury type selection (weighted random)
##   - 1 call: Severity value (randf_range)
##   - 1 call: Recovery years (randi_range)
##   - 1 call: Career-ending check (if applicable)
##   Total: 3-4 calls per injury generated
##
## Algorithm:
##   1. Select injury type via weighted randomness (sum all weights, roll, accumulate)
##   2. Generate severity within type's min/max range
##   3. Generate recovery timeline (years) within type's min/max range
##   4. Check for career-ending outcome (rare, only for types with career_ending_chance)
##   5. Build long-term penalty structure (stat caps and decline multipliers)
##
## Returns:
##   Dictionary with injury structure, or null if no types configured
##
## Determinism guarantee:
##   - Same RNG state produces identical injury type, severity, and timeline
##   - Weighted selection uses cumulative distribution for stability
static func _generate_injury(
	player: Dictionary,
	injury_cfg: Dictionary,
	rng: RandomNumberGenerator
) -> Variant:
	var injury_types: Array = injury_cfg.get("types", []) as Array
	if injury_types.is_empty():
		return null

	# RNG Call 1: Weighted random selection of injury type
	var total_weight := 0.0
	for injury_def in injury_types:
		total_weight += float((injury_def as Dictionary).get("weight", 0.0))

	var roll := rng.randf() * total_weight
	var accumulated := 0.0
	var selected_def: Dictionary = {}

	for injury_def in injury_types:
		var def: Dictionary = injury_def as Dictionary
		accumulated += float(def.get("weight", 0.0))
		if roll <= accumulated:
			selected_def = def
			break

	if selected_def.is_empty():
		return null

	# RNG Call 2: Generate severity within type's range
	var severity_min := float(selected_def.get("severity_min", 1.0))
	var severity_max := float(selected_def.get("severity_max", 2.0))
	var severity := rng.randf_range(severity_min, severity_max)

	# RNG Call 3: Generate recovery timeline within type's range
	var recovery_min := int(selected_def.get("recovery_years_min", 0))
	var recovery_max := int(selected_def.get("recovery_years_max", 1))
	var recovery_years := rng.randi_range(recovery_min, recovery_max)

	# RNG Call 4: Check for career-ending outcome (rare, only if type supports it)
	var career_ending_chance := float(selected_def.get("career_ending_chance", 0.0))
	var is_career_ending := false
	if career_ending_chance > 0.0:
		is_career_ending = rng.randf() < career_ending_chance

	# Build injury instance
	var injury := {
		"type": String(selected_def.get("type", "unknown")),
		"severity": severity,
		"affected_stats": (selected_def.get("affected_stats", []) as Array).duplicate(),
		"recovery_timeline": {
			"years_total": recovery_years,
			"years_remaining": recovery_years,
			"status": "active"
		},
		"long_term_penalty": {
			"stat_caps": {},
			"decline_multipliers": {}
		},
		"career_ending": is_career_ending
	}

	# Set long-term penalties for affected stats
	var long_term_cap := float(selected_def.get("long_term_cap", 1.0))
	var decline_mult := float(selected_def.get("long_term_decline_mult", 1.0))
	var stats: Dictionary = player.get("stats", {}) as Dictionary

	for stat_name in injury["affected_stats"]:
		if stats.has(stat_name):
			var current_val := float(stats[stat_name])
			(injury["long_term_penalty"]["stat_caps"] as Dictionary)[stat_name] = current_val * long_term_cap
			(injury["long_term_penalty"]["decline_multipliers"] as Dictionary)[stat_name] = decline_mult

	return injury
