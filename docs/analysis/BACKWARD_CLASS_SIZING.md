# Backward Class Sizing Analysis

**Date**: 2026-01-10
**Status**: Planning & Discussion Phase
**Approach**: Work backwards from NFL roster needs to determine optimal generation sizes

---

## 1. NFL Steady State (End Point)

### Roster Composition (Per Team)
```
Active roster:      53 players
Practice squad:     16 players
Injured reserve:    15 players
────────────────────────────────
Total per team:     84 players
```

### League Total
```
32 teams × 84 players = 2,688 total NFL players at steady state
```

---

## 2. NFL Annual Turnover

### Retirement Analysis

From `configs/sports/american_football/main.json` (lines 73-81):
```json
"retirement": {
    "min_age": 27,
    "soft_cap_age": 33,
    "max_age": 40,
    "base_chance": 0.02,
    "age_chance_per_year": 0.04,
    "low_rating_threshold": 55.0,
    "low_rating_boost": 0.08
}
```

**Retirement Probability by Age:**
- Age 27-32: 2% base chance
- Age 33: 2% + (33-33) × 4% = 2%
- Age 34: 2% + (34-33) × 4% = 6%
- Age 35: 2% + (35-33) × 4% = 10%
- Age 36: 2% + (36-33) × 4% = 14%
- Age 37+: 18%, 22%, 26%, 30%...
- Rating < 55: Add 8% to above chances

**Estimated Annual Retirements:**

Assuming age distribution of NFL rosters:
- Age 27-32 (60% of league = 1,613 players): 1,613 × 2% = **32 retirements**
- Age 33-35 (25% of league = 672 players): 672 × 6% avg = **40 retirements**
- Age 36+ (15% of league = 403 players): 403 × 20% avg = **81 retirements**

**Total estimated retirements per year: ~150-180 players**

### Other Turnover Sources

1. **Contract Expirations → Free Agency**
   - Typical NFL contracts: 1-5 years
   - Average contract length: ~2.5 years
   - Players per year with expiring contracts: 2,688 / 2.5 = **~1,075 players**
   - Of these:
     - ~70% re-sign with same team or other teams: 753 players
     - ~30% leave NFL (injuries, performance): 322 players

2. **Cut Players**
   - Preseason cuts, underperformers, cap casualties
   - Estimated: ~200-300 players/year
   - Most join free agent pool or leave league

### Total NFL Replacement Need

```
Retirements:           150-180 players
Cuts/departures:       200-300 players
────────────────────────────────────
Total spots to fill:   350-480 players/year
```

**Conservative estimate: ~400 players needed per year**

---

## 3. NFL Roster Filling Mechanisms

### Draft (Primary Source)
```
7 rounds × 32 teams = 224 draft picks per year
```

### Undrafted Free Agents (Secondary Source)

From `scripts/world/NflDraft.gd` line 152-154:
- Undrafted players stored in `undrafted_pool[year]`
- Available for UDFA signings

**Gap Analysis:**
```
Total need:           400 players
Draft picks:         -224 players
────────────────────────────────────
UDFA signings needed: ~176 players/year
```

### Free Agent Pool (Tertiary Source)

From `scripts/world/NflSeason.gd` lines 151-153:
- Players with expiring contracts → `free_agents[year]`
- Most re-sign somewhere, but ~30% exit league

**Bottom X% Quit Assumption:**
- Free agent pool size: ~1,075 players/year
- Bottom 30% (rating < 55, old, injured): ~322 players quit
- Top 70%: Re-sign somewhere: ~753 players

---

## 4. Draft Pool Size (College Graduates)

### Required Draft Pool Size

To support draft + UDFA:
```
Draft picks:          224 players
UDFA signings:       ~176 players
Competition buffer:    ×1.3 (30% don't make rosters)
────────────────────────────────────
Draft pool needed:    400 × 1.3 = ~520 players
```

**Conservative estimate: 500-600 draft-eligible players per year**

### Current Draft Pool Sources

From `scripts/world/CollegeSeason.gd` lines 94-103:

1. **College Seniors (Year 4+)** - Automatically draft eligible
2. **Early Declarations (Year 3)** - If rating >= 85

**Current Generation:**

130 colleges with average roster size of 85 players:
- Total college players: 130 × 85 = 11,050 players
- 4-year cycle: 11,050 / 4 = **2,763 seniors per year**
- Early declarations (juniors with rating >= 85): Estimated ~100-150/year
- **Total current draft pool: ~2,900 players/year**

