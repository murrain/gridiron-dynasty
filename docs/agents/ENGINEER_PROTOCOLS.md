# Engineer Agent Protocols

> **Role Summary**: See [AGENTS.md](../../AGENTS.md) for hierarchy, core principles, and cross-cutting concerns.

## Primary Goal

Implement game systems and simulation logic that are correct, extensible, and testable, working in parallel with other engineers under Architect guidance.

## Position in Hierarchy

Reports to Architect. Works alongside other Engineers. Submits work to Reviewer.

---

## Core Responsibilities

### 1. Implementation Excellence

- Implement assigned tasks per Architect specification
- Ensure deterministic behavior with seeded RNG (no global randomness)
- Encode lifecycles (aging, progression, regression, retirement, eligibility)
- Keep simulation steps pure where possible (explicit inputs/outputs)

### 2. RNG Discipline

- Thread RNG explicitly through all generation and simulation paths
- Derive per-phase seeds from parent seeds with logged lineage
- Document expected RNG consumption patterns
- Never use global random state or implicit `randomize()` calls

### 3. Parallel Work Coordination

- Stay within assigned file boundaries
- Implement to specified interfaces (inputs/outputs)
- Communicate blockers immediately to Architect
- Complete integration tests for cross-task dependencies

### 4. Quality Standards

- All implementations must score ≥9.5/10 from Reviewer
- Work is NOT complete until review threshold is met
- Address all review feedback systematically
- Run all mandatory testing layers before submitting for review

---

## Escalation Thresholds

**Escalate to Architect IMMEDIATELY when:**
- Blocked on dependency for > 30 minutes
- Task specification is ambiguous or contradictory
- Discovered file ownership conflict with another Engineer
- Review feedback requires changes outside assigned file boundaries
- Implementation would require architectural changes not in spec
- Estimated effort exceeds original estimate by > 50%

**Do NOT escalate (handle yourself):**
- Normal debugging and troubleshooting
- Minor clarifications you can resolve from existing docs
- Review feedback within your assigned files

---

## Implementation Workflow

```
TASK ASSIGNED (from Architect)
        │
        ▼
┌───────────────────┐
│ Review Task Spec  │
│ - Inputs/Outputs  │
│ - Dependencies    │
│ - Acceptance      │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Implement Code    │
│ - Follow patterns │
│ - Explicit RNG    │
│ - Pure functions  │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Write Tests       │
│ - Determinism     │
│ - Edge cases      │
│ - Integration     │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Mandatory Testing │
│ (All 4 Layers)    │
└────────┬──────────┘
         │
         ▼
┌───────────────────┐
│ Submit to Reviewer│
└────────┬──────────┘
         │
    ┌────┴────┐
    ▼         ▼
 APPROVED   CHANGES
 (≥9.5)    REQUESTED
    │         │
    ▼         ▼
  DONE    Fix & Resubmit
```

---

## MANDATORY Pre-Review Testing

Before submitting to Reviewer, ALL implementations MUST pass:

### 1. Syntax/Compilation Check (CRITICAL)

```bash
godot --headless --check-only --script path/to/modified/file.gd
```
- Run for EVERY modified .gd file
- Zero tolerance for syntax errors
- If this fails, DO NOT proceed to review

### 2. Unit Tests (if applicable)

```bash
godot --headless -s scripts/tests/run_[feature]_test.gd
```
- All tests must pass (no failures, no skips)

### 3. Integration/Runtime Tests (CRITICAL)

```bash
godot --headless -s scripts/pipelines/BootstrapPreview.gd
```
- Catches type errors that compilation misses
- Validates null handling, array bounds, dictionary access
- If simulation crashes, code is NOT ready

### 4. Full Test Suite (for major changes)

```bash
godot --headless -s scripts/tests/TestRunner.gd
```
- Verify no regressions in existing functionality

**Failure at ANY step means code is NOT ready for review.**

---

## GDScript Coding Guidelines

### Null-Safe Array Iteration

```gdscript
# WRONG - will crash if array contains nulls
for player: Dictionary in players:
    process(player)

# CORRECT - PlayerLifecycle can return nulls for retired players
for player in players:  # No type annotation
    if player == null:
        continue
    process(player)
```

### Hexadecimal Constants

```gdscript
# WRONG - R and D are not valid hex digits
const TRADE_SEED = 0x7RADE001

# CORRECT - use only 0-9 and A-F
const TRADE_SEED = 0x7ADE0001  # Trade RNG seed
```

### Variable Redeclaration (PR #122)

```gdscript
# WRONG - GDScript forbids redeclaring variables in the same scope
func process_awards():
    var cfg = config["heisman"]
    # ... later in same function ...
    var cfg = config["finalist"]  # PARSE ERROR!

# CORRECT - Use different variable names
func process_awards():
    var heisman_cfg = config["heisman"]
    var finalist_cfg = config["finalist"]
```

### Reserved Keywords (PR #112)

```gdscript
# WRONG - 'pass' is a reserved keyword
var pass = player.get("passing_yards")  # PARSE ERROR!

# CORRECT - Use descriptive alternatives
var passing = player.get("passing_yards")
```

### String Repetition (PR #114)

```gdscript
# WRONG - String multiplication removed in Godot 4.x
var separator = "=" * 80  # ERROR!

# CORRECT - Use .repeat() method
var separator = "=".repeat(80)
```

### Float Type Consistency (PR #114)

```gdscript
# WRONG - Type mismatch in ternary expression
var value: float = some_float if condition else 0  # Warning/Error

# CORRECT - Maintain float type throughout
var value: float = some_float if condition else 0.0
```

### Circular Reference Resolution (PR #112)

```gdscript
# WRONG - Circular preload causes compilation error
const ClassA = preload("res://ClassA.gd")  # Fails if ClassA preloads this file

# CORRECT - Dynamic loading breaks circular reference
var ClassA = load("res://ClassA.gd")
```

### Array.shuffle() Breaks Determinism (PR #122)

```gdscript
# WRONG - Array.shuffle() uses Godot's global RNG
players.shuffle()  # Non-deterministic!

# CORRECT - Explicit Fisher-Yates with passed RNG
func _shuffle_with_rng(arr: Array, rng: RandomNumberGenerator) -> Array:
    var shuffled = arr.duplicate()
    for i in range(shuffled.size() - 1, 0, -1):
        var j = rng.randi() % (i + 1)
        var tmp = shuffled[i]
        shuffled[i] = shuffled[j]
        shuffled[j] = tmp
    return shuffled
```

---

## Determinism Conventions

- RNG must be passed explicitly as `RandomNumberGenerator` instances
- Seeds must be logged or persisted at simulation boundaries
- Per-thread RNG must be derived from a parent seed deterministically
- Use `map_parallel` with explicit seed derivation for concurrent operations
- Document seed lineage in comments when derivation is non-obvious

---

## Must NOT

- Bypass established models or time systems
- Hardcode league rules, magic numbers, or tier distributions
- Use global RNG or implicit `randomize()` calls in simulation code
- Create one-off abstractions for single-use scenarios
- Skip deterministic test coverage for simulation steps
- Embed simulation logic inside UI or tooling scripts
- Submit PRs without Reviewer approval at ≥9.5/10
- Modify files outside assigned boundaries without Architect approval
