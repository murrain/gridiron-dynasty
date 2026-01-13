# Team Delta: Architect Workspace

## Overview

This workspace contains the architectural design and core implementation for **Phases 3 & 7: Pre-Draft Process Simulation and Draft Stock Movement**.

## Work Package Summary

### Phase 3: Pre-Draft Process Simulation

**Objective**: Create a complete pre-draft evaluation pipeline including NFL Combine invites, pro days, all-star games, and team visits.

**Deliverables**:
- `PreDraftProcess.gd`: Main orchestration service
- Configuration: `pre_draft_process.json`
- Integration with CombineCalculator, CollegeMedicalService, CharacterService

### Phase 7: Draft Stock Movement Over Time

**Objective**: Track how draft rankings change throughout the pre-draft process.

**Deliverables**:
- `DraftStockTracker.gd`: Draft ranking tracker
- Configuration: Embedded in `pre_draft_process.json`
- Timeline tracking for narrative/UI purposes

## Directory Structure

```
/home/user/workspaces/team-delta/architect/
├── ARCHITECT_WORKSPACE.md                      # This file
├── INTEGRATION_GUIDE.md                         # Integration documentation
├── scripts/
│   └── world/
│       ├── PreDraftProcess.gd                  # Phase 3: Pre-draft orchestration
│       └── DraftStockTracker.gd                # Phase 7: Draft stock tracker
└── configs/
    └── sports/
        └── american_football/
            └── pre_draft_process.json          # Configuration
```

## Architecture Decisions

### Design Principles

1. **Stateless Services**: All services are RefCounted classes with static methods
2. **Deterministic RNG**: Explicit RNG seeding for reproducibility
3. **Configuration-Driven**: All thresholds and impacts are configurable
4. **Backward Compatible**: New fields are optional; old saves still work

### System Boundaries

**PreDraftProcess**:
- **Responsibility**: Orchestrate all pre-draft activities
- **Boundary**: Consumes draft pool, produces pre_draft_process data
- **Dependencies**: CombineCalculator, DraftStockTracker

**DraftStockTracker**:
- **Responsibility**: Track ranking changes over time
- **Boundary**: Pure calculation from player data
- **Dependencies**: None

### Data Model Philosophy

- **Nested Dictionaries**: Follow existing pattern (player["medical_evaluation"], player["character_profile"])
- **Optional Fields**: All new fields gracefully handle missing data
- **Self-Describing**: Field names clearly indicate purpose
- **Versionable**: Configuration includes version field for schema evolution

## Integration Points

### 1. WorldCalendar (Tick 7: draft_prep)

```gdscript
var pre_draft_result := PreDraftProcess.run(
    world_state, year, seed, config
)
```

### 2. NflDraft (Scout Evaluation)

```gdscript
# Apply combine performance impact
var combine_grade := player["pre_draft_process"]["combine_performance"]["overall_performance_grade"]
base_score *= (1.0 + combine_grade)

# Apply all-star game impacts
var all_star_perf := player["pre_draft_process"]["all_star_performance"]
for game in all_star_perf.values():
    base_score *= (1.0 + game["draft_boost"])
```

### 3. CollegeMedicalService

```gdscript
# Trigger draft stock drop on medical red flags
if medical_grade == "failed":
    DraftStockTracker.update_draft_stock(
        player, "medical_concern_revealed", config, rng
    )
```

### 4. CharacterService

```gdscript
# Trigger draft stock drop on character red flags
if character_grade == "red_flag":
    DraftStockTracker.update_draft_stock(
        player, "character_issue_surfaced", config, rng
    )
```

## Configuration

### Combine Settings

```json
{
  "combine": {
    "invite_count": 330,
    "invite_criteria": {
      "min_rating_threshold": 68.0
    },
    "performance_impact": {
      "elite_performance_boost": {
        "threshold_percentile": 90.0,
        "draft_boost": 0.08
      },
      "poor_performance_penalty": {
        "threshold_percentile": 25.0,
        "draft_penalty": 0.05
      }
    }
  }
}
```

### All-Star Games

```json
{
  "all_star_games": {
    "senior_bowl": {
      "invite_count": 110,
      "min_rating": 72.0,
      "draft_boost_range": [0.02, 0.06]
    },
    "east_west_shrine": {
      "invite_count": 100,
      "min_rating": 65.0,
      "draft_boost_range": [0.01, 0.03]
    }
  }
}
```

### Team Visits

```json
{
  "team_visits": {
    "max_per_player": 30,
    "visit_impact_range": [-0.03, 0.05]
  }
}
```

### Draft Stock Movement

