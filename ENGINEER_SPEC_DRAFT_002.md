# ENGINEER SPECIFICATION: DRAFT-002 Underclassman Entry System
**Engineer ID:** team-delta/eng-2
**Workspace:** `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team-delta/eng-2/`
**Estimated Effort:** 8-10 hours
**Priority:** HIGH

---

## MISSION

Implement underclassman draft declaration system where college players decide whether to declare early for draft or return to school. System must dynamically adjust draft pool size (200-350 players) based on individual player decisions driven by draft projection and eligibility status.

---

## ARCHITECTURAL CONSTRAINTS

### 1. DERIVED PROPERTY PATTERN
`draft_eligible` must be computed, NOT stored independently:

**CORRECT:**
```gdscript
# Player.gd
func is_draft_eligible() -> bool:
    if stage != PlayerStage.COLLEGE:
        return stage == PlayerStage.DRAFT_ELIGIBLE

    # College player is eligible if senior OR declared early
    return years_remaining == 0 or declared_for_draft
```

**INCORRECT:**
```gdscript
@export var draft_eligible: bool = false  # ❌ NO! Creates dual source of truth
@export var years_remaining: int = 4      # ❌ Inconsistent with draft_eligible

# What if draft_eligible=true but years_remaining=3? Which is correct?
```

**Rationale:** Single source of truth prevents state inconsistency. Stage + years_remaining + declaration flag fully determine eligibility.

### 2. BACKWARD-COMPATIBLE MIGRATION
Old saves without `years_remaining` must load successfully:

**REQUIRED in Player.from_dict():**
```gdscript
func from_dict(d: Dictionary) -> void:
    # ... existing field loading ...

    # NEW: Eligibility fields with migration
    years_remaining = int(d.get("years_remaining", _infer_years_remaining(d)))
    declared_for_draft = bool(d.get("declared_for_draft", false))

func _infer_years_remaining(d: Dictionary) -> int:
    var player_age = int(d.get("age", 18))
    var inferred_stage = _infer_stage_from_fields(d)

    if inferred_stage == PlayerStage.COLLEGE:
        # Estimate: Freshmen ~18-19, Sophomores 20, Juniors 21, Seniors 22+
        return maxi(4 - (player_age - 18), 0)

    return 0  # Non-college players have no eligibility
```

**Validation:** Create test save without `years_remaining`, load, verify inference correct.

### 3. STATELESS SERVICE PATTERN
`DraftDecisionEngine` must be pure service:

**CORRECT:**
```gdscript
static func process_declarations(
    college_players: Array,  # All context passed as parameters
    year: int,
    seed: int,
    config: Dictionary,
    positions_cfg: Dictionary,
    class_rules: Dictionary
) -> Dictionary:
    # Pure function - no world_state access
    var rng := RandomNumberGenerator.new()
    rng.seed = Rand.splitmix64(seed ^ 0xDEC1A4E)
    # ... deterministic logic ...
```

**INCORRECT:**
```gdscript
var _world_state: Dictionary  # ❌ NO! Creates coupling

func process_declarations() -> void:
    var players = _world_state.get("college_players")  # ❌ Hidden dependency
```

### 4. CALENDAR PHASE INSERTION
New phase must shift all downstream phases:

**BEFORE:**
```json
{"id": "draft_prep", "start_tick": 7, "end_tick": 7},
{"id": "nfl_draft", "start_tick": 8, "end_tick": 8}
```

**AFTER:**
```json
{"id": "draft_declaration", "start_tick": 7, "end_tick": 7},
{"id": "draft_prep", "start_tick": 8, "end_tick": 8},
{"id": "nfl_draft", "start_tick": 9, "end_tick": 9}
```

**All phases >= tick 7 must increment by 1.**

---

## FILES TO CREATE

### 1. `scripts/world/DraftDecisionEngine.gd`
**Purpose:** Process underclassman draft declarations
**Class:** `RefCounted` (stateless service)
**Pattern:** Static methods receiving all context

