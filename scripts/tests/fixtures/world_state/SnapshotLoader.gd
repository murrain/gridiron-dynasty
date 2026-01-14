## World State Snapshot Loader
##
## Provides world state setup for testing via setup_world().
##
## USAGE:
##   # Generate fresh 3-year world
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0xSEED001)
##
##   # Load 10yr snapshot as-is (0 additional years)
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0xSEED001)
##
##   # Load 10yr snapshot + simulate 2 more years
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 2, 0xSEED001)
##
## Performance:
##   - Loading snapshot: instant (cached)
##   - Each additional year: ~10-15 seconds
##
## Regenerate snapshots by running:
##   godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
##
## Adding new snapshots:
##   1. Add entry to snapshot_config.json with year key and filename
##   2. Add constant below (e.g., const YEAR_30 := 30)
##   3. Regenerate snapshots with SnapshotGenerator.gd
class_name SnapshotLoader
extends RefCounted

const FIXTURE_PATH := "res://scripts/tests/fixtures/world_state/"
const CONFIG_FILE := "res://scripts/tests/fixtures/world_state/snapshot_config.json"

## Base world state constants for setup_world()
## Add new constants here when adding snapshots to snapshot_config.json
const FRESH := 0       ## Generate from scratch
const YEAR_5 := 5      ## Load 5-year snapshot
const YEAR_10 := 10    ## Load 10-year snapshot
const YEAR_20 := 20    ## Load 20-year snapshot

## Schema version - MUST match SnapshotGenerator.SNAPSHOT_SCHEMA_VERSION
## If mismatch detected, snapshots must be regenerated
const SNAPSHOT_SCHEMA_VERSION := 1

## Cache loaded snapshots to avoid re-parsing JSON.
static var _cache: Dictionary = {}

## Loaded config from snapshot_config.json
static var _config: Dictionary = {}

## Get the deterministic seed from config (for verification)
static func get_snapshot_seed() -> int:
	_ensure_config_loaded()
	return int(_config.get("deterministic_seed", 0x7E572026))

## Set up a world state for testing.
##
## This is the primary entry point for tests that need world state data.
##
## Parameters:
##   base: Which snapshot to start from (FRESH, YEAR_5, YEAR_10, YEAR_20)
##   years: Additional years to simulate (0 = just load snapshot)
##   seed: Seed for deterministic simulation
##
## Returns:
##   A world state dictionary (always an isolated copy, safe to mutate).
##
## Examples:
##   # Generate fresh 3-year world
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0xSEED001)
##
##   # Load 10yr snapshot, no additional simulation
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0xSEED001)
##
##   # Load 5yr snapshot + 2 more years
##   var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 2, 0xTRADE001)
static func setup_world(base: int, years: int, seed: int) -> Dictionary:
	if seed == 0:
		push_error("SnapshotLoader: seed required (cannot be 0)")
		return {}

	var world_state: Dictionary = {}

	# Load base snapshot if specified
	if base == FRESH:
		if years <= 0:
			push_error("SnapshotLoader: years must be > 0 when generating fresh")
			return {}
		# Generate fresh using BootstrapGameWorld
		const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
		var bootstrap := BootstrapGameWorld.new()
		bootstrap.years_to_simulate = years
		var result := bootstrap.run(seed, false)
		return result.get("world_state", {})
	else:
		# Load snapshot from config
		var filename := _get_snapshot_filename(base)
		if filename.is_empty():
			push_error("SnapshotLoader: Invalid base %d. Use FRESH or a year defined in snapshot_config.json." % base)
			return {}
		world_state = _deep_copy(_load_snapshot(filename))

	if world_state.is_empty():
		return {}

	# If no additional years, return the snapshot copy
	if years <= 0:
		return world_state

	# Simulate additional years
	const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
	var advancer := AdvanceWorldYear.new()
	advancer.set_bootstrap_mode(true)  # Skip reports for test performance

	var current_year: int = int(world_state.get("current_year", 2020))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for i in range(years):
		var year_seed := rng.randi()
		var result := advancer.run(world_state, current_year, year_seed)
		world_state = result.get("world_state", world_state)
		current_year += 1

	return world_state

## Clear the snapshot cache
static func clear_cache() -> void:
	_cache.clear()

