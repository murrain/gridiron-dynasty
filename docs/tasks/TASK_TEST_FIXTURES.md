# Task: Test Fixtures Implementation (Phase 2)

**Track**: Testing Performance Strategy
**Dependencies**: None (can start immediately)
**Status**: Not started
**Estimated Effort**: 3-4 days
**Priority**: Medium (improves developer experience)

## Goal

Implement a test fixture system that pre-generates expensive test data (players, teams, world states) to reduce test suite execution time from ~140 seconds to ~30-45 seconds.

## Current Problem

Tests repeatedly generate the same expensive data:
- Player generation: ~2000 players per class (~10+ seconds)
- Multi-year simulations: 2-3 years of world advancement (~60-90 seconds)
- College/team generation: Regenerated for each test

**Impact**: Slow feedback loop, developers wait 2+ minutes per test run

## Implementation

### Step 1: Create Fixture Directory Structure

```bash
scripts/tests/fixtures/
  players/
    hs_class_100.json         # 100 HS players (seed: 42)
    draft_class_200.json      # 200 draft-ready players (seed: 43)
    college_recruits_50.json  # 50 recruits with ratings (seed: 44)
  teams/
    colleges_10.json          # 10 colleges (seed: 45)
    hs_schools_20.json        # 20 high schools (seed: 46)
    nfl_teams_4.json          # 4 NFL teams (seed: 47)
  world_states/
    year_1_populated.json     # World after 1 year (seed: 100)
    year_3_populated.json     # World after 3 years (seed: 100)
```

### Step 2: Create FixtureLoader Helper

**File**: `scripts/tests/FixtureLoader.gd`

```gdscript
class_name FixtureLoader

const FIXTURE_DIR := "res://scripts/tests/fixtures/"

## Load pre-generated player fixture
static func load_players(name: String) -> Array:
    var path := FIXTURE_DIR + "players/" + name + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Fixture not found: %s" % path)
        return []

    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    if parse_result != OK:
        push_error("Invalid JSON in fixture: %s" % path)
        return []

    var data := json.get_data()
    if data is Dictionary and data.has("players"):
        return data["players"]
    elif data is Array:
        return data
    return []

## Load pre-generated team fixture
static func load_teams(name: String) -> Array:
    var path := FIXTURE_DIR + "teams/" + name + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Fixture not found: %s" % path)
        return []

    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    if parse_result != OK:
        return []

    var data := json.get_data()
    if data is Dictionary and data.has("teams"):
        return data["teams"]
    elif data is Array:
        return data
    return []

## Load pre-generated world state fixture
static func load_world_state(name: String) -> Dictionary:
    var path := FIXTURE_DIR + "world_states/" + name + ".json"
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Fixture not found: %s" % path)
        return {}

    var json := JSON.new()
    var parse_result := json.parse(file.get_as_text())
    if parse_result != OK:
        return {}

    return json.get_data()

## Check if fixture exists (for optional fixtures)
static func fixture_exists(category: String, name: String) -> bool:
    var path := FIXTURE_DIR + category + "/" + name + ".json"
    return FileAccess.file_exists(path)
```

### Step 3: Create Fixture Generator Tool

**File**: `scripts/tools/GenerateTestFixtures.gd`