**Required Public API:**
```gdscript
class_name DraftDecisionEngine
extends RefCounted

const Rand = preload("res://autoloads/Rand.gd")
const PlayerRatingCalculator = preload("res://scripts/core/rating/PlayerRatingCalculator.gd")

## Process draft declarations for all college players
## @param college_players: Array of college player dictionaries
## @param year: Current year
## @param seed: Base RNG seed for determinism
## @param config: Configuration with draft_declaration section
## @param positions_cfg: Position configuration for rating calculation
## @param class_rules: Class rules for rating calculation
## @return Dictionary: {declared_count, returning_count, declared_players, returning_players}
static func process_declarations(
    college_players: Array,
    year: int,
    seed: int,
    config: Dictionary,
    positions_cfg: Dictionary,
    class_rules: Dictionary
) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = Rand.splitmix64(seed ^ 0xDEC1A4E)

    var declared: Array = []
    var returning: Array = []

    for player in college_players:
        var p: Dictionary = player
        var years_left := int(p.get("years_remaining", 0))

        # Seniors auto-declare (no eligibility left)
        if years_left == 0:
            _declare_player(p, year)
            declared.append(p)
            continue

        # Underclassmen make decision
        var declare_prob := calculate_declaration_probability(
            p, positions_cfg, class_rules, config
        )

        if rng.randf() < declare_prob:
            _declare_player(p, year)
            declared.append(p)
        else:
            # Player returns to school - decrement eligibility
            p["years_remaining"] = years_left - 1
            returning.append(p)

    return {
        "year": year,
        "declared_count": declared.size(),
        "returning_count": returning.size(),
        "declared_players": declared,
        "returning_players": returning
    }

## Calculate probability of underclassman declaring for draft
## @param player: Player dictionary
## @param positions_cfg: Position configuration
## @param class_rules: Class rules
## @param config: Draft declaration configuration
## @return float: Probability 0.0-1.0
static func calculate_declaration_probability(
    player: Dictionary,
    positions_cfg: Dictionary,
    class_rules: Dictionary,
    config: Dictionary
) -> float:
    # Calculate draft projection (overall rating)
    var overall_rating := PlayerRatingCalculator.calculate_overall_rating(
        player, positions_cfg, class_rules
    )

    # Get probability curves from config
    var prob_cfg: Dictionary = config.get("draft_declaration", {}).get("probability_curves", {})

    # Base probability by draft grade
    # Elite (85+): 1st round projection = 90% declare
    # High (75-85): 2nd-3rd round projection = 65% declare
    # Mid (65-75): Day 3 projection = 35% declare
    # Low (<65): Undrafted projection = 15% declare
    var base_prob: float = 0.0

    if overall_rating >= float(prob_cfg.get("elite_threshold", 85.0)):
        base_prob = float(prob_cfg.get("elite_declare_rate", 0.90))
    elif overall_rating >= float(prob_cfg.get("high_threshold", 75.0)):
        base_prob = float(prob_cfg.get("high_declare_rate", 0.65))
    elif overall_rating >= float(prob_cfg.get("mid_threshold", 65.0)):
        base_prob = float(prob_cfg.get("mid_declare_rate", 0.35))
    else:
        base_prob = float(prob_cfg.get("low_declare_rate", 0.15))

    # Adjust by years remaining (earlier declaration = lower probability)
    var years_left := int(player.get("years_remaining", 4))
    var years_multiplier: float = 1.0

    if years_left == 1:  # Junior
        years_multiplier = 1.0  # Full probability
    elif years_left == 2:  # Sophomore
        years_multiplier = 0.7  # 30% less likely
    elif years_left >= 3:  # Freshman (rare)
        years_multiplier = 0.4  # 60% less likely

    var final_prob := clamp(base_prob * years_multiplier, 0.0, 1.0)

    return final_prob

## Declare player for draft (update state)
## @param player: Player dictionary (MODIFIED IN PLACE)
## @param year: Current year
static func _declare_player(player: Dictionary, year: int) -> void:
    player["declared_for_draft"] = true
    player["declaration_year"] = year
    # Do NOT modify stage here - WorldCalendar will transition stage in next phase
```

