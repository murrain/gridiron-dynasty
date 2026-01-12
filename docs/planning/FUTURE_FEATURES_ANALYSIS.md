# Future Features Analysis - Beyond Bootstrap Scope

**Document Version**: 1.0
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

## Category 3: Advanced AI for Opponent Teams

### Strategic Importance: HIGH
User's experience is defined by opponent behavior. Realistic AI creates challenge and immersion.

### Why Outside Bootstrap Scope
Bootstrap uses simple rule-based AI (best available player, cap compliance). Dynasty mode needs:
- Strategic variety (rebuilding vs contending)
- Personality-driven decisions
- Adaptive behavior based on user actions
- Realistic trade negotiations

### Features Required

#### 3.1 Team Strategy Profiles
**Description**: Each team has strategy (win-now, rebuild, balanced)
**Importance**: MUST-HAVE - Creates variety in opponent behavior
**Architectural Foundation Needed NOW**:
```gdscript
# Add to team metadata
world_state["nfl_teams"][i]["strategy"] = {
    "type": "rebuild",  # "win_now", "balanced", "rebuild"
    "window_years_remaining": 3,  # How long strategy lasts
    "trade_aggressiveness": 0.7,  # 0-1, affects trade frequency
    "draft_preference": "BPA"  # "BPA", "need", "upside"
}

# AI uses strategy to make decisions
func should_ai_trade_pick(team: Dictionary, pick_value: float) -> bool:
    var strategy: Dictionary = team["strategy"]
    if strategy["type"] == "win_now":
        return pick_value < 500  # Trade away most picks for players
    elif strategy["type"] == "rebuild":
        return pick_value > 200  # Hoard picks
    return pick_value < 300  # Balanced approach
```

**Implementation Priority**: Phase 3 (Months 9-12)
**Estimated Complexity**: Medium (10 days)

#### 3.2 GM Personalities
**Description**: Each GM has traits affecting decisions (risk-averse, aggressive, etc.)
**Importance**: Important - Adds flavor and unpredictability
**Architectural Foundation Needed NOW**:
```gdscript
# GM personality traits
world_state["nfl_teams"][i]["gm"] = {
    "id": "gm_123",
    "name": "John Smith",
    "traits": ["Risk-Averse", "Values Loyalty", "Analytics-Driven"],
    "risk_tolerance": 0.3,  # 0-1, affects trade/FA decisions
    "loyalty_factor": 0.8,   # Higher = keeps players longer
    "draft_accuracy": 0.7    # How often they pick correctly
}
```

**Implementation Priority**: Phase 3 (Months 9-12)
**Estimated Complexity**: Medium (8 days)

#### 3.3 Adaptive AI (Learns from User)
**Description**: AI adjusts strategy based on user's play style
**Importance**: Nice-to-have - Advanced feature for replayability
**Architectural Foundation Needed NOW**:
```gdscript
# Track user tendencies
user_context["play_style_analysis"] = {
    "avg_draft_position_preference": "BPA",  # vs "need"
    "trade_frequency": 0.6,  # Trades per season
    "fa_spending": "aggressive",  # vs "conservative"
    "position_value": {"QB": 1.5, "RB": 0.8}  # Relative positional emphasis
}

# AI uses analysis to counter user strategies
func get_ai_draft_strategy(team: Dictionary, user_analysis: Dictionary) -> String:
    if user_analysis["position_value"]["QB"] > 1.3:
        # User values QBs highly, AI should too to compete
        return "prioritize_qb"
```

**Implementation Priority**: Phase 4+ (Polish feature)
**Estimated Complexity**: Large (20 days)

### Architectural Foundations to Lay NOW
1. **Team strategy field** in team metadata
2. **GM personality system** - Traits and decision weights
3. **Decision logging** - Track AI choices for debugging/analysis
4. **Strategy evaluation hooks** - Recalculate team strategy each offseason

---

## Category 4: Trade and Free Agency Negotiation

### Strategic Importance: HIGH
Trades and free agency define team-building in dynasty mode. User must be able to negotiate and execute deals.

### Why Outside Bootstrap Scope
Bootstrap has passive trade/FA systems (teams just sign best available). Dynasty mode needs:
- User-initiated trade proposals
- Multi-party negotiations
- Realistic AI acceptance logic
- Contract negotiation with players

### Features Required

