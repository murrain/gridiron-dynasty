# Draft Phase 3: Complete Draft System Implementation Plan

> **Context**: Draft Phase 2 delivered 11/17 features (PR #147). This plan covers the remaining 6 features to complete the draft system.

---

## Executive Summary

**Status**: 11 of 17 DRAFT features complete (65%)

**Remaining Features**:
1. **DRAFT-001**: Draft Day Trading System (CRITICAL)
2. **DRAFT-002**: Underclassman Entry System (HIGH)
3. **DRAFT-008**: Conditional Draft Picks (Post-1.0)
4. **DRAFT-010**: Speculative AI Pre-computation (MEDIUM)
5. **DRAFT-011**: Scheme Fit Analysis (HIGH)
6. **DRAFT-017**: Private Workouts & Team Visits (LOW)

**Estimated Effort**: 47-65 hours total
**Target Delivery**: 2 major PRs (Phase 3A + 3B)

---

## Implementation Priority & Grouping

### Phase 3A: Critical Trading & QB Behavior (25-32 hours)
**Target**: Enable realistic QB draft behavior with trading

#### DRAFT-001: Draft Day Trading System (12-16 hours) - CRITICAL
**Why First**: Enables QB-desperate teams to trade up (pairs with PR #149 QB urgency)

**Components**:
- `DraftTradeEngine.gd` - Core trading logic
- AI trade proposal system with QB urgency integration
- Trade execution and pick ownership updates
- `TradeProposalDialog` UI component
- Trade history tracking

**Key Integration**: QB urgency (2.8x multiplier) drives AI trade-up behavior

**Acceptance Criteria**:
- QB-desperate teams propose trades to move up for elite QBs (75+)
- Trade value uses Jimmy Johnson chart + urgency adjustments
- Pick ownership updates correctly after trades
- 15-25 trades per draft year (realistic NFL average)
- User can initiate trades via UI

**Files Created**:
- `scripts/world/DraftTradeEngine.gd`
- `scenes/ui/draft_day/TradeProposalDialog.gd`
- `scenes/ui/draft_day/TradeProposalDialog.tscn`
- `scripts/tests/gdunit4/test_draft_trading_gdunit4.gd`

**Files Modified**:
- `scripts/world/InteractiveDraft.gd` - Add trade injection points
- `scenes/ui/draft_day/DraftDayUI.gd` - Add trade UI trigger
- `scripts/world/NflDraft.gd` - Expose trade utilities

#### DRAFT-011: Scheme Fit Analysis (8-10 hours) - HIGH
**Why Second**: Improves draft realism, complements trading decisions

**Components**:
- `SchemeFitModifier.gd` evaluation modifier
- Scheme-to-position fit mappings
- Coach scheme preferences integration
- Fit score display in UI

**Scheme Types**:
- Offense: West Coast, Air Cory, Spread, Power Run, Balanced
- Defense: 4-3, 3-4, Cover 2, Cover 3, Hybrid

**Acceptance Criteria**:
- 3-4 teams boost EDGE/LB ratings in draft
- 4-3 teams boost DL ratings
- West Coast teams boost WR/TE with route-running
- Scheme fit affects draft evaluation by ±15%
- Displayed in player cards

**Files Created**:
- `scripts/core/evaluation/modifiers/SchemeFitModifier.gd`
- `configs/sports/american_football/scheme_fit.json`
- `scripts/tests/gdunit4/test_scheme_fit_gdunit4.gd`

**Files Modified**:
- `scripts/core/evaluation/EvaluationModifierStack.gd` - Register modifier
- `scenes/ui/draft_day/PlayerCard.gd` - Display fit score

#### DRAFT-010: Speculative AI Pre-computation (5-6 hours) - MEDIUM
**Why Third**: Performance optimization for draft simulation

**Components**:
- Pre-compute AI draft boards before draft starts
- Cache player evaluations per team
- Invalidate cache on trades
- Background thread processing

**Acceptance Criteria**:
- AI picks complete in <100ms (vs current ~500ms)
- Draft simulations 5x faster for auto-draft
- Cache invalidation on trades
- Memory usage < 50MB for cache

**Files Created**:
- `scripts/world/DraftEvaluationCache.gd`
- `scripts/tests/test_draft_performance.gd`

**Files Modified**:
- `scripts/world/NflDraft.gd` - Use cached evaluations
- `scripts/world/DraftTradeEngine.gd` - Invalidate cache on trade

---

### Phase 3B: Depth & Polish (22-33 hours)
**Target**: Complete remaining features for full NFL parity

#### DRAFT-002: Underclassman Entry System (8-10 hours) - HIGH
**Components**:
- `UnderclassmanDeclarationEngine.gd`
- Draft projection-based decision logic
- Early entry pool generation (50-100 players/year)
- UI notifications for key declarations

**Acceptance Criteria**:
- 50-100 underclassmen declare per year
- Elite prospects (75+) declare 90% of time
- Marginal prospects (60-70) declare 30% of time
- Decision based on projected draft round
- Pool size varies realistically (50-150 players)

**Files Created**:
- `scripts/world/UnderclassmanDeclarationEngine.gd`
- `scripts/tests/gdunit4/test_underclassman_entry_gdunit4.gd`

**Files Modified**:
- `scripts/world/PreDraftProcess.gd` - Add declaration phase
- `scripts/core/models/Player.gd` - Add class_year field

#### DRAFT-017: Private Workouts & Team Visits (5-7 hours) - LOW
**Components**:
- Pre-draft visit scheduling
- Workout result variance (±5% rating adjustment)
- Team-specific intel gathering
- Visit history tracking

**Acceptance Criteria**:
- Each team hosts 20-30 prospects for visits
- Workout results add ±5% evaluation variance
- Teams get "extra intel" on visited players
- Visit history displayed in player cards

**Files Created**:
- `scripts/world/PreDraftWorkouts.gd`
- `scripts/tests/gdunit4/test_private_workouts_gdunit4.gd`

**Files Modified**:
- `scripts/world/PreDraftProcess.gd` - Add workout phase
- `scenes/ui/draft_day/PlayerCard.gd` - Show visit history

#### DRAFT-008: Conditional Draft Picks (9-11 hours) - POST-1.0
**Note**: Lower priority, implements advanced trade mechanic

**Components**:
- Conditional pick tracking (e.g., "3rd becomes 2nd if player is All-Pro")
- Condition evaluation engine
- Multi-year pick tracking
- UI for conditional terms

**Acceptance Criteria**:
- Conditions: playing time, awards, team performance
- Auto-convert when condition met
- Track future-year conditionals
- Display in trade UI

**Files Created**:
- `scripts/world/ConditionalPickEngine.gd`
- `scripts/tests/gdunit4/test_conditional_picks_gdunit4.gd`

**Files Modified**:
- `scripts/world/DraftTradeEngine.gd` - Support conditionals
- World state schema - Add conditional pick tracking

---

## Development Workflow

### Phase 3A Approach (1 Large PR)

**Work Streams** (can parallelize):
1. **Stream A**: DraftTradeEngine core + AI logic (Engineer 1)
2. **Stream B**: Trade UI + InteractiveDraft integration (Engineer 2)
3. **Stream C**: Scheme Fit system + Speculative Cache (Engineer 3)

**Integration Points**:
- DraftTradeEngine + QB urgency (PR #149)
- Trade UI + DraftTradeEngine
- Cache + Trading (invalidation)

**Testing Strategy**:
- Unit tests for each component
- Integration test: Full draft with 20+ trades
- Performance test: Draft simulation <10s with caching
- Determinism test: Same seed = same trades

### Phase 3B Approach (Separate PRs)

**DRAFT-002**: Standalone PR (no dependencies)
**DRAFT-017**: Standalone PR (no dependencies)
**DRAFT-008**: Post-1.0 (separate milestone)

---

## Success Metrics

### Phase 3A Complete When:
- ✅ QB-desperate teams trade up for elite QBs in 70%+ of drafts
- ✅ 15-25 trades per draft year (realistic NFL range)
- ✅ Scheme fit affects picks by ±10-15%
- ✅ Draft simulations complete in <10s (vs current ~30s)
- ✅ All tests pass with ≥9.5/10 code quality score

### Full Draft System Complete When:
- ✅ All 17 DRAFT features implemented
- ✅ Draft behavior matches NFL realism metrics:
  - 2-4 QBs in first round (when elite prospects available)
  - 20-30 trades per draft
  - Underclassmen represent 40-60% of draft pool
  - Scheme fit visible in team tendencies
- ✅ Performance: <10s draft simulation, <100ms per pick
- ✅ User experience: Full draft day UI with all features accessible

---

## Risk Mitigation

### High-Risk Areas

1. **Trade AI Complexity**
   - Risk: AI makes unrealistic trades
   - Mitigation: Extensive value validation, urgency caps, test scenarios

2. **Performance Degradation**
   - Risk: Trading + caching slows down draft
   - Mitigation: Performance tests, profiling, optimization passes

3. **Determinism Preservation**
   - Risk: Trading introduces non-deterministic behavior
   - Mitigation: RNG propagation, seed tests, trade log replay

### Testing Requirements

Each feature requires:
- ✅ Unit tests (isolated component testing)
- ✅ Integration tests (feature working in full draft)
- ✅ Determinism tests (same seed = same behavior)
- ✅ Performance tests (speed benchmarks)
- ✅ Code review score ≥9.5/10

---

## Dependencies on Other Systems

### PR #149 (QB Urgency Config) - REQUIRED
- Provides `draft_qb_urgency` configuration
- Enables 2.8x multiplier for QB-desperate teams
- Must merge before DRAFT-001 implementation

### Existing Draft Infrastructure - LEVERAGED
- `draft_pick_ownership` ledger (tracks pick ownership)
- `value_draft_pick()` function (Jimmy Johnson chart)
- `resolve_draft_order_with_ownership()` (respects trades)
- Pick history tracking (records traded picks)

### Player Generation System - ENHANCED BY
- DRAFT-002 adds underclassman pool
- DRAFT-017 adds workout variance
- Both expand player data model

---

## Timeline Estimate

### Phase 3A: Critical Features (25-32 hours)
- Week 1: DRAFT-001 implementation (12-16h)
- Week 1-2: DRAFT-011 + DRAFT-010 (13-16h)
- Week 2: Integration, testing, PR creation

### Phase 3B: Depth Features (22-33 hours)
- Week 3: DRAFT-002 implementation (8-10h)
- Week 3-4: DRAFT-017 implementation (5-7h)
- Week 4: DRAFT-008 (post-1.0, defer or implement)

**Total**: 4-6 weeks for full completion

---

## Next Steps

1. ✅ Await PR #149 merge (QB urgency config)
2. 📋 Create implementation tickets for Phase 3A
3. 🚀 Implement DRAFT-001 (Draft Trading)
4. 🚀 Implement DRAFT-011 (Scheme Fit)
5. 🚀 Implement DRAFT-010 (Caching)
6. 🧪 Integration testing + PR creation
7. 📋 Plan Phase 3B (DRAFT-002, 017, 008)

---

## Open Questions

1. **DRAFT-008 Priority**: Should conditional picks be 1.0 or deferred?
   - Recommendation: Defer to post-1.0 (complex, lower priority)

2. **Trade Frequency Tuning**: How aggressively should teams trade?
   - Recommendation: Start conservative (15 trades/draft), tune based on playtesting

3. **Scheme Definitions**: How many schemes should we support?
   - Recommendation: Start with 5 offense + 5 defense schemes

4. **Caching Strategy**: Pre-compute all 32 teams or on-demand?
   - Recommendation: Pre-compute all teams at draft start, invalidate on trades

---

*This plan will be updated as implementation progresses and new insights emerge.*
