extends RefCounted

const AppService = preload("res://autoloads/App.gd")
const RngBox = preload("res://autoloads/RngBox.gd")
const Threader = preload("res://scripts/support/threading/Threader.gd")

func run(t) -> void:
	var app := AppService.new()
	var squares := app.map_parallel([1, 2, 3, 4], func(x): return x * x, 1)
	t.assert_eq(squares, [1, 4, 9, 16], "map_parallel returns mapped values")

	var box := RngBox.new()
	var rng_a := box.get_rng()
	var rng_b := box.get_rng()
	t.assert_true(rng_a == rng_b, "RngBox returns same RNG per thread")

	var count := 10
	var visited := []
	visited.resize(count)
	for i in range(count):
		visited[i] = false
	var lock := Mutex.new()

	Threader.for_indices(count, 3, func(i):
		lock.lock()
		visited[i] = true
		lock.unlock()
	)

	for i in range(count):
		t.assert_true(visited[i], "Threader visits index %d" % i)
