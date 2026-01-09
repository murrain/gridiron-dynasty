## ThreadPool.gd
## Simple fan-out/fan-in map over a fixed number of worker threads.
## Not an autoload. Use via:  var out := ThreadPool.map(items, callable, threads)
extends RefCounted
class_name ThreadPool

class _Pool:
	var threads: int
	var _workers: Array = []
	var _queue: Array = []
	var _mutex := Mutex.new()
	var _semaphore := Semaphore.new()
	var _running: bool = true

	func _init(count: int) -> void:
		threads = count
		for i in range(count):
			var worker := Thread.new()
			worker.start(Callable(self, "_worker_loop"))
			_workers.append(worker)

	func enqueue(callable: Callable, slice: Array, out: Array, offset: int, done: Semaphore) -> void:
		_mutex.lock()
		_queue.append({
			"callable": callable,
			"slice": slice,
			"out": out,
			"offset": offset,
			"done": done
		})
		_mutex.unlock()
		_semaphore.post()

	func _worker_loop() -> void:
		while true:
			_semaphore.wait()
			if not _running:
				return
			var task: Dictionary = {}
			_mutex.lock()
			if _queue.is_empty():
				_mutex.unlock()
				continue
			task = _queue.pop_front() as Dictionary
			_mutex.unlock()
			var slice: Array = task["slice"] as Array
			var callable: Callable = task["callable"] as Callable
			var out: Array = task["out"] as Array
			var offset: int = int(task["offset"])
			var done: Semaphore = task["done"] as Semaphore
			var part: Array = ThreadPool._run_slice(callable, slice)
			for i in range(part.size()):
				out[offset + i] = part[i]
			done.post()

static var _pools: Dictionary = {}

static func _run_slice(callable: Callable, slice: Array) -> Array:
	var out: Array = []
	out.resize(slice.size())
	for i in range(slice.size()):
		out[i] = callable.call(slice[i])
	return out

## Splits an array into `parts` chunks with near-equal size.
static func _chunk(arr: Array, parts: int) -> Array:
	var chunks: Array = []
	parts = max(1, parts)
	var n: int = arr.size()
	var base: int = n / parts
	var rem: int = n % parts
	var start: int = 0
	for p in range(parts):
		var take: int = base + (1 if p < rem else 0)
		if take <= 0:
			chunks.append([])
		else:
			chunks.append(arr.slice(start, start + take))
			start += take
	return chunks

static func _get_pool(threads: int) -> _Pool:
	if _pools.has(threads):
		return _pools[threads] as _Pool
	var pool := _Pool.new(threads)
	_pools[threads] = pool
	return pool

## Map a callable across `items` using `threads` workers.
## Returns an Array with the mapped results in input order.
##
## Notes:
## - `callable` should be pure (no shared mutations) for thread safety.
## - `items` can be empty; returns [] immediately.
##
## Example:
## [codeblock]
## var doubled := ThreadPool.map([1,2,3,4], func(x): return x*2, 2)
## # -> [2,4,6,8]
## [/codeblock]
static func map(items: Array, callable: Callable, threads: int) -> Array:
	if items.is_empty():
		return []

	var t: int = max(1, threads)
	if t <= 1:
		return _run_slice(callable, items)

	var chunks: Array = _chunk(items, min(t, items.size()))
	var out: Array = []
	out.resize(items.size())
	var done := Semaphore.new()
	var pool := _get_pool(min(t, chunks.size()))
	var offset: int = 0
	for chunk in chunks:
		pool.enqueue(callable, chunk, out, offset, done)
		offset += chunk.size()

	for i in range(chunks.size()):
		done.wait()
	return out
