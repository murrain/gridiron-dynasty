## DraftPsychologyEngine - Models draft day psychology and positional runs
##
## ARCHITECTURAL PATTERN: Stateless Service with Tracking State
##
## This service tracks recent draft picks to detect positional runs (when multiple
## teams draft the same position in quick succession) and calculates urgency
## multipliers that influence AI team behavior during runs.
##
## Key Features:
##   - Run detection (3+ same position in configurable window)
##   - Urgency multipliers for team boards during active runs
##   - Panic mode detection for trade-up scenarios
##   - Run cooldown after position saturation
##
## Design Philosophy:
##   - NO RNG - All calculations are purely deterministic
##   - Urgency multipliers modify AI board scores non-destructively
##   - State is lightweight (pick history only, cleared per draft)
##   - Performance optimized for <50ms board re-scoring
##
## Determinism Guarantee:
##   - Given the same pick history and team needs, urgency calculations
##     always produce identical results
##   - No probabilistic elements in run detection or urgency formulas
##
## Integration Points:
##   - InteractiveDraft: Records picks and queries urgency multipliers
##   - DraftDayUI: Receives run_detected signal for UI alerts
##
## Usage:
##   var engine = DraftPsychologyEngine.new()
##   engine.record_pick("QB", 1, "team1")
##   var urgency = engine.get_urgency_multiplier("team2", "QB", 5, 3, needs)
##
extends RefCounted
class_name DraftPsychologyEngine

## Configuration Constants - Defines run detection and urgency behavior
## RUN_THRESHOLD: Minimum picks at same position to trigger a run
const RUN_THRESHOLD: int = 3

## RUN_WINDOW: Number of recent picks to check for runs
## A run is detected if RUN_THRESHOLD picks occur within RUN_WINDOW picks
const RUN_WINDOW: int = 5

## PANIC_REMAINING: When quality players at position drops to this level, panic mode activates
## At this threshold, urgency multiplier reaches maximum (2.0x)
const PANIC_REMAINING: int = 2

## ELEVATED_REMAINING: When quality players at position drops to this level, elevated urgency
## At this threshold, urgency multiplier is elevated (1.5x)
const ELEVATED_REMAINING: int = 5

## RUN_COOLDOWN_PICKS: After this many picks in a run, urgency starts to decrease
## Models position saturation - after many picks, fewer quality players remain anyway
const RUN_COOLDOWN_PICKS: int = 6

## NEED_THRESHOLD: Minimum need level (from team needs dict) to trigger urgency
## Teams with need below this value ignore runs at that position
const NEED_THRESHOLD: float = 1.1

## HIGH_NEED_THRESHOLD: Need level required for panic trade consideration
const HIGH_NEED_THRESHOLD: float = 1.3

## MAXIMUM_URGENCY: Cap on urgency multiplier to prevent extreme reaching
const MAXIMUM_URGENCY: float = 3.0

## NEED_MULTIPLIER_CAP: Maximum scaling from team need level
const NEED_MULTIPLIER_CAP: float = 1.5

## State tracking
## _position_picks: Maps position -> Array of pick numbers where that position was drafted
var _position_picks: Dictionary = {}

## _pick_history: Ordered list of all picks recorded, for debugging and UI display
## Each entry: {position: String, pick_number: int, team_id: String}
var _pick_history: Array = []

## Emitted when a positional run is detected
## Parameters:
##   position: The position experiencing a run
##   pick_count: Number of picks at this position in the run window
##   recent_picks: Array of pick numbers that are part of the run
signal run_detected(position: String, pick_count: int, recent_picks: Array)

## Emitted when a run cools down (saturation reached)
signal run_cooled_down(position: String)


