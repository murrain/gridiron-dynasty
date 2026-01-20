# Theme System

**Author:** Engineering Protocols
**Date:** 2026-01-20
**Status:** Implemented

---

## Overview

The Theme System provides centralized color management with support for dark and light themes throughout the entire UI. It integrates seamlessly with the existing PanelStyles system and StatQueries rating colors.

## Architecture

### Components

1. **ThemeManager (Autoload)**
   - Global singleton for theme management
   - Stores dark and light theme color definitions
   - Provides theme switching functionality
   - Emits signals when theme changes

2. **PanelStyles Integration**
   - All panel colors pulled from ThemeManager
   - Automatic theme color support
   - Legacy COLORS constant maintained for backward compatibility

3. **StatQueries Integration**
   - Rating colors (elite → poor) use ThemeManager
   - Automatic theme support for stat displays
   - Legacy COLOR_* constants maintained for backward compatibility

---

## Features

### 1. Dual Theme Support

**Dark Theme (Default)**
- Dark backgrounds with light text
- Designed for low-light environments
- Reduced eye strain for extended use

**Light Theme**
- Light backgrounds with dark text
- Designed for bright environments
- High contrast for accessibility

### 2. Comprehensive Color Palette

Both themes include:

**Background Colors**
- `bg_darker` - Deepest nested panels
- `bg_dark` - Dark panels
- `bg_medium` - Standard panels
- `bg_light` - Light panels
- `bg_lighter` - Lighter panels

**Border Colors**
- `border_subtle` - Subtle borders
- `border_medium` - Medium borders
- `border_accent` - Accent borders

**Text Colors**
- `text_primary` - Primary text
- `text_secondary` - Secondary text
- `text_disabled` - Disabled text

**Semantic Colors**
- `primary` / `primary_border` / `primary_text` - Blue accent
- `secondary` / `secondary_border` / `secondary_text` - Purple accent
- `info` / `info_border` / `info_text` - Teal accent
- `warning` / `warning_border` / `warning_text` - Orange accent
- `success` / `success_border` / `success_text` - Green accent
- `error` / `error_border` / `error_text` - Red accent

**Rating Colors (Stats)**
- `rating_elite` - 90+ (green)
- `rating_great` - 80-89 (light green)
- `rating_good` - 70-79 (pale green)
- `rating_average` - 60-69 (yellow)
- `rating_below_avg` - 50-59 (orange)
- `rating_poor` - <50 (red)

### 3. Runtime Theme Switching

- Switch themes at runtime with single function call
- All integrated components automatically use new theme colors
- Signal emission for manual UI refresh when needed

### 4. Backward Compatibility

- Legacy color constants maintained in PanelStyles and StatQueries
- Existing code continues to work without changes
- Gradual migration path available

---

## Usage

### Basic Theme Switching

```gdscript
# Switch to light theme
ThemeManager.set_theme("light")

# Switch to dark theme
ThemeManager.set_theme("dark")

# Toggle between themes
ThemeManager.toggle_theme()

# Check active theme
if ThemeManager.is_dark_theme():
    print("Dark mode active")
```

### Getting Colors

```gdscript
# Get color from active theme
var bg_color := ThemeManager.get_color("bg_dark")
var text_color := ThemeManager.get_color("text_primary")

# Via PanelStyles (recommended for UI components)
var panel_bg := PanelStyles.get_color("bg_medium")

# Via StatQueries (for rating displays)
var rating_color := StatQueries.get_stat_color(85.0)  # Returns Color
var rating_hex := StatQueries.get_stat_color_hex(85.0)  # Returns "#66ff66"
```

### Reacting to Theme Changes

```gdscript
extends Control

func _ready() -> void:
    # Connect to theme change signal
    ThemeManager.theme_changed.connect(_on_theme_changed)

    # Apply initial theme
    _apply_current_theme()

func _on_theme_changed(theme_name: String) -> void:
    print("Theme changed to: ", theme_name)
    _apply_current_theme()

func _apply_current_theme() -> void:
    # Refresh UI colors
    var bg := ThemeManager.get_color("bg_medium")
    modulate = Color.WHITE  # Reset
    # ... apply colors to UI elements
```

### Using with ReactivePanels

```gdscript
extends ReactivePanelContainer

func _ready() -> void:
    super._ready()

    # Panels automatically use theme colors
    set_style_variant("primary")

    # Listen for theme changes if manual refresh needed
    ThemeManager.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(theme_name: String) -> void:
    # Re-apply style to pick up new theme colors
    apply_style()
```

---

## Implementation Details

