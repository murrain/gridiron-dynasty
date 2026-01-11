# Class Generation Sizing Analysis

**Status**: Planning & Discussion Phase
**Date**: 2026-01-10
**Goal**: Right-size player generation to match actual roster needs

## Current State

### Generation per Year

The system currently generates **~4000 players per year** across two pipelines:

1. **High School Class** (line 163-164 in `AdvanceWorldYear.gd`)
   - Uses: `DraftClassGenerator.generate_for_year()`
   - Size: **2000 players**
   - Source: `main.json` `class_size: 2000`
   - Purpose: Feed college recruiting pipeline

2. **Draft Class** (used during bootstrap in `BootstrapWorld.gd`)
   - Uses: `DraftClassGenerator.generate_for_year()`
   - Size: **2000 players**
   - Source: Same config (`class_size: 2000`)
   - Purpose: Feed NFL rosters during world bootstrap

**Total: 4000 players generated per year**

---

## Actual Roster Needs

### College Football (130 schools)

**Per School:**
- Roster capacity: 75-105 players
- Average: ~90 players per school
- Recruiting class size: 18-26 players per year
- Average: ~22 players per class

**Total College Demand:**
- 130 schools × 22 players/year = **2,860 players per year**

### NFL (32 teams)

**Per Team:**
- Active roster: 53 players
- Practice squad: 16 players
- Injured reserve: 15 players
- Total: 84 players per team

**Draft:**
- 7 rounds × 32 picks = **224 players drafted per year**

**Total NFL Demand:**
- Draft picks: 224 players
- Undrafted free agents: ~100-150 (estimated)
- **Total: ~350-400 players per year**

---

## The Problem: Massive Oversupply

### High School → College Pipeline

| Metric | Current | Needed | Waste |
|--------|---------|--------|-------|
| Generated | 2000 | 2,860 | **-860** (undersupplied!) |
| Recruited | ~2,860 | 2,860 | 0 |
| Unused | 0 | 0 | Wait, we're short! |

**Wait, this doesn't match the user's observation!**

Let me recalculate...

Actually, we need to account for:
- **Attrition**: Players graduate from college after 4-5 years
- **Not all high school players go to college**
- **Recruiting is selective** - colleges only take top prospects

So the 2000 high school players per year are competing for ~2,860 college spots, but:
- Many high school players aren't good enough
- Colleges are recruiting from 4-year age groups (freshmen through seniors)
- Need to check how many actually get recruited vs go unused

### College → NFL Pipeline

| Metric | Current | Needed | Waste |
|--------|---------|--------|-------|
| College graduates | ? | ~350-400 | ? |
| Draft eligible | ? | 224 (draft) | ? |
| Generated (bootstrap) | 2000 | ? | ? |

**Key Question**: How many college graduates do we have per year?

- 130 colleges × ~22.5 graduates/year = **2,925 graduates per year**
- NFL needs: ~350-400 players
- **Waste: ~2,500+ players go unused every year**

---

## Investigation Needed

Before we can right-size generation, we need to answer:

### 1. High School Pipeline Questions

**Q1**: How many high school players actually get recruited to colleges?
- Check: `CollegeRecruiting.gd` recruitment results
- Expected: ~2,860 per year (130 schools × 22 avg class size)
- Gap: If we're generating 2000 but need 2,860, we're **undersupplied by 860**

**Q2**: Are high school classes cumulative over multiple years?
- Check: Line 167-168 in `AdvanceWorldYear.gd`:
  ```gdscript
  var hs_players: Array = world_state.get("hs_players", []) as Array
  hs_players.append_array(players)  # CUMULATIVE!
  ```
- **Answer: YES!** High school players accumulate over 4 years
- So the pool is: 2000 × 4 = **8,000 high school players** at steady state
- Colleges recruit 2,860 from this pool of 8,000 each year
- **Waste: 5,140 players never recruited, discarded each year**

**Q3**: How many high school players graduate/age out each year?
- Check: Line 228 in `AdvanceWorldYear.gd` - `graduates: Array`
- Likely: ~2,000 seniors graduate per year (1 year cohort of the 4-year pool)
- Of these 2,000 seniors, only ~2,860 get recruited... wait, that's more than 2,000!

**This suggests we're pulling from multiple age groups, not just seniors.**

### 2. College → NFL Pipeline Questions

**Q1**: How many players declare for the NFL draft each year?
- Check: `draft_prep` phase in `AdvanceWorldYear.gd`
- Expected: Seniors + early declarations
- Colleges: 130 × ~22 = 2,860 players graduate → ~500-800 declare for draft?

**Q2**: What happens to undrafted players?
- Do they get added to NFL practice squads?
- Do they get discarded?
- Check: NFL draft and free agent logic

**Q3**: During bootstrap, why generate 2000 players per historical year?
- Bootstrap needs to fill NFL rosters (32 × 84 = 2,688 total players)
- Over 20 years, with retirement: need ~400 new players per year
- Generating 2000 per year for bootstrap means **1,600 wasted per year × 20 = 32,000 wasted players**

---

## Efficiency Analysis

### Current Waste Estimates

**High School Generation:**
- Generated per year: 2,000
- Cumulative pool (4 years): 8,000
- Recruited to college: ~2,860 per year
- Wasted per year: ~2,000 seniors who don't get recruited = **1,000+ wasted**

