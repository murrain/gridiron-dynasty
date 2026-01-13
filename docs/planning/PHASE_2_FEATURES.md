# Phase 2 Features: Beyond Bootstrap Scope

**Document Version**: 1.1 (Renamed from FUTURE_FEATURES_ANALYSIS)
**Date**: 2026-01-12
**Author**: Architect 3 - Strategic Planning
**Purpose**: Identify and prioritize features for a complete dynasty game beyond initial bootstrap

---

## Executive Summary

**Current Scope**: The bootstrap_world system successfully generates a 20-year historical simulation with player lifecycles, rosters, contracts, recruiting, and draft mechanics. Phase 1 adds game outcomes, statistics, and awards.

**Gap Analysis**: While the foundation is strong, a true dynasty game requires interactive management, long-term progression systems, narrative generation, and user customization. This report identifies 12 strategic feature categories that transform the simulation from a "historical generator" into a "playable dynasty experience."

**Architectural Impact**: Most future features require minimal changes to the core simulation architecture. The key architectural foundations needed NOW are:
1. **Save/Load Infrastructure** - World state serialization and versioning
2. **User Context Layer** - Controlled team tracking and permissions
3. **Event System** - Notification and narrative generation hooks
4. **Modding API** - Configuration override and script extension points

---

## Understanding Current Scope

### Bootstrap_World Purpose
The bootstrap system generates a complete 20-year historical simulation:
- **Player Generation**: 10,288 players across 20 years (optimized from 40,000)
- **Player Lifecycle**: Development, aging, injuries, retirement
- **Roster Management**: High school → College → NFL progression
- **Contract System**: Salary cap compliance, free agency
- **Recruiting**: College targeting and commitments
- **Draft Mechanics**: Eligibility determination and selection

### Phase 1 Additions (Current Implementation)
18 "quick win" features adding:
- **Game Simulation**: Win/loss records, championships
- **Statistics**: Career totals, season stats
- **Awards**: MVP, All-Pro, Pro Bowl, ROTY
- **Historical Tracking**: Franchise records, dynasties, droughts

### What's Still Missing
The simulation generates history but lacks:
- **User Agency**: No player-controlled team management
- **Interactivity**: No decisions, no progression between seasons
- **Narrative**: No storylines, media coverage, or drama
- **Customization**: No team/player editing or mod support
- **Persistence**: No save/load between sessions

---

## Category 1: Multi-Season Dynasty Progression

### Strategic Importance: CRITICAL
A dynasty mode is fundamentally about managing one team across multiple seasons. This is THE core feature that defines the game type.

### Why Outside Bootstrap Scope
Bootstrap generates complete history in one pass. Dynasty mode requires:
- Stopping at each season for user decisions
- Tracking user-controlled team separately from AI teams
- Different UI/UX patterns (management vs simulation)
- Save points between seasons

### Features Required

#### 1.1 Season-by-Season Progression
**Description**: User advances one season at a time, making decisions between years
**Importance**: MUST-HAVE - Defines dynasty gameplay loop
**Architectural Foundation Needed NOW**:
```gdscript
# Create UserContext to track controlled team
class_name UserContext
var controlled_team_id: String
var current_season: int
var season_start_date: Dictionary  # For UI display
var achievements_unlocked: Array
var career_history: Dictionary  # For career mode progression

# Modify AdvanceWorldYear to support pause points
func run_to_offseason(world_state: Dictionary, year: int, user_context: UserContext) -> Dictionary:
    # Run up to but not through draft/recruiting decisions
    # Return control to user for management decisions
```

**Implementation Priority**: Phase 2 (Months 4-6)
**Estimated Complexity**: Large (20 days)

#### 1.2 Career Mode (User as Coach/GM)
**Description**: User controls one team, makes all personnel decisions
**Importance**: MUST-HAVE - Core gameplay mode
**Architectural Foundation Needed NOW**:
```gdscript
# Define user role and permissions
enum UserRole {
    HEAD_COACH,      # Roster, game planning
    GENERAL_MANAGER, # Contracts, trades, draft
    OWNER            # Everything + finances
}

# Permission system for UI decisions
func can_user_sign_player(user_context: UserContext) -> bool:
    return user_context.role in [UserRole.GENERAL_MANAGER, UserRole.OWNER]
```

**Implementation Priority**: Phase 2 (Months 4-6)
**Estimated Complexity**: Large (25 days)