## Record a pick for run tracking
##
## Called after each pick is executed to update position tracking.
## Automatically checks for and emits run detection signals.
##
## RNG: None (pure state mutation)
##
## @param position: Position of drafted player (e.g., "QB", "CB")
## @param pick_number: Overall pick number (1-262 for 7-round draft)
## @param team_id: ID of team that made the pick
func record_pick(position: String, pick_number: int, team_id: String) -> void:
	if position.is_empty():
		return

	# Initialize position array if needed
	if not _position_picks.has(position):
		_position_picks[position] = []

	# Record the pick
	_position_picks[position].append(pick_number)
	_pick_history.append({
		"position": position,
		"pick_number": pick_number,
		"team_id": team_id
	})

	# Check for run detection
	if is_position_run_active(position, pick_number):
		var recent := get_recent_picks_at_position(position, pick_number)
		run_detected.emit(position, recent.size(), recent)

		# Check for cooldown
		if recent.size() >= RUN_COOLDOWN_PICKS:
			run_cooled_down.emit(position)


## Check if a positional run is currently active
##
## A run is active when RUN_THRESHOLD or more picks at the same position
## have occurred within the RUN_WINDOW most recent picks.
##
## RNG: None (pure calculation)
##
## @param position: Position to check for run
## @param current_pick: Current overall pick number
## @return bool: True if run is active at this position
func is_position_run_active(position: String, current_pick: int) -> bool:
	var recent_picks := get_recent_picks_at_position(position, current_pick)
	return recent_picks.size() >= RUN_THRESHOLD


## Get recent picks at a position within the run window
##
## Returns all pick numbers at the specified position that fall within
## the RUN_WINDOW relative to the current pick.
##
## RNG: None (pure calculation)
##
## @param position: Position to query
## @param current_pick: Current overall pick number
## @return Array: Pick numbers at this position within the window
func get_recent_picks_at_position(position: String, current_pick: int) -> Array:
	var picks: Array = _position_picks.get(position, [])
	var recent: Array = []

	for pick_num in picks:
		# Pick is within window if it occurred within RUN_WINDOW picks of current
		if current_pick - int(pick_num) <= RUN_WINDOW:
			recent.append(pick_num)

	return recent


## Calculate urgency multiplier for a team/position combination
##
## The urgency multiplier is applied to AI team board scores to simulate
## the psychological pressure teams feel during positional runs.
##
## Calculation factors:
## 1. Run must be active (3+ picks at position in window)
## 2. Team must have need at position (need >= NEED_THRESHOLD)
## 3. Remaining quality players determine base urgency:
##    - <= PANIC_REMAINING: 2.0x (panic mode)
##    - <= ELEVATED_REMAINING: 1.5x (elevated urgency)
##    - > ELEVATED_REMAINING: 1.2x (mild concern)
## 4. Team need level scales the urgency (capped at NEED_MULTIPLIER_CAP)
## 5. Cooldown reduces urgency if too many picks already made
##
## Determinism: Same inputs always produce same output (no RNG)
##
## @param team_id: Team ID (for logging, not used in calculation)
## @param position: Position to calculate urgency for
## @param current_pick: Current overall pick number
## @param remaining_quality: Number of quality players remaining at position
## @param team_needs: Dictionary mapping position -> need multiplier (1.0 = baseline)
## @return float: Urgency multiplier (1.0 = no urgency, >1.0 = reach for position)
func get_urgency_multiplier(
	team_id: String,
	position: String,
	current_pick: int,
	remaining_quality: int,
	team_needs: Dictionary
) -> float:
	# No run active = no urgency
	if not is_position_run_active(position, current_pick):
		return 1.0

	# Team doesn't need this position = no urgency
	var need_level := float(team_needs.get(position, 1.0))
	if need_level < NEED_THRESHOLD:
		return 1.0

	# Calculate run intensity (how many picks in the run)
	var run_picks := get_recent_picks_at_position(position, current_pick)
	var run_size := run_picks.size()

	# Check for cooldown - reduce urgency after saturation
	var cooldown_factor := 1.0
	if run_size >= RUN_COOLDOWN_PICKS:
		# Reduce urgency as run continues past saturation point
		# Each pick beyond cooldown reduces urgency by 10%
		var excess := run_size - RUN_COOLDOWN_PICKS
		cooldown_factor = max(0.5, 1.0 - (float(excess) * 0.1))

	# Calculate base urgency from remaining quality players
	var urgency: float = 1.0
	if remaining_quality <= PANIC_REMAINING:
		# PANIC MODE: Very few quality players left
		urgency = 2.0
	elif remaining_quality <= ELEVATED_REMAINING:
		# ELEVATED: Limited quality players remaining
		urgency = 1.5
	else:
		# MILD CONCERN: Run is active but supply adequate
		urgency = 1.2

	# Bonus urgency for larger runs (each pick beyond threshold adds 5%)
	var run_bonus := 1.0 + (float(max(0, run_size - RUN_THRESHOLD)) * 0.05)
	urgency *= run_bonus

	# Scale by team's need level (higher need = more panic)
	# Cap at NEED_MULTIPLIER_CAP to prevent extreme values
	urgency *= min(need_level, NEED_MULTIPLIER_CAP)

	# Apply cooldown reduction
	urgency *= cooldown_factor

	# Cap at maximum urgency
	return min(urgency, MAXIMUM_URGENCY)