#### 4.1 User-Initiated Trades
**Description**: User proposes trades, AI accepts/rejects/counters
**Importance**: MUST-HAVE - Core roster management tool
**Architectural Foundation Needed NOW**:
```gdscript
# Trade proposal UI hooks
class_name TradeProposal
var offering_team_id: String
var receiving_team_id: String
var offered_players: Array  # [player_id]
var offered_picks: Array    # [DraftPick]
var requested_players: Array
var requested_picks: Array

func evaluate_for_ai(world_state: Dictionary) -> Dictionary:
    # Returns {"accepted": bool, "counter_offer": TradeProposal}
    var offered_value := TradeValuation.calculate_package_value(
        offered_players, offered_picks, world_state
    )
    var requested_value := TradeValuation.calculate_package_value(
        requested_players, requested_picks, world_state
    )

    var receiving_team: Dictionary = _get_team(receiving_team_id, world_state)
    var fairness := offered_value / requested_value  # 1.0 = fair

    # AI acceptance based on fairness + team needs + strategy
    var accept_threshold := _get_ai_acceptance_threshold(receiving_team)
    if fairness >= accept_threshold:
        return {"accepted": true}
    elif fairness >= accept_threshold * 0.8:
        # Close enough to counter-offer
        return {
            "accepted": false,
            "counter_offer": _generate_counter_offer(self, world_state)
        }
    else:
        return {"accepted": false, "reason": "insufficient_value"}
```

**Implementation Priority**: Phase 3 (Months 9-12)
**Estimated Complexity**: Large (18 days)

#### 4.2 Trade Deadline Mechanics
**Description**: Trades allowed only during specific windows
**Importance**: Important - Realism and strategic timing
**Architectural Foundation Needed NOW**:
```gdscript
# Calendar phase restrictions
func is_trade_window_open(world_state: Dictionary) -> bool:
    var current_phase := world_state["calendar"]["current_phase"]
    var allowed_phases := ["offseason", "preseason", "regular_season"]
    return current_phase in allowed_phases

func days_until_trade_deadline(world_state: Dictionary) -> int:
    # NFL trade deadline ~Week 9
    # Returns days remaining or -1 if past deadline
```

**Implementation Priority**: Phase 3 (with trade system)
**Estimated Complexity**: Small (3 days)

#### 4.3 Contract Negotiations with Players
**Description**: Offer contracts to free agents, negotiate terms
**Importance**: MUST-HAVE - Key offseason activity
**Architectural Foundation Needed NOW**:
```gdscript
# Contract negotiation system
class_name ContractOffer
var team_id: String
var player_id: String
var years: int
var aav: int  # Average annual value
var guaranteed: int
var bonuses: Dictionary  # {type: amount}

func evaluate_for_player(player: Dictionary, world_state: Dictionary) -> Dictionary:
    var player_value := PlayerValuation.calculate_market_value(player, world_state)
    var offer_value := aav * years

    var other_offers := _get_competing_offers(player_id, world_state)
    var best_other := _find_best_offer(other_offers)

    # Player accepts if:
    # 1. Offer is >= market value
    # 2. Offer is competitive with other teams
    # 3. Player wants to play for this team (morale factor)

    var acceptance_chance := _calculate_acceptance_probability(
        offer_value, player_value, best_other, team_id, player
    )

    return {
        "accepted": randf() < acceptance_chance,
        "desired_aav": player_value / years,
        "competing_teams": other_offers.size()
    }
```

**Implementation Priority**: Phase 3 (Months 9-12)
**Estimated Complexity**: Large (15 days)

### Architectural Foundations to Lay NOW
1. **TradeProposal class** - Represent multi-party trade structure
2. **Trade evaluation hooks** - AI acceptance logic
3. **Contract negotiation flow** - Offer/counter-offer state machine
4. **Calendar phase gates** - Restrict actions to appropriate windows

---

## Category 5: Recruiting System Enhancement (College)

### Strategic Importance: MEDIUM (College mode only)
If game includes college dynasty, recruiting is THE defining activity.

### Why Outside Bootstrap Scope
Bootstrap has automated recruiting (AI colleges target best available). College dynasty needs:
- User allocates recruiting resources
- Relationship building with prospects
- Competitive recruiting against AI
- Visit scheduling and pitch customization

### Features Required

