# Migration Guide: PlayerLifecycleStateMachine

## Overview

This guide helps migrate existing code from using `Player.transition_to()` to the centralized `PlayerLifecycleStateMachine`.

## Why Migrate?

The `PlayerLifecycleStateMachine` provides:

1. **Single Source of Truth**: All transition rules in one place
2. **Phase Tracking**: Know which phase should handle each transition
3. **Better Logging**: Includes phase context in transition logs
4. **Future Event Bus**: Ready for DataBus integration
5. **Easier Testing**: Centralized logic is easier to test

## Migration Steps

### Step 1: Update Player.gd (Optional Deprecation)

The existing `Player.transition_to()` method (lines 318-339) can be deprecated in favor of the state machine:

```gdscript
# In Player.gd

## @deprecated Use PlayerLifecycleStateMachine.transition_player() instead
## This method will be removed in a future version
func transition_to(new_stage: PlayerStage) -> bool:
	push_warning("Player.transition_to() is deprecated. Use PlayerLifecycleStateMachine.transition_player() instead.")

	# Forward to state machine with generic phase
	const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")
	return PlayerLifecycleStateMachine.transition_player(self, new_stage, "legacy_transition")
```

Or keep it as a convenience wrapper that delegates to the state machine.

### Step 2: Update Simulation Phases

#### PreDraftProcess.gd

**Before:**
```gdscript
# In _execute_underclassman_declarations()
for player in eligible_players:
    if player.declared_for_draft:
        player.transition_to(Player.PlayerStage.DRAFT_ELIGIBLE)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# In _execute_underclassman_declarations()
for player in eligible_players:
    if player.declared_for_draft:
        PlayerLifecycleStateMachine.transition_player(
            player,
            Player.PlayerStage.DRAFT_ELIGIBLE,
            "pre_draft"
        )
```

#### NflDraft.gd / InteractiveDraft.gd

**Before:**
```gdscript
# When drafting player
drafted_player.transition_to(Player.PlayerStage.NFL_ROOKIE)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# When drafting player
PlayerLifecycleStateMachine.transition_player(
    drafted_player,
    Player.PlayerStage.NFL_ROOKIE,
    "nfl_draft"
)
```

#### FreeAgency.gd

**Before:**
```gdscript
# When signing free agent
player.transition_to(Player.PlayerStage.NFL_VETERAN)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# When signing free agent - determine correct stage
var target_stage := Player.PlayerStage.NFL_VETERAN
if player.stage == Player.PlayerStage.DRAFT_ELIGIBLE:
    # UDFA signing as rookie
    target_stage = Player.PlayerStage.NFL_ROOKIE

PlayerLifecycleStateMachine.transition_player(
    player,
    target_stage,
    "free_agency"
)
```

#### NflSeason.gd

**Before:**
```gdscript
# Convert rookies to veterans
for player in team_roster:
    if player.stage == Player.PlayerStage.NFL_ROOKIE:
        player.transition_to(Player.PlayerStage.NFL_VETERAN)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# Convert rookies to veterans
for player in team_roster:
    if player.stage == Player.PlayerStage.NFL_ROOKIE:
        PlayerLifecycleStateMachine.transition_player(
            player,
            Player.PlayerStage.NFL_VETERAN,
            "nfl_season_end"
        )
```

#### PlayerLifecycle.gd (Retirement)

**Before:**
```gdscript
# In _should_retire() when returning true
player.transition_to(Player.PlayerStage.RETIRED)
```

**After:**
```gdscript
# Actually, retirement happens in the calling code, not in _should_retire()
# The calling code should be updated:

const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# In advance_one_year when player should retire
if should_retire:
    PlayerLifecycleStateMachine.transition_player(
        p,
        Player.PlayerStage.RETIRED,
        "retirement"
    )
    return {"player": p, "retired": true, "development_report": development_report}
```

#### CollegeSeason.gd

**Before:**
```gdscript
# When recruiting players
recruited_player.transition_to(Player.PlayerStage.COLLEGE)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# When recruiting players
PlayerLifecycleStateMachine.transition_player(
    recruited_player,
    Player.PlayerStage.COLLEGE,
    "college_recruiting"
)
```

### Step 3: Update Contract Lifecycle Integration

When contract status changes trigger stage transitions:

**Before:**
```gdscript
# When contract expires
if contract_expired:
    player.transition_to(Player.PlayerStage.NFL_FREE_AGENT)
```