#### 1.3 Multi-Team Dynasty (Switch Teams)
**Description**: User can leave current team and take another job
**Importance**: Nice-to-have - Extends career longevity
**Architectural Foundation Needed NOW**:
```gdscript
# Track user career across multiple teams
world_state["user_career_history"] = [
    {"year": 2025, "team_id": "nfl_001", "role": "HC", "record": {"wins": 12, "losses": 5}},
    {"year": 2027, "team_id": "college_042", "role": "HC", "record": {"wins": 10, "losses": 2}}
]
```

**Implementation Priority**: Phase 4+ (Optional enhancement)
**Estimated Complexity**: Medium (10 days)

#### 1.4 Retirement and Career Summary
**Description**: End career after X years, show legacy/achievements
**Importance**: Important - Provides closure and replay incentive
**Architectural Foundation Needed NOW**:
```gdscript
# Track achievements for end-of-career summary
world_state["user_achievements"] = {
    "championships": 3,
    "playoff_appearances": 12,
    "all_time_wins": 187,
    "draft_steals": ["player_123", "player_456"],  # Late round stars
    "hall_of_famers_coached": ["player_789"]
}
```

**Implementation Priority**: Phase 3 (Months 12+)
**Estimated Complexity**: Medium (8 days)

### Architectural Foundations to Lay NOW
1. **UserContext class** - Track controlled team, role, permissions
2. **Pause point hooks** in AdvanceWorldYear - Stop at decision points
3. **Achievement tracking** - Hook into world events (championships, milestones)
4. **Career history storage** - Persistent across team changes

---

## Category 2: Save/Load and Persistence

### Strategic Importance: CRITICAL
Without save/load, users lose progress on exit. This blocks any long-term engagement.

### Why Outside Bootstrap Scope
Bootstrap is designed to run in one session (75 seconds for 20 years). Dynasty mode needs:
- Save at any point in season cycle
- Resume from saved state with identical behavior
- Handle schema changes between versions
- Maintain determinism across save/load

### Features Required

#### 2.1 Save Game to Disk
**Description**: Serialize world_state and user_context to file
**Importance**: MUST-HAVE - Required for any multi-session play
**Architectural Foundation Needed NOW**:
```gdscript
# Save system with versioning
class_name SaveGame

const SAVE_VERSION = 1

func save_to_disk(world_state: Dictionary, user_context: UserContext, filepath: String) -> Error:
    var save_data := {
        "version": SAVE_VERSION,
        "timestamp": Time.get_unix_time_from_system(),
        "world_state": world_state,
        "user_context": user_context.to_dict(),
        "rng_state": Rand.get_state()  # For determinism
    }

    var file := FileAccess.open(filepath, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()

    # Use JSON for human-readability, could use binary for size
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()
    return OK

func load_from_disk(filepath: String) -> Dictionary:
    # Returns {"world_state": ..., "user_context": ..., "error": Error}
    var file := FileAccess.open(filepath, FileAccess.READ)
    if file == null:
        return {"error": FileAccess.get_open_error()}

    var content := file.get_as_text()
    file.close()

    var json := JSON.new()
    var error := json.parse(content)
    if error != OK:
        return {"error": error}

    var save_data: Dictionary = json.data

    # Version migration if needed
    if int(save_data.get("version", 0)) < SAVE_VERSION:
        save_data = _migrate_save_data(save_data)

    return {
        "world_state": save_data["world_state"],
        "user_context": UserContext.from_dict(save_data["user_context"]),
        "error": OK
    }
```

**Implementation Priority**: Phase 2 (IMMEDIATE after career mode)
**Estimated Complexity**: Medium (12 days)

#### 2.2 Autosave at Key Moments
**Description**: Auto-save at end of season, before draft, etc.
**Importance**: MUST-HAVE - Prevents user frustration from lost progress
**Architectural Foundation Needed NOW**:
```gdscript
# Hook system for autosave triggers
signal season_ended(year: int)
signal before_draft(year: int)
signal after_free_agency(year: int)

func _on_season_ended(year: int) -> void:
    if GameSettings.autosave_enabled:
        SaveGame.save_to_disk(world_state, user_context, "user://autosave.sav")
```

**Implementation Priority**: Phase 2 (with save/load)
**Estimated Complexity**: Small (3 days)