**Declaration Config (add to main config):**
```json
{
  "draft_declaration": {
    "probability_curves": {
      "elite_threshold": 85.0,
      "elite_declare_rate": 0.90,
      "high_threshold": 75.0,
      "high_declare_rate": 0.65,
      "mid_threshold": 65.0,
      "mid_declare_rate": 0.35,
      "low_declare_rate": 0.15
    },
    "years_remaining_modifiers": {
      "junior": 1.0,
      "sophomore": 0.7,
      "freshman": 0.4
    }
  }
}
```

---

## FILES TO MODIFY

### 1. `scripts/core/models/Player.gd`

**Changes Required:**

#### A. Add Eligibility Fields
```gdscript
# ADD after existing @export fields (around line 32)

## College eligibility tracking
## years_remaining: Eligibility years left (4 = freshman, 0 = senior/exhausted)
## declared_for_draft: Player explicitly declared for draft (early entry)
## declaration_year: Year player declared (for historical tracking)
@export var years_remaining: int = 4
@export var declared_for_draft: bool = false
@export var declaration_year: int = 0
```

#### B. Add Eligibility Methods
```gdscript
# ADD to "Player Stage Methods" section (around line 268)

## Check if player is draft eligible (derived property)
## Computed from stage + years_remaining + declared_for_draft
## NOT serialized independently - always calculated on demand
func is_draft_eligible() -> bool:
    # Non-college players: check stage directly
    if stage != PlayerStage.COLLEGE:
        return stage == PlayerStage.DRAFT_ELIGIBLE

    # College players: eligible if senior OR declared early
    return years_remaining == 0 or declared_for_draft

## Declare player for draft (transition to DRAFT_ELIGIBLE stage)
## Validates eligibility before declaration
## @return bool: true if declaration successful, false if ineligible
func declare_for_draft() -> bool:
    if not is_college_player():
        push_warning("Cannot declare: player not in college (stage: %s)" % PlayerStage.keys()[stage])
        return false

    if years_remaining < 0:
        push_error("Cannot declare: negative years_remaining (%d)" % years_remaining)
        return false

    # Mark as declared
    declared_for_draft = true

    # Transition stage
    if not transition_to(PlayerStage.DRAFT_ELIGIBLE):
        push_error("Failed to transition to DRAFT_ELIGIBLE stage")
        return false

    return true

## Advance eligibility (called at end of college season for returning players)
## Decrements years_remaining for players who don't declare
func advance_eligibility() -> void:
    if not is_college_player():
        return

    if declared_for_draft:
        return  # Already declared, no eligibility advance

    years_remaining -= 1

    # If exhausted eligibility, auto-declare
    if years_remaining <= 0:
        declare_for_draft()
```

#### C. Update from_dict() for Migration
```gdscript
# MODIFY existing from_dict() method (around line 88)

func from_dict(d: Dictionary) -> void:
    # ... existing field loading (keep all existing code) ...

    # ADD at end of method (after career loading):

    # NEW: Eligibility fields with backward-compatible migration
    years_remaining = int(d.get("years_remaining", _infer_years_remaining(d)))
    declared_for_draft = bool(d.get("declared_for_draft", false))
    declaration_year = int(d.get("declaration_year", 0))

# ADD new helper method at end of file
## Infer eligibility years from age/stage for legacy saves
## Used for backward compatibility when loading saves without years_remaining field
func _infer_years_remaining(d: Dictionary) -> int:
    var player_age = int(d.get("age", 18))
    var inferred_stage = _infer_stage_from_fields(d)

    if inferred_stage == PlayerStage.COLLEGE:
        # Estimate eligibility based on age
        # Typical: Freshman 18-19, Sophomore 20, Junior 21, Senior 22+
        var estimated_year := player_age - 18  # 0=freshman, 4=senior+
        var remaining := 4 - estimated_year
        return maxi(remaining, 0)  # Clamp to 0 (seniors/5th year)

    # Non-college players have no eligibility
    return 0
```

#### D. Update to_dict() to Serialize New Fields
```gdscript
# MODIFY existing to_dict() method (around line 219)

func to_dict() -> Dictionary:
    # ... existing serialization (keep all existing code) ...

    # ADD before return statement:
    result["years_remaining"] = years_remaining
    result["declared_for_draft"] = declared_for_draft
    result["declaration_year"] = declaration_year

    return result
```

