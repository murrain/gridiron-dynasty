extends RefCounted
class_name MockDraftGenerator

## Mock Draft Generator - Evolving Consensus Projections
##
## Generates 7 versions of mock drafts over time, simulating how draft consensus
## evolves as more information becomes available. Early mocks have more variance,
## later mocks converge toward actual talent.
##
## Mock Versions (time before draft):
## 1. 3 months out (high variance, sigma=15)
## 2. 1 month out (sigma~12.5)
## 3. 2 weeks out (sigma~10)
## 4. 1 week out (sigma~7.5)
## 5. 3 days out (sigma~5)
## 6. 1 day out (sigma~3.75)
## 7. Hours before (low variance, sigma=2.5)
##
## Design:
##   - Stateless RefCounted service
##   - Deterministic via explicit RNG seeding: seed ^ 0xMOCK0000 + version
##   - Pre-computes team boards ONCE for all 7 versions (key optimization)
##   - Uses simplified draft simulation (no full scouting)
##
## Performance:
##   - Target: <500ms for all 7 versions combined
##   - Strategy: Pre-compute base ratings once, apply version-specific noise
##
## Integration:
##   - Called by PreDraftProcess during draft_prep phase
##   - Stores mock history in player["draft_intelligence"]["mock_history"]
##   - Used by UI to show draft projection evolution
##
## RNG Consumption Pattern:
##   - generate_all_mocks:
##     - 7 calls to generate_mock (one per version)
##   - generate_mock:
##     - 1 RNG init per version (deterministic via seed ^ 0xMOCK0000 + version)
##     - N randfn calls where N = draft_pool size (for noise application)

