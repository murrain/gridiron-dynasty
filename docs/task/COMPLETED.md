# Completed Work

This document archives completed phases from the World Simulation Roadmap.
For current work, see `plan.md`.

---

## Phase 0: Discovery + Alignment (Complete)
**Goal:** Confirm existing capabilities and anchor the pipeline on the
current draft class generation + de-age flow as the HS baseline.

**Completed:**
- Inventoried generation/pipeline flow
- Confirmed HS baseline uses draft class generation + de-age
- Documented determinism boundaries
- Proposed data model additions for HS/college/draft tracking

**Key files:**
- `scripts/generation/PlayerGenerator.gd`
- `scripts/generation/DraftClassGenerator.gd`
- `scripts/generation/helpers/DeAger.gd`

---

## Phase 0.5: Deterministic Generation + Bootstrap Alignment (Complete)
**Goal:** Remove global RNG usage in class/scout generation and ensure
bootstrap flows are fully seed-driven for reproducibility.

**Completed:**
- Refactored draft class generators to accept explicit seeds/RNG
- Made per-thread seeds deterministic from single seed input
- Threaded RNG through de-aging and stat helpers
- Made scout creation deterministic
- Aligned bootstrap pipeline with deterministic seeds
- Seed lineage recorded in outputs/logs

**Key files:**
- `scripts/generation/DraftClassGenerator.gd`
- `scripts/generation/ClassGenerator.gd`
- `scripts/generation/PlayerGenerator.gd`
- `scripts/generation/helpers/DeAger.gd`
- `scripts/generation/ScoutFactory.gd`
- `scripts/pipelines/BootstrapWorld.gd`

---

## Phase 1: World Calendar + Phase Scheduler (Complete)
**Goal:** Create a deterministic year-by-year orchestration layer for
HS → college → NFL.

**Completed:**
- Defined phase order and boundaries for yearly cycle
- Created calendar config schema with explicit phase IDs
- Implemented `WorldCalendar.gd` to load and validate calendar config
- Implemented `AdvanceWorldYear.gd` to orchestrate phases
- Added placeholder phase handlers with explicit TODOs
- RNG seeding explicit and recorded per phase

**Key files:**
- `configs/sports/american_football/world/calendar.json`
- `scripts/world/WorldCalendar.gd`
- `scripts/pipelines/AdvanceWorldYear.gd`

---

## Phase 2: High-School Generation + Progression + Assignment (Complete)
**Goal:** Build HS schools with varied eliteness, assign players, and
advance them year-by-year with explicit eligibility rules.

**Completed:**
- Added HS fields to player dictionaries (`hs_year`, `hs_grad_year`,
  `eligibility_status`, `hs_school_id`, `home_region`, `proximity_bias`)
- Implemented HS eligibility lifecycle transitions
- Implemented HS school generation with eliteness tiers
- Implemented HS assignment with weighted randomness
- Implemented HS season progression via `PlayerLifecycle.advance_one_year`
- Added HS config validation
- Emit stable recruit pool format for college recruiting

**Key files:**
- `scripts/world/HighSchoolGenerator.gd`
- `scripts/world/HighSchoolAssignment.gd`
- `scripts/world/HighSchoolSeason.gd`
- `configs/sports/american_football/world/high_schools.json`

---

## Phase 2.5: Determinism Cleanup for Generation + Lifecycle (Complete)
**Goal:** Close remaining determinism gaps so generation and lifecycle
steps are fully seed-driven.

**Completed:**
- Removed global RNG usage in class generation + helpers
- Threaded explicit RNG through scout generation
- Made player lifecycle RNG mandatory
- Aligned bootstrap scripts with explicit seeds
- Preserved deterministic per-thread seed derivation

**Key files:**
- All generation helpers under `scripts/generation/helpers/`
- `scripts/world/PlayerLifecycle.gd`
- `scripts/pipelines/BootstrapWorld.gd`
- `scripts/pipelines/GenerateClassOnce.gd`

---

## Phase 3: College Generation + Recruiting Pipeline (Complete)
**Goal:** Generate colleges, then turn HS recruits into college
commitments deterministically.

**Completed:**
- Implemented college generation with tiered eliteness, regional tags
- Implemented `CollegeRecruiting.gd` with scout-based boards
- Incorporated proximity bias for nearby programs
- Implemented offer/visit/commit flow with explicit RNG
- Emit committed recruits with stable output format

**Key files:**
- `scripts/world/CollegeGenerator.gd`
- `scripts/pipelines/CollegeRecruiting.gd`
- `configs/sports/american_football/world/colleges.json`

---

## Phase 3.5: Test Coverage Expansion (Complete)
**Goal:** Close deterministic test gaps for generation, recruiting, and
pipeline orchestration.

**Completed tests:**
- `test_recruit_rater.gd`: percentile/star threshold logic
- `test_scout_runtime.gd`: deterministic scout scoring
- `test_scout_model.gd`: Scout resource scoring and bounds
- `test_scout_factory.gd`: deterministic scout generation
- `test_class_generator.gd`: class generation steps
- `test_draft_class_generator.gd`: class tagging + seed path
- `test_college_recruiting.gd`: deterministic offers/commitments
- `test_advance_world_year_helpers.gd`: phase seed derivation
- `test_pipeline_seed_helpers.gd`: bootstrap/future/one-shot seeds
- `test_core_utilities.gd`: App.map_parallel, RngBox, Threader
- `test_player_model.gd`: Player serialization round-trip

---

## Phase 3.6: Contract + Player Development Test Completeness (Complete)
**Goal:** Validate contract/development coverage.

**Completed tests:**
- `test_cap_accounting.gd`
- `test_cap_validation_flow.gd`
- `test_player_lifecycle.gd`
- `test_player_lifecycle_reports.gd`
- `test_high_school_season.gd`
- `test_contract_lifecycle.gd`
- `test_contract_valuation.gd`
- `test_valuation_flow.gd`
- `test_team_roster_models.gd`
- `test_development_context.gd`

---

## Existing Infrastructure (Reference)

**Preview Scenes:**
- `bootstrap_preview.tscn` / `BootstrapPreview.gd`
- `world_history_preview.tscn` / `WorldHistoryPreview.gd`
- `player_gen_benchmark.tscn`
- `generate_once.tscn`

**Core Models:**
- `scripts/core/models/Player.gd`
- `scripts/core/models/Team.gd`
- `scripts/core/models/Roster.gd`
- `scripts/core/models/Scout.gd`
- `scripts/core/models/Coach.gd`

**World Components:**
- `scripts/world/PlayerLifecycle.gd`
- `scripts/world/ContractLifecycle.gd`
- `scripts/world/ValuationFlow.gd`
- `scripts/world/CapValidationFlow.gd`
- `scripts/world/LeagueContainer.gd`

**Autoloads:**
- `autoloads/Config.gd`
- `autoloads/App.gd`
- `autoloads/Rand.gd`
- `autoloads/RngBox.gd`
