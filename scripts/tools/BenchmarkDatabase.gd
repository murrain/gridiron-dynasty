## Database Performance Benchmark Tool (ARCH-022)
## Measures query performance for common database operations
##
## Features:
## - Benchmarks all common query patterns
## - Measures before/after index impact
## - Reports timing statistics with percentiles
## - Supports warm-up runs for accurate measurements
##
## Usage:
##   var bench = BenchmarkDatabase.new()
##   var results = bench.run_benchmarks("save_game_001.db")
##   bench.print_report(results)
extends RefCounted
class_name BenchmarkDatabase

const SQLite = preload("res://addons/godot-sqlite/godot-sqlite.gd")

# Benchmark configuration
const DEFAULT_ITERATIONS = 10          # Number of times to run each benchmark
const WARM_UP_ITERATIONS = 3           # Warm-up runs (discarded from results)
const PERFORMANCE_THRESHOLD_MS = 100   # Target threshold for "good" performance

# Directory for database files
const DB_DIR = "user://saves/"

# =========================
# Public API
# =========================

## Run all benchmarks against a database
## @param db_path: Path to SQLite database file
## @param iterations: Number of iterations per benchmark (default: 10)
## @return: Dictionary of benchmark results
func run_benchmarks(db_path: String, iterations: int = DEFAULT_ITERATIONS) -> Dictionary:
	var results = {
		"database_path": db_path,
		"iterations": iterations,
		"timestamp": Time.get_datetime_string_from_system(),
		"benchmarks": {},
		"summary": {}
	}

	# Open database
	var db = SQLite.new()
	var resolved_path = _resolve_path(db_path)
	db.path = resolved_path

	if not db.open_db():
		results["error"] = "Failed to open database: %s" % resolved_path
		return results

	# Enable foreign keys
	db.query("PRAGMA foreign_keys = ON;")

	# Get database statistics for context
	results["database_stats"] = _get_database_stats(db)

	# Run benchmarks
	results["benchmarks"]["find_qbs"] = _benchmark_find_by_position(db, "QB", iterations)
	results["benchmarks"]["find_wrs"] = _benchmark_find_by_position(db, "WR", iterations)
	results["benchmarks"]["find_by_age"] = _benchmark_find_by_age_range(db, 21, 25, iterations)
	results["benchmarks"]["find_nfl_veterans"] = _benchmark_find_by_stage(db, 4, iterations)
	results["benchmarks"]["find_free_agents"] = _benchmark_find_free_agents(db, iterations)
	results["benchmarks"]["find_draft_eligible"] = _benchmark_find_draft_eligible(db, iterations)
	results["benchmarks"]["load_team_roster"] = _benchmark_load_team_roster(db, iterations)
	results["benchmarks"]["position_age_combo"] = _benchmark_position_age_combo(db, iterations)
	results["benchmarks"]["contract_expiring"] = _benchmark_contract_expiring(db, iterations)
	results["benchmarks"]["full_player_load"] = _benchmark_full_player_load(db, iterations)

	db.close_db()

	# Calculate summary statistics
	results["summary"] = _calculate_summary(results["benchmarks"])

	return results

## Run a single benchmark with specified query
## @param db_path: Path to SQLite database file
## @param query: SQL query to benchmark
## @param iterations: Number of iterations
## @return: Benchmark result dictionary
func benchmark_query(db_path: String, query: String, iterations: int = DEFAULT_ITERATIONS) -> Dictionary:
	var db = SQLite.new()
	db.path = _resolve_path(db_path)

	if not db.open_db():
		return {"error": "Failed to open database"}

	var result = _run_benchmark(db, "custom_query", query, iterations)

	db.close_db()
	return result

