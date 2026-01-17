extends RefCounted
class_name UnderclassmanDeclarationEngine

## Underclassman Declaration Engine
##
## Purpose: Evaluates which underclassmen declare early for the NFL draft based on
## their talent level and projected draft position.
##
## Key Features:
##   1. Talent-based declaration probability (elite prospects almost always declare)
##   2. Mock draft projection influence (first-round projections = 99% declare)
##   3. Deterministic RNG via explicit seeding
##   4. Target pool size of 50-100 underclassmen per year
##
## Declaration Probability Tiers:
##   - Elite prospects (75+ rating): 90% declare
##   - Good prospects (70-74 rating): 60% declare
##   - Marginal prospects (60-69 rating): 30% declare
##   - Below 60 rating: <10% declare
##   - First-round projections (mock draft 1-32): 99% declare (overrides talent tier)
##
## Design Principles:
##   - Stateless service with pure functions
##   - Explicit RNG passing for determinism
##   - Stable iteration order via player_id sorting
##   - Configuration-driven thresholds
##
## RNG Seed Pattern: base_seed ^ 0xUND3RC1A (underclass-ia)
##
## RNG Consumption Pattern:
##   - evaluate_declarations: 1 randf() call per eligible player (sorted by player_id)
##   - Total: N randf() calls where N = number of eligible underclassmen
##
## Integration Points:
##   - PreDraftProcess: Called during Phase 0.5 before combine selection
##   - MockDraftGenerator: Used for projected draft positions
##   - Player model: Sets declared_for_draft flag and stage transition

const Rand = preload("res://autoloads/Rand.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
const Player = preload("res://scripts/core/models/Player.gd")

## Magic number for underclassman declaration seed derivation
## Mnemonic: 0xUND3RC1A = "underclass-ia" (underclassman)
const UNDERCLASSMAN_SEED_MAGIC := 0xD3C1A000

## Declaration probability thresholds by rating tier
## These are the base probabilities before mock draft override
const DECLARATION_PROBABILITIES := {
	"elite": 0.90,      # 75+ rating
	"good": 0.60,       # 70-74 rating
	"marginal": 0.30,   # 60-69 rating
	"below": 0.08       # <60 rating
}

## Rating thresholds for declaration tiers
const RATING_THRESHOLDS := {
	"elite_min": 75.0,
	"good_min": 70.0,
	"marginal_min": 60.0
}

## First-round projection override (picks 1-32 have 99% declaration rate)
const FIRST_ROUND_PICK_MAX := 32
const FIRST_ROUND_DECLARATION_RATE := 0.99

## Minimum class year to be considered an underclassman for early entry
## class_year 1 = Freshman, 2 = Sophomore, 3 = Junior, 4 = Senior
## Underclassmen are class_year 1-3 (freshmen through juniors)
const MIN_UNDERCLASSMAN_YEAR := 1
const MAX_UNDERCLASSMAN_YEAR := 3


## Evaluate declarations for all eligible underclassmen.
##
## This is the primary entry point. Iterates through the draft pool in
## deterministic order (sorted by player_id), evaluates each eligible
## underclassman, and sets the declared_for_draft flag.
##
## Algorithm:
##   1. Filter to eligible underclassmen (class_year 1-3, not already declared)
##   2. Sort by player_id for deterministic iteration
##   3. For each player, calculate declaration probability
##   4. Roll RNG and set declared_for_draft flag if passes
##
## Side effects:
##   - Sets player["declared_for_draft"] = true for declaring players
##   - Sets player["stage"] = PlayerStage.DRAFT_ELIGIBLE for declaring players
##
## RNG consumption: 1 randf() call per eligible underclassman
##
## @param draft_pool: Array of Player dictionaries (mutated in place)
## @param mock_draft_ranks: Dictionary mapping player_id -> projected_pick (1-indexed)
## @param year: Draft year being processed
## @param seed: Base RNG seed for determinism
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules configuration for rating calculation
## @return Dictionary: {
##   "declaration_count": int,
##   "declared_player_ids": Array[String],
##   "modified_players": Array[Dictionary]  # Players with declared_for_draft=true
## }
static func evaluate_declarations(
	draft_pool: Array,
	mock_draft_ranks: Dictionary,
	year: int,
	seed: int,
	positions_cfg: Dictionary = {},
	class_rules: Dictionary = {}
) -> Dictionary:
	if draft_pool.is_empty():
		return {
			"declaration_count": 0,
			"declared_player_ids": [],
			"modified_players": []
		}

	# Initialize RNG with underclassman-specific seed
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ UNDERCLASSMAN_SEED_MAGIC)

	# Filter to eligible underclassmen
	var eligible := _get_eligible_underclassmen(draft_pool)

	if eligible.is_empty():
		return {
			"declaration_count": 0,
			"declared_player_ids": [],
			"modified_players": []
		}

	# Sort by player_id for deterministic iteration order
	# RNG: No RNG calls in sorting (pure comparison)
	eligible.sort_custom(func(a, b):
		var a_id := _get_player_id(a as Dictionary)
		var b_id := _get_player_id(b as Dictionary)
		return a_id < b_id
	)

	var declaration_count := 0
	var declared_player_ids: Array[String] = []
	var modified_players: Array = []

	# Evaluate each eligible player
	# RNG: 1 randf() call per player
	for player in eligible:
		var p: Dictionary = player
		var player_id := _get_player_id(p)

		# Get mock draft projection (if available)
		var mock_rank := int(mock_draft_ranks.get(player_id, 999))

		# Calculate declaration probability
		var declaration_prob := _calculate_declaration_probability(
			p, mock_rank, positions_cfg, class_rules
		)

		# Roll for declaration (RNG CALL)
		var roll := rng.randf()
		if roll < declaration_prob:
			# Player declares for draft
			p["declared_for_draft"] = true

			# Transition stage to DRAFT_ELIGIBLE
			p["stage"] = Player.PlayerStage.DRAFT_ELIGIBLE

			declaration_count += 1
			declared_player_ids.append(player_id)
			modified_players.append(p)

	return {
		"declaration_count": declaration_count,
		"declared_player_ids": declared_player_ids,
		"modified_players": modified_players
	}


