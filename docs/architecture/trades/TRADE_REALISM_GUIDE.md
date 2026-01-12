# Trade Realism Guide

**Status**: Design Phase
**Author**: Architecture Guardian
**Date**: 2026-01-11
**Parent**: TRADE_SYSTEM_ARCHITECTURE.md

---

## Purpose

This document defines the behavioral rules and constraints that make trades feel realistic rather than like fantasy football. The goal is to simulate **rational NFL GMs** making strategic decisions under organizational, competitive, and psychological constraints.

---

## Core Realism Principles

### 1. Trades Should Be Rare

**Target**: 10-20 significant trades per year across 32 teams

**Rationale**:
- Real NFL averages 15-25 trades per season (including draft day)
- Most involve role players, not stars
- Blockbuster trades (star for star) happen 2-3 times per year
- Teams prefer development over trading

**Implementation**:
```gdscript
# Trade frequency config controls attempts per window
{
  "trade_windows": {
    "pre_draft": {"trade_frequency": 0.2},      # 20% of teams attempt
    "preseason": {"trade_frequency": 0.3},      # 30% of teams attempt
    "midseason": {"trade_frequency": 0.15},     # 15% of teams attempt
    "deadline": {"trade_frequency": 0.4}        # 40% of teams attempt
  }
}

# Expected trades per year:
# Pre-draft: 32 * 0.2 / 2 = 3 trades (divide by 2 since each trade involves 2 teams)
# Preseason: 32 * 0.3 / 2 = 5 trades
# Midseason: 32 * 0.15 / 2 = 2 trades
# Deadline: 32 * 0.4 / 2 = 6 trades
# Total: ~16 trades per year ✓
```

### 2. Not Everyone Is Selling

**Principle**: Teams must have MOTIVATION to trade, not just willingness.

**Anti-Pattern** (Fantasy Football):
```
User: "I want to trade for this player"
AI Team: "Sure, here are all my players available"
```

**Realistic Pattern**:
```
Team A: *Starting CB injured for season*
System: Detects injury crisis, raises trade temperature
Team A: Actively seeking CB replacement
Team B: Has surplus CBs (4 on roster)
System: Matches complementary needs
Trade occurs: A gets CB, B gets draft pick
```

**Implementation**:
```gdscript
func should_team_consider_trades(profile: TeamTradeProfile) -> bool:
  # Team must have motivation (need OR surplus)
  if profile.positional_needs.is_empty() and profile.positional_surplus.is_empty():
    return false  # No reason to trade

  # Team must be warm enough (temperature >= 0.4)
  if profile.temperature_score < 0.4:
    return false  # Too cold, won't initiate

  # Team can't be in "frozen" situations
  if _is_team_frozen(profile):
    return false  # Protecting roster

  return true
```

### 3. Core Players Are Untouchable

**Principle**: Elite young players on good teams should almost never be traded.

**Untouchable Criteria**:
- Franchise QB (age <30, rating >80)
- Elite young player (age <25, potential >85)
- Team captain / cultural cornerstone
- Recent high draft pick (1st rounder within 2 years)

**Exception Cases**:
- Player demands trade (Phase 4: player agency)
- Team enters full rebuild (fire sale)
- Off-field issues (suspension, legal trouble)
- Cap crisis with no other options

**Implementation**:
```gdscript
func identify_untouchables(roster: Dictionary, team_status: String, config: Dictionary) -> Array:
  var untouchables := []

  for player in roster.get("players", []):
    var p: Dictionary = player
    var position := String(p.get("position", ""))
    var age := int(p.get("age", 30))
    var rating := _calculate_overall_rating(p)
    var potential := _calculate_potential_rating(p)

    # Rule 1: Franchise QB protection
    if position == "QB" and age < 30 and rating >= 80.0:
      untouchables.append(p.get("id"))
      continue

    # Rule 2: Elite young player protection
    if age <= 25 and potential >= 85.0:
      untouchables.append(p.get("id"))
      continue

    # Rule 3: Recent high pick protection
    var draft_year := int(p.get("draft_year", 0))
    var draft_round := int(p.get("draft_round", 99))
    var current_year := _get_current_year()
    if draft_round == 1 and (current_year - draft_year) <= 2:
      untouchables.append(p.get("id"))
      continue

    # Rule 4: Team captain (Phase 4)
    if p.get("traits", []).has("Team_Captain"):
      untouchables.append(p.get("id"))
      continue

  return untouchables
```

