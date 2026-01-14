## World State Snapshot Generator
##
## Generates deterministic world state snapshots for use in testing features
## that require mature simulation data.
##
## Usage:
##   godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
##
## Output files are defined in snapshot_config.json.
##
## These snapshots enable instant loading of mature world states instead of
## regenerating years of simulation data for each test run.
##
## Determinism: Uses seed from config for reproducible snapshots.
## Regenerate snapshots when:
##   - Config schema changes
##   - Player model changes
##   - World state schema changes
##   - Simulation logic changes materially
extends SceneTree

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

const CONFIG_FILE := "res://scripts/tests/fixtures/world_state/snapshot_config.json"
const OUTPUT_DIR := "res://scripts/tests/fixtures/world_state/"

# Schema version - INCREMENT when world_state structure changes
# This enables detection of stale snapshots after model changes
const SNAPSHOT_SCHEMA_VERSION := 1

var _config: Dictionary = {}

func _init() -> void:
	if not _load_config():
		push_error("SnapshotGenerator: Failed to load config")
		quit(1)
		return

	var snapshot_seed: int = int(_config.get("deterministic_seed", 0x7E572026))
	var snapshots: Dictionary = _config.get("snapshots", {})

	print("=" .repeat(80))
	print("WORLD STATE SNAPSHOT GENERATOR")
	print("=" .repeat(80))
	print("Seed: 0x%X" % snapshot_seed)
	print("Config: %s" % CONFIG_FILE)
	print("")

	var total_start := Time.get_ticks_usec()
	var generated_files: Array = []

	# Sort years for consistent output order
	var years_to_generate: Array = []
	for year_key in snapshots.keys():
		years_to_generate.append(int(year_key))
	years_to_generate.sort()

	for years in years_to_generate:
		var year_key := str(years)
		var snapshot_info: Dictionary = snapshots[year_key]
		var result := _generate_snapshot(
			years,
			snapshot_info.get("filename", "snapshot_%dyr.json" % years),
			snapshot_info.get("description", ""),
			snapshot_seed
		)
		if result["success"]:
			generated_files.append(result)

	var total_time := (Time.get_ticks_usec() - total_start) / 1_000_000.0

	print("")
	print("=" .repeat(80))
	print("SNAPSHOT GENERATION COMPLETE")
	print("=" .repeat(80))
	print("Total time: %.2f seconds" % total_time)
	print("")
	print("Generated files:")
	for file_info in generated_files:
		print("  - %s (%.2f MB, %d years)" % [
			file_info["filename"],
			file_info["size_mb"],
			file_info["years"]
		])
	print("")
	print("Use SnapshotLoader.setup_world() to load these in tests:")
	print("  var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x7E57001)")
	print("=" .repeat(80))

	quit(0)

func _load_config() -> bool:
	if not FileAccess.file_exists(CONFIG_FILE):
		push_error("SnapshotGenerator: Config file not found: %s" % CONFIG_FILE)
		return false

	var file := FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if file == null:
		push_error("SnapshotGenerator: Failed to open config: %s" % CONFIG_FILE)
		return false

	var json_string := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_string)
	if parsed == null or not parsed is Dictionary:
		push_error("SnapshotGenerator: Failed to parse config JSON")
		return false

	_config = parsed
	return true

func _generate_snapshot(years: int, filename: String, description: String, seed: int) -> Dictionary:
	print("[%d-year] Generating: %s" % [years, description])
	var start := Time.get_ticks_usec()

	# Run bootstrap simulation
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = years
	var result := bootstrap.run(seed, false)

	var gen_time := (Time.get_ticks_usec() - start) / 1000.0
	print("  Simulation: %.2f ms" % gen_time)

	# Extract world state
	var world_state: Dictionary = result.get("world_state", {})
	if world_state.is_empty():
		push_error("  ERROR: Empty world state returned")
		return {"success": false}

	# Add metadata to snapshot (including schema version for evolution tracking)
	var snapshot := {
		"_metadata": {
			"generator": "SnapshotGenerator.gd",
			"schema_version": SNAPSHOT_SCHEMA_VERSION,
			"godot_version": Engine.get_version_info().get("string", "unknown"),
			"generated_at": Time.get_datetime_string_from_system(),
			"seed": seed,
			"years_simulated": years,
			"description": description,
			"summary": result.get("summary", {})
		},
		"world_state": world_state
	}

	# Serialize to JSON
	var json_string := JSON.stringify(snapshot, "\t")

	# Save to file
	var path := OUTPUT_DIR + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("  ERROR: Failed to open file for writing: %s" % path)
		return {"success": false}

	file.store_string(json_string)
	file.close()

	# Get file size
	var size_mb := _get_file_size_mb(path)
	var total_time := (Time.get_ticks_usec() - start) / 1000.0

	print("  Saved: %s (%.2f MB)" % [filename, size_mb])
	print("  Total: %.2f ms" % total_time)
	print("")

	return {
		"success": true,
		"filename": filename,
		"years": years,
		"size_mb": size_mb,
		"time_ms": total_time
	}

func _get_file_size_mb(path: String) -> float:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0.0
	var size := file.get_length()
	file.close()
	return size / (1024.0 * 1024.0)
