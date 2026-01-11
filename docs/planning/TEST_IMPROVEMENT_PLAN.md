# Test Suite Improvement Plan

**Created**: 2026-01-10
**Status**: Ready for Implementation
**Overall Quality**: 7.5/10 → Target: 9/10

## Executive Summary

Our test suite is **well-architected with excellent determinism patterns and valuation coverage** (9/10), but has **significant consolidation opportunities** (200+ LOC of duplication) and **critical coverage gaps** in error handling and edge cases. This plan organizes work into 3 parallel tracks to improve quality, reduce maintenance burden, and close coverage gaps.

---

## Track 1: Test Infrastructure & Consolidation (HIGH PRIORITY)

**Owner**: Agent 1
**Duration**: 2-3 days
**LOC Impact**: -350 lines (consolidation)
**Quality Impact**: +1 point (maintainability)

### Goals:
1. Eliminate determinism testing duplication (37 files)
2. Centralize test data creation (15+ files)
3. Add schema validation utilities
4. Add performance assertion helpers

### Tasks:

#### Task 1.1: Enhance TestHelpers.gd
**File**: `scripts/tests/TestHelpers.gd`

Add the following helper methods:

```gdscript
## Verify a function is deterministic with given seed
## Usage: assert_deterministic(PlayerLifecycle.advance_one_year, [players, cfg], 12345, t)
func assert_deterministic(callable: Callable, args: Array, seed: int, message: String) -> void:
	var rng1 = _create_rng(seed)
	var result1 = callable.callv(args + [rng1])

	var rng2 = _create_rng(seed)
	var result2 = callable.callv(args + [rng2])

	assert_eq(JSON.stringify(result1), JSON.stringify(result2),
		"Determinism: " + message)

## Create seeded RNG (consolidates 37 repeated patterns)
func create_seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	return rng

## Assert dictionary has required fields
## Usage: assert_schema(player, ["player_id", "name", "age", "position"], "player structure")
func assert_schema(obj: Dictionary, required_fields: Array, message: String) -> void:
	for field in required_fields:
		assert_true(obj.has(field), "%s: missing field '%s'" % [message, field])

## Assert dictionary has fields with specific types
func assert_schema_typed(obj: Dictionary, schema: Dictionary, message: String) -> void:
	for field_name in schema.keys():
		var expected_type = schema[field_name]
		assert_true(obj.has(field_name), "%s: missing field '%s'" % [message, field_name])
		var actual = obj[field_name]
		assert_true(typeof(actual) == expected_type,
			"%s: field '%s' has wrong type" % [message, field_name])

## Assert operation completes within time limit
func assert_max_time(callable: Callable, max_ms: float, message: String) -> void:
	var start = Time.get_ticks_usec()
	callable.call()
	var elapsed = (Time.get_ticks_usec() - start) / 1000.0
	assert_true(elapsed <= max_ms,
		"%s (took %.2fms, max %.2fms)" % [message, elapsed, max_ms])

## Create test player with sensible defaults
func create_test_player(
	player_id: String = "TEST001",
	position: String = "QB",
	age: int = 18,
	rating: float = 75.0,
	college_year: int = 1
) -> Dictionary:
	return {
		"player_id": player_id,
		"name": "Test Player",
		"position": position,
		"age": age,
		"college_year": college_year,
		"college_eligibility_status": _year_to_status(college_year),
		"stats": _default_stats_for_position(position, rating),
		"potential": _default_potential_for_rating(rating),
		"development_history": []
	}

## Create minimal world state for testing
func create_minimal_world_state(year: int = 2025) -> Dictionary:
	return {
		"current_year": year,
		"nfl_teams": [],
		"nfl_rosters": {},
		"colleges": [],
		"college_rosters": {},
		"hs_schools": [],
		"hs_players": [],
		"draft_pool": {},
		"retired_players": []
	}

func _default_stats_for_position(position: String, rating: float) -> Dictionary:
	# Position-appropriate stats based on rating
	return {
		"speed": rating + randf_range(-5, 5),
		"strength": rating + randf_range(-5, 5),
		"accuracy": rating + randf_range(-5, 5),
		"awareness": rating + randf_range(-5, 5)
	}

func _default_potential_for_rating(rating: float) -> Dictionary:
	return {
		"speed": rating + 10.0,
		"strength": rating + 10.0,
		"accuracy": rating + 10.0,
		"awareness": rating + 10.0
	}

func _year_to_status(year: int) -> String:
	match year:
		1: return "freshman"
		2: return "sophomore"
		3: return "junior"
		4: return "senior"
		_: return "senior"
```