### 4. Division Rivals Don't Help Each Other

**Principle**: Trading within division requires massive overpay.

**Real NFL Examples**:
- Cowboys/Eagles rarely trade
- Packers/Bears almost never trade
- When they do, acquiring team pays premium

**Penalty Formula**:
```
Normal trade: 20-for-20 value is fair
Division rival: 20-for-30 required (50% premium)
```

**Statistical Target**:
- Division trades: <10% of all trades
- Non-division trades: 90% of all trades

**Implementation**:
```gdscript
func calculate_division_trade_probability(team_a: Dictionary, team_b: Dictionary) -> float:
  var same_division := (team_a.get("division") == team_b.get("division"))

  if not same_division:
    return 1.0  # No penalty

  # Base probability: 10% (most trades rejected due to rivalry)
  var base_prob := 0.1

  # Exceptions increase probability
  var exceptions := _check_rivalry_exceptions(team_a, team_b)

  # Cap crisis: +20% (desperate teams will trade anywhere)
  if exceptions.get("cap_crisis", false):
    base_prob += 0.2

  # Both rebuilding: +15% (not competing, less rivalry)
  if exceptions.get("both_rebuilding", false):
    base_prob += 0.15

  return clamp(base_prob, 0.05, 0.4)  # Max 40% chance even with exceptions
```

### 5. Context Matters (Team Status)

**Principle**: Contenders and rebuilders have opposite trade behaviors.

**Contender Behavior**:
- Keep core players (protecting championship window)
- Trade FOR win-now pieces (veterans, proven talent)
- Trade AWAY future assets (draft picks, young players)
- Aggressive at deadline if playoff spot uncertain

**Rebuilder Behavior**:
- Trade veterans (expiring contracts, aging stars)
- Trade FOR future assets (picks, young players with potential)
- Keep young core (building for 3+ years out)
- Patient, won't overpay

**Playoff Bubble Behavior**:
- Most unpredictable (could buy OR sell)
- Depends on record by week 8-10
- Aggressive if 7-3, passive if 5-5

**Implementation**:
```gdscript
func determine_trade_strategy(team_profile: TeamTradeProfile) -> Dictionary:
  match team_profile.team_status:
    "contender":
      return {
        "preference": "win_now",
        "target_age": "veteran",  # Age 27-32
        "target_type": "proven",  # Rating > 80
        "willing_to_give": ["picks", "young_players"],
        "reluctant_to_give": ["core_veterans"],
        "value_tolerance": 0.35  # Will overpay slightly
      }

    "rebuilder":
      return {
        "preference": "future_value",
        "target_age": "young",  # Age <25
        "target_type": "potential",  # Potential > 75
        "willing_to_give": ["veterans", "aging_stars"],
        "reluctant_to_give": ["young_core", "picks"],
        "value_tolerance": 0.40  # Will accept worse immediate value
      }

    "playoff_bubble":
      return {
        "preference": "flexibility",
        "target_age": "any",
        "target_type": "value",  # Best value regardless
        "willing_to_give": ["surplus"],
        "reluctant_to_give": ["starters"],
        "value_tolerance": 0.30  # Standard fairness
      }

    _:
      return {
        "preference": "balanced",
        "target_age": "any",
        "target_type": "any",
        "willing_to_give": ["surplus"],
        "reluctant_to_give": ["starters"],
        "value_tolerance": 0.30
      }
```

### 6. Positional Scarcity

**Principle**: Teams won't trade themselves into impossible depth situations.

