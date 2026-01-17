## DraftDayLauncher - Utility for launching Draft Day UI with session configuration
##
## Provides both random team assignment (bootstrap/testing) and
## specific team selection (production game flow).
##
## This stateless utility eliminates code duplication between:
## - BootstrapPreview (random team for testing)
## - NewGameMain (user-selected team for production)
##
## Usage (Bootstrap):
##   var result = DraftDayLauncher.launch_with_random_team(world_state, year, parent_node)
##   var session = result["session"]
##   var draft = result["draft"]
##   var ui = result["ui"]
##
## Usage (Production):
##   var result = DraftDayLauncher.launch_with_team(world_state, year, team_id, parent_node)
##
extends RefCounted
class_name DraftDayLauncher

const Rand = preload("res://autoloads/Rand.gd")
const GameSession = preload("res://scripts/core/models/GameSession.gd")
const InteractiveDraft = preload("res://scripts/world/InteractiveDraft.gd")
const ConfigService = preload("res://autoloads/Config.gd")

## Launch draft day with a random team assigned to user
##
## Selects a random NFL team deterministically based on world seed.
## Uses magic number 0xB007514C ("BOOTSTRAP") to derive unique seed.
##
## RNG Usage:
## - Creates RNG with seed: splitmix64(world_seed ^ 0xB007514C)
## - Consumes 1 RNG call: randi_range(0, team_count - 1)
##
## @param world_state: Fully initialized world state from BootstrapGameWorld
## @param current_year: Year to run draft for (from world state)
## @param parent_node: Node to add DraftDayUI scene to (typically get_tree().root)
## @return Dictionary with {session: GameSession, draft: InteractiveDraft, ui: DraftDayUI}
##         Returns empty {} on error
static func launch_with_random_team(world_state: Dictionary, current_year: int, parent_node: Node) -> Dictionary:
	# Validate inputs
	if world_state.is_empty():
		push_error("[DraftDayLauncher] world_state is empty")
		return {}

	if current_year <= 0:
		push_error("[DraftDayLauncher] Invalid current_year: %d" % current_year)
		return {}

	if parent_node == null:
		push_error("[DraftDayLauncher] parent_node is null")
		return {}

	# Load all required configs
	var main_cfg := _load_main_config()
	var league_cfg := _load_league_config()
	var positions_cfg := _load_positions_config()
	var stats_cfg := _load_stats_config()
	var scouts_cfg := _load_scouts_config()

	# Validate configs loaded successfully
	if league_cfg.is_empty() or positions_cfg.is_empty():
		push_error("[DraftDayLauncher] Failed to load required configs")
		return {}

	# Select random team deterministically from world seed
	var world_seed := int(world_state.get("creation_seed", 0))
	if world_seed == 0:
		push_warning("[DraftDayLauncher] world_state has no creation_seed, using year as fallback")
		world_seed = current_year

	var rng := RandomNumberGenerator.new()
	# Magic: 0xB007514C = "BOOTSTRAP" (random team for bootstrap)
	# This ensures same world seed always picks same team for reproducibility
	rng.seed = Rand.splitmix64(world_seed ^ 0xB007514C)

	var teams: Array = world_state.get("nfl_teams", [])
	if teams.is_empty():
		push_error("[DraftDayLauncher] No NFL teams in world state")
		return {}

	# RNG consumption: 1 call to randi_range
	var random_index := rng.randi_range(0, teams.size() - 1)
	var selected_team: Dictionary = teams[random_index]
	var user_team_id := String(selected_team.get("id", selected_team.get("team_id", "")))

	if user_team_id.is_empty():
		push_error("[DraftDayLauncher] Selected team has no ID")
		return {}

	print("[DraftDayLauncher] Randomly selected team: %s (index %d/%d)" % [
		user_team_id, random_index, teams.size()
	])

	# Launch with selected team
	return launch_with_team(world_state, current_year, user_team_id, parent_node)


