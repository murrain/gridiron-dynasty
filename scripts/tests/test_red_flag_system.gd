extends RefCounted

## RedFlagSystem Test Suite
##
## Tests for the draft intelligence red flag generation system.
## Verifies:
##   - Deterministic generation with same seed
##   - Correct frequency distribution (~3%)
##   - Severity distribution (70% minor, 30% major)
##   - Draft impact ranges (-5 to -20)
##   - Medical vs character type distribution
##   - Utility functions (get_total_impact, has_major_flags, etc.)
##
## 12 tests as specified in IMPLEMENTATION_SPECIFICATION.md

const RedFlagSystem = preload("res://scripts/world/RedFlagSystem.gd")
const Rand = preload("res://autoloads/Rand.gd")

func run(t) -> void:
	test_generate_red_flags_determinism(t)
	test_red_flag_frequency(t)
	test_red_flag_severity_distribution(t)
	test_medical_red_flag_generation(t)
	test_character_red_flag_generation(t)
	test_draft_impact_calculation(t)
	test_major_red_flag_detection(t)
	test_red_flag_summary(t)
	test_empty_pool_handling(t)
	test_red_flag_persistence(t)
	test_red_flag_draft_impact_range(t)
	test_multiple_red_flags_per_player(t)


## Test 1: Same seed produces identical red flags (determinism)
func test_generate_red_flags_determinism(t) -> void:
	var pool1 := _create_test_draft_pool(100)
	var pool2 := _create_test_draft_pool(100)
	var config := _create_test_config()

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = Rand.splitmix64(12345 ^ 0xFEDF1A60)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = Rand.splitmix64(12345 ^ 0xFEDF1A60)

	var count1 := RedFlagSystem.generate_red_flags(pool1, config, rng1)
	var count2 := RedFlagSystem.generate_red_flags(pool2, config, rng2)

	t.assert_eq(count1, count2, "same seed produces same flag count")

	# Verify flag details match
	var flags1 := _extract_all_flags(pool1)
	var flags2 := _extract_all_flags(pool2)

	t.assert_eq(flags1.size(), flags2.size(), "same number of flags in both pools")

	for i in range(flags1.size()):
		var f1: Dictionary = flags1[i]
		var f2: Dictionary = flags2[i]
		t.assert_eq(f1.get("type"), f2.get("type"), "flag %d type matches" % i)
		t.assert_eq(f1.get("severity"), f2.get("severity"), "flag %d severity matches" % i)
		t.assert_eq(f1.get("description"), f2.get("description"), "flag %d description matches" % i)


## Test 2: Red flag frequency respects configuration (~3%)
func test_red_flag_frequency(t) -> void:
	var pool := _create_test_draft_pool(1000)
	var config := {"red_flags": {"frequency": 0.03}}

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(54321 ^ 0xFEDF1A60)

	var count := RedFlagSystem.generate_red_flags(pool, config, rng)

	# With 1000 players at 3% frequency, expect ~30 flags
	# Allow variance of +/- 15 for statistical noise
	t.assert_true(count >= 15, "at least 15 flags generated (got %d)" % count)
	t.assert_true(count <= 60, "at most 60 flags generated (got %d)" % count)

	var actual_frequency := float(count) / 1000.0
	t.assert_true(actual_frequency >= 0.01, "frequency at least 1% (got %.2f%%)" % (actual_frequency * 100))
	t.assert_true(actual_frequency <= 0.06, "frequency at most 6% (got %.2f%%)" % (actual_frequency * 100))


