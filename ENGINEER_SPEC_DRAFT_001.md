# ENGINEER SPECIFICATION: DRAFT-001 Draft Day Trading
**Engineer ID:** team-delta/eng-1
**Workspace:** `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team-delta/eng-1/`
**Estimated Effort:** 12-16 hours
**Priority:** CRITICAL

---

## MISSION

Implement draft-day trading system enabling AI teams and users to propose/execute trades during live draft. System must integrate seamlessly with existing `InteractiveDraft` without breaking pause-based execution flow.

---

## ARCHITECTURAL CONSTRAINTS

### 1. STATELESS SERVICE PATTERN
`DraftTradeEngine` must be a pure service:
- NO access to `world_state` directly
- ALL context passed as parameters
- NO instance variables (use `RefCounted`, not `Object`)
- ALL methods must be static or receive complete context

**Example (CORRECT):**
```gdscript
func evaluate_trade_value(
    offer: Dictionary,
    offering_team_roster: Dictionary,
    receiving_team_roster: Dictionary,
    current_year: int,
    league_cfg: Dictionary
) -> float:
    # Pure function - deterministic output from inputs
```

**Example (INCORRECT - DO NOT DO THIS):**
```gdscript
var _world_state: Dictionary  # ❌ NO! Creates coupling

func evaluate_trade_value(offer: Dictionary) -> float:
    var teams = _world_state.get("nfl_teams")  # ❌ NO! Hidden dependencies
```

### 2. DETERMINISTIC RNG PATTERN
Trade acceptance MUST use stable seeds derived from context:

**CORRECT:**
```gdscript
func should_accept_trade(
    offer: Dictionary,
    receiving_team_id: String,
    year: int,
    current_pick: int,
    base_seed: int
) -> bool:
    # Seed derived from CONTEXT (year, team, pick), not call order
    var trade_seed := Rand.splitmix64(base_seed ^ hash(receiving_team_id) ^ year ^ current_pick)
    var rng := RandomNumberGenerator.new()
    rng.seed = trade_seed

    var acceptance_prob := _calculate_acceptance_probability(offer)
    return rng.randf() < acceptance_prob
```

**INCORRECT:**
```gdscript
var _global_rng: RandomNumberGenerator  # ❌ NO! Non-deterministic

func should_accept_trade(offer: Dictionary) -> bool:
    return _global_rng.randf() < 0.5  # ❌ Different result each call!
```

### 3. STATE MACHINE DISCIPLINE
Trades ONLY occur in explicit `TRADE_WINDOW` state:

**Required State Transitions:**
```
RUNNING → TRADE_WINDOW → RUNNING
        ↓
    WAITING_FOR_USER (if next pick is user's)
```

**Forbidden Transitions:**
```
WAITING_FOR_USER → TRADE_WINDOW  # ❌ User already making pick
RUNNING → TRADE_WINDOW (mid-pick) # ❌ Pick execution in progress
```

### 4. DATA SCHEMA VERSIONING
All trade records MUST include version field:

```gdscript
{
    "version": 1,  # REQUIRED - enables future migration
    "timestamp": 42,  # Pick number when executed
    "teams": {...},
    "picks_exchanged": {...}
}
```

---

## FILES TO CREATE

### 1. `scripts/world/DraftTradeEngine.gd`
**Purpose:** Core trade validation, evaluation, and execution logic
**Class:** `RefCounted` (stateless service)
**Pattern:** Static methods or context-injected instance methods