const Rand = preload("res://autoloads/Rand.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Magic number for mock draft seed derivation
## Combined with version number for deterministic generation
const MOCK_SEED_MAGIC := 0xD1AF7100

## Variance configuration: maps version to noise sigma
## Version 1 = 3 months out (high variance)
## Version 7 = hours before (low variance)
const VERSION_SIGMA := {
	1: 15.0,   # 3 months out - high uncertainty
	2: 12.5,   # 1 month out
	3: 10.0,   # 2 weeks out
	4: 7.5,    # 1 week out
	5: 5.0,    # 3 days out
	6: 3.75,   # 1 day out
	7: 2.5     # hours before - low uncertainty
}

## Projection range variance: how much uncertainty to show in range
## Earlier versions have wider ranges
const VERSION_RANGE_VARIANCE := {
	1: 10,
	2: 8,
	3: 6,
	4: 5,
	5: 4,
	6: 3,
	7: 2
}


## Generate all 7 mock versions and store in player data.
##
## This is the primary entry point. Optimized for performance by:
## 1. Computing base ratings once for all players
## 2. Generating all versions in a single pass through the pool
##
## Side effects:
##   - Adds "mock_history" array to player["draft_intelligence"]
##   - Each entry: {version, projected_pick, range_low, range_high, generated_week}
##
## RNG consumption:
##   - 7 independent RNG instances (one per version)
##   - Each version: N randfn calls (N = pool size)
##
## @param draft_pool: Array of draft-eligible players (mutated in place)
## @param teams: Array of NFL teams for pick count
## @param year: Draft year
## @param seed: Base seed for determinism
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules configuration
static func generate_all_mocks(
	draft_pool: Array,
	teams: Array,
	year: int,
	seed: int,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> void:
	if draft_pool.is_empty():
		return

	var total_picks := teams.size()  # 1 pick per team per round in round 1

	# OPTIMIZATION: Pre-compute base ratings for all players once
	# This avoids recalculating ratings 7 times per player
	var player_base_ratings: Array = []
	for player in draft_pool:
		var p: Dictionary = player
		var rating := PlayerRatingCalculator.calculate_overall_rating(
			p, positions_cfg, class_rules
		)
		var player_id := String(p.get("player_id", p.get("id", "")))
		player_base_ratings.append({
			"player": p,
			"player_id": player_id,
			"base_rating": rating
		})

	# Initialize draft_intelligence for all players
	for player in draft_pool:
		var p: Dictionary = player
		if not p.has("draft_intelligence"):
			p["draft_intelligence"] = {}
		var di: Dictionary = p["draft_intelligence"]
		if not di.has("mock_history"):
			di["mock_history"] = []

	# Generate all 7 versions
	for version in range(1, 8):
		_generate_single_version(
			player_base_ratings,
			total_picks,
			version,
			year,
			seed
		)


## Generate a single mock version with appropriate noise.
##
## Uses pre-computed base ratings and applies version-specific Gaussian noise
## to simulate evolving consensus.
##
## RNG consumption:
##   - 1 rng.seed initialization
##   - N randfn calls (N = pool size)
##
## @param player_base_ratings: Array of {player, player_id, base_rating}
## @param total_picks: Number of picks in round 1
## @param version: Mock version (1-7)
## @param year: Draft year
## @param seed: Base seed
static func _generate_single_version(
	player_base_ratings: Array,
	total_picks: int,
	version: int,
	year: int,
	seed: int
) -> void:
	# Initialize RNG with version-specific seed
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ (MOCK_SEED_MAGIC + version))

	# Get variance for this version
	var sigma: float = VERSION_SIGMA.get(version, 10.0)
	var range_variance: int = VERSION_RANGE_VARIANCE.get(version, 5)

	# Apply noise to all players and create mock ratings
	# RNG: 1 randfn call per player
	var mock_ratings: Array = []
	for entry in player_base_ratings:
		var e: Dictionary = entry
		var base_rating: float = e.get("base_rating", 50.0)

		# Apply Gaussian noise based on version variance
		var noise := rng.randfn(0.0, sigma)
		var mock_rating := base_rating + noise

		mock_ratings.append({
			"player": e.get("player"),
			"player_id": String(e.get("player_id", "")),
			"mock_rating": mock_rating,
			"base_rating": base_rating
		})

	# Sort by mock rating (descending) to determine pick order
	mock_ratings.sort_custom(func(a, b):
		var a_rating := float(a.get("mock_rating", 0.0))
		var b_rating := float(b.get("mock_rating", 0.0))
		if abs(a_rating - b_rating) < 0.001:
			# Tiebreaker: player_id for stability
			return String(a.get("player_id", "")) < String(b.get("player_id", ""))
		return a_rating > b_rating
	)

	# Assign projected picks and store in player data
	for i in range(mock_ratings.size()):
		var entry: Dictionary = mock_ratings[i]
		var player: Dictionary = entry.get("player", {})
		var projected_pick := i + 1  # 1-indexed pick number

		# Calculate projection range
		var range_low: int = max(1, projected_pick - range_variance)
		var range_high := projected_pick + range_variance

		# Store projection in player's mock history
		var di: Dictionary = player.get("draft_intelligence", {})
		var mock_history: Array = di.get("mock_history", [])

		mock_history.append({
			"version": version,
			"projected_pick": projected_pick,
			"range_low": range_low,
			"range_high": range_high,
			"generated_week": 7  # Draft prep week
		})


## Generate single mock draft version (public API for testing/UI).
##
## Simulates a mock draft at a specific point in time with appropriate variance.
## Earlier mocks have higher noise, later mocks more accurate.
##
## RNG consumption:
##   - 1 rng.seed initialization
##   - N randfn calls (N = draft_pool size)
##
## @param draft_pool: Array of draft-eligible players
## @param teams: Array of NFL teams
## @param version: Mock version 1-7
## @param year: Draft year
## @param seed: Base seed for determinism
## @param positions_cfg: Position configuration
## @param class_rules: Class rules configuration
## @return Dictionary: Mock draft results with picks array
static func generate_mock(
	draft_pool: Array,
	teams: Array,
	version: int,
	year: int,
	seed: int,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> Dictionary:
	if draft_pool.is_empty():
		return {
			"version": version,
			"generated_week": 7,
			"picks": [],
			"consensus_rankings": [],
			"noise_sigma": VERSION_SIGMA.get(version, 10.0)
		}

	# Initialize RNG for this mock version
	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(seed ^ (MOCK_SEED_MAGIC + version))

	# Get variance for this version
	var sigma: float = VERSION_SIGMA.get(version, 10.0)

	# Rate all players with noise applied
	# RNG: 1 randfn call per player
	var rated_players: Array = []
	for player in draft_pool:
		var p: Dictionary = player

		var base_rating := PlayerRatingCalculator.calculate_overall_rating(
			p, positions_cfg, class_rules
		)

		# Apply Gaussian noise to simulate uncertainty
		var noise := rng.randfn(0.0, sigma)
		var mock_rating := base_rating + noise

		rated_players.append({
			"player": p,
			"mock_rating": mock_rating,
			"true_rating": base_rating
		})

	# Sort by mock rating (descending)
	rated_players.sort_custom(func(a, b):
		var a_rating := float(a.get("mock_rating", 0.0))
		var b_rating := float(b.get("mock_rating", 0.0))
		if abs(a_rating - b_rating) < 0.001:
			var a_player: Dictionary = a.get("player", {})
			var b_player: Dictionary = b.get("player", {})
			return String(a_player.get("player_id", a_player.get("id", ""))) < String(b_player.get("player_id", b_player.get("id", "")))
		return a_rating > b_rating
	)

	# Simulate draft picks (simplified - round robin through teams)
	var picks: Array = []
	var pick_num := 1
	var team_count := teams.size()

	for i in range(min(rated_players.size(), team_count)):
		var selected: Dictionary = rated_players[i]
		var player: Dictionary = selected.get("player", {})
		var team: Dictionary = teams[i % team_count]

		picks.append({
			"pick": pick_num,
			"team_id": String(team.get("id", "")),
			"player_id": String(player.get("player_id", player.get("id", ""))),
			"mock_rating": float(selected.get("mock_rating", 0.0))
		})

		pick_num += 1

	# Build consensus rankings (player IDs in order)
	var consensus_rankings: Array = []
	for pick in picks:
		var p: Dictionary = pick
		consensus_rankings.append(String(p.get("player_id", "")))

	return {
		"version": version,
		"generated_week": 7,
		"picks": picks,
		"consensus_rankings": consensus_rankings,
		"noise_sigma": sigma
	}


## Get latest mock projection for player.
##
## Returns the most recent (version 7) projection from the player's mock history.
##
## @param player: Player dictionary with draft_intelligence
## @return Dictionary: Latest projection or empty dict if none
static func get_latest_projection(player: Dictionary) -> Dictionary:
	var di: Dictionary = player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	if mock_history.is_empty():
		return {}

	# Return last entry (should be version 7)
	return mock_history[mock_history.size() - 1] as Dictionary


## Get projection for specific version.
##
## @param player: Player dictionary with draft_intelligence
## @param version: Mock version (1-7)
## @return Dictionary: Projection for version or empty dict
static func get_projection_for_version(player: Dictionary, version: int) -> Dictionary:
	var di: Dictionary = player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	for entry in mock_history:
		var e: Dictionary = entry
		if int(e.get("version", 0)) == version:
			return e

	return {}


## Get projection evolution (all versions) for player.
##
## Returns array showing how projection changed over time.
##
## @param player: Player dictionary
## @return Array: All projections in version order
static func get_projection_evolution(player: Dictionary) -> Array:
	var di: Dictionary = player.get("draft_intelligence", {})
	return di.get("mock_history", [])


## Calculate mock accuracy post-draft.
##
## Compares final mock (version 7) projections to actual draft results.
## Used for analytics and tuning mock variance parameters.
##
## @param draft_pool: Array of players with actual draft_info results
## @return Dictionary: Accuracy metrics (average_error, players_evaluated)
static func calculate_mock_accuracy(draft_pool: Array) -> Dictionary:
	var total_error := 0.0
	var count := 0
	var within_5_picks := 0
	var within_10_picks := 0

	for player in draft_pool:
		var p: Dictionary = player
		var draft_info: Dictionary = p.get("draft_info", {})
		var actual_pick := int(draft_info.get("pick", 0))

		if actual_pick == 0:
			continue  # Player not drafted

		var final_mock := get_latest_projection(p)
		var projected_pick := int(final_mock.get("projected_pick", 0))

		if projected_pick == 0:
			continue  # Player not in mock

		var error: int = abs(actual_pick - projected_pick)
		total_error += float(error)
		count += 1

		if error <= 5:
			within_5_picks += 1
		if error <= 10:
			within_10_picks += 1

	var avg_error := total_error / float(count) if count > 0 else 0.0

	return {
		"average_error": avg_error,
		"players_evaluated": count,
		"within_5_picks": within_5_picks,
		"within_10_picks": within_10_picks,
		"accuracy_5_pct": float(within_5_picks) / float(count) * 100.0 if count > 0 else 0.0,
		"accuracy_10_pct": float(within_10_picks) / float(count) * 100.0 if count > 0 else 0.0
	}


## Calculate consensus ranking for a player.
##
## Returns the average projected pick across all mock versions.
##
## @param player: Player dictionary
## @return float: Average projected pick or 999.0 if no projections
static func get_consensus_ranking(player: Dictionary) -> float:
	var di: Dictionary = player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	if mock_history.is_empty():
		return 999.0

	var sum := 0.0
	for entry in mock_history:
		var e: Dictionary = entry
		sum += float(e.get("projected_pick", 999))

	return sum / float(mock_history.size())


## Get variance in projections (stock volatility).
##
## High variance means projection changed a lot over time (stock riser/faller).
## Low variance means consistent projection.
##
## @param player: Player dictionary
## @return float: Standard deviation of projected picks
static func get_projection_variance(player: Dictionary) -> float:
	var di: Dictionary = player.get("draft_intelligence", {})
	var mock_history: Array = di.get("mock_history", [])

	if mock_history.size() < 2:
		return 0.0

	# Calculate mean
	var sum := 0.0
	for entry in mock_history:
		var e: Dictionary = entry
		sum += float(e.get("projected_pick", 0))
	var mean := sum / float(mock_history.size())

	# Calculate variance
	var sq_diff_sum := 0.0
	for entry in mock_history:
		var e: Dictionary = entry
		var diff := float(e.get("projected_pick", 0)) - mean
		sq_diff_sum += diff * diff

	var variance := sq_diff_sum / float(mock_history.size())
	return sqrt(variance)


## Identify risers and fallers between versions.
##
## Returns players whose projection changed significantly between two versions.
##
## @param draft_pool: Array of players with mock history
## @param from_version: Earlier version (1-7)
## @param to_version: Later version (1-7)
## @param threshold: Minimum pick change to report (default 10)
## @return Dictionary: {risers: Array, fallers: Array}
static func get_risers_and_fallers(
	draft_pool: Array,
	from_version: int,
	to_version: int,
	threshold: int = 10
) -> Dictionary:
	var risers: Array = []
	var fallers: Array = []

	for player in draft_pool:
		var p: Dictionary = player
		var from_proj := get_projection_for_version(p, from_version)
		var to_proj := get_projection_for_version(p, to_version)

		if from_proj.is_empty() or to_proj.is_empty():
			continue

		var from_pick := int(from_proj.get("projected_pick", 999))
		var to_pick := int(to_proj.get("projected_pick", 999))
		var change := from_pick - to_pick  # Positive = rose, Negative = fell

		if change >= threshold:
			risers.append({
				"player": p,
				"player_id": String(p.get("player_id", p.get("id", ""))),
				"from_pick": from_pick,
				"to_pick": to_pick,
				"change": change
			})
		elif change <= -threshold:
			fallers.append({
				"player": p,
				"player_id": String(p.get("player_id", p.get("id", ""))),
				"from_pick": from_pick,
				"to_pick": to_pick,
				"change": change
			})

	# Sort by magnitude of change
	risers.sort_custom(func(a, b):
		return int(a.get("change", 0)) > int(b.get("change", 0))
	)
	fallers.sort_custom(func(a, b):
		return int(a.get("change", 0)) < int(b.get("change", 0))
	)

	return {
		"risers": risers,
		"fallers": fallers
	}