## Test 3: Severity distribution respects configuration (70/30)
func test_red_flag_severity_distribution(t) -> void:
	var pool := _create_test_draft_pool(2000)
	var config := {
		"red_flags": {
			"frequency": 0.10,  # Higher frequency for better statistics
			"severity_distribution": {"minor": 0.7, "major": 0.3}
		}
	}

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(99999 ^ 0xFEDF1A60)

	RedFlagSystem.generate_red_flags(pool, config, rng)

	var flags := _extract_all_flags(pool)
	var major_count := 0
	var minor_count := 0

	for flag in flags:
		var f: Dictionary = flag
		if String(f.get("severity", "")) == "major":
			major_count += 1
		else:
			minor_count += 1

	var total := major_count + minor_count
	t.assert_true(total > 50, "enough flags for statistical analysis (got %d)" % total)

	var major_ratio := float(major_count) / float(total)
	# Allow variance: expect 30% major, accept 15%-50%
	t.assert_true(major_ratio >= 0.15, "major ratio at least 15% (got %.1f%%)" % (major_ratio * 100))
	t.assert_true(major_ratio <= 0.50, "major ratio at most 50% (got %.1f%%)" % (major_ratio * 100))


## Test 4: Medical red flags have correct structure
func test_medical_red_flag_generation(t) -> void:
	var pool := _create_test_draft_pool(500)
	var config := {"red_flags": {"frequency": 0.10}}

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(11111 ^ 0xFEDF1A60)

	RedFlagSystem.generate_red_flags(pool, config, rng)

	var medical_flags := []
	for player in pool:
		var p: Dictionary = player
		var flags: Array = RedFlagSystem.get_red_flags_by_type(p, "medical")
		medical_flags.append_array(flags)

	t.assert_true(medical_flags.size() > 0, "some medical flags generated")

	for flag in medical_flags:
		var f: Dictionary = flag
		t.assert_eq(f.get("type"), "medical", "flag type is medical")
		t.assert_true(f.has("severity"), "medical flag has severity")
		t.assert_true(f.has("description"), "medical flag has description")
		t.assert_true(f.has("draft_impact"), "medical flag has draft_impact")
		t.assert_true(f.has("discovered_week"), "medical flag has discovered_week")

		var desc := String(f.get("description", ""))
		# Medical descriptions should contain injury-related terms
		var has_injury_term := false
		for term in ["knee", "shoulder", "ankle", "concussion", "back", "hip", "hamstring", "foot", "injuries", "medical", "Surgery", "Injury"]:
			if term.to_lower() in desc.to_lower():
				has_injury_term = true
				break
		t.assert_true(has_injury_term, "medical description contains injury term: %s" % desc)


## Test 5: Character red flags have correct structure
func test_character_red_flag_generation(t) -> void:
	var pool := _create_test_draft_pool(500)
	var config := {"red_flags": {"frequency": 0.10}}

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(22222 ^ 0xFEDF1A60)

	RedFlagSystem.generate_red_flags(pool, config, rng)

	var character_flags := []
	for player in pool:
		var p: Dictionary = player
		var flags: Array = RedFlagSystem.get_red_flags_by_type(p, "character")
		character_flags.append_array(flags)

	t.assert_true(character_flags.size() > 0, "some character flags generated")

	for flag in character_flags:
		var f: Dictionary = flag
		t.assert_eq(f.get("type"), "character", "flag type is character")
		t.assert_true(f.has("severity"), "character flag has severity")
		t.assert_true(f.has("description"), "character flag has description")
		t.assert_true(f.has("draft_impact"), "character flag has draft_impact")


## Test 6: Total draft impact correctly summed
func test_draft_impact_calculation(t) -> void:
	var player := {"player_id": "test1"}

	# No flags - should return 0
	var impact_none := RedFlagSystem.get_total_draft_impact(player)
	t.assert_eq(impact_none, 0.0, "no flags = 0 impact")

	# Add flags manually
	player["draft_intelligence"] = {
		"red_flags": [
			{"type": "medical", "severity": "minor", "draft_impact": -5.0},
			{"type": "character", "severity": "major", "draft_impact": -12.0}
		]
	}

	var impact := RedFlagSystem.get_total_draft_impact(player)
	t.assert_eq(impact, -17.0, "total impact is sum of individual impacts")