#### E. Update Stage Transition Validation
```gdscript
# MODIFY existing transition_to() method (around line 272)

func transition_to(new_stage: PlayerStage) -> bool:
    var valid_transitions = {
        PlayerStage.HIGH_SCHOOL: [PlayerStage.COLLEGE],
        PlayerStage.COLLEGE: [PlayerStage.DRAFT_ELIGIBLE, PlayerStage.COLLEGE],  # Already correct
        PlayerStage.DRAFT_ELIGIBLE: [PlayerStage.NFL_ROOKIE, PlayerStage.NFL_FREE_AGENT],
        # ... rest unchanged ...
    }

    # ... existing validation logic unchanged ...
```

No changes needed to transition validation - COLLEGE → DRAFT_ELIGIBLE already allowed.

### 2. `scripts/world/WorldCalendar.gd`

**Changes Required:**

#### Add Draft Declaration Handler
```gdscript
# ADD new method (around line 100, after _validate_phase)

## Get handler method name for a phase
## Used by WorldController to execute phase logic
## @param phase_id: Phase identifier
## @return String: Handler method name, or empty if no handler
func get_phase_handler(phase_id: String) -> String:
    var handlers := {
        "draft_declaration": "_handle_draft_declaration",
        # ... existing handlers if any ...
    }

    return String(handlers.get(phase_id, ""))
```

**NOTE:** WorldCalendar is currently minimal (just phase definitions). Handler execution is in `WorldController` or `WorldSimulation` (not provided). If no handler system exists, declaration processing must be manually triggered in the main sim loop.

**Alternative Integration (if no handler system):**
```gdscript
# In WorldSimulation or WorldController (wherever phases are executed):

func _process_phase(phase: Dictionary, world_state: Dictionary) -> void:
    var phase_id := String(phase.get("id", ""))

    match phase_id:
        "draft_declaration":
            _handle_draft_declaration(world_state)
        "draft_prep":
            _handle_draft_prep(world_state)
        # ... other phases ...

func _handle_draft_declaration(world_state: Dictionary) -> void:
    # Get all college players
    var college_players := _get_college_players(world_state)

    # Process declarations
    var result := DraftDecisionEngine.process_declarations(
        college_players,
        world_state.get("current_year", 2025),
        world_state.get("seed", 12345),
        _config,
        _positions_cfg,
        _class_rules
    )

    # Update draft pool with declared players only
    var declared_players: Array = result.get("declared_players", [])
    var year := int(result.get("year", 0))

    if not world_state.has("draft_pool"):
        world_state["draft_pool"] = {}

    var draft_pool: Dictionary = world_state["draft_pool"]
    draft_pool[year] = declared_players

    # Log summary
    SimLogger.info("Draft Declarations: %d declared, %d returning to school" % [
        result.get("declared_count", 0),
        result.get("returning_count", 0)
    ])
```

### 3. `configs/sports/american_football/world/calendar.json`

**Changes Required:**

**BEFORE:**
```json
{
  "id": "college_season",
  "start_tick": 6,
  "end_tick": 6
},
{
  "id": "draft_prep",
  "start_tick": 7,
  "end_tick": 7
},
{
  "id": "nfl_draft",
  "start_tick": 8,
  "end_tick": 8
}
```

**AFTER:**
```json
{
  "id": "college_season",
  "start_tick": 6,
  "end_tick": 6,
  "tags": ["college"],
  "placeholder": false
},
{
  "id": "draft_declaration",
  "label": "Draft Declaration Window",
  "start_tick": 7,
  "end_tick": 7,
  "tags": ["college", "nfl"],
  "placeholder": false
},
{
  "id": "draft_prep",
  "label": "Draft prep",
  "start_tick": 8,
  "end_tick": 8,
  "tags": ["nfl"],
  "placeholder": false
},
{
  "id": "nfl_draft",
  "label": "NFL draft",
  "start_tick": 9,
  "end_tick": 9,
  "tags": ["nfl"],
  "placeholder": false
},
{
  "id": "roster_management",
  "label": "Roster management",
  "start_tick": 10,
  "end_tick": 10,
  "tags": ["nfl", "cap"],
  "placeholder": false
},
{
  "id": "nfl_free_agency",
  "label": "NFL free agency",
  "start_tick": 11,
  "end_tick": 11,
  "tags": ["nfl"],
  "placeholder": false
},
{
  "id": "cap_validation",
  "label": "Cap validation",
  "start_tick": 12,
  "end_tick": 12,
  "tags": ["nfl", "cap"],
  "placeholder": false
},
{
  "id": "nfl_season",
  "label": "NFL season",
  "start_tick": 13,
  "end_tick": 13,
  "tags": ["nfl"],
  "placeholder": false
}
```

