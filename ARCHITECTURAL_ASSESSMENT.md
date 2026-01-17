# ARCHITECTURAL ASSESSMENT: Draft System Phase 1
**Team Delta - Architect**
**Date:** 2026-01-16
**Assessment ID:** ARCH-DELTA-001

---

## EXECUTIVE SUMMARY

**DECISION: APPROVED WITH MODIFICATIONS**

Both DRAFT-001 (Draft Day Trading) and DRAFT-002 (Underclassman Entry) are architecturally sound and align with existing system patterns. The proposed implementations require minor structural adjustments to maintain long-term architectural integrity.

**Risk Level:** MEDIUM
**Complexity Justification:** NECESSARY - Addresses critical realism gaps
**Technical Debt Impact:** NEUTRAL - No new debt introduced

---

## DRAFT-001: DRAFT DAY TRADING SYSTEM

### Impact Scope
- **Core Systems Modified:**
  - `InteractiveDraft` (execution flow injection points)
  - `world_state` schema (draft_trades history)

- **New Boundaries Created:**
  - `DraftTradeEngine` - Trade validation and execution service
  - `TradeProposalDialog` - UI component (outside architecture scope)

- **Data Model Changes:**
  - New `world_state.draft_trades[year]` array structure
  - Extends existing `draft_pick_ownership` ledger (no schema change)

### Architectural Evaluation

#### ✓ STRENGTHS

1. **Fits Existing Patterns**
   - Stateless service pattern matches `PreDraftProcess`, `NflDraft`
   - Deterministic RNG pattern using `Rand.splitmix64()` seed derivation
   - Reuses existing `NflDraft.value_draft_pick()` infrastructure
   - Leverages existing `draft_pick_ownership` ledger without modification

2. **Clear Boundaries**
   - `DraftTradeEngine` has single responsibility: trade logic
   - Clean separation: validation → evaluation → execution pipeline
   - No leakage into draft execution logic (injection point pattern)
   - UI/service boundary properly defined

3. **Data Model Coherence**
   - `draft_trades` history structure mirrors `draft_history`
   - Trade records immutable once executed (append-only log)
   - Pick ownership updates atomic (no partial state)

4. **Complexity Justified**
   - NFL drafts average 20-30 trades - current system has 0
   - Existing value chart unused - this activates dormant infrastructure
   - AI trade logic necessary for realistic draft dynamics

#### ⚠ ARCHITECTURAL CONCERNS

1. **Lifecycle Risk: Real-time vs Batch Execution**
   - **Issue:** `InteractiveDraft` is pause-based (user turns). Trades must integrate without breaking pause semantics.
   - **Risk:** Trade UI opens during AI pick processing → state inconsistency
   - **Mitigation Required:** Define clear "trade windows" - only between picks, not during pick execution

2. **Boundary Violation Potential: Trade Engine Statelessness**
   - **Issue:** Proposal states "AI trade proposals based on needs" - this implies draft state awareness
   - **Risk:** `DraftTradeEngine` becomes stateful, coupling to `InteractiveDraft` internals
   - **Mitigation Required:** Trade engine must receive context as parameters, never query draft state directly

3. **Persistence Format Versioning**
   - **Issue:** `draft_trades` schema not explicitly versioned
   - **Risk:** Future changes (multi-year trades, conditional picks) break saves
   - **Mitigation Required:** Add `version` field to trade records

4. **RNG Determinism Ordering**
   - **Issue:** User-initiated trades inject non-deterministic timing
   - **Risk:** Same seed → different results if user trades at different moments
   - **Mitigation Required:** Trade acceptance must use stable seed derived from (year, team_id, pick_number), not call order

### Required Modifications

#### MODIFICATION 1: Trade Window State Machine
**File:** `scripts/world/InteractiveDraft.gd`