#### 2.3 Multiple Save Slots
**Description**: User can maintain separate dynasty saves
**Importance**: Important - Allows experimentation and multiple careers
**Architectural Foundation Needed NOW**:
```gdscript
# Save slot metadata for UI display
const SAVE_SLOTS = 10

func get_save_slot_info(slot: int) -> Dictionary:
    var filepath := "user://save_slot_%d.sav" % slot
    if not FileAccess.file_exists(filepath):
        return {"exists": false}

    # Quick metadata read without loading full world_state
    var file := FileAccess.open(filepath, FileAccess.READ)
    var json := JSON.new()
    json.parse(file.get_as_text())
    var data: Dictionary = json.data

    return {
        "exists": true,
        "team": data["user_context"]["controlled_team_id"],
        "season": data["world_state"]["current_year"],
        "record": data["user_context"]["current_season_record"],
        "timestamp": data["timestamp"]
    }
```

**Implementation Priority**: Phase 2 (with save/load)
**Estimated Complexity**: Small (4 days)

#### 2.4 Cloud Save Support
**Description**: Sync saves across devices via cloud service
**Importance**: Nice-to-have - Quality of life for multi-device users
**Architectural Foundation Needed NOW**:
- Abstract save backend (local disk vs cloud)
- Conflict resolution strategy
- Authentication system integration

**Implementation Priority**: Phase 4+ (Post-launch enhancement)
**Estimated Complexity**: Large (20 days + infrastructure)

### Architectural Foundations to Lay NOW
1. **SaveGame service class** - Serialize/deserialize with versioning
2. **Migration system** - Handle schema changes between versions
3. **RNG state capture** - Maintain determinism across save/load
4. **Metadata extraction** - Quick save slot preview without full load

---

## Prioritization Framework

### Must-Have (Phase 2-3) - Core Dynasty Experience
These features define dynasty gameplay and should be prioritized immediately after Phase 1:

1. **Season-by-Season Progression** - Can't have dynasty without this
2. **Career Mode (User as Coach/GM)** - Core gameplay loop
3. **Save/Load System** - Can't play multi-session without persistence
4. **Dashboard and Management UI** - User needs interface to make decisions
5. **User-Initiated Trades** - Essential team-building tool
6. **Contract Negotiations** - Offseason roster management

**Timeline**: Months 4-12 (Phase 2-3)
**Estimated Effort**: ~120 days of development

### Should-Have (Phase 3-4) - Depth and Replayability
Features that significantly improve experience but aren't blocking:

1. **Team Strategy Profiles** - AI variety
2. **Recruiting Board** (for college mode) - If college dynasty implemented
3. **Historical Records Tracking** - Context for achievements
4. **Hall of Fame System** - Ultimate recognition
5. **Storyline Generation** - Narrative immersion
6. **Advanced Stats** - Analytics appeal

**Timeline**: Months 12-18
**Estimated Effort**: ~100 days

### Nice-to-Have (Phase 4+) - Polish and Extensions
Features for long-term engagement after core experience solid:

1. **Multi-Team Dynasty** - Career progression
2. **Custom Leagues/Modding** - Community content
3. **Challenge Scenarios** - Achievement hunting
4. **Fantasy Draft Mode** - Alternate starts
5. **Predictive Analytics** - "Moneyball" features
6. **Online Multiplayer** - Competitive play

**Timeline**: Post-launch, driven by user feedback
**Estimated Effort**: ~200+ days (ongoing)

### Defer (Low ROI)
Features that require massive effort for minimal benefit:

1. **Multiplayer Infrastructure** (until single-player polished)
2. **Historical Seasons Mode** (licensing + content burden)
3. **Advanced Modding API** (small audience)

---

## Architectural Foundations to Implement NOW

These systems enable future features and should be built during Phase 1-2:

### 1. UserContext Layer (CRITICAL - Phase 2)
```gdscript
class_name UserContext
var controlled_team_id: String
var role: UserRole
var current_season: int
var career_history: Array
var achievements: Dictionary
var preferences: Dictionary

func save_to_dict() -> Dictionary
func load_from_dict(data: Dictionary) -> UserContext
```

**Why Now**: Every dynasty feature depends on knowing which team user controls
**Effort**: 3 days
**Blocks**: Career mode, save/load, all user interactions

### 2. Save/Load Infrastructure (CRITICAL - Phase 2)
```gdscript
class_name SaveGame
const SAVE_VERSION = 1

func save_to_disk(filepath: String) -> Error
func load_from_disk(filepath: String) -> Dictionary
func migrate_save_data(old_version: int, data: Dictionary) -> Dictionary
```

**Why Now**: Required for any multi-session play
**Effort**: 12 days
**Blocks**: Persistence, cloud sync, all long-term gameplay