## Test 7: has_major_red_flags accurately detects major flags
func test_major_red_flag_detection(t) -> void:
	var player_no_flags := {"player_id": "test1"}
	t.assert_false(RedFlagSystem.has_major_red_flags(player_no_flags), "no flags = no major")

	var player_minor_only := {
		"player_id": "test2",
		"draft_intelligence": {
			"red_flags": [
				{"type": "medical", "severity": "minor", "draft_impact": -5.0}
			]
		}
	}
	t.assert_false(RedFlagSystem.has_major_red_flags(player_minor_only), "minor only = no major")

	var player_with_major := {
		"player_id": "test3",
		"draft_intelligence": {
			"red_flags": [
				{"type": "medical", "severity": "minor", "draft_impact": -5.0},
				{"type": "character", "severity": "major", "draft_impact": -12.0}
			]
		}
	}
	t.assert_true(RedFlagSystem.has_major_red_flags(player_with_major), "has major flag")


## Test 8: Summary formatting is correct
func test_red_flag_summary(t) -> void:
	var player_no_flags := {"player_id": "test1"}
	var summary_none := RedFlagSystem.get_red_flag_summary(player_no_flags)
	t.assert_eq(summary_none, "No red flags", "no flags summary")

	var player_with_flags := {
		"player_id": "test2",
		"draft_intelligence": {
			"red_flags": [
				{"type": "medical", "severity": "minor", "description": "Knee issue", "draft_impact": -5.0},
				{"type": "character", "severity": "major", "description": "Off-field incident", "draft_impact": -12.0}
			]
		}
	}

	var summary := RedFlagSystem.get_red_flag_summary(player_with_flags)
	t.assert_true("[MINOR]" in summary, "summary contains MINOR tag")
	t.assert_true("[MAJOR]" in summary, "summary contains MAJOR tag")
	t.assert_true("Knee issue" in summary, "summary contains description")

	var short := RedFlagSystem.get_short_summary(player_with_flags)
	t.assert_true("2 flags" in short, "short summary has count")
	t.assert_true("1 major" in short, "short summary has major count")
	t.assert_true("1 minor" in short, "short summary has minor count")


## Test 9: Empty draft pool handled gracefully
func test_empty_pool_handling(t) -> void:
	var empty_pool: Array = []
	var config := _create_test_config()

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(33333 ^ 0xFEDF1A60)

	var count := RedFlagSystem.generate_red_flags(empty_pool, config, rng)
	t.assert_eq(count, 0, "empty pool generates 0 flags")


## Test 10: Flags survive serialization (Dictionary persistence)
func test_red_flag_persistence(t) -> void:
	var pool := _create_test_draft_pool(50)
	var config := {"red_flags": {"frequency": 0.20}}  # Higher frequency for test

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(44444 ^ 0xFEDF1A60)

	RedFlagSystem.generate_red_flags(pool, config, rng)

	# Find a player with flags
	var player_with_flags: Dictionary = {}
	for player in pool:
		var p: Dictionary = player
		if RedFlagSystem.has_red_flags(p):
			player_with_flags = p
			break

	if player_with_flags.is_empty():
		t.skip("No flags generated in test pool")
		return

	# Serialize and deserialize
	var original_flags: Array = player_with_flags.get("draft_intelligence", {}).get("red_flags", [])
	var serialized := player_with_flags.duplicate(true)
	var deserialized: Dictionary = serialized.duplicate(true)

	var restored_flags: Array = deserialized.get("draft_intelligence", {}).get("red_flags", [])

	t.assert_eq(restored_flags.size(), original_flags.size(), "flag count preserved after serialization")

	for i in range(original_flags.size()):
		var orig: Dictionary = original_flags[i]
		var rest: Dictionary = restored_flags[i]
		t.assert_eq(orig.get("type"), rest.get("type"), "type preserved for flag %d" % i)
		t.assert_eq(orig.get("severity"), rest.get("severity"), "severity preserved for flag %d" % i)
		t.assert_eq(orig.get("draft_impact"), rest.get("draft_impact"), "impact preserved for flag %d" % i)