## Print formatted benchmark report
## @param results: Results dictionary from run_benchmarks()
func print_report(results: Dictionary) -> void:
	print("")
	print("=" .repeat(70))
	print("DATABASE PERFORMANCE BENCHMARK REPORT")
	print("=" .repeat(70))
	print("")

	if results.has("error"):
		print("ERROR: %s" % results["error"])
		return

	print("Database: %s" % results["database_path"])
	print("Timestamp: %s" % results["timestamp"])
	print("Iterations: %d" % results["iterations"])
	print("")

	# Database statistics
	if results.has("database_stats"):
		var stats = results["database_stats"]
		print("Database Statistics:")
		print("  - Players: %d" % stats.get("player_count", 0))
		print("  - Teams: %d" % stats.get("team_count", 0))
		print("  - Roster entries: %d" % stats.get("roster_entry_count", 0))
		print("")

	# Benchmark results
	print("-" .repeat(70))
	print("%-30s %10s %10s %10s %10s" % ["Benchmark", "Min (ms)", "Avg (ms)", "Max (ms)", "Status"])
	print("-" .repeat(70))

	var benchmarks = results.get("benchmarks", {})
	for name in benchmarks.keys():
		var bench = benchmarks[name]
		if bench.has("error"):
			print("%-30s %s" % [name, "ERROR: " + bench["error"]])
		else:
			var status = "PASS" if bench["avg_ms"] < PERFORMANCE_THRESHOLD_MS else "SLOW"
			print("%-30s %10.2f %10.2f %10.2f %10s" % [
				name,
				bench["min_ms"],
				bench["avg_ms"],
				bench["max_ms"],
				status
			])

	print("-" .repeat(70))
	print("")

	# Summary
	if results.has("summary"):
		var summary = results["summary"]
		print("Summary:")
		print("  - Total benchmarks: %d" % summary.get("total_benchmarks", 0))
		print("  - Passed (<%d ms): %d" % [PERFORMANCE_THRESHOLD_MS, summary.get("passed", 0)])
		print("  - Slow (>=%d ms): %d" % [PERFORMANCE_THRESHOLD_MS, summary.get("slow", 0)])
		print("  - Overall average: %.2f ms" % summary.get("overall_avg_ms", 0))

	print("")
	print("=" .repeat(70))

# =========================
# Private: Benchmark Runners
# =========================

## Run a single benchmark
func _run_benchmark(db: SQLite, name: String, query: String, iterations: int) -> Dictionary:
	var result = {
		"name": name,
		"query": query,
		"times_ms": [],
		"min_ms": 0.0,
		"max_ms": 0.0,
		"avg_ms": 0.0,
		"row_count": 0
	}

	# Warm-up runs (not counted)
	for _i in WARM_UP_ITERATIONS:
		db.query(query)

	# Timed runs
	for _i in iterations:
		var start = Time.get_ticks_usec()
		db.query(query)
		var end = Time.get_ticks_usec()

		var time_ms = (end - start) / 1000.0
		result["times_ms"].append(time_ms)

		# Store row count from last iteration
		result["row_count"] = db.query_result.size() if db.query_result != null else 0

	# Calculate statistics
	if result["times_ms"].size() > 0:
		result["min_ms"] = result["times_ms"].min()
		result["max_ms"] = result["times_ms"].max()
		var sum = 0.0
		for t in result["times_ms"]:
			sum += t
		result["avg_ms"] = sum / result["times_ms"].size()

	return result

