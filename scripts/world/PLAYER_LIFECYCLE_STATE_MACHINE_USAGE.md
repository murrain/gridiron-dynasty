# PlayerLifecycleStateMachine Usage Guide

## Overview

The `PlayerLifecycleStateMachine` provides a single source of truth for player lifecycle transitions. It ensures all stage transitions are valid and provides utilities for querying lifecycle state.

## Basic Usage

### Checking if a Transition is Valid

```gdscript
const Player = preload("res://scripts/core/models/Player.gd")
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

func can_player_declare_for_draft(player: Player) -> bool:
    return PlayerLifecycleStateMachine.can_transition(
        player.stage,
        Player.PlayerStage.DRAFT_ELIGIBLE
    )
```

### Transitioning a Player

```gdscript
func declare_player_for_draft(player: Player, phase_id: String) -> bool:
    if PlayerLifecycleStateMachine.can_transition(player.stage, Player.PlayerStage.DRAFT_ELIGIBLE):
        return PlayerLifecycleStateMachine.transition_player(
            player,
            Player.PlayerStage.DRAFT_ELIGIBLE,
            phase_id
        )
    return false
```

### Getting Valid Next Stages

```gdscript
func get_player_options(player: Player) -> Array:
    var next_stages := PlayerLifecycleStateMachine.get_valid_next_stages(player.stage)
    var options := []
    for stage in next_stages:
        options.append({
            "stage": stage,
            "name": _get_stage_display_name(stage)
        })
    return options
```

## Integration Points

### 1. Replace Player.transition_to() Calls

**Before:**
```gdscript
# Old method in Player.gd (lines 318-339)
player.transition_to(Player.PlayerStage.DRAFT_ELIGIBLE)
```

**After:**
```gdscript
# Use centralized state machine
PlayerLifecycleStateMachine.transition_player(
    player,
    Player.PlayerStage.DRAFT_ELIGIBLE,
    "pre_draft"
)
```

### 2. Pre-Draft Process (PreDraftProcess.gd)

```gdscript
# When declaring underclassmen for draft
func _execute_underclassman_declarations(eligible_players: Array, phase_id: String) -> void:
    for player in eligible_players:
        if player.declared_for_draft:
            # Use state machine for transition
            PlayerLifecycleStateMachine.transition_player(
                player,
                Player.PlayerStage.DRAFT_ELIGIBLE,
                phase_id
            )
```

### 3. Draft Process (NflDraft.gd / InteractiveDraft.gd)

```gdscript
# When drafting a player
func _draft_player(player: Player, team_id: String) -> void:
    # Transition to NFL_ROOKIE
    PlayerLifecycleStateMachine.transition_player(
        player,
        Player.PlayerStage.NFL_ROOKIE,
        "nfl_draft"
    )

    # Additional draft logic...
```

### 4. Free Agency (FreeAgency.gd)

```gdscript
# When signing a free agent
func _sign_free_agent(player: Player, team_id: String, contract: Dictionary) -> void:
    # Determine target stage based on player history
    var target_stage := Player.PlayerStage.NFL_VETERAN
    if player.stage == Player.PlayerStage.DRAFT_ELIGIBLE:
        target_stage = Player.PlayerStage.NFL_ROOKIE

    PlayerLifecycleStateMachine.transition_player(
        player,
        target_stage,
        "free_agency"
    )

    # Additional signing logic...
```

### 5. Retirement (PlayerLifecycle.gd)

```gdscript
# When player retires
func _retire_player(player: Player, reason: String) -> void:
    PlayerLifecycleStateMachine.transition_player(
        player,
        Player.PlayerStage.RETIRED,
        "retirement"
    )

    # Additional retirement logic...
```

### 6. Season End Processing

```gdscript
# Convert rookies to veterans
func _process_season_end_transitions(players: Array) -> void:
    for player in players:
        if player.stage == Player.PlayerStage.NFL_ROOKIE:
            # Transition rookie to veteran after first season
            PlayerLifecycleStateMachine.transition_player(
                player,
                Player.PlayerStage.NFL_VETERAN,
                "nfl_season_end"
            )
```

## Phase IDs

The state machine defines expected phase IDs for each transition:

| Transition | Phase ID |
|------------|----------|
| HIGH_SCHOOL → COLLEGE | `college_recruiting` |
| COLLEGE → DRAFT_ELIGIBLE | `pre_draft` |
| DRAFT_ELIGIBLE → NFL_ROOKIE | `nfl_draft` |
| DRAFT_ELIGIBLE → NFL_FREE_AGENT | `post_draft_udfa` |
| NFL_ROOKIE → NFL_VETERAN | `nfl_season_end` |
| NFL_VETERAN → NFL_FREE_AGENT | `nfl_contract_expiry` |
| NFL_FREE_AGENT → NFL_VETERAN | `free_agency` |
| Any → RETIRED | `retirement` |
| COLLEGE → COLLEGE | `college_season_end` |

## Lifecycle Paths

### Primary Path (Standard Progression)
```
HIGH_SCHOOL → COLLEGE → DRAFT_ELIGIBLE → NFL_ROOKIE → NFL_VETERAN → RETIRED
```

### Undrafted Free Agent Path
```
HIGH_SCHOOL → COLLEGE → DRAFT_ELIGIBLE → NFL_FREE_AGENT → NFL_VETERAN → RETIRED
```

### Free Agency Cycles
```
NFL_VETERAN ←→ NFL_FREE_AGENT (contract cycles)
```

## Validation Utilities

### Check if Stage is Terminal

```gdscript
if PlayerLifecycleStateMachine.is_terminal_stage(player.stage):
    print("Player has reached terminal stage (retired)")
```

### Get All Reachable Stages

```gdscript
# Find all stages player could potentially reach
var reachable := PlayerLifecycleStateMachine.get_reachable_stages(player.stage)
if Player.PlayerStage.NFL_ROOKIE in reachable:
    print("Player could potentially reach NFL")
```

### Validate Transition Phase

```gdscript
# Ensure transition is happening in correct phase
if PlayerLifecycleStateMachine.validate_transition_phase(
    from_stage,
    to_stage,
    current_phase_id
):
    # Proceed with transition
    pass
else:
    push_warning("Transition attempted in wrong phase")
```

## Benefits

1. **Single Source of Truth**: All valid transitions defined in one place
2. **Type Safety**: Compile-time checking of stage enums
3. **Audit Trail**: All transitions logged with phase context
4. **Validation**: Automatic validation prevents invalid transitions
5. **Extensibility**: Easy to add new stages or transition rules
6. **Testing**: Comprehensive test coverage ensures correctness
7. **Documentation**: Clear lifecycle paths and phase mapping

## Future Enhancements

When DataBus is implemented, the state machine will automatically emit events:

```gdscript
# Automatic event emission (future)
DataBus.emit_signal("player_stage_changed", {
    "player_id": player.id,
    "from_stage": from_stage,
    "to_stage": to_stage,
    "phase_id": phase_id,
    "timestamp": Time.get_ticks_msec()
})
```

This will enable reactive systems:
- UI updates when player stages change
- Analytics tracking lifecycle transitions
- Achievement/milestone detection
- Draft board updates when players declare
- Roster validation when players sign/retire
