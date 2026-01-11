extends RefCounted
class_name TestHelpers

var failures: Array = []

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])

func assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		failures.append("%s (unexpected %s)" % [message, str(actual)])

func assert_approx(actual: float, expected: float, epsilon: float, message: String) -> void:
	if abs(actual - expected) > epsilon:
		failures.append("%s (expected %.4f±%.4f, got %.4f)" % [message, expected, epsilon, actual])

func assert_between(actual: float, lo: float, hi: float, message: String) -> void:
	if actual < lo or actual > hi:
		failures.append("%s (expected between %.4f and %.4f, got %.4f)" % [message, lo, hi, actual])

func create_seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