### Waste in Draft Pool

```
Current draft pool:     2,900 players
Actually needed:         ~520 players
────────────────────────────────────────
Wasted generation:      2,380 players (82% waste!)
```

---

## 5. College Roster Requirements

### Roster Steady State

From `configs/sports/american_football/world/colleges.json`:
- 130 colleges
- Roster capacity: 75-105 players (default: 85)
- Total college players: 130 × 85 = **11,050 players**

### Annual College Recruiting Needs

**Attrition Sources:**
1. **Seniors graduating:** ~2,763/year
2. **Early declarations:** ~100-150/year
3. **Transfers out:** Not modeled yet (assume 0)
4. **Injury retirements:** Not modeled yet (assume 0)

**Total roster spots to fill:**
```
Seniors graduating:    2,763 players
Early declarations:      125 players
────────────────────────────────────
Recruiting class size: 2,888 players/year
```

**Average per college:**
```
2,888 total / 130 colleges = ~22.2 recruits per college/year
```

This matches the config! (`recruiting.class_size_min: 18, class_size_max: 26`)

---

## 6. High School Generation Requirements

### Recruiting Competition & Selectivity

Colleges compete for top prospects, so we need MORE than exact demand:

**Buffer Factors:**
1. **Selectivity:** Colleges want choices (1.3x multiplier)
2. **Regional distribution:** Not all players match all schools (1.1x)
3. **Position imbalances:** Some positions oversupplied, others undersupplied (1.05x)

**Combined buffer: ~1.5x**

### Required High School Generation

```
College recruiting need:  2,888 players
Selectivity buffer:        ×1.5
──────────────────────────────────────
HS generation per year:   4,332 players
```

**Proposed: 4,000-4,500 high school players per year**

### Current High School Pipeline

From `scripts/pipelines/AdvanceWorldYear.gd` lines 163-168:

1. Generate 2,000 players per year
2. Accumulate over 4 years (lines 167-168 show `append_array`)
3. Steady state pool: 2,000 × 4 = **8,000 high school players**
4. Recruit ~2,888 per year
5. Discard seniors not recruited: ~2,000 - recruitment shortfall

**Problem: Undersupply!**
```
HS pool steady state:    8,000 players (4-year accumulation)
Annual generation:       2,000 players
Recruitment demand:      2,888 players
────────────────────────────────────────
Shortfall:              -888 players/year!
```

**Wait, how does this work currently?**

The system recruits from ALL 4 years (freshmen through seniors), not just seniors:
- Pool of 8,000 players across all ages
- Colleges recruit best 2,888 from this pool
- Remaining ~5,112 players age out or remain in pool

But we're generating 2,000/year and recruiting 2,888/year... this creates a slow depletion!

---

## 7. Proposed Optimal Generation Sizes

### Working Backwards Summary

| Stage | Current | Needed | Waste | Recommendation |
|-------|---------|--------|-------|----------------|
| **NFL Rosters** | 2,688 | 2,688 | 0 | ✅ Correct |
| **Draft Picks** | 224 | 224 | 0 | ✅ Correct |
| **UDFA Signings** | ??? | ~176 | ??? | Need logic |
| **Draft Pool** | ~2,900 | ~520 | **-2,380 (82%)** | Reduce drastically |
| **College Recruiting** | 2,888 | 2,888 | 0 | ✅ Correct |
| **HS Generation** | 2,000 | **4,000-4,500** | **-2,000** | **INCREASE** |

### Key Findings

1. **High School Generation is UNDERSUPPLIED** ❌
   - Currently: 2,000/year
   - Need: 4,000-4,500/year
   - Must INCREASE by 100-125%

2. **College → Draft Pipeline is OVERSUPPLIED** ❌
   - Currently: ~2,900 draft-eligible/year
   - Need: ~520 draft-eligible/year
   - Waste: 2,380 players (82%)

3. **The Real Bottleneck: College Eligibility Rules**
   - ALL seniors auto-declared for draft
   - Should be: Only top X% declare for draft
   - Rest should: Graduate and leave football, or attempt UDFA

---

## 8. Optimization Strategies

### Option A: Increase HS Generation, Fix Draft Eligibility

**Changes:**
1. **Increase HS generation:** 2,000 → 4,500 per year
2. **Add draft declaration logic:**
   - Only players with rating >= 65 declare for draft
   - Others graduate and leave football