**Summary:** All phases >= tick 7 increment by 1. Insert `draft_declaration` at tick 7.

### 4. `scripts/world/PreDraftProcess.gd`

**Changes Required:**

#### Add Defensive Filter for Declared Players
```gdscript
# MODIFY run() method (around line 66)

static func run(
    world_state: Dictionary,
    year: int,
    seed: int,
    config: Dictionary
) -> Dictionary:
    var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
    var draft_pool: Array = draft_pool_all.get(year, [])

    # NEW: Defensive filter - only process declared players
    # Primary filtering happens in DraftDecisionEngine, this is defensive
    draft_pool = draft_pool.filter(func(p):
        var player: Dictionary = p
        # Default true for backward compatibility (old saves have all seniors auto-entered)
        return bool(player.get("declared_for_draft", true))
    )

    if draft_pool.is_empty():
        return {
            "year": year,
            "combine_invites": 0,
            "pro_day_participants": 0,
            "all_star_participants": 0,
            "team_visits_scheduled": 0,
            "step_seeds": {}
        }

    # ... rest of method unchanged ...
```

**Rationale:** Ensures PreDraftProcess never operates on undeclared players. Defense-in-depth approach.

---

## TESTING REQUIREMENTS

### Unit Tests
Create: `scripts/tests/models/test_player_eligibility.gd`

**Test Coverage:**
```gdscript
func test_is_draft_eligible_senior():
    # College player with years_remaining=0 returns true

func test_is_draft_eligible_junior_declared():
    # College player with years_remaining=1, declared_for_draft=true returns true

func test_is_draft_eligible_junior_not_declared():
    # College player with years_remaining=1, declared_for_draft=false returns false

func test_declare_for_draft_transitions_stage():
    # Calling declare_for_draft() sets stage=DRAFT_ELIGIBLE

func test_advance_eligibility_decrements_years():
    # Junior (years=1) advances to senior (years=0)

func test_advance_eligibility_auto_declares_senior():
    # Senior (years=0) auto-declares when advanced

func test_from_dict_migrates_missing_years_remaining():
    # Load dict without years_remaining, verify inference from age

func test_to_dict_serializes_eligibility_fields():
    # Verify years_remaining, declared_for_draft in output
```

### Unit Tests
Create: `scripts/tests/world/test_draft_decision_engine.gd`

**Test Coverage:**
```gdscript
func test_process_declarations_seniors_auto_declare():
    # All seniors (years=0) appear in declared_players

func test_process_declarations_deterministic():
    # Same seed produces same declarations (10 iterations)

func test_calculate_declaration_probability_elite():
    # Player with 85+ rating has 90% probability (junior)

func test_calculate_declaration_probability_low():
    # Player with <65 rating has 15% probability (junior)

func test_calculate_declaration_probability_sophomore_penalty():
    # Sophomore (years=2) has 70% of junior probability

func test_declaration_updates_player_state():
    # Declared player has declared_for_draft=true, declaration_year set

func test_returning_player_decrements_eligibility():
    # Junior (years=1) who doesn't declare becomes senior (years=0)
```

### Integration Tests
Create: `scripts/tests/integration/test_draft_declaration_integration.gd`

**Test Coverage:**
```gdscript
func test_draft_pool_size_variance():
    # Run 10 seasons, verify draft pool varies 200-350 players

func test_pre_draft_process_filters_declared_only():
    # Undeclared juniors not in PreDraftProcess combine invites

func test_calendar_phase_ordering():
    # Verify draft_declaration runs before draft_prep

func test_save_load_eligibility_fields():
    # Save player with years_remaining, load, verify fields preserved

func test_legacy_save_migration():
    # Load save without years_remaining, verify inference works
```

