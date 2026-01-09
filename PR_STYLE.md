# PR_STYLE.md

## Purpose

This document defines **mandatory pull request standards** for *Gridiron Dynasty*.

The PR description is treated as **technical documentation** and should allow
reviewers to understand the change without scanning the diff.

---

## Core Philosophy

* Explain **why** the change exists before describing what changed.
* Keep the scope tight; PRs should do one coherent thing.
* Make review easier than it would be without the description.

---

## Required PR Description Structure

Every PR MUST follow this structure:

```
Summary:
- What changed at a high level

Why:
- Why this change is necessary now
- What it fixes or unlocks

Assumptions:
- Assumptions made during implementation
- If none, write: None

Determinism notes:
- How RNG is seeded/passed if simulation logic changed
- If not applicable, write: None

Tests run:
- Commands executed and their results
- If not run, explain why
```

All sections are REQUIRED unless explicitly stated otherwise.
If a section has no content, write `None` to make the omission explicit.

---

## Summary Guidelines

The **Summary** should:

* Be a short, high-signal list of changes.
* Avoid implementation details that belong in the diff.
* Use bullets; keep each bullet to one concept.

---

## Why Guidelines

The **Why** section must answer:

* Why is this change needed now?
* What would remain broken or unclear without it?

If the motivation is non-obvious, include a short background sentence.

---

## Assumptions Guidelines

The **Assumptions** section must:

* Call out any decisions made without full certainty.
* Identify constraints or external dependencies relied upon.

If no assumptions were made, write `None`.

---

## Determinism Notes (Simulation Changes)

When a PR touches simulation logic:

* Describe how RNG is seeded and passed.
* Call out any new randomness boundaries.
* Mention any determinism tests added or missing.

If no simulation logic is touched, write `None`.

---

## Tests Run

The **Tests run** section must:

* List exact commands executed.
* Note failures or skipped tests with a reason.

Example:

```
Tests run:
- cargo test
- pytest tests/sim/test_draft.py
```

---

## Scope Discipline

PRs MUST be split when:

* A refactor is combined with behavior changes.
* Multiple unrelated systems are touched.
* Formatting changes obscure logical changes.

---

## Review Guidance

If review attention is needed in a specific area, include an extra line:

```
Review guidance:
- Focus on draft generation in src/sim/draft.rs
```

This is optional and should only be included when it helps reviewers.
