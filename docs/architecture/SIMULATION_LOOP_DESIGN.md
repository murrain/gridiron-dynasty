# Simulation Loop Design

**Feature**: Tick-Based Simulation Architecture
**Status**: Design Phase
**Created**: 2026-01-16
**Related**: `GAME_SAVES_IMPLEMENTATION_PLAN.md`

---

## Overview

This document outlines the design for the tick-based simulation loop that will drive gameplay progression. The current system uses phase-based simulation (HS season, draft, etc.). This design evolves that into a finer-grained tick system.

### Current State

The existing `BootstrapGameWorld.gd` operates in discrete phases:
- High School season simulation
- NFL Draft
- Rookie Development
- Season progression

### Target State

A unified tick-based loop where:
- Game time progresses in discrete ticks
- Each tick triggers relevant systems
- Events affect player/team state
- AI teams evaluate and act on roster needs
- Player-coach receives notifications and can act

---

## Tick Architecture

### Tick Frequency Options

| Option | Description | Use Case |
|--------|-------------|----------|
| **Daily Ticks** | One tick per in-game day | Most granular; allows daily events, training, injuries |
| **2x Weekly** | Pre-game and Post-game ticks | Balance between granularity and performance |
| **Weekly** | One tick per week | Simpler; good for offseason |

**Recommendation**: Variable tick frequency based on season phase:

```gdscript
enum TickFrequency {
    DAILY,      # Offseason - free agency, training
    TWICE_WEEKLY,  # Regular season - pre-game prep, post-game results
    WEEKLY      # Preseason, combine, draft
}
```

### Tick Lifecycle

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TICK START                                  │
│                                                                     │
│   1. Advance game clock (date/time)                                │
│   2. Trigger scheduled events for this tick                        │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                        EVENT PROCESSING                             │
│                                                                     │
│   3. Process triggered events                                      │
│      └── Each event may:                                           │
│          • Modify player stats (via implications)                  │
│          • Generate follow-up events                               │
│          • Emit signals for AI/UI notification                     │
│                                                                     │
│   4. Apply event implications                                      │
│      └── StatModifier updates to players/teams                     │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                        AI EVALUATION                                │
│                                                                     │
│   5. AI teams evaluate roster (if cache invalidated)               │
│      └── AITeamNeedsCache provides candidates                      │
│      └── AI may initiate trades, signings, cuts                    │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                        INDEX REBUILD                                │
│                                                                     │
│   6. Rebuild OptimizedPlayerQueries indexes                        │
│      └── Only if roster changes occurred this tick                 │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                       PLAYER-COACH TURN                             │
│                                                                     │
│   7. Notify player-coach of relevant events                        │
│   8. Wait for player-coach actions (if any pending)                │
│   9. Process player-coach decisions                                │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                         TICK END                                    │
│                                                                     │
│  10. Emit tick_completed signal                                    │
│  11. Check for phase transitions (season end, etc.)                │
│  12. Auto-save checkpoint (if configured)                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### SimulationLoop

```gdscript
class_name SimulationLoop
extends Node

## Main simulation loop controller
##
## Manages tick progression, event scheduling, and system coordination.

signal tick_started(tick_data: TickData)
signal tick_completed(tick_data: TickData)
signal phase_changed(old_phase: int, new_phase: int)
signal player_action_required(action_type: String, context: Dictionary)

var _world_state: Dictionary
var _player_queries: OptimizedPlayerQueries
var _ai_needs_cache: AITeamNeedsCache
var _event_scheduler: EventScheduler
var _current_tick: int = 0
var _paused: bool = false
var _awaiting_player_action: bool = false

## Advance simulation by one tick
func advance_tick() -> void:
    if _paused or _awaiting_player_action:
        return

    _current_tick += 1
    var tick_data := TickData.new(_current_tick, _get_current_date())
    tick_started.emit(tick_data)

    # 1. Process scheduled events
    var events := _event_scheduler.get_events_for_tick(_current_tick)
    var roster_changed := false

    for event in events:
        var result := _process_event(event)
        if result.roster_changed:
            roster_changed = true

    # 2. AI evaluation (only if relevant events occurred)
    if roster_changed:
        _invalidate_ai_caches(events)
        _run_ai_evaluation()

    # 3. Rebuild indexes if needed
    if roster_changed:
        _player_queries.rebuild_indexes(_world_state)

    # 4. Check for player-coach notifications
    var player_notifications := _get_player_notifications(events)
    if not player_notifications.is_empty():
        _notify_player_coach(player_notifications)

    # 5. Complete tick
    tick_completed.emit(tick_data)
    _check_phase_transition()

func _process_event(event: GameEvent) -> EventResult:
    # Apply event implications (stat modifiers)
    var result := EventResult.new()

    for implication in event.implications:
        match implication.type:
            "stat_modifier":
                _apply_stat_modifier(implication)
            "roster_change":
                result.roster_changed = true
                _apply_roster_change(implication)
            "generate_event":
                _event_scheduler.schedule(implication.event)

    return result

func _invalidate_ai_caches(events: Array) -> void:
    for event in events:
        if event.affects_roster():
            _ai_needs_cache.on_roster_event(event.to_dict())

func _run_ai_evaluation() -> void:
    for team_id in _get_ai_team_ids():
        var candidates := _ai_needs_cache.get_candidates(team_id, _player_queries)
        if not candidates.is_empty():
            _ai_consider_moves(team_id, candidates)
```

### EventScheduler

```gdscript
class_name EventScheduler
extends RefCounted

## Manages event scheduling and retrieval
##
## Events can be scheduled for specific ticks or date ranges.

var _scheduled_events: Dictionary = {}  # tick -> Array[GameEvent]
var _recurring_events: Array = []       # Events that repeat

func schedule(event: GameEvent, tick: int = -1) -> void:
    if tick < 0:
        tick = _calculate_tick_for_date(event.scheduled_date)

    if not _scheduled_events.has(tick):
        _scheduled_events[tick] = []
    _scheduled_events[tick].append(event)

func get_events_for_tick(tick: int) -> Array:
    var events: Array = []

    # Scheduled events
    if _scheduled_events.has(tick):
        events.append_array(_scheduled_events[tick])

    # Recurring events (check if this tick matches pattern)
    for recurring in _recurring_events:
        if recurring.matches_tick(tick):
            events.append(recurring.generate())

    return events

func clear_past_events(current_tick: int) -> void:
    var to_remove: Array = []
    for tick in _scheduled_events.keys():
        if tick < current_tick:
            to_remove.append(tick)

    for tick in to_remove:
        _scheduled_events.erase(tick)
```

### TickData

```gdscript
class_name TickData
extends RefCounted

## Data structure representing a single simulation tick

var tick_number: int
var game_date: Dictionary  # { year, month, day, week }
var phase: int             # Current season phase
var events_processed: int = 0
var roster_changes: int = 0
var ai_moves: int = 0

func _init(p_tick: int, p_date: Dictionary) -> void:
    tick_number = p_tick
    game_date = p_date
```

---

## Event System Integration

### Event Implications for Roster Interest

Events should include implications that affect trade availability. Example:

```gdscript
# Player receives DUI event
var dui_event := GameEvent.new({
    "type": "off_field_incident",
    "subtype": "dui",
    "player_id": player.id,
    "implications": [
        {
            "type": "stat_modifier",
            "stat": "loyalty",
            "modifier": -15,  # Loyalty drops
            "duration": "permanent"
        },
        {
            "type": "stat_modifier",
            "stat": "reputation",
            "modifier": -10,
            "duration": 52  # Recovers over ~1 year
        },
        {
            "type": "roster_interest_change",
            "available_for_trade": true  # Team more willing to trade
        }
    ]
})
```

### AI Response to Events

When loyalty drops below threshold, AI teams can:
1. Flag player as available for trade
2. Re-evaluate roster needs
3. Search for replacements

```gdscript
# In AITeamNeedsCache._meets_criteria()
func _meets_criteria(player: Variant, criteria: Dictionary) -> bool:
    # ... other checks ...

    # Check trade availability (loyalty-based)
    var require_available: bool = criteria.get("require_available", true)
    if require_available:
        var loyalty := _get_player_stat(player, "loyalty")
        if loyalty > 80:  # High loyalty = unlikely to be available
            return false

    return true
```

---

## Performance Considerations

### Tick Performance Budget

For smooth gameplay, each tick should complete in < 100ms:

| Operation | Target Time |
|-----------|-------------|
| Event processing | < 20ms |
| AI evaluation (32 teams) | < 40ms |
| Index rebuild | < 30ms |
| UI notifications | < 10ms |

### Optimization Strategies

1. **Lazy AI Evaluation**: Only evaluate teams affected by events
2. **Incremental Index Updates**: Update indexes incrementally vs full rebuild
3. **Event Batching**: Process multiple events before triggering AI
4. **Background Processing**: Non-critical calculations in background thread

### Index Rebuild Strategy

```gdscript
## Option A: Full rebuild (simple, ~50ms for 10k players)
func rebuild_all() -> void:
    _clear_indexes()
    for player in all_players:
        _index_player(player)

## Option B: Incremental update (complex, ~1ms per change)
func update_player(player: Player, old_team: String, new_team: String) -> void:
    # Remove from old indexes
    _players_by_team[old_team].erase(player)

    # Add to new indexes
    if not _players_by_team.has(new_team):
        _players_by_team[new_team] = []
    _players_by_team[new_team].append(player)
```

**Recommendation**: Start with Option A (full rebuild). Only optimize to Option B if profiling shows it's needed.

---

## Save Integration

### Checkpoint Saves

The simulation loop integrates with the save system:

```gdscript
func advance_tick() -> void:
    # ... tick processing ...

    tick_completed.emit(tick_data)

    # Auto-checkpoint every N ticks
    if _current_tick % AUTO_SAVE_INTERVAL == 0:
        PersistenceLayer.checkpoint_save(_world_state)

func restore_from_save(save_name: String) -> void:
    _world_state = PersistenceLayer.load_world_state(save_name)
    _current_tick = _world_state.get("current_tick", 0)
    _player_queries.rebuild_indexes(_world_state)
    _event_scheduler.restore(_world_state.get("scheduled_events", {}))
```

### RNG State Preservation

For deterministic replay, RNG state must be saved:

```gdscript
func _prepare_save_data() -> Dictionary:
    return {
        "current_tick": _current_tick,
        "rng_state": Rand.get_state(),
        "world_state": _world_state,
        "scheduled_events": _event_scheduler.serialize()
    }

func _restore_from_save(data: Dictionary) -> void:
    _current_tick = data.current_tick
    Rand.set_state(data.rng_state)
    _world_state = data.world_state
    _event_scheduler.deserialize(data.scheduled_events)
```

---

## Player-Coach Interaction

### Action Queue

Player-coach actions are queued and processed during their turn:

```gdscript
enum PlayerAction {
    TRADE_PROPOSAL,
    SIGN_FREE_AGENT,
    CUT_PLAYER,
    SCOUT_PLAYER,
    SKIP_TURN
}

var _player_action_queue: Array = []

func queue_player_action(action: PlayerAction, data: Dictionary) -> void:
    _player_action_queue.append({
        "action": action,
        "data": data
    })

func process_player_actions() -> void:
    for queued in _player_action_queue:
        match queued.action:
            PlayerAction.TRADE_PROPOSAL:
                _process_trade_proposal(queued.data)
            PlayerAction.SCOUT_PLAYER:
                _process_scout_action(queued.data)
            # ... etc

    _player_action_queue.clear()
    _awaiting_player_action = false
```