### 3. Event/Notification System (Important - Phase 2)
```gdscript
# Signal-based event system
signal player_signed(team_id: String, player_id: String, contract: Dictionary)
signal player_traded(from_team: String, to_team: String, player_id: String)
signal draft_pick_made(team_id: String, player_id: String, pick_number: int)
signal championship_won(team_id: String, year: int)

# Notification queue for UI
class_name NotificationQueue
func add_notification(type: String, data: Dictionary) -> void
func get_unread_notifications(user_id: String) -> Array
```

**Why Now**: Enables storylines, achievements, UI responsiveness
**Effort**: 5 days
**Blocks**: Dashboard, storyline generation, achievement tracking

### 4. Mod/Config Override System (Nice-to-have - Phase 3)
```gdscript
class_name ModLoader
func load_mod(mod_path: String) -> Dictionary
func apply_config_overrides(overrides: Dictionary) -> void
func validate_mod_schema(mod_data: Dictionary) -> bool
```

**Why Now**: Easier to design now than retrofit later
**Effort**: 8 days
**Blocks**: Customization, community content, alternate leagues

---

## Implementation Roadmap

### Phase 2: Core Dynasty Features (Months 4-8)
**Goal**: Playable single-player dynasty mode

**Month 4-5: Foundation**
- User Context system (3 days)
- Save/Load infrastructure (12 days)
- Dashboard UI (15 days)

**Month 6-7: Interactivity**
- Season-by-season progression (20 days)
- Career mode framework (25 days)
- Depth chart management (10 days)

**Month 8: Offseason Management**
- User-initiated trades (18 days)
- Contract negotiations (15 days)
- Draft war room (18 days)

**Deliverable**: Complete dynasty mode with save/load, career tracking, and offseason decisions

### Phase 3: Depth and AI (Months 9-15)
**Goal**: Realistic opponent behavior and long-term goals

**Months 9-11: AI Enhancement**
- Team strategy profiles (10 days)
- GM personalities (8 days)
- Improved trade AI (15 days)

**Months 11-13: Historical Context**
- All-time records tracking (8 days)
- Hall of Fame system (15 days)
- Storyline generation (12 days)

**Months 13-15: College Dynasty (If Applicable)**
- Recruiting board (20 days)
- Official visits (12 days)
- Recruiting AI competition (10 days)

**Deliverable**: Rich dynasty experience with smart AI and historical context

### Phase 4: Extensions and Polish (Months 16+)
**Goal**: Long-term engagement features

**Ongoing Work:**
- Advanced statistics (20 days)
- Challenge scenarios (10 days + content)
- Modding support (25 days)
- Fantasy draft mode (8 days)
- Multi-team career (10 days)

**Deliverable**: Feature-complete dynasty game with high replay value

---

## Conclusion

### Current State
The bootstrap system creates a solid **historical simulation foundation**. Phase 1 adds game outcomes and statistics. This creates a complete "observer mode" where users can explore 20 years of football history.

### Gap to Dynasty Game
A true dynasty game requires **user agency, persistence, and progressive decision-making**. The 12 feature categories identified in this document transform the simulation from "historical generator" to "playable management game."

### Critical Path
The foundation for future features must be laid during Phase 2:
1. **UserContext** - Track which team user controls
2. **Save/Load** - Enable multi-session play
3. **Event System** - Hook for narratives and achievements
4. **Mod Support** - Allow community extensions

### Recommended Focus
**Phase 2 (Must-Have)**: Build core dynasty experience
- Season-by-season progression
- Career mode with management decisions
- Save/load system
- Interactive offseason (draft, trades, FA)

**Phase 3 (Should-Have)**: Add depth and variety
- Improved AI behavior
- Historical records and Hall of Fame
- Storyline generation
- Recruiting (if college mode)

**Phase 4+ (Nice-to-Have)**: Polish and extensions
- Advanced features based on user feedback
- Modding support
- Alternate game modes
- (Possibly) Multiplayer

### Architectural Impact
Most future features integrate cleanly with existing architecture:
- Simulation core remains deterministic and performant
- World state schema extensions are non-breaking
- UI and user interaction layer built on top of existing systems

The key insight: **Build the foundation (UserContext, Save/Load, Events) in Phase 2, and most future features become straightforward extensions rather than architectural overhauls.**

---

**Document Status**: Strategic Planning Complete
**Next Action**: Review with team, approve Phase 2 foundation work, begin implementation of UserContext and Save/Load systems
