# Remaining Work Plan - Draft System & Playable Experience

> **Status as of 2026-01-16**: Draft Phase 3A complete (PR #150 under review)

---

## ✅ Completed: Draft Phase 3A (PR #150)

- **DRAFT-001**: Draft trading system ✅
- **DRAFT-011**: Scheme fit analysis ✅
- **DRAFT-010**: Draft board caching ✅
- **Quality**: Both reviews 9.6-9.7/10 ✅

---

## 📋 Remaining DRAFT System Tickets

### Phase 3B: Core Features

#### DRAFT-002: Underclassman Entry System (HIGH PRIORITY)
**Effort**: 8-10 hours | **Engineer**: 1

**What It Does**:
- Players can declare early for draft (leave college before senior year)
- Elite prospects (75+ rating) declare 90% of time
- Marginal prospects (60-70 rating) declare 30% of time
- Pool size varies realistically: 50-100 underclassmen per year

**Implementation**:
- Create `UnderclassmanDeclarationEngine.gd`
- Add `class_year` field to Player model (Fr, So, Jr, Sr)
- Add `declared_for_draft` boolean flag
- Integration with PreDraftProcess

**Why It Matters**: Dynamic draft pool sizes create more realistic draft variability. Some years have deep classes, others are shallow.

#### DRAFT-017: Private Workouts & Team Visits (LOW PRIORITY)
**Effort**: 5-7 hours | **Engineer**: 1 (or DEFER)

**What It Does**:
- Teams host 20-30 prospects for pre-draft visits
- Workouts add ±5% evaluation variance
- Teams get "extra intel" on visited players

**Implementation**:
- Create `PreDraftWorkouts.gd`
- Integration with PreDraftProcess
- Display visit history in player cards

**Recommendation**: DEFER to post-1.0 (low user impact, backend variance)

#### DRAFT-008: Conditional Draft Picks (POST-1.0)
**Effort**: 9-11 hours | **Status**: Deferred

**What It Does**:
- "3rd round pick becomes 2nd if player is All-Pro"
- Complex trade mechanic used in real NFL

**Recommendation**: Defer - advanced feature, not needed for MVP

### Summary: DRAFT Tickets Remaining

| Ticket | Priority | Effort | Status |
|--------|----------|--------|--------|
| DRAFT-002 (Underclassmen) | HIGH | 8-10h | Ready for guardian |
| DRAFT-017 (Workouts) | LOW | 5-7h | Recommend defer |
| DRAFT-008 (Conditional Picks) | POST-1.0 | 9-11h | Explicitly deferred |

**Recommended Next Step**: Spawn Architecture-Guardian for DRAFT-002 only (1 engineer, focused implementation)

---

## 🎮 Playable Draft UI Work

### Current State

The Draft Phase 3A backend is complete, but the draft is **not yet fully playable** by a human user. Missing pieces:

#### What Works Now (Automated)
- ✅ AI teams make picks automatically
- ✅ AI teams propose and execute trades
- ✅ Draft board with player ratings
- ✅ Scheme fit and QB urgency driving decisions

#### What's Missing for Human Play

1. **User Team Selection** (CRITICAL)
   - No UI to select which team user controls
   - Draft currently auto-simulates all picks
   - Need: Team selection screen before draft

2. **User Pick Interaction** (CRITICAL)
   - No pause when user's pick comes up
   - No player selection UI for user
   - Need: Modal/screen for user to choose from available players

3. **User-Initiated Trades** (COMPLETE)
   - ✅ TradeProposalDialog exists (Engineer 2 built it)
   - ✅ "Propose Trade" button in DraftDayUI
   - ✅ Trade value calculator working

4. **Draft State Visibility** (PARTIAL)
   - ✅ Can see picks as they happen
   - ✅ Can see player details
   - ❌ Can't easily see own team's current roster
   - ❌ Can't see team needs assessment

5. **Roster Context** (MISSING)
   - Need: Pre-draft roster view showing starter/backup/needs
   - Need: Depth chart display
   - Need: Position need indicators

### Playable Draft UI Implementation Plan

**Recommended Approach**: Depth-first (Option A) - Get playable draft working ASAP

#### Phase 1: Basic Playable Draft (15-20 hours, 1-2 engineers)

**Work Package: "Make Draft Playable"**

**Engineer 1: User Interaction Layer** (10-12 hours)
- Team selection screen (which team to control)
- User pick modal (pause draft, show available players, let user select)
- Integration with InteractiveDraft state machine
- Pick confirmation and draft progression
- Draft results summary screen

**Engineer 2: Roster Context Display** (5-8 hours)
- Pre-draft roster view (current team's players)
- Position needs visualization (red/yellow/green indicators)
- Depth chart preview (starters, backups, needs)
- Draft recap showing picks made

**Success Criteria**:
- User can select a team before draft starts
- User can manually select players when their pick comes up
- User can propose trades during draft
- User can see their team's current roster and needs
- Draft can be completed start-to-finish with user participation

**Integration Points**:
- InteractiveDraft already has signals and state management
- DraftDayUI already has UI structure
- TradeProposalDialog already built and working

#### Phase 2: Polish & Features (10-15 hours, 1 engineer)

**Enhancements**:
- Draft board filters (by position, by need)
- Player comparison view (side-by-side stats)
- Draft history/log
- Pick timer (simulate draft clock)
- Draft grades for user's picks

---

## 🚀 Recommended Sequencing

### Next 3 Work Packages (in order)

1. **DRAFT-002: Underclassman System** (1-2 days, 1 guardian + 1 engineer)
   - Simple, focused, completes core draft mechanics
   - No UI work, pure backend
   - 8-10 hours effort

2. **Playable Draft UI: Phase 1** (3-5 days, 1 guardian + 2 engineers)
   - Makes draft playable by humans
   - Delivers user-facing value immediately
   - 15-20 hours effort

3. **Playable Draft UI: Phase 2** (2-3 days, 1 guardian + 1 engineer)
   - Polish and quality-of-life features
   - Iterative improvements based on playtesting
   - 10-15 hours effort

### Total Timeline: 7-10 days to **fully playable draft**

---

## 📊 Remaining Ticket Summary

### DRAFT System (Backend)
- ✅ **Complete**: DRAFT-001, 011, 010 (Phase 3A - PR #150)
- 🔄 **Ready**: DRAFT-002 (Underclassmen) - 8-10h
- ⏸️ **Deferred**: DRAFT-017 (Workouts) - 5-7h
- ❌ **Post-1.0**: DRAFT-008 (Conditional Picks) - 9-11h

### Playable Experience (Frontend)
- ✅ **Complete**: Trade UI, Draft board display
- 🔄 **Phase 1**: User pick selection, team selection, roster context - 15-20h
- ⏸️ **Phase 2**: Polish, filters, comparison tools - 10-15h

### Grand Total Remaining
- **Must-Have**: DRAFT-002 + Playable UI Phase 1 = **23-30 hours** (3 work packages)
- **Nice-to-Have**: Playable UI Phase 2 = **+10-15 hours** (1 work package)
- **Deferred**: DRAFT-017 + DRAFT-008 = **14-18 hours** (post-playable)

---

## ✅ Answer: Which Tickets Are Left?

**Short Answer**:
1. DRAFT-002 (Underclassmen) - 8-10h - Ready to implement
2. Playable Draft UI Phase 1 - 15-20h - Critical for user gameplay
3. Playable Draft UI Phase 2 - 10-15h - Polish

**Everything else is complete (Phase 3A) or deferred (DRAFT-017, DRAFT-008).**

---

*Last updated: 2026-01-16 after PR #150 creation*
