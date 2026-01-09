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

**Agent: Engineer**
1. Add HS fields to player dictionaries:
   - `hs_year`, `hs_grad_year`, `eligibility_status`, `hs_school_id`,
     `home_region`, `proximity_bias`.
2. Implement HS school generation with eliteness tiers
   (e.g., `scripts/world/HighSchoolGenerator.gd`):
   - Create schools with an `eliteness` rating and `region`.
   - Define assignment weights: elite schools attract stronger players,
     while allowing probabilistic outliers and proximity pulls.
3. Implement `scripts/world/HighSchoolAssignment.gd`:
   - Assign HS players to schools using eliteness-weighted randomness.
   - Include a proximity modifier based on `home_region` and
     player-specific `proximity_bias`.
4. Implement `scripts/world/HighSchoolSeason.gd`:
   - Calls `PlayerLifecycle.advance_one_year`.
   - Updates eligibility and graduation.
5. Provide minimal HS output stats to drive recruiting evaluation.

**Agent: Engineer**
1. Define HS performance distributions or simple stat templates.
2. Provide HS eliteness distribution, regional split, and assignment weights.
3. Provide config defaults for HS output (if needed).

**Agent: Review**
1. Ensure HS progression does not bypass lifecycle rules.
2. Confirm RNG handling is explicit and deterministic.

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