**Files to Modify**: 37 test files using determinism pattern
**LOC Reduction**: ~200 lines

#### Task 1.2: Apply TestHelpers Consolidation
**Action**: Refactor 15+ test files to use centralized helpers

**Example Refactor** (test_player_lifecycle.gd):
```gdscript
# Before:
func _create_test_player() -> Dictionary:
	return {
		"player_id": "TEST001",
		"name": "Test Player",
		# ... 20 lines
	}

var rng = RandomNumberGenerator.new()
rng.seed = 12345
var result = PlayerLifecycle.advance_one_year(...)

# After:
var player = t.create_test_player("TEST001", "QB", 18, 75.0)
var rng = t.create_seeded_rng(12345)
var result = PlayerLifecycle.advance_one_year(...)
```

**Files to Refactor**:
- test_player_lifecycle.gd
- test_college_season.gd
- test_nfl_season.gd
- test_recruiting_optimization.gd
- (10+ more)

**LOC Reduction**: ~150 lines

#### Task 1.3: Add Performance Assertions
**Action**: Convert informational prints to assertions in optimization tests

**Example** (test_recruiting_optimization.gd):
```gdscript
# Before (line 306-313):
print("Original: %.2fms" % original_time)
print("Optimized: %.2fms" % optimized_time)
print("Speedup: %.2fx" % speedup)

# After:
t.assert_max_time(func(): pipeline.run(...), 5000.0,
	"Recruiting completes within 5s")
t.assert_true(optimized_time < original_time,
	"Optimized faster than baseline (%.2fms vs %.2fms)" % [optimized_time, original_time])
```

**Files to Modify**:
- test_recruiting_optimization.gd
- test_parallel_lifecycle.gd
- test_copy_optimization.gd

---

## Track 2: Error Handling & Edge Cases (CRITICAL GAP)

**Owner**: Agent 2
**Duration**: 2-3 days
**LOC Impact**: +500 lines (new tests)
**Quality Impact**: +1.5 points (coverage)

### Goals:
1. Add comprehensive error handling test suite
2. Add boundary value / edge case tests
3. Cover validation failures and invalid inputs

### Tasks:

#### Task 2.1: Create Error Handling Test Suite
**New File**: `scripts/tests/test_error_handling.gd`