### Turn-Based vs Real-Time

Two modes of operation:

| Mode | Description |
|------|-------------|
| **Turn-Based** | Simulation pauses for player decisions |
| **Real-Time** | Simulation continues; player has limited time window |

```gdscript
func set_game_mode(mode: GameMode) -> void:
    match mode:
        GameMode.TURN_BASED:
            _awaiting_player_action = true
            player_action_required.emit("turn", {})

        GameMode.REAL_TIME:
            # Start timer for player response
            _action_timer.start(PLAYER_ACTION_TIMEOUT)
```

---

## Phase Transitions

### Season Phases

```gdscript
enum SeasonPhase {
    OFFSEASON,      # Free agency, trades, training
    PRESEASON,      # Exhibition games
    REGULAR_SEASON, # 17-week season
    PLAYOFFS,       # Postseason games
    DRAFT           # NFL Draft
}
```

### Phase Transition Logic

```gdscript
func _check_phase_transition() -> void:
    var current_date := _get_current_date()

    match _current_phase:
        SeasonPhase.OFFSEASON:
            if current_date.month == 8 and current_date.day >= 1:
                _transition_to_phase(SeasonPhase.PRESEASON)

        SeasonPhase.PRESEASON:
            if current_date.month == 9 and current_date.day >= 7:
                _transition_to_phase(SeasonPhase.REGULAR_SEASON)

        # ... etc

func _transition_to_phase(new_phase: SeasonPhase) -> void:
    var old_phase := _current_phase
    _current_phase = new_phase

    # Adjust tick frequency for new phase
    match new_phase:
        SeasonPhase.OFFSEASON:
            _tick_frequency = TickFrequency.DAILY
        SeasonPhase.REGULAR_SEASON:
            _tick_frequency = TickFrequency.TWICE_WEEKLY
        SeasonPhase.DRAFT:
            _tick_frequency = TickFrequency.WEEKLY

    phase_changed.emit(old_phase, new_phase)
```

---

## Determinism and RNG Architecture

### Core Principles

The simulation system must produce **identical results** given identical inputs and seeds. This enables:
- **Reproducible simulations**: Same seed = same 20-year outcome
- **Debugging**: Replay exact sequences to diagnose issues
- **Testing**: Verify correctness with known seeds
- **Save integrity**: Load/save doesn't introduce randomness

### RNG Seeding Strategy

The codebase uses `Rand.gd` (autoload) which provides SplitMix64-based deterministic seed derivation.

```gdscript
## Per-Tick RNG Seeding Pattern
##
## CRITICAL: Never use Math.random() or create unseeded RNG instances.
## Always derive seeds from the base seed using Rand.derive_seeds().

class_name SimulationLoop

var _tick_base_seed: int = 0  # Set at simulation start
var _current_tick: int = 0

func initialize_simulation(base_seed: int) -> void:
	_tick_base_seed = base_seed
	Rand.set_base_seed(base_seed)
	print("Simulation initialized with seed: %d" % base_seed)

func advance_tick() -> void:
	_current_tick += 1

	# Derive a unique seed for this tick using SplitMix64
	# Expected RNG consumption: 0 (pure calculation)
	var tick_seed := Rand.splitmix64(_tick_base_seed + _current_tick)
	var tick_rng := Rand.rng_for_seed(tick_seed)

	# All operations in this tick use tick_rng
	_process_tick_events(tick_rng)
	_run_ai_evaluation(tick_rng)
	_simulate_scheduled_games(tick_rng)

func _process_tick_events(rng: RandomNumberGenerator) -> void:
	# Events may need sub-seeds for multi-step operations
	# Derive sub-seeds deterministically using index-based seeding
	var events := _event_scheduler.get_events_for_tick(_current_tick)

	for i in range(events.size()):
		var event: GameEvent = events[i]
		# Each event gets a unique sub-seed derived from tick RNG state
		# Expected RNG consumption: 1 randi() per event for sub-seed generation
		var event_seed := rng.randi()
		var event_rng := Rand.rng_for_seed(event_seed)
		_process_single_event(event, event_rng)
```

### RNG Passing Patterns

**Pattern 1: Direct Pass-Through** (Simple operations)

```gdscript
## Use this when an operation consumes RNG directly without sub-operations

func determine_injury_occurrence(player: Player, rng: RandomNumberGenerator) -> bool:
	# Expected RNG consumption: 1 randf() call
	var injury_chance := _calculate_injury_risk(player)  # Pure calculation
	var roll := rng.randf()
	return roll < injury_chance

func _calculate_injury_risk(player: Player) -> float:
	# Expected RNG consumption: 0 (pure calculation)
	var age_factor := clamp(player.age - 25, 0, 10) * 0.01
	var wear_factor := float(player.career.wear.get("snaps", 0)) / 10000.0
	return min(0.15, 0.02 + age_factor + wear_factor)
```

**Pattern 2: Index-Based Sub-Seeding** (Parallel operations)

```gdscript
## Use this when processing multiple independent items in a loop

func simulate_all_games_in_week(games: Array, rng: RandomNumberGenerator) -> Array:
	var results: Array = []

	for i in range(games.size()):
		# Derive sub-seed from index for deterministic parallel processing
		# Expected RNG consumption: 1 randi() per game
		var game_seed := rng.randi()
		var game_rng := Rand.rng_for_seed(game_seed)

		# Each game simulation is independent
		var result := GameSimulator.determine_winner(
			games[i],
			_team_strengths,
			game_rng,
			_sim_config
		)
		results.append(result)

	return results
```

**Pattern 3: Sequential Sub-Seeding** (Dependent operations)

```gdscript
## Use this when operations depend on prior RNG results

func process_draft_pick(pick: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# Step 1: Determine if team trades pick
	# Expected RNG consumption: 1 randf()
	var trade_chance := _calculate_trade_likelihood(pick)
	var trade_roll := rng.randf()

	if trade_roll < trade_chance:
		# Step 2: If traded, select trading partner
		# Expected RNG consumption: 1 randi_range()
		var trading_partners := _get_potential_trading_partners(pick)
		var partner_idx := rng.randi_range(0, trading_partners.size() - 1)
		return _execute_trade(pick, trading_partners[partner_idx], rng)
	else:
		# Step 3: Team keeps pick, select player
		# Expected RNG consumption: Variable (depends on AI evaluation)
		return _ai_select_player(pick, rng)
```

### Replay Determinism Verification

**Test Pattern for Determinism**

```gdscript
## Test class demonstrating determinism verification
extends RefCounted

const SimulationLoop = preload("res://scripts/core/simulation/SimulationLoop.gd")

func test_20_year_determinism() -> bool:
	var seed := 123456789
	var num_years := 20

	# Run 1: Full 20-year simulation
	var sim1 := SimulationLoop.new()
	sim1.initialize_simulation(seed)
	var results1 := _run_simulation_years(sim1, num_years)

	# Run 2: Identical configuration
	var sim2 := SimulationLoop.new()
	sim2.initialize_simulation(seed)
	var results2 := _run_simulation_years(sim2, num_years)

	# Verify: Results must be byte-for-byte identical
	var hash1 := _hash_simulation_state(results1)
	var hash2 := _hash_simulation_state(results2)

	if hash1 != hash2:
		push_error("Determinism violation: Hash mismatch")
		_log_first_difference(results1, results2)
		return false

	print("Determinism verified: 20-year simulation reproduced exactly")
	return true

func _hash_simulation_state(state: Dictionary) -> String:
	# Hash critical state components for comparison
	var json := JSON.stringify(state, "\t", false)
	return json.sha256_text()

func _log_first_difference(state1: Dictionary, state2: Dictionary) -> void:
	# Deep comparison to find first divergence point
	for key in state1.keys():
		if state1[key] != state2[key]:
			push_error("First difference at key: %s" % key)
			push_error("  Run 1: %s" % str(state1[key]))
			push_error("  Run 2: %s" % str(state2[key]))
			return
```

### Handling RNG Across Parallel Operations

When simulating multiple independent entities in parallel (e.g., 32 AI teams evaluating rosters), ensure each receives a deterministic sub-seed:

```gdscript
func _run_ai_evaluation_for_all_teams(rng: RandomNumberGenerator) -> void:
	# Get all AI team IDs (deterministic order)
	var ai_teams := _get_ai_team_ids()  # Always return same sorted order
	ai_teams.sort()  # Explicit sort for determinism

	# Process each team with a derived seed
	for i in range(ai_teams.size()):
		var team_id: String = ai_teams[i]

		# Derive team-specific seed from index
		# Expected RNG consumption: 1 randi() per team
		var team_seed := rng.randi()
		var team_rng := Rand.rng_for_seed(team_seed)

		# AI evaluation is now deterministic per team
		_evaluate_single_team(team_id, team_rng)
```

**CRITICAL**: Never parallelize operations that share mutable state. Even with sub-seeds, race conditions break determinism.

### Integration with Save System

The RNG state must be persisted for mid-simulation saves:

```gdscript
func _prepare_save_data() -> Dictionary:
	return {
		"simulation_version": "1.0.0",
		"tick_base_seed": _tick_base_seed,
		"current_tick": _current_tick,
		"rng_state": _serialize_rng_state(),  # If using stateful RNG
		"scheduled_events": _event_scheduler.serialize(),
		"world_state": _world_state
	}

func _serialize_rng_state() -> Dictionary:
	# If maintaining a persistent RNG across ticks (alternative pattern)
	# Store internal state for restoration
	# NOTE: Current design uses tick-derived seeds (no persistent state needed)
	return {
		"seed": _tick_base_seed,
		"tick": _current_tick
	}

func _restore_from_save(data: Dictionary) -> void:
	_tick_base_seed = int(data.get("tick_base_seed", 0))
	_current_tick = int(data.get("current_tick", 0))

	# Restore RNG state if using persistent pattern
	var rng_state: Dictionary = data.get("rng_state", {})
	# Current design: No action needed, tick-derived seeds handle this

	_event_scheduler.deserialize(data.get("scheduled_events", {}))
	_world_state = data.get("world_state", {})
```

### RNG Consumption Documentation Pattern

**Every function that uses RNG must document its consumption:**

```gdscript
## Generates a random injury for a player.
##
## RNG Consumption Pattern:
##   - 1 randf() to determine injury type from weighted distribution
##   - 1 randf_range() to determine severity (0.0-1.0)
##   - 1 randi_range() to determine recovery weeks (1-16)
##   Total: 3 RNG calls per invocation
##
## @param player: Player to injure
## @param rng: RandomNumberGenerator (explicit, caller-controlled)
## @return: Injury instance
func generate_injury(player: Player, rng: RandomNumberGenerator) -> Injury:
	# RNG call 1: Injury type selection
	var injury_types := ["ACL", "MCL", "Hamstring", "Concussion", "Fracture"]
	var weights := [0.10, 0.15, 0.30, 0.25, 0.20]  # Sums to 1.0
	var roll := rng.randf()
	var injury_type := _weighted_select(injury_types, weights, roll)

	# RNG call 2: Severity determination
	var severity := rng.randf()

	# RNG call 3: Recovery timeline
	var min_weeks := 1 if severity < 0.5 else 4
	var max_weeks := 4 if severity < 0.5 else 16
	var recovery_weeks := rng.randi_range(min_weeks, max_weeks)

	var injury := Injury.new()
	injury.type = injury_type
	injury.severity = severity
	injury.recovery_timeline = {
		"weeks_total": recovery_weeks,
		"weeks_elapsed": 0
	}

	return injury
```