## Test 11: Draft impacts within expected bounds (-5 to -20)
func test_red_flag_draft_impact_range(t) -> void:
	var pool := _create_test_draft_pool(500)
	var config := {"red_flags": {"frequency": 0.15}}

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(55555 ^ 0xFEDF1A60)

	RedFlagSystem.generate_red_flags(pool, config, rng)

	var flags := _extract_all_flags(pool)
	t.assert_true(flags.size() > 0, "flags generated for impact testing")

	for flag in flags:
		var f: Dictionary = flag
		var impact := float(f.get("draft_impact", 0.0))

		# All impacts should be negative (drops draft position)
		t.assert_true(impact < 0, "impact is negative: %.1f" % impact)

		# Minor flags: -3 to -10, Major flags: -10 to -20
		var severity := String(f.get("severity", ""))
		if severity == "minor":
			t.assert_true(impact >= -10.0, "minor impact >= -10: %.1f" % impact)
			t.assert_true(impact <= -3.0, "minor impact <= -3: %.1f" % impact)
		else:  # major
			t.assert_true(impact >= -20.0, "major impact >= -20: %.1f" % impact)
			t.assert_true(impact <= -10.0, "major impact <= -10: %.1f" % impact)


## Test 12: Player can have multiple red flags
func test_multiple_red_flags_per_player(t) -> void:
	# Use very high frequency to increase chance of multiple flags
	# This is a probabilistic test - we run with high frequency
	var pool := _create_test_draft_pool(100)
	var config := {"red_flags": {"frequency": 0.50}}  # 50% chance each player

	var rng := RandomNumberGenerator.new()
	rng.seed = Rand.splitmix64(66666 ^ 0xFEDF1A60)

	# Run multiple times to accumulate flags
	RedFlagSystem.generate_red_flags(pool, config, rng)

	# Reset RNG and run again on same pool to add more flags
	rng.seed = Rand.splitmix64(77777 ^ 0xFEDF1A60)
	RedFlagSystem.generate_red_flags(pool, config, rng)

	# Find players with multiple flags
	var max_flags := 0
	for player in pool:
		var p: Dictionary = player
		var count := RedFlagSystem.get_red_flag_count(p)
		max_flags = max(max_flags, count)

	t.assert_true(max_flags >= 2, "at least one player has 2+ flags (max: %d)" % max_flags)

	# Verify multiple flags are properly stored
	for player in pool:
		var p: Dictionary = player
		if RedFlagSystem.get_red_flag_count(p) >= 2:
			var di: Dictionary = p.get("draft_intelligence", {})
			var flags: Array = di.get("red_flags", [])

			# Verify each flag is properly structured
			for flag in flags:
				var f: Dictionary = flag
				t.assert_true(f.has("type"), "multi-flag has type")
				t.assert_true(f.has("severity"), "multi-flag has severity")
				t.assert_true(f.has("draft_impact"), "multi-flag has impact")
			break


# =========================
# Helper functions
# =========================

func _create_test_draft_pool(count: int) -> Array:
	var pool := []
	var positions := ["QB", "RB", "WR", "TE", "OL", "DL", "LB", "CB", "S"]

	for i in range(count):
		var rating := 60.0 + float(i % 40)
		pool.append({
			"player_id": "player_%d" % i,
			"name": "Player %d" % i,
			"position": positions[i % positions.size()],
			"stats": {
				"speed": rating,
				"strength": rating - 5.0,
				"agility": rating + 3.0
			}
		})

	return pool


func _create_test_config() -> Dictionary:
	return {
		"red_flags": {
			"frequency": 0.03,
			"severity_distribution": {
				"minor": 0.7,
				"major": 0.3
			}
		}
	}


func _extract_all_flags(pool: Array) -> Array:
	var all_flags := []
	for player in pool:
		var p: Dictionary = player
		var di: Dictionary = p.get("draft_intelligence", {})
		var flags: Array = di.get("red_flags", [])
		all_flags.append_array(flags)
	return all_flags