```gdscript
extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")
const PlayerGenerator = preload("res://scripts/world/PlayerGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const CollegeRecruiting = preload("res://scripts/world/CollegeRecruiting.gd")
const PlayerLifecycle = preload("res://scripts/world/PlayerLifecycle.gd")

func run(t: TestHelpers) -> void:
	test_player_generator_invalid_inputs(t)
	test_hs_generator_zero_schools(t)
	test_lifecycle_invalid_player_data(t)
	test_recruiting_empty_colleges(t)
	test_config_missing_fields(t)
	test_world_state_corruption(t)
	test_negative_values(t)
	test_boundary_overflow(t)

func test_player_generator_invalid_inputs(t: TestHelpers) -> void:
	var gen = PlayerGenerator.new()
	var config = _load_test_config()

	# Test max_players = 0
	var result = gen.generate_hs_class(0, 2025, 12345, config, {})
	t.assert_eq(result.size(), 0, "zero max_players returns empty array")

	# Test negative max_players
	result = gen.generate_hs_class(-5, 2025, 12345, config, {})
	t.assert_eq(result.size(), 0, "negative max_players treated as zero")

	# Test empty config
	result = gen.generate_hs_class(100, 2025, 12345, {}, {})
	# Should not crash - verify graceful degradation or reasonable defaults
	t.assert_true(result.is_empty() or result.size() > 0,
		"empty config handled without crash")

func test_hs_generator_zero_schools(t: TestHelpers) -> void:
	var gen = HighSchoolGenerator.new()
	var config = _load_test_config()

	# Test school_count = 0
	var result = gen.generate(0, 2025, 12345, config)
	t.assert_eq(result.size(), 0, "zero school_count returns empty array")

func test_lifecycle_invalid_player_data(t: TestHelpers) -> void:
	var rng = t.create_seeded_rng(12345)
	var config = _load_test_config()

	# Player with negative age
	var invalid_player = {
		"player_id": "INVALID",
		"age": -5,
		"stats": {"speed": 50.0},
		"potential": {"speed": 60.0}
	}

	var result = PlayerLifecycle.advance_one_year([invalid_player],
		config["positions"], config["main"], config["stats"], rng, {})

	# Should handle gracefully - either skip, clamp, or document expected behavior
	var players = result.get("players", [])
	if players.size() > 0:
		var p = players[0]
		# Age should not remain negative
		t.assert_true(int(p.get("age", 0)) >= 0, "negative age handled")

func test_recruiting_empty_colleges(t: TestHelpers) -> void:
	var recruiting = CollegeRecruiting.new()
	var config = _load_test_config()
	var rng = t.create_seeded_rng(12345)

	# Empty colleges array
	var result = recruiting.run([], [], 2025, 12345, config, {})
	t.assert_true(result.has("commitments"), "empty colleges handled without crash")
	var commitments = result.get("commitments", {})
	t.assert_eq(commitments.size(), 0, "no commitments when no colleges")

func test_config_missing_fields(t: TestHelpers) -> void:
	# Test with minimal/empty config
	var empty_config = {}

	# Verify systems handle missing config gracefully
	# Each system should have sensible defaults or fail gracefully
	t.assert_true(true, "placeholder - test each system with empty config")

func test_world_state_corruption(t: TestHelpers) -> void:
	# Test world_state with missing referenced entities
	var world_state = {
		"nfl_rosters": {
			"KC": {"players": ["MISSING_PLAYER_ID"]}
		},
		"colleges": []  # Empty colleges
	}

	# Systems should handle missing references gracefully
	t.assert_true(true, "placeholder - test missing entity references")

func test_negative_values(t: TestHelpers) -> void:
	# Test stats with negative values
	var player = t.create_test_player()
	player["stats"]["speed"] = -10.0
	player["potential"]["speed"] = -5.0

	# System should clamp or reject negative stats
	t.assert_true(true, "placeholder - verify negative value handling")

func test_boundary_overflow(t: TestHelpers) -> void:
	# Test stat values > 100 (max boundary)
	var player = t.create_test_player()
	player["stats"]["speed"] = 150.0  # Overflow

	# System should clamp to max
	t.assert_true(true, "placeholder - verify overflow handling")
```

**Scope**: 30+ test functions, 100+ assertions
**Priority**: CRITICAL

#### Task 2.2: Create Edge Case Test Suite
**New File**: `scripts/tests/test_edge_cases_comprehensive.gd`

