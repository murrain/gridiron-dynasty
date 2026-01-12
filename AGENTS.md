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

**Code Quality Standards:**
- All implementations must be reviewed by the code-quality-reviewer agent
- **Minimum acceptable score: 9.5/10 (ideally 10/10)**
- Work is NOT considered complete until this threshold is met
- If review score falls below 9.5/10:
  - Carefully review all feedback and identified issues
  - Address each concern systematically
  - Re-submit for code-quality-reviewer approval
  - Continue this cycle until 9.5/10+ is achieved
- This standard ensures long-term project health and maintainability

**MANDATORY Pre-Review Testing:**
Before submitting to code-quality-reviewer, ALL implementations MUST pass:

1. **Syntax/Compilation Check** (CRITICAL - catches parse errors):
   ```bash
   # Check each modified .gd file compiles without errors
   godot --headless --check-only --script path/to/modified/file.gd
   ```
   - Run this for EVERY modified .gd file
   - Zero tolerance for syntax errors - these must be fixed immediately
   - If this fails, DO NOT proceed to code review
   - NOTE: This does NOT catch all type errors (e.g., null assignments to typed variables)

2. **Unit Tests** (if applicable):
   ```bash
   # Run specific test suite
   godot --headless -s scripts/tests/run_[feature]_test.gd
   ```
   - All tests must pass (no failures, no skips)
   - Verify test output explicitly shows success
   - Tests must exercise actual code paths, not just type check

3. **Integration/Runtime Tests** (CRITICAL - catches type errors, null handling):
   ```bash
   # For season/lifecycle changes, run actual simulation
   godot --headless -s scripts/pipelines/BootstrapPreview.gd
   # OR run relevant integration test
   godot --headless -s scripts/tests/TestRunner.gd
   ```
   - MUST complete without runtime errors
   - Catches type annotation errors that --check-only misses
   - Validates null handling, array bounds, dictionary access
   - If simulation crashes or errors, code is NOT ready
   - Examples of errors caught: "Trying to assign value of type 'Nil' to Dictionary"

4. **Full Test Suite** (for major changes):
   ```bash
   # Run full test suite to check for regressions
   godot --headless -s scripts/tests/TestRunner.gd
   ```
   - Verify no regressions in existing functionality
   - Check that new functionality integrates correctly

**IMPORTANT**: Compilation checks alone are INSUFFICIENT. Runtime testing with actual
data is required because many type errors (especially with nulls, arrays, and strict
typing) only manifest during execution.

**Failure at ANY step means code is NOT ready for review.**

**Coding Guidelines:**

To prevent common GDScript type annotation errors:

1. **Arrays That Can Contain Nulls**:
   - `PlayerLifecycle.advance_one_year_parallel()` returns nulls in arrays when players retire
   - DO NOT use strict Dictionary typing when iterating such arrays
   - Pattern to AVOID: `var p: Dictionary = array[i]`
   - Correct pattern: `var p = array[i]  # No type annotation - array can contain nulls`
   - Always include null check: `if p == null: continue`
   - **Why**: GDScript 4.x does not support nullable types (`Dictionary?` or `Dictionary | null`)
   - **Detection**: This error only manifests at runtime, not during compilation
   - **Impact**: "Trying to assign value of type 'Nil' to a variable of type 'Dictionary'" crash

2. **Hexadecimal Constants**:
   - Only use valid hex digits: 0-9 and A-F
   - Pattern to AVOID: `0x7RADE001` (R and D are not valid hex)
   - Correct pattern: `0x7ADE0001`
   - Add comment explaining purpose: `# Trade RNG seed`

**Must NOT:**
- Bypass established models or time systems
- Hardcode league rules, magic numbers, or tier distributions
- Use global RNG or implicit `randomize()` calls in simulation code
- Create one-off abstractions for single-use scenarios
- Skip deterministic test coverage for simulation steps
- Embed simulation logic inside UI or tooling scripts
- Submit PRs without code-quality-reviewer approval at 9.5/10+

**Determinism conventions:**
- RNG must be passed explicitly as `RandomNumberGenerator` instances (no global state)
- Seeds must be logged or persisted at simulation boundaries (phase start/end)
- Per-thread RNG must be derived from a parent seed deterministically
- Use `map_parallel` with explicit seed derivation for concurrent operations
- Document seed lineage in comments when derivation is non-obvious

### 3. Review Agent (code-quality-reviewer)

**Primary Goal:**
Protect code quality and project coherence through rigorous review standards.

**Review Scoring Standard:**
- All code must score **≥9.5/10** (ideally 10/10) to be approved for merge
- Provide clear, actionable feedback when score is below threshold
- Identify specific issues that must be addressed before approval
- Re-review after fixes are implemented to verify improvements

**Responsibilities:**
- **FIRST**: Verify all modified .gd files compile without syntax errors
  - Run: `godot --headless --check-only --script path/to/file.gd`
  - If ANY file has syntax errors, IMMEDIATELY reject with score 0/10
  - No review proceeds until all files compile cleanly
- **SECOND**: Verify runtime tests pass (CRITICAL for season/lifecycle changes)
  - For season files, run: `godot --headless -s scripts/pipelines/BootstrapPreview.gd`
  - For other changes, run relevant test suite
  - If runtime errors occur (type errors, null assignments, crashes), reject with low score
  - Compilation checks do NOT catch all type errors - runtime validation required
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
- Provide detailed score breakdown across dimensions (code quality, testing, documentation, architecture, integration)

**Must NOT:**
- Approve PRs solely because "it works"
- Approve any PR scoring below 9.5/10 without requesting fixes
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
- Do not "future-proof" beyond the current phase unless explicitly instructed

## Commit and PR Workflow

**ALL code changes MUST go through PR workflow**:

1. Create feature branch from main
2. Make changes on branch
3. Run all 4 layers of mandatory testing (syntax, unit, runtime, full suite)
4. Get code-quality-reviewer approval (≥9.5/10)
5. Address any feedback and re-submit for review if needed
6. Create PR with proper description (use PR Structure Template below)
7. Wait for CI checks to pass
8. Merge via PR (no direct-to-main commits)

**NO EXCEPTIONS**: Even critical hotfixes must follow this workflow.

**Rationale**:
- Direct-to-main commits bypass code review and quality gates
- They create unclear git history and make rollbacks harder
- Pre-commit hooks provide immediate feedback on syntax errors
- PR workflow ensures all changes meet the 9.5/10 quality threshold
- This maintains long-term project health and code quality

**Pre-commit Hook**:
- Automatically runs compilation verification before allowing commits
- Prevents syntax errors from entering the repository
- Located at `.git/hooks/pre-commit`
- To test manually: `./scripts/tests/verify_compilation.sh`

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

**Quality Gate:**
- Code-quality-reviewer agent must score PR at **≥9.5/10** (ideally 10/10)
- If below threshold, address all feedback and re-submit for review
- Do NOT merge until this standard is met

Before approving or merging, verify:

**Compilation (MANDATORY FIRST STEP):**
- ALL modified .gd files compile without syntax errors
- Run: `godot --headless --check-only --script path/to/file.gd` for each modified file
- **BLOCKER**: Any syntax error must be fixed before proceeding with review
- This catches parse errors, invalid hex constants, type mismatches, etc.

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
