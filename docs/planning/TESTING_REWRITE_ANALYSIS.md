# Testing Suite Rewrite Analysis

**Date**: 2026-01-13
**Status**: Analysis Complete
**Decision**: Hybrid Approach Recommended

---

## Executive Summary

After comprehensive review, a **full rewrite is NOT recommended**. Instead, a **targeted modernization** approach will deliver 80% of the benefits at 30% of the cost and risk.

| Approach | Effort | Risk | Benefit | Recommendation |
|----------|--------|------|---------|----------------|
| Full Rewrite | High (3-4 weeks) | High | 100% | Not recommended |
| Incremental Patches | Low (1 week) | Low | 40% | Partial |
| **Hybrid Modernization** | **Medium (1-2 weeks)** | **Low-Medium** | **80%** | **Recommended** |

---

## Current State Assessment

### Strengths to Preserve

1. **Determinism Patterns** - Seeded RNG throughout, reproducible tests
2. **Domain-Specific Helpers** - `create_test_player()`, `assert_schema()`, etc.
3. **Benchmark Infrastructure** - Performance tracking with baseline comparison
4. **Test Organization** - Clear naming conventions, feature-grouped tests
5. **Fast Test Runner** - 31 unit tests in ~10 seconds

### Pain Points to Address

| Problem | Impact | Current Workaround |
|---------|--------|-------------------|
| No parallel execution | Slow full suite (120-140s) | TestRunnerFast for quick feedback |
| No coverage metrics | Unknown gaps | Manual tracking in docs |
| Code duplication | 200+ LOC repeated | Being consolidated |
| No watch mode | Manual re-runs | None |
| Large test files | Hard to navigate | Splitting in progress |
| No fixture snapshots | Slow data-dependent tests | **Just implemented** |

---

## Full Rewrite Analysis

### What a Full Rewrite Would Involve

1. **New Test Framework** - GdUnit4, Gut, or custom v2
2. **Migrate 100+ Test Files** - Convert all existing tests
3. **New Helper Library** - Rebuild TestHelpers.gd
4. **New Runner Infrastructure** - Parallel execution, watch mode
5. **New CI Integration** - Update all workflows

### Estimated Effort

| Component | LOC | Effort |
|-----------|-----|--------|
| Framework Selection & Setup | - | 2-3 days |
| TestHelpers v2 | ~500 | 2-3 days |
| Migrate 70 Core Tests | ~7,000 | 5-7 days |
| Migrate 30+ Additional Tests | ~3,000 | 3-4 days |
| Runner Infrastructure | ~300 | 2 days |
| CI Integration | - | 1 day |
| Debugging & Stabilization | - | 3-5 days |
| **Total** | ~11,000 | **18-25 days** |

### Risks of Full Rewrite

1. **Regression Risk** - Tests are the safety net; rewriting them is inherently risky
2. **Feature Freeze** - No new features during migration
3. **Knowledge Loss** - Some test intent may be lost in translation
4. **Framework Lock-in** - New framework may have its own limitations
5. **Team Velocity** - Learning curve for new patterns

---

## Available GDScript Testing Frameworks

### Option 1: GdUnit4

**Pros:**
- Active development
- Built-in mocking
- Scene testing
- Coverage reports (partial)
- Parallel execution

**Cons:**
- Heavy IDE integration (less suited for headless)
- Complex setup
- Learning curve

### Option 2: Gut (Godot Unit Test)

**Pros:**
- Mature, well-documented
- Simple API
- Good headless support
- Active community

**Cons:**
- No built-in coverage
- Limited parallel execution
- Some Godot 4.x issues

### Option 3: Keep Custom Framework (Modernize)

**Pros:**
- No migration risk
- Preserves domain knowledge
- Full control
- Known patterns

**Cons:**
- Need to build missing features
- Maintenance burden

---

## Recommended: Hybrid Modernization

### Phase 1: Enhance Current Framework (1 week)

Keep `TestHelpers.gd` and `TestRunner.gd`, add missing features:

#### 1.1 Parallel Test Execution

```gdscript
# scripts/tests/TestRunnerParallel.gd
extends SceneTree

const TestHelpers = preload("res://scripts/tests/TestHelpers.gd")

# Number of parallel workers
const WORKER_COUNT := 4

var _test_queue: Array = []
var _results: Array = []
var _workers_done := 0

func _init() -> void:
    _test_queue = TEST_SCRIPTS.duplicate()
    _run_parallel()

func _run_parallel() -> void:
    var threads: Array = []

    for i in range(WORKER_COUNT):
        var thread := Thread.new()
        thread.start(_worker_run.bind(i))
        threads.append(thread)

    # Wait for all threads
    for thread in threads:
        thread.wait_to_finish()

    _report_results()

func _worker_run(worker_id: int) -> void:
    while true:
        var test_path: String
        _queue_mutex.lock()
        if _test_queue.is_empty():
            _queue_mutex.unlock()
            break
        test_path = _test_queue.pop_front()
        _queue_mutex.unlock()

        var result := _run_single_test(test_path)
        _results_mutex.lock()
        _results.append(result)
        _results_mutex.unlock()
```

**Expected Speedup**: 2-4x (120s → 30-60s)

#### 1.2 Coverage Tracking (Manual but Systematic)