#### 5.1 Recruiting Board and Target Management
**Description**: User creates list of prospects to recruit
**Importance**: MUST-HAVE (for college mode)
**Architectural Foundation Needed NOW**:
```gdscript
# User's recruiting board
user_context["recruiting_board"] = {
    "targets": [
        {
            "player_id": "hs_player_123",
            "priority": "high",  # high/medium/low
            "interest_level": 0.6,  # 0-1, player's interest in school
            "competing_schools": ["college_042", "college_089"],
            "visits_scheduled": ["2025-10-15"],
            "notes": "Top QB prospect, values winning culture"
        }
    ],
    "points_remaining": 5000,  # Recruiting resource budget
    "visits_remaining": 25      # Official visit slots
}

func allocate_recruiting_points(player_id: String, points: int) -> bool:
    # User spends points to increase interest
    if user_context["recruiting_board"]["points_remaining"] < points:
        return false

    var target := _find_target(player_id)
    target["interest_level"] += points / 1000.0  # Example conversion
    user_context["recruiting_board"]["points_remaining"] -= points
    return true
```

**Implementation Priority**: Phase 3 (College dynasty implementation)
**Estimated Complexity**: Large (20 days)

#### 5.2 Official Visits and Campus Tours
**Description**: Schedule visits, boost interest through experiences
**Importance**: Important - Key recruiting mechanic
**Architectural Foundation Needed NOW**:
```gdscript
# Visit event system
func schedule_official_visit(player_id: String, date: String) -> bool:
    var target := _find_target(player_id)
    if target["visits_scheduled"].size() >= 5:
        return false  # NCAA limit

    target["visits_scheduled"].append(date)
    return true

func execute_visit(player_id: String, visit_date: String) -> Dictionary:
    var player: Dictionary = _get_player(player_id)
    var interest_boost := 0.0

    # Interest boost based on:
    # - Recent team success (game records from Phase 1)
    # - Facility quality
    # - Player position needs on depth chart
    # - Weather during visit (random factor for realism)

    interest_boost += _calculate_success_factor() * 0.1
    interest_boost += _calculate_need_factor() * 0.05
    interest_boost += randf_range(-0.05, 0.15)  # Visit experience variance

    var target := _find_target(player_id)
    target["interest_level"] = clamp(target["interest_level"] + interest_boost, 0.0, 1.0)

    return {
        "interest_change": interest_boost,
        "new_interest": target["interest_level"],
        "visit_quality": "good" if interest_boost > 0.1 else "average"
    }
```

**Implementation Priority**: Phase 3 (College dynasty)
**Estimated Complexity**: Medium (12 days)

### Architectural Foundations to Lay NOW
1. **Recruiting board structure** - Target list with metadata
2. **Point allocation system** - Resource budgeting
3. **Visit scheduling** - Calendar integration
4. **Interest calculation** - Multi-factor evaluation

---

## Category 6: Historical Records and Hall of Fame

### Strategic Importance: MEDIUM
Records and HOF provide long-term goals and context for achievements.

### Why Outside Bootstrap Scope
Bootstrap generates stats (Phase 1), but doesn't analyze them for:
- All-time record tracking
- Hall of Fame eligibility
- Career comparisons across eras

### Features Required

#### 6.1 All-Time Records Tracking
**Description**: Track single-season and career records across all years
**Importance**: Important - Context for achievements
**Architectural Foundation Needed NOW**:
```gdscript
# Records tracking system
world_state["all_time_records"] = {
    "career": {
        "pass_yards": {"player_id": "player_123", "value": 75000, "years": "2025-2039"},
        "rush_yards": {"player_id": "player_456", "value": 18000, "years": "2027-2036"}
    },
    "single_season": {
        "pass_yards": {"player_id": "player_789", "value": 5500, "year": 2031},
        "pass_tds": {"player_id": "player_789", "value": 55, "year": 2031}
    },
    "single_game": {
        "pass_yards": {"player_id": "player_234", "value": 550, "date": "2029-11-15"}
    }
}

# Update records after each season
func update_records(world_state: Dictionary, year: int) -> void:
    var player_stats: Dictionary = world_state["player_career_stats"]

    for player_id in player_stats.keys():
        var season_stats: Dictionary = player_stats[player_id].get(year, {})

        # Check single-season records
        for stat_name in season_stats.keys():
            var value: int = season_stats[stat_name]
            var record_key := "single_season/%s" % stat_name

            if _is_new_record(value, record_key, world_state):
                _set_record(record_key, player_id, value, year, world_state)
```

**Implementation Priority**: Phase 2-3 (After stats system stable)
**Estimated Complexity**: Medium (8 days)

