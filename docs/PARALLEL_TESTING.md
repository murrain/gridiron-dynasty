# Parallel Testing Configuration

This document describes the parallel test execution setup for GdUnit4 tests.

## Overview

GdUnit4 v6 executes tests sequentially within a single process. To achieve parallelism, we run multiple Godot instances simultaneously, each processing a subset of tests (shards).

## Architecture

```
                    +------------------+
                    |  Test Dispatcher |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |         |          |          |         |
   +----v----+ +--v----+ +---v---+ +----v----+
   | Shard 1 | | Shard 2| | Shard 3| | Shard 4 |
   | Godot   | | Godot  | | Godot  | | Godot   |
   +---------+ +--------+ +--------+ +---------+
        |         |          |          |
        +--------------------+--------------------+
                             |
                    +--------v---------+
                    |  Result Aggregator|
                    +------------------+
```

## Configuration Files

### CI/CD Workflow: `.github/workflows/gdunit4-tests.yml`

The GitHub Actions workflow splits tests across 4 parallel runners:

- **Shard Distribution**: Tests are sorted alphabetically and divided evenly
- **Retry Mechanism**: Each shard retries up to 2 times on failure
- **Artifact Collection**: Test logs and reports are uploaded for each shard
- **Summary Report**: Aggregates results from all shards

### Local Runner: `scripts/tests/run_tests_parallel.sh`

For local development, use the parallel runner script:

```bash
# Run with default 4 shards
./scripts/tests/run_tests_parallel.sh

# Run with custom shard count
./scripts/tests/run_tests_parallel.sh 8
```

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Full suite (sequential) | < 150s | Single Godot process |
| Full suite (4 shards) | < 45s | Parallel execution |
| CI pipeline total | < 10 min | Including setup/teardown |
| Individual test | < 5s | Except integration tests |

## Determinism Requirements

When running tests in parallel:

1. **Test Isolation**: Each test must be independent - no shared state between test files
2. **Explicit Seeds**: All RNG operations use explicit seeds
3. **Cache Cleanup**: Clear SnapshotLoader cache in teardown
4. **No File Conflicts**: Shards write to separate report directories

Example test pattern:
```gdscript
extends GdUnitTestSuite

func before() -> void:
    # Setup runs before each test file
    pass

func after() -> void:
    # Cleanup after each test file
    SnapshotLoader.clear_cache()

func test_something() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345  # Explicit seed for determinism
    # Test code here
```

## Troubleshooting

### Flaky Tests

If tests pass locally but fail in CI:
1. Check for race conditions in shared resources
2. Verify explicit seeds are used
3. Ensure cache cleanup in `after()` hook
4. Check for timing-dependent assertions

### Shard Imbalance

If some shards take much longer:
1. Large integration tests should be distributed evenly
2. Consider test file naming conventions for better distribution
3. Adjust shard count based on test characteristics

### CI Timeout

If CI pipeline times out:
1. Increase `timeout-minutes` in workflow
2. Add more shards to distribute load
3. Profile slow tests for optimization

## Monitoring

### Test Metrics

The following metrics are tracked:
- Total test count per shard
- Execution time per shard
- Pass/fail rate per shard
- Retry count (indicates flakiness)

### Reports

Test reports are generated in:
- Local: `reports/shard-N/`
- CI: Uploaded as artifacts `test-results-shard-N`

## Future Improvements

1. **Dynamic Sharding**: Split based on historical test duration
2. **Test Caching**: Skip unchanged tests
3. **Flaky Test Detection**: Automatic retry and reporting
4. **HTML Dashboard**: Visual test result dashboard
