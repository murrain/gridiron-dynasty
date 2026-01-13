## World State Snapshot Loader
##
## Provides instant loading of pre-generated world state snapshots for testing.
## Use this instead of running BootstrapGameWorld in tests that need mature data.
##
## IMPORTANT - SHARED REFERENCE WARNING:
##   load_*yr() methods return a SHARED REFERENCE from cache for performance.
##   If your test mutates the world_state, you MUST use load_*yr_copy() instead!
##
##   ✅ READ-ONLY TEST (use load_*yr - fast, cached):
##      var world_state := SnapshotLoader.load_10yr()
##      var teams := world_state.get("nfl_teams", [])  # Read only
##
##   ✅ MUTATION TEST (use load_*yr_copy - creates isolated copy):
##      var world_state := SnapshotLoader.load_10yr_copy()
##      world_state["nfl_teams"].append(new_team)  # Safe to mutate
##
##   ❌ INCORRECT (will pollute cache for other tests):
##      var world_state := SnapshotLoader.load_10yr()
##      world_state["nfl_teams"].append(new_team)  # BAD! Mutates shared cache
##
## TEST ISOLATION:
##   Call SnapshotLoader.clear_cache() in test teardown if test execution order
##   might affect results. TestHelpers should call this automatically between tests.
##
## Available snapshots:
##   - load_5yr()  - Basic rosters, recruiting data (~60-90s generation saved)
##   - load_10yr() - Trade tests, contract history (~120-180s saved)
##   - load_20yr() - HoF, dynasty, long-term trends (~240-360s saved)
##
## SETUP: Creating or extending a world state:
##   Generate fresh:
##     var world_state := SnapshotLoader.setup_world({}, 3, 0xFRESH001)
##   Add years to snapshot:
##     var world_state := SnapshotLoader.load_10yr_copy()
##     world_state = SnapshotLoader.setup_world(world_state, 2, 0xTRADE001)
##   Performance: ~10-15s per year simulated.
##
## Regenerate snapshots by running:
##   godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
##
## Seed: 0x7E572026 (deterministic - same seed as BootstrapGameWorld for consistency)
class_name SnapshotLoader
extends RefCounted

const FIXTURE_PATH := "res://scripts/tests/fixtures/world_state/"

## Deterministic seed matching SnapshotGenerator for consistency
const SNAPSHOT_SEED := 0x7E572026

## Schema version - MUST match SnapshotGenerator.SNAPSHOT_SCHEMA_VERSION
## If mismatch detected, snapshots must be regenerated
const SNAPSHOT_SCHEMA_VERSION := 1

## Cache loaded snapshots to avoid re-parsing JSON.
## WARNING: This is shared state. Tests that mutate data MUST use load_*yr_copy().
## Cache is cleared by clear_cache() - call in test teardown for isolation.
static var _cache: Dictionary = {}

## Load 5-year world state snapshot
## Best for: Basic roster tests, recruiting pipeline tests
## Saves: ~60-90 seconds of generation time
static func load_5yr() -> Dictionary:
	return _load_snapshot("snapshot_5yr.json")

## Load 10-year world state snapshot
## Best for: Trade tests, contract history, career progression
## Saves: ~120-180 seconds of generation time
static func load_10yr() -> Dictionary:
	return _load_snapshot("snapshot_10yr.json")

## Load 20-year world state snapshot
## Best for: Hall of Fame, dynasty detection, long-term trend analysis
## Saves: ~240-360 seconds of generation time
static func load_20yr() -> Dictionary:
	return _load_snapshot("snapshot_20yr.json")

## Get metadata from a loaded snapshot (full snapshot, not just world_state)
## Returns generator info, seed, summary statistics
static func get_metadata(snapshot: Dictionary) -> Dictionary:
	return snapshot.get("_metadata", {})

## Get the full snapshot including metadata (for verification)
## Returns the complete snapshot dictionary with _metadata and world_state keys
static func get_full_snapshot_5yr() -> Dictionary:
	_ensure_loaded("snapshot_5yr.json")
	return _cache.get("snapshot_5yr.json", {})

static func get_full_snapshot_10yr() -> Dictionary:
	_ensure_loaded("snapshot_10yr.json")
	return _cache.get("snapshot_10yr.json", {})

static func get_full_snapshot_20yr() -> Dictionary:
	_ensure_loaded("snapshot_20yr.json")
	return _cache.get("snapshot_20yr.json", {})

## Helper to ensure a snapshot is loaded into cache
static func _ensure_loaded(filename: String) -> void:
	if not _cache.has(filename):
		_load_snapshot(filename)

## Verify snapshot integrity (seed matches expected)
## Use get_full_snapshot_*yr() to get the full snapshot for verification
static func verify_snapshot(snapshot: Dictionary, expected_seed: int = 0x7E572026) -> bool:
	var metadata := get_metadata(snapshot)
	var actual_seed := int(metadata.get("seed", 0))
	return actual_seed == expected_seed

## Clear the snapshot cache (useful for memory-sensitive tests)
static func clear_cache() -> void:
	_cache.clear()

## Check if a snapshot file exists
static func snapshot_exists(filename: String) -> bool:
	var path := FIXTURE_PATH + filename
	return FileAccess.file_exists(path)