```gdscript
# scripts/tests/CoverageTracker.gd
class_name CoverageTracker
extends RefCounted

# Track which functions are exercised by tests
static var _coverage: Dictionary = {}

static func mark_covered(file_path: String, function_name: String) -> void:
    if not _coverage.has(file_path):
        _coverage[file_path] = {}
    _coverage[file_path][function_name] = true

static func report() -> Dictionary:
    return _coverage.duplicate()

static func export_json(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(_coverage, "\t"))
    file.close()
```

#### 1.3 Watch Mode (Shell Script)

```bash
#!/bin/bash
# scripts/tests/watch_tests.sh

LAST_HASH=""

while true; do
    CURRENT_HASH=$(find scripts -name "*.gd" -exec md5sum {} \; | md5sum)

    if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
        echo "Changes detected, running tests..."
        godot --headless -s res://scripts/tests/TestRunnerFast.gd
        LAST_HASH=$CURRENT_HASH
    fi

    sleep 2
done
```

#### 1.4 Test Tagging System

```gdscript
# Enhanced TestHelpers.gd
class_name TestHelpers
extends RefCounted

enum Tag { UNIT, INTEGRATION, E2E, SLOW, SNAPSHOT_REQUIRED }

var _tags: Array = []

func tag(t: Tag) -> TestHelpers:
    _tags.append(t)
    return self

func skip_if_tag_excluded(excluded_tags: Array) -> bool:
    for tag in _tags:
        if tag in excluded_tags:
            return true
    return false

# Usage in test:
# func run(t: TestHelpers) -> void:
#     t.tag(TestHelpers.Tag.SLOW)
#     t.tag(TestHelpers.Tag.SNAPSHOT_REQUIRED)
#     if t.skip_if_tag_excluded([TestHelpers.Tag.SLOW]):
#         return
```

### Phase 2: Consolidation (3-5 days)

From existing TEST_IMPROVEMENT_PLAN.md:

1. **Consolidate Determinism Patterns** - Save 200+ LOC
2. **Split Large Test Files** - Improve navigation
3. **Add Missing Tests** - Error handling, edge cases
4. **Document Coverage Requirements** - Per-system minimums

### Phase 3: Snapshot Integration (Already Done)

- ✅ SnapshotGenerator.gd created
- ✅ SnapshotLoader.gd created
- ✅ test_snapshot_loader.gd created
- ⏳ Generate actual snapshots (run generator)

---

## Comparison: Rewrite vs Modernization

| Feature | Full Rewrite | Hybrid Modernization |
|---------|--------------|---------------------|
| Parallel Execution | ✅ Built-in | ✅ Add via threads |
| Coverage Tracking | ✅ GdUnit4 | ⚠️ Manual tracking |
| Watch Mode | ✅ Built-in | ✅ Shell script |
| Test Tagging | ✅ Built-in | ✅ Add to TestHelpers |
| Mocking | ✅ Built-in | ⚠️ Manual stubs |
| Scene Testing | ✅ Built-in | ❌ Not needed |
| Migration Risk | ❌ High | ✅ None |
| Effort | ❌ 18-25 days | ✅ 5-7 days |
| Feature Freeze | ❌ Yes | ✅ No |

---

## Implementation Roadmap

### Week 1: Core Enhancements

| Day | Task | Owner |
|-----|------|-------|
| 1 | Add TestRunnerParallel.gd | Agent |
| 1-2 | Add test tagging system to TestHelpers.gd | Agent |
| 2 | Create watch_tests.sh | Agent |
| 3 | Generate world state snapshots | Script |
| 3-4 | Consolidate determinism patterns (Track 1.1) | Agent |
| 4-5 | Add error handling tests (Track 2.1) | Agent |

### Week 2: Polish & Documentation

| Day | Task | Owner |
|-----|------|-------|
| 1-2 | Add edge case tests (Track 2.2) | Agent |
| 2-3 | Split large test files (Track 3.1) | Agent |
| 3-4 | Add API contract tests (Track 3.2) | Agent |
| 4-5 | Document coverage requirements | Agent |
| 5 | Update CI for parallel runner | Agent |

---

## Decision Matrix

| Criterion | Weight | Rewrite | Modernize |
|-----------|--------|---------|-----------|
| Risk Mitigation | 30% | 2/5 | 5/5 |
| Development Velocity | 25% | 2/5 | 4/5 |
| Long-term Maintainability | 20% | 4/5 | 3/5 |
| Feature Completeness | 15% | 5/5 | 3/5 |
| Effort Efficiency | 10% | 2/5 | 5/5 |
| **Weighted Score** | 100% | **2.65** | **4.05** |

---

## Conclusion

**Recommendation: Hybrid Modernization**

The current testing infrastructure is fundamentally sound. The issues (speed, coverage, data generation) can be addressed through targeted enhancements without the risk and effort of a full rewrite.

**Immediate Actions:**

1. ✅ Implement snapshot infrastructure (DONE)
2. Add parallel test runner
3. Add test tagging system
4. Consolidate existing tests (per TEST_IMPROVEMENT_PLAN.md)
5. Document coverage requirements

**Future Consideration:**

If the codebase grows significantly (200+ test files, 500+ functions), revisit the rewrite decision. By then, GdUnit4 or Gut may have better Godot 4.x support and the migration effort may be justified.

---

*Analysis by Director Agent - 2026-01-13*