(Wait, math doesn't quite work. Need to trace actual flow.)

**Bootstrap Generation:**
- Generated per historical year: 2,000
- Actually needed: ~400 for NFL roster turnover
- Wasted per year: ~1,600
- Over 20-year bootstrap: **32,000 wasted players**

### Memory Impact

Each player dictionary is ~4KB (50+ fields including nested dicts for stats, potential, etc.)

**Wasted Memory:**
- High school waste: 1,000 players × 4KB = **4MB wasted per year**
- Bootstrap waste: 32,000 players × 4KB = **128MB wasted during 20-year bootstrap**
- Generation time: 2000 players × 5ms = **10 seconds wasted per year**

---

## Proposed Optimizations (Discussion)

### Option 1: Calculate Exact Needs

**High School:**
```
colleges = 130
avg_class_size = 22
buffer = 1.2  # 20% extra for choice/competition

hs_generation_size = colleges * avg_class_size * buffer
= 130 × 22 × 1.2
= 3,432 players per year
```

**NFL Draft:**
```
draft_picks = 224
undrafted_fa = 150  # estimate
buffer = 1.2

draft_generation_size = (draft_picks + undrafted_fa) * buffer
= 374 × 1.2
= ~450 players per year
```

**Savings:**
- High school: 2000 → 3432 (actually need MORE!)
- Draft: 2000 → 450 (**77.5% reduction**)
- Bootstrap (20 years): 40,000 → 9,000 players (**77.5% reduction**)

### Option 2: Dynamic Sizing Based on Roster Gaps

**Formula:**
```gdscript
func calculate_needed_class_size(
    colleges: int,
    avg_roster_size: int,
    avg_class_size: int,
    current_pool_size: int,
    target_pool_size: int
) -> int:
    # How many players do we need to maintain healthy pool?
    var annual_demand = colleges * avg_class_size
    var current_deficit = target_pool_size - current_pool_size
    var buffer_multiplier = 1.2  # 20% extra for selectivity

    return int((annual_demand + current_deficit) * buffer_multiplier)
```

**Benefits:**
- Adapts to actual roster needs
- Accounts for attrition and graduation
- Maintains healthy competition (buffer)
- Eliminates waste

### Option 3: Tiered Generation by Position Scarcity

**Insight**: Not all positions have equal demand.

- OL (5 starters × 130 = 650 needed per year)
- QB (1 starter × 130 = 130 needed per year)

**Position-aware generation:**
```
Generate more OL prospects, fewer QB prospects
Matches real college roster composition
Reduces waste while maintaining competition
```

---

## Questions for Discussion

1. **High School Pool Dynamics**:
   - Should we maintain a 4-year pool (8,000 players)?
   - Or generate just-in-time for recruiting (~3,500 per year)?
   - How does this affect recruiting competition?

2. **Bootstrap Optimization**:
   - Can we generate fewer players during bootstrap (450 vs 2000)?
   - Impact on roster depth and quality distribution?
   - Trade-off: Speed vs. realism?

3. **Position Distribution**:
   - Should generation match real roster position needs?
   - Current: Equal probability across all positions
   - Proposed: Weight by roster depth requirements

4. **Quality vs. Quantity**:
   - Do we need 2000 players to ensure quality distribution?
   - Or can 450 high-quality players suffice?
   - Impact on scouting, recruiting competitiveness?

5. **Backward Compatibility**:
   - Change config value (`class_size`) or add new fields?
   - Separate HS and draft class sizes?
   - Migration path for existing worlds?

---

## Next Steps

**Phase 1: Data Collection** (No code changes)
1. Run a 1-year simulation and measure:
   - How many HS players get recruited (actual vs. pool size)
   - How many college graduates declare for draft
   - How many undrafted players get signed
   - Actual waste numbers

2. Analyze position distribution in rosters vs. generated classes

3. Measure memory and performance impact of waste

**Phase 2: Design** (Still no code)
1. Design dynamic sizing formula
2. Define position-aware generation weights
3. Create config schema for new sizing parameters
4. Plan backward compatibility strategy

**Phase 3: Implementation**
1. Implement dynamic sizing in `ClassGenerator.gd`
2. Update config files with new parameters
3. Add position-aware generation
4. Write tests for new sizing logic

**Phase 4: Validation**
1. Run bootstrap with new sizes
2. Verify roster filling still works
3. Check recruiting competition remains realistic
4. Measure performance improvements

---

## References

**Config Files:**
- `configs/sports/american_football/main.json` - `class_size: 2000`
- `configs/sports/american_football/world/colleges.json` - Recruiting class sizes
- `configs/sports/american_football/world/league.json` - NFL roster limits

**Generation Code:**
- `scripts/generation/ClassGenerator.gd` - Base class generation
- `scripts/generation/DraftClassGenerator.gd` - Draft class generation
- `scripts/pipelines/AdvanceWorldYear.gd` - High school generation (line 163-164)
- `scripts/pipelines/BootstrapWorld.gd` - Bootstrap generation (line 33)

**Related Systems:**
- `scripts/pipelines/CollegeRecruiting.gd` - Measures actual recruitment
- `scripts/world/HighSchoolSeason.gd` - High school graduation
- `scripts/pipelines/NflDraft.gd` - Draft and UDFA signing
