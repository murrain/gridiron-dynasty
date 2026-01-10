# Task F5: Parallel Player Lifecycle Processing

**Track**: Performance Optimization (Track F)
**Dependencies**: F4 (Deep Copy Reduction)
**Status**: Not started
**Estimated Effort**: 1-2 days
**Priority**: P3 - Medium Impact

## Problem Statement

`PlayerLifecycle.advance_one_year()` processes players sequentially, even though each player's advancement is independent. This is a natural candidate for parallelization.

## Current Implementation

```gdscript
static func advance_one_year(players: Array, ..., rng: RandomNumberGenerator) -> Dictionary:
    var updated: Array = []
    var retired: Array = []
    updated.resize(players.size())

    for i in range(players.size()):
        var p: Dictionary = players[i]
        if p == null:
            updated[i] = p
            continue
        var evolved := _advance_player_one_year(p, ..., rng)  # Uses shared RNG
        if evolved.get("retired", false):
            retired.append(evolved.get("player", p))
            updated[i] = null
        else:
            updated[i] = evolved.get("player", p)

    return {"players": updated, "retired": retired, ...}
```

**Problem**: Shared `rng` prevents simple parallelization.

## Proposed Solution

### Seed Derivation for Parallel RNG

Pre-derive seeds for each player, then process in parallel:

```gdscript
static func advance_one_year_parallel(
    players: Array,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator,
    threads: int = 0
) -> Dictionary:
    if threads <= 0:
        threads = _default_threads()

    # Phase 1: Derive deterministic seeds for each player (serial, RNG-consuming)
    var seeds: Array = []
    seeds.resize(players.size())
    for i in range(players.size()):
        seeds[i] = rng.randi()  # Consume RNG in order

    # Phase 2: Process players in parallel (each with own RNG from derived seed)
    var items: Array = []
    items.resize(players.size())
    for i in range(players.size()):
        items[i] = {
            "player": players[i],
            "seed": seeds[i],
            "index": i
        }

    var results := ThreadPool.map(items, func(item):
        if item["player"] == null:
            return {"player": null, "retired": false, "index": item["index"]}

        var player_rng := RandomNumberGenerator.new()
        player_rng.seed = int(item["seed"])

        var evolved := _advance_player_one_year(
            item["player"],
            positions_cfg,
            main_cfg,
            stats_cfg,
            player_rng,
            {}  # development_context merged from player
        )
        evolved["index"] = item["index"]
        return evolved,
        threads
    )

    # Phase 3: Reconstruct output arrays (serial, maintains order)
    var updated: Array = []
    var retired: Array = []
    var development_reports: Array = []
    updated.resize(players.size())
    development_reports.resize(players.size())

    for result in results:
        var idx: int = result["index"]
        if result.get("retired", false):
            retired.append(result.get("player"))
            updated[idx] = null
        else:
            updated[idx] = result.get("player")
        development_reports[idx] = result.get("development_report", {})

    return {
        "players": updated,
        "retired": retired,
        "development_reports": development_reports
    }
```

## Implementation Plan

### Phase 1: Update PlayerLifecycle

**File**: `scripts/world/PlayerLifecycle.gd`

Add parallel variant alongside existing method:

```gdscript
const ThreadPool = preload("res://autoloads/ThreadPool.gd")
const Rand = preload("res://autoloads/Rand.gd")

static func advance_one_year_parallel(
    players: Array,
    positions_cfg: Dictionary,
    main_cfg: Dictionary,
    stats_cfg: Dictionary,
    rng: RandomNumberGenerator,
    threads: int = 0
) -> Dictionary:
    if players.size() < 100 or threads <= 1:
        # Fall back to serial for small arrays
        return advance_one_year(players, positions_cfg, main_cfg, stats_cfg, rng)

    # ... parallel implementation as above
```

### Phase 2: Update Callers

**HighSchoolSeason.gd**:
```gdscript
var progressed: Dictionary = PlayerLifecycle.advance_one_year_parallel(
    prepared_players,
    positions_cfg,
    main_cfg,
    stats_cfg,
    lifecycle_rng,
    _threads_count()
)
```

**CollegeSeason.gd**:
```gdscript
# Process each college's roster in parallel
var college_items := []
for college_id in rosters.keys():
    college_items.append({
        "college_id": college_id,
        "roster": rosters[college_id],
        "seed": rng.randi()
    })

var results := ThreadPool.map(college_items, func(item):
    var roster: Dictionary = item["roster"]
    var players: Array = roster.get("players", [])
    var college_rng := RandomNumberGenerator.new()
    college_rng.seed = item["seed"]

    var prepared := _apply_development_context(players, ...)
    return PlayerLifecycle.advance_one_year(prepared, ..., college_rng),
    _threads_count()
)
```

