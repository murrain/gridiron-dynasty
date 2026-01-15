## GdUnit4 test suite for ThreadPool
##
## Validates parallel mapping and chunking utilities.
## Migrated from test_threadpool.gd
extends GdUnitTestSuite

const ThreadPool = preload("res://autoloads/ThreadPool.gd")


func test_chunk_returns_parts() -> void:
	var chunks = ThreadPool._chunk([1, 2, 3, 4, 5], 2)
	assert_int(chunks.size()).is_equal(2)


func test_chunk_splits_evenly() -> void:
	var chunks = ThreadPool._chunk([1, 2, 3, 4, 5], 2)
	assert_array(chunks[0]).is_equal([1, 2, 3])


func test_chunk_splits_remainder() -> void:
	var chunks = ThreadPool._chunk([1, 2, 3, 4, 5], 2)
	assert_array(chunks[1]).is_equal([4, 5])


func test_chunk_returns_requested_parts() -> void:
	var more = ThreadPool._chunk([1, 2], 4)
	assert_int(more.size()).is_equal(4)


func test_chunk_includes_empty_slices() -> void:
	var more = ThreadPool._chunk([1, 2], 4)
	assert_array(more[2]).is_equal([])


func test_map_preserves_order() -> void:
	var mapped = ThreadPool.map([1, 2, 3], func(x): return x * 2, 1)
	assert_array(mapped).is_equal([2, 4, 6])


func test_map_handles_empty_input() -> void:
	var empty = ThreadPool.map([], func(x): return x, 1)
	assert_array(empty).is_equal([])
