# AGENTS

## Purpose

This project uses multiple AI agents with clearly defined roles to collaboratively build and maintain Gridiron Dynasty, an American Football Manager–style simulation game.

Agents are expected to operate with discipline, restraint, and long-term thinking.
Feature velocity is secondary to simulation correctness, clarity, and maintainability.

This file defines:
- The agent hierarchy and role relationships
- Cross-cutting concerns ALL agents must follow
- Shared standards for code, reviews, and commits

**Role-specific protocols** are documented separately:
- [Director Protocols](docs/agents/DIRECTOR_PROTOCOLS.md) - Team spawning, multi-team coordination, lessons learned
- [Architect Protocols](docs/agents/ARCHITECT_PROTOCOLS.md) - System design, work decomposition, quality gates
- [Engineer Protocols](docs/agents/ENGINEER_PROTOCOLS.md) - Implementation, coding guidelines, RNG discipline
- [Test Engineer Protocols](docs/agents/TEST_ENGINEER_PROTOCOLS.md) - Testing infrastructure, CI/CD, developer tooling
- [Reviewer Protocols](docs/agents/REVIEWER_PROTOCOLS.md) - Review scoring, checklists, anti-patterns

---

## Agent Hierarchy

```
                          ┌─────────────┐
                          │  DIRECTOR   │
                          │  (Project   │
                          │  Manager)   │
                          └──────┬──────┘
                                 │
                                 │ spawns for planning
                                 │
                 ┌───────────────┼───────────────┬───────────────┐
                 │               │               │               │
           ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐   ┌─────▼─────┐
           │Architecture│   │Architecture│   │Architecture│   │   Test    │
           │ Guardian   │   │ Guardian   │   │ Guardian   │   │ Engineer  │
           │  (Team A)  │   │  (Team B)  │   │  (Team N)  │   │  (Infra)  │
           └─────┬──────┘   └─────┬──────┘   └─────┬──────┘   └───────────┘
                 │                │                │
                 │ reports ready  │                │
                 │ for 1-3 engrs  │                │
                 ▼                ▼                ▼
           ┌─────────────┐
           │  DIRECTOR   │ ◄──── Spawns engineers based on
           │   spawns    │       guardian recommendations
           │  engineers  │
           └──────┬──────┘
                  │
                  │ spawns 1-3 engineers per team
                  │
           ┌──────┼──────┬───────┐
           │      │      │       │
         Eng1   Eng2   Eng3    ...
           │      │      │
           └──────┼──────┘
                  │
                  │ spawns reviewers
                  ▼
           ┌─────────────┐
           │ Reviewers   │
           │ (Test Infra │
           │  + Code     │
           │  Quality)   │
           └─────────────┘
```

**Spawning Chain (NEW WORKFLOW):**
1. **Director** spawns **Architecture-Guardian(s)** with work packages for architectural planning
2. **Architecture-Guardian** conducts architectural assessment:
   - Reviews impact scope and system boundaries
   - Evaluates fit with existing patterns
   - Analyzes lifecycle implications and complexity justification
   - Provides approval/rejection decision with detailed rationale
3. **Architecture-Guardian** determines engineer allocation (1-3 engineers based on work scope and parallelization opportunities)
4. **Architecture-Guardian** reports back to **Director**: "Ready for N engineers with specifications X, Y, Z"
5. **Director** spawns **Engineer(s)** (1-3 per team) based on Guardian's specifications
6. **Director** spawns **Test Infrastructure Engineer** to review test quality
7. **Director** spawns **Code Quality Reviewer** to review implementation
8. **Test Engineer** and **Reviewer** must both approve (≥9.5/10) before merge

**Why Architecture-Guardians Plan First:**
- Separates architectural design phase from implementation phase
- Guardians can explore codebase thoroughly without implementation pressure
- Ensures architectural soundness before committing engineering resources
- Director coordinates engineer spawning based on architectural approval
- Prevents wasted work on architecturally unsound approaches

**Why Director Spawns Engineers (not Guardians):**
- Claude Code's agent system only allows top-level agents to spawn sub-agents
- Architecture-Guardians cannot directly spawn Engineer sub-agents due to tool limitations
- Guardians design and approve the work; Director handles the spawning
- This creates a clear Plan → Approve → Spawn → Implement workflow

**Dynamic Team Scaling:**
- Architect determines Engineer count based on work decomposition
- Multiple Reviewers can run in parallel if engineers finish at different times
- Example: Engineers 1 & 2 finish → spawn 2 Reviewers; Engineer 3 finishes → reuse idle Reviewer
- This prevents review bottlenecks and maximizes throughput

