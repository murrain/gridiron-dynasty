extends RefCounted
class_name TeamNeeds

## Team Needs Assessment System
##
## Analyzes roster composition and depth chart to identify positional needs.
## Used by AI drafting (Team 4), free agency, and roster management systems.
##
## All methods are static and stateless - pure analysis functions.
## No RNG usage, no side effects, deterministic output.

const StatGenerator = preload("res://scripts/core/game_simulation/StatGenerator.gd")

## Priority thresholds for need severity
const PRIORITY_CRITICAL := 0.9   # No starter or severe lack of depth
const PRIORITY_HIGH := 0.7       # Weak starter or insufficient depth
const PRIORITY_MEDIUM := 0.5     # Average starter but no depth
const PRIORITY_LOW := 0.3        # Adequate starter and some depth

## Priority calculation weights
const PRIORITY_WEIGHT_STARTER := 0.6   # Weight for starter quality in priority calculation
const PRIORITY_WEIGHT_DEPTH := 0.4     # Weight for depth quality in priority calculation

## Depth evaluation constants
const DEPTH_MIN_BACKUP_COUNT := 1      # Minimum number of backups per position
const DEPTH_IDEAL_BACKUP_COUNT := 3.0  # Ideal number of backups for full depth score
const DEPTH_WEIGHT_COUNT := 0.5        # Weight for backup count in depth quality
const DEPTH_WEIGHT_QUALITY := 0.5      # Weight for backup rating in depth quality

## Age thresholds for future need assessment (reserved for future use)
const AGE_THRESHOLD_AGING := 30   # Age at which players begin decline
const AGE_THRESHOLD_OLD := 33     # Age at which players are considered old

