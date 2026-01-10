# World Simulation Roadmap (HS → College → NFL)

This plan breaks the work into bite-sized chunks and provides explicit
instructions for agents. Keep the scope tight and deterministic.

## Working agreements (all agents)
- Prefer explicit state transitions over hidden state.
- RNG must be passed explicitly; seeds logged or persisted per phase.
- Keep changes small and reviewable.
- Avoid UI unless required by simulation correctness.

## Phase 0: Discovery + alignment
**Goal:** Confirm existing capabilities and anchor the pipeline on the
current draft class generation + de-age flow as the HS baseline.

**Agent: Review**
1. Inventory current generation/pipeline flow and confirm HS baseline:
   - Draft class generation + de-age as HS class source.
   - `scripts/generation/PlayerGenerator.gd`
   - `scripts/generation/DraftClassGenerator.gd`
   - `scripts/generation/helpers/DeAger.gd`
2. Note determinism boundaries and any global RNG usage.
3. Produce a short findings note for the team (bulleted list).

**Agent: Architect**
1. Propose the minimal data model additions needed for:
   - HS year/grad tracking
   - College roster membership
   - Draft eligibility/declaration status
2. Document the proposed fields and lifecycle transitions.
3. Call out any architecture-impacting risks.

---

## Phase 0.5: Deterministic generation + bootstrap alignment
**Goal:** Remove global RNG usage in class/scout generation and ensure
bootstrap flows are fully seed-driven for reproducibility.

**Agent: Engineer**
1. Refactor draft class generators to accept explicit seeds/RNG:
   - `scripts/generation/DraftClassGenerator.gd`
   - `scripts/generation/ClassGenerator.gd`
   - Replace `seed()/randomize()` usage with passed seed inputs.
2. Make per-thread seeds deterministic from a single seed input:
   - `scripts/generation/PlayerGenerator.gd`
   - Replace `randi()/randf_range()/randfn()` with `RandomNumberGenerator`.
   - Ensure combine and freak assignment use derived RNGs.
3. Thread RNG through de-aging and stat helpers:
   - `scripts/generation/helpers/DeAger.gd`
   - `scripts/generation/StatHelpers.gd`
   - Require RNG inputs (no fallback to global RNG).
4. Make scout creation deterministic:
   - `scripts/generation/ScoutFactory.gd`
   - Accept RNG in `create_random_scout`.
   - Avoid `rng.randomize()` defaults in team scout creation unless
     explicitly called from tooling.
5. Align bootstrap pipeline with deterministic seeds:
   - `scripts/pipelines/BootstrapWorld.gd`
   - Derive per-class and per-advance seeds from base seed + year.
   - Pass RNG explicitly to `PlayerLifecycle.advance_years`.
6. Record seed lineage in outputs or logs for the above pipelines.

**Agent: Review**
1. Verify no generation/scouting paths depend on global RNG calls.
2. Confirm seed lineage is explicit and auditable in logs/outputs.
3. Check threading paths for deterministic seed derivation.

---

## Phase 1: World calendar + phase scheduler
**Goal:** Create a deterministic year-by-year orchestration layer for
HS → college → NFL.

**Agent: Architect**
1. Define the phase order and boundaries for a yearly cycle:
   - HS season → recruiting → college season → draft prep → NFL draft.
2. Specify the minimal scheduler interface and data contracts:
   - Input: year index, world state handle, RNG seed tuple.
   - Output: ordered list of phase descriptors with explicit phase ids,
     start/end boundaries, and seed lineage.
   - Define a stable phase id naming scheme (e.g., `hs_season`,
     `hs_recruiting`, `college_season`, `draft_prep`, `nfl_draft`).
3. Define logging/trace expectations for phase boundaries:
   - Each phase must emit start/end with year + phase id + seed used.
   - Ensure phase logs allow re-running a single phase deterministically.
4. Document how phases map to existing pipeline steps:
   - Identify existing generators or lifecycle steps used in Phase 1.
   - Note which steps are placeholders vs. implemented.
5. Mark architecture-impacting risks or open questions:
   - e.g., how to represent phase outputs without coupling to UI.
6. Status: Complete (Architect).

**Agent: Engineer**
1. Add a calendar config (e.g., `configs/world/calendar.json`) that
   includes HS generation, HS season, and HS assignment steps per year.
2. Define calendar schema in config with explicit phase ids and ordering:
   - Include optional metadata fields for future phases (college/nfl).
   - Keep the schema minimal and deterministic (no computed defaults).
