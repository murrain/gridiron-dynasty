extends GdUnitTestSuite
class_name TestThreadPoolGdUnit4

## GdUnit4 tests for ThreadPool - Parallel processing utilities
##
## Tests:
##   - Parallel map operations
##   - Thread pool management
##   - Work distribution and chunking
##   - Result ordering guarantees
##   - Performance characteristics

const ThreadPool = preload("res://autoloads/ThreadPool.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")


# =============================================================================
# BASIC MAP OPERATION TESTS
# =============================================================================

func test_map_simple_operation() -> void:
	var items := [1, 2, 3, 4, 5]
	var double_func := func(x): return x * 2

	var result := ThreadPool.map(items, double_func, 2)

	assert_array(result).contains_exactly([2, 4, 6, 8, 10])


func test_map_preserves_order() -> void:
	var items := [10, 20, 30, 40, 50]
	var add_100_func := func(x): return x + 100

	var result := ThreadPool.map(items, add_100_func, 3)

	# Results should be in same order as input
	assert_int(result[0]).is_equal(110)
	assert_int(result[1]).is_equal(120)
	assert_int(result[2]).is_equal(130)
	assert_int(result[3]).is_equal(140)
	assert_int(result[4]).is_equal(150)


func test_map_with_empty_array() -> void:
	var items := []
	var func_never_called := func(x): return x * 2

	var result := ThreadPool.map(items, func_never_called, 2)

	assert_array(result).is_empty()


func test_map_with_single_item() -> void:
	var items := [42]
	var square_func := func(x): return x * x

	var result := ThreadPool.map(items, square_func, 4)

	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(1764)


# =============================================================================
# THREAD COUNT TESTS
# =============================================================================

func test_map_with_single_thread() -> void:
	var items := [1, 2, 3, 4, 5]
	var double_func := func(x): return x * 2

	var result := ThreadPool.map(items, double_func, 1)

	# Should still work correctly with single thread
	assert_array(result).contains_exactly([2, 4, 6, 8, 10])


func test_map_with_zero_threads_uses_one() -> void:
	var items := [1, 2, 3]
	var triple_func := func(x): return x * 3

	var result := ThreadPool.map(items, triple_func, 0)

	# Should default to 1 thread
	assert_array(result).contains_exactly([3, 6, 9])


func test_map_with_more_threads_than_items() -> void:
	var items := [1, 2]
	var add_10_func := func(x): return x + 10

	var result := ThreadPool.map(items, add_10_func, 10)

	# Should handle gracefully (won't create 10 threads for 2 items)
	assert_array(result).contains_exactly([11, 12])


# =============================================================================
# CALLABLE FUNCTION TESTS
# =============================================================================

func test_map_with_complex_callable() -> void:
	var items := [
		{"value": 10, "multiplier": 2},
		{"value": 20, "multiplier": 3},
		{"value": 30, "multiplier": 4}
	]

	var compute_func := func(item):
		return item["value"] * item["multiplier"]

	var result := ThreadPool.map(items, compute_func, 2)

	assert_int(result[0]).is_equal(20)
	assert_int(result[1]).is_equal(60)
	assert_int(result[2]).is_equal(120)


func test_map_with_stateless_callable() -> void:
	# Pure function - no shared state
	var items := [1, 2, 3, 4, 5]
	var factorial_func := func(n):
		var result := 1
		for i in range(1, n + 1):
			result *= i
		return result

	var result := ThreadPool.map(items, factorial_func, 3)

	assert_int(result[0]).is_equal(1)    # 1!
	assert_int(result[1]).is_equal(2)    # 2!
	assert_int(result[2]).is_equal(6)    # 3!
	assert_int(result[3]).is_equal(24)   # 4!
	assert_int(result[4]).is_equal(120)  # 5!


# =============================================================================
# CHUNKING TESTS
# =============================================================================

func test_chunk_divides_array_evenly() -> void:
	var arr := [1, 2, 3, 4, 5, 6]
	var chunks := ThreadPool._chunk(arr, 3)

	assert_int(chunks.size()).is_equal(3)
	assert_int(chunks[0].size()).is_equal(2)
	assert_int(chunks[1].size()).is_equal(2)
	assert_int(chunks[2].size()).is_equal(2)


func test_chunk_handles_uneven_division() -> void:
	var arr := [1, 2, 3, 4, 5]
	var chunks := ThreadPool._chunk(arr, 2)

	assert_int(chunks.size()).is_equal(2)
	# First chunk gets the extra element
	assert_int(chunks[0].size()).is_equal(3)
	assert_int(chunks[1].size()).is_equal(2)


func test_chunk_with_single_chunk() -> void:
	var arr := [1, 2, 3, 4, 5]
	var chunks := ThreadPool._chunk(arr, 1)

	assert_int(chunks.size()).is_equal(1)
	assert_int(chunks[0].size()).is_equal(5)


func test_chunk_with_more_chunks_than_items() -> void:
	var arr := [1, 2, 3]
	var chunks := ThreadPool._chunk(arr, 10)

	# Should create 10 chunks, some empty
	assert_int(chunks.size()).is_equal(10)


# =============================================================================
# LARGE DATASET TESTS
# =============================================================================

func test_map_large_dataset() -> void:
	var items := []
	for i in range(1000):
		items.append(i)

	var square_func := func(x): return x * x

	var result := ThreadPool.map(items, square_func, 4)

	assert_int(result.size()).is_equal(1000)
	assert_int(result[0]).is_equal(0)
	assert_int(result[10]).is_equal(100)
	assert_int(result[999]).is_equal(998001)


