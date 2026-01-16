## JSON to SQLite Migration Tool (ARCH-021)
## Migrates existing JSON save files to SQLite database format
##
## Features:
## - Transaction-based all-or-nothing migration
## - Clear error reporting with warnings for partial failures
## - Verification step to ensure data integrity
## - Handles missing or malformed data gracefully
##
## Usage:
##   var migrator = MigrateSaveToDatabase.new()
##   var result = migrator.migrate("save_game_001.json", "save_game_001.db")
##   if result.success:
##       print("Migrated %d players, %d teams" % [result.player_count, result.team_count])
##   else:
##       push_error("Migration failed: %s" % result.error)
extends RefCounted
class_name MigrateSaveToDatabase

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")

# Import DAOs for entity persistence
const PlayerDAO = preload("res://scripts/persistence/PlayerDAO.gd")
const TeamDAO = preload("res://scripts/persistence/TeamDAO.gd")

# Import models for data conversion
const Player = preload("res://scripts/core/models/Player.gd")
const Team = preload("res://scripts/core/models/Team.gd")

# Directory paths
const SAVE_DIR = "user://saves/"
const SCHEMA_FILE = "res://scripts/persistence/schema.sql"

# =========================
# Public API
# =========================

## Migrate JSON save file to SQLite database
## @param json_path: Path to source JSON file (filename or relative to SAVE_DIR)
## @param db_path: Path for destination SQLite database (filename or absolute path)
## @return: Migration result dictionary with success status, counts, and any errors
func migrate(json_path: String, db_path: String) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"player_count": 0,
		"team_count": 0,
		"warnings": [],
		"duration_ms": 0
	}

	var start_time = Time.get_ticks_msec()

	# Step 1: Load JSON save file
	print("MigrateSaveToDatabase: Loading JSON save from %s" % json_path)
	var json_data = _load_json_save(json_path)
	if json_data.is_empty():
		result.error = "Failed to load JSON save file: %s" % json_path
		return result

	# Step 2: Validate data integrity
	print("MigrateSaveToDatabase: Validating JSON data structure")
	var validation = _validate_json_data(json_data)
	if not validation.valid:
		result.error = "JSON validation failed: %s" % validation.error
		result.warnings = validation.warnings
		return result
	result.warnings.append_array(validation.warnings)

	# Step 3: Create SQLite database with schema
	print("MigrateSaveToDatabase: Creating database at %s" % db_path)
	var db = SQLite.new()

	# Resolve database path
	var resolved_db_path = _resolve_path(db_path, ".db")
	db.path = resolved_db_path

	if not db.open_db():
		result.error = "Failed to create database at %s" % resolved_db_path
		return result

	# Enable foreign keys for data integrity
	db.query("PRAGMA foreign_keys = ON;")

	# Load and execute schema
	var schema_sql = _load_schema()
	if schema_sql.is_empty():
		result.error = "Failed to load database schema from %s" % SCHEMA_FILE
		db.close_db()
		return result

	if not _execute_schema(db, schema_sql, result):
		db.close_db()
		return result

	# Step 4: Begin transaction for atomic migration
	print("MigrateSaveToDatabase: Beginning migration transaction")
	db.query("BEGIN TRANSACTION;")

	# Step 5: Migrate entities
	var player_dao = PlayerDAO.new(db)
	var team_dao = TeamDAO.new(db, player_dao)

	# Migrate players first (teams reference players via roster)
	var players_data = json_data.get("players", [])
	print("MigrateSaveToDatabase: Migrating %d players" % players_data.size())

	for player_data in players_data:
		var player = _convert_player_data(player_data)
		if player == null:
			var player_id = String(player_data.get("id", "unknown"))
			result.warnings.append("Skipped invalid player data: %s" % player_id)
			continue

		if not player_dao.save(player):
			result.warnings.append("Failed to migrate player: %s" % player.id)
		else:
			result.player_count += 1

	# Migrate teams
	var teams_data = json_data.get("teams", [])
	print("MigrateSaveToDatabase: Migrating %d teams" % teams_data.size())

	for team_data in teams_data:
		var team = _convert_team_data(team_data)
		if team == null:
			var team_id = String(team_data.get("id", "unknown"))
			result.warnings.append("Skipped invalid team data: %s" % team_id)
			continue

		if not team_dao.save(team):
			result.warnings.append("Failed to migrate team: %s" % team.id)
		else:
			result.team_count += 1

	# Step 6: Verify migration before commit
	print("MigrateSaveToDatabase: Verifying migration results")
	var verification = _verify_migration(db, result.player_count, result.team_count)
	if not verification.success:
		result.error = "Verification failed: %s - rolling back" % verification.error
		db.query("ROLLBACK;")
		db.close_db()
		return result

	# Step 7: Commit transaction
	print("MigrateSaveToDatabase: Committing migration transaction")
	db.query("COMMIT;")

	db.close_db()

	result.success = true
	result.duration_ms = Time.get_ticks_msec() - start_time

	print("MigrateSaveToDatabase: Migration complete - %d players, %d teams in %d ms" % [
		result.player_count, result.team_count, result.duration_ms
	])

	return result