3. Implement `scripts/world/WorldCalendar.gd` to:
   - Load calendar config and validate required fields.
   - Emit ordered phase descriptors with year context.
4. Implement `scripts/pipelines/AdvanceWorldYear.gd` to:
   - Accept world state + seed input.
   - Iterate phases, calling phase handlers by id.
   - Record per-phase seed derivations and outputs.
   - Return a structured summary (phase id, seed used, outputs).
5. Add placeholder phase handlers for non-Phase1 steps:
   - No-op handlers with explicit TODOs and determinism notes.
6. Ensure RNG seeding is explicit and recorded per phase:
   - Derive per-phase seeds from the year seed.
   - Persist seeds in logs or structured outputs.

**Agent: Review**
1. Verify scheduler interfaces are deterministic and modular:
   - Phase ordering stable for fixed config.
   - Phase handlers are pure-ish with explicit inputs/outputs.
2. Confirm no simulation logic is hidden inside UI or tooling.
3. Validate seed derivation is explicit and auditable in logs/outputs.

---

## Phase 2: High-school generation + progression + assignment
**Goal:** Build HS schools with varied eliteness, assign players, and
advance them year-by-year with explicit eligibility rules.
**Implementation note:** Phase 2 requires new HS config defaults and
world-state containers; add them if missing before wiring handlers.

**Agent: Engineer**
1. Add HS fields to player dictionaries:
   - `hs_year`, `hs_grad_year`, `eligibility_status`, `hs_school_id`,
     `home_region`, `proximity_bias`.
2. Define HS eligibility lifecycle transitions and logging:
   - `hs_year` increments yearly.
   - `eligibility_status` transitions (`hs_underclass` → `hs_upperclass` → `hs_grad`).
   - Emit per-player transition logs with old/new values.
3. Implement HS school generation with eliteness tiers
   (e.g., `scripts/world/HighSchoolGenerator.gd`):
   - Create schools with an `eliteness` rating and `region`.
   - Define assignment weights: elite schools attract stronger players,
     while allowing probabilistic outliers and proximity pulls.
4. Implement `scripts/world/HighSchoolAssignment.gd`:
   - Assign HS players to schools using eliteness-weighted randomness.
   - Include a proximity modifier based on `home_region` and
     player-specific `proximity_bias`.
5. Implement `scripts/world/HighSchoolSeason.gd`:
   - Calls `PlayerLifecycle.advance_one_year`.
   - Updates eligibility and graduation.
6. Provide minimal HS output stats to drive recruiting evaluation.
7. Define HS school schema + defaults:
   - Required fields: `id`, `name`, `region`, `eliteness`.
   - Optional fields: `capacity`, `metadata`.
   - Provide defaults for eliteness tiers and regional distribution.
8. Define assignment weighting formula:
   - Combine eliteness, proximity, and player strength into a single weight.
   - Specify proximity bias scale and region match multiplier.
   - Define deterministic tie-break rules.
9. Specify HS season output stat bundle:
   - Emit a minimal, stable set of recruiting-facing stats (e.g., `hs_performance_score` or
     compact stat line).
   - Document how the stat bundle is derived and its deterministic guarantees.
10. Add HS config validation:
   - Distribution sums, non-overlapping tiers, non-empty regions.
   - Fail-fast with explicit errors on invalid configs.

**Agent: Engineer**
1. Define HS performance distributions or simple stat templates.
2. Provide HS eliteness distribution, regional split, and assignment weights.
3. Provide config defaults for HS output (if needed).
4. Add Phase 2 world-state containers for HS entities:
   - `world.hs_schools`, `world.hs_players`, and any lookup indices.
   - Use these containers for all HS steps (no ad-hoc globals).
5. Add Phase 2 RNG derivation spec:
   - Derive per-step RNG seeds from the year seed + phase id + step id.
   - Log seed lineage per step (`hs_school_gen`, `hs_assignment`, `hs_season`).
6. Define Phase 2 handler contract:
   - Handler signature inputs (world, seed, year) and explicit outputs
     (updated world + structured summary).
7. Add Phase 2-to-Phase 3 recruiting handoff:
   - Emit a stable HS recruit pool format for `CollegeRecruiting.gd`.
   - Map HS stat bundle and eligibility status into a `recruit_profile`.
   - Ensure regional tags and school ids align with Phase 3 college regions.