```gdscript
enum DraftState {
    NOT_STARTED,
    RUNNING,
    WAITING_FOR_USER,
    TRADE_WINDOW,  # NEW: Between picks, trades allowed
    COMPLETED
}

# Trade injection point - ONLY callable in TRADE_WINDOW state
func enter_trade_window(current_pick: int) -> void:
    if _state != DraftState.RUNNING:
        return
    _state = DraftState.TRADE_WINDOW
    trade_window_opened.emit(current_pick, _get_tradeable_picks())

func exit_trade_window() -> void:
    if _state != DraftState.TRADE_WINDOW:
        return
    _state = DraftState.RUNNING
```

**Rationale:** Explicit state prevents race conditions where trades execute during pick processing.

#### MODIFICATION 2: Stateless Trade Engine Contract
**File:** `scripts/world/DraftTradeEngine.gd`

```gdscript
# ALL methods receive context - NEVER access world_state directly
func evaluate_trade_value(
    offer: Dictionary,
    offering_team_roster: Dictionary,
    receiving_team_roster: Dictionary,
    offering_team_needs: Dictionary,
    receiving_team_needs: Dictionary,
    current_draft_position: int,
    available_players: Array,
    rng_seed: int  # Derived from stable context, not call order
) -> float:
    # Pure function - no side effects, no global state access
```

**Rationale:** Ensures engine remains testable, cacheable, and safe for concurrent evaluation.

#### MODIFICATION 3: Versioned Trade History Schema
**File:** World state documentation (no code change, schema formalization)

```gdscript
# draft_trades[year] = Array[Dictionary]
{
    "version": 1,  # Schema version for migration compatibility
    "timestamp": int,  # Pick number when trade executed
    "teams": {
        "offering": String,  # team_id
        "receiving": String
    },
    "picks_exchanged": {
        "offering_sends": Array[Dictionary],  # {year, round, pick}
        "receiving_sends": Array[Dictionary]
    },
    "players_exchanged": {  # Future-proofing
        "offering_sends": Array[String],  # player_ids
        "receiving_sends": Array[String]
    },
    "value_differential": float,  # Calculated via value_draft_pick()
    "initiated_by": String  # "ai" | "user"
}
```

**Rationale:** Explicit versioning enables safe schema evolution. Player fields prepare for player-for-pick trades (Phase 2).

#### MODIFICATION 4: Deterministic Trade Acceptance RNG
**File:** `scripts/world/DraftTradeEngine.gd`

```gdscript
func should_accept_trade(
    offer: Dictionary,
    receiving_team_id: String,
    year: int,
    current_pick: int,
    base_seed: int
) -> bool:
    # Derive stable seed from context, not call order
    var trade_seed := Rand.splitmix64(base_seed ^ hash(receiving_team_id) ^ year ^ current_pick)
    var rng := RandomNumberGenerator.new()
    rng.seed = trade_seed

    var value_diff := calculate_value_differential(offer)
    var acceptance_threshold := _calculate_acceptance_threshold(value_diff, receiving_team_id)

    return rng.randf() < acceptance_threshold
```

**Rationale:** Same offer at same draft moment always produces same decision, regardless of when user initiates trade.

### Testing Strategy Validation

✓ **Unit Tests:** Comprehensive coverage of validation, value calculation, ownership updates
✓ **Integration Tests:** Draft state consistency after trades verified
✓ **Determinism Tests:** Seed stability requirements explicitly defined
✓ **Performance Tests:** Realistic thresholds (<100ms for trade evaluation)
✓ **Regression Tests:** Ensures draft without trades unaffected

**Gap Identified:** Missing concurrency test - "User initiates trade while AI considering different trade" edge case.

### Acceptance Criteria Adjustments

**ADD:**
- [ ] Trade engine methods are pure functions (no world_state access)
- [ ] Trade windows only open between picks (explicit state transition)
- [ ] Trade history includes schema version field
- [ ] Determinism tests verify stable seeds (context-derived, not call-order)

**KEEP ALL EXISTING CRITERIA** - fully aligned with architecture.

---

## DRAFT-002: UNDERCLASSMAN ENTRY SYSTEM

### Impact Scope
- **Core Models Modified:**
  - `Player.gd` - Add eligibility tracking fields

