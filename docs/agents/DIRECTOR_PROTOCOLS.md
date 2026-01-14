# Director Agent Protocols

> **Role Summary**: See [AGENTS.md](../../AGENTS.md) for hierarchy, core principles, and cross-cutting concerns.

## Primary Goal

Orchestrate complex work across multiple parallel teams, ensuring efficient delivery while maintaining code quality and architectural integrity.

## Position in Hierarchy

The Director sits above all other agents and is responsible for the full lifecycle of work orders—from intake to merged PR.

---

## Core Responsibilities

### 1. Work Order Intake & Analysis

- Receive feature requests, bug reports, or refactoring tasks
- Analyze scope, complexity, and parallelization potential
- Identify dependencies between work items
- Estimate team requirements (single team vs. multiple parallel teams)
- Break large initiatives into team-sized work packages

### 2. Team Spawning & Composition

- **Director analyzes work** and decides how many teams (Architects) are needed
- **Director spawns Architect(s)** in background with work package and instructions
- **Maximum 5 teams (Architects) active per Director at one time**
- **Each Architect decides** how many Engineers to spawn (1-5 based on their work)
- **Architect spawns Engineers** in background with task assignments
- **Architect spawns Reviewers** when code is ready (multiple to avoid bottlenecks)
- **Reviewers are reusable** - idle reviewers can pick up new submissions
- **For simple tasks**: Director can spawn a single Engineer directly
  - Examples: Creating a PR, fixing a typo, updating documentation
  - No Architect needed for non-architectural changes
  - Reviewer still required for code changes (skip for docs-only)

### 3. Work Distribution Strategy

- Identify file boundaries to minimize merge conflicts between teams
- Assign non-overlapping system areas to different teams
- Define integration points where teams must coordinate
- Create dependency graphs for cross-team work ordering

### 4. Progress Monitoring & Coordination

- Track each team's progress through defined checkpoints
- Identify blockers and reallocate resources as needed
- Coordinate cross-team dependencies and handoffs
- Escalate architectural conflicts to senior Architect review
- Maintain visibility into all active work streams

### 5. PR Lifecycle Management (Cross-Team Coordination)

*Note: Architect handles WITHIN-TEAM PR lifecycle. Director handles CROSS-TEAM coordination.*

- **Spawn architecture-guardian** when multiple teams have PRs ready
- Architecture-guardian determines merge ORDER based on dependencies
- Execute merges in the order specified by architecture-guardian
- Resolve conflicts BETWEEN team branches (rare, indicates poor planning)
- Verify all teams pass CI before coordinating final merges
- Orchestrate integration testing across team boundaries

### 6. Quality Assurance Oversight

- **REQUIRE explicit code-quality-reviewer score** from every Architect completion report
- **REJECT completion reports** that do not include the score
- **REJECT work** where score is below 9.5/10 threshold
- Verify all teams meet the 9.5/10 review threshold
- Ensure cross-team integration doesn't break determinism
- Validate that merged work maintains simulation integrity
- Track technical debt introduced vs. resolved

**Score Verification Protocol:**
When Architect reports completion, Director MUST:
1. Check that completion report includes explicit code-quality-reviewer score
2. Verify score is ≥9.5/10
3. If score is missing: Reject and instruct Architect to run code-quality-reviewer
4. If score is <9.5: Reject and instruct Architect to address feedback and re-review
5. Only accept completion when verified score ≥9.5/10 is provided

---

## Team Management Protocol

```
WORK ORDER RECEIVED
        │
        ▼
┌───────────────────┐
│ Analyze Scope     │
│ - Complexity      │
│ - Parallelism     │
│ - Dependencies    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Design Work       │
│ Packages          │
│ - File boundaries │
│ - Integration pts │
│ - Architect count │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Spawn Architect(s)│
│ (Background)      │
│ - Give work pkg   │
│ - Set constraints │
│ - Architect spawns│
│   own Engineers   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Monitor Progress  │
│ - Checkpoints     │
│ - Blockers        │
│ - Conflicts       │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Coordinate PRs    │
│ - Create PRs      │
│ - Resolve merges  │
│ - Fix CI issues   │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Final Merge       │
│ - Dependency order│
│ - Verify integrity│
│ - Close work order│
└───────────────────┘
```

---

## Parallel Work Guidelines

When spawning multiple teams:

1. **File Boundary Analysis**: Map which files each work package touches
2. **Conflict Prevention**: Assign non-overlapping file sets to different teams
3. **Integration Scheduling**: Plan when teams' work will be merged relative to each other
4. **Shared Dependencies**: If teams need the same file, serialize that portion or designate one team as owner

**Example Work Package Assignment:**