**Agent: Review**
1. Ensure HS progression does not bypass lifecycle rules.
2. Confirm RNG handling is explicit and deterministic.

---

### Phase 2 carryover (schedule during Phase 3+)
**Goal:** Finish Phase 2 elements that are still missing in code.

**Agent: Engineer**
1. Implement HS school generation with eliteness tiers and regional tags.
2. Implement HS assignment logic with eliteness, proximity, and player strength weighting.
3. Add HS player fields (`hs_year`, `hs_grad_year`, `eligibility_status`,
   `hs_school_id`, `home_region`, `proximity_bias`) and lifecycle transitions.
4. Implement HS season progression via `PlayerLifecycle.advance_one_year`,
   including eligibility and graduation updates.
5. Define HS stat output bundle for recruiting and emit a stable recruit pool
   handoff to `CollegeRecruiting.gd`.
6. Add HS config schemas/defaults and validation (tier distributions, regions,
   non-overlapping tiers).
7. Introduce explicit per-step RNG derivation and log seed lineage for HS steps.

**Agent: Review**
1. Verify HS steps are deterministic with explicit RNG usage.
2. Confirm lifecycle transitions are logged and auditable.

---

## Phase 2.5: Determinism cleanup for generation + lifecycle backfill
**Goal:** Close remaining Phase 0.5 determinism gaps before Phase 3
work so generation and lifecycle steps are fully seed-driven.

**Agent: Engineer**
1. Remove global RNG usage in class generation + helpers:
   - `scripts/generation/DraftClassGenerator.gd`
   - `scripts/generation/ClassGenerator.gd`
   - `scripts/generation/PlayerGenerator.gd`
   - `scripts/generation/helpers/DeAger.gd`
   - `scripts/generation/helpers/NamesHelper.gd`
   - `scripts/generation/helpers/PositionHelper.gd`
   - `scripts/generation/helpers/StatsHelper.gd`
   - `scripts/generation/helpers/PhysicalsHelper.gd`
2. Thread explicit RNG through scout generation:
   - `scripts/generation/ScoutFactory.gd`
   - Ensure `create_random_scout` accepts RNG input with no implicit
     `randomize()` defaults.
3. Make player lifecycle RNG mandatory (no implicit randomize):
   - `scripts/world/PlayerLifecycle.gd`
   - Require RNG inputs for `advance_years` and `advance_one_year`.
4. Align bootstrap and one-off generation scripts with explicit seeds:
   - `scripts/pipelines/BootstrapWorld.gd`
   - `scripts/pipelines/GenerateClassOnce.gd`
   - Ensure seed lineage is logged and derived from config + year.
5. Preserve deterministic per-thread seed derivation:
   - Replace `randi()` fan-out with derived seeds from a parent RNG.
   - Document the seed derivation method in comments (why chosen).

**Agent: Review**
1. Audit for any remaining `randomize()` or global RNG calls in
   generation/scouting/lifecycle code paths.
2. Confirm seed lineage is explicit and logged for generation and
   bootstrap flows.

---

## Phase 3: College generation + recruiting pipeline
**Goal:** Generate colleges, then turn HS recruits into college
commitments deterministically.

**Agent: Engineer**
1. Implement college generation (e.g., `scripts/world/CollegeGenerator.gd`)
   with tiered eliteness, regional tags, and roster capacities.
2. Add `scripts/pipelines/CollegeRecruiting.gd`.
3. Use `Scout.score_player` and `RecruitRater` to build team boards.
4. Incorporate proximity bias so some recruits favor nearby programs even
   when eliteness is lower.
5. Implement offer/visit/commit flow with explicit RNG.
6. Emit committed recruits with a stable output format.

**Agent: Engineer**
1. Provide baseline recruiting tuning (weights, interest curves).
2. Define college tier distributions, regional splits, and strength ranges.
3. Supply any name lists or school archetypes if needed.

**Agent: Review**
1. Verify recruiting logic does not embed hardcoded magic numbers.
2. Confirm separation between evaluation and commitment mechanics.

---

## Phase 3.5: Test coverage expansion
**Goal:** Close deterministic test gaps for generation, recruiting, and
pipeline orchestration so Phase 4 builds on verified foundations.

**Agent: Engineer**
1. Add deterministic coverage for recruiting/scouting ratings:
   - `scripts/core/rating/RecruitRater.gd`
   - `scripts/core/scouting/ScoutRuntime.gd`
   - `scripts/core/models/Scout.gd`
   - `scripts/generation/ScoutFactory.gd`
   - Ensure tests cover percentile logic, star thresholds, scout
     perception noise, and deterministic seeding.