**After:**
```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# When contract expires
if contract_expired:
    PlayerLifecycleStateMachine.transition_player(
        player,
        Player.PlayerStage.NFL_FREE_AGENT,
        "nfl_contract_expiry"
    )
```

### Step 4: Add Validation to UI

In UI code that displays player actions:

```gdscript
const PlayerLifecycleStateMachine = preload("res://scripts/world/PlayerLifecycleStateMachine.gd")

# Check if player can declare for draft
func _can_declare_for_draft(player: Player) -> bool:
    return PlayerLifecycleStateMachine.can_transition(
        player.stage,
        Player.PlayerStage.DRAFT_ELIGIBLE
    )

# Get available actions for player
func _get_player_actions(player: Player) -> Array:
    var actions := []
    var valid_stages := PlayerLifecycleStateMachine.get_valid_next_stages(player.stage)

    for stage in valid_stages:
        match stage:
            Player.PlayerStage.DRAFT_ELIGIBLE:
                actions.append({"id": "declare_draft", "label": "Declare for Draft"})
            Player.PlayerStage.RETIRED:
                actions.append({"id": "retire", "label": "Retire"})
            # ... etc

    return actions
```

## Search and Replace Patterns

Use these patterns to find code that needs updating:

### Pattern 1: Direct transition_to calls
```
Search: \.transition_to\(
Files: scripts/world/*.gd
```

### Pattern 2: Stage assignment
```
Search: \.stage\s*=\s*Player\.PlayerStage\.
Files: scripts/world/*.gd
```

### Pattern 3: Manual stage checks before transition
```
Search: if.*stage.*==.*PlayerStage
Files: scripts/world/*.gd
```

## Testing After Migration

After migrating code, run these tests:

1. **Unit Tests**: Run the state machine tests
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://scripts/tests/world -gfile=test_player_lifecycle_state_machine.gd
   ```

2. **Integration Tests**: Test each phase that performs transitions
   - College recruiting
   - Draft declaration
   - NFL draft
   - Free agency
   - Season end
   - Retirement

3. **Determinism Tests**: Verify transitions are deterministic
   - Same seed should produce same transitions
   - Log files should be identical across runs

## Rollout Strategy

### Phase 1: Add State Machine (Done)
- ✅ Create PlayerLifecycleStateMachine.gd
- ✅ Add comprehensive tests
- ✅ Document usage patterns

### Phase 2: Parallel Operation
- Keep existing Player.transition_to() working
- Add PlayerLifecycleStateMachine calls in new code
- Gradually migrate existing calls

### Phase 3: Full Migration
- Update all world/*.gd files to use state machine
- Deprecate Player.transition_to() with warning
- Run full test suite

### Phase 4: Cleanup
- Remove deprecated Player.transition_to()
- Add DataBus event emission
- Monitor for any missed transitions

## Validation Checklist

After migration, verify:

- [ ] All transitions use PlayerLifecycleStateMachine
- [ ] All transitions include correct phase_id
- [ ] No direct player.stage assignments (except in state machine)
- [ ] Tests pass with new state machine
- [ ] Determinism tests still pass
- [ ] No player.transition_to() calls remain (or only deprecated wrapper)
- [ ] Documentation updated with new patterns

## Common Pitfalls

### ❌ Don't: Direct stage assignment
```gdscript
player.stage = Player.PlayerStage.NFL_ROOKIE  # BAD
```

### ✅ Do: Use state machine
```gdscript
PlayerLifecycleStateMachine.transition_player(player, Player.PlayerStage.NFL_ROOKIE, "nfl_draft")
```

### ❌ Don't: Skip validation
```gdscript
# Just setting stage without checking if valid
player.stage = new_stage
```

### ✅ Do: Validate first
```gdscript
if PlayerLifecycleStateMachine.can_transition(player.stage, new_stage):
    PlayerLifecycleStateMachine.transition_player(player, new_stage, phase_id)
```

### ❌ Don't: Use generic phase names
```gdscript
PlayerLifecycleStateMachine.transition_player(player, stage, "update")  # BAD
```

### ✅ Do: Use specific phase IDs
```gdscript
PlayerLifecycleStateMachine.transition_player(player, stage, "nfl_draft")  # GOOD
```

## Questions?

If you encounter issues during migration:

1. Check PLAYER_LIFECYCLE_STATE_MACHINE_USAGE.md for examples
2. Review test cases in test_player_lifecycle_state_machine.gd
3. Verify phase IDs in TRANSITION_PHASES constant
4. Ensure transition is in VALID_TRANSITIONS map