---

## Workspace Organization (Multi-Agent Disk Layout)

> **CRITICAL**: All agents MUST read and follow this section to avoid git conflicts and repository corruption.

To enable parallel work across multiple agents, each agent requires its own git checkout on a separate branch. Workspaces are **ephemeral** - created when needed, deleted after merge.

**CRITICAL**: Workspaces must be **outside** the main repository to avoid git conflicts and permission issues.

### Directory Structure

```
<project-root>/
├── main/                         # Reference copy (main branch, read-only)
│
└── workspaces/                   # Ephemeral workspaces (sibling to main, NOT inside it)
    ├── director/                 # Director's workspace (for temporary work)
    │
    ├── team-alpha/               # Created by Director for Team Alpha
    │   ├── architect/            # Architect's checkout (created by Director)
    │   ├── eng-1/                # Created by Architect as needed
    │   ├── eng-2/                # Created by Architect as needed
    │   └── eng-3/                # Created by Architect as needed
    │
    └── team-beta/                # Created by Director for Team Beta
        ├── architect/
        └── eng-1/
```

**Example paths (vary by machine):**
- `/home/user/gridiron-dynasty/main/` and `/home/user/gridiron-dynasty/workspaces/`
- `/mnt/disk1/code/gridiron-dynasty/main/` and `/mnt/disk1/code/gridiron-dynasty/workspaces/`

**Why workspaces are outside the main repo:**
- Prevents `git pull`/`git status` in main repo from affecting workspaces
- Avoids nested `.git` directory conflicts
- Protects workspaces from `git clean` operations
- Each workspace is an independent clone with its own git state

**DIRECTOR NOTE - Initial Working Directory:**
When spawned, you may start inside the main repository (e.g., `/home/user/gridiron-dynasty/` or `/mnt/disk1/code/project/main/`). Before creating workspaces:
1. Check if you're inside a git repo: `git rev-parse --show-toplevel`
2. If yes, go UP one directory: `cd ..`
3. Create `workspaces/` as a sibling to the main repo, not inside it

Example:
```bash
# If starting in /home/user/gridiron-dynasty (the main repo)
cd ..                              # Go to /home/user/
mkdir -p workspaces/team-alpha     # Creates /home/user/workspaces/team-alpha
```

**Keep the main repo clean:**
- NEVER create temporary files, notes, or untracked items in the main repository
- The main repo should always have a clean `git status`
- For any temporary work (notes, scratch files, planning docs), use `<workspaces>/director/`
- This prevents accidental commits of temporary files and keeps the reference copy pristine

### Workspace Lifecycle

**Workspaces are ephemeral** - they exist only for the duration of the work:

1. **Director creates** team workspace when spawning Architect
2. **Architect creates** engineer workspaces as needed
3. **All workspaces deleted** after PR is merged to main

### Branch Naming Convention

```
main                              # Protected, merge target
team-{name}/architect             # Architect's integration branch
team-{name}/feature-{description} # Engineer feature branches
```

### Workspace Isolation Rules

| Rule | Description |
|------|-------------|
| **One agent per directory** | Never have two agents working in the same directory simultaneously |
| **One branch per engineer** | Each Engineer works on their own feature branch |
| **Architect owns team folder** | Architect manages all workspaces under their team |
| **No cross-team access** | Teams do not access each other's workspaces |
| **Ephemeral by default** | Delete workspaces after merge |

### Git Operations

**IMPORTANT:**
- **Never run `git pull`** in a workspace - use `git fetch` + `git checkout` or `git merge` instead
- Each workspace is an independent clone; pulling can cause unexpected merge commits
- If you need the latest from a branch, fetch and reset: `git fetch origin && git reset --hard origin/branch-name`

### Merge Flow

```
Engineer branches ──► Architect integration branch ──► main

team-alpha/feature-x ─┐
team-alpha/feature-y ─┼──► team-alpha/architect ─┐
team-alpha/feature-z ─┘                         │
                                                ├──► main
team-beta/feature-a ──┐                         │    (ordered by
team-beta/feature-b ──┼──► team-beta/architect ─┘    architecture-guardian)
```

---

## Role Assignment

Unless explicitly instructed otherwise, a worker may assume the General Purpose Agent role (see below).
If a task requires a different role, the agent must explicitly declare the role at the start of the task.
Role changes during a task must be documented in the PR.

---

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

---

## Agent Roles (Summary)

### 0. Director Agent (Project Manager)

**Primary Goal:** Orchestrate complex work across multiple parallel teams.