#### 6.2 Hall of Fame Voting
**Description**: Retired players eligible for HOF based on career stats/awards
**Importance**: Important - Ultimate player recognition
**Architectural Foundation Needed NOW**:
```gdscript
# HOF eligibility and voting
func evaluate_hof_candidate(player: Dictionary, world_state: Dictionary) -> Dictionary:
    var years_retired := world_state["current_year"] - player["retirement_year"]
    if years_retired < 5:
        return {"eligible": false, "reason": "not_enough_years"}

    var hof_score := 0.0

    # Career stats (from Phase 1 stat system)
    var career_stats := _sum_career_stats(player["id"], world_state)
    hof_score += career_stats["pass_yards"] / 1000.0  # 75000 yards = 75 points

    # Awards (from Phase 1 award system)
    var awards := _count_player_awards(player["id"], world_state)
    hof_score += awards["mvp"] * 50.0
    hof_score += awards["all_pro_1st"] * 15.0
    hof_score += awards["pro_bowl"] * 3.0

    # Championships
    hof_score += awards["super_bowls"] * 30.0

    # Longevity
    var years_played := player["retirement_year"] - player["draft_year"]
    hof_score += years_played * 2.0

    var hof_threshold := 250.0  # Calibrate based on testing

    return {
        "eligible": true,
        "score": hof_score,
        "inducted": hof_score >= hof_threshold,
        "threshold": hof_threshold
    }

# Annual HOF induction ceremony
func induct_hof_class(world_state: Dictionary, year: int) -> Array:
    var candidates := _get_hof_eligible_players(world_state, year)
    var inducted := []

    for candidate in candidates:
        var evaluation := evaluate_hof_candidate(candidate, world_state)
        if evaluation["inducted"]:
            inducted.append(candidate)
            _add_to_hof(candidate["id"], year, world_state)

    return inducted  # For UI display
```

**Implementation Priority**: Phase 3 (Months 12+)
**Estimated Complexity**: Large (15 days)

### Architectural Foundations to Lay NOW
1. **Records tracking** - Incremental update hooks
2. **HOF scoring system** - Multi-factor evaluation
3. **Ceremony events** - Annual induction timeline

---

## Category 7: User Customization and Modding

### Strategic Importance: MEDIUM
Customization extends game longevity and community engagement.

### Why Outside Bootstrap Scope
Bootstrap is data-driven (configs define everything), but lacks:
- User-friendly editing tools
- Mod loading/priority system
- Script extension points
- Custom content validation

### Features Required

#### 7.1 Team/Player Editor
**Description**: UI to edit team names, colors, player attributes
**Importance**: Important - Personalization and "what-if" scenarios
**Architectural Foundation Needed NOW**:
```gdscript
# Editor safety system (prevent breaking simulation)
class_name EntityEditor

func edit_team(team_id: String, changes: Dictionary) -> Error:
    var team: Dictionary = _get_team(team_id, world_state)

    # Whitelist safe fields
    var safe_fields := ["name", "city", "abbreviation", "colors", "logo_path"]

    for field in changes.keys():
        if field not in safe_fields:
            return ERR_INVALID_PARAMETER

        team[field] = changes[field]

    # Validation
    if not _validate_team(team):
        return ERR_INVALID_DATA

    return OK

func edit_player(player_id: String, changes: Dictionary) -> Error:
    # Similar safety checks + rating recalculation
    var player: Dictionary = _get_player(player_id, world_state)

    # Allow editing attributes but recalculate overall rating
    if "attributes" in changes:
        player["attributes"] = changes["attributes"]
        player["overall_rating"] = PlayerRatingCalculator.calculate_overall_rating(
            player, positions_cfg, class_rules
        )

    return OK
```

**Implementation Priority**: Phase 4+ (Post-launch enhancement)
**Estimated Complexity**: Large (20 days)

#### 7.2 Custom League/Roster Files
**Description**: Import/export rosters, create alternate universes
**Importance**: Important - Modding foundation
**Architectural Foundation Needed NOW**:
```gdscript
# Mod loading system
class_name ModLoader

func load_mod(mod_path: String) -> Dictionary:
    # Returns {"success": bool, "mod_data": Dictionary, "error": String}
    var mod_file := FileAccess.open(mod_path, FileAccess.READ)
    if mod_file == null:
        return {"success": false, "error": "file_not_found"}

    var json := JSON.new()
    json.parse(mod_file.get_as_text())
    var mod_data: Dictionary = json.data

    # Validate mod structure
    if not _validate_mod_schema(mod_data):
        return {"success": false, "error": "invalid_schema"}

    return {"success": true, "mod_data": mod_data}

func apply_mod(mod_data: Dictionary, world_state: Dictionary) -> void:
    # Override config values
    if mod_data.has("config_overrides"):
        _apply_config_overrides(mod_data["config_overrides"])

    # Replace teams/players
    if mod_data.has("teams"):
        world_state["nfl_teams"] = mod_data["teams"]

    # Add custom content
    if mod_data.has("custom_events"):
        world_state["custom_events"] = mod_data["custom_events"]
```

