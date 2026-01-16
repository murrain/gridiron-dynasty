## SQLite-based persistence backend
## Provides high-performance queryable storage for game entities
## Uses normalized schema with PlayerDAO/TeamDAO for entity management
extends RefCounted
class_name DatabasePersistence

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")
# DAOs will be preloaded once they're implemented (ARCH-019, ARCH-020)
# const PlayerDAO = preload("res://scripts/persistence/PlayerDAO.gd")
# const TeamDAO = preload("res://scripts/persistence/TeamDAO.gd")

var _db: SQLite = null
# var _player_dao: PlayerDAO = null
# var _team_dao: TeamDAO = null

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
	var statements = schema_sql.split(";")
	for stmt in statements:
		var trimmed = stmt.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("--"):
			continue

		_db.query(trimmed)
		if _db.query_result_error != null and not _db.query_result_error.is_empty():
			push_error("DatabasePersistence: Schema creation failed: %s\nError: %s" %
				[trimmed.substr(0, 100), _db.query_result_error])
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
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("DatabasePersistence: Failed to begin transaction: %s" % _db.query_result_error)
		return false
	return true

## Commit database transaction
## @return: true on success, false on failure
func commit_transaction() -> bool:
	_db.query("COMMIT")
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("DatabasePersistence: Failed to commit transaction: %s" % _db.query_result_error)
		return false
	return true

## Rollback database transaction
## @return: true on success, false on failure
func rollback_transaction() -> bool:
	_db.query("ROLLBACK")
	if _db.query_result_error != null and not _db.query_result_error.is_empty():
		push_error("DatabasePersistence: Failed to rollback transaction: %s" % _db.query_result_error)
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

	# TODO (ARCH-019): Implement player saving via PlayerDAO
	# TODO (ARCH-020): Implement team/roster saving via TeamDAO

	# Placeholder implementation until DAOs are ready
	push_warning("DatabasePersistence.save_world_state: Not yet implemented (requires PlayerDAO/TeamDAO)")

	close_database()
	return false

## Load complete world state from database
## @param save_name: Database identifier
## @return: World state dictionary (empty on failure)
func load_world_state(save_name: String) -> Dictionary:
	if not open_database(save_name):
		return {}

	# TODO (ARCH-019): Implement player loading via PlayerDAO
	# TODO (ARCH-020): Implement team/roster loading via TeamDAO

	# Placeholder implementation
	push_warning("DatabasePersistence.load_world_state: Not yet implemented (requires PlayerDAO/TeamDAO)")

	close_database()
	return {}

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
