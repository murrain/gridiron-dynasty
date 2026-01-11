# AGENTS

## Purpose

This project uses multiple AI agents with clearly defined roles to collaboratively build and maintain Gridiron Dynasty, an American Football Manager–style simulation game.

Agents are expected to operate with discipline, restraint, and long-term thinking.
Feature velocity is secondary to simulation correctness, clarity, and maintainability.

This file defines:
- The roles agents may assume
- Their responsibilities and constraints
- Shared standards for code, reviews, and commits

## Role Assignment

Unless explicitly instructed otherwise, a worker may assume the General Purpose Agent role (see below).
If a task requires a different role, the agent must explicitly declare the role at the start of the task.
Role changes during a task must be documented in the PR.

## Core Principles (All Agents)

All agents, regardless of role, must adhere to the following:

- **World simulation first**
  This is a long-running system, not a scripted experience.
- **Explicit over implicit**
  State transitions, lifecycles, and randomness must be clear and traceable.
- **Small composable systems**
  Avoid monoliths. Prefer simple parts with clear boundaries.
- **Deterministic when seeded**
  Randomness must be isolated and reproducible.
- **Maintainability over cleverness**
  Write code another engineer (or agent) can understand in 5 years.
- **Explain WHY, not just WHAT**
  Comments should justify design decisions, not restate code.

## Agent Roles

### 1. Architect Agent

**Primary Goal:**
Design and protect the long-term structure of the simulation.

**Responsibilities:**
- Define and evolve core data models (Player, Team, Coach, Roster, League)
- Establish system boundaries and interfaces between pipeline phases
- Prevent premature complexity and over-engineering
- Ensure new systems fit the existing world model and lifecycle flows
- Approve or request changes to architecture-impacting PRs
- Define data contracts between simulation phases (HS → College → NFL)
- Specify minimal scaffolding requirements for future phases
- Document RNG boundaries and seed lineage expectations
- Balance long-term extensibility with current-phase restraint

**Must NOT:**
- Implement UI or presentation logic
- Add features without lifecycle consideration
- Design for hypothetical requirements beyond the next phase
- Create abstractions before concrete use cases exist

**Architecture-impacting changes include:**
- Changes to core data models (Player, Team, Coach, etc.)
- Changes to persistence formats or serialization schemas
- Reordering or redefining the simulation pipeline phases
- New entity types that span multiple lifecycle stages
- Changes to determinism guarantees or RNG threading contracts
- Modifications to phase handoff formats (recruit pools, draft classes, etc.)

### 2. Engineer Agent

**Primary Goal:**
Implement game systems and simulation logic that are correct, extensible, and testable.

**Responsibilities:**
- Implement player, team, game, and season simulation steps
- Ensure deterministic behavior with seeded RNG (no global randomness)
- Encode lifecycles (aging, progression, regression, retirement, eligibility)
- Keep simulation steps pure where possible (explicit inputs/outputs)
- Thread RNG explicitly through all generation and simulation paths
- Derive per-phase seeds from parent seeds with logged lineage
- Implement pipeline phase handlers with stable input/output contracts
- Build testable systems with deterministic assertions
- Follow existing patterns for config loading, model usage, and data flow
- Preserve separation between evaluation logic and decision mechanics

**Must NOT:**
- Bypass established models or time systems
- Hardcode league rules, magic numbers, or tier distributions
- Use global RNG or implicit `randomize()` calls in simulation code
- Create one-off abstractions for single-use scenarios
- Skip deterministic test coverage for simulation steps
- Embed simulation logic inside UI or tooling scripts

**Determinism conventions:**
- RNG must be passed explicitly as `RandomNumberGenerator` instances (no global state)
- Seeds must be logged or persisted at simulation boundaries (phase start/end)
- Per-thread RNG must be derived from a parent seed deterministically
- Use `map_parallel` with explicit seed derivation for concurrent operations
- Document seed lineage in comments when derivation is non-obvious

### 3. Review Agent

**Primary Goal:**
Protect code quality and project coherence.

**Responsibilities:**
- Review PRs for:
  - Clarity and maintainability
  - Correct abstractions and separation of concerns
  - Deterministic behavior and explicit RNG usage
  - Algorithmic runtime and memory use (reject changes that introduce
    avoidable performance regressions)
  - Test coverage for simulation logic
  - Adherence to lifecycle and phase contracts
- Flag hidden state, leaky randomness, or tight coupling
- Ensure comments explain *why* (intent, design decisions, trade-offs)
- Push back on feature creep and premature abstractions
- Verify seed lineage is auditable in logs/outputs
- Confirm config usage follows existing patterns
- Check that changes fit within the current phase scope
- Validate that new entity fields have serialization parity
- Enforce performance guardrails; prefer clear, bounded algorithms
  over unbounded or quadratic approaches unless explicitly justified

**Must NOT:**
- Approve PRs solely because "it works"
- Rewrite entire systems unless necessary
- Accept magic numbers or hardcoded distributions
- Allow global RNG usage or implicit randomize() calls
- Approve missing deterministic test coverage for simulation steps
- Skip verification of phase handoff format stability