### ThemeManager Color Dictionaries

Themes are defined as const dictionaries in ThemeManager:

```gdscript
const DARK_THEME := {
    "bg_dark": Color(0.10, 0.10, 0.12),
    "text_primary": Color(0.90, 0.90, 0.92),
    # ... all other colors
}

const LIGHT_THEME := {
    "bg_dark": Color(0.90, 0.90, 0.92),  # Inverted
    "text_primary": Color(0.10, 0.10, 0.12),  # Inverted
    # ... all other colors
}
```

### Color Retrieval Flow

1. UI component calls `PanelStyles.get_color("bg_dark")`
2. PanelStyles delegates to `ThemeManager.get_color("bg_dark")`
3. ThemeManager returns color from active theme dictionary
4. Fallback color returned if key not found

### Signal Propagation

```gdscript
# ThemeManager emits signal when theme changes
signal theme_changed(theme_name: String)

# UI components can connect to react
ThemeManager.theme_changed.connect(_on_theme_changed)
```

---

## Testing

Comprehensive test coverage:

**ThemeManager Tests** (`tests/ui/test_theme_manager.gd`)
- Theme switching functionality
- Color retrieval from both themes
- Signal emission verification
- Fallback behavior
- Integration with PanelStyles and StatQueries

**Test Coverage:**
- ✅ Default theme is dark
- ✅ Can switch to light theme
- ✅ Toggle between themes
- ✅ Invalid theme names rejected
- ✅ Color retrieval works for both themes
- ✅ Different colors per theme
- ✅ Fallback for missing keys
- ✅ All required color keys present
- ✅ Signals emit correctly
- ✅ PanelStyles integration
- ✅ StatQueries integration

Run tests:
```bash
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add res://tests/ui/test_theme_manager.gd --exit
```

---

## Design Decisions

### Why Autoload Singleton?

**Pros:**
- Global access without dependency injection
- Single source of truth for active theme
- Centralized signal emission
- No file I/O overhead
- Simple integration for all UI components

**Cons:**
- Global state (mitigated by read-only access pattern)
- Harder to mock in tests (mitigated by fallback mechanisms)

**Alternative Considered:** Resource-based themes (.tres files)
- Rejected due to file I/O overhead
- Dictionary approach simpler and faster
- Easier to extend programmatically

### Why Two-Tier Color Access?

UI components use `PanelStyles.get_color()` instead of direct ThemeManager access:

**Benefits:**
- Additional abstraction layer for future enhancements
- PanelStyles can provide additional color utilities
- Consistent API for panel-related styling
- ThemeManager remains focused on theme management

**Direct ThemeManager access** is available for non-panel components.

### Color Naming Convention

Colors use descriptive functional names:
- `bg_dark` not `color_1a1a1f`
- `text_primary` not `text_light`
- `rating_elite` not `green_bright`

**Benefits:**
- Semantic meaning clear from name
- Theme-agnostic (same names in dark and light)
- Easier to understand and maintain

---

## Migration Guide

### Migrating Hardcoded Colors

**Before:**
```gdscript
const BG_COLOR = Color(0.15, 0.15, 0.18)
const TEXT_COLOR = Color(0.9, 0.9, 0.92)

func _ready():
    background.color = BG_COLOR
    label.modulate = TEXT_COLOR
```

**After:**
```gdscript
func _ready():
    _apply_theme()
    ThemeManager.theme_changed.connect(_apply_theme)

func _apply_theme(_theme_name: String = "") -> void:
    background.color = ThemeManager.get_color("bg_medium")
    label.modulate = ThemeManager.get_color("text_primary")
```

### Migrating PanelStyles Usage

**Before:**
```gdscript
var bg_color := PanelStyles.COLORS["bg_dark"]  # Direct constant access
```

**After:**
```gdscript
var bg_color := PanelStyles.get_color("bg_dark")  # Uses ThemeManager
```

**Note:** Legacy `COLORS` constant still works but is deprecated.

### Migrating StatQueries Usage

**Before:**
```gdscript
const COLOR_ELITE = "#00ff00"
var color := COLOR_ELITE if rating >= 90 else "#ff0000"
```

**After:**
```gdscript
var color := StatQueries.get_stat_color_hex(rating)  # Automatic theme support
```

**Note:** Legacy `COLOR_*` constants still work but are deprecated.

---

## Future Enhancements

### Planned

1. **User Preference Persistence**
   - Save selected theme to user settings
   - Auto-load on startup
   - Per-user theme preferences

2. **Additional Themes**
   - High contrast theme for accessibility
   - Custom color schemes
   - User-defined themes

