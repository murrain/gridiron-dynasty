## SQLite-based persistence backend
## Provides high-performance queryable storage for game entities
## Uses normalized schema with PlayerDAO/TeamDAO for entity management
extends RefCounted
class_name DatabasePersistence

const PlayerDAO = preload("res://scripts/persistence/PlayerDAO.gd")
const TeamDAO = preload("res://scripts/persistence/TeamDAO.gd")

# Import models for data conversion
const Player = preload("res://scripts/core/models/Player.gd")
const Team = preload("res://scripts/core/models/Team.gd")

var _db: SQLite = null
var _player_dao: PlayerDAO = null
var _team_dao: TeamDAO = null

const DB_DIR = "user://saves/"
const SCHEMA_FILE = "res://scripts/persistence/schema.sql"

## Initialize database connection
func _init() -> void:
	_db = SQLite.new()

## Open database connection
## @param save_name: Database filename (without .db extension)
## @return: true on success, false on failure
func open_database(save_name: String) -> bool:
	if not DirAccess.dir_exists_absolute(DB_DIR):
		var dir_result = DirAccess.make_dir_recursive_absolute(DB_DIR)
		if dir_result != OK:
			push_error("DatabasePersistence: Failed to create database directory: %s" % DB_DIR)
			return false

	_db.path = DB_DIR + save_name + ".db"
	if not _db.open_db():
		push_error("DatabasePersistence: Failed to open database: %s" % _db.path)
		return false

	print("DatabasePersistence: Opened database at %s" % _db.path)
	return true

## Close database connection
func close_database() -> void:
	if _db:
		_db.close_db()
		print("DatabasePersistence: Closed database connection")

## Initialize database schema if not exists
## @return: true on success, false on failure
func initialize_schema() -> bool:
	# Check if schema already exists (check for schema_metadata table)
	_db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='schema_metadata'")
	var result = _db.query_result
	if result.size() > 0:
		# Schema exists, verify version
		_db.query("SELECT value FROM schema_metadata WHERE key='schema_version'")
		var version_result = _db.query_result
		if version_result.size() > 0:
			var version = version_result[0]["value"]
			print("DatabasePersistence: Schema version %s already exists" % version)
			return true

	# Schema doesn't exist, create it
	print("DatabasePersistence: Initializing schema from %s" % SCHEMA_FILE)

	var schema_sql = _load_schema_file()
	if schema_sql.is_empty():
		return false

	# Execute schema creation (split by semicolons)
	# Note: We must handle multi-line statements that may have comments before them
	var statements = schema_sql.split(";")
	for stmt in statements:
		var trimmed = stmt.strip_edges()
		if trimmed.is_empty():
			continue

		# Remove comment lines but keep SQL statements
		var sql_lines: Array[String] = []
		for line in trimmed.split("\n"):
			var line_trimmed = line.strip_edges()
			if not line_trimmed.is_empty() and not line_trimmed.begins_with("--"):
				sql_lines.append(line)

		if sql_lines.is_empty():
			continue

		var clean_sql = "\n".join(sql_lines).strip_edges()
		if clean_sql.is_empty():
			continue

		_db.query(clean_sql)
		if _db.error_message != "not an error":
			push_error("DatabasePersistence: Schema creation failed: %s\nError: %s" %
				[clean_sql.substr(0, 100), _db.error_message])
			return false

	print("DatabasePersistence: Schema initialized successfully")
	return true

## Load schema SQL from file
func _load_schema_file() -> String:
	if not FileAccess.file_exists(SCHEMA_FILE):
		push_error("DatabasePersistence: Schema file not found: %s" % SCHEMA_FILE)
		return ""

	var file = FileAccess.open(SCHEMA_FILE, FileAccess.READ)
	if not file:
		push_error("DatabasePersistence: Failed to open schema file: %s" % SCHEMA_FILE)
		return ""

	var content = file.get_as_text()
	file.close()
	return content

# =========================
# Transaction Support
# =========================

## Begin database transaction
## @return: true on success, false on failure
func begin_transaction() -> bool:
	_db.query("BEGIN TRANSACTION")
	if _db.error_message != "not an error":
		push_error("DatabasePersistence: Failed to begin transaction: %s" % _db.error_message)
		return false
	return true

## Commit database transaction
## @return: true on success, false on failure
func commit_transaction() -> bool:
	_db.query("COMMIT")
	if _db.error_message != "not an error":
		push_error("DatabasePersistence: Failed to commit transaction: %s" % _db.error_message)
		return false
	return true

