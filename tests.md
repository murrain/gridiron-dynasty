# Tests

## Current testing level

- **Unit tests (GDScript):** A lightweight, headless test runner executes targeted
  unit tests for core simulation helpers, including RNG utilities, config
  loading/merging, generation helpers, combine calculations, player lifecycle,
  and world systems (calendar/high schools). The tests live under
  `scripts/tests/` and rely on fixture configs in
  `scripts/tests/fixtures/`.
- **Coverage goal:** The current suite is intended to exercise most non-UI
  logic paths in deterministic, config-driven subsystems.

## How to run

### Best practice (headless)

Use Godot’s headless mode so tests run quickly and deterministically without
rendering:

```
# From repo root
Godot --headless -s res://scripts/tests/TestRunner.gd
```

Notes:
- Prefer a fixed Godot version in CI to keep RNG and serialization behavior
  stable across runs.
- The test runner returns exit code `0` on success and non-zero on failure.

### Optional: CI integration

- Add a CI step that installs the project’s target Godot version and runs the
  headless command above.
- Capture console output to preserve failure context.
