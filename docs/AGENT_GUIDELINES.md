# Agent Coding Guidelines

This document provides coding standards and best practices for AI agents working on this codebase.

## Function Optimization

### ❌ DON'T: Create separate `_optimized()` functions

**Bad Example:**
```gdscript
# Original function
func process_data(data: Array) -> Array:
    # ... implementation using dictionary lookups ...
    return result

# Optimized version (separate function)
func process_data_optimized(data: Array, config: Config = null) -> Array:
    # ... improved implementation ...
    return result
```

**Problems:**
- Code duplication (must maintain two implementations)
- API pollution (two function names for same operation)
- Maintenance burden (changes must be applied to both)
- Confusion for users (which version should I call?)

### ✅ DO: Improve functions in place with optional parameters

**Good Example:**
```gdscript
# Single function with optional optimization parameters
func process_data(data: Array, config: Config = null) -> Array:
    if config != null:
        # Optimized path using pre-extracted config
        return _process_with_config(data, config)
    else:
        # Fallback to dictionary lookups for backwards compatibility
        return _process_fallback(data)
```

**Benefits:**
- Single source of truth
- Clean API (one function name)
- Backwards compatible through optional parameters
- Performance benefits when optimization parameters provided

### Implementation Pattern

When improving an existing function's performance:

1. **Add optional parameters** with `null` defaults
2. **Add conditional logic** that uses optimized path when parameters provided
3. **Keep fallback path** for backwards compatibility
4. **Rename old code** to `_something_fallback()` if needed for fallback implementation
5. **Update callers** that can benefit from optimization to pass the parameters

**Example Refactoring:**

Before:
```gdscript
static func calculate_score(player: Dictionary, positions_cfg: Dictionary) -> float:
    var peak_age: int = positions_cfg.get("peak_age", 26)
    # ... more dictionary lookups ...
    return score
```

After:
```gdscript
static func calculate_score(
    player: Dictionary,
    positions_cfg: Dictionary,
    extracted_config: ExtractedConfig = null  # Optional optimization
) -> float:
    if extracted_config != null:
        # O(1) member access - fast path
        var peak_age: int = extracted_config.peak_age(player.position)
        # ...
    else:
        # O(log n) dictionary lookup - fallback for compatibility
        var peak_age: int = positions_cfg.get("peak_age", 26)
        # ...
    return score
```

### Config Extraction Pattern

When configuration access becomes a bottleneck:

1. **Create a config extraction class** (e.g., `DevelopmentConfig`, `WearConfig`)
2. **Pre-extract values** in `_init()` into member variables
3. **Provide O(1) accessor methods** for extracted values
4. **Update hot-path functions** to accept optional config parameter
5. **Maintain fallback path** using original dictionary access

See `scripts/support/config/DevelopmentConfig.gd` and `scripts/support/config/WearConfig.gd` for examples.

## Naming Conventions

- ❌ Avoid suffixes like `_optimized`, `_fast`, `_v2`, `_new`
- ✅ Use descriptive names: `calculate_with_cache()`, `build_parallel()`
- ✅ Use parameters to control behavior: `process(data, parallel: bool = false)`

## Backwards Compatibility

When improving existing functions:

1. **Preserve existing call signatures** by making new parameters optional
2. **Default to old behavior** when optional parameters not provided
3. **Document migration path** in function docstring
4. **Update callers incrementally** to benefit from optimizations

## Testing

When refactoring functions:

1. **Verify tests pass** with default parameters (fallback path)
2. **Verify tests pass** with optimization parameters (fast path)
3. **Add tests** if coverage is insufficient
4. **Check performance** with benchmarks if optimizing hot paths

---

**Last Updated:** 2026-01-10
**Reason:** Consolidated `_optimized` function pattern to eliminate code duplication