### Determinism Tests
Create: `scripts/tests/determinism/test_draft_declaration_determinism.gd`

**Test Coverage:**
```gdscript
func test_declarations_same_seed():
    # Run process_declarations twice with seed 12345, identical results

func test_declarations_different_seeds():
    # Seed 12345 vs 54321 produce different but valid results

func test_full_season_with_declarations_deterministic():
    # Full season sim with declarations reproducible with same seed
```

---

## ACCEPTANCE CRITERIA

### Functional Requirements
- [ ] DraftDecisionEngine created with process_declarations and calculate_declaration_probability
- [ ] Player.gd has years_remaining, declared_for_draft, declaration_year fields
- [ ] Player.is_draft_eligible() is derived property (not serialized)
- [ ] Player.declare_for_draft() transitions stage correctly
- [ ] Player.advance_eligibility() decrements years_remaining
- [ ] from_dict() migrates missing years_remaining field
- [ ] WorldCalendar has draft_declaration phase at tick 7
- [ ] PreDraftProcess filters declared players
- [ ] Draft pool size varies 200-350 players per season
- [ ] All 8 Player unit tests passing
- [ ] All 7 DraftDecisionEngine unit tests passing
- [ ] All 5 integration tests passing
- [ ] All 3 determinism tests passing

### Architectural Requirements
- [ ] is_draft_eligible() is computed property (NOT @export field)
- [ ] DraftDecisionEngine is stateless (no world_state access)
- [ ] All RNG uses splitmix64 seed derivation
- [ ] Backward-compatible migration for old saves
- [ ] Calendar phases shifted correctly (all >=7 increment by 1)

### Code Quality Requirements
- [ ] All methods have docstring comments
- [ ] Probability calculation has inline comments explaining thresholds
- [ ] Error handling for invalid stage transitions
- [ ] Migration inference logic has comments explaining age estimation
- [ ] No magic numbers (use config for thresholds)

---

## REFERENCE FILES

**Must Read:**
- `/main/scripts/core/models/Player.gd` (modification target)
- `/main/scripts/world/WorldCalendar.gd` (phase insertion target)
- `/main/scripts/world/PreDraftProcess.gd` (filtering integration)
- `/main/configs/sports/american_football/world/calendar.json` (phase config)
- `/main/docs/architecture/IMPLEMENTATION_TICKETS.md` (Phase 5, DRAFT-002 section)
- `/workspaces/team-delta/architect/ARCHITECTURAL_ASSESSMENT.md` (this review)

**Patterns to Follow:**
- Derived properties: Compute on demand, never serialize independently
- Migration: `field = d.get("field", _infer_field(d))`
- Stage transitions: `transition_to(new_stage)` with validation
- Seed derivation: `Rand.splitmix64(seed ^ 0xCONSTANT)`

---

## DELIVERY CHECKLIST

Before requesting code review:
- [ ] All 4 files created/modified committed to git
- [ ] All 23 tests implemented and passing
- [ ] Manual testing: Season sim with declarations produces 200-350 player pool
- [ ] Manual testing: Elite junior declares, low-rated junior returns
- [ ] Manual testing: Load save without years_remaining, verify inference
- [ ] Determinism verified: Same seed produces identical declarations
- [ ] Migration tested: Load v1.0 save (pre-Phase-5) successfully
- [ ] Code self-reviewed for architectural violations
- [ ] Docstrings complete for all public methods
- [ ] No commented-out code or debug prints

---

## QUESTIONS FOR ARCHITECT

If blocked, ask architect:
1. "Should redshirt players (5th year seniors) be supported in Phase 1?"
2. "What happens if a player declares but draft doesn't happen (sim cancelled)?"
3. "Should withdrawal mechanism (declare then return to school) be in Phase 1?"
4. "How to handle graduate transfers (4 years elapsed but switch schools)?"

**Workspace Ready:** `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team-delta/eng-2/`
**Branch:** `team-delta/eng-2` (to be created)
**Merge Target:** `team-delta/architect` branch

---

**Specification Author:** Architecture Guardian
**Date:** 2026-01-16
**Version:** 1.0