**Minimum Depth Requirements** (from config):
```json
{
  "position_minimums": {
    "QB": 2,    # Must have 2 QBs (starter + backup)
    "RB": 3,    # 3 RBs minimum
    "WR": 4,    # 4 WRs minimum
    "TE": 2,
    "OL": 8,    # 5 starters + 3 backups
    "DL": 6,
    "EDGE": 4,
    "LB": 5,
    "CB": 4,
    "S": 3,
    "K": 1,
    "P": 1
  }
}
```

**Special Case: QB Protection**
```gdscript
func can_trade_quarterback(qb_id: String, roster: Dictionary) -> Dictionary:
  var qbs := _get_players_by_position(roster, "QB")

  # Count healthy QBs
  var healthy_qbs := 0
  for qb in qbs:
    if not _is_injured(qb):
      healthy_qbs += 1

  if healthy_qbs <= 1:
    return {
      "can_trade": false,
      "reason": "qb_scarcity",
      "message": "Cannot trade only healthy QB"
    }

  # Check if trading QB is franchise player
  var qb := _find_player_by_id(roster, qb_id)
  var rating := _calculate_overall_rating(qb)
  var age := int(qb.get("age", 30))

  if rating >= 80.0 and age < 30:
    # Check if backup is viable
    var backup := _get_best_backup_qb(roster, qb_id)
    var backup_rating := _calculate_overall_rating(backup)

    if backup_rating < 70.0:
      return {
        "can_trade": false,
        "reason": "no_viable_backup",
        "message": "Backup QB not starter quality (rating < 70)"
      }

  return {"can_trade": true}
```

---

## Trade Rejection Reasons

### Why Teams Say "No"

Comprehensive rejection taxonomy:

#### 1. Value Imbalance
```gdscript
{
  "reason": "value_imbalance",
  "details": {
    "value_given": 25.0,
    "value_received": 15.0,
    "pct_diff": 40.0,  # 40% difference
    "tolerance": 30.0,  # Only accept 30%
    "excess": 10.0  # 10% over tolerance
  },
  "message": "Trade value 40% imbalanced, exceeds 30% tolerance"
}
```

#### 2. Division Rival
```gdscript
{
  "reason": "division_rival",
  "details": {
    "division": "nfc_east",
    "penalty_applied": true,
    "required_premium": 50.0  # Would need 50% more value
  },
  "message": "Will not trade quality player to division rival"
}
```

#### 3. Untouchable Player
```gdscript
{
  "reason": "untouchable_player",
  "details": {
    "player_id": "p123",
    "player_name": "Star QB",
    "untouchable_type": "franchise_qb"
  },
  "message": "Franchise QB not available for trade"
}
```

#### 4. Positional Constraint
```gdscript
{
  "reason": "positional_constraint",
  "details": {
    "position": "QB",
    "current_depth": 2,
    "minimum_depth": 2,
    "healthy_count": 1
  },
  "message": "Cannot trade only healthy QB"
}
```

#### 5. Cap Space
```gdscript
{
  "reason": "cap_space_insufficient",
  "details": {
    "cap_space": 5.0,
    "player_contract": 15.0,
    "shortfall": 10.0
  },
  "message": "Insufficient cap space to absorb contract"
}
```

#### 6. Team Status Mismatch
```gdscript
{
  "reason": "team_status_mismatch",
  "details": {
    "our_status": "contender",
    "trade_type": "future_value",
    "preferred_type": "win_now"
  },
  "message": "Contender not interested in future assets"
}
```

#### 7. Roster Construction
```gdscript
{
  "reason": "roster_construction",
  "details": {
    "position": "RB",
    "current_count": 6,
    "issue": "already_have_surplus"
  },
  "message": "Already have surplus at RB, no need to add more"
}
```

#### 8. Contract Situation
```gdscript
{
  "reason": "bad_contract",
  "details": {
    "player_value": 8.0,
    "annual_value": 18.0,
    "overpay_ratio": 2.25
  },
  "message": "Will not absorb overpaid contract"
}
```