## Check if team should consider panic trading up
##
## Returns true when conditions suggest a team might desperately trade
## up to secure a player at a position experiencing a run.
##
## Conditions required (ALL must be true):
## 1. Run is active at the position
## 2. Team has high need at position (>= HIGH_NEED_THRESHOLD)
## 3. Few quality players remaining (<= PANIC_REMAINING)
## 4. Team has draft capital to trade (>= 2 picks)
##
## RNG: None (pure boolean calculation)
##
## @param team_id: Team ID (for logging)
## @param position: Position to check
## @param current_pick: Current overall pick number
## @param remaining_quality: Number of quality players at position
## @param team_needs: Dictionary mapping position -> need multiplier
## @param team_draft_capital: Number of picks team has remaining
## @return bool: True if team should consider panic trade
func should_team_panic_trade(
	team_id: String,
	position: String,
	current_pick: int,
	remaining_quality: int,
	team_needs: Dictionary,
	team_draft_capital: int
) -> bool:
	# Must be in panic mode (few quality players left)
	if remaining_quality > PANIC_REMAINING:
		return false

	# Must have run active
	if not is_position_run_active(position, current_pick):
		return false

	# Must have strong need
	var need_level := float(team_needs.get(position, 1.0))
	if need_level < HIGH_NEED_THRESHOLD:
		return false

	# Must have draft capital to trade (at least 2 picks remaining)
	if team_draft_capital < 2:
		return false

	return true


## Calculate reach distance - how many spots a team might reach during a run
##
## When a run is active, teams may draft players earlier than their natural
## board position. This function calculates how many spots they might "reach."
##
## Formula: base_reach + (urgency_bonus * run_intensity)
## - Base reach: 5 spots
## - Run intensity adds up to 5 more spots
## - Panic mode adds 3 more spots
##
## RNG: None (pure calculation)
##
## @param position: Position being reached for
## @param current_pick: Current overall pick number
## @param remaining_quality: Quality players remaining at position
## @param team_needs: Team's position needs
## @return int: Number of spots team might reach (0-13 typical range)
func calculate_reach_distance(
	position: String,
	current_pick: int,
	remaining_quality: int,
	team_needs: Dictionary
) -> int:
	if not is_position_run_active(position, current_pick):
		return 0

	var need_level := float(team_needs.get(position, 1.0))
	if need_level < NEED_THRESHOLD:
		return 0

	# Base reach during any run
	var base_reach := 5

	# Additional reach based on run intensity
	var run_picks := get_recent_picks_at_position(position, current_pick)
	var intensity_reach: int = min(run_picks.size() - RUN_THRESHOLD, 5)

	# Panic mode additional reach
	var panic_reach := 0
	if remaining_quality <= PANIC_REMAINING:
		panic_reach = 3

	return base_reach + intensity_reach + panic_reach


