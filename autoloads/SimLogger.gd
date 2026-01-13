## SimLogger.gd
## Centralized logging shim for the simulation engine.
##
## Provides a clean interface for logging that abstracts away implementation details.
## Generation code passes messages; SimLogger handles timestamps, async, file output, etc.
##
## Configuration:
##   SimLogger.configure({"async": true, "level": "info", "log_to_file": false})
##
## Usage:
##   SimLogger.info("Starting HS generation for year 2025")
##   SimLogger.debug("Generated player: %s" % player_id)
##   SimLogger.stats("HS Background", {"stars": {5: 10}, "avg_hype": 42.3})
extends RefCounted
class_name SimLogger

## Log levels (lower = more verbose)
enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, NONE = 4 }

## Default configuration - async with full timestamps
static var _config := {
	"async": true,           # Use async logging (non-blocking)
	"level": Level.INFO,     # Minimum log level to output
	"timestamps": true,      # Include timestamps in all logs
	"log_to_file": false,    # Also write to log file
	"log_file_path": "user://simulation.log",
	"show_seeds": false,     # Show RNG seeds (verbose, for debugging)
	"categories": {}         # Per-category level overrides
}

## File handle for log file (lazy initialized)
static var _log_file: FileAccess = null

## Configure logger settings
## Example: SimLogger.configure({"level": "debug", "log_to_file": true})
static func configure(settings: Dictionary) -> void:
	for key in settings.keys():
		if key == "level" and settings[key] is String:
			_config[key] = _level_from_string(settings[key])
		else:
			_config[key] = settings[key]

	# Reset file handle if path changed
	if settings.has("log_file_path") and _log_file != null:
		_log_file.close()
		_log_file = null

## Convert string level to enum
static func _level_from_string(s: String) -> int:
	match s.to_lower():
		"debug": return Level.DEBUG
		"info": return Level.INFO
		"warn", "warning": return Level.WARN
		"error": return Level.ERROR
		"none", "off": return Level.NONE
		_: return Level.INFO

## Get timestamp prefix
static func _timestamp() -> String:
	if not _config["timestamps"]:
		return ""
	var time := Time.get_time_dict_from_system()
	return "[%02d:%02d:%02d] " % [time["hour"], time["minute"], time["second"]]

## Check if should log for level/category
static func _should_log(level: int, category: String = "") -> bool:
	var min_level: int = _config["level"]
	if category != "" and _config["categories"].has(category):
		min_level = _config["categories"][category]
	return level >= min_level

## Write to log file (called from async context)
static func _write_to_file_sync(message: String) -> void:
	if _log_file == null:
		_log_file = FileAccess.open(_config["log_file_path"], FileAccess.WRITE)
	if _log_file != null:
		_log_file.store_line(message)
		_log_file.flush()

## Core output function - entire pipeline is async when enabled
static func _output(message: String) -> void:
	if _config["async"]:
		var msg := message  # Capture for lambda
		var log_to_file: bool = _config["log_to_file"]
		WorkerThreadPool.add_task(func():
			print(msg)
			if log_to_file:
				_write_to_file_sync(msg)
		)
	else:
		print(message)
		if _config["log_to_file"]:
			_write_to_file_sync(message)

## Format and output a log message
static func _log(level: int, level_prefix: String, message: String, category: String = "") -> void:
	if not _should_log(level, category):
		return
	var full_message := "%s%s%s" % [_timestamp(), level_prefix, message]
	_output(full_message)

# ============================================================================
# PUBLIC API - Simple message-based logging
# ============================================================================

## Debug level - verbose, for development
static func debug(message: String, category: String = "") -> void:
	_log(Level.DEBUG, "[DEBUG] ", message, category)

## Info level - normal operational logs (default)
static func info(message: String, category: String = "") -> void:
	_log(Level.INFO, "", message, category)

## Warning level - potential issues
static func warn(message: String, category: String = "") -> void:
	_log(Level.WARN, "[WARN] ", message, category)

## Error level - failures
static func error(message: String, category: String = "") -> void:
	_log(Level.ERROR, "[ERROR] ", message, category)

# ============================================================================
# CONVENIENCE METHODS - Structured logging for common patterns
# ============================================================================

## Log phase start
static func phase_start(phase_id: String, year: int, seed: int) -> void:
	var seed_str := " (seed=%d)" % seed if _config["show_seeds"] else ""
	info("%d %s: start%s" % [year, phase_id, seed_str])

## Log phase end
static func phase_end(phase_id: String, year: int, seed: int) -> void:
	var seed_str := " (seed=%d)" % seed if _config["show_seeds"] else ""
	info("%d %s: end%s" % [year, phase_id, seed_str])

## Log step seed (debug level)
static func step_seed(year: int, phase_id: String, step_id: String, seed: int) -> void:
	if _config["show_seeds"]:
		debug("%d %s.%s: step (seed=%d)" % [year, phase_id, step_id, seed])

## Log phase summary with metrics and timing
static func phase_summary(phase_id: String, year: int, metrics: Dictionary, elapsed_ms: float) -> void:
	var parts: Array = []
	for key in metrics.keys():
		var val = metrics[key]
		if val is float:
			if key == "spent":
				parts.append("%s=$%.2fM" % [key, val])
			else:
				parts.append("%s=%.1f" % [key, val])
		else:
			parts.append("%s=%s" % [key, str(val)])
	var summary: String = " | ".join(parts) if not parts.is_empty() else "complete"
	info("%d %s: %s (%.1fms)" % [year, phase_id.to_upper(), summary, elapsed_ms])

## Log timing summary for a year
static func timing_summary(year: int, phase_timings: Dictionary) -> void:
	info("Year %d timing summary:" % year)
	var total_ms: float = 0.0
	for pid in phase_timings.keys():
		var ms: float = phase_timings[pid]
		total_ms += ms
		if ms > 100.0:
			info("  %s: %.1fms" % [pid, ms])
	info("  TOTAL: %.1fms" % total_ms)

## Log stats/metrics dictionary
static func stats(category: String, data: Dictionary) -> void:
	var parts: Array = []
	for key in data.keys():
		var val = data[key]
		if val is float:
			parts.append("%s=%.1f" % [key, val])
		elif val is Dictionary:
			var sub_parts: Array = []
			for k in val.keys():
				sub_parts.append("%s:%s" % [str(k), str(val[k])])
			parts.append("%s=[%s]" % [key, " ".join(sub_parts)])
		else:
			parts.append("%s=%s" % [key, str(val)])
	info("[%s] %s" % [category, " | ".join(parts)], category)

## Log distribution data (stars, tiers, etc.)
static func distribution(category: String, label: String, dist: Dictionary, total: int = 0) -> void:
	var parts: Array = []
	for key in dist.keys():
		parts.append("%s:%d" % [str(key), int(dist[key])])
	var msg: String
	if total > 0:
		msg = "[%s] %s (n=%d): %s" % [category, label, total, " ".join(parts)]
	else:
		msg = "[%s] %s: %s" % [category, label, " ".join(parts)]
	info(msg, category)