**Implementation Priority**: Phase 4+ (Mod support)
**Estimated Complexity**: Large (25 days)

#### 7.3 Script Modding API
**Description**: Expose GDScript hooks for community scripts
**Importance**: Nice-to-have - Advanced modding
**Architectural Foundation Needed NOW**:
```gdscript
# Mod hook system
signal before_draft(world_state: Dictionary, year: int)
signal after_free_agency(world_state: Dictionary, year: int)
signal player_retired(player: Dictionary, reason: String)

# Mods can connect to signals
func register_mod_scripts() -> void:
    var mod_dir := DirAccess.open("user://mods/")
    if mod_dir == null:
        return

    for script_path in _find_mod_scripts(mod_dir):
        var mod_script := load(script_path)
        if mod_script.has_method("_on_before_draft"):
            before_draft.connect(mod_script._on_before_draft)
```

**Implementation Priority**: Phase 4+ (Advanced feature)
**Estimated Complexity**: Large (30 days)

### Architectural Foundations to Lay NOW
1. **Entity validation** - Ensure edits don't break simulation
2. **Mod schema definition** - Standardized mod format
3. **Signal/hook system** - Extension points for mods
4. **Sandbox safety** - Prevent malicious mod code

---

## Category 8: Media, Storylines, and Narrative

### Strategic Importance: MEDIUM
Narrative layer makes simulation feel alive and provides context for events.

### Why Outside Bootstrap Scope
Bootstrap generates data but doesn't interpret it for:
- Storyline generation
- Media coverage simulation
- Player/team narratives

### Features Required

#### 8.1 Dynamic Storyline Generation
**Description**: Generate storylines from simulation events (upsets, rivalries, etc.)
**Importance**: Important - Immersion and context
**Architectural Foundation Needed NOW**:
```gdscript
# Event detection and storyline generation
class_name StorylineEngine

func generate_season_storylines(world_state: Dictionary, year: int) -> Array:
    var storylines := []

    # Detect upset victories (from Phase 1 game results)
    var upsets := _detect_upsets(world_state, year)
    for upset in upsets:
        storylines.append({
            "type": "upset",
            "title": "%s Stuns %s" % [upset["winner"], upset["loser"]],
            "description": _generate_upset_text(upset),
            "importance": "medium"
        })

    # Detect dynasty runs
    var dynasties := _detect_dynasties(world_state, year)
    for dynasty in dynasties:
        storylines.append({
            "type": "dynasty",
            "title": "%s Continue Dominance" % dynasty["team"],
            "description": "%d championships in %d years" % [dynasty["count"], dynasty["years"]],
            "importance": "high"
        })

    # Detect breakout players
    var breakouts := _detect_breakout_players(world_state, year)
    for player in breakouts:
        storylines.append({
            "type": "breakout",
            "title": "%s Emerges as Star" % player["name"],
            "description": _generate_breakout_text(player),
            "importance": "medium"
        })

    return storylines

func _detect_upsets(world_state: Dictionary, year: int) -> Array:
    var upsets := []
    var season_records: Dictionary = world_state["season_records"][year]

    # Find games where team with <30 wins beat team with >70 wins
    for team_id in season_records.keys():
        var record: Dictionary = season_records[team_id]
        # Implementation: parse game results to find upsets

    return upsets
```

**Implementation Priority**: Phase 3-4 (Polish feature)
**Estimated Complexity**: Medium (12 days)

#### 8.2 Power Rankings and Media Perception
**Description**: Weekly/monthly rankings with narrative explanations
**Importance**: Important - Context for team standings
**Architectural Foundation Needed NOW**:
Already planned in Phase 2 (M12.1 - Power Rankings)

#### 8.3 Player Personality and Drama
**Description**: Players have off-field storylines (holdouts, controversies, etc.)
**Importance**: Important - Adds unpredictability
**Architectural Foundation Needed NOW**:
Partially covered in Phase 1 (B8.5 - Retirement Decisions)
Expansion needed for additional drama types