**Required Public API:**
```gdscript
class_name DraftTradeEngine
extends RefCounted

## Validate trade legality
## @param offer: Trade offer structure
## @param ownership: draft_pick_ownership ledger
## @param year: Current draft year
## @return Dictionary: {valid: bool, reason: String}
static func validate_trade(
    offer: Dictionary,
    ownership: Dictionary,
    year: int
) -> Dictionary:
    pass

## Calculate trade value differential
## @param offer: Trade offer structure
## @param league_cfg: Configuration with pick value chart
## @param current_year: Current year (for future pick discount)
## @return float: Positive = receiving team benefits, negative = offering team benefits
static func calculate_value_differential(
    offer: Dictionary,
    league_cfg: Dictionary,
    current_year: int
) -> float:
    pass

## Determine if receiving team accepts trade
## @param offer: Trade offer structure
## @param receiving_team_id: Team evaluating offer
## @param receiving_roster: Team's current roster
## @param receiving_needs: Position needs dictionary
## @param year: Current draft year
## @param current_pick: Current pick number in draft
## @param base_seed: Draft seed for determinism
## @return bool: true if accepted
static func should_accept_trade(
    offer: Dictionary,
    receiving_team_id: String,
    receiving_roster: Dictionary,
    receiving_needs: Dictionary,
    year: int,
    current_pick: int,
    base_seed: int,
    league_cfg: Dictionary
) -> bool:
    pass

## Execute trade (update ownership ledger)
## @param offer: Trade offer structure
## @param ownership: draft_pick_ownership ledger (MODIFIED IN PLACE)
## @param year: Current draft year
## @return Dictionary: Trade record for history
static func execute_trade(
    offer: Dictionary,
    ownership: Dictionary,
    year: int
) -> Dictionary:
    pass

## Get AI-initiated trade proposals for current pick
## @param current_pick: Current pick number
## @param teams: All NFL teams
## @param rosters: Team rosters
## @param ownership: Pick ownership ledger
## @param available_players: Current draft pool
## @param year: Draft year
## @param base_seed: Draft seed
## @param league_cfg: Configuration
## @return Array[Dictionary]: Potential trade offers
static func generate_ai_trade_proposals(
    current_pick: int,
    teams: Array,
    rosters: Dictionary,
    ownership: Dictionary,
    available_players: Array,
    year: int,
    base_seed: int,
    league_cfg: Dictionary
) -> Array:
    pass
```

**Trade Offer Structure:**
```gdscript
{
    "offering_team_id": String,
    "receiving_team_id": String,
    "picks_offered": [  # Picks offered BY offering team TO receiving team
        {
            "year": int,
            "round": int,
            "pick_in_round": int,  # Original position (for value calc)
            "pick_id": String  # Unique identifier for ownership lookup
        }
    ],
    "picks_requested": [  # Picks requested FROM receiving team BY offering team
        # Same structure as picks_offered
    ],
    "initiated_by": String  # "ai" or "user"
}
```

**Trade Validation Rules:**
1. Both teams exist
2. All picks are owned by the teams offering them
3. No duplicate picks in same offer
4. Pick numbers valid (1-7 rounds, 1-32 per round)
5. No trading picks already used in current draft (pick < current_pick)

**Value Calculation:**
- Use `NflDraft.value_draft_pick(year, round, pick_in_round, current_year, league_cfg)`
- Sum incoming pick values - Sum outgoing pick values = differential
- Positive differential = receiving team gets more value

**Acceptance Logic:**
Base formula:
```
acceptance_probability = base_rate * value_multiplier * need_multiplier * desperation_multiplier

where:
- base_rate = 0.3 (AI accepts ~30% of fair trades)
- value_multiplier = 1.0 + (value_differential / 500.0)  # More value = more likely
- need_multiplier = 1.0 + (need_score / 10.0)  # Filling needs increases acceptance
- desperation_multiplier = 1.0 + (pick_position_urgency / 5.0)  # Teams wanting to move up pay premium
```

Cap acceptance probability at 0.95 (never 100% certain).

**AI Trade Generation Heuristics:**
- Teams without top-20 picks may trade up if elite player available
- Teams with multiple early picks may trade back for volume
- Generate 0-3 proposals per pick (RNG-based with seed from current_pick)
- Only generate trades when value differential within ±20% (fair trades)

### 2. `scenes/ui/draft_day/TradeProposalDialog.gd`
**Purpose:** User interface for proposing trades
**Class:** `Control` or `Window` node
**Pattern:** Signal-based communication with DraftDayUI

**Required Signals:**
```gdscript
signal trade_proposed(offer: Dictionary)
signal trade_cancelled()
```

**Required Public API:**
```gdscript
func open_dialog(
    user_team_id: String,
    available_teams: Array,
    user_picks: Array[Dictionary],
    ownership: Dictionary,
    year: int
) -> void:
    # Populate UI with tradeable picks

func set_target_team(team_id: String, team_picks: Array[Dictionary]) -> void:
    # Update UI with target team's picks

func calculate_value_preview() -> void:
    # Show real-time value differential as user selects picks
```

**UI Requirements:**
- Dropdown: Select target team
- Two columns: "Your Picks" | "Their Picks"
- Checkboxes for each tradeable pick
- Value display: "You give: 500 pts | You receive: 650 pts | Differential: +150"
- Submit button (disabled if no picks selected)
- Cancel button