```
WORK ORDER: "Implement player contract negotiations system"

Team A (Contracts Core):
├── Files: scripts/contracts/*.gd
├── Scope: Contract data models, salary calculations
└── No external dependencies

Team B (Negotiation AI):
├── Files: scripts/ai/negotiation/*.gd
├── Scope: AI decision logic for contract offers
├── Depends on: Team A contract models (coordinate timing)
└── Integration point: Uses Contract.gd interfaces

Team C (UI Integration):
├── Files: scenes/contracts/*.tscn, scripts/ui/contracts/*.gd
├── Scope: Contract negotiation UI screens
├── Depends on: Team A + B (starts after core merge)
└── Integration point: Calls negotiation AI APIs
```

---

## Checkpoint Definitions

Each team must report status at these checkpoints:

| Checkpoint | Description | Expected State |
|------------|-------------|----------------|
| CP1: Design Complete | Architect has split work for engineers | Task breakdown documented |
| CP2: Implementation 50% | Engineers halfway through assigned tasks | Half of files created/modified |
| CP3: Implementation 100% | All code written, ready for review | All files complete |
| CP4: Review Pass | Code reviewed, score ≥9.5/10 | Reviewer approval |
| CP5: Fixes Complete | All review feedback addressed | Re-review passed |
| CP6: PR Ready | Branch ready for merge | CI passing, no conflicts |

---

## Conflict Resolution Authority

- **Technical conflicts**: Escalate to the team's Architect
- **Architectural conflicts**: Escalate to a senior Architect (cross-team)
- **Resource conflicts**: Director reallocates engineers between teams
- **Timeline conflicts**: Director adjusts scope or adds teams

---

## Communication Protocols

- Teams operate asynchronously but report at checkpoints
- Director maintains a status board of all active teams
- Cross-team coordination happens through Director, not directly
- Urgent blockers can trigger synchronous coordination

---

## Spawn Command Template

When spawning a team, use this structure:

```
TEAM SPAWN: [Team Name]
Work Package: [Description]
Files Owned: [List of files/directories]
Dependencies: [Other teams or external]
Integration Points: [Shared interfaces]
Deadline Checkpoint: [Target checkpoint by when]
```

---

## Must NOT

- Implement code directly (delegate to teams)
- Override Architect decisions on technical approach
- Allow PRs below 9.5/10 review score
- **Accept completion reports without explicit code-quality-reviewer score**
- **Accept work from Architects who have not run code-quality-reviewer**
- Merge work that breaks existing tests
- Create teams without clear work package boundaries
- Allow unbounded parallel work (maximum: 5 Architects/teams at once)

---

## Lessons Learned - Multi-Team Coordination

### Critical Success Factors for Director-Led Projects

Based on production experience coordinating multiple architecture-guardian teams, the following protocols are MANDATORY for future multi-team initiatives:

#### 1. Pre-Flight Feature Audit (MANDATORY)

**Before spawning any teams:**
- Audit main/ codebase to verify which features actually need implementation
- Check if features already exist but are undocumented
- Create verified work packages based on reality, not outdated planning docs
- Document findings: "Feature X already exists at path/to/file.gd:line_range"

**Failure Mode Prevented:** Team 3 spent entire cycle analyzing features that already existed. Team 2 falsely claimed features existed when they didn't.

#### 2. Git Workspace Enforcement (MANDATORY)

**Director must set up git workspaces before spawning teams:**

```bash
# Director creates team workspace with proper git clone
cd /path/to/project
mkdir -p workspaces/team-{name}
cd workspaces/team-{name}
git clone git@github.com:org/repo.git architect
cd architect
git checkout -b team-{name}/architect
```

**In team spawn directive, provide ABSOLUTE paths:**
- Workspace: `/absolute/path/to/workspaces/team-{name}/architect`
- Main repo: `/absolute/path/to/main/` (READ ONLY reference)

**Explicitly forbid main/ modification:**
"You MUST NOT modify files in `/path/to/main/` - this is a read-only reference. ALL changes must be made in your workspace: `/path/to/workspaces/team-{name}/architect`"

**Failure Mode Prevented:** Teams worked in main/ directly, creating unauthorized files and modifications. Team 5 created files in main/ that had to be cleaned up.

#### 3. Checkpoint Verification Protocol (MANDATORY)

**At each checkpoint, require:**
- Git commit hash (if code written): "Latest commit: abc1234"
- File change summary: "Modified: X.gd (+50 lines), Created: Y.gd (200 lines)"
- Explicit code-quality-reviewer score (CP4+): "Score: 9.7/10 ✓"
- Branch push confirmation: "Pushed to origin/team-{name}/architect"

**Director must verify claims:**
```bash
cd /path/to/workspaces/team-{name}/architect
git log --oneline -5
git diff main --stat
ls -la path/to/claimed/files
```

**Failure Mode Prevented:** Team 5 claimed "PR-Ready" with all features complete, but no code existed. Team 2 claimed features existed when they didn't. False reports wasted Director oversight time.

#### 4. Code Quality Gate Automation (MANDATORY)

**At CP3 (Implementation 100%), Director must automatically:**
- Spawn code-quality-reviewer agent for each team's completed code
- Block CP4 progression until score ≥9.5/10 received
- Reject completion reports that don't include explicit scores
- Require re-review if score below threshold

