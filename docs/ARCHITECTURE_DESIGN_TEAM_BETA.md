# Architecture Design: Medical & Character Risk Systems

## ARCHITECTURAL ASSESSMENT

### Impact Scope
- **New Services**: `CollegeMedicalService.gd`, `CharacterService.gd`
- **Modified Configs**: `configs/sports/american_football/main.json` (add medical_evaluation section)
- **New Configs**: `configs/sports/american_football/character_system.json`
- **Integration Points**: `CollegeSeason.gd`, `NflDraft.gd`
- **Data Model Extensions**: Player dictionary fields for medical and character tracking

---

## System Integration Analysis

### Existing Injury System (PlayerLifecycle.gd)
The codebase already has a comprehensive NFL injury system at lines 883-1051:
- Injury generation with weighted type selection
- Severity, recovery timeline, affected stats
- Career-ending injury flags
- Active injury suppression
- Long-term stat penalties

**Key Finding**: We should **reuse** this injury engine for college, not duplicate it.

### Player Data Model (SportPlayer.gd)
Current injury tracking (line 71):
```gdscript
var injuries: Array[Dictionary] = []
```

Injury structure from PlayerLifecycle (lines 1024-1038):
```gdscript
{
    "type": String,
    "severity": float,
    "affected_stats": Array,
    "recovery_timeline": {...},
    "long_term_penalty": {...},
    "career_ending": bool
}
```

---

## Architectural Decisions

### Decision 1: Reuse Existing Injury System
**Rationale**: PlayerLifecycle already implements injury mechanics. We extend it for college context rather than duplicate.

**Approach**:
- `CollegeMedicalService` wraps `PlayerLifecycle._apply_injury()` and `_generate_injury()`
- Adds college-specific injury tracking (year, games_missed)
- Adds pre-draft medical evaluation layer

**Benefits**:
- Single source of truth for injury mechanics
- Consistent injury behavior across college/NFL
- Reduced code duplication
- Easier maintenance

### Decision 2: Medical Evaluation as Draft-Time Calculation
**Rationale**: Medical grades are assessed at draft time, not during college seasons.

**Approach**:
- `CollegeSeason` tracks injuries naturally via PlayerLifecycle
- `NflDraft` calls `CollegeMedicalService.evaluate_medical_status()` before draft evaluation
- Medical grade impacts draft position via scout score adjustment

### Decision 3: Character Tracking as Separate System
**Rationale**: Discipline events are discrete occurrences, unlike continuous injury risk.

**Approach**:
- `CharacterService` handles discipline events independently
- Stores events in player dictionary field `character_profile`
- Character grade calculated at draft time from event history

---

## Data Model Extensions

### Player Dictionary Additions

```gdscript
# Medical tracking (extends existing injuries array)
"college_injury_context": {
    "year": int,          # College year when injured
    "games_missed": int   # Games missed this season
}  # Added to each injury dict during college

# Medical evaluation (added at draft time)
"medical_evaluation": {
    "grade": String,  # "clean", "minor_concern", "major_concern", "failed"
    "red_flags": Array[String],
    "durability_projection": float,
    "draft_impact": float  # Multiplier for draft score (0.7-1.0)
}

# Character tracking (new)
"character_profile": {
    "discipline_record": [
        {"year": int, "type": String, "games": int, "reason": String}
    ],
    "character_grade": String,  # "exemplary", "clean", "concern", "red_flag"
    "character_draft_impact": float  # Multiplier for draft score (0.7-1.0)
}
```

---

## Service Design

### CollegeMedicalService.gd

**Purpose**: Medical evaluation layer for draft, wrapping existing injury system