## Rollback database transaction
## @return: true on success, false on failure
func rollback_transaction() -> bool:
	_db.query("ROLLBACK")
	if _db.error_message != "not an error":
		push_error("DatabasePersistence: Failed to rollback transaction: %s" % _db.error_message)
		return false
	return true

# =========================
# World State Operations
# =========================

## Save complete world state to database
## @param world_state: Dictionary containing all game entities
## @param save_name: Database identifier
## @return: true on success, false on failure
func save_world_state(world_state: Dictionary, save_name: String) -> bool:
	if not open_database(save_name):
		return false

	if not initialize_schema():
		close_database()
		return false

	# Initialize DAOs
	_player_dao = PlayerDAO.new(_db)
	_team_dao = TeamDAO.new(_db, _player_dao)

	# Enable foreign keys for data integrity
	_db.query("PRAGMA foreign_keys = ON;")

	# Begin transaction for atomic save
	if not begin_transaction():
		close_database()
		return false

	var success = true
	var player_count = 0
	var team_count = 0

	# Extract NFL players from nfl_rosters dictionary
	# The world_state structure uses nfl_rosters as a Dictionary mapping team_id -> roster
	# Each roster has a "players" array
	var players_data: Array = []
	var nfl_rosters: Dictionary = world_state.get("nfl_rosters", {})

	for team_id in nfl_rosters.keys():
		var roster_data = nfl_rosters[team_id]
		if roster_data is Dictionary:
			var roster_players = roster_data.get("players", [])
			players_data.append_array(roster_players)
		elif roster_data is Array:
			# Handle legacy format where roster might be direct array
			players_data.append_array(roster_data)

	print("DatabasePersistence: Saving %d NFL players from rosters" % players_data.size())

	# Save players first (teams reference players via roster)
	for player_data in players_data:
		var player = _convert_player_data(player_data)
		if player == null:
			var player_id = String(player_data.get("id", "unknown"))
			push_warning("DatabasePersistence: Skipped invalid player data: %s" % player_id)
			continue

		if not _player_dao.save(player):
			push_warning("DatabasePersistence: Failed to save player: %s" % player.id)
			success = false
			break
		else:
			player_count += 1

	# Save teams if players saved successfully
	if success:
		# Use nfl_teams array from world_state
		var teams_data = world_state.get("nfl_teams", [])
		print("DatabasePersistence: Saving %d NFL teams" % teams_data.size())

		for team_data in teams_data:
			var team = _convert_team_data(team_data)
			if team == null:
				var team_id = String(team_data.get("id", "unknown"))
				push_warning("DatabasePersistence: Skipped invalid team data: %s" % team_id)
				continue

			if not _team_dao.save(team):
				push_warning("DatabasePersistence: Failed to save team: %s" % team.id)
				success = false
				break
			else:
				team_count += 1

	# Commit or rollback based on success
	if success:
		if not commit_transaction():
			success = false
		else:
			print("DatabasePersistence: Successfully saved %d players, %d teams" % [player_count, team_count])
	else:
		rollback_transaction()
		push_error("DatabasePersistence: Save failed, rolling back transaction")

	close_database()
	return success

## Load complete world state from database
## @param save_name: Database identifier
## @return: World state dictionary (empty on failure)
func load_world_state(save_name: String) -> Dictionary:
	if not open_database(save_name):
		return {}

	# Initialize DAOs
	_player_dao = PlayerDAO.new(_db)
	_team_dao = TeamDAO.new(_db, _player_dao)

	var world_state = {}

	# Load all players
	print("DatabasePersistence: Loading players from database")
	var players = _player_dao.load_all()
	var players_data = []
	for player in players:
		players_data.append(_convert_player_to_dict(player))

	# Store as nfl_players (flat array) for compatibility with verification script
	world_state["nfl_players"] = players_data
	print("DatabasePersistence: Loaded %d NFL players" % players_data.size())

	# Load all teams
	print("DatabasePersistence: Loading teams from database")
	var teams = _team_dao.load_all(false)  # Load without full player objects (just IDs)
	var teams_data = []
	for team in teams:
		teams_data.append(_convert_team_to_dict(team))

	# Store as nfl_teams (matches world_state structure)
	world_state["nfl_teams"] = teams_data
	print("DatabasePersistence: Loaded %d NFL teams" % teams_data.size())

	# Reconstruct nfl_rosters structure (Dictionary mapping team_id -> roster with players)
	# This ensures compatibility with the full world_state structure
	var nfl_rosters: Dictionary = {}
	for team_dict in teams_data:
		var team_id = team_dict.get("id", "")
		if team_id.is_empty():
			continue

		# Get players for this team
		var team_players: Array = []
		for player_dict in players_data:
			if player_dict.get("nfl_team_id", "") == team_id:
				team_players.append(player_dict)

		# Create roster structure
		nfl_rosters[team_id] = {
			"players": team_players,
			"starters": team_dict.get("starters", {}),
			"depth_chart": team_dict.get("depth_chart", {})
		}

	world_state["nfl_rosters"] = nfl_rosters
	print("DatabasePersistence: Reconstructed %d NFL rosters" % nfl_rosters.size())

	close_database()
	return world_state