**Validation:**
- Cannot propose trade with no picks exchanged
- Cannot offer picks user doesn't own
- Cannot request picks target team doesn't own

### 3. `scenes/ui/draft_day/TradeProposalDialog.tscn`
**Purpose:** Scene file for trade dialog
**Structure:**
```
TradeProposalDialog (WindowDialog or Panel)
├─ MarginContainer
│  ├─ VBoxContainer
│  │  ├─ Label ("Propose Trade")
│  │  ├─ HBoxContainer
│  │  │  ├─ Label ("Trade with:")
│  │  │  └─ OptionButton (teams dropdown)
│  │  ├─ HSplitContainer
│  │  │  ├─ VBoxContainer ("Your Picks")
│  │  │  │  ├─ Label
│  │  │  │  └─ ScrollContainer
│  │  │  │     └─ VBoxContainer (pick checkboxes)
│  │  │  └─ VBoxContainer ("Their Picks")
│  │  │     ├─ Label
│  │  │     └─ ScrollContainer
│  │  │        └─ VBoxContainer (pick checkboxes)
│  │  ├─ Panel (Value Summary)
│  │  │  ├─ Label ("Value: You give X pts, receive Y pts")
│  │  │  └─ Label ("Differential: +/- Z pts")
│  │  └─ HBoxContainer (Buttons)
│  │     ├─ Button ("Propose Trade")
│  │     └─ Button ("Cancel")
```

**Styling:** Match existing DraftDayUI theme.

---

## FILES TO MODIFY

### 1. `scripts/world/InteractiveDraft.gd`

**Changes Required:**

#### A. Add Trade Window State
```gdscript
enum DraftState {
    NOT_STARTED,
    RUNNING,
    WAITING_FOR_USER,
    TRADE_WINDOW,  # NEW
    COMPLETED
}
```

#### B. Add Trade Signals
```gdscript
## Emitted when trade window opens (between picks)
signal trade_window_opened(current_pick: int, user_tradeable_picks: Array)

## Emitted when trade is executed
signal trade_executed(trade_record: Dictionary)

## Emitted when trade is rejected
signal trade_rejected(reason: String)
```

#### C. Add Trade Methods
```gdscript
## Enter trade window (called between picks)
func enter_trade_window() -> void:
    if _state != DraftState.RUNNING:
        push_warning("[InteractiveDraft] Cannot enter trade window from state %d" % _state)
        return

    _state = DraftState.TRADE_WINDOW
    var user_picks := _get_user_tradeable_picks()
    trade_window_opened.emit(_current_pick, user_picks)

## Exit trade window and resume draft
func exit_trade_window() -> void:
    if _state != DraftState.TRADE_WINDOW:
        push_warning("[InteractiveDraft] Not in trade window")
        return

    _state = DraftState.RUNNING
    _advance_draft()

## Propose trade (user-initiated)
func propose_trade(offer: Dictionary) -> bool:
    if _state != DraftState.TRADE_WINDOW:
        push_error("[InteractiveDraft] Trades only allowed in trade window")
        return false

    # Validate trade
    var validation := DraftTradeEngine.validate_trade(
        offer,
        _world_state.get("draft_pick_ownership", {}),
        _year
    )

    if not validation.get("valid", false):
        trade_rejected.emit(String(validation.get("reason", "Invalid trade")))
        return false

    # Evaluate acceptance (AI decision)
    var receiving_team_id := String(offer.get("receiving_team_id", ""))
    var receiving_roster := _rosters.get(receiving_team_id, {})
    var receiving_needs := _calculate_position_needs(receiving_roster)

    var accepted := DraftTradeEngine.should_accept_trade(
        offer,
        receiving_team_id,
        receiving_roster,
        receiving_needs,
        _year,
        _current_pick,
        _seed,
        _league_cfg
    )

    if not accepted:
        trade_rejected.emit("Trade declined by %s" % receiving_team_id)
        return false

    # Execute trade
    _execute_trade(offer)
    return true

## Execute trade (internal helper)
func _execute_trade(offer: Dictionary) -> void:
    var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})

    # Use engine to update ownership and create record
    var trade_record := DraftTradeEngine.execute_trade(offer, ownership, _year)

    # Update world state
    _world_state["draft_pick_ownership"] = ownership

    # Add to trade history
    if not _world_state.has("draft_trades"):
        _world_state["draft_trades"] = {}
    var trade_history: Dictionary = _world_state["draft_trades"]
    if not trade_history.has(_year):
        trade_history[_year] = []
    (trade_history[_year] as Array).append(trade_record)

    # Emit signal
    trade_executed.emit(trade_record)

    # Rebuild draft order (ownership changed)
    _build_draft_order()

## Get user's tradeable picks
func _get_user_tradeable_picks() -> Array:
    var ownership: Dictionary = _world_state.get("draft_pick_ownership", {})
    var user_picks: Array = []

    for round_num in range(_current_round, _rounds + 1):
        var round_key := "%d_%d" % [_year, round_num]
        var round_ownership: Array = ownership.get(round_key, [])

        for pick_assignment in round_ownership:
            var p: Dictionary = pick_assignment
            if String(p.get("current_owner_id", "")) == _user_team_id:
                var pick_in_round := int(p.get("pick_in_round", 1))
                var overall := (_rounds * (round_num - 1)) + pick_in_round

                # Only tradeable if not yet used
                if overall > _current_pick:
                    user_picks.append({
                        "year": _year,
                        "round": round_num,
                        "pick_in_round": pick_in_round,
                        "overall": overall,
                        "pick_id": "%d_%d_%d" % [_year, round_num, pick_in_round]
                    })

    return user_picks
```

