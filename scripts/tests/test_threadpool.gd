extends RefCounted

const ThreadPool = preload("res://autoloads/ThreadPool.gd")

func run(t) -> void:
	var chunks = ThreadPool._chunk([1,2,3,4,5], 2)
	t.assert_eq(chunks.size(), 2, "_chunk should return parts")
	t.assert_eq(chunks[0], [1,2,3], "_chunk should split evenly")
	t.assert_eq(chunks[1], [4,5], "_chunk should split remainder")

	var more = ThreadPool._chunk([1,2], 4)
	t.assert_eq(more.size(), 4, "_chunk should return requested parts")
	t.assert_eq(more[2], [], "_chunk should include empty slices")

	var mapped = ThreadPool.map([1,2,3], func(x): return x * 2, 1)
	t.assert_eq(mapped, [2,4,6], "map should preserve order")

	var empty = ThreadPool.map([], func(x): return x, 1)
	t.assert_eq(empty, [], "map should handle empty input")