3. **Add UDFA signing phase:**
   - Sign top ~176 undrafted players
   - Bottom 80% quit football

**Expected Results:**
- HS pool size: 4,500 × 4 = 18,000 players (healthy competition)
- College recruitment: ~2,888 from 18,000 pool (top 16%)
- Draft declarations: ~520 seniors/juniors with rating >= 65
- UDFA pool: ~520 declared, 224 drafted, 176 sign as UDFA
- Waste: ~120 undrafted players quit (vs 2,380 currently)

**Benefits:**
- 95% reduction in draft pool waste
- Maintains college recruiting competition
- Realistic draft pool size

**Drawbacks:**
- Increases HS generation cost by 2.25x
- More memory for HS player pool

---

### Option B: Keep HS Generation, Filter Draft Pool Aggressively

**Changes:**
1. **Keep HS generation:** 2,000 per year
2. **Reduce college roster sizes:** 85 → 65 per school
3. **Add strict draft declaration threshold:** Rating >= 75
4. **Auto-retire low performers:** Players not drafted with rating < 60 quit

**Expected Results:**
- Total college players: 130 × 65 = 8,450 players
- Graduates per year: 8,450 / 4 = 2,113 players
- Draft declarations: ~450 with rating >= 75
- UDFA signings: ~176 from this pool
- Waste: ~274 undrafted players quit

**Benefits:**
- No increase in HS generation cost
- Reduces memory for college rosters

**Drawbacks:**
- Smaller college rosters feel unrealistic (FBS teams have 85-105)
- Recruiting pool smaller (may reduce competition)
- Still wastes 274 players in draft pool

---

### Option C: Dynamic Sizing Based on Actual Needs (Recommended)

**Changes:**
1. **Calculate HS generation dynamically:**
   ```gdscript
   func calculate_hs_generation_size(colleges: int, avg_class_size: float) -> int:
       var recruitment_demand = colleges * avg_class_size
       var buffer_for_competition = 1.5  # 50% extra for selectivity
       return int(recruitment_demand * buffer_for_competition)
   ```
   Result: 130 × 22.2 × 1.5 = **~4,333 players/year**

2. **Calculate draft pool dynamically:**
   ```gdscript
   func calculate_draft_threshold(graduates: Array, target_pool_size: int) -> float:
       # Sort graduates by rating descending
       graduates.sort_custom(func(a, b): return a.rating > b.rating)
       # Find rating of Nth player where N = target_pool_size
       if graduates.size() > target_pool_size:
           return graduates[target_pool_size - 1].get("rating", 50.0)
       else:
           return 0.0  # All players declare if not enough
   ```
   Result: Only top ~520 players declare for draft

3. **Add UDFA signing phase:**
   - After draft, sign top ~176 undrafted players to practice squads
   - Remaining undrafted players quit football

**Benefits:**
- Adapts to actual roster needs
- Minimal waste at every stage
- Maintains realistic competition
- No hardcoded thresholds (dynamic based on supply/demand)

**Implementation:**
- Phase 1: Increase HS generation to 4,333/year
- Phase 2: Add draft declaration threshold logic
- Phase 3: Add UDFA signing phase
- Phase 4: Add "quit football" logic for undrafted players

---

## 9. Bottom X% Quit Logic

### Free Agent Attrition

From user request: "assume maybe the bottom X% of free agents just quit the NFL"

**Proposed Logic:**
```gdscript
func filter_free_agents(free_agents: Array, quit_threshold: float = 55.0) -> Dictionary:
    var active_fa := []
    var quit_fa := []

    for player in free_agents:
        var rating := player.get("rating", 50.0)
        var age := player.get("age", 30)

        # Bottom X% quit based on rating + age
        var should_quit := false
        if rating < quit_threshold:
            should_quit = true
        elif age >= 35 and rating < 65:
            should_quit = true

        if should_quit:
            player["status"] = "retired"
            player["retirement_reason"] = "free_agent_attrition"
            quit_fa.append(player)
        else:
            active_fa.append(player)

    return {
        "active": active_fa,
        "quit": quit_fa
    }
```

**Expected Results:**
- Free agent pool: ~1,075 players/year
- Bottom 30% (rating < 55 or age 35+ and rating < 65): **~322 quit**
- Top 70%: Remain in free agent pool for re-signing

---

## 10. Bootstrap Optimization

