# High School Simplification Integration Guide

## Overview

The new HighSchoolBackground system replaces the complex 420-school simulation with lightweight one-time generation. This document describes how to integrate it with AdvanceWorldYear.gd.

## Changes Required in AdvanceWorldYear.gd

### 1. Remove Old Imports

```gdscript
# REMOVE these lines:
const HighSchoolGenerator = preload("res://scripts/world/HighSchoolGenerator.gd")
const HighSchoolAssignment = preload("res://scripts/world/HighSchoolAssignment.gd")
const HighSchoolSeason = preload("res://scripts/world/HighSchoolSeason.gd")

# ADD this line:
const HighSchoolBackground = preload("res://scripts/world/HighSchoolBackground.gd")
```

### 2. Remove School Generation (lines 180-186)

The new system doesn't use individual school entities. Remove this entire section:

```gdscript
# REMOVE THIS:
var schools: Array = world_state.get("hs_schools", []) as Array
if schools.is_empty():
	var school_gen := HighSchoolGenerator.new()
	var config := _get_config()
	var generated := school_gen.generate(step_seeds["hs_school_gen"], "world/high_schools", config)
	schools = generated.get("schools", []) as Array
	world_state["hs_schools"] = schools
```

### 3. Replace _step_hs_assign() (lines 211-223)

Replace the school assignment logic with HS background generation:

```gdscript
## Generate HS background for unassigned players
func _step_hs_assign(world_state: Dictionary, step_seed: int) -> void:
	var hs_players: Array = world_state.get("hs_players", []) as Array
	var rng := RandomNumberGenerator.new()
	rng.seed = step_seed

	var updated_count := 0
	for player in hs_players:
		if player == null:
			continue

		# Skip if already has HS background
		if player.has("hs_region"):
			continue

		# Skip if already graduated HS
		if String(player.get("eligibility_status", "")) == "hs_grad":
			continue

		# Generate HS background
		var hs_background := HighSchoolBackground.generate_hs_background(player, rng)

		# Merge into player dict
		for key in hs_background.keys():
			player[key] = hs_background[key]

		updated_count += 1

	print("Generated HS background for %d players" % updated_count)
	world_state["hs_players"] = hs_players
```

### 4. Simplify _step_hs_season() (lines 244-267)

Replace the full season simulation with simple development application:

```gdscript
## Apply HS development and advance player years
func _step_hs_season(world_state: Dictionary, year: int, step_seed: int) -> void:
	var hs_players: Array = world_state.get("hs_players", []) as Array
	var hs_cfg: Dictionary = _get_config().get_config("world/high_schools")

	var eligibility_cfg: Dictionary = hs_cfg.get("eligibility", {}) as Dictionary
	var hs_years := int(eligibility_cfg.get("hs_years", 4))

	var active: Array = []
	var graduated: Array = []

	for player in hs_players:
		if player == null:
			continue

		# Increment HS year
		var current_hs_year := int(player.get("hs_year", 0))
		current_hs_year += 1
		player["hs_year"] = current_hs_year

		# Check if graduated
		if current_hs_year >= hs_years:
			player["eligibility_status"] = "hs_grad"
			# Apply full HS development on graduation
			HighSchoolBackground.apply_hs_development(player, hs_years)
			graduated.append(player)
		else:
			active.append(player)

	print("HS Season complete: %d active, %d graduated" % [active.size(), graduated.size()])

	# Update world state
	world_state["hs_players"] = active
	world_state["hs_grads"] = graduated
```

## Migration Notes

### Backward Compatibility

**Breaking Change:** Existing save games with hs_schools array will no longer work. This is acceptable per the design scope.

Players in the middle of HS when migrating will need their HS background generated retroactively.

### World State Changes

**Removed fields:**
- `world_state["hs_schools"]` - No longer needed

**Modified fields:**
- `world_state["hs_players"]` - Players now have simpler HS fields:
  - `hs_region` (String)
  - `hs_program_tier` (String)
  - `recruiting_star_rating` (int)
  - `development_modifier` (float)
  - `initial_hype` (float)

**Removed from players:**
- `hs_school_id`
- `hs_stats`
- `development_context`

### Performance Impact

**Before:** O(n × schools) with annual simulation passes
**After:** O(n) one-time generation

Expected speedup: 5-10x for HS phase with 10,000+ players

## Files to Remove

Once integration is complete, these files can be deleted:
- `/scripts/world/HighSchoolGenerator.gd`
- `/scripts/world/HighSchoolAssignment.gd`
- `/scripts/world/HighSchoolSeason.gd` (or keep as deprecated)

## Testing

After integration:
1. Run full world advancement for 5 years
2. Verify players graduate with proper star ratings
3. Verify hype values are reasonable (15-95 range)
4. Verify regional distribution matches weights
5. Check that development modifiers are applied correctly

## Additional Integration

The `initial_hype` field should be used when players enter college recruiting:
- Copy to player's `hype` stat during college transition
- Update with combine/event modifiers as they occur
- Use in scout evaluations via ScoutRuntime.score_player_enhanced()
