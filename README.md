# Gridiron Dynasty

A deterministic American football simulation and dynasty management game built with Godot 4.5.

## Overview

Gridiron Dynasty simulates the complete lifecycle of football players from high school through college recruiting, NFL draft, and professional careers. The simulation features deterministic RNG for reproducible results, comprehensive player development systems, and realistic scouting and valuation mechanics.

## Key Features

- **Deterministic Simulation**: Identical seeds produce identical outcomes for testing and debugging
- **Multi-Level Pipeline**: High school generation → College recruiting → NFL draft → Pro seasons
- **Player Lifecycle**: Age-based development, decline curves, injury systems, retirement logic
- **Scouting System**: Scouts with varying skills evaluate players with realistic uncertainty
- **Player Valuation**: Market-based valuation incorporating positional scarcity and team context
- **Performance Optimized**: 84% faster bootstrap time through parallel processing and config caching

## Quick Start

### Prerequisites

- Godot Engine 4.5 (stable)
- 8GB+ RAM recommended
- Multi-core CPU recommended for parallel features

### Installation

1. **Install Godot Engine 4.5**
   - Download from [godotengine.org](https://godotengine.org/download)
   - Or use package manager: `flatpak install flathub org.godotengine.Godot`

2. **Clone Repository**
   ```bash
   git clone https://github.com/murrain/gridiron-dynasty.git
   cd gridiron-dynasty
   ```

3. **Open in Godot**
   - Launch Godot Engine
   - Click "Import"
   - Navigate to project directory
   - Select `project.godot`
   - Click "Import & Edit"

### Running the Simulation

```bash
# Open project in Godot Editor
godot -e

# Or run headless for testing
godot --headless --script scripts/tests/TestRunner.gd

# Run fast unit tests
godot --headless --script scripts/tests/TestRunnerFast.gd

# Run benchmarks
godot --headless --script scripts/tests/BenchmarkRunner.gd
```

### Project Structure

```
gridiron-dynasty/
├── autoloads/              # Global singletons (Config, Rand, ThreadPool, App)
├── scripts/
│   ├── benchmarks/         # Benchmark utilities and tools
│   ├── core/               # Core systems organized by domain
│   │   ├── finance/        # Contract and salary cap systems
│   │   ├── models/         # Data models (Player, Scout, Team, etc.)
│   │   ├── rating/         # Rating calculation systems
│   │   ├── scouting/       # Scout evaluation and caching
│   │   ├── trades/         # Trade valuation logic
│   │   └── valuation/      # Player valuation systems
│   ├── generation/         # Entity generation (players, teams, schools)
│   ├── pipelines/          # Major simulation phases (recruiting, draft, seasons)
│   ├── world/              # World state management and lifecycle
│   ├── support/            # Utilities, helpers, and config extraction
│   └── tests/              # Comprehensive test suite (83+ tests)
├── configs/                # JSON configuration files
│   ├── sports/american_football/  # Position configs, stats definitions, scouts
│   └── trades/             # Trade valuation curves and rules
├── docs/                   # Documentation and task tracking
│   ├── tasks/              # Individual feature task specifications
│   └── architectural_notes/ # Design decisions and resolutions
└── [Additional files]      # Scene files (.tscn), project config, etc.
```

*Note: Simplified view showing key directories. See repository for complete structure.*

## Development

### Coding Standards

See `docs/AGENT_GUIDELINES.md` for comprehensive coding standards including:
- Function optimization patterns (avoid `_optimized` suffix duplication)
- Config extraction for hot paths
- Backwards compatibility strategies
- Testing requirements

### Running Tests

The project has extensive test coverage organized by feature area:

```bash
# Fast tests only (~10 seconds)
godot --headless -s scripts/tests/TestRunnerFast.gd

# Full test suite (~2-3 minutes)
godot --headless -s scripts/tests/TestRunner.gd

# Specific test category
godot --headless -s scripts/tests/TestRunnerRecruitingCache.gd
```

Test categories:
- **Core utilities**: RNG, ThreadPool, Config loading
- **Generation**: Players, teams, schools, classes
- **Scouting**: Scout models, evaluation, caching
- **Pipelines**: Recruiting, draft, seasons
- **Lifecycle**: Player development, retirement, injuries
- **Valuation**: Player value, contract calculations, market supply
- **Performance**: Copy optimization, parallel processing, config caching

### Performance Features

#### Parallel Processing

For large simulations (100+ players), parallel processing provides 2x+ speedup:

```gdscript
# Automatically detect CPU cores
PlayerLifecycle.advance_one_year_parallel(players, configs...)

# Or specify thread count
PlayerLifecycle.advance_one_year_parallel(players, configs..., threads=8)
```

#### Config Optimization

Pre-extract config values for O(1) access in hot paths:

```gdscript
# Create once, reuse many times
var dev_config = DevelopmentConfig.new(positions_cfg, main_cfg)
var ret_config = RetirementConfig.new(main_cfg)

# 10x faster than dictionary lookups
PlayerLifecycle.advance_one_year(players, configs..., dev_config, ret_config)
```

#### Memory Optimization

Skip report generation during bootstrap to save memory:

```gdscript
# Reduces memory by 75MB per year
var result = PlayerLifecycle.advance_one_year(
    players, configs...,
    options={"skip_reports": true}
)
```

## Architecture Principles

### Determinism

All simulation logic maintains strict determinism:
- Fixed seed → identical results across runs and platforms
- RNG consumption patterns explicitly managed
- Cache hits consume identical RNG as cache misses
- Parallel processing uses deterministic seed derivation (splitmix64)

### Thread Safety

Parallel features are designed for safety:
- No shared mutable state between threads
- Config dictionaries deep-copied per thread (Godot Dictionary not thread-safe)
- Independent RNG instances per player
- Per-thread cache instances for recruiting evaluation

### Performance Patterns

1. **Selective Copying**: Copy only mutable fields that change
2. **Config Extraction**: Pre-compute O(1) accessors for hot paths
3. **Parallel Processing**: Deterministic seed derivation + thread isolation
4. **Deferred Generation**: Skip expensive operations when not needed
5. **Memoization**: Cache expensive computations with deterministic keys

## Documentation

- `docs/README.md` - Documentation overview and directory structure
- `docs/tasks/` - Individual feature task specifications
- `docs/AGENT_GUIDELINES.md` - Coding standards for AI agents
- `docs/PHASE_F_ROADMAP.md` - Performance optimization roadmap
- `docs/architectural_notes/` - Historical design decisions

## Contributing

**Status**: Active Development | Pre-Alpha

### Getting Started
1. Check `docs/tasks/README.md` for available tasks
2. Read `docs/AGENT_GUIDELINES.md` for coding standards
3. Review `docs/contributing/COMMIT_STYLE.md` for commit conventions

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following task specifications
4. Run tests to verify implementation (`godot --headless -s scripts/tests/TestRunner.gd`)
5. Commit with descriptive message following `docs/contributing/COMMIT_STYLE.md`
6. Push to your fork and submit a Pull Request

### Bug Reports & Feature Requests
- Open an issue on GitHub with detailed description
- For bugs: include reproduction steps and Godot version
- For features: explain use case and expected behavior

### Questions?
- Check existing documentation in `docs/`
- Review architectural notes in `docs/architectural_notes/`
- Open a discussion on GitHub

## Performance Benchmarks

Recent optimizations (PR #82) achieved:

- **Bootstrap Time**: 720s → 75s (84% improvement)
- **Memory Usage**: 2.27GB → 224MB per year (90% reduction)
- **Config Access**: 5us → 0.5us per lookup (10x faster)
- **Scout Evaluation**: 2000x+ cache hit rate in recruiting

See `docs/metrics/BENCHMARKS.md` for detailed performance data.

## License

This project's license is to be determined. Until a license is added, all rights are reserved by the author(s).

For contributors: Please await license clarification before submitting contributions.

## Credits

**Maintainer**: [To be added]

**Built With**:
- [Godot Engine 4.5](https://godotengine.org) - Game engine and simulation framework
- [Claude Code](https://claude.com/claude-code) - AI-assisted development and optimization

**Acknowledgments**:
- Performance optimization work (PR #82) achieved 84% improvement through systematic profiling and parallel processing
- Test suite covers 83+ test cases ensuring deterministic simulation behavior