## Check if a snapshot file exists
static func snapshot_exists(filename: String) -> bool:
	var path := FIXTURE_PATH + filename
	return FileAccess.file_exists(path)

## Get available snapshots with their metadata
static func list_available() -> Array:
	_ensure_config_loaded()
	var available: Array = []
	var snapshots: Dictionary = _config.get("snapshots", {})

	for year_key in snapshots.keys():
		var snapshot_info: Dictionary = snapshots[year_key]
		var filename: String = snapshot_info.get("filename", "")
		if snapshot_exists(filename):
			_load_snapshot(filename)
			var full_snapshot: Dictionary = _cache.get(filename, {})
			var metadata: Dictionary = full_snapshot.get("_metadata", {})
			available.append({
				"year": int(year_key),
				"filename": filename,
				"description": snapshot_info.get("description", ""),
				"years": metadata.get("years_simulated", 0),
				"generated_at": metadata.get("generated_at", "unknown"),
				"seed": metadata.get("seed", 0),
				"summary": metadata.get("summary", {})
			})

	return available

## Get list of available snapshot years from config
static func get_available_years() -> Array:
	_ensure_config_loaded()
	var snapshots: Dictionary = _config.get("snapshots", {})
	var years: Array = []
	for year_key in snapshots.keys():
		years.append(int(year_key))
	years.sort()
	return years

## Internal: Ensure config is loaded
static func _ensure_config_loaded() -> void:
	if not _config.is_empty():
		return

	if not FileAccess.file_exists(CONFIG_FILE):
		push_error("SnapshotLoader: Config file not found: %s" % CONFIG_FILE)
		return

	var file := FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if file == null:
		push_error("SnapshotLoader: Failed to open config: %s" % CONFIG_FILE)
		return

	var json_string := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_string)
	if parsed == null or not parsed is Dictionary:
		push_error("SnapshotLoader: Failed to parse config JSON")
		return

	_config = parsed

## Internal: Get snapshot filename for a given year
static func _get_snapshot_filename(years: int) -> String:
	_ensure_config_loaded()
	var snapshots: Dictionary = _config.get("snapshots", {})
	var year_key := str(years)

	if not snapshots.has(year_key):
		return ""

	var snapshot_info: Dictionary = snapshots[year_key]
	return snapshot_info.get("filename", "")

## Internal: Load and cache a snapshot file
static func _load_snapshot(filename: String) -> Dictionary:
	if _cache.has(filename):
		return _cache[filename].get("world_state", {})

	var path := FIXTURE_PATH + filename

	if not FileAccess.file_exists(path):
		push_error("SnapshotLoader: Snapshot not found: %s" % path)
		push_error("Run: godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd")
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SnapshotLoader: Failed to open: %s" % path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var snapshot = JSON.parse_string(json_string)
	if snapshot == null:
		push_error("SnapshotLoader: Failed to parse JSON: %s" % path)
		return {}

	if not snapshot is Dictionary:
		push_error("SnapshotLoader: Invalid snapshot structure: %s" % path)
		return {}

	var snapshot_dict: Dictionary = snapshot
	if not snapshot_dict.has("world_state"):
		push_error("SnapshotLoader: Snapshot missing world_state: %s" % path)
		return {}

	if not _validate_schema_version(snapshot_dict, path):
		return {}

	_cache[filename] = snapshot_dict
	return snapshot_dict.get("world_state", {})

## Internal: Validate snapshot schema version
static func _validate_schema_version(snapshot: Dictionary, path: String) -> bool:
	var metadata: Dictionary = snapshot.get("_metadata", {})
	var snapshot_version: int = int(metadata.get("schema_version", 0))

	if snapshot_version == 0:
		push_error("SnapshotLoader: Snapshot has no schema_version: %s" % path)
		push_error("Regenerate: godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd")
		return false

	if snapshot_version != SNAPSHOT_SCHEMA_VERSION:
		push_error("SnapshotLoader: Schema version mismatch in %s" % path)
		push_error("  Expected: v%d, Found: v%d" % [SNAPSHOT_SCHEMA_VERSION, snapshot_version])
		push_error("  Regenerate: godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd")
		return false

	return true

## Internal: Deep copy a dictionary
static func _deep_copy(source: Dictionary) -> Dictionary:
	return source.duplicate(true)