**Static Functions**:
```gdscript
class_name CollegeMedicalService

# Called by CollegeSeason during player lifecycle processing
static func apply_college_injury_context(
    player: Dictionary,
    year: int,
    games_in_season: int
) -> void:
    # Annotates most recent injury with college context
    # Called after PlayerLifecycle.advance_one_year() generates injuries

# Called by NflDraft before scout evaluation
static func evaluate_medical_status(
    player: Dictionary,
    config: Dictionary
) -> Dictionary:
    # Analyzes injury history
    # Returns medical_evaluation dict
    # Considers: injury count, severity, surgeries, recurring patterns

# Helper for draft score adjustment
static func calculate_draft_medical_impact(
    player: Dictionary,
    config: Dictionary
) -> float:
    # Returns multiplier: 1.0 (clean) to 0.0 (failed)
    # Used by NflDraft scout evaluation

# Pattern detection
static func check_for_recurring_injury(
    player: Dictionary,
    new_injury_type: String,
    config: Dictionary
) -> bool:
    # Checks if player has 2+ injuries of same type
```

**RNG Pattern**: None (deterministic analysis of existing injury data)

### CharacterService.gd

**Purpose**: Track discipline events and character grading

**Static Functions**:
```gdscript
class_name CharacterService

# Called by CollegeSeason after player lifecycle
static func apply_discipline_events(
    player: Dictionary,
    year: int,
    config: Dictionary,
    rng: RandomNumberGenerator
) -> Dictionary:
    # Rolls for discipline events (base 2% chance)
    # Appends to character_profile.discipline_record
    # Returns event dict if occurred, empty dict otherwise

# Called by NflDraft before scout evaluation
static func evaluate_character_grade(
    player: Dictionary,
    config: Dictionary
) -> String:
    # Analyzes discipline_record
    # Returns: "exemplary", "clean", "concern", "red_flag"

# Helper for draft score adjustment
static func calculate_character_draft_impact(
    player: Dictionary,
    config: Dictionary
) -> float:
    # Returns multiplier based on character_grade
    # exemplary: 1.02, clean: 1.0, concern: 0.95, red_flag: 0.70-0.90

# Interview simulation (optional depth)
static func simulate_interview_red_flag_detection(
    player: Dictionary,
    scout: Dictionary,
    config: Dictionary,
    rng: RandomNumberGenerator
) -> Array:
    # Simulates pre-draft visit
    # Returns array of detected red flags
    # Higher scout skill = better detection
```

**RNG Pattern**:
- `apply_discipline_events`: 1-2 calls per player per year (event roll, severity roll)
- `simulate_interview_red_flag_detection`: 1 call per red flag check

---

## Integration Points

### CollegeSeason.gd Integration

**Location**: After `PlayerLifecycle.advance_one_year_parallel()` (line 98)

```gdscript
# After player lifecycle progression
for i in range(updated_players.size()):
    var p: Variant = updated_players[i]
    if p == null:
        continue

    # PHASE 4: Medical context annotation
    # Annotate any new injuries with college context
    CollegeMedicalService.apply_college_injury_context(p, year, 12)  # 12 games

    # PHASE 5: Character events
    # Roll for discipline events
    var discipline_rng := RandomNumberGenerator.new()
    discipline_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E6 ^ i)
    CharacterService.apply_discipline_events(p, year, char_config, discipline_rng)
```

### NflDraft.gd Integration

**Location**: Before scout evaluation in `_score_draft_pool()` (line 607)

```gdscript
func _score_draft_pool(...) -> Array:
    # ... existing code ...

    for player in candidates:
        var p: Dictionary = player

        # PHASE 4: Medical evaluation (once per draft, cached)
        if not p.has("medical_evaluation"):
            p["medical_evaluation"] = CollegeMedicalService.evaluate_medical_status(p, main_cfg)

        # PHASE 5: Character evaluation (once per draft, cached)
        if not p.has("character_profile") or not p["character_profile"].has("character_grade"):
            if not p.has("character_profile"):
                p["character_profile"] = {"discipline_record": []}
            p["character_profile"]["character_grade"] = CharacterService.evaluate_character_grade(p, char_config)

        # Existing scout evaluation
        var base_score := score_cache.get_or_compute(...)

        # PHASE 4+5: Apply risk factor adjustments
        var medical_impact := CollegeMedicalService.calculate_draft_medical_impact(p, main_cfg)
        var character_impact := CharacterService.calculate_character_draft_impact(p, char_config)

        var risk_adjusted_score := base_score * medical_impact * character_impact
        # ... continue with needs weighting, etc ...
```