**Key Responsibilities:**
- Work order intake and analysis
- Team spawning (max 5 teams at once)
- Progress monitoring through checkpoints
- Cross-team PR lifecycle management
- Quality assurance oversight (enforce 9.5/10 threshold)

**Must NOT:** Implement code directly, allow PRs below 9.5/10, accept reports without quality scores.

📖 **Full Protocol:** [docs/agents/DIRECTOR_PROTOCOLS.md](docs/agents/DIRECTOR_PROTOCOLS.md)

---

### 1. Architect Agent

**Primary Goal:** Design and protect the long-term structure of the simulation.

**Key Responsibilities:**
- System design and data modeling
- Work decomposition for parallel teams
- Integration oversight
- Quality gatekeeping
- PR lifecycle management (within team)

**Must NOT:** Implement UI, add features without lifecycle consideration, claim completion without 9.5+ score.

📖 **Full Protocol:** [docs/agents/ARCHITECT_PROTOCOLS.md](docs/agents/ARCHITECT_PROTOCOLS.md)

---

### 2. Engineer Agent

**Primary Goal:** Implement game systems that are correct, extensible, and testable.

**Key Responsibilities:**
- Implementation per Architect specification
- RNG discipline (explicit threading, no global state)
- Parallel work coordination
- Mandatory 4-layer testing before review

**Must NOT:** Bypass models, hardcode rules, use global RNG, skip tests.

📖 **Full Protocol:** [docs/agents/ENGINEER_PROTOCOLS.md](docs/agents/ENGINEER_PROTOCOLS.md)

---

### 3. Review Agent (code-quality-reviewer)

**Primary Goal:** Protect code quality through rigorous, consistent review.

**Key Responsibilities:**
- Compilation verification (blocking)
- Runtime verification (blocking)
- Code quality assessment
- Anti-pattern detection

**Scoring:** Minimum 9.5/10 required. 0/10 for compilation failures.

📖 **Full Protocol:** [docs/agents/REVIEWER_PROTOCOLS.md](docs/agents/REVIEWER_PROTOCOLS.md)

---

### 4. Test Engineer Agent (Platform/Infrastructure)

**Primary Goal:** Build and maintain testing infrastructure, CI/CD pipelines, and developer tooling.

**Position in Hierarchy:**
- **Spawned by Director** for project-wide infrastructure (test framework migrations, CI setup)
- **Spawned by Architect** for team-specific test needs (fixture systems, integration tests)
- Peer to Engineer within team context
- Subject to Reviewer approval like Engineers

**Key Responsibilities:**
- Test framework setup, migration, and maintenance
- CI/CD pipeline configuration and optimization
- Test fixture systems and snapshot management
- Developer tooling (hooks, scripts, automation)
- Test coverage analysis and gap identification

**Must NOT:** Implement game simulation logic, modify core models, bypass Reviewer approval.

📖 **Full Protocol:** [docs/agents/TEST_ENGINEER_PROTOCOLS.md](docs/agents/TEST_ENGINEER_PROTOCOLS.md)

---

### 5. General Purpose Agent

**Primary Goal:** Contribute across areas while respecting existing architecture.

**Position in Hierarchy:**
- Entry-level role for **ad-hoc, human-directed work**
- **NOT spawned by Director** (Director spawns Architects or Engineers directly)
- Used when a human needs quick assistance without formal team structure
- Can escalate to any specialized role as the task scope becomes clear

**Responsibilities:**
- Follow the Core Principles
- Defer architectural decisions to the Architect Agent
- Preserve determinism conventions when touching simulation logic
- Keep changes small, reviewable, and well-documented
- Consult `docs/architecture/IMPLEMENTATION_TICKETS.md` to understand current planned work
- Check `docs/contributing/` for style guides and testing documentation
- Read existing code patterns before implementing new features
- Use config files for tunable parameters (no hardcoded distributions)
- Add deterministic tests for new simulation behavior
- Document seed lineage when adding RNG-dependent code
- Ask clarifying questions when phase boundaries are unclear

**When to Escalate:**
- Data model changes → Architect Agent
- Complex simulation logic → Engineer Agent
- Pre-merge review → Review Agent
- Uncertainty about phase scope → Architect Agent
- Multi-team work → Director Agent

**Must NOT:**
- Override role-specific constraints without explicit instruction
- Introduce hidden state or opaque randomness
- Add features beyond the current phase scope
- Skip deterministic test coverage for simulation changes
- Make architectural decisions without Architect review
- Hardcode league rules, tier distributions, or magic numbers

---

## Team Coordination Protocols

### Parallel Work Safety

When multiple engineers work on the same codebase:

