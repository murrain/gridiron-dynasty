extends RefCounted
class_name Threader

static func default_threads() -> int:
	var n := OS.get_processor_count()
	return min(max(n, 1), 8)  # 1/core up to 8

# Run cb(i) for i in [0, count)
static func for_indices(count: int, threads: int, cb: Callable) -> void:
	if count <= 0:
		return
	threads = max(1, min(threads, count))
	var chunk := int(ceil(count / float(threads)))

	var ts: Array[Thread] = []
	ts.resize(threads)

	for t in range(threads):
		var start_i := t * chunk
		var end_i := min(count, start_i + chunk)
		if start_i >= end_i: break
		var thr := Thread.new()
		ts[t] = thr
		thr.start(Callable(Threader, "_worker_indices").bind(start_i, end_i, cb))

	for thr in ts:
		if thr != null:
			thr.wait_to_finish()

static func _worker_indices(start_i: int, end_i: int, cb: Callable) -> void:
	for i in range(start_i, end_i):
		cb.call(i)