```gdscript
extends Node
## One-time tool to generate test fixtures
## Run with: godot --headless -s res://scripts/tools/GenerateTestFixtures.gd

const PlayerGenerator = preload("res://scripts/generation/PlayerGenerator.gd")
const CollegeGenerator = preload("res://scripts/world/CollegeGenerator.gd")
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const NflTeamGenerator = preload("res://scripts/world/NflTeamGenerator.gd")
const BootstrapGameWorld = preload("res://scripts/pipelines/BootstrapGameWorld.gd")

const FIXTURE_DIR := "res://scripts/tests/fixtures/"

func _ready() -> void:
    print("🔧 Generating test fixtures...")

    _create_directories()
    _generate_player_fixtures()
    _generate_team_fixtures()
    _generate_world_state_fixtures()

    print("✅ Test fixtures generated successfully")
    get_tree().quit()

func _create_directories() -> void:
    DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "players/")
    DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "teams/")
    DirAccess.make_dir_recursive_absolute(FIXTURE_DIR + "world_states/")

func _generate_player_fixtures() -> void:
    print("  Generating player fixtures...")
    var gen := PlayerGenerator.new()

    # 100 HS players
    var rng1 := _create_rng(42)
    var hs_class := gen.generate_class(100, 0.7, rng1)
    _save_fixture("players/hs_class_100.json", {
        "_meta": _fixture_meta("100 HS players", 42),
        "players": hs_class
    })

    # 200 draft-ready players
    var rng2 := _create_rng(43)
    var draft_class := gen.generate_class(200, 0.7, rng2)
    _save_fixture("players/draft_class_200.json", {
        "_meta": _fixture_meta("200 draft-ready players", 43),
        "players": draft_class
    })

    # 50 college recruits
    var rng3 := _create_rng(44)
    var recruits := gen.generate_class(50, 0.7, rng3)
    _save_fixture("players/college_recruits_50.json", {
        "_meta": _fixture_meta("50 college recruits", 44),
        "players": recruits
    })

    print("    ✓ Player fixtures generated")

func _generate_team_fixtures() -> void:
    print("  Generating team fixtures...")

    # 10 colleges
    var college_gen := CollegeGenerator.new()
    var colleges := college_gen.generate(45, "world/colleges")
    _save_fixture("teams/colleges_10.json", {
        "_meta": _fixture_meta("10 colleges", 45),
        "teams": colleges.get("colleges", []).slice(0, 10)
    })

    # 20 high schools
    var hs_gen := HighSchoolGenerator.new()
    var hs_schools := hs_gen.generate(46, "world/high_schools")
    _save_fixture("teams/hs_schools_20.json", {
        "_meta": _fixture_meta("20 high schools", 46),
        "teams": hs_schools.get("schools", []).slice(0, 20)
    })

    # 4 NFL teams
    var nfl_gen := NflTeamGenerator.new()
    var nfl_teams := nfl_gen.generate(47, "world/league")
    _save_fixture("teams/nfl_teams_4.json", {
        "_meta": _fixture_meta("4 NFL teams", 47),
        "teams": nfl_teams.get("teams", []).slice(0, 4)
    })

    print("    ✓ Team fixtures generated")

func _generate_world_state_fixtures() -> void:
    print("  Generating world state fixtures (this will take a minute)...")

    # 1-year world state
    var bootstrap1 := BootstrapGameWorld.new()
    bootstrap1.years_to_simulate = 1
    var result1 := bootstrap1.run(100)
    _save_fixture("world_states/year_1_populated.json", {
        "_meta": _fixture_meta("World state after 1 year", 100),
        "world_state": result1.world_state,
        "summary": result1.summary
    })

    # 3-year world state
    var bootstrap3 := BootstrapGameWorld.new()
    bootstrap3.years_to_simulate = 3
    var result3 := bootstrap3.run(100)
    _save_fixture("world_states/year_3_populated.json", {
        "_meta": _fixture_meta("World state after 3 years", 100),
        "world_state": result3.world_state,
        "summary": result3.summary
    })

    print("    ✓ World state fixtures generated")

func _save_fixture(relative_path: String, data: Dictionary) -> void:
    var path := FIXTURE_DIR + relative_path
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Failed to write fixture: %s" % path)
        return
    file.store_string(JSON.stringify(data, "  "))

func _fixture_meta(description: String, seed: int) -> Dictionary:
    return {
        "generated_date": Time.get_datetime_string_from_system(),
        "description": description,
        "seed": seed,
        "generator_version": "Phase 2"
    }

func _create_rng(seed: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    return rng
```