### Testing Strategies for Determinism

**1. Unit Test: Single Function Determinism**

```gdscript
func test_function_determinism() -> void:
	var seed := 42
	var player := _create_test_player()

	# Run 100 times with same seed
	var results := []
	for i in range(100):
		var rng := Rand.rng_for_seed(seed)
		var result := generate_injury(player, rng)
		results.append(result.to_dict())

	# Verify all results identical
	var first := results[0]
	for i in range(1, results.size()):
		assert(results[i] == first, "Result %d differs from first result" % i)
```

**2. Integration Test: Full Tick Determinism**

```gdscript
func test_tick_determinism() -> void:
	var seed := 999

	# Run same tick 10 times
	var tick_results := []
	for i in range(10):
		var sim := SimulationLoop.new()
		sim.initialize_simulation(seed)
		sim.advance_tick()
		tick_results.append(_capture_world_state(sim))

	# Verify all ticks produced identical world state
	for i in range(1, tick_results.size()):
		_assert_states_equal(tick_results[0], tick_results[i])
```

**3. System Test: Multi-Season Determinism**

```gdscript
func test_multi_season_determinism() -> void:
	var seeds := [111, 222, 333]

	for seed in seeds:
		var sim1 := _run_full_season(seed)
		var sim2 := _run_full_season(seed)

		var hash1 := _hash_final_state(sim1)
		var hash2 := _hash_final_state(sim2)

		assert(hash1 == hash2, "Season with seed %d is non-deterministic" % seed)
```

### Common Determinism Pitfalls

**❌ NEVER DO THIS:**

```gdscript
# BAD: Creating new unseeded RNG
func bad_random_selection(items: Array) -> Variant:
	var rng := RandomNumberGenerator.new()  # DETERMINISM VIOLATION
	return items[rng.randi_range(0, items.size() - 1)]

# BAD: Using Math functions with hidden RNG state
func bad_shuffle(items: Array) -> void:
	items.shuffle()  # DETERMINISM VIOLATION: Uses global RNG

# BAD: Relying on iteration order of Dictionary keys
func bad_team_processing(teams: Dictionary, rng: RandomNumberGenerator) -> void:
	for team_id in teams.keys():  # DETERMINISM VIOLATION: Order not guaranteed
		_process_team(team_id, rng)

# BAD: Using system time or external state
func bad_seed_generation() -> int:
	return Time.get_ticks_msec()  # DETERMINISM VIOLATION
```

**✅ ALWAYS DO THIS:**

```gdscript
# GOOD: Explicit RNG parameter
func good_random_selection(items: Array, rng: RandomNumberGenerator) -> Variant:
	return items[rng.randi_range(0, items.size() - 1)]

# GOOD: Manual Fisher-Yates with explicit RNG
func good_shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp

# GOOD: Sort keys for deterministic order
func good_team_processing(teams: Dictionary, rng: RandomNumberGenerator) -> void:
	var team_ids: Array = teams.keys()
	team_ids.sort()  # Deterministic order
	for team_id in team_ids:
		_process_team(team_id, rng)

# GOOD: Use provided seed from game state
func good_seed_generation(base_seed: int, context_id: int) -> int:
	return Rand.splitmix64(base_seed + context_id)
```

---

## Event Processing Pipeline

### Event Structure

Events are the primary mechanism for state changes in the simulation. Each event represents a discrete occurrence that affects player, team, or league state.

```gdscript
class_name GameEvent
extends Resource

## Event types determine processing priority and handler routing
enum EventType {
	# Phase 1: Core events (implement first)
	GAME_RESULT,           # Game outcome with stats
	INJURY_OCCURRED,       # Player injured during game
	CONTRACT_SIGNED,       # Player signs contract
	CONTRACT_EXPIRED,      # Contract reaches end
	PLAYER_RETIRED,        # Player retires
	PLAYER_AGED,           # Player birthday (age increment)
	DRAFT_PICK_MADE,       # Draft selection executed
	TRADE_COMPLETED,       # Trade finalized

	# Phase 2: Advanced events (future implementation)
	FREE_AGENT_SIGNED,     # FA signing
	PLAYER_CUT,            # Player released
	TRAINING_COMPLETED,    # Training camp results
	AWARD_RECEIVED,        # Player wins award
	PLAYOFF_BERTH,         # Team makes playoffs
	CHAMPIONSHIP_WON,      # Team wins championship
	OFF_FIELD_INCIDENT,    # Player discipline event
	COACH_FIRED,           # Coaching change
	SCHEME_CHANGE          # Team changes offensive/defensive scheme
}

## Event priority determines processing order within a tick
## Lower priority number = processed first
enum EventPriority {
	CRITICAL = 0,    # Must execute first (e.g., time advancement)
	HIGH = 1,        # Important state changes (e.g., contracts)
	NORMAL = 2,      # Standard events (e.g., game results)
	LOW = 3,         # Background events (e.g., stat updates)
	DEFERRED = 4     # Process last (e.g., cleanup tasks)
}

@export var event_id: String = ""
@export var event_type: EventType = EventType.GAME_RESULT
@export var priority: EventPriority = EventPriority.NORMAL
@export var tick: int = 0             # Tick when event should trigger
@export var year: int = 0              # Season year
@export var week: int = 0              # Week number (if applicable)
@export var source_entity: String = "" # Entity that triggered event (player_id, team_id)
@export var target_entities: Array[String] = []  # Entities affected

## Implications are state changes resulting from this event
## Processed by EventProcessor after event validation
@export var implications: Array[Dictionary] = []

## Cascading events are new events triggered by this event
## Scheduled by EventScheduler during event processing
@export var cascading_events: Array[GameEvent] = []

## Event metadata for debugging and logging
@export var metadata: Dictionary = {}

func from_dict(d: Dictionary) -> void:
	event_id = String(d.get("event_id", event_id))
	event_type = int(d.get("event_type", event_type)) as EventType
	priority = int(d.get("priority", priority)) as EventPriority
	tick = int(d.get("tick", tick))
	year = int(d.get("year", year))
	week = int(d.get("week", week))
	source_entity = String(d.get("source_entity", source_entity))
	target_entities = (d.get("target_entities", target_entities) as Array).duplicate()
	implications = (d.get("implications", implications) as Array).duplicate(true)
	metadata = (d.get("metadata", metadata) as Dictionary).duplicate(true)

func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"event_type": event_type,
		"priority": priority,
		"tick": tick,
		"year": year,
		"week": week,
		"source_entity": source_entity,
		"target_entities": target_entities.duplicate(),
		"implications": implications.duplicate(true),
		"metadata": metadata.duplicate(true)
	}
```

### Event Priority and Ordering

Events within a tick are processed in priority order. Within the same priority, events are ordered by:
1. **Priority level** (CRITICAL → DEFERRED)
2. **Tick number** (earlier ticks first)
3. **Event ID** (lexicographic order for determinism)

```gdscript
class_name EventScheduler

func get_events_for_tick(tick: int) -> Array[GameEvent]:
	var events: Array[GameEvent] = []

	# Collect scheduled events for this tick
	if _scheduled_events.has(tick):
		events.append_array(_scheduled_events[tick])

	# Collect recurring events that match this tick
	for recurring in _recurring_events:
		if recurring.matches_tick(tick):
			events.append(recurring.generate())

	# Sort by priority, then by event_id for determinism
	# Expected RNG consumption: 0 (deterministic sort)
	events.sort_custom(_compare_event_priority)

	return events

func _compare_event_priority(a: GameEvent, b: GameEvent) -> bool:
	# Sort by priority first
	if a.priority != b.priority:
		return a.priority < b.priority

	# Then by event_id for deterministic ordering
	return a.event_id < b.event_id
```

### Event Dependency Resolution

Some events depend on others completing first. Use priority levels to enforce order:

```gdscript
## Example: Contract expiration must complete before free agency opens

# Priority HIGH: Contract expires
var contract_expired := GameEvent.new()
contract_expired.event_type = GameEvent.EventType.CONTRACT_EXPIRED
contract_expired.priority = GameEvent.EventPriority.HIGH
contract_expired.implications = [{
	"type": "stage_transition",
	"player_id": player.id,
	"new_stage": Player.PlayerStage.NFL_FREE_AGENT
}]

# Priority NORMAL: Free agency market opens
var fa_market_opens := GameEvent.new()
fa_market_opens.event_type = GameEvent.EventType.FREE_AGENT_SIGNED
fa_market_opens.priority = GameEvent.EventPriority.NORMAL
# Will process after contract expiration

_event_scheduler.schedule(contract_expired, current_tick)
_event_scheduler.schedule(fa_market_opens, current_tick)
```

### Cascading Events (Events That Trigger Events)

Events can spawn follow-up events. These are added to the scheduler during processing:

```gdscript
func _process_event(event: GameEvent, rng: RandomNumberGenerator) -> EventResult:
	var result := EventResult.new()

	# Apply direct implications
	for implication in event.implications:
		_apply_implication(implication, result)

	# Handle cascading events based on event type
	match event.event_type:
		GameEvent.EventType.INJURY_OCCURRED:
			# Cascade: Check if injury requires IR placement
			var injury: Injury = _get_player_injury(event.target_entities[0])
			if injury.requires_ir():
				var ir_event := _create_ir_placement_event(
					event.target_entities[0],
					injury,
					event.tick + 1  # Schedule for next tick
				)
				_event_scheduler.schedule(ir_event)
				result.cascaded_events.append(ir_event)

		GameEvent.EventType.PLAYER_RETIRED:
			# Cascade: Clear roster spot, trigger cap space update
			var roster_update := _create_roster_update_event(
				event.source_entity,
				event.tick + 1
			)
			_event_scheduler.schedule(roster_update)
			result.cascaded_events.append(roster_update)

		GameEvent.EventType.TRADE_COMPLETED:
			# Cascade: Invalidate AI caches for both teams
			var trade_data: Dictionary = event.metadata
			var cache_invalidation := _create_cache_invalidation_event(
				[trade_data["team_a"], trade_data["team_b"]],
				event.tick
			)
			_event_scheduler.schedule(cache_invalidation)
			result.cascaded_events.append(cache_invalidation)

	return result

func _create_ir_placement_event(player_id: String, injury: Injury, tick: int) -> GameEvent:
	var event := GameEvent.new()
	event.event_id = "ir_placement_%s_%d" % [player_id, tick]
	event.event_type = GameEvent.EventType.INJURY_OCCURRED  # Reuse type with different implications
	event.priority = GameEvent.EventPriority.HIGH
	event.tick = tick
	event.target_entities = [player_id]
	event.implications = [{
		"type": "roster_status_change",
		"player_id": player_id,
		"new_status": "ir",
		"eligible_week": injury.get_ir_eligible_week(_current_week)
	}]
	return event
```

### Event Cancellation and Rollback

Events can be cancelled before processing. Rollback requires explicit undo operations:

```gdscript
class_name EventScheduler

## Cancel a scheduled event before it processes
## Returns true if event was found and cancelled
func cancel_event(event_id: String) -> bool:
	for tick in _scheduled_events.keys():
		var events: Array = _scheduled_events[tick]
		for i in range(events.size()):
			var event: GameEvent = events[i]
			if event.event_id == event_id:
				events.remove_at(i)
				_cancelled_events[event_id] = event  # Archive for debugging
				return true
	return false

## Cancel all events matching criteria
## Returns number of events cancelled
func cancel_events_matching(filter: Callable) -> int:
	var cancelled_count := 0
	for tick in _scheduled_events.keys():
		var events: Array = _scheduled_events[tick]
		for i in range(events.size() - 1, -1, -1):  # Reverse iteration for safe removal
			var event: GameEvent = events[i]
			if filter.call(event):
				events.remove_at(i)
				_cancelled_events[event.event_id] = event
				cancelled_count += 1
	return cancelled_count

## Example: Cancel all events for a player who was traded
func cancel_player_events(player_id: String) -> void:
	var cancelled := cancel_events_matching(func(e: GameEvent) -> bool:
		return player_id in e.target_entities
	)
	print("Cancelled %d events for player %s" % [cancelled, player_id])
```

**Rollback Pattern:**

Rollback is complex and should be avoided when possible. Instead, use compensating events:

```gdscript
## Instead of rolling back a trade, create a new trade event to reverse it
func undo_trade(original_trade_event: GameEvent) -> void:
	var reverse_trade := GameEvent.new()
	reverse_trade.event_type = GameEvent.EventType.TRADE_COMPLETED
	reverse_trade.priority = GameEvent.EventPriority.HIGH
	reverse_trade.tick = _current_tick + 1

	# Swap teams in trade metadata
	var original_data: Dictionary = original_trade_event.metadata
	reverse_trade.metadata = {
		"team_a": original_data["team_b"],  # Reversed
		"team_b": original_data["team_a"],  # Reversed
		"players_a": original_data["players_b"],
		"players_b": original_data["players_a"],
		"is_reversal": true  # Flag for debugging
	}

	# Create implications to reverse roster changes
	reverse_trade.implications = _create_trade_implications(reverse_trade.metadata)

	_event_scheduler.schedule(reverse_trade)
```

### Event Logging and Debugging

**Event Log Structure:**

```gdscript
class_name EventLog
extends RefCounted

## Persistent event log for debugging and replay analysis

var _log_entries: Array[Dictionary] = []
var _log_file_path: String = "user://event_log.json"

func log_event(event: GameEvent, result: EventResult) -> void:
	var entry := {
		"timestamp": Time.get_ticks_msec(),
		"tick": event.tick,
		"event": event.to_dict(),
		"result": {
			"success": result.success,
			"roster_changed": result.roster_changed,
			"cascaded_events": result.cascaded_events.size(),
			"errors": result.errors
		}
	}
	_log_entries.append(entry)

	# Optional: Write to disk periodically
	if _log_entries.size() % 100 == 0:
		_flush_to_disk()

func query_events(filter: Dictionary) -> Array[Dictionary]:
	# Query log entries by criteria
	var results: Array[Dictionary] = []
	for entry in _log_entries:
		if _matches_filter(entry, filter):
			results.append(entry)
	return results

func _matches_filter(entry: Dictionary, filter: Dictionary) -> bool:
	for key in filter.keys():
		if not entry["event"].has(key):
			return false
		if entry["event"][key] != filter[key]:
			return false
	return true

## Example usage:
# Find all injury events in year 2025
var injury_events := event_log.query_events({
	"event_type": GameEvent.EventType.INJURY_OCCURRED,
	"year": 2025
})
```

**Debug Visualization:**

```gdscript
func print_event_summary(event: GameEvent, result: EventResult) -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("EVENT: %s (Tick %d, Priority %d)" % [
		_event_type_name(event.event_type),
		event.tick,
		event.priority
	])
	print("  Source: %s" % event.source_entity)
	print("  Targets: %s" % ", ".join(event.target_entities))
	print("  Implications: %d" % event.implications.size())

	if not result.success:
		print("  ⚠ FAILED: %s" % ", ".join(result.errors))
	else:
		print("  ✓ Success")
		if result.roster_changed:
			print("    → Roster changed")
		if not result.cascaded_events.is_empty():
			print("    → Cascaded %d events" % result.cascaded_events.size())

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
```

**Event Replay for Debugging:**

```gdscript
## Replay events from a log to reproduce a bug
func replay_from_log(log_file: String, stop_at_tick: int = -1) -> void:
	var log_data := _load_log_file(log_file)

	var sim := SimulationLoop.new()
	sim.initialize_simulation(log_data["base_seed"])

	for entry in log_data["events"]:
		var event_dict: Dictionary = entry["event"]
		var event := GameEvent.new()
		event.from_dict(event_dict)

		if stop_at_tick > 0 and event.tick > stop_at_tick:
			print("Replay stopped at tick %d" % stop_at_tick)
			break

		# Process event with original RNG seed
		var tick_seed := Rand.splitmix64(log_data["base_seed"] + event.tick)
		var tick_rng := Rand.rng_for_seed(tick_seed)

		print("Replaying: %s at tick %d" % [event.event_id, event.tick])
		sim._process_event(event, tick_rng)
```

### Event Result Structure

```gdscript
class_name EventResult
extends RefCounted

## Result of processing a single event

var success: bool = true
var errors: Array[String] = []
var roster_changed: bool = false
var cap_changed: bool = false
var cascaded_events: Array[GameEvent] = []
var affected_players: Array[String] = []
var affected_teams: Array[String] = []

func add_error(error_msg: String) -> void:
	success = false
	errors.append(error_msg)

func mark_roster_change(team_id: String) -> void:
	roster_changed = true
	if not team_id in affected_teams:
		affected_teams.append(team_id)

func mark_player_change(player_id: String) -> void:
	if not player_id in affected_players:
		affected_players.append(player_id)
```

---

## Player Lifecycle Integration

### Overview

Player lifecycle encompasses all time-dependent changes to player state, from rookie entry to retirement. The simulation loop manages these transitions through events and scheduled updates.

### Player Aging and Birthdays

Players age once per season. This occurs during the offseason phase:

```gdscript
## Process annual aging for all players
## Scheduled as CRITICAL priority event at season end
func _process_annual_aging(rng: RandomNumberGenerator) -> void:
	var all_players := _get_all_players()  # From world_state

	for player in all_players:
		var p: Player = player

		# Age increment (deterministic)
		p.age += 1

		# Create aging event for logging
		var aging_event := GameEvent.new()
		aging_event.event_id = "aging_%s_%d" % [p.id, _current_year]
		aging_event.event_type = GameEvent.EventType.PLAYER_AGED
		aging_event.priority = GameEvent.EventPriority.CRITICAL
		aging_event.tick = _current_tick
		aging_event.year = _current_year
		aging_event.source_entity = p.id
		aging_event.target_entities = [p.id]

		# Apply age-related stat changes
		# Expected RNG consumption: 0 (deterministic formula)
		var stat_changes := _calculate_age_stat_changes(p)
		aging_event.implications = stat_changes

		_process_event(aging_event, rng)

		# Check for retirement eligibility
		# Expected RNG consumption: 1 randf() per player
		if _should_consider_retirement(p, rng):
			var retirement_event := _create_retirement_event(p)
			_event_scheduler.schedule(retirement_event, _current_tick + 1)
```

### Player Development and Skill Progression

Player stats evolve based on age, experience, and performance. Development is processed annually or after significant events:

```gdscript
## Calculate age-based stat modifiers
## RNG Consumption: 0 (pure calculation based on age curves)
func _calculate_age_stat_changes(player: Player) -> Array[Dictionary]:
	var implications: Array[Dictionary] = []

	# Age curves vary by position
	var peak_age := _get_position_peak_age(player.position)
	var decline_rate := _get_position_decline_rate(player.position)

	# Calculate performance multiplier based on age vs peak
	var age_factor := _calculate_age_performance_factor(
		player.age,
		peak_age,
		decline_rate
	)

	# Apply to relevant stats
	for stat_name in player.stats_profile.current.keys():
		var base_value := player.stats_profile.get_stat(stat_name)
		var age_modifier := _get_age_modifier_for_stat(stat_name, age_factor)

		if abs(age_modifier) > 0.01:  # Only apply meaningful changes
			implications.append({
				"type": "stat_modifier",
				"player_id": player.id,
				"stat": stat_name,
				"modifier": age_modifier,
				"reason": "age_%d" % player.age
			})

	return implications

## Position-specific peak ages (based on NFL research)
func _get_position_peak_age(position: String) -> int:
	var peak_ages := {
		"QB": 32,   # QBs peak later (experience)
		"RB": 24,   # RBs peak early (wear)
		"WR": 27,   # WRs peak mid-career
		"TE": 28,   # TEs peak mid-late
		"OL": 29,   # O-Line peaks with experience
		"DL": 27,   # D-Line peaks mid-career
		"LB": 27,   # LBs peak mid-career
		"DB": 26    # DBs peak early-mid (speed)
	}
	return peak_ages.get(position, 27)

## Age performance curve (logistic decline after peak)
func _calculate_age_performance_factor(age: int, peak_age: int, decline_rate: float) -> float:
	if age <= peak_age:
		# Growth phase: gradual improvement until peak
		var years_to_peak := float(peak_age - 22)  # Assume 22 = rookie entry
		var years_progressed := float(age - 22)
		return 0.85 + (0.15 * min(1.0, years_progressed / years_to_peak))
	else:
		# Decline phase: exponential decline after peak
		var years_past_peak := float(age - peak_age)
		return 1.0 - (decline_rate * years_past_peak * years_past_peak / 100.0)

## Experience-based development (separate from age)
## Triggered after each season based on performance
func _process_experience_development(player: Player, season_stats: Dictionary, rng: RandomNumberGenerator) -> void:
	# Calculate development points based on performance
	# Expected RNG consumption: 0 (deterministic calculation)
	var dev_points := _calculate_development_points(player, season_stats)

	# Potential determines how many points convert to actual improvement
	# Expected RNG consumption: 1 randf() per stat for variance
	for stat_name in player.stats_profile.potential.keys():
		var current := player.stats_profile.get_stat(stat_name)
		var potential := player.stats_profile.potential[stat_name]

		if current < potential:
			# Improvement chance based on development points
			var improvement_chance := min(0.9, dev_points / 100.0)
			var roll := rng.randf()

			if roll < improvement_chance:
				# Improve by small amount toward potential
				var improvement := (potential - current) * 0.1
				player.set_stat(stat_name, current + improvement)

				# Log development
				player.career.development_history.append({
					"year": _current_year,
					"stat": stat_name,
					"change": improvement,
					"reason": "experience"
				})

func _calculate_development_points(player: Player, season_stats: Dictionary) -> float:
	# More playing time = more development
	var snaps := float(season_stats.get("snaps", 0))
	var games := float(season_stats.get("games_played", 0))

	# Younger players develop faster
	var age_factor := max(0.5, 1.0 - (player.age - 22) * 0.05)

	# Performance quality matters
	var performance_rating := _evaluate_season_performance(player, season_stats)

	return snaps * 0.01 * age_factor * performance_rating
```