## Launch draft day with specific team assigned to user
##
## Creates GameSession, InteractiveDraft, and DraftDayUI with full initialization.
## This is the production path used by NewGameMain after team selection.
##
## @param world_state: Fully initialized world state
## @param current_year: Year to run draft for
## @param user_team_id: Team ID user will control
## @param parent_node: Node to add DraftDayUI scene to
## @return Dictionary with {session: GameSession, draft: InteractiveDraft, ui: DraftDayUI}
##         Returns empty {} on error
static func launch_with_team(world_state: Dictionary, current_year: int, user_team_id: String, parent_node: Node) -> Dictionary:
	# Validate inputs
	if world_state.is_empty():
		push_error("[DraftDayLauncher] world_state is empty")
		return {}

	if current_year <= 0:
		push_error("[DraftDayLauncher] Invalid current_year: %d" % current_year)
		return {}

	if user_team_id.is_empty():
		push_error("[DraftDayLauncher] user_team_id is empty")
		return {}

	if parent_node == null:
		push_error("[DraftDayLauncher] parent_node is null")
		return {}

	# Load configs
	var main_cfg := _load_main_config()
	var league_cfg := _load_league_config()
	var positions_cfg := _load_positions_config()
	var stats_cfg := _load_stats_config()
	var scouts_cfg := _load_scouts_config()

	# Validate configs
	if league_cfg.is_empty():
		push_error("[DraftDayLauncher] Failed to load league config")
		return {}

	if positions_cfg.is_empty():
		push_error("[DraftDayLauncher] Failed to load positions config")
		return {}

	# Create GameSession
	var session := GameSession.new()
	session.world_state = world_state
	session.current_year = current_year
	session.user_team_id = user_team_id

	# Find user team name for display
	var teams: Array = world_state.get("nfl_teams", [])
	for team in teams:
		var t: Dictionary = team
		var team_id := String(t.get("id", t.get("team_id", "")))
		if team_id == user_team_id:
			var city := String(t.get("city", ""))
			var name := String(t.get("name", ""))
			session.user_team_name = "%s %s" % [city, name]
			break

	if session.user_team_name.is_empty():
		session.user_team_name = user_team_id
		push_warning("[DraftDayLauncher] Could not find team name for %s" % user_team_id)

	print("[DraftDayLauncher] Created session for %s (%d)" % [session.user_team_name, current_year])

	# Create InteractiveDraft
	var draft := InteractiveDraft.new()
	var draft_seed := int(world_state.get("creation_seed", 0)) ^ current_year
	if draft_seed == 0:
		# Fallback if no creation_seed
		draft_seed = current_year * 0x44524146  # "DRAF" magic
		push_warning("[DraftDayLauncher] No creation_seed in world_state, using fallback draft seed")

	print("[DraftDayLauncher] Initializing draft with seed: %d" % draft_seed)

	draft.initialize(
		world_state,
		current_year,
		draft_seed,
		user_team_id,
		league_cfg,
		positions_cfg,
		stats_cfg,
		scouts_cfg,
		main_cfg
	)

	# Load and instantiate DraftDayUI scene
	var draft_ui_scene := load("res://scenes/ui/draft_day/draft_day_ui.tscn")
	if not draft_ui_scene:
		push_error("[DraftDayLauncher] Failed to load DraftDayUI scene at res://scenes/ui/draft_day/draft_day_ui.tscn")
		return {}

	var ui: Node = draft_ui_scene.instantiate()
	if ui == null:
		push_error("[DraftDayLauncher] Failed to instantiate DraftDayUI scene")
		return {}

	parent_node.add_child(ui)

	# Initialize UI (this connects signals and starts the draft)
	if ui.has_method("initialize"):
		ui.initialize(session, draft)
	else:
		push_error("[DraftDayLauncher] DraftDayUI missing initialize() method")
		ui.queue_free()
		return {}

	print("[DraftDayLauncher] Draft Day launched successfully for %s" % session.user_team_name)

	return {
		"session": session,
		"draft": draft,
		"ui": ui
	}


# =============================================================================
# HELPER METHODS - Config Loading
# =============================================================================

## Load main config (class_rules, etc.)
static func _load_main_config() -> Dictionary:
	var config := ConfigService.new()
	var cfg := config.get_config("main")
	if cfg.is_empty():
		push_warning("[DraftDayLauncher] main.json not found, using defaults")
	return cfg


## Load league config (draft rules, roster limits, etc.)
static func _load_league_config() -> Dictionary:
	var config := ConfigService.new()
	var cfg := config.get_config("world/league")
	if cfg.is_empty():
		push_error("[DraftDayLauncher] world/league.json not found - draft cannot proceed")
	return cfg


## Load positions config (position definitions, weights, etc.)
static func _load_positions_config() -> Dictionary:
	var config := ConfigService.new()
	var cfg := config.get_config("positions")
	if cfg.is_empty():
		push_error("[DraftDayLauncher] positions.json not found - draft cannot proceed")
	return cfg


## Load stats config (stat definitions, calculations, etc.)
static func _load_stats_config() -> Dictionary:
	var config := ConfigService.new()
	var cfg := config.get_config("stats")
	if cfg.is_empty():
		push_warning("[DraftDayLauncher] stats.json not found, using defaults")
	return cfg


## Load scouts config (scouting rules, accuracy, etc.)
static func _load_scouts_config() -> Dictionary:
	var config := ConfigService.new()
	var cfg := config.get_config("scouts")
	if cfg.is_empty():
		push_warning("[DraftDayLauncher] scouts.json not found, using defaults")
	return cfg