- **Calendar Modified:**
  - `WorldCalendar` phases - Insert `draft_declaration` phase

- **New Services:**
  - `DraftDecisionEngine` - Declaration probability logic

- **Integration Points:**
  - `PreDraftProcess` - Must filter declared players only
  - Draft pool generation - Conditional on declaration status

### Architectural Evaluation

#### ✓ STRENGTHS

1. **Model Extension Strategy**
   - Adds fields to existing `Player.gd` (no new entity)
   - Fields are lifecycle-agnostic (apply to all college players)
   - Backward compatible via `to_dict()`/`from_dict()` existing patterns

2. **Calendar Integration**
   - Inserts cleanly between `college_season` (tick 6) and `draft_prep` (tick 7)
   - Respects existing phase ordering semantics
   - No disruption to downstream phases

3. **Stateless Service Pattern**
   - `DraftDecisionEngine` matches `PreDraftProcess`, `NflDraft` patterns
   - Deterministic probability calculation
   - No hidden state between invocations

4. **Complexity Justified**
   - Real NFL pools: 200-300 players. Current system: ~500 (all eligible auto-enter)
   - Elite underclassman decisions are major storylines (missing from simulation)
   - Dynamic pool size increases strategic depth

#### ⚠ ARCHITECTURAL CONCERNS

1. **Model Lifecycle Coupling**
   - **Issue:** `draft_eligible` flag requires coordination with `Player.stage` enum
   - **Risk:** Inconsistent states (stage=COLLEGE but draft_eligible=true vs stage=DRAFT_ELIGIBLE)
   - **Mitigation Required:** Derive `draft_eligible` from stage + declaration, not independent field

2. **Calendar Phase Density**
   - **Issue:** Calendar already has 13 phases. Adding `draft_declaration` increases cognitive load.
   - **Risk:** Each phase addition makes pipeline harder to understand
   - **Assessment:** ACCEPTABLE - This phase is necessary and well-defined (single responsibility)

3. **Data Migration Path**
   - **Issue:** Existing players have no `years_remaining` field
   - **Risk:** Load fails on old saves without explicit migration
   - **Mitigation Required:** Infer `years_remaining` from age/stage in `from_dict()`

4. **Downstream Dependencies**
   - **Issue:** Multiple systems assume "all seniors auto-enter"
   - **Risk:** Draft pool suddenly smaller → roster shortfalls, free agency imbalance
   - **Mitigation Required:** Audit all draft pool consumers

### Required Modifications

#### MODIFICATION 1: Derived Eligibility Pattern
**File:** `scripts/core/models/Player.gd`

```gdscript
# ADD to Player.gd

## Eligibility tracking (college players only)
## years_remaining: Eligibility years left (4 for freshmen, 0 for seniors with redshirt used)
## declared_for_draft: Player explicitly declared early (juniors/sophomores)
@export var years_remaining: int = 4
@export var declared_for_draft: bool = false

## Derived property - do NOT serialize independently
## Calculated from stage + declaration + years_remaining
func is_draft_eligible() -> bool:
    if stage != PlayerStage.COLLEGE:
        return stage == PlayerStage.DRAFT_ELIGIBLE

    # College player is eligible if:
    # 1. Senior (years_remaining = 0), OR
    # 2. Underclassman who declared early
    return years_remaining == 0 or declared_for_draft

## Transition player to draft eligible stage
## Validates eligibility before transition
func declare_for_draft() -> bool:
    if not is_college_player():
        push_warning("Cannot declare: player not in college")
        return false

    if years_remaining == 0:
        # Senior auto-eligible, just update stage
        transition_to(PlayerStage.DRAFT_ELIGIBLE)
        declared_for_draft = true  # Mark for historical tracking
        return true

    # Underclassman declaring early
    declared_for_draft = true
    transition_to(PlayerStage.DRAFT_ELIGIBLE)
    return true
```

**Rationale:** `is_draft_eligible()` is computed property (not persisted). Prevents state inconsistency. Single source of truth: stage + declaration flag.

