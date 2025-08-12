## ThreadPool.gd
## Simple fan-out/fan-in map over a fixed number of worker threads.
## Not an autoload. Use via:  var out := ThreadPool.map(items, callable, threads)
extends RefCounted
class_name ThreadPool

## Internal worker record.
class _Job:
	var thread: Thread
	var callable: Callable
	var slice: Array
	var out: Array = []

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
	var chunks: Array = _chunk(items, min(t, items.size()))

	# Launch
	var jobs: Array = []
	for chunk in chunks:
		var job := _Job.new()
		job.thread = Thread.new()
		job.callable = callable
		job.slice = chunk
		job.thread.start(Callable(ThreadPool, "_run_slice").bind(job.callable, job.slice))
		jobs.append(job)

	# Join and stitch back together in order
	var out: Array = []
	for job in jobs:
		var part: Array = job.thread.wait_to_finish()
		if part != null:
			out.append_array(part)
	return out