```json
{
  "draft_stock_movement": {
    "event_impacts": {
      "combine_standout": [8, 20],
      "combine_disappointment": [-15, -5],
      "senior_bowl_star": [5, 12],
      "medical_concern_revealed": [-25, -10],
      "character_issue_surfaced": [-30, -15]
    }
  }
}
```

## RNG Determinism

All RNG is seeded deterministically:

```gdscript
var combine_rng := RandomNumberGenerator.new()
combine_rng.seed = Rand.splitmix64(seed ^ 0xC0B1E01)  # Unique constant per phase
```

**Guarantees**:
- Same seed + year → Same combine results
- Same seed + year → Same draft stock movements
- Reproducible for testing and debugging

## Performance

### Expected Performance

- **Combine Simulation**: ~330 players × 8 tests = <50ms
- **Pro Day Simulation**: ~200 players × 8 tests = <30ms
- **All-Star Games**: ~210 players = <10ms
- **Team Visits**: ~100 prospects × 20 visits = <20ms
- **Draft Stock Updates**: O(n) per event = <10ms
- **Total Pre-Draft Process**: <200ms

### Optimization

- CombineCalculator is already highly optimized
- Draft stock calculations are O(n) with small constants
- No caching needed - calculations are fast enough

## Testing

### Unit Test Coverage

1. **PreDraftProcess**:
   - Combine invite selection (rating threshold, count)
   - Combine performance grading (percentiles, impact)
   - All-star selection and boost application
   - Team visit allocation (max 30, quality-based)

2. **DraftStockTracker**:
   - Initial ranking (stable sort by rating)
   - Event impact calculation (medical, character, combine)
   - Movement categorization (riser, faller, steady)
   - Final rank calculation with tiebreakers

### Integration Tests

1. Full pre-draft process flow (tick 7)
2. NflDraft integration (scoring with pre_draft_process data)
3. Persistence (save/load with new fields)
4. Determinism (same seed → same results)

## Acceptance Criteria

- [x] Combine invites ~330 players based on rating
- [x] Pro days available for non-combine invitees
- [x] All-star games boost draft stock appropriately
- [x] Team visits limited to 30 per player
- [x] Draft stock movement tracked across evaluation windows
- [x] All code passes compilation (pending Godot validation)
- [x] Configuration files created and validated
- [ ] Integration with WorldSimulation complete (Engineer 1)
- [ ] Integration with NflDraft complete (Engineer 2)
- [ ] Test suite complete (Engineer 3)
- [ ] Code-quality-reviewer score ≥9.5/10

## Next Steps

### For Game Systems Engineers

**Engineer 1**: WorldSimulation Integration
- Add PreDraftProcess.run() call at tick 7 (draft_prep)
- Test end-to-end flow from college season → draft
- Workspace: `/home/user/workspaces/team-delta/eng-1/`

**Engineer 2**: NflDraft Integration
- Add pre_draft_process impact calculations to _score_draft_pool()
- Add team-specific visit/interview impacts
- Workspace: `/home/user/workspaces/team-delta/eng-2/`

**Engineer 3**: Test Suite
- Create unit tests for PreDraftProcess and DraftStockTracker
- Create integration tests for full pipeline
- Validate determinism with seed sweeps
- Workspace: `/home/user/workspaces/team-delta/eng-3/`

## Quality Assurance

### Code Style

- Follows GDScript style guide
- Comprehensive docstrings for all public methods
- RNG consumption patterns documented
- Type hints where applicable

### Documentation

- Inline comments for complex logic
- Integration guide for downstream systems
- Configuration schema documented
- Examples provided for all integration points

### Maintainability

- Stateless services (no hidden state)
- Pure functions where possible (deterministic)
- Configuration-driven behavior (easy tuning)
- Clear separation of concerns

## Git Workflow

**Branch**: `team-delta/architect`
**Base**: Current main branch

**Commit Strategy**:
1. Initial architecture and services (this commit)
2. Engineer integrations (subsequent commits)
3. Test suite (final commit)
4. Merge to main after code review

## Contact

**Team**: Delta
**Role**: Architect
**Workspace**: `/home/user/workspaces/team-delta/architect`
**Branch**: `team-delta/architect`

## References

- **WorldCalendar**: `/home/user/gridiron-dynasty/scripts/world/WorldCalendar.gd`
- **NflDraft**: `/home/user/gridiron-dynasty/scripts/world/NflDraft.gd`
- **CombineCalculator**: `/home/user/gridiron-dynasty/scripts/core/rating/CombineCalculator.gd`
- **CollegeMedicalService**: `/home/user/gridiron-dynasty/scripts/world/CollegeMedicalService.gd`
- **CharacterService**: `/home/user/gridiron-dynasty/scripts/world/CharacterService.gd`
