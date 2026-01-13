# Phase 6: College Awards & Media Hype - Architecture Design

## Executive Summary

This document defines the architecture for the College Awards & Media Hype system (Phase 6). As the Architecture Guardian, I have reviewed the proposed data model and integration points to ensure they align with existing system patterns and maintain long-term sustainability.

## Architectural Assessment

### Impact Scope
- **Core Data Models**: Player dictionaries, world_state structures
- **Integration Points**: CollegeSeason.gd, HypeGenerator.gd, NflDraft.gd
- **New Systems**: CollegeAwardsService.gd, mock draft generation
- **Configuration**: New college_awards.json config file

### Original Proposal Analysis

The initial specification proposed adding these fields to player dictionaries:

```gdscript
"college_awards": {
    "heisman_votes": {year: {"rank": int, "votes": int}},
    "all_american": {year: {"team": "first"|"second"|"third"}},
    "conference_awards": {year: ["offensive_poy", "defensive_poy", ...]},
    "weekly_honors": int,
    "bowl_mvp": bool
},
"media_profile": {
    "hype": float,
    "mock_draft_positions": {year: {"espn": int, "nfl_network": int}},
    "consensus_ranking": int,
    "hype_vs_talent_gap": float
}
```

**DECISION: REQUIRES MODIFICATION**

**Critical Issues Identified:**

1. **Temporal Structure Inconsistency**
   - Mixes annual data (`heisman_votes[year]`, `all_american[year]`) with career aggregates (`weekly_honors`, `bowl_mvp`)
   - Violates single responsibility principle - one structure serving two temporal scopes
   - Impact: Makes querying and maintenance difficult

2. **Data Redundancy**
   - `media_profile.hype` duplicates existing player hype field managed by HypeGenerator
   - Creates potential for inconsistency between two hype sources
   - Violates DRY principle

3. **Architectural Pattern Deviation**
   - Existing awards system stores data at world_state level (see AwardSelector.gd)
   - NFL awards: `world_state["awards"][year]`, `world_state["all_pro_teams"][year]`
   - Proposed model breaks this pattern by embedding everything in player dictionaries
   - Impact: Inconsistent query patterns across similar systems

4. **Nested Year Keys**
   - Using `{year: {...}}` as dictionary keys in player data is awkward in GDScript
   - Makes iteration and lookups cumbersome
   - Doesn't align with existing temporal data patterns