```gdscript
extends RefCounted

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

func run(t: TestHelpers) -> void:
	test_age_boundaries(t)
	test_score_boundaries(t)
	test_empty_collections(t)
	test_threshold_values(t)
	test_max_capacity_overflow(t)

func test_age_boundaries(t: TestHelpers) -> void:
	# Test exactly age 18 (min)
	var player_min = t.create_test_player("P1", "QB", 18, 75.0)
	# Test lifecycle at minimum age

	# Test exactly age 45 (max)
	var player_max = t.create_test_player("P2", "QB", 45, 75.0)
	# Test retirement at maximum age

func test_score_boundaries(t: TestHelpers) -> void:
	# Test score = 0
	var player_zero = t.create_test_player("P1", "QB", 18, 0.0)

	# Test score = 100
	var player_max = t.create_test_player("P2", "QB", 18, 100.0)

	# Test score = 50 (average)
	var player_avg = t.create_test_player("P3", "QB", 18, 50.0)

func test_empty_collections(t: TestHelpers) -> void:
	# Test with 0 players
	var result = PlayerLifecycle.advance_one_year([], ...)
	t.assert_eq(result.get("players", []).size(), 0, "empty input returns empty")

	# Test with 0 schools
	# Test with 0 colleges

func test_threshold_values(t: TestHelpers) -> void:
	# Test draft declaration at exactly rating=65
	var player_threshold = t.create_test_player("P1", "QB", 21, 65.0)
	player_threshold["college_year"] = 4  # Senior

	# Run college season
	# Verify player declares for draft

func test_max_capacity_overflow(t: TestHelpers) -> void:
	# Test roster with more players than max capacity
	# Verify system handles gracefully (reject? truncate? error?)
```

**Scope**: 40+ test functions, 80+ assertions
**Priority**: HIGH

---

## Track 3: Valuation & Integration Tests (POLISH)

**Owner**: Agent 3
**Duration**: 2 days
**LOC Impact**: +200 lines (new tests), -100 lines (refactor)
**Quality Impact**: +0.5 points (coverage depth)

### Goals:
1. Split large test files for readability
2. Add contract/API boundary tests
3. Add statistical property tests (distribution validation)

### Tasks:

#### Task 3.1: Refactor Large Test Files
**Action**: Split test_player_value.gd (709 lines) into 3 files

**New Structure**:
- `test_player_value_core.gd` (250 lines) - Basic valuation tests
- `test_player_value_scenarios.gd` (250 lines) - Elite, backup, depth scenarios
- `test_player_value_integration.gd` (200 lines) - Component integration tests

**Similar splits**:
- test_contract_valuation.gd (642 lines) → 3 files
- test_recruiting_optimization.gd (438 lines) → 2 files

**Priority**: MEDIUM

#### Task 3.2: Add Contract/API Tests
**New File**: `scripts/tests/test_api_contracts.gd`

```gdscript
extends RefCounted

func run(t: TestHelpers) -> void:
	test_player_lifecycle_contract(t)
	test_recruiting_contract(t)
	test_season_contract(t)

func test_player_lifecycle_contract(t: TestHelpers) -> void:
	# Verify function signature / return contract
	var result = PlayerLifecycle.advance_one_year(...)

	t.assert_schema(result, ["players", "retired", "development_reports"],
		"PlayerLifecycle.advance_one_year return contract")

	t.assert_true(result["players"] is Array, "players is Array")
	t.assert_true(result["retired"] is Array, "retired is Array")
```

**Scope**: 15 test functions
**Priority**: MEDIUM

#### Task 3.3: Add Statistical Property Tests
**New File**: `scripts/tests/test_statistical_properties.gd`

```gdscript
extends RefCounted

func run(t: TestHelpers) -> void:
	test_player_height_distribution(t)
	test_stat_distribution_ranges(t)
	test_draft_pick_weighting(t)

func test_player_height_distribution(t: TestHelpers) -> void:
	# Generate 1000 players
	var heights = []
	for i in range(1000):
		var player = PlayerGenerator.generate_hs_class(1, 2025, i, config, {})
		heights.append(player[0].get("height", 0))

	# Calculate mean, std dev
	var mean = _mean(heights)
	var stddev = _stddev(heights)

	# Verify normal distribution (mean ≈ 72, stddev ≈ 2)
	t.assert_between(mean, 70.0, 74.0, "player height mean reasonable")
	t.assert_between(stddev, 1.5, 3.0, "player height stddev reasonable")

func test_stat_distribution_ranges(t: TestHelpers) -> void:
	# Verify stats don't have obvious holes or skews
	# Generate many players, verify stat distributions are smooth
```