## Benchmark: Find players by position
func _benchmark_find_by_position(db: SQLite, position: String, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE position = '%s'" % position
	return _run_benchmark(db, "find_%s" % position.to_lower(), query, iterations)

## Benchmark: Find players by age range
func _benchmark_find_by_age_range(db: SQLite, min_age: int, max_age: int, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE age BETWEEN %d AND %d" % [min_age, max_age]
	return _run_benchmark(db, "find_age_%d_%d" % [min_age, max_age], query, iterations)

## Benchmark: Find players by stage
func _benchmark_find_by_stage(db: SQLite, stage: int, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE stage = %d" % stage
	return _run_benchmark(db, "find_stage_%d" % stage, query, iterations)

## Benchmark: Find free agents (stage = 5)
func _benchmark_find_free_agents(db: SQLite, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE stage = 5"
	return _run_benchmark(db, "find_free_agents", query, iterations)

## Benchmark: Find draft-eligible players (stage = 2)
func _benchmark_find_draft_eligible(db: SQLite, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE stage = 2"
	return _run_benchmark(db, "find_draft_eligible", query, iterations)

## Benchmark: Load team roster with player IDs
func _benchmark_load_team_roster(db: SQLite, iterations: int) -> Dictionary:
	# First, get a team ID to test with
	db.query("SELECT id FROM team LIMIT 1")
	var team_result = db.query_result

	if team_result.is_empty():
		return {"name": "load_team_roster", "error": "No teams in database", "times_ms": [], "min_ms": 0, "max_ms": 0, "avg_ms": 0}

	var team_id = team_result[0]["id"]
	var query = "SELECT * FROM roster_entry WHERE team_id = '%s'" % team_id
	return _run_benchmark(db, "load_team_roster", query, iterations)

## Benchmark: Position + age combination query
func _benchmark_position_age_combo(db: SQLite, iterations: int) -> Dictionary:
	var query = "SELECT * FROM player WHERE position = 'RB' AND age BETWEEN 22 AND 28"
	return _run_benchmark(db, "position_age_combo", query, iterations)

## Benchmark: Find expiring contracts
func _benchmark_contract_expiring(db: SQLite, iterations: int) -> Dictionary:
	var query = "SELECT p.*, pc.* FROM player p JOIN player_contract pc ON p.id = pc.player_id WHERE pc.current_year = pc.total_years AND pc.total_years > 0"
	return _run_benchmark(db, "contract_expiring", query, iterations)

## Benchmark: Full player load with all components
func _benchmark_full_player_load(db: SQLite, iterations: int) -> Dictionary:
	# This simulates loading a complete player with all component tables
	var query = """
		SELECT p.*, pp.*, pc.*, ps.*
		FROM player p
		LEFT JOIN player_physicals pp ON p.id = pp.player_id
		LEFT JOIN player_combine pc ON p.id = pc.player_id
		LEFT JOIN player_stats ps ON p.id = ps.player_id
		LIMIT 100
	"""
	return _run_benchmark(db, "full_player_load", query, iterations)

# =========================
# Private: Utility Functions
# =========================

## Get database statistics
func _get_database_stats(db: SQLite) -> Dictionary:
	var stats = {
		"player_count": 0,
		"team_count": 0,
		"roster_entry_count": 0
	}

	db.query("SELECT COUNT(*) as count FROM player")
	if db.query_result.size() > 0:
		stats["player_count"] = int(db.query_result[0]["count"])

	db.query("SELECT COUNT(*) as count FROM team")
	if db.query_result.size() > 0:
		stats["team_count"] = int(db.query_result[0]["count"])

	db.query("SELECT COUNT(*) as count FROM roster_entry")
	if db.query_result.size() > 0:
		stats["roster_entry_count"] = int(db.query_result[0]["count"])

	return stats

## Calculate summary statistics from benchmark results
func _calculate_summary(benchmarks: Dictionary) -> Dictionary:
	var summary = {
		"total_benchmarks": benchmarks.size(),
		"passed": 0,
		"slow": 0,
		"failed": 0,
		"overall_avg_ms": 0.0
	}

	var total_avg = 0.0
	var valid_count = 0

	for name in benchmarks.keys():
		var bench = benchmarks[name]
		if bench.has("error"):
			summary["failed"] += 1
		else:
			if bench["avg_ms"] < PERFORMANCE_THRESHOLD_MS:
				summary["passed"] += 1
			else:
				summary["slow"] += 1
			total_avg += bench["avg_ms"]
			valid_count += 1

	if valid_count > 0:
		summary["overall_avg_ms"] = total_avg / valid_count

	return summary

## Resolve database path
func _resolve_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://") or path.begins_with("/"):
		if not path.ends_with(".db"):
			return path + ".db"
		return path

	var filename = path
	if not filename.ends_with(".db"):
		filename = filename + ".db"

	return DB_DIR + filename

# =========================
# Index Analysis (Optional)
# =========================

## Analyze query execution plan
## @param db_path: Path to database
## @param query: SQL query to analyze
## @return: EXPLAIN QUERY PLAN output
func explain_query(db_path: String, query: String) -> Array:
	var db = SQLite.new()
	db.path = _resolve_path(db_path)

	if not db.open_db():
		return []

	db.query("EXPLAIN QUERY PLAN " + query)
	var result = db.query_result.duplicate()

	db.close_db()
	return result

## List all indexes in the database
## @param db_path: Path to database
## @return: Array of index information
func list_indexes(db_path: String) -> Array:
	var db = SQLite.new()
	db.path = _resolve_path(db_path)

	if not db.open_db():
		return []

	db.query("SELECT name, tbl_name, sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL ORDER BY tbl_name, name")
	var result = db.query_result.duplicate()

	db.close_db()
	return result

## Get index usage statistics (requires ANALYZE to have been run)
## @param db_path: Path to database
## @return: Dictionary of index statistics
func get_index_stats(db_path: String) -> Dictionary:
	var db = SQLite.new()
	db.path = _resolve_path(db_path)

	if not db.open_db():
		return {}

	# Run ANALYZE to update statistics
	db.query("ANALYZE")

	# Get statistics
	db.query("SELECT * FROM sqlite_stat1")
	var stats = db.query_result.duplicate()

	db.close_db()

	return {"sqlite_stat1": stats}