## Assess team needs based on roster composition and depth chart
##
## Algorithm:
##   1. For each position, evaluate starter quality (via depth chart or ratings)
##   2. Evaluate depth (number of backups, their quality)
##   3. Calculate priority score (0.0-1.0, higher = more urgent need)
##   4. Return dictionary mapping position -> priority
##
## Parameters:
##   roster: Roster resource with entries and depth_chart
##   positions_cfg: Position configuration
##   main_cfg: Main configuration
##
## Returns:
##   Dictionary: { position: String -> priority: float }
##   Priority ranges: 0.0 (no need) to 1.0 (critical need)
static func assess_team_needs(
	roster: Roster,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> Dictionary:
	var needs := {}

	# Get all positions from thresholds (standard positions)
	var positions := StatGenerator.STARTER_POSITION_THRESHOLDS.keys()

	# Get active players only (exclude practice squad, IR, suspended)
	var active_players := roster.get_players_by_status(Roster.RosterStatus.ACTIVE)

	# Build position -> players mapping
	var players_by_position := _group_by_position(active_players)

	for position in positions:
		var required_starters := int(StatGenerator.STARTER_POSITION_THRESHOLDS.get(position, 1))
		var position_players: Array = players_by_position.get(position, [])

		# Assess need for this position
		var priority := _assess_position_need(
			position,
			position_players,
			required_starters,
			roster.depth_chart,
			positions_cfg,
			main_cfg
		)

		needs[position] = priority

	return needs


## Get top N priority positions sorted by need
##
## Parameters:
##   needs_dict: Dictionary from assess_team_needs()
##   count: Number of positions to return
##   min_priority: Minimum priority threshold (default: PRIORITY_LOW)
##
## Returns:
##   Array[String]: Sorted array of position names by priority (highest first)
static func get_priority_positions(
	needs_dict: Dictionary,
	count: int = 5,
	min_priority: float = PRIORITY_LOW
) -> Array[String]:
	# Convert to array of [position, priority] pairs
	var needs_array: Array = []
	for position in needs_dict.keys():
		var priority := float(needs_dict[position])
		if priority >= min_priority:
			needs_array.append({"position": position, "priority": priority})

	# Sort by priority descending
	needs_array.sort_custom(func(a, b): return a["priority"] > b["priority"])

	# Extract top N positions
	var result: Array[String] = []
	for i in range(min(count, needs_array.size())):
		result.append(String(needs_array[i]["position"]))

	return result


## Get needs by priority category
##
## Returns:
##   Dictionary with keys: "critical", "high", "medium", "low"
##   Each value is Array[String] of positions in that category
static func categorize_needs(needs_dict: Dictionary) -> Dictionary:
	var categories := {
		"critical": [],
		"high": [],
		"medium": [],
		"low": []
	}

	for position in needs_dict.keys():
		var priority := float(needs_dict[position])

		if priority >= PRIORITY_CRITICAL:
			categories["critical"].append(position)
		elif priority >= PRIORITY_HIGH:
			categories["high"].append(position)
		elif priority >= PRIORITY_MEDIUM:
			categories["medium"].append(position)
		elif priority >= PRIORITY_LOW:
			categories["low"].append(position)

	return categories


## Groups roster entries by position string
##
## Returns: Dictionary mapping position strings to Arrays of roster entry Dictionaries
##   {
##     "QB": [entry1, entry2, ...],
##     "RB": [entry3, entry4, ...],
##     ...
##   }
static func _group_by_position(players: Array[Dictionary]) -> Dictionary:
	var grouped := {}
	for player in players:
		var position := String(player.get("position", ""))
		if position == "":
			continue

		if not grouped.has(position):
			grouped[position] = []

		(grouped[position] as Array).append(player)

	return grouped


## Internal: Assess need for a single position
##
## Factors considered:
##   - Number of players at position vs required starters
##   - Quality of starter (rating)
##   - Depth quality (backup ratings)
##   - Depth chart presence
##
## Returns priority: 0.0-1.0
static func _assess_position_need(
	position: String,
	position_players: Array,
	required_starters: int,
	depth_chart: DepthChart,
	positions_cfg: Dictionary,
	main_cfg: Dictionary
) -> float:
	# Critical need: No players at position
	if position_players.is_empty():
		return 1.0

	# Get player ratings
	var class_rules: Dictionary = main_cfg.get("class_rules", {})
	var player_ratings: Array = []
	for player in position_players:
		var p: Dictionary = player as Dictionary
		var rating := _get_player_rating(p, positions_cfg, class_rules)
		player_ratings.append(rating)

	# Sort ratings descending (best players first)
	player_ratings.sort_custom(func(a, b): return float(a) > float(b))

	# Evaluate starter quality
	var starter_rating := float(player_ratings[0])
	var starter_quality := _rate_starter_quality(starter_rating)

	# Evaluate depth
	var depth_quality := _rate_depth_quality(player_ratings, required_starters)

	# Combine factors into priority score
	var priority := (1.0 - starter_quality) * PRIORITY_WEIGHT_STARTER + (1.0 - depth_quality) * PRIORITY_WEIGHT_DEPTH

	# Boost priority if position is critically understaffed
	var player_count := position_players.size()
	var min_required := required_starters + DEPTH_MIN_BACKUP_COUNT
	if player_count < required_starters:
		priority = max(priority, PRIORITY_CRITICAL)
	elif player_count < min_required:
		priority = max(priority, PRIORITY_HIGH)

	return clamp(priority, 0.0, 1.0)


## Internal: Rate starter quality (0.0 = poor, 1.0 = excellent)
static func _rate_starter_quality(rating: float) -> float:
	# Rating scale: 0-100
	# 85+ = excellent (1.0)
	# 70-85 = good (0.7-1.0)
	# 60-70 = average (0.5-0.7)
	# 50-60 = below average (0.3-0.5)
	# <50 = poor (0.0-0.3)

	if rating >= 85.0:
		return 1.0
	elif rating >= 70.0:
		return 0.7 + (rating - 70.0) / 50.0  # 0.7-1.0
	elif rating >= 60.0:
		return 0.5 + (rating - 60.0) / 50.0  # 0.5-0.7
	elif rating >= 50.0:
		return 0.3 + (rating - 50.0) / 50.0  # 0.3-0.5
	else:
		return rating / 166.67  # 0.0-0.3 for <50


## Internal: Rate depth quality (0.0 = no depth, 1.0 = excellent depth)
static func _rate_depth_quality(sorted_ratings: Array, required_starters: int) -> float:
	var depth_count := sorted_ratings.size() - required_starters
	if depth_count <= 0:
		return 0.0  # No depth

	# Evaluate backup quality
	var backup_ratings: Array = []
	for i in range(required_starters, sorted_ratings.size()):
		backup_ratings.append(sorted_ratings[i])

	# Average backup rating
	var avg_backup_rating := 0.0
	for rating in backup_ratings:
		avg_backup_rating += float(rating)
	avg_backup_rating /= float(backup_ratings.size())

	# Number of backups factor (more is better, diminishing returns)
	var depth_count_factor: float = min(1.0, float(depth_count) / DEPTH_IDEAL_BACKUP_COUNT)

	# Quality factor (based on average backup rating)
	var quality_factor := avg_backup_rating / 100.0

	# Combine factors
	return depth_count_factor * DEPTH_WEIGHT_COUNT + quality_factor * DEPTH_WEIGHT_QUALITY


## Internal: Get player overall rating
static func _get_player_rating(
	player: Dictionary,
	positions_cfg: Dictionary,
	class_rules: Dictionary
) -> float:
	# Use PlayerRatingCalculator from StatGenerator
	const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")
	return PlayerRatingCalculator.calculate_overall_rating(player, positions_cfg, class_rules)
