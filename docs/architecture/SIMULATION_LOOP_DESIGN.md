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