### Architectural Foundations to Lay NOW
1. **Event detection hooks** - Identify noteworthy occurrences
2. **Template system** - Generate text from event data
3. **Storyline storage** - Persist narratives for UI display

---

## Category 9: Multiplayer and Online Leagues

### Strategic Importance: LOW-MEDIUM
Multiplayer extends longevity but requires significant infrastructure.

### Why Outside Bootstrap Scope
Bootstrap is single-player, deterministic simulation. Multiplayer needs:
- Server infrastructure
- Synchronization between clients
- Conflict resolution
- Cheating prevention

### Features Required

#### 9.1 Online Dynasty Leagues
**Description**: Multiple human players control different teams in same world
**Importance**: Nice-to-have - Extends engagement for competitive players
**Architectural Foundation Needed NOW**:
```gdscript
# Network layer abstraction
class_name OnlineLeague

var league_id: String
var participant_teams: Dictionary  # {user_id: team_id}
var current_phase: String
var waiting_for_users: Array  # User IDs not yet completed current phase

func advance_when_ready() -> bool:
    # All users must complete current phase before advancing
    return waiting_for_users.is_empty()

func submit_user_actions(user_id: String, actions: Dictionary) -> Error:
    # Actions: draft picks, trades, FA signings for current phase
    # Server validates and stores actions
    # When all users submitted, server advances simulation

    _validate_user_actions(user_id, actions)
    _store_user_actions(user_id, actions)
    waiting_for_users.erase(user_id)

    if advance_when_ready():
        _execute_phase_for_all_teams()

    return OK
```

**Implementation Priority**: Phase 4+ (Post-launch, if demand exists)
**Estimated Complexity**: Very Large (60+ days + infrastructure)

#### 9.2 Asynchronous Play
**Description**: Players take turns at their own pace
**Importance**: Important (if multiplayer implemented) - Respects schedules
**Architectural Foundation Needed NOW**:
- Action queue system
- Notification system for turn completion
- Deadline/timeout mechanics

**Implementation Priority**: Phase 4+
**Estimated Complexity**: Large (30 days)

### Architectural Foundations to Lay NOW
1. **Action validation** - Ensure user actions are legal
2. **Deterministic simulation** - ALREADY IN PLACE (critical for sync)
3. **Phase-based progression** - ALREADY IN PLACE (can pause between phases)

Recommendation: **DEFER multiplayer until single-player is polished.** Foundation is already compatible.

---

## Category 10: Advanced Statistics and Analytics

### Strategic Importance: MEDIUM
Analytics appeal to hardcore players and enable deeper strategy.

### Why Outside Bootstrap Scope
Phase 1 adds basic stats. Advanced analytics require:
- Complex calculations (PER, WAR, etc.)
- Historical comparisons
- Predictive modeling

### Features Required

#### 10.1 Advanced Metrics (PER, WAR, EPA)
**Description**: Sabermetric-style stats beyond basic counting stats
**Importance**: Nice-to-have - Appeals to stat-head audience
**Architectural Foundation Needed NOW**:
```gdscript
# Advanced stat calculations
class_name AdvancedStats

static func calculate_player_efficiency_rating(player_stats: Dictionary) -> float:
    # Weighted formula combining multiple stats
    var per := 0.0
    per += float(player_stats.get("points", 0)) * 1.0
    per += float(player_stats.get("assists", 0)) * 0.7
    per -= float(player_stats.get("turnovers", 0)) * 0.5
    # ... more complex formula
    return per

static func calculate_wins_above_replacement(player: Dictionary, world_state: Dictionary) -> float:
    # Compare player performance to "replacement level" player
    var player_stats := _get_season_stats(player["id"], world_state)
    var replacement_stats := _get_position_replacement_stats(player["position"], world_state)

    var war := (player_stats["value"] - replacement_stats["value"]) / replacement_stats["value"]
    return war * 10.0  # Scale to familiar WAR values
```

**Implementation Priority**: Phase 4+ (After basic stats stable)
**Estimated Complexity**: Large (20 days for research + implementation)

#### 10.2 Stat Leaderboards and Rankings
**Description**: Sort players by any stat category, filter by position/year
**Importance**: Important - Essential for stat exploration
**Architectural Foundation Needed NOW**:
Already planned in Phase 1 (S2.7 - Statistical Leaders)

