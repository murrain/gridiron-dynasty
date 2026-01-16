## PersistenceLayer Autoload
## Provides unified interface for world state persistence with pluggable backends
## Supports JSON (current/legacy) and SQLite (high-performance) storage
extends Node

const JSONPersistence = preload("res://scripts/persistence/JSONPersistence.gd")
const DatabasePersistence = preload("res://scripts/persistence/DatabasePersistence.gd")

## Persistence backend types
enum Backend {
	JSON,    ## File-based JSON storage (current implementation)
	SQLITE   ## SQLite database storage (new high-performance backend)
}

## Current active backend
var current_backend: Backend = Backend.JSON

## Backend implementations
var _json_handler: JSONPersistence = null
var _db_handler: DatabasePersistence = null

## Initialize persistence layer
func _ready() -> void:
	_json_handler = JSONPersistence.new()
	_db_handler = DatabasePersistence.new()
	print("PersistenceLayer: Initialized with %s backend" % Backend.keys()[current_backend])

# =========================
# Backend Management
# =========================

## Set active persistence backend
## @param backend: Backend enum value (JSON or SQLITE)
func set_backend(backend: Backend) -> void:
	current_backend = backend
	print("PersistenceLayer: Switched to %s backend" % Backend.keys()[backend])

## Get current backend type
## @return: Current Backend enum value
func get_backend() -> Backend:
	return current_backend

## Check if a specific backend is available
## @param backend: Backend to check
## @return: true if backend is available, false otherwise
func is_backend_available(backend: Backend) -> bool:
	match backend:
		Backend.JSON:
			return _json_handler != null
		Backend.SQLITE:
			return _db_handler != null
	return false

# =========================
# World State Operations
# =========================

## Save complete world state
## Routes to active backend (JSON or SQLite)
## @param world_state: Dictionary containing all game entities
## @param save_name: Identifier for this save (filename without extension)
## @return: true on success, false on failure
func save_world_state(world_state: Dictionary, save_name: String) -> bool:
	if save_name.is_empty():
		push_error("PersistenceLayer: save_name cannot be empty")
		return false

	if world_state.is_empty():
		push_warning("PersistenceLayer: world_state is empty, saving anyway")

	match current_backend:
		Backend.JSON:
			return _json_handler.save_world_state(world_state, save_name)
		Backend.SQLITE:
			return _db_handler.save_world_state(world_state, save_name)

	push_error("PersistenceLayer: Invalid backend: %d" % current_backend)
	return false

## Load complete world state
## Routes to active backend (JSON or SQLite)
## @param save_name: Identifier for save to load
## @return: World state dictionary (empty on failure)
func load_world_state(save_name: String) -> Dictionary:
	if save_name.is_empty():
		push_error("PersistenceLayer: save_name cannot be empty")
		return {}

	match current_backend:
		Backend.JSON:
			return _json_handler.load_world_state(save_name)
		Backend.SQLITE:
			return _db_handler.load_world_state(save_name)

	push_error("PersistenceLayer: Invalid backend: %d" % current_backend)
	return {}

## List available save files for current backend
## @return: Array of save names (without extension)
func list_saves() -> Array[String]:
	match current_backend:
		Backend.JSON:
			return _json_handler.list_saves()
		Backend.SQLITE:
			return _db_handler.list_saves()

	push_error("PersistenceLayer: Invalid backend: %d" % current_backend)
	return []

## Delete a save file
## @param save_name: Save identifier to delete
## @return: true on success, false on failure
func delete_save(save_name: String) -> bool:
	if save_name.is_empty():
		push_error("PersistenceLayer: save_name cannot be empty")
		return false

	match current_backend:
		Backend.JSON:
			return _json_handler.delete_save(save_name)
		Backend.SQLITE:
			return _db_handler.delete_save(save_name)

	push_error("PersistenceLayer: Invalid backend: %d" % current_backend)
	return false

## Check if a save exists
## @param save_name: Save identifier to check
## @return: true if save exists, false otherwise
func save_exists(save_name: String) -> bool:
	var saves = list_saves()
	return saves.has(save_name)

# =========================
# Transaction Support
# =========================

## Begin database transaction
## Only applicable to SQLite backend, no-op for JSON
## @return: true on success, false on failure
func begin_transaction() -> bool:
	if current_backend == Backend.SQLITE:
		return _db_handler.begin_transaction()
	return true  # JSON doesn't support transactions, return success

## Commit database transaction
## Only applicable to SQLite backend, no-op for JSON
## @return: true on success, false on failure
func commit_transaction() -> bool:
	if current_backend == Backend.SQLITE:
		return _db_handler.commit_transaction()
	return true

## Rollback database transaction
## Only applicable to SQLite backend, no-op for JSON
## @return: true on success, false on failure
func rollback_transaction() -> bool:
	if current_backend == Backend.SQLITE:
		return _db_handler.rollback_transaction()
	return true

# =========================
# Entity-Level Operations
# =========================
# These operations are primarily for SQLite backend
# JSON backend saves entire world state at once

## Save single player (SQLite only)
## @param player: Player resource to save
## @return: true on success, false on failure
func save_player(player: Resource) -> bool:
	if current_backend == Backend.SQLITE:
		return _db_handler.save_player(player)

	push_warning("PersistenceLayer.save_player: Not supported for JSON backend")
	return false

## Query players with filters (SQLite only)
## @param filters: Query filters {position: "QB", age_min: 21, stage: 3}
## @return: Array of Player resources
func query_players(filters: Dictionary = {}) -> Array:
	if current_backend == Backend.SQLITE:
		return _db_handler.query_players(filters)

	push_warning("PersistenceLayer.query_players: Not supported for JSON backend")
	return []

# =========================
# Utility Methods
# =========================

## Get backend statistics
## @return: Dictionary with backend-specific stats
func get_backend_stats() -> Dictionary:
	var stats = {
		"current_backend": Backend.keys()[current_backend],
		"json_available": is_backend_available(Backend.JSON),
		"sqlite_available": is_backend_available(Backend.SQLITE),
		"save_count": list_saves().size()
	}
	return stats

## Migrate save from one backend to another
## This is a placeholder for ARCH-021 (migration tool)
## @param save_name: Save to migrate
## @param from_backend: Source backend
## @param to_backend: Destination backend
## @return: true on success, false on failure
func migrate_save(save_name: String, from_backend: Backend, to_backend: Backend) -> bool:
	if from_backend == to_backend:
		push_error("PersistenceLayer: Cannot migrate to same backend")
		return false

	# Load from source backend
	var original_backend = current_backend
	set_backend(from_backend)
	var world_state = load_world_state(save_name)

	if world_state.is_empty():
		push_error("PersistenceLayer: Failed to load from source backend")
		set_backend(original_backend)
		return false

	# Save to destination backend
	set_backend(to_backend)
	var success = save_world_state(world_state, save_name + "_migrated")

	# Restore original backend
	set_backend(original_backend)

	if success:
		print("PersistenceLayer: Migrated save '%s' from %s to %s" %
			[save_name, Backend.keys()[from_backend], Backend.keys()[to_backend]])
	else:
		push_error("PersistenceLayer: Failed to save to destination backend")

	return success
