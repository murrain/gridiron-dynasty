# Playable Game Roadmap - Player-Coach Experience

> **Goal**: Enable full player-coach gameplay where user can draft, manage roster, and play through seasons

---

## Current State (2026-01-16)

**✅ Complete**:
- Architecture improvements (27/27 ARCH tickets)
- Draft Phase 2 (11/17 DRAFT features)
- QB urgency configuration (PR #149)
- Game saves infrastructure (Phase 0)
- Player generation system

**🚧 In Progress**:
- Draft Phase 3 (Director af89470): DRAFT-001, 011, 010, 002, 017

**❌ Critical Gaps for Playable Game**:
1. **No interactive draft UI for user**
2. **No season simulation flow**
3. **No roster management UI**
4. **No free agency system**
5. **No contract negotiations**
6. **No coaching decisions interface**

---

## Playability Requirements Analysis

### Minimum Playable Product (MPP)

To play as a player-coach through one draft cycle:

#### Phase 1: Interactive Draft (CRITICAL - Week 1)
**Status**: 🚧 In progress (Draft Phase 3)

**Required**:
- ✅ Draft evaluation system (Phase 2 complete)
- ✅ QB urgency (PR #149)
- 🚧 DRAFT-001: Trading system (Director working)
- 🚧 DRAFT-011: Scheme fit (Director working)
- ❌ **Interactive Draft UI** (NOT IN TICKETS)
- ❌ **User pick selection interface**
- ❌ **Trade proposal UI for user**

**Missing**: The DRAFT tickets focus on AI behavior, but there's no ticket for the USER INTERFACE that lets a human make picks!

#### Phase 2: Pre-Draft Setup (HIGH - Week 2)
**Required for context**:
- ❌ Team selection UI
- ❌ Current roster display
- ❌ Team needs visualization
- ❌ Draft board customization (exists partially in Phase 2)

#### Phase 3: Post-Draft Management (MEDIUM - Week 2-3)
**Required to progress to next season**:
- ❌ Roster cuts UI
- ❌ Contract signings (rookies)
- ❌ Training camp simulation
- ❌ Depth chart management

#### Phase 4: Season Simulation (MEDIUM - Week 3-4)
**Required to reach next draft**:
- ❌ Week-by-week sim or auto-sim
- ❌ Coaching decisions (play calling, player management)
- ❌ Free agency (offseason)
- ❌ Contract extensions/negotiations

---

## Critical Missing Tickets

### UI/UX Layer (NOT IN IMPLEMENTATION_TICKETS!)

The IMPLEMENTATION_TICKETS focuses on backend systems but lacks UI tickets for player interaction:

1. **InteractiveDraft User Experience** (8-12 hours)
   - User pick selection UI
   - Real-time draft board updates
   - Trade proposal interface (human-initiated trades)
   - Clock management
   - Pick notifications

2. **Team Management Dashboard** (10-15 hours)
   - Roster overview
   - Depth chart editor
   - Player cards with contract info
   - Team needs analysis
   - Cap space management

3. **Season Flow UI** (12-18 hours)
   - Calendar/schedule view
   - Week simulation controls
   - Coaching decisions interface
   - Game results display
   - Standings tracker

4. **Free Agency Interface** (8-12 hours)
   - Available players list
   - Contract offer system
   - Negotiation UI
   - Signing confirmations

### Backend Systems (Partially in tickets)

5. **Season Simulation Engine** (15-20 hours)
   - Week-by-week game simulation
   - Injury system
   - Player development
   - Team chemistry
   - Playoff bracket

6. **Free Agency System** (10-12 hours)
   - FA pool generation
   - AI team bidding
   - Contract evaluation
   - Signing execution

7. **Contract Management** (8-10 hours)
   - Extension offers
   - Restructuring
   - Cap calculations
   - Dead money tracking

---

## Revised Roadmap for Playable Game

### Sprint 1: Complete Draft System (Current - Week 1)
**Owner**: Director af89470

**Deliverables**:
- DRAFT-001: Trading system with AI + user UI
- DRAFT-011: Scheme fit
- DRAFT-010: Performance optimization
- DRAFT-002: Underclassmen
- DRAFT-017: Private workouts

**Gap**: Ensure DRAFT-001 includes **user-facing trade proposal UI**

### Sprint 2: Interactive Draft Experience (Week 2)
**Owner**: New team

**Deliverables**:
- User pick selection UI (when it's user's turn)
- Draft clock with notifications
- Trade initiation for user
- Real-time board updates during AI picks
- Draft results summary screen

**Integration**: Connect with Draft Phase 3 backend

### Sprint 3: Roster Management Core (Week 2-3)
**Owner**: New team

**Deliverables**:
- Team selection/loading
- Current roster display with contracts
- Depth chart editor
- Roster cuts interface
- Player comparison tools

**Integration**: Use existing roster data structures

### Sprint 4: Season Simulation MVP (Week 3-4)
**Owner**: New team

**Deliverables**:
- Week-by-week simulation (auto-sim only initially)
- Basic injury system
- Player stat tracking
- Season progression to next offseason
- Playoff qualification

**Scope**: Simplified - no coaching decisions yet

### Sprint 5: Free Agency System (Week 4-5)
**Owner**: New team

**Deliverables**:
- FA pool generation
- Contract bidding system
- AI team competition
- User offer interface
- Signing execution with cap validation

**Integration**: Reuses draft evaluation for FA

---

## Fast-Track Option: Playable Draft Only

If we want to enable playing the draft ASAP without full season simulation:

### Week 1: Draft Phase 3 (In progress)
- Backend trading + scheme fit + caching

### Week 2: Draft UI Polish
- User pick selection
- Trade proposal UI
- Real-time updates
- Draft results

### Week 3: Roster Context
- Load roster before draft
- Display team needs
- Show contract implications
- Basic depth chart view

**Result**: User can play through one draft with full context, trading, and strategic decisions.

**Gap**: Can't progress to next season yet (no sim/FA), but validates draft gameplay loop.

---

## Recommended Approach

### Option A: Depth-First (Playable Draft ASAP)
1. ✅ Finish Draft Phase 3 (Week 1)
2. Build Draft UI layer (Week 2)
3. Add minimal roster context (Week 2-3)
4. **Playable draft demo** (End Week 3)
5. Add season sim + FA (Weeks 4-6)

**Pros**: Playable demo quickly, validates draft mechanics
**Cons**: Can't progress to next season initially

### Option B: Breadth-First (Full Season Loop)
1. ✅ Finish Draft Phase 3 (Week 1)
2. Build all UI layers in parallel (Weeks 2-4)
3. Implement season sim + FA (Weeks 2-4)
4. **Full playable game** (End Week 4-5)

**Pros**: Complete experience sooner
**Cons**: Nothing playable for 4-5 weeks

### Recommendation: **Option A** (Depth-First)

**Rationale**:
- Get playable draft in user's hands quickly for feedback
- Draft is the most complex system - validate it works well
- Season sim can be simplified initially (auto-sim to next offseason)
- Incremental releases maintain momentum

---

## Success Criteria

### Playable Draft (3 weeks)
User can:
- ✅ Load a team before draft
- ✅ See current roster and needs
- ✅ Make picks when it's their turn
- ✅ Propose trades to AI teams
- ✅ See AI picks and trades in real-time
- ✅ View draft results and grades

### Playable Season (6 weeks)
User can:
- ✅ All draft features above
- ✅ Manage roster (cuts, depth chart)
- ✅ Simulate through season
- ✅ Reach playoffs (if qualified)
- ✅ Enter offseason/free agency
- ✅ Sign free agents
- ✅ Progress to next draft

---

## Next Actions

1. **Monitor Director af89470**: Ensure Draft Phase 3 includes user trade UI
2. **Create UI Implementation Tickets**: Draft UI layer not in current tickets
3. **Spawn UI Team**: Dedicated team for interactive draft interface
4. **Define MVP Scope**: Decide on Option A (draft-first) vs Option B (full game)
5. **Update IMPLEMENTATION_TICKETS.md**: Add UI/season sim tickets

---

## Dependencies

**Draft Phase 3 → Draft UI → Roster Context → Season Sim → Free Agency**

Each layer depends on previous, but can be developed in parallel once interfaces defined.

---

## Risk Assessment

**High Risk**:
- UI complexity for draft interactions
- Real-time updates during AI picks
- Trade negotiation UX

**Medium Risk**:
- Season simulation performance
- Contract cap calculations
- Free agency AI bidding

**Low Risk**:
- Roster display (data already exists)
- Draft results presentation
- Basic depth chart editing

---

## Open Questions

1. **Should Draft Phase 3 include user trade UI, or is it AI-only?**
   - Check with Director af89470 on scope

2. **Is there ANY existing UI for user draft picks?**
   - Need to audit current InteractiveDraft implementation

3. **What's the minimum viable season sim?**
   - Auto-advance to next offseason? Or week-by-week controls?

4. **Should we create UI tickets in IMPLEMENTATION_TICKETS?**
   - Or separate GAMEPLAY_TICKETS document?

---

*This roadmap prioritizes getting a playable experience in the user's hands as quickly as possible while maintaining code quality.*
