## GameSession - Tracks the user's game context
##
## This model maintains the state of a player's game session, including:
## - Which team the user controls
## - The current game year and phase
## - World state reference
## - Session metadata (save name, timestamps)
##
## Usage:
##   var session = GameSession.new()
##   session.initialize(world_state, "team_phi", 2025)
##   session.save_to_file("saves/my_game.json")
##
extends RefCounted
class_name GameSession

## Session identification
var session_id: String = ""
var save_name: String = ""
var created_at: int = 0  # Unix timestamp
var last_played_at: int = 0  # Unix timestamp

## User's team context
var user_team_id: String = ""
var user_team_name: String = ""

## World state reference (not persisted directly - loaded separately)
var world_state: Dictionary = {}

## Game progression
var current_year: int = 2025
var current_phase: String = "pre_draft"  # pre_draft, draft, post_draft, season, offseason
var years_simulated: int = 0

## Draft state (when in draft phase)
var draft_pick_index: int = 0  # Current pick in the draft
var user_picks_remaining: Array = []  # Array of {round, pick, original_team_id}
var draft_completed: bool = false

## Game settings
var difficulty: String = "normal"  # easy, normal, hard
var auto_sim_enabled: bool = false

## Statistics tracking
var seasons_played: int = 0
var total_wins: int = 0
var total_losses: int = 0
var championships: int = 0

## Initialize a new game session
func initialize(p_world_state: Dictionary, team_id: String, year: int) -> void:
	session_id = _generate_session_id()
	created_at = int(Time.get_unix_time_from_system())
	last_played_at = created_at

	world_state = p_world_state
	user_team_id = team_id
	current_year = year
	current_phase = "pre_draft"

	# Extract team name from world_state
	var teams: Array = world_state.get("nfl_teams", [])
	for team in teams:
		var t: Dictionary = team
		if String(t.get("id", "")) == team_id:
			user_team_name = String(t.get("name", team_id))
			break

	# Initialize user's draft picks
	_initialize_user_draft_picks()


## Initialize the user's draft picks from the ownership ledger
func _initialize_user_draft_picks() -> void:
	user_picks_remaining.clear()

	var ownership: Dictionary = world_state.get("draft_pick_ownership", {})
	var year_ownership: Dictionary = ownership.get(current_year, {})

	# Find all picks owned by the user's team
	for round_num in year_ownership.keys():
		var round_ownership: Dictionary = year_ownership[round_num]
		for original_team_id in round_ownership.keys():
			var owner_id: String = round_ownership[original_team_id]
			if owner_id == user_team_id:
				user_picks_remaining.append({
					"round": round_num,
					"original_team_id": original_team_id,
					"traded": original_team_id != user_team_id
				})

	# Sort by round
	user_picks_remaining.sort_custom(func(a, b):
		return int(a.get("round", 99)) < int(b.get("round", 99))
	)


## Get the user's team data from world_state
func get_user_team() -> Dictionary:
	var teams: Array = world_state.get("nfl_teams", [])
	for team in teams:
		var t: Dictionary = team
		if String(t.get("id", "")) == user_team_id:
			return t
	return {}


## Get the user's roster from world_state
func get_user_roster() -> Dictionary:
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	return rosters.get(user_team_id, {"players": [], "by_position": {}})


## Get the user's head coach
func get_user_coach() -> Dictionary:
	var team := get_user_team()
	return team.get("coach", {})


## Check if user has any picks remaining in the draft
func has_picks_remaining() -> bool:
	return not user_picks_remaining.is_empty()


## Get the user's next pick info
func get_next_user_pick() -> Dictionary:
	if user_picks_remaining.is_empty():
		return {}
	return user_picks_remaining[0]


## Mark a pick as used (called after drafting)
func consume_pick() -> void:
	if not user_picks_remaining.is_empty():
		user_picks_remaining.pop_front()


## Advance to next phase
func advance_phase() -> void:
	match current_phase:
		"pre_draft":
			current_phase = "draft"
		"draft":
			current_phase = "post_draft"
			draft_completed = true
		"post_draft":
			current_phase = "season"
		"season":
			current_phase = "offseason"
		"offseason":
			current_phase = "pre_draft"
			current_year += 1


## Update last played timestamp
func touch() -> void:
	last_played_at = int(Time.get_unix_time_from_system())


## Generate a unique session ID
## @param seed: Optional seed for deterministic ID generation (for testing)
##              If not provided or 0, uses system time for uniqueness
func _generate_session_id(seed: int = 0) -> String:
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		# Deterministic mode for testing
		rng.seed = seed
	else:
		# Production mode: use system time for uniqueness
		rng.randomize()
	return "%08x-%04x-%04x-%04x-%012x" % [
		rng.randi(),
		rng.randi() & 0xFFFF,
		rng.randi() & 0xFFFF,
		rng.randi() & 0xFFFF,
		rng.randi()
	]


## Serialize session metadata (not world_state) for saving
func to_dict() -> Dictionary:
	return {
		"session_id": session_id,
		"save_name": save_name,
		"created_at": created_at,
		"last_played_at": last_played_at,
		"user_team_id": user_team_id,
		"user_team_name": user_team_name,
		"current_year": current_year,
		"current_phase": current_phase,
		"years_simulated": years_simulated,
		"draft_pick_index": draft_pick_index,
		"user_picks_remaining": user_picks_remaining,
		"draft_completed": draft_completed,
		"difficulty": difficulty,
		"auto_sim_enabled": auto_sim_enabled,
		"seasons_played": seasons_played,
		"total_wins": total_wins,
		"total_losses": total_losses,
		"championships": championships,
	}


## Restore session from dictionary (call load_world_state separately)
func from_dict(data: Dictionary) -> void:
	session_id = String(data.get("session_id", ""))
	save_name = String(data.get("save_name", ""))
	created_at = int(data.get("created_at", 0))
	last_played_at = int(data.get("last_played_at", 0))
	user_team_id = String(data.get("user_team_id", ""))
	user_team_name = String(data.get("user_team_name", ""))
	current_year = int(data.get("current_year", 2025))
	current_phase = String(data.get("current_phase", "pre_draft"))
	years_simulated = int(data.get("years_simulated", 0))
	draft_pick_index = int(data.get("draft_pick_index", 0))
	user_picks_remaining = data.get("user_picks_remaining", [])
	draft_completed = bool(data.get("draft_completed", false))
	difficulty = String(data.get("difficulty", "normal"))
	auto_sim_enabled = bool(data.get("auto_sim_enabled", false))
	seasons_played = int(data.get("seasons_played", 0))
	total_wins = int(data.get("total_wins", 0))
	total_losses = int(data.get("total_losses", 0))
	championships = int(data.get("championships", 0))


## Load world state into session
func load_world_state(p_world_state: Dictionary) -> void:
	world_state = p_world_state
	_initialize_user_draft_picks()