**Scope**: 15 test functions
**Priority**: LOW-MEDIUM

---

## Implementation Order

### Phase 1: Foundation (Days 1-2)
- **Track 1, Task 1.1**: Enhance TestHelpers.gd (Agent 1)
- **Track 2, Task 2.1**: Create error handling suite (Agent 2)

### Phase 2: Consolidation (Days 2-3)
- **Track 1, Task 1.2**: Apply TestHelpers consolidation (Agent 1)
- **Track 2, Task 2.2**: Create edge case suite (Agent 2)
- **Track 3, Task 3.1**: Refactor large test files (Agent 3)

### Phase 3: Polish (Days 3-4)
- **Track 1, Task 1.3**: Add performance assertions (Agent 1)
- **Track 3, Task 3.2**: Add contract tests (Agent 3)
- **Track 3, Task 3.3**: Add statistical tests (Agent 3)

---

## Success Metrics

### Before:
- Total tests: 54 files, 890 assertions
- Quality: 7.5/10
- LOC: ~15,000 (estimated)
- Redundancy: High (37 files repeat determinism pattern)
- Coverage gaps: Error handling, edge cases

### After:
- Total tests: 60+ files, 1100+ assertions
- Quality: 9/10
- LOC: ~15,000 (net zero - consolidation offsets new tests)
- Redundancy: Low (centralized helpers)
- Coverage: Comprehensive (error handling, edge cases covered)

### Specific Improvements:
- **-350 LOC** from consolidation (Track 1)
- **+500 LOC** from new error/edge tests (Track 2)
- **+200 LOC** from new contract/statistical tests (Track 3)
- **-100 LOC** from refactoring large files (Track 3)
- **Net: +250 LOC** (+17% assertions, +0% maintenance burden)

---

## Agent Assignment

### Agent 1: Infrastructure Engineer
**Track**: Track 1 (Test Infrastructure & Consolidation)
**Expertise**: Code refactoring, helper utilities, patterns
**Duration**: 2-3 days
**Deliverables**:
- Enhanced TestHelpers.gd
- Refactored 37+ test files to use helpers
- Performance assertion helpers

### Agent 2: Quality Assurance Engineer
**Track**: Track 2 (Error Handling & Edge Cases)
**Expertise**: Edge case identification, validation, negative testing
**Duration**: 2-3 days
**Deliverables**:
- test_error_handling.gd (30+ tests)
- test_edge_cases_comprehensive.gd (40+ tests)
- Documentation of error behavior

### Agent 3: Integration & Polish Engineer
**Track**: Track 3 (Valuation & Integration)
**Expertise**: Integration testing, API contracts, statistical analysis
**Duration**: 2 days
**Deliverables**:
- Split large test files (3 files → 9 files)
- test_api_contracts.gd
- test_statistical_properties.gd

---

## Risks & Mitigation

### Risk 1: Breaking Existing Tests
**Mitigation**:
- Run full test suite after each consolidation
- Use git branches per agent
- Merge incrementally (Track 1 → Track 2 → Track 3)

### Risk 2: TestHelpers Becomes Too Large
**Mitigation**:
- Keep helpers focused and single-purpose
- Document each helper clearly
- Consider splitting into TestHelpers + TestFixtures

### Risk 3: Performance Regressions
**Mitigation**:
- Run benchmarks before/after (BenchmarkRunner)
- Performance assertions prevent silent degradation

---

## Next Steps

1. **Review & Approve** this plan
2. **Spawn 3 agents** (1 per track)
3. **Track 1 completes first** (foundation for other tracks)
4. **Tracks 2 & 3 run in parallel** (after Track 1 Task 1.1 done)
5. **Integration testing** after all tracks complete
6. **Document lessons learned** for future test development
