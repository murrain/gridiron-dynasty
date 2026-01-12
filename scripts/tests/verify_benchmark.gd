extends SceneTree
## Quick validation script to verify BenchmarkRunner syntax and structure
##
## This performs static validation only (no actual execution of benchmarks)
## Use this to verify the benchmark implementation is loadable

func _init() -> void:
	print("=".repeat(80))
	print("BENCHMARK RUNNER VALIDATION")
	print("=".repeat(80))
	print("")

	var errors: Array = []

	# Test 1: Load BenchmarkRunner script
	print("Test 1: Loading BenchmarkRunner.gd...")
	var benchmark_script = load("res://scripts/tests/BenchmarkRunner.gd")
	if benchmark_script == null:
		errors.append("Failed to load BenchmarkRunner.gd")
		print("  FAIL: Could not load script")
	else:
		print("  PASS: Script loaded successfully")

	# Test 2: Verify required constants exist
	print("\nTest 2: Verifying constants...")
	if benchmark_script != null:
		var script_source := FileAccess.open("res://scripts/tests/BenchmarkRunner.gd", FileAccess.READ)
		if script_source != null:
			var content := script_source.get_as_text()
			script_source.close()

			var required_constants := [
				"BENCHMARK_SEED",
				"PLAYER_GEN_CLASS_SIZE",
				"SCOUT_EVAL_SAMPLE_SIZE",
				"LIFECYCLE_BATCH_SIZE",
				"MEMORY_SAMPLE_SIZE"
			]

			for constant in required_constants:
				if content.contains(constant):
					print("  PASS: Found constant %s" % constant)
				else:
					errors.append("Missing constant: %s" % constant)
					print("  FAIL: Missing constant %s" % constant)
		else:
			errors.append("Could not read BenchmarkRunner.gd source")
			print("  FAIL: Could not read source file")
	else:
		print("  SKIP: Script not loaded")

	# Test 3: Verify benchmark methods exist
	print("\nTest 3: Verifying benchmark methods...")
	if benchmark_script != null:
		var script_source := FileAccess.open("res://scripts/tests/BenchmarkRunner.gd", FileAccess.READ)
		if script_source != null:
			var content := script_source.get_as_text()
			script_source.close()

			var required_methods := [
				"_run_phase_timing_benchmarks",
				"_run_operation_benchmarks",
				"_run_bootstrap_benchmarks",
				"_run_memory_benchmarks",
				"_save_results",
				"_compare_to_baseline",
				"_print_summary"
			]

			for method in required_methods:
				if content.contains("func %s(" % method):
					print("  PASS: Found method %s" % method)
				else:
					errors.append("Missing method: %s" % method)
					print("  FAIL: Missing method %s" % method)
		else:
			errors.append("Could not read BenchmarkRunner.gd source")
			print("  FAIL: Could not read source file")
	else:
		print("  SKIP: Script not loaded")

	# Test 4: Verify dependencies can be loaded
	print("\nTest 4: Verifying dependencies...")
	var dependencies := {
		"Config": "res://autoloads/Config.gd",
		"Rand": "res://autoloads/Rand.gd",
		"DraftClassGenerator": "res://scripts/generation/DraftClassGenerator.gd",
		"ScoutRuntime": "res://scripts/core/scouting/ScoutRuntime.gd",
		"PlayerLifecycle": "res://scripts/world/PlayerLifecycle.gd",
		"AdvanceWorldYear": "res://scripts/pipelines/AdvanceWorldYear.gd",
		"BootstrapWorld": "res://scripts/pipelines/BootstrapWorld.gd",
		"HighSchoolSeason": "res://scripts/world/HighSchoolSeason.gd",
		"CollegeRecruiting": "res://scripts/pipelines/CollegeRecruiting.gd"
	}

	for dep_name in dependencies.keys():
		var dep_path: String = dependencies[dep_name]
		var dep_script = load(dep_path)
		if dep_script == null:
			errors.append("Failed to load dependency: %s (%s)" % [dep_name, dep_path])
			print("  FAIL: Could not load %s" % dep_name)
		else:
			print("  PASS: Loaded %s" % dep_name)

	# Test 5: Verify scene file exists
	print("\nTest 5: Verifying scene file...")
	var scene_path := "res://benchmark_runner.tscn"
	if FileAccess.file_exists(scene_path):
		print("  PASS: Scene file exists at %s" % scene_path)
	else:
		errors.append("Scene file missing: %s" % scene_path)
		print("  FAIL: Scene file not found")

	# Test 6: Verify output directory handling
	print("\nTest 6: Verifying output directory handling...")
	var dir := DirAccess.open("user://")
	if dir != null:
		print("  PASS: Can access user:// directory")
		if not dir.dir_exists("benchmarks"):
			dir.make_dir("benchmarks")
			print("  INFO: Created benchmarks directory")
		else:
			print("  INFO: Benchmarks directory already exists")
	else:
		errors.append("Cannot access user:// directory")
		print("  FAIL: Cannot access user:// directory")

	# Summary
	print("\n" + "=".repeat(80))
	print("VALIDATION SUMMARY")
	print("=".repeat(80))

	if errors.is_empty():
		print("\nALL TESTS PASSED")
		print("\nBenchmark suite is ready to run:")
		print("  godot --headless -s res://scripts/tests/BenchmarkRunner.gd")
		print("\nExpected runtime: 5-15 minutes (depending on hardware)")
		quit(0)
	else:
		print("\nFAILURES DETECTED (%d):" % errors.size())
		for error in errors:
			print("  - %s" % error)
		print("\nFix these issues before running benchmarks.")
		quit(1)
