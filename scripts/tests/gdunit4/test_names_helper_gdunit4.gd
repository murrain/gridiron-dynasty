extends GdUnitTestSuite
class_name TestNamesHelperGdUnit4

const NamesHelper = preload("res://scripts/generation/helpers/NamesHelper.gd")
const ConfigLoader = preload("res://scripts/generation/ConfigLoader.gd")
const TestHelpersGdUnit4 = preload("res://scripts/tests/TestHelpersGdUnit4.gd")

var _names_cfg: Dictionary = {}

func before_test() -> void:
	var loader = ConfigLoader.new()
	loader.configure("res://configs/sports/american_football", "", false)
	_names_cfg = loader.get_config("names")


# ============================================================================
# DETERMINISM TESTS
# ============================================================================

func test_name_generation_is_deterministic() -> void:
	TestHelpersGdUnit4.assert_deterministic(
		self,
		func(rng):
			return NamesHelper.random_full(_names_cfg, rng),
		0xNAME01,
		"name generation should be deterministic"
	)


# ============================================================================
# NAME GENERATION TESTS
# ============================================================================

func test_generates_full_name() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0001)
	var name = NamesHelper.random_full(_names_cfg, rng)

	assert_str(name).is_not_empty()
	assert_bool(name.contains(" ")).override_failure_message(
		"Name should contain space: %s" % name
	).is_true()

func test_generated_name_has_first_and_last() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0002)
	var name = NamesHelper.random_full(_names_cfg, rng)

	var parts = name.split(" ", false)
	assert_int(parts.size()).is_greater_equal(2)

func test_multiple_names_are_different() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0003)
	var names := []

	for i in 100:
		var name = NamesHelper.random_full(_names_cfg, rng)
		names.append(name)

	# With 100 names, should have significant variety
	var unique_names := {}
	for name in names:
		unique_names[name] = true

	assert_int(unique_names.size()).is_greater(50)


# ============================================================================
# FALLBACK TESTS
# ============================================================================

func test_handles_empty_config() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0004)
	var empty_cfg := {}
	var name = NamesHelper.random_full(empty_cfg, rng)

	# Should fall back to default names
	assert_str(name).is_not_empty()
	assert_str(name).contains("Alex Taylor")

func test_handles_missing_first_names() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0005)
	var cfg := {"last_names": ["Smith", "Johnson"]}
	var name = NamesHelper.random_full(cfg, rng)

	# Should use fallback first name
	assert_str(name).is_not_empty()
	assert_bool(name.contains(" ")).is_true()

func test_handles_missing_last_names() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0006)
	var cfg := {"first_names": ["John", "Jane"]}
	var name = NamesHelper.random_full(cfg, rng)

	# Should use fallback last name
	assert_str(name).is_not_empty()
	assert_bool(name.contains(" ")).is_true()


# ============================================================================
# CONFIG VARIANT TESTS
# ============================================================================

func test_supports_first_names_key() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0007)
	var cfg := {
		"first_names": ["Alice", "Bob"],
		"last_names": ["Smith", "Jones"]
	}
	var name = NamesHelper.random_full(cfg, rng)

	assert_str(name).is_not_empty()
	var parts = name.split(" ")
	assert_bool(parts[0] in ["Alice", "Bob"]).is_true()
	assert_bool(parts[1] in ["Smith", "Jones"]).is_true()

func test_supports_first_key() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0008)
	var cfg := {
		"first": ["Charlie", "Dana"],
		"last": ["Brown", "Green"]
	}
	var name = NamesHelper.random_full(cfg, rng)

	assert_str(name).is_not_empty()
	var parts = name.split(" ")
	assert_bool(parts[0] in ["Charlie", "Dana"]).is_true()

func test_supports_male_first_names_key() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0009)
	var cfg := {
		"male_first_names": ["Mike", "Tom"],
		"last_names": ["Black", "White"]
	}
	var name = NamesHelper.random_full(cfg, rng)

	assert_str(name).is_not_empty()
	var parts = name.split(" ")
	assert_bool(parts[0] in ["Mike", "Tom"]).is_true()

func test_supports_female_first_names_key() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0010)
	var cfg := {
		"female_first_names": ["Sarah", "Emma"],
		"last_names": ["Gray", "Blue"]
	}
	var name = NamesHelper.random_full(cfg, rng)

	assert_str(name).is_not_empty()
	var parts = name.split(" ")
	assert_bool(parts[0] in ["Sarah", "Emma"]).is_true()


# ============================================================================
# NAME DISTRIBUTION TESTS
# ============================================================================

func test_name_distribution_is_uniform() -> void:
	var rng = TestHelpersGdUnit4.create_seeded_rng(0xN0011)
	var cfg := {
		"first_names": ["A", "B"],
		"last_names": ["X", "Y"]
	}

	var first_counts := {"A": 0, "B": 0}
	var last_counts := {"X": 0, "Y": 0}

	for i in 200:
		var name = NamesHelper.random_full(cfg, rng)
		var parts = name.split(" ")
		first_counts[parts[0]] = first_counts.get(parts[0], 0) + 1
		last_counts[parts[1]] = last_counts.get(parts[1], 0) + 1

	# With 200 samples, each should be roughly 100 (allow 60-140 range)
	assert_int(first_counts["A"]).is_greater(60)
	assert_int(first_counts["A"]).is_less(140)
	assert_int(first_counts["B"]).is_greater(60)
	assert_int(first_counts["B"]).is_less(140)