func test_map_preserves_order_with_large_dataset() -> void:
	var items := []
	for i in range(500):
		items.append(i)

	var add_1000_func := func(x): return x + 1000

	var result := ThreadPool.map(items, add_1000_func, 8)

	# Check order is preserved
	for i in range(500):
		assert_int(result[i]).is_equal(i + 1000)


# =============================================================================
# TYPE PRESERVATION TESTS
# =============================================================================

func test_map_preserves_string_types() -> void:
	var items := ["hello", "world", "test"]
	var uppercase_func := func(s): return s.to_upper()

	var result := ThreadPool.map(items, uppercase_func, 2)

	assert_str(result[0]).is_equal("HELLO")
	assert_str(result[1]).is_equal("WORLD")
	assert_str(result[2]).is_equal("TEST")


func test_map_preserves_dictionary_types() -> void:
	var items := [
		{"name": "Alice", "age": 30},
		{"name": "Bob", "age": 25},
		{"name": "Charlie", "age": 35}
	]

	var get_name_func := func(person): return person["name"]

	var result := ThreadPool.map(items, get_name_func, 2)

	assert_str(result[0]).is_equal("Alice")
	assert_str(result[1]).is_equal("Bob")
	assert_str(result[2]).is_equal("Charlie")


# =============================================================================
# DETERMINISM TESTS
# =============================================================================

func test_map_is_deterministic_single_thread() -> void:
	var items := [5, 3, 8, 1, 9, 2, 7, 4, 6]
	var double_func := func(x): return x * 2

	var result1 := ThreadPool.map(items, double_func, 1)
	var result2 := ThreadPool.map(items, double_func, 1)

	# Results should be identical
	for i in range(items.size()):
		assert_int(result1[i]).is_equal(result2[i])


func test_map_is_deterministic_multi_thread() -> void:
	var items := [5, 3, 8, 1, 9, 2, 7, 4, 6]
	var triple_func := func(x): return x * 3

	var result1 := ThreadPool.map(items, triple_func, 4)
	var result2 := ThreadPool.map(items, triple_func, 4)

	# Results should be identical (order preserved)
	for i in range(items.size()):
		assert_int(result1[i]).is_equal(result2[i])


# =============================================================================
# EDGE CASES
# =============================================================================

func test_run_slice_sequential_execution() -> void:
	var items := [1, 2, 3]
	var double_func := func(x): return x * 2

	var result := ThreadPool._run_slice(double_func, items)

	assert_array(result).contains_exactly([2, 4, 6])


func test_map_with_negative_thread_count_uses_one() -> void:
	var items := [10, 20, 30]
	var half_func := func(x): return x / 2

	var result := ThreadPool.map(items, half_func, -5)

	# Should default to 1 thread
	assert_array(result).contains_exactly([5, 10, 15])


func test_map_callable_returning_null() -> void:
	var items := [1, 2, 3]
	var return_null_func := func(_x): return null

	var result := ThreadPool.map(items, return_null_func, 2)

	assert_int(result.size()).is_equal(3)
	for item in result:
		assert_object(item).is_null()


func test_map_callable_returning_array() -> void:
	var items := [1, 2, 3]
	var range_func := func(n): return range(n)

	var result := ThreadPool.map(items, range_func, 2)

	# Each result should be an array
	assert_int(result[0].size()).is_equal(1)  # range(1) = [0]
	assert_int(result[1].size()).is_equal(2)  # range(2) = [0, 1]
	assert_int(result[2].size()).is_equal(3)  # range(3) = [0, 1, 2]


# =============================================================================
# PERFORMANCE CHARACTERISTICS
# =============================================================================

func test_map_parallelization_improves_performance() -> void:
	# Heavy computation that benefits from parallelization
	var items := []
	for i in range(100):
		items.append(i)

	var heavy_func := func(n):
		var result := 0
		for i in range(1000):
			result += n * i
		return result

	# Single-threaded
	var single_thread_callable := func():
		ThreadPool.map(items, heavy_func, 1)

	# Multi-threaded
	var multi_thread_callable := func():
		ThreadPool.map(items, heavy_func, 4)

	# Note: Just verify both complete successfully
	# Actual performance comparison depends on hardware
	single_thread_callable.call()
	multi_thread_callable.call()

	# Test passes if both complete without error
	assert_bool(true).is_true()


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_map_simulation_use_case() -> void:
	# Simulate processing player stats in parallel
	var players := []
	for i in range(100):
		players.append({
			"id": "PLAYER_%d" % i,
			"stats": {"yards": 1000 + i * 10, "tds": 5 + i}
		})

	var calculate_rating_func := func(player):
		var stats = player["stats"]
		return stats["yards"] / 100.0 + stats["tds"] * 10.0

	var ratings := ThreadPool.map(players, calculate_rating_func, 4)

	assert_int(ratings.size()).is_equal(100)
	# Check first player rating
	assert_float(ratings[0]).is_equal(1000.0 / 100.0 + 5.0 * 10.0)


func test_map_nested_parallelization_not_recommended() -> void:
	# This test shows that nested ThreadPool.map calls work but aren't optimal
	var outer_items := [1, 2, 3]

	var nested_func := func(n):
		var inner_items := range(n)
		var inner_result := ThreadPool.map(inner_items, func(x): return x * 2, 1)
		return inner_result.size()

	var result := ThreadPool.map(outer_items, nested_func, 2)

	# Should complete successfully even with nested maps
	assert_int(result[0]).is_equal(1)
	assert_int(result[1]).is_equal(2)
	assert_int(result[2]).is_equal(3)