1. **File Ownership**: Each engineer owns specific files; others do not modify
2. **Interface Contracts**: Shared interfaces defined by Architect before implementation
3. **Integration Order**: Architect specifies merge order to avoid conflicts
4. **Conflict Resolution**: If conflicts arise, Architect arbitrates

### Cross-Team Coordination

When multiple teams work simultaneously:

1. **Work Package Isolation**: Director ensures minimal file overlap
2. **Dependency Ordering**: Teams with dependencies wait for upstream merges
3. **Integration Windows**: Scheduled times for cross-team integration
4. **Director Oversight**: All cross-team issues flow through Director

### Checkpoint Synchronization

Teams report status at defined checkpoints:

```
CP1 ─► Design complete, tasks assigned
CP2 ─► Implementation 50%
CP3 ─► Implementation 100%, ready for review
CP4 ─► Review passed (≥9.5/10)
CP5 ─► All fixes complete
CP6 ─► PR ready, CI passing
```

---

## Collaboration Rules

- Agents may request changes, not silently work around issues
- Architectural concerns override feature requests
- If uncertain, document the uncertainty
- Do not "future-proof" beyond the current phase unless explicitly instructed
- Cross-team communication flows through Director
- Within-team communication flows through Architect

---

## Commit and PR Workflow

**ALL code changes MUST go through PR workflow**:

1. Create feature branch from main
2. Make changes on branch
3. Run all 4 layers of mandatory testing (syntax, unit, runtime, full suite)
4. Get Reviewer approval (≥9.5/10)
5. Address any feedback and re-submit for review if needed
6. Create PR with proper description (use PR Structure Template below)
7. Wait for CI checks to pass
8. Director or Architect approves merge
9. Merge via PR (no direct-to-main commits)

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
- **Installation required**: Run `./scripts/hooks/install.sh` after cloning
- Hook source: `scripts/hooks/pre-commit` (tracked in version control)
- To test manually: `./scripts/tests/verify_compilation.sh`

---

## Testing Procedures for Agents

> **CRITICAL**: All agents must follow these testing procedures to ensure code quality and test reliability.

### Mandatory Testing Layers

Before submitting code for review, run ALL layers in order:

1. **Syntax Check** (BLOCKING):
   ```bash
   godot --headless --check-only --script path/to/modified/file.gd
   ```

2. **Unit Tests** (if applicable):
   ```bash
   godot --headless -s scripts/tests/run_[feature]_test.gd
   ```

3. **Runtime Integration**:
   ```bash
   godot --headless -s scripts/pipelines/BootstrapPreview.gd
   ```

4. **Full Test Suite** (for major changes):
   ```bash
   godot --headless -s scripts/tests/TestRunner.gd
   ```

### Using World State Snapshots

For tests requiring mature simulation data (contracts, trades, career progression), use pre-generated snapshots via the unified `setup_world()` API:

```gdscript
const SnapshotLoader = preload("res://scripts/tests/fixtures/world_state/SnapshotLoader.gd")

# Load 10-year snapshot (no additional simulation)
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_10, 0, 0x7E57001)

# Load 5-year snapshot + simulate 2 more years
var world_state := SnapshotLoader.setup_world(SnapshotLoader.YEAR_5, 2, 0x72ADE01)

# Generate fresh 3-year world (no snapshot)
var world_state := SnapshotLoader.setup_world(SnapshotLoader.FRESH, 3, 0xF2E5401)
```

**Available Base States:**
- `FRESH` - Generate from scratch
- `YEAR_5` - Basic rosters, recruiting data
- `YEAR_10` - Trade tests, contract history
- `YEAR_20` - Hall of Fame, dynasty detection

**API**: `setup_world(base, years, seed)` always returns an isolated deep copy safe to mutate. No need for separate read-only vs copy methods.

### Regenerating Test Snapshots

Regenerate snapshots after changes to:
- Config schemas
- Player/team model structures
- World state format
- Significant simulation logic

```bash
godot --headless -s res://scripts/tests/fixtures/world_state/SnapshotGenerator.gd
```

### Test Isolation

- TestRunner automatically clears snapshot cache between test files
- For manual cache clearing: `SnapshotLoader.clear_cache()`
- Each test should be independent - no shared mutable state

### Writing New Tests

1. Use existing test patterns in `scripts/tests/`
2. Prefer snapshot data over full generation for speed
3. Use deterministic seeds for reproducibility
4. Document expected behavior in test names
5. Cover edge cases: empty pools, ties, boundaries

See `docs/contributing/TESTING.md` for detailed testing infrastructure documentation.