**NflSeason.gd**:
```gdscript
# Process each team's roster in parallel
var team_items := []
for team in teams:
    var team_id := String(team.get("id", ""))
    team_items.append({
        "team_id": team_id,
        "roster": rosters.get(team_id, {}),
        "seed": rng.randi()
    })

var results := ThreadPool.map(team_items, func(item):
    var roster: Dictionary = item["roster"]
    var players: Array = roster.get("players", [])
    var team_rng := RandomNumberGenerator.new()
    team_rng.seed = item["seed"]

    var prepared := _apply_nfl_development_context(players, team_rng, year)
    return PlayerLifecycle.advance_one_year(prepared, ..., team_rng),
    _threads_count()
)
```

## Determinism Verification

The key to preserving determinism:

1. **Seed derivation order**: Serial loop consumes RNG in consistent order
2. **Per-player RNG**: Each player gets deterministic RNG from derived seed
3. **Result ordering**: Results indexed by original position, not completion order

```gdscript
func _test_parallel_determinism(t):
    var players := _generate_test_players(1000)
    var rng1 := RandomNumberGenerator.new()
    var rng2 := RandomNumberGenerator.new()
    rng1.seed = 12345
    rng2.seed = 12345

    var serial := PlayerLifecycle.advance_one_year(players.duplicate(true), ..., rng1)
    var parallel := PlayerLifecycle.advance_one_year_parallel(players.duplicate(true), ..., rng2, 4)

    # Must produce identical results
    for i in range(players.size()):
        t.assert_deep_eq(serial.players[i], parallel.players[i])
```

## Thread Safety Considerations

1. **No shared mutable state**: Each thread works on its own player copy
2. **Config dictionaries read-only**: Shared across threads safely
3. **RNG per-thread**: Each player gets its own RNG instance
4. **Result array pre-sized**: Threads write to different indices

## Performance Expectations

| Roster Size | Serial Time | Parallel (4 threads) | Speedup |
|-------------|-------------|----------------------|---------|
| 100 players | 10ms | 10ms | 1x (overhead) |
| 500 players | 50ms | 15ms | 3.3x |
| 2000 players | 200ms | 60ms | 3.3x |

Expected improvement per year:
- HighSchoolSeason: 3s -> 1s
- CollegeSeason: 5s -> 2s
- NflSeason: 4s -> 1.5s
- **Total: ~7s savings per year**

## Test Coverage

**File**: `scripts/tests/test_parallel_lifecycle.gd`

```gdscript
func _test_parallel_correctness(t):
    # Parallel produces same results as serial
    pass

func _test_parallel_determinism(t):
    # Same seed produces same results
    pass

func _test_parallel_speedup(t):
    # Parallel is faster for large arrays
    var players := _generate_test_players(2000)
    var rng := RandomNumberGenerator.new()
    rng.seed = 42

    var start := Time.get_ticks_msec()
    PlayerLifecycle.advance_one_year(players.duplicate(true), ..., rng)
    var serial_time := Time.get_ticks_msec() - start

    rng.seed = 42
    start = Time.get_ticks_msec()
    PlayerLifecycle.advance_one_year_parallel(players.duplicate(true), ..., rng, 4)
    var parallel_time := Time.get_ticks_msec() - start

    t.assert_true(parallel_time < serial_time * 0.5, "Parallel should be 2x+ faster")

func _test_small_array_fallback(t):
    # Small arrays use serial path
    pass
```

## Acceptance Criteria

- [ ] `advance_one_year_parallel()` implemented
- [ ] HighSchoolSeason, CollegeSeason, NflSeason use parallel version
- [ ] Determinism preserved (verified by tests)
- [ ] Speedup of 2x+ for large rosters
- [ ] Fallback to serial for small arrays (<100 players)
- [ ] All existing tests pass

## Files to Modify

- `scripts/world/PlayerLifecycle.gd` - Add parallel method
- `scripts/world/HighSchoolSeason.gd` - Use parallel lifecycle
- `scripts/world/CollegeSeason.gd` - Use parallel lifecycle
- `scripts/world/NflSeason.gd` - Use parallel lifecycle

## Files to Create

- `scripts/tests/test_parallel_lifecycle.gd`

## Next Task

After completing F5, proceed to **TASK_F6_config_optimization.md** for config access optimization.