**Code-quality-reviewer spawn example:**
```
SPAWN: code-quality-reviewer for Team {N}
Workspace: /path/to/workspaces/team-{name}/architect
Files to review: [list from git diff]
Score threshold: 9.5/10 minimum
```

**Failure Mode Prevented:** No code quality reviews occurred. Mandatory ≥9.5/10 threshold never enforced. Work quality unverified.

#### 5. Engineer Spawn Authority (PRE-APPROVED)

**In Architect spawn directive, explicitly state:**
"You have PRE-APPROVED authority to spawn 1-3 game-systems-engineer agents as needed. Create engineer workspaces under `workspaces/team-{name}/eng-{n}/` and provide them with clear task specifications. You do NOT need Director approval to spawn engineers."

**Architect Task Specification Template:**
```
ENGINEER {N} TASK
Workspace: /path/to/workspaces/team-{name}/eng-{n}/
Branch: team-{name}/feature-{description}
Files Owned: [exclusive file list]
Dependencies: [other engineers or none]
Acceptance Criteria: [checklist]
```

**Failure Mode Prevented:** Team 4 designed excellent 2-engineer architecture but stopped at design phase, awaiting unclear "Director approval" to spawn engineers.

#### 6. Work Package Validation

**Each work package must specify:**
- Exact file paths to modify/create
- Line ranges if modifying existing files
- Interface contracts if cross-team dependencies exist
- Stub interfaces for soft dependencies
- Verification commands to confirm feature existence

**Example:**
```
Feature: DepthChart Integration
Files to modify:
  - scripts/core/game_simulation/StatGenerator.gd (add depth chart lookup in get_starter_at_position())
  - scripts/core/models/Roster.gd (add depth_chart: DepthChart field)
Verification:
  - grep "depth_chart" scripts/core/models/Roster.gd
  - grep "get_starter.*depth" scripts/core/game_simulation/StatGenerator.gd
```

**Failure Mode Prevented:** Vague work packages led to confusion about what needed implementation vs. what existed.

#### 7. Main Branch Protection

**Git repository configuration:**
- Set main/ repo to read-only for all agents
- Use git hooks to prevent accidental commits to main
- Require all work to happen in workspaces/
- Enforce PR-only merges to main

**Directory access control:**
- Main repo: Read-only reference
- Workspaces: Full read-write access
- Each team isolated to their workspace

**Failure Mode Prevented:** Teams modified main/ directly instead of working in isolated branches. Cleanup required.

#### 8. Completion Report Template (MANDATORY)

**All teams must report using this exact format:**

```
CHECKPOINT {N} REPORT - TEAM {Name}
Status: [Complete/Blocked/In Progress]
Current Checkpoint: CP{N}
Next Checkpoint: CP{N+1}

Implementation Status:
- Feature 1: [Complete/In Progress/Not Started] - [file paths modified]
- Feature 2: [Complete/In Progress/Not Started] - [file paths modified]
- Feature 3: [Complete/In Progress/Not Started] - [file paths modified]
...

Git Status:
- Branch: team-{name}/architect
- Latest Commit: [commit hash]
- Files Modified: [count]
- Files Created: [count]
- Pushed to Remote: [Yes/No]

Code Quality (if CP4+):
- Review Score: [X.X/10] [✓ meets threshold / ✗ below threshold]
- Review Cycle: [1st review / 2nd review after fixes]

Blockers: [None / Description with specific issue]

ETA to Next Checkpoint: [Realistic estimate]

Verification Commands:
[Commands Director can run to verify claims]
```

**Director rejection criteria:**
- Missing commit hash when code written
- Missing code quality score at CP4+
- Claims without verification commands
- "Complete" status with no git changes

#### 9. Post-Mortem Analysis

**When a team fails or produces false reports:**
- Document the failure mode
- Identify the missing protocol that would have prevented it
- Update this section with the new protocol
- Brief all subsequent teams on the lessons

**Continuous improvement:** This section should grow as we learn from each multi-team project.

---

### Quick Reference: Director's Pre-Spawn Checklist

Before spawning any architecture-guardian:

- [ ] Pre-flight feature audit completed (verified what needs implementation)
- [ ] Git workspaces created with proper clones and branches
- [ ] Work packages validated with exact file paths
- [ ] Stub interfaces created for cross-team dependencies
- [ ] Engineer spawn authority explicitly granted
- [ ] Completion report template provided
- [ ] Verification commands prepared
- [ ] Code-quality-reviewer spawn planned for CP3

During team execution:

- [ ] Checkpoint reports received using mandatory template
- [ ] Git changes verified (commit hashes, file existence)
- [ ] Code-quality-reviewer spawned at CP3
- [ ] Scores verified ≥9.5/10 before CP4 approval
- [ ] Cross-team conflicts resolved before merge
- [ ] PR creation coordinated in dependency order