5. **Scope Creep**
   - `weekly_honors` and `bowl_mvp` not mentioned in requirements
   - Premature complexity that may never be used
   - Violates YAGNI (You Aren't Gonna Need It)

6. **Missing Versioning Strategy**
   - No consideration for persistence format changes
   - No migration path for future modifications
   - Risk: Breaking changes when evolving the system

## Approved Architecture

### Data Model Design

Following the established patterns from NFL awards (AwardSelector.gd) and maintaining consistency with existing world_state structures:

#### World-Level Storage (Primary)

```gdscript
# Annual college awards (parallel to NFL awards structure)
world_state["college_awards"][year] = {
    "heisman": {
        "winner": {"player_id": str, "school_id": str, "position": str, "votes": int},
        "finalists": [
            {"player_id": str, "rank": int, "votes": int, "school_id": str, "position": str},
            ...
        ]
    },
    "conference_awards": {
        "conference_id": {
            "offensive_poy": {"player_id": str, "school_id": str, "position": str},
            "defensive_poy": {"player_id": str, "school_id": str, "position": str}
        },
        ...
    }
}

# All-American teams (parallel to NFL All-Pro structure)
world_state["all_american_teams"][year] = {
    "first_team": [
        {"player_id": str, "position": str, "school_id": str, "score": float},
        ...
    ],
    "second_team": [...],
    "third_team": [...]
}

# Mock draft rankings (new structure for media perception)
world_state["mock_drafts"][year] = {
    "source_rankings": {
        "espn": [
            {"player_id": str, "rank": int, "position": str, "school_id": str},
            ...
        ],
        "nfl_network": [...],
        "pff": [...]
    },
    "consensus": [
        {"player_id": str, "avg_rank": float, "rank_variance": float, "hype_factor": float},
        ...
    ]
}
```

**Rationale:**
- Maintains consistency with NFL awards patterns
- Enables efficient year-based queries
- Separates concerns: world-level for aggregated views, player-level for individual context
- Supports easy iteration for UI display (e.g., "show all Heisman winners")
- Facilitates historical analysis without scanning all players

#### Player-Level References (Minimal)

Players only store **lightweight references** to awards they won:

```gdscript
player["awards"] = {
    "college": {
        "heisman_finalist": [2024],  # Years when finalist
        "all_american": {
            2024: "first",   # team level
            2023: "second"
        },
        "conference_awards": {
            2024: ["offensive_poy"]
        }
    }
}
```

**Rationale:**
- Minimal data duplication
- Easy to check if a player has specific awards
- Detailed data lives in world_state, not duplicated per player
- Follows pattern used by NFL awards (players reference awards, full data elsewhere)

#### Computed Fields (On-Demand)

These are **NOT** stored but computed when needed:

```gdscript
# Computed by CollegeAwardsService when evaluating draft prospects
{
    "hype_vs_talent_gap": float,  # Difference between mock rank and actual talent
    "overhyped": bool,             # Mock rank > actual talent
    "underhyped": bool,            # Mock rank < actual talent
    "consensus_ranking": int       # Average mock draft position
}
```

**Rationale:**
- Avoids stale data (recomputed fresh for each draft)
- Reduces storage footprint
- Makes relationship between hype and talent explicit
- Easy to modify calculation without data migration

### System Architecture

#### CollegeAwardsService.gd

**Purpose:** Pure functional service for college award selection and mock draft generation

**Key Principles:**
- Static functions only (no state)
- No RNG (deterministic based on stats and configuration)
- Thread-safe (pure functions)
- Follows AwardSelector.gd pattern

**Public API:**

```gdscript
class_name CollegeAwardsService

# Award Selection
static func select_heisman_winner(world_state: Dictionary, year: int, config: Dictionary) -> Dictionary
static func select_heisman_finalists(world_state: Dictionary, year: int, config: Dictionary) -> Array
static func select_all_americans(world_state: Dictionary, year: int, config: Dictionary) -> Dictionary
static func select_conference_awards(world_state: Dictionary, year: int, config: Dictionary) -> Dictionary

# Mock Draft Generation
static func generate_mock_draft_rankings(
    draft_pool: Array,
    config: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary

# Analysis
static func calculate_hype_vs_talent_gap(
    player: Dictionary,
    mock_rankings: Dictionary,
    positions_cfg: Dictionary,
    main_cfg: Dictionary
) -> float

# Batch operations (optimization)
static func select_all_college_awards(world_state: Dictionary, year: int, config: Dictionary) -> Dictionary
```

**Design Decisions:**

1. **Separate Heisman vs All-American**
   - Heisman is QB/RB/WR focused, different selection criteria
   - All-American covers all positions like NFL All-Pro
   - Prevents mixing selection logic

2. **RNG Only for Mock Drafts**
   - Award selections are deterministic (based on stats)
   - Mock drafts have intentional noise/bias (requires RNG)
   - Clear separation of deterministic vs stochastic operations

3. **Batch Operations**
   - `select_all_college_awards()` runs all selections in one call
   - Reduces redundant data access
   - Matches AwardSelector.select_all_awards() pattern

#### Configuration: college_awards.json

```json
{
    "version": 1,
    "description": "College awards and media mock draft configuration",

    "heisman": {
        "eligible_positions": ["QB", "RB", "WR"],
        "finalist_count": 4,
        "min_games_played": 10,
        "voting_weights": {
            "stats_production": 0.40,
            "efficiency_metrics": 0.25,
            "team_success": 0.20,
            "hype": 0.15
        },
        "position_bias": {
            "QB": 1.0,
            "RB": 0.85,
            "WR": 0.80
        }
    },

    "all_american": {
        "teams": ["first", "second", "third"],
        "positions": {
            "QB": 1,
            "RB": 2,
            "WR": 3,
            "TE": 2,
            "OL": 5,
            "DL": 4,
            "EDGE": 2,
            "LB": 3,
            "CB": 2,
            "S": 2
        },
        "min_games_started": 8
    },

    "conference_awards": {
        "awards": [
            "offensive_poy",
            "defensive_poy"
        ],
        "voting_weights": {
            "stats_production": 0.50,
            "efficiency_metrics": 0.30,
            "team_contribution": 0.20
        }
    },

    "mock_draft": {
        "sources": ["espn", "nfl_network", "pff"],
        "top_n_players": 100,
        "noise_sigma": 15.0,
        "hype_susceptibility_by_source": {
            "espn": 0.70,
            "nfl_network": 0.50,
            "pff": 0.30
        },
        "source_bias": {
            "espn": {
                "description": "Entertainment-focused, high hype susceptibility",
                "big_school_bias": 1.15,
                "flashy_positions": ["QB", "RB", "WR"]
            },
            "nfl_network": {
                "description": "Balanced analysis with moderate hype influence",
                "big_school_bias": 1.05,
                "flashy_positions": []
            },
            "pff": {
                "description": "Analytics-focused, low hype susceptibility",
                "big_school_bias": 1.0,
                "flashy_positions": []
            }
        }
    }
}
```

**Configuration Design Rationale:**

1. **Versioning:** Enables future migration of config format
2. **Weighted Voting:** Configurable balance between stats, team success, and hype
3. **Position Bias:** Reflects reality (QBs dominate Heisman)
4. **Source-Specific Mock Draft Behavior:** Different media outlets have different biases
5. **Noise Parameters:** Tunable randomness in mock draft rankings

### Integration Points

#### 1. CollegeSeason.gd Integration

**Location:** After `_update_college_stat_analysis()` (line 177)

```gdscript
# PHASE 6: Select college awards after season completion
# This generates Heisman finalists, All-Americans, and conference awards
# RNG: None (deterministic based on stats)
if options.get("enable_college_awards", true):
    _select_college_awards(world_state, year, config, positions_cfg, main_cfg)
```

**New Helper Function:**

```gdscript
func _select_college_awards(
    world_state: Dictionary,
    year: int,
    config: Dictionary,
    positions_cfg: Dictionary,
    main_cfg: Dictionary
) -> void:
    var awards_cfg: Dictionary = config.get("college_awards", {})
    var summary := CollegeAwardsService.select_all_college_awards(
        world_state,
        year,
        awards_cfg
    )

    # Apply hype events for award winners
    if options.get("enable_hype_events", true):
        _apply_award_hype_events(world_state, year, summary, config)
```

**Rationale:**
- Minimal modification to CollegeSeason.gd
- Feature flag for easy disabling during testing
- Follows existing pattern (like `enable_stat_analysis`)

#### 2. HypeGenerator.gd Integration

**Status:** No modification required

**Existing Event Types Already Support College Awards:**
- `"heisman_finalist"`: +15-25 hype (line 88)
- `"conference_poy"`: +8-12 hype (line 90)
- `"bowl_mvp"`: +10-18 hype (line 92)

**New Event Types Needed:**
```gdscript
"heisman_winner": rng.randf_range(25.0, 35.0),
"all_american_first": rng.randf_range(12.0, 18.0),
"all_american_second": rng.randf_range(6.0, 12.0),
"all_american_third": rng.randf_range(3.0, 8.0)
```

**Integration Pattern:**

```gdscript
# In CollegeSeason._apply_award_hype_events()
var hype_rng := RandomNumberGenerator.new()
hype_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E6)

for player_id in award_winners:
    var player: Dictionary = _find_player_in_draft_pool(world_state, year, player_id)
    if player.is_empty():
        continue

    var current_hype := float(player.get("hype", 50.0))
    var award_type := String(award_winners[player_id])
    var new_hype := HypeGenerator.apply_hype_event(current_hype, award_type, hype_rng)
    player["hype"] = new_hype
```

#### 3. NflDraft.gd Integration

**Location:** In `_score_draft_pool()` function

**Purpose:** Use `hype_vs_talent_gap` to influence team perception

**Implementation:**

```gdscript
# Add after line 156 (within _score_draft_pool loop)
var hype_adjustment := _calculate_hype_draft_adjustment(
    player,
    world_state,
    year,
    team_id,
    team_quality
)
final_score *= hype_adjustment
```

**New Helper Function:**

```gdscript
func _calculate_hype_draft_adjustment(
    player: Dictionary,
    world_state: Dictionary,
    year: int,
    team_id: String,
    team_quality: Dictionary
) -> float:
    var mock_drafts: Dictionary = world_state.get("mock_drafts", {}).get(year, {})
    if mock_drafts.is_empty():
        return 1.0  # No adjustment if no mock drafts

    var hype_gap := CollegeAwardsService.calculate_hype_vs_talent_gap(
        player,
        mock_drafts,
        positions_cfg,
        main_cfg
    )

    # Teams with poor scouting are more susceptible to hype
    var scouting_quality := float(team_quality.get(team_id, 0.5))
    var hype_susceptibility := 1.0 - scouting_quality  # 0.0-1.0

    # Overhyped players get boost for bad scouting teams
    # Underhyped players get penalty for bad scouting teams
    var adjustment := 1.0 + (hype_gap * hype_susceptibility * 0.15)
    return clamp(adjustment, 0.85, 1.15)  # ±15% max adjustment
```

**Rationale:**
- Poor scouting teams are more influenced by media hype
- Good scouting teams see through hype to true talent
- Adjustment is bounded to prevent extreme distortion

### Performance Analysis

**Computational Complexity:**

1. **Heisman Selection:** O(n log n) where n = QB/RB/WR pool (~150 players)
2. **All-American Selection:** O(n log n) per position, ~10 positions = O(10n log n)
3. **Conference Awards:** O(n log n) per conference, ~10 conferences = O(10n log n)
4. **Mock Draft Generation:** O(n log n) where n = top 100 prospects, run 3 times for 3 sources

**Total:** O(n log n) dominated by sorting, where n ≈ 500 draft-eligible players

**Expected Runtime:** < 100ms per year (negligible compared to full season simulation)

**Memory Footprint:**
- World-level storage: ~50KB per year (awards + mock drafts)
- Player-level storage: ~50 bytes per player (award references only)
- Total: < 1MB for 20-year simulation

### Testing Strategy

**Unit Tests:**
1. Heisman selection produces exactly 1 winner + 4 finalists
2. All-American teams fill all positions correctly
3. Conference awards select one winner per category per conference
4. Mock draft rankings have appropriate noise/variance
5. Hype vs talent gap calculation is accurate

**Integration Tests:**
1. CollegeSeason calls award selection at correct time
2. Award winners receive hype events
3. Draft teams are influenced by mock draft hype
4. World state structures are correctly populated

**Regression Tests:**
1. Existing tests continue to pass (no breaking changes)
2. Award selection is deterministic given same stats

### Migration and Versioning

**Version 1 (Initial Release):**
- Basic Heisman, All-American, conference awards
- Simple mock draft with noise

**Future Extensions (Not in Scope):**
- Weekly honors (if needed for UI)
- Position-specific awards (Biletnikoff, Outland Trophy, etc.)
- Regional bias in mock drafts
- Historical award tracking (HOF credentials)

**Data Migration:**
- Config versioning enables future changes
- World state structures are additive (won't break old saves)
- Player award references use arrays (can add new award types)

## Recommendations

### Must Have (Phase 6 Requirements)
1. ✅ Implement CollegeAwardsService.gd with core award selection
2. ✅ Create college_awards.json configuration
3. ✅ Integrate with CollegeSeason.gd
4. ✅ Add hype events for award winners
5. ✅ Use hype gap in NflDraft.gd evaluation

### Should Have (Enhances Phase 6)
1. Add mock draft consensus ranking to UI
2. Track historical Heisman winners for legacy queries
3. Log award selections in debug mode

### Nice to Have (Future Phases)
1. Position-specific awards (Biletnikoff, Outland, etc.)
2. Weekly honors tracking
3. Award prediction system (pre-season favorites)

### Must Not Have (Out of Scope)
1. Individual voter simulation (too complex)
2. Regional bias in award voting (premature)
3. Award ceremony events (no UI requirements)

## Decision Record

**Status:** APPROVED WITH MODIFICATIONS

**Key Changes from Original Proposal:**
1. ❌ Rejected: Nested year keys in player dictionaries
2. ✅ Approved: World-level storage following NFL awards pattern
3. ❌ Rejected: Redundant hype field in player data
4. ✅ Approved: Computed hype_vs_talent_gap on-demand
5. ❌ Rejected: weekly_honors and bowl_mvp (scope creep)
6. ✅ Approved: Source-specific mock draft biases

**Rationale:**
The modified architecture maintains consistency with existing patterns, reduces data redundancy, and provides clear separation of concerns. It's maintainable, testable, and extensible for future requirements.

---

**Architecture Guardian Sign-Off**
- Date: 2026-01-13
- Branch: team-gamma/architect
- Phase: 6 - College Awards & Media Hype
- Status: Ready for Implementation