---

## Phased Development Awareness

All agents must respect the current development phase.
The authoritative, up-to-date status lives in `docs/architecture/IMPLEMENTATION_TICKETS.md` and should be
consulted before starting work.

---

## PR Structure Template

Include the following in PR descriptions:
- Summary
- Why
- Assumptions
- Determinism notes
- Tests run
- Files modified (with ownership if multi-engineer)

---

## Dispute Resolution

If agents disagree:
1. **Within a team**: Architect has final say on technical approach
2. **Between teams**: Director mediates and decides
3. **Architectural disputes**: Senior Architect (or Director) arbitrates
4. **Still uncertain**: Document the dispute and defer to stakeholder input

**Hierarchy of authority:**
- Director > Architect > Engineer = Test Engineer = Reviewer > General Purpose

---

## Review Checklist (For All PRs)

> **CRITICAL**: Quality gate that ALL PRs must pass.

**Quality Gate:**
- Reviewer agent must score PR at **≥9.5/10** (ideally 10/10)
- If below threshold, address all feedback and re-submit for review
- Do NOT merge until this standard is met

Before approving or merging, verify:

**Compilation (MANDATORY FIRST STEP):**
- ALL modified .gd files compile without syntax errors
- Run: `godot --headless --check-only --script path/to/file.gd` for each file
- **BLOCKER**: Any syntax error must be fixed before proceeding

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

**Code Quality:**
- Do comments explain *why* this exists (intent, trade-offs, design decisions)?
- Are config files used for tunable parameters (no magic numbers)?
- Are abstractions justified by concrete use cases (no premature generalization)?
- Are runtime and memory costs acceptable for multi-season simulations?
- Would this still make sense after 50 simulated seasons?

**Testing:**
- Are deterministic tests included for simulation changes?
- Do tests validate seed-driven reproducibility?
- Are edge cases covered (empty pools, tie-breaks, boundary conditions)?

---

## Role Selection Examples

**Use Director Agent when:**
- Receiving large feature requests that require multiple teams
- Coordinating parallel work across the codebase
- Managing complex initiatives with dependencies
- Resolving cross-team conflicts or resource allocation
- Overseeing full PR lifecycle for multi-team work

**Use Architect Agent when:**
- Defining new data models (Team, Coach, Injury, etc.)
- Changing existing model schemas (adding/removing fields)
- Planning phase boundaries and handoff contracts
- Deciding between architectural approaches
- Splitting work for parallel engineer execution
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

**Use Test Engineer Agent when:**
- Migrating to a new testing framework (e.g., GdUnit4)
- Setting up or modifying CI/CD pipelines
- Creating or updating test fixture systems
- Building snapshot generation or management tools
- Implementing custom test assertions or utilities
- Optimizing test suite performance
- Creating developer tooling (hooks, scripts, automation)
- Debugging flaky tests or CI infrastructure issues

**Use General Purpose Agent when:**
- Making small, localized changes
- Adding config-driven parameters
- Fixing bugs that don't require architectural changes
- Writing documentation or comments
- Running existing tests or pipelines
- Tasks that span multiple areas but respect existing patterns

---

## Glossary

- **Director**: The orchestrating agent that manages teams and work orders
- **Team**: A group of agents (1 Architect, 1-5 Engineers, 1+ Reviewers) working on a work package
- **Work Package**: A scoped unit of work assigned to a team by the Director
- **Work Order**: A feature request or task received by the Director
- **Checkpoint**: A defined progress milestone for team synchronization (CP1-CP6)
- **Simulation step**: A discrete, ordered unit of simulation work with clearly defined inputs/outputs
- **Lifecycle**: A defined progression of states for an entity (e.g., player aging, progression, retirement)
- **Scaffolding**: Minimal structure to support future systems without implementing full behavior
- **Phase**: A discrete stage in the yearly simulation cycle (e.g., HS season, recruiting, draft)
- **Seed lineage**: The documented chain of RNG seed derivations from parent to child seeds
- **Determinism**: The property that identical inputs (including seeds) produce identical outputs
- **Phase handoff**: The stable data format passed between simulation phases (e.g., recruit pool, draft class)

---

## Final Note

This project values clarity, restraint, and simulation integrity.

If forced to choose:

Fewer features, well designed
beats
Many features, poorly understood

---

## Additional References

- Commit message requirements: `docs/contributing/COMMIT_STYLE.md`
- Testing infrastructure: `docs/contributing/TESTING.md`
- Current planned work: `docs/architecture/IMPLEMENTATION_TICKETS.md`
- Role-specific protocols: `docs/agents/`