#### D. Add AI Trade Injection Point (in `_advance_draft`)
```gdscript
func _advance_draft() -> void:
    while _state == DraftState.RUNNING and _current_pick < _draft_order.size():
        var pick_assignment: Dictionary = _draft_order[_current_pick]
        var picking_team_id := String(pick_assignment.get("current_owner_id", ""))
        var round_num := int(pick_assignment.get("round", 1))

        # Check for round change
        if round_num != _current_round:
            _current_round = round_num
            round_changed.emit(_current_round)

        # NEW: Check for AI-initiated trades (before pick execution)
        _process_ai_trade_opportunities()

        # Check if it's user's pick
        if picking_team_id == _user_team_id:
            _state = DraftState.WAITING_FOR_USER
            _request_user_pick()
            return

        # AI makes pick
        _make_ai_pick(pick_assignment)
        _current_pick += 1

    # Draft completed
    if _current_pick >= _draft_order.size():
        _finalize_draft()

## Process AI-initiated trade opportunities (NEW)
func _process_ai_trade_opportunities() -> void:
    # Generate AI trade proposals for current pick
    var proposals := DraftTradeEngine.generate_ai_trade_proposals(
        _current_pick,
        _teams,
        _rosters,
        _world_state.get("draft_pick_ownership", {}),
        _remaining_pool,
        _year,
        _seed,
        _league_cfg
    )

    # Execute first accepted trade (if any)
    for proposal in proposals:
        var p: Dictionary = proposal
        var receiving_team_id := String(p.get("receiving_team_id", ""))
        var receiving_roster := _rosters.get(receiving_team_id, {})
        var receiving_needs := _calculate_position_needs(receiving_roster)

        var accepted := DraftTradeEngine.should_accept_trade(
            p,
            receiving_team_id,
            receiving_roster,
            receiving_needs,
            _year,
            _current_pick,
            _seed,
            _league_cfg
        )

        if accepted:
            _execute_trade(p)
            break  # Only execute one trade per pick
```

**Integration Points:**
- Call `enter_trade_window()` from UI button/hotkey
- Call `exit_trade_window()` after trade completed or cancelled
- Listen to `trade_executed` signal for UI updates
- Listen to `trade_rejected` signal for error messages

### 2. `scenes/ui/draft_day/DraftDayUI.gd`

**Changes Required:**

#### A. Add Trade UI References
```gdscript
@onready var trade_button: Button = $MarginContainer/VBox/TopBar/TradeButton
@onready var trade_dialog: TradeProposalDialog = $TradeProposalDialog
```

#### B. Connect Signals
```gdscript
func _ready() -> void:
    # ... existing connections ...

    # NEW: Trade UI connections
    if trade_button:
        trade_button.pressed.connect(_on_trade_button_pressed)
    if trade_dialog:
        trade_dialog.trade_proposed.connect(_on_trade_proposed)
        trade_dialog.trade_cancelled.connect(_on_trade_cancelled)

    # NEW: Draft signals for trade system
    if draft:
        draft.trade_window_opened.connect(_on_trade_window_opened)
        draft.trade_executed.connect(_on_trade_executed)
        draft.trade_rejected.connect(_on_trade_rejected)
```