### Step 4: Update Tests to Use Fixtures

**Example**: `test_college_recruiting.gd` (before/after)

```gdscript
# BEFORE (slow - 13+ seconds)
func _test_recruiting_flow(t):
    var generator := PlayerGenerator.new()
    var recruits := generator.generate_class(500, 0.7, rng)  # 10+ seconds

    var college_gen := CollegeGenerator.new()
    var colleges := college_gen.generate(seed, "world/colleges")  # 2+ seconds

    var recruiting := CollegeRecruiting.new()
    var result := recruiting.run(recruits, colleges, config, ...)  # 1 second

    t.assert_true(result.commitments.size() > 0)

# AFTER (fast - 1 second)
func _test_recruiting_flow(t):
    var recruits := FixtureLoader.load_players("college_recruits_50")  # <0.1 seconds
    var colleges := FixtureLoader.load_teams("colleges_10")  # <0.1 seconds

    var recruiting := CollegeRecruiting.new()
    var result := recruiting.run(recruits, colleges, config, ...)  # 1 second

    t.assert_true(result.commitments.size() > 0)
```

### Step 5: Update Test Suite

**Priority tests to migrate** (highest impact first):
1. `test_bootstrap_game_world.gd` - Use `year_3_populated.json` fixture
2. `test_world_history_preview.gd` - Use world state fixtures
3. `test_college_recruiting.gd` - Use recruit + college fixtures
4. `test_nfl_draft.gd` - Use draft class + NFL team fixtures
5. `test_high_school_season.gd` - Use HS player + school fixtures

## Fixture Maintenance

### When to Regenerate Fixtures

✅ **Do regenerate when**:
- Player model schema changes (add/remove fields)
- Generation algorithms change significantly
- New test scenarios require different data

❌ **Don't regenerate for**:
- Cosmetic code changes
- Bug fixes that don't affect data structure
- Config tuning (eliteness, weights, etc.)

### Fixture Documentation

Each fixture includes `_meta` field:
```json
{
  "_meta": {
    "generated_date": "2026-01-10",
    "description": "50 college recruits with varied ratings",
    "seed": 44,
    "generator_version": "Phase 2"
  },
  "players": [...]
}
```

## Testing Strategy

### Unit Tests vs Integration Tests

- **Unit tests**: Use small fixtures (50-100 entities)
- **Integration tests**: Use world state fixtures (pre-simulated)
- **Generation tests**: Use smaller counts (50 instead of 2000)

### Philosophy

Tests verify **correctness**, not **scale**. A test with 50 players is just as valid as one with 2000 players for verifying logic.

## Acceptance Criteria

- [ ] FixtureLoader.gd created and tested
- [ ] GenerateTestFixtures.gd tool created
- [ ] All fixtures generated and committed to git
- [ ] Top 5 slowest tests migrated to use fixtures
- [ ] Test suite execution time < 45 seconds
- [ ] All tests still pass with fixtures
- [ ] Fixture documentation complete

## Files to Create

- `scripts/tests/FixtureLoader.gd`
- `scripts/tools/GenerateTestFixtures.gd`
- `scripts/tests/fixtures/**/*.json` (fixture data files)

## Files to Modify

- `scripts/tests/test_bootstrap_game_world.gd`
- `scripts/tests/test_world_history_preview.gd`
- `scripts/tests/test_college_recruiting.gd`
- `scripts/tests/test_nfl_draft.gd`
- `scripts/tests/test_high_school_season.gd`

## Expected Performance Improvement

| Milestone | Current | Target | Improvement |
|-----------|---------|--------|-------------|
| Full test suite | 141s | 30-45s | 3-5x faster |
| Developer feedback loop | 141s | 30-45s | 3-5x faster |

## Next Task

After completing fixtures, proceed to **TASK_TEST_PARALLEL.md** for Phase 3 (parallel test execution).