3. **Theme Loading from Config**
   - Load themes from JSON files
   - Hot-reload theme changes
   - Theme marketplace/sharing

### Under Consideration

1. **Smooth Transitions**
   - Animate color changes when switching themes
   - Fade between theme states
   - Configurable transition duration

2. **Automatic Panel Refresh**
   - Auto-refresh all ReactivePanels when theme changes
   - No manual signal connection needed
   - Opt-out available for performance

3. **Theme Preview**
   - Preview theme without applying
   - Side-by-side theme comparison
   - Theme editor UI

---

## Performance Considerations

### Memory

- **Themes stored as const dictionaries:** ~2KB per theme
- **No runtime allocations:** Colors accessed by reference
- **Minimal memory overhead:** ~4KB total for both themes

### Performance

- **Color lookups:** O(1) dictionary access
- **No file I/O:** All themes in memory
- **Signal emission:** Negligible overhead (~μs)
- **Theme switching:** Instant (<1ms)

### Optimization Tips

- Cache frequently-used colors in local variables
- Avoid repeated `get_color()` calls in `_process()`
- Use `theme_changed` signal for batch updates
- Disconnect signals when nodes are freed

---

## Troubleshooting

### Colors Not Changing on Theme Switch

**Symptom:** UI elements keep old colors after theme change

**Causes:**
1. Hardcoded colors not using ThemeManager
2. Missing `theme_changed` signal connection
3. Colors cached in variables not refreshed

**Solution:**
```gdscript
# Connect to theme change signal
ThemeManager.theme_changed.connect(_refresh_colors)

func _refresh_colors(_theme_name: String = "") -> void:
    # Re-fetch colors from ThemeManager
    my_color = ThemeManager.get_color("bg_dark")
```

### Missing Color Warning

**Symptom:** "ThemeManager: Color 'xyz' not found" warning

**Causes:**
1. Typo in color name
2. Color not defined in theme
3. Using wrong color key

**Solution:**
- Check spelling of color key
- Verify color exists in ThemeManager theme dictionaries
- Use fallback color: `get_color("xyz", Color.WHITE)`

### Performance Issues

**Symptom:** Lag when switching themes

**Causes:**
1. Too many signal connections
2. Heavy operations in `theme_changed` handlers
3. Excessive `_process()` color lookups

**Solution:**
- Batch color updates
- Cache colors in member variables
- Defer non-critical updates with `call_deferred()`

---

## API Reference

### ThemeManager

```gdscript
## Constants
const THEME_DARK := "dark"
const THEME_LIGHT := "light"
const DEFAULT_THEME := THEME_DARK

## Properties
var active_theme: String  # Currently active theme name

## Signals
signal theme_changed(theme_name: String)  # Emitted when theme switches

## Methods
func set_theme(theme_name: String) -> void
func toggle_theme() -> void
func get_color(color_name: String, fallback: Color = Color.MAGENTA) -> Color
func get_all_colors() -> Dictionary
func is_dark_theme() -> bool
func is_light_theme() -> bool
```

### PanelStyles Theme Integration

```gdscript
## Methods (updated to use ThemeManager)
static func get_color(color_name: String, fallback: Color = Color.WHITE) -> Color
static func create_style(variant: String, nesting_depth: int = 0, custom_config: Dictionary = {}) -> StyleBoxFlat

## Deprecated (use get_color() instead)
const COLORS: Dictionary  # Legacy fallback, does not change with theme
```

### StatQueries Theme Integration

```gdscript
## Methods (updated to use ThemeManager)
static func get_stat_color(value: float) -> Color
static func get_stat_color_hex(value: float) -> String

## Deprecated (use get_stat_color_hex() instead)
const COLOR_ELITE: String
const COLOR_GREAT: String
const COLOR_GOOD: String
const COLOR_AVERAGE: String
const COLOR_BELOW_AVG: String
const COLOR_POOR: String
```

---

## See Also

- **[PANEL_STYLE_SYSTEM.md](./PANEL_STYLE_SYSTEM.md)** - Panel styling documentation
- **[REACTIVE_PANEL_GUIDE.md](./REACTIVE_PANEL_GUIDE.md)** - ReactivePanel guide
- **[autoloads/ThemeManager.gd](/home/user/gridiron-dynasty/autoloads/ThemeManager.gd)** - Implementation
- **[tests/ui/test_theme_manager.gd](/home/user/gridiron-dynasty/tests/ui/test_theme_manager.gd)** - Test suite

---

**END OF THEME SYSTEM DOCUMENTATION**
