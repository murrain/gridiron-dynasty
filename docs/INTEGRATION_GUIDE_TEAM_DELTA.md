# Pre-Draft Process Integration Guide

## Overview

This document describes the integration points for Phases 3 and 7: Pre-Draft Process Simulation and Draft Stock Movement.

## Architecture

### Data Flow

```
WorldCalendar (tick 7: draft_prep)
    ↓
PreDraftProcess.run()
    ↓
    ├─→ DraftStockTracker.initialize_draft_stock()
    ├─→ CombineCalculator.compute_all() (per player)
    ├─→ DraftStockTracker.update_draft_stock() (per event)
    └─→ DraftStockTracker.finalize_draft_stock()
    ↓
NflDraft.run()
    ↓
    ├─→ Read player["pre_draft_process"]
    ├─→ Read player["draft_stock_timeline"]
    └─→ Apply draft_stock_movement to final scoring
```

### System Boundaries

1. **PreDraftProcess.gd**
   - **Responsibility**: Orchestrate all pre-draft evaluation activities
   - **Inputs**: world_state, year, seed, config
   - **Outputs**: Updated player dictionaries with pre_draft_process fields
   - **Dependencies**: CombineCalculator, DraftStockTracker

2. **DraftStockTracker.gd**
   - **Responsibility**: Track draft ranking changes over time
   - **Inputs**: draft_pool, events, config
   - **Outputs**: Updated player dictionaries with draft_stock_timeline
   - **Dependencies**: None (pure calculation)

3. **Configuration**: `pre_draft_process.json`
   - **Responsibility**: Define all thresholds, impacts, and rules
   - **Scope**: Combine, all-star games, team visits, draft stock movement

## Data Models

### Player Dictionary Extensions

```gdscript
player = {
    # ... existing fields ...

    "pre_draft_process": {
        "combine_invited": bool,
        "combine_performance": {
            "forty_percentile": float,
            "vertical_percentile": float,
            "overall_performance_grade": float,  # -0.10 to +0.10 impact
            "results": Dictionary  # Raw combine results
        },
        "pro_day_attended": bool,
        "pro_day_performance": Dictionary,
        "all_star_games": ["senior_bowl", "east_west_shrine"],
        "all_star_performance": {
            "senior_bowl": {"draft_boost": float},
            "east_west_shrine": {"draft_boost": float}
        },
        "team_visits": ["team_id_1", "team_id_2", ...],  # Max 30
        "visit_impacts": {
            "team_id_1": float,  # -0.03 to +0.05
            "team_id_2": float
        },
        "interview_scores": {
            "team_id_1": float,  # 0-100 scale
            "team_id_2": float
        },
        "draft_stock_movement": float  # Aggregated impact
    },

    "draft_stock_timeline": {
        "pre_season_rank": int,
        "post_season_rank": int,
        "post_combine_rank": int,
        "final_rank": int,
        "movement_events": [
            {
                "event": str,  # "combine_standout", "medical_concern_revealed", etc.
                "impact": int,  # Position change
                "timestamp": str
            }
        ],
        "total_movement": int,  # Net position change
        "movement_category": str  # "riser", "faller", "steady"
    }
}
```

## Integration with Existing Systems

### 1. WorldCalendar Integration

**File**: `scripts/world/WorldSimulation.gd` or similar

```gdscript
# In year advancement loop, at tick 7 (draft_prep):
if phase_id == "draft_prep":
    var pre_draft_result := PreDraftProcess.run(
        world_state,
        year,
        seed,
        config
    )

    print("Pre-draft process complete: %d combine invites, %d all-star participants" % [
        pre_draft_result["combine_invites"],
        pre_draft_result["all_star_participants"]
    ])
```

### 2. NflDraft Integration

**File**: `scripts/world/NflDraft.gd`

Add to `_score_draft_pool()` function:

```gdscript
# After calculating base_score from scout evaluation:

# Apply pre-draft process impacts
var pre_draft: Dictionary = player.get("pre_draft_process", {})

# Combine performance impact
var combine_perf: Dictionary = pre_draft.get("combine_performance", {})
var combine_grade := float(combine_perf.get("overall_performance_grade", 0.0))
base_score *= (1.0 + combine_grade)

# All-star game impacts
var all_star_perf: Dictionary = pre_draft.get("all_star_performance", {})
for game_name in all_star_perf.keys():
    var game_perf: Dictionary = all_star_perf[game_name]
    var boost := float(game_perf.get("draft_boost", 0.0))
    base_score *= (1.0 + boost)

# Team-specific visit impact
var visit_impacts: Dictionary = pre_draft.get("visit_impacts", {})
if visit_impacts.has(team_id):
    var visit_impact := float(visit_impacts[team_id])
    base_score *= (1.0 + visit_impact)

# Team-specific interview score
var interview_scores: Dictionary = pre_draft.get("interview_scores", {})
if interview_scores.has(team_id):
    var interview_score := float(interview_scores[team_id])
    # Scale interview score (0-100) to multiplier (0.9-1.1)
    var interview_mult := 0.9 + (interview_score / 100.0) * 0.2
    base_score *= interview_mult

# Draft stock movement narrative (for logging/UI only, not scoring)
var timeline: Dictionary = player.get("draft_stock_timeline", {})
var movement_category := String(timeline.get("movement_category", "steady"))
```