2. Add orchestration coverage for class generation:
   - `scripts/generation/ClassGenerator.gd`
   - `scripts/generation/DraftClassGenerator.gd`
   - Validate tagging (`class_tag`, `draft_year`), potential copy, and
     de-aging steps with fixed seeds.
3. Add pipeline coverage for world + college steps:
   - `scripts/pipelines/AdvanceWorldYear.gd`
   - `scripts/pipelines/BootstrapWorld.gd`
   - `scripts/pipelines/GenerateFutureDraftClasses.gd`
   - `scripts/pipelines/GenerateClassOnce.gd` (smoke test if headless-friendly)
   - `scripts/pipelines/CollegeRecruiting.gd`
   - `scripts/world/CollegeGenerator.gd`
   - Validate phase ordering, seed lineage outputs, and deterministic
     commitments/offers.
4. Add core utility/model coverage:
   - `scripts/core/models/Player.gd` (round-trip serialization)
   - `autoloads/App.gd` (thread count/map_parallel behavior)
   - `autoloads/RngBox.gd` (per-thread RNG isolation sanity)
   - `scripts/support/threading/Threader.gd` (index coverage)
5. Register new test scripts in `scripts/tests/TestRunner.gd`.

**Agent: Review**
1. Verify new tests are deterministic with explicit RNG usage.
2. Confirm tests cover seed lineage outputs for pipeline steps.

---

## Phase 4: Team + roster scaffolding
**Goal:** Provide minimal containers for players across HS/college/NFL.

**Agent: Architect**
1. Define minimal Team and Roster models:
   - id, name, level, roster_slots, metadata.
2. Specify how rosters are referenced in pipelines.
3. Define a Coach model and how it attaches to teams.

**Agent: Engineer**
1. Implement `scripts/core/models/Team.gd` and `Roster.gd`.
2. Add a `scripts/world/LeagueContainer.gd` for level grouping.
3. Add roster assignment helpers in `scripts/world/`.
4. Implement a `scripts/core/models/Coach.gd` with coaching-specific stats
   (play-calling, development, scheme fit, etc.).
5. Attach head coaches to teams in the league container.

**Agent: Review**
1. Confirm scaffolding remains minimal (no full simulation).
2. Validate deterministic handling of roster placement.
3. Ensure Coach model scopes to team-level behavior only.

---

## Phase 5: College progression + NFL draft entry
**Goal:** Move college players through seasons into draft eligibility.

**Agent: Engineer**
1. Implement a `CollegeSeason.gd` step:
   - Calls `PlayerLifecycle.advance_one_year`.
   - Updates class year and eligibility.
2. Add a `DraftEligibility.gd` helper:
   - Seniors auto-eligible.
   - Early declarations via explicit RNG.
3. Record eligibility state on players.
4. Add a path for retired players to enter a coach candidate pool.
5. Implement a lightweight coach generation path mirroring player generation
   (shared RNG, separate coaching stat distributions).

**Agent: Review**
1. Check eligibility transitions are explicit and auditable.
2. Confirm RNG boundaries are documented.
3. Ensure player-to-coach transitions are explicit and optional.

---

## Phase 6: NFL teams + draft pipeline
**Goal:** Generate NFL teams, scout players, and assign via draft.

**Agent: Engineer**
1. Implement NFL team generation (e.g., `scripts/world/NflTeamGenerator.gd`)
   or add NFL teams to the league container.
2. Implement `scripts/pipelines/NflDraft.gd`:
   - Build draft pool.
   - Order teams deterministically.
   - Use team scouts to rate players.
   - Select players using ratings/potential heuristics.
3. Assign drafted players to NFL rosters.
4. Record draft results with stable schema.
5. Generate or assign head coaches per team if missing.

**Agent: Review**
1. Verify no hidden randomness.
2. Confirm draft order and selection are reproducible.

---

## Phase 7: Integration + validation
**Goal:** Tie phases together and validate determinism.

**Agent: Engineer**
1. Integrate HS → recruiting → college → draft into `AdvanceWorldYear`.
2. Add a deterministic smoke test or scripted run.

**Agent: Review**
1. Validate end-to-end determinism with fixed seeds.
2. Confirm logs or outputs expose RNG seeds per phase.