#### 10.3 Predictive Analytics (Future Performance)
**Description**: Project player development, team success
**Importance**: Nice-to-have - "Moneyball" appeal
**Architectural Foundation Needed NOW**:
```gdscript
# Projection system
static func project_player_stats(player: Dictionary, years_ahead: int, world_state: Dictionary) -> Array:
    var projections := []

    for i in range(years_ahead):
        var future_age := player["age"] + i + 1
        var age_curve := _get_age_curve_multiplier(player["position"], future_age)

        var current_stats := _get_latest_stats(player["id"], world_state)
        var projected_stats := {}

        for stat_name in current_stats.keys():
            projected_stats[stat_name] = current_stats[stat_name] * age_curve

        projections.append({
            "year": world_state["current_year"] + i + 1,
            "age": future_age,
            "stats": projected_stats
        })

    return projections
```

**Implementation Priority**: Phase 4+ (Polish feature)
**Estimated Complexity**: Medium (10 days)

### Architectural Foundations to Lay NOW
1. **Stat calculation framework** - Plugin architecture for new metrics
2. **Historical stat storage** - ALREADY IN PLACE (Phase 1)
3. **Query/filter system** - Efficient stat lookups

---

## Category 11: Additional Game Modes

### Strategic Importance: LOW-MEDIUM
Alternate modes provide variety but require significant content creation.

### Why Outside Bootstrap Scope
Bootstrap creates one timeline. Alternate modes need:
- Different rule sets
- Specialized UI/UX
- Mode-specific content

### Features Required

#### 11.1 Historical Seasons Mode
**Description**: Play specific historical seasons with real rosters
**Importance**: Nice-to-have - Nostalgia appeal
**Architectural Foundation Needed NOW**:
- Historical roster data (licensing required)
- Era-specific rule sets
- "What-if" alternate history tracking

**Implementation Priority**: Phase 4+ (Content-heavy)
**Estimated Complexity**: Very Large (60+ days + content)

#### 11.2 Fantasy Draft Mode
**Description**: All teams redraft rosters from scratch
**Importance**: Nice-to-have - Fresh start appeal
**Architectural Foundation Needed NOW**:
```gdscript
# Fantasy draft system
func run_fantasy_draft(world_state: Dictionary) -> void:
    # Pool all players from all teams
    var player_pool := _collect_all_players(world_state)

    # Snake draft (reverse order each round)
    var draft_order := _randomize_teams(world_state)
    var rosters := {}

    for round in range(20):  # 20 rounds for ~53 roster spots
        if round % 2 == 1:
            draft_order.reverse()  # Snake pattern

        for team_id in draft_order:
            var pick := _ai_make_fantasy_pick(team_id, player_pool, rosters)
            rosters[team_id].append(pick)
            player_pool.erase(pick)

    # Replace world_state rosters with fantasy draft results
    _apply_fantasy_rosters(rosters, world_state)
```

**Implementation Priority**: Phase 4+
**Estimated Complexity**: Medium (8 days)

#### 11.3 Challenge Scenarios
**Description**: Specific scenario challenges (rebuild worst team in 3 years, etc.)
**Importance**: Nice-to-have - Achievement appeal
**Architectural Foundation Needed NOW**:
```gdscript
# Scenario/challenge system
class_name Challenge

var id: String
var title: String
var description: String
var starting_world_state: Dictionary  # Pre-configured scenario
var success_conditions: Array  # Win championship, make playoffs, etc.
var time_limit: int  # Years to complete

func check_success(world_state: Dictionary, user_context: UserContext) -> bool:
    for condition in success_conditions:
        if not _evaluate_condition(condition, world_state, user_context):
            return false
    return true
```

**Implementation Priority**: Phase 4+ (Content creation)
**Estimated Complexity**: Medium (10 days + scenario design)

### Architectural Foundations to Lay NOW
1. **World state snapshots** - Save/restore starting conditions
2. **Achievement system** - Already partially in place
3. **Scenario definition format** - Standardized challenge structure

---

## Category 12: UI/UX Enhancements

### Strategic Importance: MEDIUM
Good UI is essential for usability, but separate from core simulation.

### Why Outside Bootstrap Scope
Bootstrap is headless (runs in background). Dynasty mode needs:
- Interactive management screens
- Real-time updates
- Responsive controls

### Features Required

