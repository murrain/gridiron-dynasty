## GdUnit4 test suite for core utility classes
##
## Validates AppService, RngBox, and Threader utilities.
## Migrated from test_core_utilities.gd
extends GdUnitTestSuite

const AppService = preload("res://autoloads/App.gd")
const RngBox = preload("res://autoloads/RngBox.gd")
const Threader = preload("res://scripts/support/threading/Threader.gd")


func test_map_parallel_returns_mapped_values() -> void:
	var app := AppService.new()
	var squares := app.map_parallel([1, 2, 3, 4], func(x): return x * x, 1)
	assert_array(squares).is_equal([1, 4, 9, 16])


func test_rng_box_returns_same_rng_per_thread() -> void:
	var box := RngBox.new()
	var rng_a := box.get_rng()
	var rng_b := box.get_rng()
	assert_bool(rng_a == rng_b).is_true()


func test_threader_visits_all_indices() -> void:
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
		assert_bool(visited[i]).override_failure_message(
			"Threader should visit index %d" % i
		).is_true()
