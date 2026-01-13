extends RefCounted
class_name HighSchoolBackground

## High School Background Generation System
##
## Replaces the complex 420-school HS simulation with lightweight one-time generation.
## Instead of tracking individual schools and simulating seasons, we generate:
## - Region (south, midwest, west, northeast)
## - Program tier (elite, good, avg, low)
## - Star rating (2-5 stars based on potential)
## - Development modifier (from program tier)
## - Initial hype
##
## RNG Usage: 6-8 randf_range() calls per player (region, tier, stars, hype generation)

## Regional distribution weights (based on HS football hotbeds)
const REGION_WEIGHTS := {
	"south": 0.34,      # Texas, Florida, Georgia, etc.
	"midwest": 0.22,    # Ohio, Pennsylvania, Michigan
	"west": 0.18,       # California, Arizona
	"northeast": 0.26   # Remaining states
}

## Program tier distribution (correlates slightly with player potential)
const BASE_TIER_WEIGHTS := {
	"elite": 0.08,      # Top programs (IMG, Mater Dei, etc.)
	"good": 0.25,       # Strong programs
	"avg": 0.50,        # Average programs
	"low": 0.17         # Weak programs
}

## Development modifiers by program tier
const TIER_DEV_MODIFIERS := {
	"elite": 1.08,      # 8% boost
	"good": 1.03,       # 3% boost
	"avg": 1.00,        # Neutral
	"low": 0.95         # 5% penalty
}

## School media market tiers (for hype generation)
const TIER_MEDIA_MARKET := {
	"elite": 0.9,       # High media exposure
	"good": 0.6,        # Moderate exposure
	"avg": 0.3,         # Low exposure
	"low": 0.1          # Minimal exposure
}