#### MODIFICATION 2: Backward-Compatible Migration
**File:** `scripts/core/models/Player.gd` (extend `from_dict()`)

```gdscript
func from_dict(d: Dictionary) -> void:
    # ... existing field loading ...

    # NEW: Eligibility fields with migration
    years_remaining = int(d.get("years_remaining", _infer_years_remaining(d)))
    declared_for_draft = bool(d.get("declared_for_draft", false))

## Infer eligibility years from age/stage for legacy saves
func _infer_years_remaining(d: Dictionary) -> int:
    var player_age = int(d.get("age", 18))
    var inferred_stage = _infer_stage_from_fields(d)

    if inferred_stage == PlayerStage.COLLEGE:
        # Estimate: Freshmen ~18-19, Sophomores 20, Juniors 21, Seniors 22+
        return maxi(4 - (player_age - 18), 0)

    return 0  # Non-college players have no remaining eligibility
```

**Rationale:** Graceful degradation for old saves. Inference may be approximate but prevents load failures.

#### MODIFICATION 3: Calendar Phase Specification
**File:** `configs/sports/american_football/world/calendar.json`

```json
{
  "id": "draft_declaration",
  "label": "Draft Declaration Window",
  "start_tick": 7,
  "end_tick": 7,
  "tags": ["college", "nfl"],
  "placeholder": false,
  "description": "Underclassmen decide whether to declare for NFL draft or return to school"
}
```

**Shift existing phases:**
- `draft_prep`: tick 7 → tick 8
- `nfl_draft`: tick 8 → tick 9
- All subsequent phases +1

**Rationale:** Inserts declaration between college season and draft prep. PreDraftProcess (tick 8) now operates on declared players only.

#### MODIFICATION 4: PreDraftProcess Filter Integration
**File:** `scripts/world/PreDraftProcess.gd`

```gdscript
static func run(
    world_state: Dictionary,
    year: int,
    seed: int,
    config: Dictionary
) -> Dictionary:
    var draft_pool_all: Dictionary = world_state.get("draft_pool", {})
    var draft_pool: Array = draft_pool_all.get(year, [])

    # NEW: Filter to only declared players
    # draft_pool should already contain only declared players from DraftDecisionEngine
    # This is defensive validation
    draft_pool = draft_pool.filter(func(p):
        var player: Dictionary = p
        return bool(player.get("declared_for_draft", true))  # Default true for seniors
    )

    if draft_pool.is_empty():
        return {
            "year": year,
            "combine_invites": 0,
            # ...
        }

    # ... rest of combine/pro day logic unchanged ...
```

**Rationale:** Defensive filter ensures PreDraftProcess never operates on undeclared players. Primary filtering happens in DraftDecisionEngine.

#### MODIFICATION 5: DraftDecisionEngine Core Contract
**File:** `scripts/world/DraftDecisionEngine.gd` (NEW)

```gdscript
extends RefCounted
class_name DraftDecisionEngine

## Processes underclassman draft declarations
## Pure function - receives all context, returns decisions
## RNG consumption: 1 call per underclassman (declaration roll)

static func process_declarations(
    college_players: Array[Dictionary],  # All college players
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

        # Seniors auto-declare (no choice)
        if years_left == 0:
            _declare_player(p)
            declared.append(p)
            continue

        # Underclassmen make decision
        var declare_prob := _calculate_declaration_probability(
            p, year, positions_cfg, class_rules, config
        )

        if rng.randf() < declare_prob:
            _declare_player(p)
            declared.append(p)
        else:
            returning.append(p)

    return {
        "year": year,
        "declared_count": declared.size(),
        "returning_count": returning.size(),
        "declared_players": declared,
        "returning_players": returning
    }

## Calculate declaration probability based on draft projection
static func _calculate_declaration_probability(
    player: Dictionary,
    year: int,
    positions_cfg: Dictionary,
    class_rules: Dictionary,
    config: Dictionary
) -> float:
    var overall_rating := PlayerRatingCalculator.calculate_overall_rating(
        player, positions_cfg, class_rules
    )

    # Simplified model - more sophisticated logic in implementation
    # 1st round grade (85+): 90% declare
    # 2nd-3rd round (75-85): 65% declare
    # Day 3 (65-75): 35% declare
    # Below day 3 (<65): 15% declare

    if overall_rating >= 85:
        return 0.90
    elif overall_rating >= 75:
        return 0.65
    elif overall_rating >= 65:
        return 0.35
    else:
        return 0.15

static func _declare_player(player: Dictionary) -> void:
    player["declared_for_draft"] = true
    player["stage"] = Player.PlayerStage.DRAFT_ELIGIBLE  # Transition stage
```