## Get list of eligible underclassmen from draft pool.
##
## Eligibility criteria:
##   - class_year between 1-3 (freshman through junior)
##   - Not already declared (declared_for_draft == false)
##   - Currently in college (stage == COLLEGE)
##
## RNG: None (pure filter)
##
## @param draft_pool: Array of Player dictionaries
## @return Array: Eligible underclassmen
static func _get_eligible_underclassmen(draft_pool: Array) -> Array:
	var eligible: Array = []

	for player in draft_pool:
		var p: Dictionary = player

		# Check class year (1-3 for underclassmen)
		var class_year := int(p.get("class_year", 4))
		if class_year < MIN_UNDERCLASSMAN_YEAR or class_year > MAX_UNDERCLASSMAN_YEAR:
			continue

		# Check not already declared
		if bool(p.get("declared_for_draft", false)):
			continue

		# Check currently in college
		var stage := int(p.get("stage", Player.PlayerStage.COLLEGE))
		if stage != Player.PlayerStage.COLLEGE:
			continue

		eligible.append(p)

	return eligible


## Calculate declaration probability for a player.
##
## Probability is determined by:
##   1. First-round mock draft projection (overrides everything)
##   2. Rating-based tier (elite/good/marginal/below)
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param mock_rank: Projected draft pick (1-indexed, 999 = unranked)
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @return float: Declaration probability (0.0 - 1.0)
static func _calculate_declaration_probability(
	player: Dictionary,
	mock_rank: int,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	# First-round projections have 99% declaration rate
	if mock_rank >= 1 and mock_rank <= FIRST_ROUND_PICK_MAX:
		return FIRST_ROUND_DECLARATION_RATE

	# Calculate overall rating
	var rating := PlayerRatingCalculator.calculate_overall_rating(
		player, positions_cfg, class_rules
	)

	# Determine tier based on rating
	if rating >= RATING_THRESHOLDS["elite_min"]:
		return DECLARATION_PROBABILITIES["elite"]  # 90%
	elif rating >= RATING_THRESHOLDS["good_min"]:
		return DECLARATION_PROBABILITIES["good"]   # 60%
	elif rating >= RATING_THRESHOLDS["marginal_min"]:
		return DECLARATION_PROBABILITIES["marginal"]  # 30%
	else:
		return DECLARATION_PROBABILITIES["below"]  # 8%


## Get player ID from dictionary (handles both "player_id" and "id" keys).
##
## RNG: None (pure lookup)
##
## @param player: Player dictionary
## @return String: Player ID
static func _get_player_id(player: Dictionary) -> String:
	if player.has("player_id"):
		return String(player.get("player_id", ""))
	return String(player.get("id", ""))


## Calculate rating for a player (convenience wrapper).
##
## RNG: None (pure calculation)
##
## @param player: Player dictionary
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @return float: Player overall rating
static func get_player_rating(
	player: Dictionary,
	positions_cfg: Dictionary = {},
	class_rules: Dictionary = {}
) -> float:
	return PlayerRatingCalculator.calculate_overall_rating(
		player, positions_cfg, class_rules
	)


## Get declaration probability tier name for a rating.
##
## Useful for debugging and testing.
##
## RNG: None (pure calculation)
##
## @param rating: Player overall rating
## @return String: Tier name ("elite", "good", "marginal", "below")
static func get_tier_for_rating(rating: float) -> String:
	if rating >= RATING_THRESHOLDS["elite_min"]:
		return "elite"
	elif rating >= RATING_THRESHOLDS["good_min"]:
		return "good"
	elif rating >= RATING_THRESHOLDS["marginal_min"]:
		return "marginal"
	else:
		return "below"


## Get expected declaration count for a pool (statistical estimate).
##
## Calculates expected value based on rating distribution.
## Useful for validating pool sizes in tests.
##
## RNG: None (pure calculation)
##
## @param draft_pool: Array of Player dictionaries
## @param mock_draft_ranks: Dictionary mapping player_id -> projected_pick
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @return float: Expected number of declarations
static func estimate_declaration_count(
	draft_pool: Array,
	mock_draft_ranks: Dictionary,
	positions_cfg: Dictionary = {},
	class_rules: Dictionary = {}
) -> float:
	var eligible := _get_eligible_underclassmen(draft_pool)
	var expected := 0.0

	for player in eligible:
		var p: Dictionary = player
		var player_id := _get_player_id(p)
		var mock_rank := int(mock_draft_ranks.get(player_id, 999))
		var prob := _calculate_declaration_probability(p, mock_rank, positions_cfg, class_rules)
		expected += prob

	return expected


## Build mock draft ranks dictionary from draft pool.
##
## Generates simple mock rankings based on player ratings.
## This is a simplified version for testing; in production use MockDraftGenerator.
##
## RNG: None (deterministic based on ratings)
##
## @param draft_pool: Array of Player dictionaries
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @return Dictionary: {player_id: projected_pick}
static func build_simple_mock_ranks(
	draft_pool: Array,
	positions_cfg: Dictionary = {},
	class_rules: Dictionary = {}
) -> Dictionary:
	# Rate all players
	var rated: Array = []
	for player in draft_pool:
		var p: Dictionary = player
		var player_id := _get_player_id(p)
		var rating := PlayerRatingCalculator.calculate_overall_rating(p, positions_cfg, class_rules)
		rated.append({"id": player_id, "rating": rating})

	# Sort by rating descending
	rated.sort_custom(func(a, b):
		var a_rating := float(a.get("rating", 0.0))
		var b_rating := float(b.get("rating", 0.0))
		if abs(a_rating - b_rating) < 0.001:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return a_rating > b_rating
	)

	# Assign picks
	var ranks := {}
	for i in range(rated.size()):
		var entry: Dictionary = rated[i]
		ranks[String(entry.get("id", ""))] = i + 1

	return ranks