#### 12.1 Dashboard/Home Screen
**Description**: Central hub showing team status, upcoming events, notifications
**Importance**: MUST-HAVE - User orientation
**Architectural Foundation Needed NOW**:
```gdscript
# Dashboard data model
func get_dashboard_data(world_state: Dictionary, user_context: UserContext) -> Dictionary:
    var team_id := user_context.controlled_team_id
    var team: Dictionary = _get_team(team_id, world_state)
    var current_phase := world_state["calendar"]["current_phase"]

    return {
        "team": {
            "name": team["name"],
            "record": _get_current_season_record(team_id, world_state),
            "rank": _get_team_rank(team_id, world_state),
            "cap_space": _get_available_cap_space(team_id, world_state)
        },
        "next_event": {
            "type": "draft" if current_phase == "draft" else "game",
            "date": _get_next_event_date(world_state)
        },
        "notifications": _get_user_notifications(user_context),
        "roster_needs": _analyze_roster_needs(team_id, world_state)
    }
```

**Implementation Priority**: Phase 2 (With career mode)
**Estimated Complexity**: Large (15 days)

#### 12.2 Depth Chart Management
**Description**: Drag-and-drop roster organization, starter designation
**Importance**: MUST-HAVE - Core management tool
**Architectural Foundation Needed NOW**:
```gdscript
# Depth chart modification
func update_depth_chart(team_id: String, position: String, ordered_players: Array) -> Error:
    var team: Dictionary = _get_team(team_id, world_state)

    if not team.has("depth_chart"):
        team["depth_chart"] = {}

    team["depth_chart"][position] = ordered_players  # [player_id] in order

    return OK
```

**Implementation Priority**: Phase 2 (Core UI)
**Estimated Complexity**: Medium (10 days)

#### 12.3 Draft War Room
**Description**: Interactive draft board with scouting reports, trade tools
**Importance**: MUST-HAVE - Key offseason activity
**Architectural Foundation Needed NOW**:
Already partially covered by existing World Explorer draft panel
Enhancement needed for interactive picks

**Implementation Priority**: Phase 2-3
**Estimated Complexity**: Large (18 days)

### Architectural Foundations to Lay NOW
1. **Dashboard query layer** - Aggregate data for UI
2. **Notification system** - Event-driven alerts
3. **State management** - Reactive UI updates

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

## Risk Assessment

### High-Risk Areas

**1. Save/Load Reliability**
- **Risk**: Save corruption or incompatibility breaks user progress
- **Mitigation**:
  - Comprehensive versioning system
  - Automated save validation
  - Multiple backup save slots
  - Beta testing with real users

**2. AI Decision Quality**
- **Risk**: AI makes nonsensical trades/signings, breaks immersion
- **Mitigation**:
  - Extensive testing with different team strategies
  - Configurable AI difficulty levels
  - User feedback integration period

**3. Performance with UI**
- **Risk**: Interactive UI slows down simulation
- **Mitigation**:
  - Maintain headless simulation core (already in place)
  - Async processing for long operations
  - UI data caching and incremental updates

**4. Scope Creep**
- **Risk**: Feature requests expand beyond manageable scope
- **Mitigation**:
  - Strict priority framework (must/should/nice-to-have)
  - User feedback-driven Phase 4+ roadmap
  - Modding API to allow community extensions

### Medium-Risk Areas

**1. Multiplayer Complexity**
- **Risk**: Online mode is technically complex and maintenance-heavy
- **Mitigation**: Defer until single-player polished, validate demand first

**2. Content Creation Burden**
- **Risk**: Historical rosters, scenarios require extensive content work
- **Mitigation**: Start with generated content, add curated content later

**3. Modding Support**
- **Risk**: Open modding API introduces bugs and support burden
- **Mitigation**: Start with safe config overrides, expand API incrementally

---

## Success Metrics

### Phase 2 Completion (Core Dynasty)
- [ ] User can play 20-season dynasty with one team
- [ ] Save/load works reliably across sessions
- [ ] User can make all key decisions (draft, trades, FA signings)
- [ ] AI opponents make reasonable roster decisions
- [ ] Dashboard provides clear status and next actions

### Phase 3 Completion (Depth)
- [ ] AI teams have varied strategies (rebuilding, contending, etc.)
- [ ] Historical records tracked and displayable
- [ ] Hall of Fame inducts deserving players
- [ ] Storylines generated for key events
- [ ] (If college mode) Recruiting competition feels realistic

### Phase 4+ Completion (Extensions)
- [ ] Users can customize teams/players safely
- [ ] Community can create and share mods
- [ ] Challenge scenarios provide replayability
- [ ] Advanced stats appeal to analytics-minded players
- [ ] (If implemented) Multiplayer leagues functional

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