## Get all currently active runs
##
## Returns a summary of all positions with active runs, useful for
## UI display and debugging.
##
## RNG: None (pure calculation)
##
## @param current_pick: Current overall pick number
## @return Array: Array of dictionaries with run information
##   Each entry: {position, pick_count, recent_picks, urgency_level}
func get_active_runs(current_pick: int) -> Array:
	var runs: Array = []

	for position in _position_picks.keys():
		if is_position_run_active(position, current_pick):
			var recent := get_recent_picks_at_position(position, current_pick)
			var pick_count := recent.size()

			# Determine urgency level string for UI
			var urgency_level: String
			if pick_count >= RUN_COOLDOWN_PICKS:
				urgency_level = "COOLING"
			elif pick_count >= 5:
				urgency_level = "CRITICAL"
			elif pick_count >= 4:
				urgency_level = "HIGH"
			else:
				urgency_level = "MEDIUM"

			runs.append({
				"position": position,
				"pick_count": pick_count,
				"recent_picks": recent,
				"urgency_level": urgency_level
			})

	return runs


## Get user notification message for active runs
##
## Generates helpful notification messages for the user when runs are
## detected that might affect their draft strategy.
##
## RNG: None (pure string generation)
##
## @param current_pick: Current overall pick number
## @param user_needs: User's team position needs
## @return Array: Array of notification dictionaries
##   Each entry: {message: String, urgency: int (1=MEDIUM, 2=HIGH)}
func get_user_notifications(current_pick: int, user_needs: Dictionary) -> Array:
	var notifications: Array = []
	var runs := get_active_runs(current_pick)

	for run in runs:
		var r: Dictionary = run
		var position := String(r.get("position", ""))
		var pick_count := int(r.get("pick_count", 0))
		var urgency_level := String(r.get("urgency_level", "MEDIUM"))

		# Only notify if user has need at this position
		var user_need := float(user_needs.get(position, 1.0))
		if user_need < NEED_THRESHOLD:
			continue

		var urgency_int := 1 if urgency_level == "MEDIUM" else 2
		var action_suggestion: String

		if urgency_level == "COOLING":
			action_suggestion = "Supply exhausted - consider other options"
		elif urgency_level == "CRITICAL":
			action_suggestion = "Act NOW if you need a %s!" % position
		elif urgency_level == "HIGH":
			action_suggestion = "Consider trading up or reaching for %s" % position
		else:
			action_suggestion = "Monitor availability"

		notifications.append({
			"message": "RUN on %s (%d picks in last %d) - %s" % [
				position, pick_count, RUN_WINDOW, action_suggestion
			],
			"urgency": urgency_int,
			"position": position
		})

	return notifications


## Get positions where a run might form soon
##
## Identifies positions with 2 picks in the window (one away from run).
## Useful for anticipating market movements.
##
## RNG: None (pure calculation)
##
## @param current_pick: Current overall pick number
## @return Array: Positions with 2 picks in window (near-run state)
func get_positions_near_run(current_pick: int) -> Array:
	var near_runs: Array = []

	for position in _position_picks.keys():
		var recent := get_recent_picks_at_position(position, current_pick)
		# Near run = exactly 2 picks (one more triggers threshold of 3)
		if recent.size() == RUN_THRESHOLD - 1:
			near_runs.append(position)

	return near_runs


## Reset state (called after draft completes or for testing)
##
## Clears all pick tracking data to prepare for a new draft.
##
## RNG: None (pure state reset)
func reset() -> void:
	_position_picks.clear()
	_pick_history.clear()


## Get debug state for testing and inspection
##
## Returns internal state for test assertions and debugging.
##
## RNG: None (pure data copy)
##
## @return Dictionary: Copy of internal state
##   {position_picks: Dict, pick_history: Array, total_picks_tracked: int}
func get_debug_state() -> Dictionary:
	return {
		"position_picks": _position_picks.duplicate(true),
		"pick_history": _pick_history.duplicate(true),
		"total_picks_tracked": _pick_history.size()
	}


## Get pick history for a specific position
##
## @param position: Position to query
## @return Array: All pick numbers where this position was drafted
func get_position_history(position: String) -> Array:
	return _position_picks.get(position, []).duplicate()


## Get last N picks for ticker display
##
## @param count: Number of recent picks to return
## @return Array: Most recent picks (newest first)
func get_recent_picks(count: int) -> Array:
	var start_idx: int = max(0, _pick_history.size() - count)
	var recent := _pick_history.slice(start_idx)
	recent.reverse()
	return recent
