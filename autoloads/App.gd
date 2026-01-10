## App.gd
## Global app services: thread count + a convenience parallel map wrapper.
extends Node

const ThreadPool = preload("res://autoloads/ThreadPool.gd")

var _thread_count: int = 1

func _ready() -> void:
	# Initialize once; runtime changes should use Config.threads_count().
	_thread_count = Config.threads_count()

## Returns the configured number of worker threads.
func get_thread_count() -> int:
	return Config.threads_count()

## Alias to match older calls like App.threads_count()
func threads_count() -> int:
	return Config.threads_count()

## Convenience: parallel map using global thread count by default.
##
## Example:
## [codeblock]
## var squares := App.map_parallel(range(1000), func(x): return x * x)
## [/codeblock]
func map_parallel(items: Array, callable: Callable, threads: int = -1) -> Array:
	var t: int = Config.threads_count() if threads <= 0 else threads
	return ThreadPool.map(items, callable, t)