### Current Bootstrap Generation

From initial analysis document:
- 20 historical years simulated during bootstrap
- Each year generates 2,000 draft class players
- Total: 20 × 2,000 = **40,000 players generated**

**Actually Needed for Bootstrap:**
- Fill initial NFL rosters: 2,688 players (one-time)
- Annual replacement during 20-year sim: 20 × 400 = 8,000 players
- Total needed: **~10,688 players**

**Waste: 40,000 - 10,688 = 29,312 players (73% waste!)**

### Optimized Bootstrap Generation

**Strategy:**
1. **Year 1:** Generate full NFL rosters = 2,688 players
2. **Years 2-20:** Generate only replacement needs = 400/year
3. **Total:** 2,688 + (19 × 400) = **10,288 players**

**Savings:**
- Current: 40,000 players
- Optimized: 10,288 players
- **Reduction: 74% fewer players generated during bootstrap**

**Memory Impact:**
- Current: 40,000 × 4KB = 160MB
- Optimized: 10,288 × 4KB = 41MB
- **Savings: 119MB (74% reduction)**

---

## 11. Recommended Implementation Plan

### Phase 1: Data Collection (No Code Changes)
1. Run 1-year simulation with current settings
2. Measure:
   - Actual recruitment from HS pool (demand vs supply)
   - Draft pool size and composition
   - Free agent attrition rates
3. Validate assumptions in this document

### Phase 2: Increase HS Generation
1. Change `class_size` config: 2000 → 4500
2. Test college recruiting still works
3. Measure memory and performance impact

### Phase 3: Add Draft Declaration Logic
1. Add `should_declare_for_draft()` function
2. Filter seniors by rating threshold (dynamic or fixed at 65)
3. Test draft pool size matches target (~520 players)

### Phase 4: Add UDFA Signing Phase
1. Create new phase: `nfl_udfa_signing`
2. Sign top ~176 undrafted players to practice squads
3. Test roster filling works correctly

### Phase 5: Add Free Agent Attrition
1. Filter free agents by rating/age after season
2. Move bottom 30% to "retired" status
3. Test free agent pool remains realistic

### Phase 6: Optimize Bootstrap
1. Add bootstrap-specific generation logic
2. Generate 2,688 in year 1, then 400/year
3. Measure bootstrap time and memory improvements

---

## 12. Expected Performance Impact

### Memory Savings
```
Current waste per year:
  Draft pool:       2,380 players × 4KB = 9.5MB

With optimization:
  Draft pool:         120 players × 4KB = 0.5MB

Savings: 9MB per year
Bootstrap savings: 119MB (one-time)
```

### Performance Impact
```
HS generation increase:
  2,000 → 4,500 players (+2,500 players)
  Generation time: +12.5 seconds per year

Draft pool reduction:
  2,900 → 520 players (-2,380 players)
  Scouting time: -20 seconds per draft (80% reduction)

Net impact: +12.5s HS, -20s draft = -7.5s per year (improvement!)
```

---

## Questions for Discussion

1. **HS Generation Increase:**
   - Are we comfortable increasing HS generation from 2,000 to 4,500?
   - Is 50% buffer (1.5x multiplier) appropriate for recruiting competition?

2. **Draft Declaration Threshold:**
   - Should we use fixed threshold (rating >= 65)?
   - Or dynamic threshold (top N players by rating)?
   - What about early declarations (juniors)?

3. **UDFA Signing:**
   - Should UDFA be a separate phase or part of draft?
   - How many UDFA signings are realistic (150-200)?

4. **Free Agent Attrition:**
   - Is 30% quit rate appropriate?
   - Should it vary by position/age/rating?

5. **Bootstrap:**
   - Can we use different generation sizes for bootstrap vs steady-state?
   - Impact on determinism/testing?

---

## References

**Config Files:**
- `configs/sports/american_football/main.json` - Retirement, class_size
- `configs/sports/american_football/world/league.json` - NFL rosters, draft
- `configs/sports/american_football/world/colleges.json` - College rosters, recruiting

**Code Files:**
- `scripts/pipelines/AdvanceWorldYear.gd` - HS generation (line 163-164)
- `scripts/world/CollegeSeason.gd` - Draft eligibility (lines 94-103)
- `scripts/world/NflDraft.gd` - Draft and undrafted pool (lines 152-154)
- `scripts/world/NflSeason.gd` - Free agents (lines 151-153)
