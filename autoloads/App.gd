## App.gd
## Global app services: thread count + a convenience parallel map wrapper.
extends Node

var _thread_count: int = 1

func _ready() -> void:
	# Read engine threads config from Config (assumes you autoloaded Config.gd)
	var eng: Dictionary = Config.engine if Config.engine != null else {}
	var t_cfg: Dictionary = eng.get("threads", {}) as Dictionary
	var desired: int = int(t_cfg.get("count", 0))      # 0 means "auto"
	var max_cap: int = int(t_cfg.get("max", 8))        # safety cap (default 8)
	var cores: int = OS.get_processor_count()

	if desired > 0:
		_thread_count = min(desired, max_cap)
	else:
		_thread_count = min(cores, max_cap)

## Returns the configured number of worker threads.
func get_thread_count() -> int:
	return _thread_count

## Alias to match older calls like App.threads_count()
func threads_count() -> int:
	return _thread_count

## Convenience: parallel map using global thread count by default.
##
## Example:
## [codeblock]
## var squares := App.map_parallel(range(1000), func(x): return x * x)
## [/codeblock]
func map_parallel(items: Array, callable: Callable, threads: int = -1) -> Array:
	var t: int = _thread_count if threads <= 0 else threads
	return ThreadPool.map(items, callable, t)