### 3. CollegeMedicalService Integration

**File**: `scripts/world/CollegeSeason.gd` or similar

```gdscript
# After medical evaluation during draft prep:
if medical_grade in ["failed", "major_concern"]:
    DraftStockTracker.update_draft_stock(
        player,
        "medical_concern_revealed",
        config,
        rng
    )
```

### 4. CharacterService Integration

**File**: `scripts/world/CollegeSeason.gd` or similar

```gdscript
# After character evaluation during draft prep:
if character_grade in ["red_flag", "concern"]:
    DraftStockTracker.update_draft_stock(
        player,
        "character_issue_surfaced",
        config,
        rng
    )
```

## Configuration Requirements

### Required Config Files

1. **`configs/sports/american_football/pre_draft_process.json`**
   - Combine invite criteria
   - All-star game settings
   - Team visit rules
   - Draft stock movement impacts

2. **`configs/sports/american_football/combine_tests.json`** (existing)
   - Combine test definitions
   - Used by CombineCalculator

3. **`configs/sports/american_football/main.json`** (existing)
   - Add `"combine_tuning"` section if not present
   - Used by CombineCalculator

## RNG Determinism

All RNG calls are seeded deterministically:

```gdscript
var combine_rng := RandomNumberGenerator.new()
combine_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E01)

var pro_day_rng := RandomNumberGenerator.new()
pro_day_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E02)

# ... etc
```

This ensures:
- Same seed + year → Same combine results
- Same seed + year → Same draft stock movements
- Reproducible simulation for testing/debugging

## Persistence & Versioning

### Save Format

Player dictionaries with pre_draft_process and draft_stock_timeline fields can be serialized directly to JSON.

### Migration Strategy

If loading an old save without these fields:
- Fields are optional
- Systems check `if player.has("pre_draft_process")` before access
- Missing fields default to neutral impact (no bonus/penalty)

### Versioning

Config file includes `"version": 1` for future schema changes.

## Performance Considerations

### Optimization Strategies

1. **Combine Invites**: 330 players × 8 tests = ~2,640 calculations
   - CombineCalculator is highly optimized
   - Expected time: <50ms

2. **Pro Days**: ~200 players × 8 tests = ~1,600 calculations
   - Expected time: <30ms

3. **Draft Stock Updates**: O(n) per event, where n = pool size
   - Expected time: <10ms per event

4. **Total Pre-Draft Process**: <200ms for full draft class

### Caching

No caching is needed - all calculations are fast enough to run on-demand.

## Testing Strategy

### Unit Tests

1. **PreDraftProcess**
   - Test combine invite selection (top 330 by rating)
   - Test combine performance impact calculation
   - Test all-star game selection and boost application
   - Test team visit allocation

2. **DraftStockTracker**
   - Test initial ranking (stable sort)
   - Test event impact calculation
   - Test movement categorization
   - Test consensus ranking aggregation

### Integration Tests

1. Test full pre-draft process flow
2. Test integration with NflDraft scoring
3. Test persistence (save/load with new fields)
4. Test determinism (same seed → same results)

## Acceptance Criteria Checklist

- [ ] Combine invites ~330 players based on rating + conference tier
- [ ] Pro days available for non-combine invitees
- [ ] All-star games boost draft stock appropriately
- [ ] Team visits limited to 30 per player
- [ ] Draft stock movement tracked across evaluation windows
- [ ] All code passes compilation
- [ ] Integration with NflDraft.gd complete
- [ ] Configuration files created and validated
- [ ] RNG determinism verified
- [ ] Code-quality-reviewer score ≥9.5/10

## Next Steps for Game Systems Engineers

1. **Engineer 1**: Implement WorldSimulation integration
   - Add PreDraftProcess.run() call at tick 7
   - Test end-to-end flow

2. **Engineer 2**: Implement NflDraft integration
   - Add pre_draft_process impact calculations
   - Test draft scoring with new data

3. **Engineer 3**: Create test suite
   - Unit tests for PreDraftProcess and DraftStockTracker
   - Integration tests for full pipeline
   - Determinism validation

## Contact

**Architect**: Team Delta Architect
**Workspace**: `/home/user/workspaces/team-delta/architect`
**Branch**: `team-delta/architect`