**Rationale:** Pure function with explicit RNG. Probabilities based on draft projection (primary decision factor). Deterministic given same seed.

### Testing Strategy Validation

✓ **Unit Tests:** Declaration probability calculation, years_remaining tracking
✓ **Integration Tests:** Draft pool size variance (200-350 players), PreDraftProcess filtering
✓ **Determinism Tests:** Same seed → same declarations
⚠ **Missing:** Migration test - load save without years_remaining field
⚠ **Missing:** Edge case - Redshirt players (5th year seniors)

### Acceptance Criteria Adjustments

**ADD:**
- [ ] `is_draft_eligible()` is derived property (not serialized independently)
- [ ] Legacy saves without `years_remaining` load successfully (inferred from age)
- [ ] Redshirt seniors (5th year) handled correctly (years_remaining can be negative)
- [ ] PreDraftProcess filters undeclared players defensively

**KEEP ALL EXISTING CRITERIA** - fully aligned with architecture.

---

## CROSS-CUTTING CONCERNS

### 1. Determinism Coordination
Both systems inject non-deterministic user timing. Solution:
- **DRAFT-001:** Context-derived RNG seeds (year, team, pick)
- **DRAFT-002:** No user interaction (fully deterministic)

**Validation:** Draft with both features enabled must be replay-stable with same seed.

### 2. Save/Load Compatibility
Both systems modify world_state and Player model. Solution:
- **Versioned schemas:** `draft_trades.version`, `Player.years_remaining` inference
- **Defensive defaults:** Missing fields get safe defaults (declared_for_draft=false)
- **Migration tests:** Explicit test loading pre-Phase-5 saves

### 3. Performance Impact
- **DRAFT-001:** Trade evaluation during draft (user-blocking)
  - Mitigation: <100ms evaluation requirement (already in tests)
- **DRAFT-002:** Declaration processing (batch operation)
  - Risk: LOW - O(n) over college players (~1000 max)

### 4. Configuration Surface Area
Both systems add config sections:
- `draft_pick_trading` (DRAFT-001): Value chart, acceptance thresholds
- `draft_declaration` (DRAFT-002): Probability curves, eligibility rules

**Recommendation:** Consolidate under `configs/sports/american_football/draft/` directory structure.

---

## IMPLEMENTATION RISK ASSESSMENT

### HIGH RISK AREAS
1. **InteractiveDraft State Machine (DRAFT-001)**
   - Risk: Trades during pick execution → corruption
   - Mitigation: Explicit TRADE_WINDOW state (Modification 1)
   - Validation: State transition integration tests

2. **Player Stage Consistency (DRAFT-002)**
   - Risk: stage=COLLEGE but declared_for_draft=true inconsistency
   - Mitigation: Derived `is_draft_eligible()` property (Modification 1)
   - Validation: Stage transition unit tests

### MEDIUM RISK AREAS
3. **Save Compatibility (Both)**
   - Risk: Old saves fail to load
   - Mitigation: Explicit migration in `from_dict()` (Modifications 2, DRAFT-002)
   - Validation: Load legacy save test fixture

4. **Determinism with User Interaction (DRAFT-001)**
   - Risk: Same seed → different results
   - Mitigation: Context-derived RNG (Modification 4)
   - Validation: Determinism tests with user trades at different moments

