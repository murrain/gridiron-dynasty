## AsyncLogger.gd
## Non-blocking logger that offloads print statements to background threads.
## Use for logging during performance-critical operations like world generation.
##
## Usage:
##   AsyncLogger.log("[Phase] Message here")
##   AsyncLogger.log_stats("HS Background", {"stars": 5, "count": 100})
##
## The logger uses Godot's WorkerThreadPool for fire-and-forget execution,
## ensuring logging doesn't block the main simulation thread.
extends RefCounted
class_name AsyncLogger

## Simple async print - fires and forgets
static func log(message: String) -> void:
	WorkerThreadPool.add_task(func(): print(message))

## Log with timestamp prefix
static func log_timed(message: String) -> void:
	var time := Time.get_time_dict_from_system()
	var timestamp := "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]
	WorkerThreadPool.add_task(func(): print("%s %s" % [timestamp, message]))

## Log stats dictionary in a formatted way
static func log_stats(category: String, stats: Dictionary) -> void:
	var parts: Array = []
	for key in stats.keys():
		var val = stats[key]
		if val is float:
			parts.append("%s=%.1f" % [key, val])
		elif val is Dictionary:
			# Flatten nested dict
			var sub_parts: Array = []
			for k in val.keys():
				sub_parts.append("%s:%s" % [str(k), str(val[k])])
			parts.append("%s=[%s]" % [key, " ".join(sub_parts)])
		else:
			parts.append("%s=%s" % [key, str(val)])
	var message := "[%s] %s" % [category, " | ".join(parts)]
	WorkerThreadPool.add_task(func(): print(message))

## Log generation distribution (e.g., star ratings, tiers)
static func log_distribution(category: String, label: String, dist: Dictionary, total: int = 0) -> void:
	var parts: Array = []
	for key in dist.keys():
		parts.append("%s:%d" % [str(key), int(dist[key])])
	var message: String
	if total > 0:
		message = "[%s] %s (n=%d): %s" % [category, label, total, " ".join(parts)]
	else:
		message = "[%s] %s: %s" % [category, label, " ".join(parts)]
	WorkerThreadPool.add_task(func(): print(message))