## Get available snapshots with their metadata
static func list_available() -> Array:
	var available: Array = []
	var filenames := ["snapshot_5yr.json", "snapshot_10yr.json", "snapshot_20yr.json"]

	for filename in filenames:
		if snapshot_exists(filename):
			# Load to populate cache
			_load_snapshot(filename)
			# Get full snapshot from cache to access metadata
			var full_snapshot: Dictionary = _cache.get(filename, {})
			var metadata := get_metadata(full_snapshot)
			available.append({
				"filename": filename,
				"years": metadata.get("years_simulated", 0),
				"generated_at": metadata.get("generated_at", "unknown"),
				"seed": metadata.get("seed", 0),
				"summary": metadata.get("summary", {})
			})

	return available

## Internal: Load and cache a snapshot file
static func _load_snapshot(filename: String) -> Dictionary:
	# Check cache first
	if _cache.has(filename):
		return _cache[filename].get("world_state", {})

	var path := FIXTURE_PATH + filename

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("SnapshotLoader: Snapshot not found: %s" % path)
		push_error("Run: godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd")
		return {}

	# Load and parse JSON
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

	# Validate structure
	if not snapshot is Dictionary:
		push_error("SnapshotLoader: Invalid snapshot structure: %s" % path)
		return {}

	var snapshot_dict: Dictionary = snapshot
	if not snapshot_dict.has("world_state"):
		push_error("SnapshotLoader: Snapshot missing world_state: %s" % path)
		return {}

	# Validate schema version to detect stale snapshots
	if not _validate_schema_version(snapshot_dict, path):
		# Error already logged by _validate_schema_version
		return {}

	# Cache the full snapshot (with metadata)
	_cache[filename] = snapshot_dict

	# Return just the world_state for convenience
	return snapshot_dict.get("world_state", {})

## Create a deep copy of a world state (for tests that mutate state)
static func load_5yr_copy() -> Dictionary:
	var original := load_5yr()
	return _deep_copy(original)

static func load_10yr_copy() -> Dictionary:
	var original := load_10yr()
	return _deep_copy(original)

static func load_20yr_copy() -> Dictionary:
	var original := load_20yr()
	return _deep_copy(original)

## Set up a world state for testing by generating or extending simulation years.
##
## This is the primary entry point for tests that need world state data.
## Use this instead of manually calling BootstrapGameWorld or AdvanceWorldYear.
##
## Parameters:
##   world_state: Existing world state to extend, or empty {} to generate fresh
##   years: Number of years to simulate (must be > 0)
##   seed: Seed for deterministic simulation
##
## Returns:
##   The generated/extended world state.
##
## Performance:
##   Each year: ~10-15 seconds
##
## Examples:
##   # Generate fresh 3-year world state
##   var world_state := SnapshotLoader.setup_world({}, 3, 0xFRESH001)
##
##   # Load 10yr snapshot + simulate 2 more years
##   var world_state := SnapshotLoader.load_10yr_copy()
##   world_state = SnapshotLoader.setup_world(world_state, 2, 0xTRADE001)
static func setup_world(world_state: Dictionary, years: int, seed: int) -> Dictionary:
	if years <= 0:
		push_error("SnapshotLoader: years must be > 0")
		return world_state if not world_state.is_empty() else {}

	if seed == 0:
		push_error("SnapshotLoader: seed required (cannot be 0)")
		return {}

	# If world_state is empty, generate fresh using BootstrapGameWorld
	if world_state.is_empty():
		const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")
		var bootstrap := BootstrapGameWorld.new()
		bootstrap.years_to_simulate = years
		var result := bootstrap.run(seed, false)
		return result.get("world_state", {})

	# Otherwise, extend existing world state
	const AdvanceWorldYear = preload("res://scripts/pipelines/AdvanceWorldYear.gd")
	var advancer := AdvanceWorldYear.new()
	advancer.set_bootstrap_mode(true)  # Skip reports for test performance

	# Get current year from world state, default to 2020 if not found
	var current_year: int = int(world_state.get("current_year", 2020))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	for i in range(years):
		var year_seed := rng.randi()
		var result := advancer.run(world_state, current_year, year_seed)
		world_state = result.get("world_state", world_state)
		current_year += 1

	return world_state

## Internal: Validate snapshot schema version matches current code
## Returns false and logs error if mismatch detected
static func _validate_schema_version(snapshot: Dictionary, path: String) -> bool:
	var metadata: Dictionary = snapshot.get("_metadata", {})
	var snapshot_version: int = int(metadata.get("schema_version", 0))

	# Schema version 0 means old snapshot without versioning - require regeneration
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

## Internal: Deep copy a dictionary (for mutation-safe test data)
##
## Uses Godot 4.x's duplicate(true) which performs recursive deep copy of all
## nested Arrays and Dictionaries. This is fast (~10-50ms for typical snapshots)
## compared to JSON round-trip (~200-500ms).
##
## Use load_*yr() for read-only tests to avoid any copy overhead.
static func _deep_copy(source: Dictionary) -> Dictionary:
	# Godot 4.x duplicate(true) performs recursive deep copy of nested structures
	# This is well-documented and reliable behavior in Godot 4.x
	return source.duplicate(true)
