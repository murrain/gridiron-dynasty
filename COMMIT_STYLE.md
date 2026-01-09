# COMMIT_STYLE.md

## Purpose

This document defines **mandatory commit and pull request standards** for *Gridiron Dynasty*.

The commit history is treated as **technical documentation**, not a scratchpad.
Future contributors (human or agent) must be able to understand:

* What changed
* Why it changed
* What assumptions were made

Ambiguous or low-signal commits are not acceptable.

---

## Core Philosophy

* Commits should explain **intent**, not just outcomes
* Small, coherent commits are preferred over large, mixed ones
* Every commit must justify its existence
* If a change is difficult to explain clearly, it is likely poorly scoped

---

## Commit Size Rules

Each commit MUST:

* Do **one logical thing**
* Be independently reviewable
* Build and pass tests (where applicable)

Avoid commits that:

* Mix refactors with behavior changes
* Combine unrelated systems
* Include “drive-by” cleanups

If multiple concerns exist, split them.

---

## Required Commit Message Structure

Every commit message MUST follow this structure:

```
<Short summary (imperative, present tense)>

<Blank line>

Context:
- Why this change is necessary
- What problem it addresses

Approach:
- How the problem is solved
- Key design decisions
- Constraints or tradeoffs

Notes:
- Assumptions made
- Known limitations
- Follow-up work (if any)
```

All sections are REQUIRED unless explicitly stated otherwise.
If a section has no content, write `- None` to make the omission explicit.

---

## Short Summary Rules

The first line MUST:

* Be **imperative** (“Add”, “Fix”, “Refactor”, “Remove”, “Document”)
* Be a complete, grammatical sentence that describes the primary intent
* Avoid vague language
* Be short enough to fit within IDE commit lists (e.g., VS Code’s left pane)

Preferred format inspired by Bellard/Doom-era habits:

```
<subsystem>: <imperative summary>
```

Examples:

```
sim: add multi-year draft class generation
rng: inject season seed into progression step
ui: document phase boundary labels
```

### ✅ Good examples

```
Add multi-year draft class generation
Refactor player aging into deterministic step function
Fix injury duration overflow in season simulation
```

### ❌ Bad examples

```
Updates
Cleanup
WIP
Fix stuff
More changes
```

---

## Context Section

The **Context** section must answer:

* Why is this change needed now?
* What was broken, missing, or unclear before?

### Example

```
Context:
- Draft classes were generated only for the current year
- This prevented long-term simulation and league continuity
```

---

## Approach Section

The **Approach** section must explain:

* How the solution works at a high level
* Why this approach was chosen over alternatives
* Any relevant constraints

### Example

```
Approach:
- Generate draft classes N years in advance using a seeded RNG
- Store classes in a time-indexed structure
- Avoid coupling draft generation to team logic
```

---

## Notes Section

The **Notes** section is required even if brief.

Include:

* Assumptions
* Edge cases
* Deferred decisions
* Explicit TODOs (with reasoning)

### Example

```
Notes:
- Does not yet account for early declarations
- Retirement logic handled separately
- Future work: integrate scout visibility
```

---

## When to Split Commits

You MUST split commits when:

* Refactoring + behavior change both occur
* Multiple systems are touched for unrelated reasons
* Formatting or renaming obscures logic changes

Example split:

1. Refactor player aging into pure function
2. Add regression curves based on age

---

## Refactor Commits

Refactor commits MUST:

* Avoid changing external behavior
* Explicitly state intent in the summary

Example:

```
Refactor player development logic for clarity
```

And in Context:

```
Context:
- Existing logic was correct but difficult to reason about
```

---

## Documentation Commits

Documentation-only commits are allowed and encouraged.

Example:

```
Document simulation phase boundaries
```

Documentation commits must **not** include code changes unless unavoidable.

---

## Practical Formatting Rules

* Wrap body text at ~72 columns for terminal readability.
* Do not end the summary with a period.
* Avoid ticket-only summaries (e.g., “Fix #1234”).
* Avoid marketing adjectives (“quick”, “minor”, “simple”).

---

## Determinism Notes (Simulation Changes)

When a commit touches simulation logic:

* State how RNG is passed and seeded.
* Call out any new randomness boundaries.
* Mention determinism constraints in **Notes**.

---

## Pull Request Requirements

Every PR MUST include:

### 1. High-Level Summary

* What does this PR introduce or change?

### 2. Motivation

* Why this is necessary
* What it unlocks or fixes

### 3. Scope

* What is explicitly included
* What is explicitly out of scope

### 4. Review Guidance

* Files or concepts reviewers should focus on
* Known rough edges

---

## Commit Messages in PRs

* Squash commits are allowed ONLY if each commit already follows this standard
* Do not rely on PR descriptions to explain missing commit context
* Commits must stand alone

---

## Agent-Specific Rules

AI agents must:

* Follow this format exactly
* Avoid conversational or apologetic language
* Never use filler phrases like:

  * “minor change”
  * “quick fix”
  * “should work”

If uncertain, document the uncertainty explicitly in **Notes**.

---

## Enforcement

Commits or PRs that do not meet this standard:

* Will be requested for revision
* May be rejected regardless of functionality

This is intentional.

---

## Final Guiding Principle

> A good commit message allows a reader to understand the change
> without opening the diff.

All contributors are expected to meet this bar.