### Injury Recovery Timelines

Injuries progress each week based on recovery timelines defined in the Injury model:

```gdscript
## Process injury recovery for all injured players
## Scheduled weekly during regular season
func _process_weekly_injury_recovery() -> void:
	var injured_players := _get_injured_players()  # Players with active injuries

	for player in injured_players:
		var p: Player = player

		for injury in p.health.injuries:
			if not injury.is_active:
				continue  # Skip healed injuries

			# Increment recovery progress
			var timeline: Dictionary = injury.recovery_timeline
			var weeks_elapsed := int(timeline.get("weeks_elapsed", 0))
			var weeks_total := int(timeline.get("weeks_total", 0))

			weeks_elapsed += 1
			timeline["weeks_elapsed"] = weeks_elapsed

			# Check if fully recovered
			if weeks_elapsed >= weeks_total:
				_complete_injury_recovery(p, injury)
			# Check if eligible to return from IR
			elif injury.is_ir_eligible(_current_week):
				_create_ir_eligible_notification(p, injury)

func _complete_injury_recovery(player: Player, injury: Injury) -> void:
	# Mark injury as inactive
	injury.is_active = false

	# Create recovery completion event
	var recovery_event := GameEvent.new()
	recovery_event.event_id = "recovery_%s_%d" % [player.id, _current_tick]
	recovery_event.event_type = GameEvent.EventType.INJURY_OCCURRED  # Reuse type
	recovery_event.priority = GameEvent.EventPriority.NORMAL
	recovery_event.tick = _current_tick
	recovery_event.source_entity = player.id
	recovery_event.target_entities = [player.id]

	# Implication: Remove from IR if applicable
	var team := _get_player_team(player.id)
	if team != null:
		var roster_entry := team.roster._find_entry(player.id)
		if not roster_entry.is_empty() and String(roster_entry.get("status", "")) == "ir":
			recovery_event.implications.append({
				"type": "roster_status_change",
				"player_id": player.id,
				"team_id": team.id,
				"old_status": "ir",
				"new_status": "active"
			})

	_event_scheduler.schedule(recovery_event)

	print("Player %s recovered from %s injury" % [player.get_full_name(), injury.type])

## Long-term injury effects
## Some injuries leave permanent penalties
func _apply_long_term_injury_effects(player: Player, injury: Injury) -> void:
	if injury.long_term_penalty.is_empty():
		return

	# Apply permanent stat reductions
	for stat_name in injury.long_term_penalty.keys():
		var penalty := float(injury.long_term_penalty[stat_name])
		var current := player.stats_profile.get_stat(stat_name)
		player.set_stat(stat_name, max(0.0, current - penalty))

		# Log permanent penalty
		player.career.development_history.append({
			"year": _current_year,
			"stat": stat_name,
			"change": -penalty,
			"reason": "injury_penalty_%s" % injury.type
		})
```

### Contract Progression

Contracts advance each season. Expiration triggers free agency:

```gdscript
## Process contract progression for all players with active contracts
## Scheduled annually at season end
func _process_annual_contract_updates() -> void:
	var contracted_players := _get_players_with_contracts()

	for player in contracted_players:
		var p: Player = player

		if p.contract == null or not p.contract.is_active():
			continue

		# Advance contract year
		var old_year := p.contract.current_year
		p.contract.advance_year()

		print("Advanced contract for %s: Year %d/%d" % [
			p.get_full_name(),
			p.contract.current_year,
			p.contract.total_years
		])

		# Check if contract just expired
		if p.contract.is_expired():
			var expiration_event := GameEvent.new()
			expiration_event.event_id = "contract_expired_%s_%d" % [p.id, _current_year]
			expiration_event.event_type = GameEvent.EventType.CONTRACT_EXPIRED
			expiration_event.priority = GameEvent.EventPriority.HIGH
			expiration_event.tick = _current_tick
			expiration_event.source_entity = p.id
			expiration_event.target_entities = [p.id]

			# Implication: Transition to free agent
			expiration_event.implications = [{
				"type": "stage_transition",
				"player_id": p.id,
				"old_stage": p.stage,
				"new_stage": Player.PlayerStage.NFL_FREE_AGENT
			}, {
				"type": "roster_change",
				"player_id": p.id,
				"action": "release",
				"reason": "contract_expired"
			}]

			_event_scheduler.schedule(expiration_event, _current_tick + 1)

## Contract option years and extensions (future feature)
func _evaluate_contract_options(player: Player, team: Team, rng: RandomNumberGenerator) -> void:
	# Expected RNG consumption: 1 randf() for team decision
	# Future: Implement option evaluation logic based on performance

	pass  # Placeholder for future implementation
```

### Training Effects

Training occurs during offseason and training camp. Effects are applied before season start:

```gdscript
## Process offseason training for all active players
## Results depend on player dedication, facilities, and age
func _process_offseason_training(rng: RandomNumberGenerator) -> void:
	var active_players := _get_active_players()

	for player in active_players:
		var p: Player = player
		var team := _get_player_team(p.id)

		# Calculate training effectiveness
		# Expected RNG consumption: 0 (deterministic factors)
		var effectiveness := _calculate_training_effectiveness(p, team)

		# Apply training results with variance
		# Expected RNG consumption: 1 randf() per trainable stat
		for stat_name in _get_trainable_stats(p.position):
			var current := p.stats_profile.get_stat(stat_name)
			var potential := p.stats_profile.potential.get(stat_name, current)

			if current < potential:
				# Training improvement with RNG variance
				var base_improvement := (potential - current) * effectiveness * 0.05
				var variance := rng.randf() * 0.02 - 0.01  # ±1%
				var actual_improvement := max(0.0, base_improvement + variance)

				p.set_stat(stat_name, current + actual_improvement)

				# Log training result
				player.career.development_history.append({
					"year": _current_year,
					"stat": stat_name,
					"change": actual_improvement,
					"reason": "offseason_training"
				})

func _calculate_training_effectiveness(player: Player, team: Team) -> float:
	var base_effectiveness := 1.0

	# Younger players train more effectively
	if player.age < 26:
		base_effectiveness *= 1.2
	elif player.age > 32:
		base_effectiveness *= 0.8

	# Team facilities matter (future: read from team config)
	var facility_rating := 1.0  # Placeholder
	base_effectiveness *= facility_rating

	# Player traits affect training (future: check for "Hard Worker" trait)
	if "Hard Worker" in player.trait_set.visible:
		base_effectiveness *= 1.15

	return clamp(base_effectiveness, 0.5, 1.5)

func _get_trainable_stats(position: String) -> Array[String]:
	# Position-specific trainable stats
	var trainable := {
		"QB": ["accuracy", "arm_strength", "decision_making"],
		"RB": ["speed", "power", "agility", "vision"],
		"WR": ["speed", "route_running", "hands", "release"],
		"OL": ["strength", "technique", "footwork"],
		"DL": ["strength", "pass_rush", "run_defense"],
		"LB": ["speed", "tackling", "coverage"],
		"DB": ["speed", "coverage", "ball_skills"]
	}
	return trainable.get(position, [])
```

### Retirement Decisions

Retirement is probabilistic based on age, injuries, and performance:

```gdscript
## Determine if player should consider retirement
## Called annually after contract evaluation
## RNG Consumption: 1 randf() per eligible player
func _should_consider_retirement(player: Player, rng: RandomNumberGenerator) -> bool:
	# Age thresholds
	if player.age < 30:
		return false  # Too young to retire

	# Calculate retirement probability
	var retirement_prob := _calculate_retirement_probability(player)

	# RNG roll
	var roll := rng.randf()
	return roll < retirement_prob

func _calculate_retirement_probability(player: Player) -> float:
	var base_prob := 0.0

	# Age factor (exponential after 33)
	if player.age >= 33:
		base_prob = 0.05 * pow(1.3, player.age - 33)

	# Injury history increases retirement chance
	var injury_count := player.career.wear.get("injury_count", 0)
	if injury_count > 3:
		base_prob += 0.05 * (injury_count - 3)

	# Recent performance affects decision
	var last_season_rating := _get_last_season_performance(player)
	if last_season_rating < 60.0:  # Poor performance
		base_prob += 0.1

	# Contract status matters
	if player.contract == null or player.contract.is_expired():
		base_prob += 0.15  # More likely to retire if unsigned

	# Cap at 90% (always some chance to continue)
	return min(0.90, base_prob)

func _create_retirement_event(player: Player) -> GameEvent:
	var event := GameEvent.new()
	event.event_id = "retirement_%s_%d" % [player.id, _current_year]
	event.event_type = GameEvent.EventType.PLAYER_RETIRED
	event.priority = GameEvent.EventPriority.HIGH
	event.tick = _current_tick
	event.source_entity = player.id
	event.target_entities = [player.id]

	# Implications: Stage transition, roster removal
	event.implications = [{
		"type": "stage_transition",
		"player_id": player.id,
		"old_stage": player.stage,
		"new_stage": Player.PlayerStage.RETIRED
	}, {
		"type": "roster_change",
		"player_id": player.id,
		"action": "retire",
		"reason": "retirement"
	}]

	event.metadata = {
		"age": player.age,
		"final_team": _get_player_team_id(player.id),
		"career_snaps": player.career.wear.get("snaps", 0),
		"career_awards": player.career.awards.size()
	}

	return event

## Handle retirement announcement and ceremony
func _process_retirement(player: Player, event: GameEvent) -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("RETIREMENT: %s" % player.get_full_name())
	print("  Age: %d" % player.age)
	print("  Position: %s" % player.position)
	print("  Career Snaps: %s" % player.career.wear.get("snaps", 0))
	print("  Awards: %d" % player.career.awards.size())
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# Future: Generate retirement ceremony event for player notification
```

---

## Team Lifecycle Integration

### Overview

Team lifecycle encompasses roster management, salary cap dynamics, draft pick allocation, and schedule generation. These processes are tightly integrated with the simulation loop's tick system.

### Roster Management Constraints

The simulation enforces NFL roster rules at all times:

```gdscript
## Roster size limits (NFL rules)
const ROSTER_LIMIT_ACTIVE := 53         # Active roster max
const ROSTER_LIMIT_PRACTICE_SQUAD := 16 # Practice squad max
const ROSTER_LIMIT_TOTAL := 69          # Total max (53 + 16)
const ROSTER_LIMIT_GAME_DAY := 48       # Game day active (not implemented in Phase 1)

## Validate roster composition during tick processing
## Called before any roster-modifying event is applied
func _validate_roster_constraints(team: Team) -> Dictionary:
	var result := {
		"valid": true,
		"violations": []
	}

	# Count players by status
	var active_count := team.roster.get_status_count(Roster.RosterStatus.ACTIVE)
	var ps_count := team.roster.get_status_count(Roster.RosterStatus.PRACTICE_SQUAD)
	var total_count := active_count + ps_count

	# Check active roster limit
	if active_count > ROSTER_LIMIT_ACTIVE:
		result.valid = false
		result.violations.append({
			"type": "active_roster_overflow",
			"current": active_count,
			"limit": ROSTER_LIMIT_ACTIVE,
			"overage": active_count - ROSTER_LIMIT_ACTIVE
		})

	# Check practice squad limit
	if ps_count > ROSTER_LIMIT_PRACTICE_SQUAD:
		result.valid = false
		result.violations.append({
			"type": "practice_squad_overflow",
			"current": ps_count,
			"limit": ROSTER_LIMIT_PRACTICE_SQUAD,
			"overage": ps_count - ROSTER_LIMIT_PRACTICE_SQUAD
		})

	# Check total roster limit
	if total_count > ROSTER_LIMIT_TOTAL:
		result.valid = false
		result.violations.append({
			"type": "total_roster_overflow",
			"current": total_count,
			"limit": ROSTER_LIMIT_TOTAL,
			"overage": total_count - ROSTER_LIMIT_TOTAL
		})

	return result

## Apply roster change with validation
## Returns EventResult with success/failure status
func _apply_roster_change_safe(team: Team, change: Dictionary) -> EventResult:
	var result := EventResult.new()

	# Validate before applying
	var pre_validation := _validate_roster_constraints(team)
	if not pre_validation.valid:
		result.add_error("Pre-change validation failed: %s" % str(pre_validation.violations))
		return result

	# Apply change
	match String(change.get("action", "")):
		"add_player":
			_roster_add_player(team, change, result)
		"remove_player":
			_roster_remove_player(team, change, result)
		"move_to_ir":
			_roster_move_to_ir(team, change, result)
		"activate_from_ir":
			_roster_activate_from_ir(team, change, result)
		_:
			result.add_error("Unknown roster action: %s" % change.get("action"))
			return result

	# Validate after applying
	var post_validation := _validate_roster_constraints(team)
	if not post_validation.valid:
		result.add_error("Post-change validation failed: %s" % str(post_validation.violations))
		# Rollback change (implementation depends on change type)
		_rollback_roster_change(team, change)
		return result

	result.mark_roster_change(team.id)
	return result
```

### Salary Cap Changes

The salary cap is checked and enforced during roster moves and contract signings:

```gdscript
## Process annual salary cap updates
## Scheduled at league year start (typically March)
func _process_annual_cap_update() -> void:
	var new_cap := _calculate_league_cap(_current_year)

	for team_id in _get_all_team_ids():
		var team := _get_team(team_id)

		# Update league cap
		var old_cap := team.league_cap
		team.league_cap = new_cap

		# Recalculate cap used (in case rules changed)
		var cap_used := team.roster.get_cap_used()

		# Determine if over cap
		team.is_over_cap = cap_used > new_cap

		print("Cap update for %s: $%.2fM used / $%.2fM cap (%s)" % [
			team.name,
			cap_used / 1_000_000.0,
			new_cap / 1_000_000.0,
			"OVER" if team.is_over_cap else "under"
		])

		# If over cap, trigger cap compliance event
		if team.is_over_cap:
			var compliance_event := _create_cap_compliance_event(team)
			_event_scheduler.schedule(compliance_event, _current_tick + 1)

## Calculate league-wide salary cap for a given year
## Based on revenue projections (simplified in Phase 1)
func _calculate_league_cap(year: int) -> float:
	# Base cap (2025 NFL cap)
	var base_cap := 255_400_000.0

	# Annual growth rate (3-5% typical)
	var growth_rate := 0.04

	# Calculate cap with growth
	var years_from_base := year - 2025
	return base_cap * pow(1.0 + growth_rate, years_from_base)

## Validate team cap compliance before contract signing
func _validate_cap_space(team: Team, proposed_contract: Contract) -> bool:
	var current_cap_used := team.roster.get_cap_used()
	var new_cap_hit := proposed_contract.annual_value

	# Check if signing would put team over cap
	if current_cap_used + new_cap_hit > team.league_cap:
		print("Cap violation: %s cannot afford $%.2fM contract (%.2fM available)" % [
			team.name,
			new_cap_hit / 1_000_000.0,
			team.cap_space / 1_000_000.0
		])
		return false

	return true

## Cap compliance enforcement (AI teams must comply)
func _enforce_cap_compliance(team: Team, rng: RandomNumberGenerator) -> void:
	var overage := team.cap_used - team.league_cap

	print("Enforcing cap compliance for %s: $%.2fM over cap" % [
		team.name,
		overage / 1_000_000.0
	])

	# AI must cut/restructure until compliant
	while team.cap_used > team.league_cap:
		# Find highest-paid player who can be cut
		# Expected RNG consumption: 0 (deterministic selection)
		var cut_candidate := _find_cut_candidate(team)

		if cut_candidate == null:
			push_error("Cannot achieve cap compliance for %s" % team.name)
			break

		# Cut player
		var cut_event := _create_player_cut_event(team, cut_candidate)
		_process_event(cut_event, rng)

## Find best candidate to cut for cap savings
func _find_cut_candidate(team: Team) -> String:
	var best_candidate := ""
	var best_savings := 0.0

	for entry in team.roster.entries:
		var e: Dictionary = entry
		var player_id := String(e.get("player_id", ""))
		var player := _get_player(player_id)

		if player == null or not player.is_nfl_player():
			continue

		# Calculate cap savings if cut
		var contract_dict: Dictionary = e.get("contract", {})
		var cap_hit := Roster.contract_cap_charge(contract_dict)
		var dead_money := float(contract_dict.get("dead_money", 0.0))
		var savings := cap_hit - dead_money

		# Prefer cutting older, more expensive players
		var value_score := savings / max(1.0, player.age - 25)

		if savings > best_savings:
			best_savings = savings
			best_candidate = player_id

	return best_candidate
```

### Draft Pick Progression

Draft picks are tracked and advanced through the league year:

```gdscript
## Draft pick structure
## Stored in world_state["draft_picks"]
## Format: { year: int, round: int, pick: int, original_team: String, current_owner: String }

## Process annual draft
## Scheduled after season ends, before free agency
func _process_annual_draft(rng: RandomNumberGenerator) -> void:
	var draft_year := _current_year + 1  # Draft is for next season
	var draft_picks := _get_draft_picks_for_year(draft_year)

	# Sort picks by round and pick number
	draft_picks.sort_custom(func(a, b): return _compare_draft_picks(a, b))

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("NFL DRAFT: %d" % draft_year)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	for pick in draft_picks:
		var pick_dict: Dictionary = pick

		# Derive sub-seed for this pick
		# Expected RNG consumption: 1 randi() per pick
		var pick_seed := rng.randi()
		var pick_rng := Rand.rng_for_seed(pick_seed)

		# Process pick (AI or player-controlled)
		var result := _process_single_draft_pick(pick_dict, pick_rng)

		# Create draft pick event
		var pick_event := _create_draft_pick_event(pick_dict, result)
		_event_scheduler.schedule(pick_event, _current_tick)

		print("Round %d, Pick %d: %s selects %s (%s)" % [
			pick_dict["round"],
			pick_dict["pick"],
			pick_dict["current_owner"],
			result["player_name"],
			result["position"]
		])

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func _compare_draft_picks(a: Dictionary, b: Dictionary) -> bool:
	if int(a["round"]) != int(b["round"]):
		return int(a["round"]) < int(b["round"])
	return int(a["pick"]) < int(b["pick"])

## Generate draft picks for a season
## Called when season ends to allocate next year's picks
func _generate_draft_picks_for_next_season() -> void:
	var next_year := _current_year + 1
	var team_ids := _get_all_team_ids()

	# Sort teams by season record (worst to best)
	# Expected RNG consumption: 0 (deterministic sort)
	var standings := _get_season_standings(_current_year)
	standings.sort_custom(func(a, b): return _compare_draft_order(a, b))

	# Allocate 7 rounds of picks
	var NUM_ROUNDS := 7
	var pick_number := 1

	for round in range(1, NUM_ROUNDS + 1):
		for team_record in standings:
			var team_id := String(team_record["team_id"])

			var pick := {
				"year": next_year,
				"round": round,
				"pick": pick_number,
				"original_team": team_id,
				"current_owner": team_id,  # May change via trades
				"is_compensatory": false
			}

			_world_state["draft_picks"].append(pick)
			pick_number += 1

## Compare teams for draft order (worst record picks first)
func _compare_draft_order(a: Dictionary, b: Dictionary) -> bool:
	var a_wins := int(a["wins"])
	var b_wins := int(b["wins"])

	if a_wins != b_wins:
		return a_wins < b_wins  # Fewer wins = higher pick

	# Tiebreaker: Strength of schedule (weaker SOS picks first)
	var a_sos := float(a.get("strength_of_schedule", 50.0))
	var b_sos := float(b.get("strength_of_schedule", 50.0))
	return a_sos < b_sos

## Process a single draft pick
## RNG Consumption: Variable (depends on AI evaluation logic)
func _process_single_draft_pick(pick: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var team_id := String(pick["current_owner"])
	var is_player_team := _is_player_controlled_team(team_id)

	if is_player_team:
		# Player-controlled: Queue action and wait
		_queue_player_draft_decision(pick)
		return {"status": "pending_player_input"}
	else:
		# AI-controlled: Auto-select
		return _ai_draft_selection(team_id, pick, rng)

## AI draft selection logic
## RNG Consumption: 1 randf() for best available with variance
func _ai_draft_selection(team_id: String, pick: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var team := _get_team(team_id)
	var draft_eligible := _get_draft_eligible_players()

	# Evaluate players by team need and talent
	# Expected RNG consumption: 0 (deterministic scoring)
	var player_scores := []
	for player in draft_eligible:
		var p: Player = player
		var score := _evaluate_draft_prospect(team, p)
		player_scores.append({
			"player": p,
			"score": score
		})

	# Sort by score (highest first)
	player_scores.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))

	# Select top player with variance
	# Expected RNG consumption: 1 randf()
	var selection_variance := rng.randf() * 0.1  # 10% variance
	var selection_idx := int(selection_variance * min(5, player_scores.size()))
	var selected := player_scores[selection_idx]

	return {
		"player_id": selected["player"].id,
		"player_name": selected["player"].get_full_name(),
		"position": selected["player"].position,
		"score": selected["score"]
	}
```

### Schedule Generation

Game schedules are generated at the start of each season:

```gdscript
## Generate NFL schedule for the season
## Scheduled during offseason (typically late July)
func _generate_season_schedule(rng: RandomNumberGenerator) -> void:
	var year := _current_year
	var teams := _get_all_teams()

	# Derive schedule seed from base seed + year
	# Expected RNG consumption: 1 randi()
	var schedule_seed := rng.randi()
	var schedule_rng := Rand.rng_for_seed(schedule_seed)

	# Generate 17-week schedule using GameSimulator
	# Expected RNG consumption: Variable (see GameSimulator.generate_nfl_schedule)
	var schedule := GameSimulator.generate_nfl_schedule(
		teams,
		[],  # Divisions (Phase 1: unused)
		year,
		schedule_seed
	)

	print("Generated %d games for %d season" % [schedule.size(), year])

	# Schedule game events for each week
	for game in schedule:
		var g: Dictionary = game
		var week := int(g["week"])

		# Calculate tick for this game
		# Assume regular season starts week 1 of September
		var game_tick := _calculate_tick_for_week(year, week)

		# Create game event
		var game_event := _create_game_event(g, game_tick)
		_event_scheduler.schedule(game_event, game_tick)

	# Store schedule in world state for reference
	_world_state["schedules"][year] = schedule

func _calculate_tick_for_week(year: int, week: int) -> int:
	# Convert year and week to tick number
	# Assumes:
	# - Season starts at a known base tick
	# - Each week is a fixed number of ticks (e.g., 7 days = 7 ticks)

	var base_tick := _get_season_start_tick(year)
	var ticks_per_week := 7  # Daily tick frequency during season

	return base_tick + (week - 1) * ticks_per_week

func _create_game_event(matchup: Dictionary, tick: int) -> GameEvent:
	var event := GameEvent.new()
	event.event_id = String(matchup["game_id"])
	event.event_type = GameEvent.EventType.GAME_RESULT
	event.priority = GameEvent.EventPriority.NORMAL
	event.tick = tick
	event.year = int(matchup["year"])
	event.week = int(matchup["week"])
	event.source_entity = String(matchup["home_team_id"])
	event.target_entities = [
		String(matchup["home_team_id"]),
		String(matchup["away_team_id"])
	]
	event.metadata = matchup.duplicate()

	return event
```