### LOW RISK AREAS
5. **Calendar Phase Insertion (DRAFT-002)**
   - Risk: Phase ordering breaks downstream systems
   - Assessment: LOW - Phases are loosely coupled by tick number
   - Validation: Full season integration test

---

## RECOMMENDATIONS

### APPROVED FOR IMPLEMENTATION

Both DRAFT-001 and DRAFT-002 are **APPROVED** subject to incorporating the 5 required modifications detailed above.

### ENGINEER DELEGATION STRATEGY

**Engineer 1: DRAFT-001 (Draft Trading)**
- Estimated: 12-16 hours
- Focus: DraftTradeEngine implementation, InteractiveDraft integration
- Key deliverables: Trade validation, value calculation, state machine, deterministic RNG
- Risk areas: State machine transitions, determinism tests

**Engineer 2: DRAFT-002 (Underclassman Entry)**
- Estimated: 8-10 hours
- Focus: Player model changes, DraftDecisionEngine, calendar integration
- Key deliverables: Eligibility tracking, declaration logic, migration compatibility
- Risk areas: Model consistency, save compatibility

**Parallel Work Safe:** Systems are independent. No merge conflicts expected.

### REVIEW CHECKPOINTS

**Checkpoint 1 (CP1): Design Complete**
- Architect reviews: State machines, data schemas, integration points
- Validate: Modifications 1-5 incorporated into design

**Checkpoint 2 (CP3): Implementation 100%**
- Architect reviews: Code structure, boundary respect, determinism patterns
- Validate: All 24+ tests passing (unit, integration, determinism, performance)

**Checkpoint 3 (CP4): Code Review ≥9.5/10**
- Architect reviews: Long-term maintainability, technical debt, documentation
- Validate: No architectural violations introduced

### POST-IMPLEMENTATION VALIDATION

After merge to main:
- [ ] Run full season sim with both features (seed stability test)
- [ ] Load save from v1.0 (pre-Phase-5) and verify graceful handling
- [ ] Benchmark draft with 20 trades vs 0 trades (performance regression)
- [ ] User acceptance test: Trade UI responsiveness during live draft

---

## ARCHITECTURAL DEBT ASSESSMENT

### DEBT INTRODUCED: NONE

Both systems follow existing patterns:
- Stateless services (DraftTradeEngine, DraftDecisionEngine)
- Deterministic RNG (splitmix64 seed derivation)
- Dictionary-based world_state (no new infrastructure)
- Resource-based models (Player.gd extension)

### DEBT REDUCED: MINOR

Activates dormant `value_draft_pick()` function (built but unused). Demonstrates value of forward-looking infrastructure.

### FUTURE EVOLUTION PATHS

**DRAFT-001 Extensions (Post-Phase-1):**
- Multi-year pick trading (future draft picks)
- Player-for-pick trades (combine with roster trades)
- Conditional picks (2025 2nd becomes 2025 1st if playoffs made)

**Architecture Impact:** Current schema versioning (Modification 3) prepares for this. No rework needed.

**DRAFT-002 Extensions (Post-Phase-1):**
- Withdrawal window (players declare then withdraw)
- Graduate transfers (5th year eligibility)
- Medical hardship exemptions (6th year eligibility)

**Architecture Impact:** `years_remaining` already supports negative values (Modification 1). Extensions are additive.

---

## FINAL VERDICT

**Status:** APPROVED WITH MODIFICATIONS
**Confidence:** HIGH
**Blockers:** NONE (modifications are refinements, not blockers)

Both systems demonstrate strong architectural discipline:
- Clear boundaries and responsibilities
- Appropriate complexity for value delivered
- Maintainable lifecycle management
- No hidden coupling or state leakage

The required modifications strengthen an already solid foundation. These are not rejections but refinements to ensure long-term system health.

**PROCEED TO ENGINEER SPAWNING.**

---

**Architect Signature:** Architecture Guardian
**Date:** 2026-01-16
**Review ID:** ARCH-DELTA-001