## General Purpose Agent

**Primary Goal:**
Contribute across areas while respecting current phase focus and existing architecture.

**Responsibilities:**
- Follow the Core Principles
- Defer architectural decisions to the Architect Agent
- Preserve determinism conventions when touching simulation logic
- Keep changes small, reviewable, and well-documented
- Consult plan.md to understand current phase scope and constraints
- Check docs/tasks for active task guidance and context before starting work
- Read existing code patterns before implementing new features
- Use config files for tunable parameters (no hardcoded distributions)
- Add deterministic tests for new simulation behavior
- Document seed lineage when adding RNG-dependent code
- Ask clarifying questions when phase boundaries are unclear

**When to escalate:**
- Data model changes → Architect Agent
- Complex simulation logic → Engineer Agent (if specialized guidance needed)
- Pre-merge review → Review Agent
- Uncertainty about phase scope or architectural fit → Architect Agent

**Must NOT:**
- Override role-specific constraints without explicit instruction
- Introduce hidden state or opaque randomness
- Add features beyond the current phase scope
- Skip deterministic test coverage for simulation changes
- Make architectural decisions without Architect review
- Hardcode league rules, tier distributions, or magic numbers

## Collaboration Rules

- Agents may request changes, not silently work around issues
- Architectural concerns override feature requests
- If uncertain, document the uncertainty
- Do not “future-proof” beyond the current phase unless explicitly instructed

## Phased Development Awareness

All agents must respect the current development phase.
The authoritative, up-to-date status lives in `docs/tasks` and should be
consulted before starting work.

## PR Structure Template

Include the following in PR descriptions:
- Summary
- Why
- Assumptions
- Determinism notes
- Tests run

## Dispute Resolution

If agents disagree:
- The Architect Agent has final say on structure.
- The Engineer Agent has final say on correctness.
- If still uncertain, document and defer.

## Review Checklist (For All PRs)

Before approving or merging, verify:

**Determinism:**
- Is the system deterministic when seeded?
- Is randomness isolated and passed explicitly (no global RNG)?
- Are per-phase seeds derived from parent seeds with logged lineage?
- Can the same seed reproduce the same outputs?

**Architecture:**
- Are lifecycles explicit (e.g., eligibility transitions, contract states)?
- Are responsibilities clearly separated (evaluation vs. decision logic)?
- Do new entity fields have serialization parity (to_dict/from_dict)?
- Does this fit within the current phase scope?
- Are phase handoff formats stable and documented?

**Code quality:**
- Do comments explain *why* this exists (intent, trade-offs, design decisions)?
- Are config files used for tunable parameters (no magic numbers)?
- Are abstractions justified by concrete use cases (no premature generalization)?
- Are runtime and memory costs acceptable for multi-season simulations?
- Would this still make sense after 50 simulated seasons?

**Testing:**
- Are deterministic tests included for simulation changes?
- Do tests validate seed-driven reproducibility?
- Are edge cases covered (empty pools, tie-breaks, boundary conditions)?

## Role Selection Examples

**Use Architect Agent when:**
- Defining new data models (Team, Coach, Injury, etc.)
- Changing existing model schemas (adding/removing fields)
- Planning phase boundaries and handoff contracts
- Deciding between architectural approaches
- Reviewing architectural impact of proposed changes
- Defining minimal scaffolding for future phases

**Use Engineer Agent when:**
- Implementing pipeline phase handlers
- Threading RNG through generation or simulation code
- Building lifecycle transitions (aging, eligibility, retirement)
- Creating deterministic tests for simulation behavior
- Refactoring to remove global RNG usage
- Implementing evaluation or decision mechanics

**Use Review Agent when:**
- Reviewing completed PRs before merge
- Auditing code for determinism violations
- Checking test coverage completeness
- Validating seed lineage documentation
- Ensuring changes fit current phase scope
- Identifying premature abstractions or feature creep

**Use General Purpose Agent when:**
- Making small, localized changes
- Adding config-driven parameters
- Fixing bugs that don't require architectural changes
- Writing documentation or comments
- Running existing tests or pipelines
- Tasks that span multiple areas but respect existing patterns

## Glossary

- **Simulation step**: A discrete, ordered unit of simulation work with clearly defined inputs/outputs.
- **Lifecycle**: A defined progression of states for an entity (e.g., player aging, progression, retirement).
- **Scaffolding**: Minimal structure to support future systems without implementing full behavior.
- **Phase**: A discrete stage in the yearly simulation cycle (e.g., HS season, recruiting, draft).
- **Seed lineage**: The documented chain of RNG seed derivations from parent to child seeds.
- **Determinism**: The property that identical inputs (including seeds) produce identical outputs.
- **Phase handoff**: The stable data format passed between simulation phases (e.g., recruit pool, draft class).

## Final Note

This project values clarity, restraint, and simulation integrity.

If forced to choose:

Fewer features, well designed
beats
Many features, poorly understood

## Additional References

Commit message requirements live in `COMMIT_STYLE.md` at the repository root.
All agents and contributors are expected to follow it.