#### C. Add Trade UI Handlers
```gdscript
func _on_trade_button_pressed() -> void:
    if not draft:
        return

    # Request trade window
    draft.enter_trade_window()

func _on_trade_window_opened(current_pick: int, user_picks: Array) -> void:
    if not trade_dialog:
        return

    # Open trade dialog
    var ownership := _get_draft_ownership()
    trade_dialog.open_dialog(
        _user_team_id,
        _get_available_trade_partners(),
        user_picks,
        ownership,
        _current_year
    )
    trade_dialog.show()

func _on_trade_proposed(offer: Dictionary) -> void:
    if not draft:
        return

    # Propose trade to draft engine
    var accepted := draft.propose_trade(offer)

    if accepted:
        trade_dialog.hide()
        draft.exit_trade_window()
    # If rejected, stay in dialog (rejection handler shows message)

func _on_trade_cancelled() -> void:
    if not draft:
        return

    trade_dialog.hide()
    draft.exit_trade_window()

func _on_trade_executed(trade_record: Dictionary) -> void:
    # Show trade notification
    _show_trade_notification(trade_record)
    _update_draft_board()  # Refresh pick ownership display

func _on_trade_rejected(reason: String) -> void:
    # Show rejection message
    _show_error_message("Trade Rejected: %s" % reason)

func _get_available_trade_partners() -> Array:
    # Return all teams except user team
    var partners: Array = []
    for team in _teams:
        var t: Dictionary = team
        if String(t.get("id", "")) != _user_team_id:
            partners.append(t)
    return partners

func _show_trade_notification(trade: Dictionary) -> void:
    var offering := String(trade.get("offering_team_id", ""))
    var receiving := String(trade.get("receiving_team_id", ""))
    var picks_offered := (trade.get("picks_offered", []) as Array).size()
    var picks_requested := (trade.get("picks_requested", []) as Array).size()

    var msg := "TRADE: %s sends %d pick(s) to %s for %d pick(s)" % [
        offering, picks_offered, receiving, picks_requested
    ]
    _show_notification(msg, Color.YELLOW, 5.0)  # Existing notification system
```

#### D. Add Trade Button to Scene
In `DraftDayUI.tscn`, add button to top bar:
```
TopBar (HBoxContainer)
├─ ... (existing buttons)
└─ TradeButton (Button)  # NEW
   text = "Propose Trade"
   disabled = false (enable when trade window available)
```

---

## TESTING REQUIREMENTS

### Unit Tests
Create: `scripts/tests/world/test_draft_trade_engine.gd`

**Test Coverage:**
```gdscript
func test_validate_trade_valid_offer():
    # Valid offer with owned picks returns {valid: true}

func test_validate_trade_unowned_pick():
    # Offering pick not owned returns {valid: false, reason: "..."}

func test_validate_trade_already_used_pick():
    # Trading pick < current_pick returns invalid

func test_calculate_value_differential_equal_value():
    # 1st round pick (1000 pts) for two 2nd round picks (500 pts each) = 0

func test_calculate_value_differential_unequal():
    # 1st overall (1500 pts) for 10th overall (800 pts) = -700

func test_should_accept_trade_deterministic():
    # Same seed, same offer, same context = same result (10 iterations)

func test_should_accept_trade_different_seeds():
    # Different seeds produce different results (but both valid)

func test_execute_trade_updates_ownership():
    # After execution, picks are owned by correct teams

func test_execute_trade_creates_history_record():
    # Trade record has all required fields (version, teams, picks, timestamp)

func test_generate_ai_proposals_deterministic():
    # Same seed produces same proposals (teams, picks, timing)

func test_generate_ai_proposals_no_unfair_trades():
    # All generated proposals within ±30% value differential
```

### Integration Tests
Create: `scripts/tests/integration/test_draft_trading_integration.gd`

**Test Coverage:**
```gdscript
func test_user_trade_during_draft():
    # User trades pick 20 for pick 10, draft correctly uses pick 10 for user

func test_ai_trade_updates_draft_order():
    # AI team trades up, InteractiveDraft uses new pick correctly

func test_multiple_trades_same_draft():
    # Execute 5 trades, verify all picks owned correctly

func test_trade_history_persists():
    # Execute trade, save world_state, load, verify trade in history

func test_trade_window_state_transitions():
    # RUNNING → TRADE_WINDOW → RUNNING → WAITING_FOR_USER (if user's turn)
```

### Determinism Tests
Create: `scripts/tests/determinism/test_draft_trading_determinism.gd`