---

## Realistic Trade Patterns

### Pattern 1: Injury Replacement

**Scenario**: Starting QB tears ACL week 2

**Behavior**:
1. Injured team's temperature spikes (0.3 → 0.8)
2. System identifies positional need (QB, severity 0.9)
3. Scans league for teams with QB surplus
4. Finds team with 3 QBs on roster
5. Initiates trade: injured team's 2nd round pick for backup QB
6. Accepting team gets future value, has depth to spare

**Realistic Elements**:
- Urgency drives trade (wouldn't happen without injury)
- Acquiring team "overpays" (40% value diff, but urgency allows)
- Selling team has expendable asset (3rd QB)
- Both teams' needs aligned

### Pattern 2: Deadline Push

**Scenario**: 8-3 team weak at CB, trade deadline approaching

**Behavior**:
1. Contender identifies weakness (CB depth below average)
2. Week 10 deadline creates urgency
3. Scans rebuilders (2-9, 3-8 teams) for veteran CBs
4. Finds 3-8 team with 28-year-old CB (rating 78)
5. Trade: contender's 1st round pick for veteran CB
6. Rebuilder gets future asset, trades aging player

**Realistic Elements**:
- Deadline urgency (wouldn't trade 1st rounder in offseason)
- Contender trades future for present
- Rebuilder trades present for future
- Win-win: aligned timelines

### Pattern 3: Cap Casualty

**Scenario**: Team over cap by $12M, must cut players or trade

**Behavior**:
1. Team's cap crisis triggers must_shed_salary flag
2. Temperature spikes (0.4 → 0.85, desperate)
3. Identifies high-salary players to move
4. Finds team with cap space needing that position
5. Trade: $15M/year DE for 5th round pick
6. Team accepts terrible value to avoid releasing player for nothing

**Realistic Elements**:
- Desperation overrides fair value (accepts 60% value loss)
- Receiving team gets bargain due to leverage
- Cap rules force trade (realistic constraint)
- Division rival penalty waived (cap crisis exception)

### Pattern 4: Rejected Trade (Division Rival)

**Scenario**: Cowboys try to trade with Eagles

**Behavior**:
1. Cowboys have surplus RB (4 on roster)
2. Eagles have RB injury, need replacement
3. System identifies complementary needs
4. Calculates trade: Cowboys RB (value 12.0) for Eagles 4th round pick (value 8.0)
5. Division rival penalty applies: 12.0 * 1.5 = 18.0 required
6. Eagles must offer 18.0 value (3rd round pick instead)
7. Eagles refuse (won't give 3rd for RB worth 12.0)
8. Trade rejected

**Realistic Elements**:
- Perfect match on paper (need + surplus)
- Rivalry prevents trade (penalty too high)
- Both teams walk away (no deal better than bad deal)
- Matches real NFL behavior (NFC East rarely trades internally)

### Pattern 5: Rejected Trade (Untouchable)

**Scenario**: Team attempts to trade franchise QB

**Behavior**:
1. 6-6 bubble team exploring all options
2. Receives mega-offer: 3 first-round picks for QB
3. QB is age 27, rating 88, franchise cornerstone
4. QB in untouchables list (age <30, rating >80)
5. Trade rejected despite incredible value
6. Reason: "Cannot trade franchise QB"

**Realistic Elements**:
- Value isn't everything (organizational importance)
- Some players transcend pure value calculation
- Team identity players protected
- Matches real NFL (Mahomes, Allen, Burrow not available at any price)

---

## Anti-Patterns (What NOT To Allow)

### Anti-Pattern 1: Fantasy Football Trading
```
BAD: User offers 3 terrible players for 1 star
AI accepts because "total value equals"
```

**Prevention**: Don't allow 3-for-1 trades in Phase 1. Only 1-for-1 player trades.

### Anti-Pattern 2: Lopsided "Realistic" Trades
```
BAD: Team trades franchise QB for 7th round pick because "team is rebuilding"
```

**Prevention**: Untouchables list prevents core players from being traded regardless of team status.

### Anti-Pattern 3: Trade Spam
```
BAD: Team makes 5 trades in single week, constantly churning roster
```

**Prevention**: One trade per team per trade window. Realistic cooling-off period.

### Anti-Pattern 4: Same Division Trades Too Common
```
BAD: NFC East teams trade with each other 30% of the time
```

**Prevention**: Division rival penalty ensures <10% of trades are intra-division.

### Anti-Pattern 5: No Context Trades
```
BAD: Contending team trades star player for draft picks with no motivation
```

**Prevention**: Team status dictates trade strategy. Contenders don't rebuild mid-season.

---

## Behavioral Validation Tests

### Test 1: Trade Frequency
```gdscript
func test_trade_frequency():
  var total_trades := 0
  for year in range(20):
    var year_trades := _count_trades_in_year(year)
    total_trades += year_trades

  var avg_per_year := total_trades / 20.0
  assert(avg_per_year >= 10.0 and avg_per_year <= 25.0, "Trade frequency realistic")
```

### Test 2: Division Rival Trades
```gdscript
func test_division_rival_frequency():
  var total_trades := _count_all_trades()
  var division_trades := _count_division_rival_trades()
  var pct := float(division_trades) / float(total_trades)

  assert(pct < 0.10, "Division trades <10% of total")
```

### Test 3: Franchise QB Protection
```gdscript
func test_franchise_qb_protection():
  var franchise_qbs := _identify_franchise_qbs()  # Age <30, rating >80

  for qb in franchise_qbs:
    var traded := _was_player_traded(qb.id)
    assert(not traded, "Franchise QB never traded")
```

### Test 4: Contender Behavior
```gdscript
func test_contender_behavior():
  var contenders := _get_teams_with_status("contender")

  for team in contenders:
    var trades := _get_team_trades(team.id)

    for trade in trades:
      # Contenders should keep core young players
      var gave_young_star := _check_young_star_traded(trade, team.id)
      assert(not gave_young_star, "Contender doesn't trade young stars")
```

### Test 5: Value Fairness
```gdscript
func test_value_fairness():
  var all_trades := _get_all_trades()

  for trade in all_trades:
    var pct_diff := trade.value_pct_diff
    var tolerance := _calculate_tolerance(trade)

    assert(pct_diff <= tolerance, "All trades within tolerance bounds")
```

---

## Configuration Tuning Guide

### Trade Frequency Tuning

**Too Many Trades** (>25/year):
```json
{
  "trade_windows": {
    "pre_draft": {"trade_frequency": 0.15},    // Reduce from 0.2
    "preseason": {"trade_frequency": 0.25},    // Reduce from 0.3
    "midseason": {"trade_frequency": 0.10},    // Reduce from 0.15
    "deadline": {"trade_frequency": 0.30}      // Reduce from 0.4
  }
}
```

**Too Few Trades** (<10/year):
```json
{
  "trade_windows": {
    "pre_draft": {"trade_frequency": 0.25},    // Increase
    "preseason": {"trade_frequency": 0.35},
    "midseason": {"trade_frequency": 0.20},
    "deadline": {"trade_frequency": 0.50}
  }
}
```

### Rivalry Penalty Tuning

**Too Many Division Trades** (>15%):
```json
{
  "division_rival_penalty": 2.0  // Increase from 1.5 (100% premium)
}
```

**Too Few Division Trades** (<5%):
```json
{
  "division_rival_penalty": 1.25  // Reduce from 1.5 (25% premium)
}
```

### Value Tolerance Tuning

**Trades Too Lopsided**:
```json
{
  "trade_value_tolerance": 0.20  // Reduce from 0.30 (stricter fairness)
}
```

**Trades Too Rare** (teams can't agree):
```json
{
  "trade_value_tolerance": 0.40  // Increase from 0.30 (more lenient)
}
```

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-11 | Architecture Guardian | Initial realism guide |