---

## Configuration Structure

### main.json additions (medical section)

```json
{
    "college_injury_system": {
        "enabled": true,
        "note": "Uses existing PlayerLifecycle injury system with college context",
        "games_per_season": 12
    },
    "medical_evaluation": {
        "grade_criteria": {
            "clean": {"max_injuries": 1, "max_surgeries": 0, "max_severity_sum": 3.0},
            "minor_concern": {"max_injuries": 2, "max_surgeries": 1, "max_severity_sum": 6.0},
            "major_concern": {"max_injuries": 4, "max_surgeries": 2, "max_severity_sum": 12.0},
            "failed": {"triggers": ["career_ending", "recurring_major", "multiple_surgeries"]}
        },
        "recurring_injury_multiplier": 1.5,
        "surgery_required_types": ["knee", "shoulder", "back"],
        "draft_impact_multipliers": {
            "clean": 1.0,
            "minor_concern": 0.95,
            "major_concern": 0.85,
            "failed": 0.70
        }
    }
}
```

### character_system.json (new file)

```json
{
    "discipline_events": {
        "base_chance_per_year": 0.02,
        "types": [
            {
                "type": "academic",
                "weight": 0.4,
                "games_range": [1, 4],
                "severity": "minor",
                "draft_penalty": 0.98
            },
            {
                "type": "team_rules",
                "weight": 0.3,
                "games_range": [1, 2],
                "severity": "minor",
                "draft_penalty": 0.99
            },
            {
                "type": "substance_abuse",
                "weight": 0.15,
                "games_range": [2, 6],
                "severity": "moderate",
                "draft_penalty": 0.90
            },
            {
                "type": "conduct",
                "weight": 0.10,
                "games_range": [1, 8],
                "severity": "major",
                "draft_penalty": 0.85
            },
            {
                "type": "legal_trouble",
                "weight": 0.05,
                "games_range": [4, 16],
                "severity": "severe",
                "draft_penalty": 0.70
            }
        ]
    },
    "character_grades": {
        "exemplary": {
            "max_incidents": 0,
            "draft_boost": 1.02,
            "description": "No discipline issues, high character"
        },
        "clean": {
            "max_incidents": 1,
            "max_severity": "minor",
            "draft_impact": 1.0,
            "description": "Minor or single incident only"
        },
        "concern": {
            "max_incidents": 2,
            "max_severity": "moderate",
            "draft_penalty": 0.95,
            "description": "Multiple minor or moderate issues"
        },
        "red_flag": {
            "triggers": ["legal_trouble", "multiple_major", "pattern"],
            "draft_penalty_range": [0.70, 0.90],
            "description": "Serious character concerns"
        }
    },
    "interview_red_flags": {
        "enabled": false,
        "note": "Phase 2 enhancement - interview simulation",
        "detection_chance_base": 0.30,
        "scout_skill_bonus": 0.25
    }
}
```

---

## Phase Boundaries and Future Extensibility

### Phase 1 (Current Work Package)
- Basic medical evaluation from injury history
- Basic character grading from discipline events
- Draft impact multipliers

### Phase 2 (Future)
- Pre-draft visit interviews (red flag detection)
- Medical combine tests (drug screening, physical exams)
- Background checks and team interview notes
- Scout disagreement on character (some scouts weigh more heavily)

### Scaffolding for Phase 2
- `simulate_interview_red_flag_detection()` stub included
- Character config has `interview_red_flags` section (disabled)
- Medical evaluation dict has `red_flags: Array` field for future use

---

## Determinism Guarantees

### RNG Seed Derivation
```gdscript
# CollegeSeason integration
var medical_rng := RandomNumberGenerator.new()
medical_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E6)

var discipline_rng := RandomNumberGenerator.new()
discipline_rng.seed = Rand.splitmix64(seed ^ 0xC011E6E7)
```