## Generate complete high school background for a player
##
## This is the main entry point - call once when player enters HS.
## Generates all HS-related attributes in a single pass.
##
## RNG consumption: 6-8 randf_range() calls
##   - 1 for region selection
##   - 1 for tier selection
##   - 1 for star rating calculation
##   - 4 for initial hype generation (from HypeGenerator)
##
## Parameters:
##   player: Player dictionary (must have position and potential data)
##   rng: RandomNumberGenerator instance
##
## Returns: Dictionary with HS background fields
static func generate_hs_background(player: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# Step 1: Assign geographic region
	var region := _weighted_pick_region(rng)

	# Step 2: Assign program tier (slightly correlated with potential)
	var potential_overall := _get_player_rating(player)
	var program_tier := _assign_program_tier(potential_overall, rng)

	# Step 3: Calculate star rating (potential + tier visibility + noise)
	var star_rating := _calculate_star_rating(potential_overall, program_tier, rng)

	# Step 4: Get development modifier from tier
	var dev_modifier: float = TIER_DEV_MODIFIERS.get(program_tier, 1.0)

	# Step 5: Generate initial hype
	var position := String(player.get("position", ""))
	var school_media_tier: float = TIER_MEDIA_MARKET.get(program_tier, 0.3)

	const HypeGenerator = preload("res://scripts/generation/HypeGenerator.gd")
	var initial_hype := HypeGenerator.generate_initial_hype(
		player,
		star_rating,
		region,
		school_media_tier,
		rng
	)

	return {
		"hs_region": region,
		"hs_program_tier": program_tier,
		"recruiting_star_rating": star_rating,
		"development_modifier": dev_modifier,
		"initial_hype": initial_hype
	}

## Get player's rating for star calculation
##
## Prefers composite_score (actual calculated rating) when available,
## falls back to potential estimate for early-stage players.
##
## Parameters:
##   player: Player dictionary
##
## Returns: Rating value (float) - higher = better prospect
static func _get_player_rating(player: Dictionary) -> float:
	# Priority 1: Use composite_score if available (most accurate)
	if player.has("composite_score"):
		var score := float(player.get("composite_score", 0.0))
		if score > 0.0:
			return score

	# Priority 2: Check ratings dict for composite_score
	var ratings: Dictionary = player.get("ratings", {}) as Dictionary
	if ratings.has("composite_score"):
		var score := float(ratings.get("composite_score", 0.0))
		if score > 0.0:
			return score

	# Priority 3: Use pre-calculated potential rating
	if player.has("potential_overall"):
		return float(player.get("potential_overall", 50.0))

	# Priority 4: Estimate from potential stats
	var potential: Dictionary = player.get("potential", {}) as Dictionary
	if potential.is_empty():
		return 50.0  # Neutral fallback

	# Simple average of potential stats
	var sum := 0.0
	var count := 0
	for stat_value in potential.values():
		if stat_value is float or stat_value is int:
			sum += float(stat_value)
			count += 1

	if count > 0:
		return sum / float(count)
	else:
		return 50.0

## Weighted pick for region
##
## RNG consumption: 1 randf() call
static func _weighted_pick_region(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	var cumulative := 0.0

	for region in ["south", "midwest", "west", "northeast"]:
		cumulative += REGION_WEIGHTS.get(region, 0.0)
		if roll <= cumulative:
			return region

	return "south"  # Fallback

## Assign program tier based on player potential
##
## Higher potential players are more likely to attend elite programs.
## RNG consumption: 1 randf() call
static func _assign_program_tier(potential_overall: float, rng: RandomNumberGenerator) -> String:
	# Adjust weights based on potential
	var potential_factor := potential_overall / 100.0  # 0.0-1.0

	# High potential → more likely to be at elite/good programs
	var adjusted_weights := {
		"elite": BASE_TIER_WEIGHTS["elite"] * (1.0 + potential_factor * 0.5),
		"good": BASE_TIER_WEIGHTS["good"] * (1.0 + potential_factor * 0.3),
		"avg": BASE_TIER_WEIGHTS["avg"] * (1.0 - potential_factor * 0.2),
		"low": BASE_TIER_WEIGHTS["low"] * (1.0 - potential_factor * 0.4)
	}

	# Normalize weights
	var total := 0.0
	for weight in adjusted_weights.values():
		total += weight

	for tier in adjusted_weights.keys():
		adjusted_weights[tier] /= total

	# Weighted pick
	var roll := rng.randf()
	var cumulative := 0.0

	for tier in ["elite", "good", "avg", "low"]:
		cumulative += adjusted_weights.get(tier, 0.0)
		if roll <= cumulative:
			return tier

	return "avg"  # Fallback

## Calculate recruiting star rating (2-5 stars)
##
## Based on potential + program visibility + noise
## RNG consumption: 1 randf_range() call
static func _calculate_star_rating(
	potential_overall: float,
	program_tier: String,
	rng: RandomNumberGenerator
) -> int:
	var base_potential := potential_overall

	# Program tier affects visibility (elite programs get more scouts)
	var visibility_bonus := 0.0
	match program_tier:
		"elite":
			visibility_bonus = 8.0
		"good":
			visibility_bonus = 3.0
		"avg":
			visibility_bonus = 0.0
		"low":
			visibility_bonus = -5.0

	# Random noise in evaluation
	var noise := rng.randf_range(-10.0, 10.0)

	var effective_rating := base_potential + visibility_bonus + noise

	# Convert to stars (2-5 range)
	if effective_rating >= 88.0:
		return 5  # Elite prospect
	elif effective_rating >= 78.0:
		return 4  # High-level prospect
	elif effective_rating >= 65.0:
		return 3  # Solid prospect
	else:
		return 2  # Minimum for college prospects

## Apply HS development to player stats
##
## Called when player graduates HS and enters college.
## Applies cumulative development effect based on program tier.
##
## RNG consumption: None (deterministic application of development)
##
## Parameters:
##   player: Player dictionary (will be modified in place)
##   years: Number of years at HS (typically 4)
##
## Returns: void (modifies player in place)
static func apply_hs_development(player: Dictionary, years: int = 4) -> void:
	var dev_modifier := float(player.get("development_modifier", 1.0))
	var player_stats: Dictionary = player.get("stats", {}) as Dictionary
	var player_potential: Dictionary = player.get("potential", {}) as Dictionary

	if player_stats.is_empty():
		return  # No stats to develop

	# Apply development to each stat
	for stat_name in player_stats.keys():
		var current_value := float(player_stats.get(stat_name, 50.0))
		var potential_value := float(player_potential.get(stat_name, current_value))

		# Calculate growth: base growth per year * modifier * years
		var base_growth_per_year := (potential_value - current_value) * 0.15  # 15% of gap per year
		var total_growth := base_growth_per_year * float(years) * dev_modifier

		# Apply growth, capped at potential
		var new_value := minf(current_value + total_growth, potential_value)
		player_stats[stat_name] = new_value

	player["stats"] = player_stats