### Roster Deadline Enforcement

Key roster deadlines are enforced by the simulation:

```gdscript
## Roster deadlines (NFL calendar)
const DEADLINE_TRAINING_CAMP := {"month": 7, "day": 25}   # Must be under 90
const DEADLINE_CUT_TO_53 := {"month": 8, "day": 29}       # Must cut to 53
const DEADLINE_TRADE := {"month": 11, "day": 1}           # Trade deadline (Week 9)

## Check and enforce roster deadlines each tick
func _check_roster_deadlines() -> void:
	var current_date := _get_current_date()

	# Cut to 53 deadline
	if _is_date(current_date, DEADLINE_CUT_TO_53):
		_enforce_53_man_roster_deadline()

	# Trade deadline
	if _is_date(current_date, DEADLINE_TRADE):
		_close_trade_window()

func _enforce_53_man_roster_deadline() -> void:
	print("ROSTER DEADLINE: All teams must cut to 53-man roster")

	for team_id in _get_all_team_ids():
		var team := _get_team(team_id)
		var active_count := team.roster.get_status_count(Roster.RosterStatus.ACTIVE)

		while active_count > ROSTER_LIMIT_ACTIVE:
			# Force cut worst player
			var cut_player := _find_lowest_rated_player(team)
			var cut_event := _create_player_cut_event(team, cut_player)
			_event_scheduler.schedule(cut_event, _current_tick)

			active_count -= 1

func _is_date(current: Dictionary, target: Dictionary) -> bool:
	return int(current["month"]) == int(target["month"]) \
		and int(current["day"]) == int(target["day"])
```

---

## Game Simulation Integration

### Overview

Game simulation is the core gameplay loop. Each game generates results, accumulates player stats, triggers injuries, and spawns post-game events. The simulation uses explicit RNG to ensure determinism.

### Game Result Generation

Games are simulated using `GameSimulator.determine_winner()` with pre-calculated team strengths:

```gdscript
## Simulate a single game during a tick
## RNG Consumption: See GameSimulator.determine_winner() documentation (1 randf())
func _simulate_game(game_event: GameEvent, rng: RandomNumberGenerator) -> Dictionary:
	var matchup: Dictionary = game_event.metadata
	var home_id := String(matchup["home_team_id"])
	var away_id := String(matchup["away_team_id"])

	# Get pre-calculated team strengths (cached at season start)
	var team_strengths := _world_state.get("team_strengths", {})
	if not team_strengths.has(home_id) or not team_strengths.has(away_id):
		push_error("Missing team strengths for game %s" % game_event.event_id)
		return {}

	# Simulate game outcome
	# Expected RNG consumption: 1 randf() (see GameSimulator.determine_winner)
	var result := GameSimulator.determine_winner(
		matchup,
		team_strengths,
		rng,
		_sim_config
	)

	print("Game Result: %s (%d) at %s (%d) - Winner: %s %s" % [
		away_id,
		result["away_score"],
		home_id,
		result["home_score"],
		result["winner_id"],
		"[UPSET]" if result["upset"] else ""
	])

	return result

## Pre-calculate all team strengths at season start (performance optimization)
## Called once per season, cached for all games
func _calculate_season_team_strengths() -> void:
	var teams := _get_all_teams()
	var team_ids: Array = []
	var rosters := {}

	for team in teams:
		var t: Team = team
		team_ids.append(t.id)
		rosters[t.id] = _build_roster_dict_for_team(t)

	# Calculate all strengths in batch
	# Expected RNG consumption: 0 (pure calculation)
	var team_strengths := GameSimulator.calculate_all_team_strengths(
		team_ids,
		rosters,
		_positions_cfg,
		_main_cfg
	)

	# Cache for season
	_world_state["team_strengths"] = team_strengths

	print("Calculated strengths for %d teams" % team_strengths.size())
	for team_id in team_strengths.keys():
		print("  %s: %.1f" % [team_id, team_strengths[team_id]])

func _build_roster_dict_for_team(team: Team) -> Dictionary:
	# Convert Team.roster to format expected by GameSimulator
	var players := []
	var active_ids := team.get_active_player_ids()

	for player_id in active_ids:
		var player := _get_player(player_id)
		if player != null:
			players.append(player.to_dict())

	return {
		"players": players
	}
```

### Stat Accumulation

Player stats are accumulated after each game:

```gdscript
## Process game completion and update player stats
## Called after game simulation finishes
func _process_game_completion(game_event: GameEvent, game_result: Dictionary, rng: RandomNumberGenerator) -> void:
	var home_id := String(game_result["home_team_id"])
	var away_id := String(game_result["away_team_id"])

	var home_team := _get_team(home_id)
	var away_team := _get_team(away_id)

	# Build roster dictionaries
	var home_roster := _build_roster_dict_for_team(home_team)
	var away_roster := _build_roster_dict_for_team(away_team)

	# Accumulate player stats
	# Expected RNG consumption: Variable (see StatGenerator documentation)
	GameSimulator.accumulate_player_stats(
		_world_state,
		game_result,
		home_roster,
		away_roster,
		_positions_cfg,
		_main_cfg,
		rng
	)

	# Update season records
	_update_season_records(game_result)

	# Check for injuries that occurred during game
	_process_game_injuries(game_result, rng)

	# Generate post-game events (awards, milestones, etc.)
	_generate_post_game_events(game_result, rng)

## Update team season records after game
func _update_season_records(game_result: Dictionary) -> void:
	var winner_id := String(game_result["winner_id"])
	var loser_id := String(game_result["loser_id"])
	var year := int(game_result["year"])

	# Ensure season records exist
	if not _world_state.has("season_records"):
		_world_state["season_records"] = {}
	if not _world_state["season_records"].has(year):
		_world_state["season_records"][year] = {}

	var records: Dictionary = _world_state["season_records"][year]

	# Initialize records if needed
	if not records.has(winner_id):
		records[winner_id] = _create_empty_season_record(winner_id, year)
	if not records.has(loser_id):
		records[loser_id] = _create_empty_season_record(loser_id, year)

	# Update win/loss
	var winner_record: Dictionary = records[winner_id]
	var loser_record: Dictionary = records[loser_id]

	winner_record["wins"] = int(winner_record.get("wins", 0)) + 1
	loser_record["losses"] = int(loser_record.get("losses", 0)) + 1

	# Update point differential (Phase 2: when scores implemented)
	# winner_record["point_differential"] += (result["home_score"] - result["away_score"])

func _create_empty_season_record(team_id: String, year: int) -> Dictionary:
	return {
		"team_id": team_id,
		"year": year,
		"wins": 0,
		"losses": 0,
		"point_differential": 0,
		"strength_of_schedule": 0.0,
		"playoff_appearance": false,
		"championship_winner": false
	}
```

### Injury Occurrence During Games

Injuries can occur probabilistically during game simulation:

```gdscript
## Process potential injuries from a game
## RNG Consumption: 2 randf() per active player (injury chance + severity)
func _process_game_injuries(game_result: Dictionary, rng: RandomNumberGenerator) -> void:
	var home_id := String(game_result["home_team_id"])
	var away_id := String(game_result["away_team_id"])

	# Process injuries for both teams
	_check_team_injuries(home_id, game_result, rng)
	_check_team_injuries(away_id, game_result, rng)

func _check_team_injuries(team_id: String, game_result: Dictionary, rng: RandomNumberGenerator) -> void:
	var team := _get_team(team_id)
	var active_players := team.get_active_player_ids()

	for player_id in active_players:
		var player := _get_player(player_id)
		if player == null:
			continue

		# Calculate injury risk
		# Expected RNG consumption: 0 (pure calculation)
		var injury_risk := _calculate_game_injury_risk(player, game_result)

		# Roll for injury occurrence
		# Expected RNG consumption: 1 randf()
		var injury_roll := rng.randf()

		if injury_roll < injury_risk:
			# Player injured!
			# Expected RNG consumption: 3 (see generate_injury documentation)
			var injury := _generate_injury(player, rng)

			# Add to player's injury list
			player.health.injuries.append(injury)

			# Create injury event
			var injury_event := _create_injury_event(player, injury, game_result)
			_event_scheduler.schedule(injury_event, _current_tick + 1)

			print("INJURY: %s (%s) - %s (Severity: %.2f, Recovery: %d weeks)" % [
				player.get_full_name(),
				player.position,
				injury.type,
				injury.severity,
				injury.recovery_timeline.get("weeks_total", 0)
			])

## Calculate injury risk for a player in a game
## Factors: Position, age, wear, game conditions
## RNG Consumption: 0 (deterministic calculation)
func _calculate_game_injury_risk(player: Player, game_result: Dictionary) -> float:
	# Base injury rate per game
	var base_rate := 0.02  # 2% per game

	# Position risk multipliers (based on NFL data)
	var position_multipliers := {
		"QB": 0.8,   # Lower risk
		"RB": 1.5,   # High contact
		"WR": 1.0,   # Moderate
		"TE": 1.2,   # Moderate-high
		"OL": 1.1,   # Moderate
		"DL": 1.3,   # High contact
		"LB": 1.4,   # High contact
		"DB": 1.0    # Moderate
	}

	var position_mult := position_multipliers.get(player.position, 1.0)

	# Age factor (older players more injury-prone)
	var age_mult := 1.0
	if player.age > 30:
		age_mult = 1.0 + (player.age - 30) * 0.05  # +5% per year over 30

	# Wear factor (career snaps increase risk)
	var snaps := float(player.career.wear.get("snaps", 0))
	var wear_mult := 1.0 + (snaps / 50000.0)  # +2% per 1000 career snaps

	# Previous injury history
	var injury_count := player.career.wear.get("injury_count", 0)
	var history_mult := 1.0 + (injury_count * 0.03)  # +3% per previous injury

	# Upset games have higher injury rates (more intense play)
	var intensity_mult := 1.2 if bool(game_result.get("upset", false)) else 1.0

	return base_rate * position_mult * age_mult * wear_mult * history_mult * intensity_mult

## Generate random injury with type, severity, and recovery timeline
## RNG Consumption: 3 calls (type selection, severity, recovery weeks)
func _generate_injury(player: Player, rng: RandomNumberGenerator) -> Injury:
	# Injury type distribution (weighted)
	var injury_types := [
		{"type": "Hamstring", "weight": 0.25},
		{"type": "Concussion", "weight": 0.20},
		{"type": "Ankle Sprain", "weight": 0.15},
		{"type": "Knee (MCL)", "weight": 0.12},
		{"type": "Shoulder", "weight": 0.10},
		{"type": "Knee (ACL)", "weight": 0.08},
		{"type": "Fracture", "weight": 0.06},
		{"type": "Back", "weight": 0.04}
	]

	# RNG call 1: Select injury type from weighted distribution
	var type_roll := rng.randf()
	var cumulative := 0.0
	var selected_type := "Hamstring"  # Default

	for injury_def in injury_types:
		cumulative += float(injury_def["weight"])
		if type_roll < cumulative:
			selected_type = String(injury_def["type"])
			break

	# RNG call 2: Determine severity (0.0-1.0)
	var severity := rng.randf()

	# RNG call 3: Recovery timeline based on severity
	var min_weeks := 1 if severity < 0.5 else 4
	var max_weeks := 4 if severity < 0.5 else 16
	var recovery_weeks := rng.randi_range(min_weeks, max_weeks)

	# Create injury
	var injury := Injury.new()
	injury.type = selected_type
	injury.severity = severity
	injury.recovery_timeline = {
		"weeks_total": recovery_weeks,
		"weeks_elapsed": 0
	}
	injury.week_occurred = int(_world_state.get("current_week", 0))
	injury.season_year = int(_world_state.get("current_year", 0))
	injury.is_active = true

	# Determine affected stats based on injury type
	injury.affected_stats = _get_affected_stats_for_injury(selected_type)

	# Long-term penalty for severe injuries
	if severity >= 0.8:
		injury.long_term_penalty = _calculate_long_term_penalty(selected_type, severity)

	# Update career wear
	player.career.wear["injury_count"] = int(player.career.wear.get("injury_count", 0)) + 1

	return injury

func _get_affected_stats_for_injury(injury_type: String) -> Array[String]:
	var affected_map := {
		"Hamstring": ["speed", "acceleration"],
		"Concussion": ["awareness", "reaction_time"],
		"Ankle Sprain": ["agility", "acceleration"],
		"Knee (MCL)": ["speed", "agility", "power"],
		"Shoulder": ["arm_strength", "throwing_power"],
		"Knee (ACL)": ["speed", "agility", "cutting"],
		"Fracture": [],  # Depends on location
		"Back": ["flexibility", "power"]
	}
	var affected: Array = affected_map.get(injury_type, [])
	var result: Array[String] = []
	for stat in affected:
		result.append(String(stat))
	return result

func _calculate_long_term_penalty(injury_type: String, severity: float) -> Dictionary:
	# Severe injuries leave permanent stat reductions
	var penalty_map := {
		"Knee (ACL)": {"speed": 2.0, "agility": 3.0},
		"Knee (MCL)": {"speed": 1.0, "agility": 2.0},
		"Concussion": {"awareness": 1.5},
		"Back": {"power": 2.0, "flexibility": 2.5}
	}

	var base_penalty: Dictionary = penalty_map.get(injury_type, {})
	var scaled_penalty := {}

	# Scale by severity (0.8+ severity only)
	var scale_factor := (severity - 0.8) * 5.0  # 0.8=0%, 1.0=100%
	for stat in base_penalty.keys():
		scaled_penalty[stat] = float(base_penalty[stat]) * scale_factor

	return scaled_penalty
```

