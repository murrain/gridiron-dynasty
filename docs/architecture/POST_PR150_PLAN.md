# Post-PR #150 Implementation Plan

> **Trigger**: Execute after PR #150 (Draft Phase 3A) merges to main

---

## 📦 Work Package: Complete Draft System & Playable Experience

### Scope

**Remaining DRAFT Backend**:
- DRAFT-002: Underclassman entry system (8-10 hours)

**Playable Draft UI** (CRITICAL for user gameplay):
- Phase 1: Basic playable experience (15-20 hours)
  - Team selection before draft
  - User pick selection modal
  - Pre-draft roster view
  - Position needs visualization
- Phase 2: Polish & features (10-15 hours)
  - Draft board filters and sorting
  - Player comparison tools
  - Draft grades and analysis
  - Pick timer/clock simulation

**Total Estimated Effort**: 33-45 hours across multiple engineers

---

## 🏗️ Proposed Workflow

### Step 1: Spawn Architecture-Guardian (1 agent)

**Guardian Mission**: Comprehensive architectural planning for all remaining draft work

**Guardian Deliverables**:
1. **Architectural Assessment**:
   - Review DRAFT-002 integration with existing player models
   - Design playable UI architecture (team selection, state management, user flow)
   - Evaluate UI/backend separation and integration points
   - Assess session state persistence (user's team selection, draft progress)

2. **Engineer Allocation Decision**:
   - Determine optimal number of engineers (recommended: 4)
   - Define clear file ownership boundaries
   - Identify parallelization opportunities and dependencies
   - Specify integration checkpoints

3. **Engineer Specifications**:
   - **Engineer 1**: DRAFT-002 Underclassman system (backend)
   - **Engineer 2**: Team selection + user pick modal (UI foundation)
   - **Engineer 3**: Roster context + position needs (UI context)
   - **Engineer 4**: Polish layer (filters, comparisons, grades)

### Step 2: Director Spawns Engineers (4 agents)

Based on guardian specifications, Director spawns engineers in parallel.

**Coordination Strategy**:
- Engineers 1 works independently (backend, no UI dependencies)
- Engineers 2-3 coordinate on UI state management
- Engineer 4 depends on Engineers 2-3 completing foundation

**Integration Order**:
1. Engineer 1 (DRAFT-002) can merge first (independent)
2. Engineers 2-3 (Playable UI Phase 1) merge together
3. Engineer 4 (Polish) merges last (depends on 2-3)

### Step 3: Quality Reviews (2 reviewers)

- Test Infrastructure Engineer reviews all test suites
- Code Quality Reviewer reviews all implementations
- Both must score ≥9.5/10 before merge

---

## 📋 Detailed Work Package for Guardian

### DRAFT-002: Underclassman Entry System

**Architecture Considerations**:
- Player model extension: Add `class_year` field (Fr=1, So=2, Jr=3, Sr=4)
- Add `declared_for_draft` boolean flag
- Backward compatibility: Infer class_year from age for old saves
- Integration point: PreDraftProcess calls declaration engine before draft pool finalization
- RNG determinism: Seeded decision-making for declaration probability

**Implementation Requirements**:
- Create `UnderclassmanDeclarationEngine.gd` (stateless service)
- Decision logic:
  - Elite prospects (75+): 90% declaration rate
  - Good prospects (70-74): 60% declaration rate
  - Marginal prospects (60-69): 30% declaration rate
  - Below 60: <10% declaration rate
- Projected draft round influences decision (1st round → always declare)
- Pool size varies: 50-100 underclassmen per year

**Files to Create**:
- `scripts/world/UnderclassmanDeclarationEngine.gd`
- `scripts/tests/gdunit4/test_underclassman_entry_gdunit4.gd`

**Files to Modify**:
- `scripts/core/models/Player.gd` (add fields with backward compatibility)
- `scripts/world/PreDraftProcess.gd` (integrate declaration phase)

**Success Criteria**:
- 50-100 underclassmen declare per year
- Declaration rates match specified probabilities
- RNG determinism maintained
- Backward compatible with existing saves

---

### Playable Draft UI: Phase 1 (Critical)

**Architecture Considerations**:
- **User Session State**: Need to persist user's team selection across draft
- **State Machine Integration**: InteractiveDraft already has state machine, extend for user interaction
- **UI Pause Mechanism**: Pause auto-simulation when user's pick comes up
- **Signal Architecture**: Use Godot signals for UI ↔ backend communication
- **Roster Data Loading**: Pre-load user team's roster before draft starts
- **Position Needs Calculation**: Use existing TeamNeeds.gd, expose to UI

**Component 1: Team Selection (Pre-Draft)**

**What It Does**:
- Screen before draft starts where user selects which team to control
- Shows team info: city, name, current record, draft position
- "Start Draft" button begins draft with user controlling selected team

**Implementation**:
- Create `TeamSelectionScreen.gd/.tscn` (new scene)
- Integration: InteractiveDraft.start() accepts `user_team_id` parameter
- State: Store user_team_id in InteractiveDraft for pick pause logic

**Component 2: User Pick Modal (During Draft)**

**What It Does**:
- When user's pick comes up, pause draft and show player selection UI
- Display available players (filtered by BPA or position need)
- Show player details: position, rating, scheme fit, projection
- "Select Player" button makes the pick
- Option to "Auto-Pick BPA" if user wants to skip

**Implementation**:
- Create `UserPickModal.gd/.tscn` (modal dialog)
- Integration: InteractiveDraft emits `user_pick_required` signal
- DraftDayUI listens and shows modal
- Modal returns selected player, InteractiveDraft executes pick

**Component 3: Pre-Draft Roster View**

**What It Does**:
- Before draft, show user team's current roster
- Display starters, backups, depth
- Highlight position needs (red = critical, yellow = depth, green = set)
- Show contract info (years remaining, cap impact)

**Implementation**:
- Create `PreDraftRosterView.gd/.tscn` (scrollable list)
- Uses Team.roster data from world_state
- TeamNeeds.gd calculates position priorities
- Contract display from Player.contract (already typed in Phase 3A)

**Files to Create**:
- `scenes/ui/draft/TeamSelectionScreen.gd/.tscn`
- `scenes/ui/draft/UserPickModal.gd/.tscn`
- `scenes/ui/draft/PreDraftRosterView.gd/.tscn`
- `scripts/tests/gdunit4/test_playable_draft_ui_gdunit4.gd`

**Files to Modify**:
- `scripts/world/InteractiveDraft.gd` (add user interaction state machine states)
- `scenes/ui/draft_day/DraftDayUI.gd` (integrate new components)
- `scripts/world/NflDraft.gd` (expose helper methods if needed)

**Success Criteria**:
- User can select team before draft
- Draft pauses when user's pick comes up
- User can select from available players
- User can see roster context and position needs
- User can propose trades (already working from Phase 3A)
- Draft completes successfully with user participation

---

### Playable Draft UI: Phase 2 (Polish)

**Architecture Considerations**:
- Build on Phase 1 foundation
- All enhancements are additive (no core changes)
- Focus on user experience and quality-of-life

**Component 1: Draft Board Filters**

**What It Does**:
- Filter available players by position (QB, RB, WR, etc.)
- Sort by: overall rating, scheme fit, position need, draft projection
- Search by player name

**Component 2: Player Comparison**

**What It Does**:
- Select 2-3 players to compare side-by-side
- Show stats, ratings, scheme fit, contract projections
- Helps user decide between similar prospects

**Component 3: Draft Grades & Analysis**

**What It Does**:
- After each user pick, show draft grade (A+, A, B, C, D, F)
- Analysis: "Reached for need" vs "Value pick" vs "BPA"
- End-of-draft summary: Overall grade, best picks, reaches

**Component 4: Pick Timer/Clock**

**What It Does**:
- Countdown timer for user picks (e.g., 5 minutes per pick)
- Option to turn off for casual play
- Auto-pick BPA if timer expires

**Files to Create**:
- `scenes/ui/draft/DraftBoardFilter.gd` (filter UI)
- `scenes/ui/draft/PlayerComparisonView.gd/.tscn` (comparison modal)
- `scripts/world/DraftGrader.gd` (grading logic)
- `scenes/ui/draft/DraftGradeDisplay.gd` (grade UI)

**Files to Modify**:
- `scenes/ui/draft_day/DraftDayUI.gd` (integrate new features)
- `scenes/ui/draft/UserPickModal.gd` (add filters and timer)

**Success Criteria**:
- User can filter/sort available players
- User can compare multiple prospects
- User receives grades after picks
- Pick timer (optional) creates urgency

---

## 🎯 Guardian Success Criteria

**Guardian must deliver**:
1. ✅ Architectural assessment (APPROVED/REQUIRES MODIFICATION)
2. ✅ Clear file ownership boundaries (no engineer conflicts)
3. ✅ Integration strategy (merge order, checkpoints)
4. ✅ Engineer specifications (1-4 engineers, detailed tasks)
5. ✅ RNG determinism verification (all user actions seeded)
6. ✅ State persistence strategy (user team selection saved)

**Guardian reports to Director**:
```
READY FOR ENGINEER SPAWNING

Recommend spawning [N] engineers with the following specifications:

**Engineer 1: DRAFT-002 Underclassman System**
[Detailed spec]

**Engineer 2: Team Selection + User Pick Modal**
[Detailed spec]

**Engineer 3: Roster Context + Position Needs**
[Detailed spec]

**Engineer 4: Draft Polish (Filters, Comparisons, Grades)**
[Detailed spec]
```

---

## 📊 Timeline Estimate

**Guardian Planning**: 2-4 hours (thorough exploration)

**Implementation** (parallel):
- Engineers 1-3: 3-5 days (core work)
- Engineer 4: 2-3 days (polish, depends on 2-3)

**Reviews**: 1 day (test infra + code quality)

**Total**: 6-10 days to **fully playable draft**

---

## ✅ Definition of Done

**After this work package, users can**:
- ✅ Select a team to control before draft
- ✅ See team's current roster and position needs
- ✅ Make picks manually when their turn comes up
- ✅ Propose trades to AI teams during draft
- ✅ Filter and compare available prospects
- ✅ See real-time AI picks and trades
- ✅ Receive draft grades for their selections
- ✅ Complete a full draft experience start-to-finish

**Quality Requirements**:
- ✅ All tests pass (determinism, integration, unit)
- ✅ Test Infrastructure Review: ≥9.5/10
- ✅ Code Quality Review: ≥9.5/10
- ✅ Performance: UI responsive (<100ms interactions)
- ✅ RNG determinism maintained (same seed = same draft)

---

## 🚀 Execution Command for Director

**After PR #150 merges**:

```
Director: Spawn Architecture-Guardian with this work package (POST_PR150_PLAN.md)

Guardian will:
1. Conduct architectural assessment
2. Determine engineer allocation (recommended: 4)
3. Prepare detailed engineer specifications

Director: Await guardian report, then spawn engineers (1-4 based on guardian recommendation)

Director: Spawn reviewers after engineers complete implementation
```

---

*This plan delivers a fully playable draft experience, completing the draft system implementation.*