# =========================
# Entity Operations (Future)
# =========================

## Save single player
## @param player: Player resource to save
## @return: true on success, false on failure
func save_player(player: Resource) -> bool:
	push_warning("DatabasePersistence.save_player: Not yet implemented (requires PlayerDAO)")
	return false

## Query players with filters
## @param filters: Query filters {position: "QB", age_min: 21, stage: 3}
## @return: Array of Player resources
func query_players(filters: Dictionary) -> Array:
	push_warning("DatabasePersistence.query_players: Not yet implemented (requires PlayerDAO)")
	return []

## List available database saves
## @return: Array of save names (without .db extension)
func list_saves() -> Array[String]:
	var saves: Array[String] = []

	if not DirAccess.dir_exists_absolute(DB_DIR):
		return saves

	var dir = DirAccess.open(DB_DIR)
	if not dir:
		push_error("DatabasePersistence: Failed to open database directory: %s" % DB_DIR)
		return saves

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".db"):
			saves.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	return saves

## Delete a database save
## @param save_name: Save identifier to delete
## @return: true on success, false on failure
func delete_save(save_name: String) -> bool:
	var path = DB_DIR + save_name + ".db"

	if not FileAccess.file_exists(path):
		push_warning("DatabasePersistence: Database file not found for deletion: %s" % path)
		return false

	var result = DirAccess.remove_absolute(path)
	if result != OK:
		push_error("DatabasePersistence: Failed to delete database: %s (error: %d)" % [path, result])
		return false

	print("DatabasePersistence: Deleted database: %s" % path)
	return true

# =========================
# Private: Data Conversion
# =========================

## Convert player dictionary to Player resource
## @param data: Player data dictionary from world_state
## @return: Player resource, or null on failure
func _convert_player_data(data) -> Player:
	if not data is Dictionary:
		return null

	var player_dict: Dictionary = data as Dictionary

	# Validate required fields
	if not player_dict.has("id") or String(player_dict["id"]).is_empty():
		return null
	if not player_dict.has("position"):
		return null

	var player = Player.new()

	# Use the Player's from_dict method for proper conversion
	# This handles backward compatibility with legacy save formats
	player.from_dict(player_dict)

	return player

## Convert team dictionary to Team resource
## @param data: Team data dictionary from world_state
## @return: Team resource, or null on failure
func _convert_team_data(data) -> Team:
	if not data is Dictionary:
		return null

	var team_dict: Dictionary = data as Dictionary

	# Validate required fields
	if not team_dict.has("id") or String(team_dict["id"]).is_empty():
		return null
	if not team_dict.has("name") or String(team_dict["name"]).is_empty():
		return null

	# Create a mutable copy for modification
	var clean_dict = team_dict.duplicate(true)

	# Remove roster data - we handle players separately via nfl_rosters
	# The Team.roster field can be problematic with legacy formats, and we reconstruct
	# roster relationships from PlayerDAO player data (via nfl_team_id field)
	if clean_dict.has("roster"):
		clean_dict.erase("roster")

	var team = Team.new()

	# Use the Team's from_dict method for proper conversion
	team.from_dict(clean_dict)

	return team

## Convert Player resource to dictionary
## @param player: Player resource
## @return: Dictionary representation
func _convert_player_to_dict(player: Player) -> Dictionary:
	return player.to_dict()

## Convert Team resource to dictionary
## @param team: Team resource
## @return: Dictionary representation
func _convert_team_to_dict(team: Team) -> Dictionary:
	return team.to_dict()