### Post-Game Events

Games can trigger follow-up events like awards, milestones, and roster changes:

```gdscript
## Generate events triggered by game results
## Examples: Player of the week, milestone achievements, injury updates
func _generate_post_game_events(game_result: Dictionary, rng: RandomNumberGenerator) -> void:
	var year := int(game_result["year"])
	var week := int(game_result["week"])

	# Check for player milestones
	_check_player_milestones(game_result)

	# Check for award eligibility (weekly awards)
	if week % 4 == 0:  # Monthly awards
		_check_monthly_awards(year, week, rng)

	# Check for rivalry game outcomes (future feature)
	# _check_rivalry_outcomes(game_result)

## Check if any players reached career milestones
func _check_player_milestones(game_result: Dictionary) -> void:
	var year := int(game_result["year"])

	# Get player stats for this year
	if not _world_state.has("player_career_stats"):
		return

	var career_stats: Dictionary = _world_state["player_career_stats"]

	for player_id in career_stats.keys():
		var player_years: Dictionary = career_stats[player_id]
		if not player_years.has(year):
			continue

		var season_stats: Dictionary = player_years[year]

		# Check various milestones
		_check_milestone(player_id, "passing_yards", season_stats, 5000, "5000 Passing Yards")
		_check_milestone(player_id, "rushing_yards", season_stats, 2000, "2000 Rushing Yards")
		_check_milestone(player_id, "receiving_yards", season_stats, 2000, "2000 Receiving Yards")
		_check_milestone(player_id, "touchdowns", season_stats, 20, "20 Touchdowns")

func _check_milestone(player_id: String, stat: String, season_stats: Dictionary, threshold: int, milestone_name: String) -> void:
	var value := int(season_stats.get(stat, 0))

	if value >= threshold:
		var player := _get_player(player_id)
		if player == null:
			return

		# Check if already awarded this year
		var milestone_key := "milestone_%s_%d" % [stat, _current_year]
		if milestone_key in player.career.awards.keys():
			return  # Already awarded

		# Award milestone
		player.career.awards[milestone_key] = 1

		# Create award event
		var award_event := GameEvent.new()
		award_event.event_id = "milestone_%s_%s_%d" % [player_id, stat, _current_year]
		award_event.event_type = GameEvent.EventType.AWARD_RECEIVED
		award_event.priority = GameEvent.EventPriority.LOW
		award_event.tick = _current_tick + 1
		award_event.source_entity = player_id
		award_event.target_entities = [player_id]
		award_event.metadata = {
			"award_type": "milestone",
			"milestone_name": milestone_name,
			"stat": stat,
			"value": value
		}

		_event_scheduler.schedule(award_event)

		print("MILESTONE: %s achieved %s (%d %s)" % [
			player.get_full_name(),
			milestone_name,
			value,
			stat
		])

## Weekly/monthly awards (Player of the Week, etc.)
func _check_monthly_awards(year: int, week: int, rng: RandomNumberGenerator) -> void:
	# Get top performers for this month
	# Expected RNG consumption: 0 (deterministic selection of best)

	var top_qb := _find_top_performer("QB", year, week - 3, week)
	var top_rb := _find_top_performer("RB", year, week - 3, week)
	var top_wr := _find_top_performer("WR", year, week - 3, week)

	# Award player of the month
	if top_qb != "":
		_award_player_of_month(top_qb, "Offensive Player of the Month")
	if top_rb != "":
		_award_player_of_month(top_rb, "Offensive Player of the Month")
	if top_wr != "":
		_award_player_of_month(top_wr, "Offensive Player of the Month")

func _find_top_performer(position: String, year: int, week_start: int, week_end: int) -> String:
	# Scan player stats to find best performer
	# Returns player_id of top performer

	var best_player := ""
	var best_score := 0.0

	if not _world_state.has("player_career_stats"):
		return best_player

	var career_stats: Dictionary = _world_state["player_career_stats"]

	for player_id in career_stats.keys():
		var player := _get_player(player_id)
		if player == null or player.position != position:
			continue

		var player_years: Dictionary = career_stats[player_id]
		if not player_years.has(year):
			continue

		var season_stats: Dictionary = player_years[year]
		var score := _calculate_performance_score(position, season_stats)

		if score > best_score:
			best_score = score
			best_player = player_id

	return best_player

func _calculate_performance_score(position: String, stats: Dictionary) -> float:
	# Position-specific scoring
	match position:
		"QB":
			var yards := float(stats.get("passing_yards", 0))
			var tds := float(stats.get("passing_touchdowns", 0))
			var ints := float(stats.get("interceptions", 0))
			return yards + (tds * 25.0) - (ints * 15.0)
		"RB":
			var yards := float(stats.get("rushing_yards", 0))
			var tds := float(stats.get("rushing_touchdowns", 0))
			return yards + (tds * 30.0)
		"WR":
			var yards := float(stats.get("receiving_yards", 0))
			var tds := float(stats.get("receiving_touchdowns", 0))
			return yards + (tds * 25.0)
		_:
			return 0.0

func _award_player_of_month(player_id: String, award_name: String) -> void:
	var player := _get_player(player_id)
	if player == null:
		return

	# Record award
	var award_key := "potm_%d_w%d" % [_current_year, _current_week]
	player.career.awards[award_key] = 1

	print("AWARD: %s wins %s" % [player.get_full_name(), award_name])
```

### Game Event Processing Flow

```gdscript
## Complete flow for processing a game event
func _process_game_event(event: GameEvent, rng: RandomNumberGenerator) -> EventResult:
	var result := EventResult.new()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("SIMULATING GAME: Week %d" % event.week)
	print("  %s at %s" % [event.metadata["away_team_id"], event.metadata["home_team_id"]])

	# 1. Simulate game outcome
	# Expected RNG consumption: 1 randf()
	var game_result := _simulate_game(event, rng)

	if game_result.is_empty():
		result.add_error("Game simulation failed")
		return result

	# 2. Accumulate player stats
	# Expected RNG consumption: Variable (see StatGenerator)
	_process_game_completion(event, game_result, rng)

	# 3. Process injuries
	# Expected RNG consumption: 2 randf() per active player
	_process_game_injuries(game_result, rng)

	# 4. Generate post-game events
	# Expected RNG consumption: 0 (deterministic)
	_generate_post_game_events(game_result, rng)

	print("  Winner: %s" % game_result["winner_id"])
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	result.affected_teams.append(String(event.metadata["home_team_id"]))
	result.affected_teams.append(String(event.metadata["away_team_id"]))

	return result
```

---

## Implementation Phases

### Phase 1: Basic Loop
- [ ] Create SimulationLoop class
- [ ] Implement tick advancement
- [ ] Connect to existing event system
- [ ] Index rebuild on tick

### Phase 2: AI Integration
- [ ] Connect AITeamNeedsCache
- [ ] Event-driven cache invalidation
- [ ] Basic AI move logic

### Phase 3: Player-Coach Integration
- [ ] Action queue system
- [ ] Turn-based mode
- [ ] Notification system

### Phase 4: Save Integration
- [ ] Checkpoint saves
- [ ] RNG state preservation
- [ ] Event scheduler serialization

### Phase 5: Optimization
- [ ] Profile tick performance
- [ ] Incremental index updates (if needed)
- [ ] Background processing (if needed)

---

## Open Questions

1. **Tick Frequency**: Should we allow players to configure tick frequency?
2. **AI Complexity**: How sophisticated should AI trade/signing logic be in v1?
3. **Real-Time Mode**: Is real-time mode needed for v1, or turn-based only?
4. **Checkpoint Frequency**: How often should auto-saves occur?

---

## Summary

This design provides a flexible tick-based simulation that:
- Integrates with the existing event system
- Uses in-memory queries for performance
- Supports both turn-based and real-time play
- Maintains save/load compatibility
- Scales to handle 32 teams and 10,000+ players

The architecture separates concerns cleanly:
- `SimulationLoop`: Orchestration
- `EventScheduler`: Event timing
- `OptimizedPlayerQueries`: Runtime queries
- `AITeamNeedsCache`: AI optimization
- `PersistenceLayer`: Save/load
