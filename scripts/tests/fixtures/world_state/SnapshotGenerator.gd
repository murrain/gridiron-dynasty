## World State Snapshot Generator
##
## Generates deterministic world state snapshots at 5, 10, and 20 year marks
## for use in testing features that require mature simulation data.
##
## Usage:
##   godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
##
## Output:
##   - snapshot_5yr.json (~5-10 MB)
##   - snapshot_10yr.json (~15-20 MB)
##   - snapshot_20yr.json (~30-40 MB)
##
## These snapshots enable instant loading of mature world states instead of
## regenerating 20 years of simulation data for each test run.
##
## Determinism: Uses fixed seed 0xTEST_2026 to ensure reproducible snapshots.
## Regenerate snapshots when:
##   - Config schema changes
##   - Player model changes
##   - World state schema changes
##   - Simulation logic changes materially
extends SceneTree

const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

# Fixed seed for reproducible snapshots across regenerations
const SNAPSHOT_SEED := 0x7E572026  # TEST_2026 in hex-ish

# Schema version - INCREMENT when world_state structure changes
# This enables detection of stale snapshots after model changes
const SNAPSHOT_SCHEMA_VERSION := 1

# Snapshot configurations
const SNAPSHOTS := [
	{"years": 5, "filename": "snapshot_5yr.json", "description": "Basic rosters, recruiting data"},
	{"years": 10, "filename": "snapshot_10yr.json", "description": "Trade tests, contract history"},
	{"years": 20, "filename": "snapshot_20yr.json", "description": "HoF, dynasty, long-term trends"}
]

# Output directory (relative to this script)
const OUTPUT_DIR := "res://scripts/tests/fixtures/world_state/"

func _init() -> void:
	print("=" .repeat(80))
	print("WORLD STATE SNAPSHOT GENERATOR")
	print("=" .repeat(80))
	print("Seed: 0x%X" % SNAPSHOT_SEED)
	print("")

	var total_start := Time.get_ticks_usec()
	var generated_files: Array = []

	for snapshot in SNAPSHOTS:
		var result := _generate_snapshot(
			snapshot["years"],
			snapshot["filename"],
			snapshot["description"]
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
	print("Use SnapshotLoader.gd to load these in tests:")
	print("  var world_state := SnapshotLoader.load_10yr()")
	print("=" .repeat(80))

	quit(0)

func _generate_snapshot(years: int, filename: String, description: String) -> Dictionary:
	print("[%d-year] Generating: %s" % [years, description])
	var start := Time.get_ticks_usec()

	# Run bootstrap simulation
	var bootstrap := BootstrapGameWorld.new()
	bootstrap.years_to_simulate = years
	var result := bootstrap.run(SNAPSHOT_SEED, false)

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
			"seed": SNAPSHOT_SEED,
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