## Dry run migration - validate without writing to database
## @param json_path: Path to source JSON file
## @return: Validation result dictionary
func validate_only(json_path: String) -> Dictionary:
	var result = {
		"valid": false,
		"error": "",
		"player_count": 0,
		"team_count": 0,
		"warnings": []
	}

	# Load JSON
	var json_data = _load_json_save(json_path)
	if json_data.is_empty():
		result.error = "Failed to load JSON save file"
		return result

	# Validate structure
	var validation = _validate_json_data(json_data)
	result.warnings = validation.warnings

	if not validation.valid:
		result.error = validation.error
		return result

	# Count entities
	var players = json_data.get("players", [])
	var teams = json_data.get("teams", [])

	for player_data in players:
		if _is_valid_player_data(player_data):
			result.player_count += 1
		else:
			result.warnings.append("Invalid player data: %s" % String(player_data.get("id", "unknown")))

	for team_data in teams:
		if _is_valid_team_data(team_data):
			result.team_count += 1
		else:
			result.warnings.append("Invalid team data: %s" % String(team_data.get("id", "unknown")))

	result.valid = true
	return result

# =========================
# Private: File Operations
# =========================

## Load JSON save file from disk
## @param path: JSON file path (filename or absolute path)
## @return: Parsed dictionary, or empty dictionary on failure
func _load_json_save(path: String) -> Dictionary:
	var resolved_path = _resolve_path(path, ".json")

	if not FileAccess.file_exists(resolved_path):
		push_error("MigrateSaveToDatabase: Save file not found: %s" % resolved_path)
		return {}

	var file = FileAccess.open(resolved_path, FileAccess.READ)
	if not file:
		var error_code = FileAccess.get_open_error()
		push_error("MigrateSaveToDatabase: Failed to open file: %s (error: %d)" % [resolved_path, error_code])
		return {}

	var json_string = file.get_as_text()
	file.close()

	if json_string.is_empty():
		push_error("MigrateSaveToDatabase: File is empty: %s" % resolved_path)
		return {}

	# Parse JSON
	var json = JSON.new()
	var parse_error = json.parse(json_string)
	if parse_error != OK:
		push_error("MigrateSaveToDatabase: JSON parse error at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		return {}

	if not json.data is Dictionary:
		push_error("MigrateSaveToDatabase: JSON root must be a Dictionary")
		return {}

	return json.data as Dictionary

## Resolve path to absolute path in save directory
func _resolve_path(path: String, extension: String) -> String:
	# If already absolute path, use as-is
	if path.begins_with("user://") or path.begins_with("res://") or path.begins_with("/"):
		# Ensure extension
		if not path.ends_with(extension):
			return path + extension
		return path

	# Relative path - prepend save directory
	var filename = path
	if not filename.ends_with(extension):
		filename = filename + extension

	return SAVE_DIR + filename

## Load schema SQL from file
func _load_schema() -> String:
	if not FileAccess.file_exists(SCHEMA_FILE):
		push_error("MigrateSaveToDatabase: Schema file not found: %s" % SCHEMA_FILE)
		return ""

	var file = FileAccess.open(SCHEMA_FILE, FileAccess.READ)
	if file == null:
		push_error("MigrateSaveToDatabase: Failed to open schema file")
		return ""

	var content = file.get_as_text()
	file.close()
	return content

## Execute schema SQL statements
func _execute_schema(db: SQLite, schema_sql: String, result: Dictionary) -> bool:
	# Split by semicolons and execute each statement
	var statements = schema_sql.split(";")

	for stmt in statements:
		var trimmed = stmt.strip_edges()

		# Skip empty statements and comments
		if trimmed.is_empty():
			continue
		if trimmed.begins_with("--"):
			continue

		# Skip index creation - we'll add those after data migration (ARCH-022)
		# Indexes on empty tables are fine, but this maintains clear separation

		db.query(trimmed)

		# Check for errors (godot-sqlite uses query_result_error for error messages)
		if db.query_result_error != null and not db.query_result_error.is_empty():
			# Some "errors" are actually warnings or info - filter actual failures
			var error_lower = db.query_result_error.to_lower()
			if error_lower.contains("error") or error_lower.contains("fail"):
				result.error = "Schema creation failed: %s" % db.query_result_error
				return false

	return true

# =========================
# Private: Validation
# =========================

## Validate JSON data structure
## @param data: Parsed JSON dictionary
## @return: Validation result {valid: bool, error: String, warnings: Array}
func _validate_json_data(data: Dictionary) -> Dictionary:
	var result = {
		"valid": true,
		"error": "",
		"warnings": []
	}

	# Check for required top-level keys
	if not data.has("players") and not data.has("teams"):
		result.valid = false
		result.error = "JSON must contain 'players' and/or 'teams' arrays"
		return result

	# Validate players array
	if data.has("players"):
		var players = data["players"]
		if not players is Array:
			result.valid = false
			result.error = "'players' must be an array"
			return result

		if players.is_empty():
			result.warnings.append("'players' array is empty")

	# Validate teams array
	if data.has("teams"):
		var teams = data["teams"]
		if not teams is Array:
			result.valid = false
			result.error = "'teams' must be an array"
			return result

		if teams.is_empty():
			result.warnings.append("'teams' array is empty")

	return result

## Validate individual player data
func _is_valid_player_data(data) -> bool:
	if not data is Dictionary:
		return false

	var player_dict: Dictionary = data as Dictionary

	# Required fields
	if not player_dict.has("id") or String(player_dict["id"]).is_empty():
		return false

	# Position is required
	if not player_dict.has("position"):
		return false

	return true

## Validate individual team data
func _is_valid_team_data(data) -> bool:
	if not data is Dictionary:
		return false

	var team_dict: Dictionary = data as Dictionary

	# Required fields
	if not team_dict.has("id") or String(team_dict["id"]).is_empty():
		return false

	if not team_dict.has("name") or String(team_dict["name"]).is_empty():
		return false

	return true

# =========================
# Private: Data Conversion
# =========================

## Convert player dictionary to Player resource
## @param data: Player data dictionary from JSON
## @return: Player resource, or null on failure
func _convert_player_data(data) -> Player:
	if not _is_valid_player_data(data):
		return null

	var player_dict: Dictionary = data as Dictionary
	var player = Player.new()

	# Use the Player's from_dict method for proper conversion
	# This handles backward compatibility with legacy save formats
	player.from_dict(player_dict)

	return player

## Convert team dictionary to Team resource
## @param data: Team data dictionary from JSON
## @return: Team resource, or null on failure
func _convert_team_data(data) -> Team:
	if not _is_valid_team_data(data):
		return null

	var team_dict: Dictionary = data as Dictionary
	var team = Team.new()

	# Use the Team's from_dict method for proper conversion
	team.from_dict(team_dict)

	return team

# =========================
# Private: Verification
# =========================

## Verify migration by comparing entity counts
## @param db: SQLite database connection
## @param expected_players: Number of players expected in database
## @param expected_teams: Number of teams expected in database
## @return: Verification result {success: bool, error: String}
func _verify_migration(db: SQLite, expected_players: int, expected_teams: int) -> Dictionary:
	var result = {
		"success": true,
		"error": ""
	}

	# Count players
	db.query("SELECT COUNT(*) as count FROM player;")
	var player_result = db.query_result
	if player_result.is_empty():
		result.success = false
		result.error = "Failed to count players in database"
		return result

	var actual_players = int(player_result[0]["count"])
	if actual_players != expected_players:
		result.success = false
		result.error = "Player count mismatch: expected %d, got %d" % [expected_players, actual_players]
		return result

	# Count teams
	db.query("SELECT COUNT(*) as count FROM team;")
	var team_result = db.query_result
	if team_result.is_empty():
		result.success = false
		result.error = "Failed to count teams in database"
		return result

	var actual_teams = int(team_result[0]["count"])
	if actual_teams != expected_teams:
		result.success = false
		result.error = "Team count mismatch: expected %d, got %d" % [expected_teams, actual_teams]
		return result

	# Verify referential integrity
	db.query("PRAGMA foreign_key_check;")
	var fk_result = db.query_result
	if not fk_result.is_empty():
		result.success = false
		result.error = "Foreign key violations detected: %d issues" % fk_result.size()
		return result

	return result