### RNG Consumption Patterns
- **Medical**: 0 RNG calls (deterministic analysis of existing injuries)
- **Character - Discipline Events**: 1-2 calls per player per year
  - Call 1: Event occurrence roll (randf())
  - Call 2: Event type selection (weighted random)
  - Call 3: Games suspended (randi_range())

### Expected Total RNG Calls
- 400 college players × 4 years × 0.02 event rate × 3 calls = ~96 calls per draft class
- Negligible compared to existing lifecycle RNG consumption

---

## Quality Assurance

### Compilation Verification
```bash
godot --headless --check-only --script /path/to/CollegeMedicalService.gd
godot --headless --check-only --script /path/to/CharacterService.gd
```

### Runtime Verification
```bash
godot --headless -s scripts/pipelines/BootstrapPreview.gd
```

Expected output:
- No crashes from new services
- Draft pool contains medical_evaluation and character_profile fields
- Draft scores reflect risk adjustments

### Integration Tests
1. Generate 100 players with varied injury histories
2. Verify medical grades match criteria
3. Verify character grades match event patterns
4. Verify draft impact multipliers are applied correctly

---

## Risk Assessment

### Low Risk
- ✅ Reuses existing injury system (no new injury mechanics)
- ✅ Adds fields to player dictionaries (non-breaking, optional)
- ✅ Static services match existing patterns
- ✅ Minimal RNG consumption
- ✅ Config-driven (tunable without code changes)

### Medium Risk
- ⚠️ Integration with CollegeSeason requires careful placement after lifecycle
- ⚠️ Integration with NflDraft requires score adjustment before final sort
- **Mitigation**: Thorough testing with BootstrapPreview.gd

### Architecture Violations to Avoid
- ❌ DO NOT create new injury generation logic (reuse PlayerLifecycle)
- ❌ DO NOT modify existing Player.gd Resource class (use dictionary extensions)
- ❌ DO NOT add dependencies between CollegeMedicalService and CharacterService
- ❌ DO NOT consume RNG in medical evaluation (deterministic only)

---

## Success Criteria

### Functional
- [ ] Medical grades correctly classify players based on injury history
- [ ] Character grades correctly classify players based on discipline events
- [ ] Draft scores adjust appropriately for risk factors
- [ ] No false positives (players with no issues get "clean" grades)

### Architectural
- [ ] All code passes compilation checks
- [ ] All code passes BootstrapPreview.gd runtime test
- [ ] Services follow static function pattern
- [ ] RNG threading is explicit with documented consumption
- [ ] Config files are well-structured and commented

### Code Quality
- [ ] Code review score ≥9.5/10
- [ ] Comments explain WHY (design rationale), not WHAT
- [ ] No magic numbers (all values in config)
- [ ] Functions have single responsibilities
- [ ] Determinism is provable (seed → outcome mapping)

---

## Decision: APPROVED FOR IMPLEMENTATION

**Rationale**:
- Reuses existing injury system (reduces risk)
- Follows established patterns (static services, explicit RNG, config-driven)
- Minimal architectural impact (adds fields, doesn't modify core systems)
- Clear integration points with well-defined boundaries
- Extensible for Phase 2 (interview simulation, combine tests)
- Deterministic and testable

**Recommendations**:
1. Implement CollegeMedicalService first (simpler, no RNG)
2. Test medical evaluation in isolation before integration
3. Implement CharacterService second (adds RNG complexity)
4. Integration testing with small draft pool before full bootstrap
5. Document any deviations from this design in commit messages

---

## Implementation Order

1. **Create CollegeMedicalService.gd** (no RNG, deterministic)
2. **Create CharacterService.gd** (adds RNG)
3. **Create character_system.json**
4. **Modify main.json** (add medical_evaluation section)
5. **Verify compilation** for all new files
6. **Test with BootstrapPreview.gd**
7. **Address any issues found in testing**
8. **Request code quality review**

---

**Architect**: Team Beta Architect
**Date**: 2026-01-13
**Status**: Design Approved, Ready for Implementation