**Test Coverage:**
```gdscript
func test_ai_trades_same_seed():
    # Run draft twice with seed 12345, verify identical AI trades (teams, picks, timing)

func test_user_trade_acceptance_deterministic():
    # Propose same trade 10 times with same seed, AI decision identical

func test_trade_timing_independence():
    # User trades at pick 15 vs pick 20, different outcomes but both deterministic
```

### Performance Tests
Create: `scripts/tests/performance/test_draft_trading_performance.gd`

**Test Coverage:**
```gdscript
func test_validate_trade_performance():
    # 1000 validations complete in < 10ms total (0.01ms each)

func test_calculate_value_performance():
    # 1000 calculations complete in < 50ms total (0.05ms each)

func test_generate_ai_proposals_performance():
    # Generating proposals for all 32 teams completes in < 100ms

func test_draft_with_trades_performance():
    # Draft with 20 trades completes within 5% of draft with 0 trades
```

---

## ACCEPTANCE CRITERIA

### Functional Requirements
- [ ] DraftTradeEngine created with all required public API methods
- [ ] TradeProposalDialog UI functional (select picks, show value, submit)
- [ ] InteractiveDraft has TRADE_WINDOW state and transitions
- [ ] User can propose trades during draft (not just on their turn)
- [ ] AI teams generate trade proposals based on needs and value
- [ ] AI teams accept/reject trades based on value differential
- [ ] Pick ownership updates correctly after trades
- [ ] Trade history persisted in world_state with version field
- [ ] All 11 unit tests passing
- [ ] All 5 integration tests passing
- [ ] All 3 determinism tests passing
- [ ] All 4 performance tests passing

### Architectural Requirements
- [ ] DraftTradeEngine is stateless (no world_state access)
- [ ] All RNG uses context-derived seeds (deterministic)
- [ ] Trade records include schema version field
- [ ] State machine transitions explicit (no implicit state changes)
- [ ] No circular dependencies (DraftTradeEngine → InteractiveDraft ❌)

### Code Quality Requirements
- [ ] All methods have docstring comments
- [ ] Complex logic has inline comments explaining intent
- [ ] No magic numbers (use named constants or config)
- [ ] Error handling for all failure cases
- [ ] Validation messages are user-friendly

---

## REFERENCE FILES

**Must Read:**
- `/main/scripts/world/InteractiveDraft.gd` (integration target)
- `/main/scripts/world/NflDraft.gd` (value_draft_pick usage, pick ownership pattern)
- `/main/scripts/world/TradeGenerator.gd` (existing trade value calculation patterns)
- `/main/docs/architecture/IMPLEMENTATION_TICKETS.md` (Phase 5, DRAFT-001 section)
- `/workspaces/team-delta/architect/ARCHITECTURAL_ASSESSMENT.md` (this review)

**Patterns to Follow:**
- Seed derivation: `Rand.splitmix64(base_seed ^ context_hash)`
- Pick ownership: `world_state["draft_pick_ownership"]["%d_%d" % [year, round]]`
- Trade value: `NflDraft.value_draft_pick(year, round, pick_in_round, current_year, cfg)`

---

## DELIVERY CHECKLIST

Before requesting code review:
- [ ] All 4 files created/modified committed to git
- [ ] All 23 tests implemented and passing
- [ ] Manual testing: Draft with 5+ trades completes successfully
- [ ] Manual testing: User trade proposal UI functional
- [ ] Manual testing: Trade rejection shows clear message
- [ ] Determinism verified: Same seed produces identical draft with trades
- [ ] Performance benchmarked: Trade evaluation < 100ms
- [ ] Code self-reviewed for architectural violations
- [ ] Docstrings complete for all public methods
- [ ] No commented-out code or debug prints

---

## QUESTIONS FOR ARCHITECT

If blocked, ask architect:
1. "Is it acceptable for AI teams to propose trades to user (not just user-initiated)?"
2. "Should trades involving future draft picks (Year+1) be supported in Phase 1?"
3. "How should trade value imbalance be displayed in UI (% or absolute points)?"
4. "Should there be a max number of trades per draft (anti-spam)?"

**Workspace Ready:** `/mnt/linux2-nvme/patrick/Claude/gridiron-dynasty/workspaces/team-delta/eng-1/`
**Branch:** `team-delta/eng-1` (to be created)
**Merge Target:** `team-delta/architect` branch

---

**Specification Author:** Architecture Guardian
**Date:** 2026-01-16
**Version:** 1.0
