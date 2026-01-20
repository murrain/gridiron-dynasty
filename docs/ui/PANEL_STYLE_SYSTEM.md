# ReactivePanel Style System

**Author:** Engineering Protocols
**Date:** 2026-01-20
**Status:** Implemented

---

## Overview

The ReactivePanel Style System provides a built-in theming and styling solution for all ReactivePanel and ReactivePanelContainer instances. It offers consistent colors, automatic nesting detection with visual hierarchy, and a comprehensive palette system.

## Features

### 1. Style Variants

9 pre-configured style variants for different use cases:

- **default**: Standard dark panel (medium background, subtle border)
- **primary**: Blue accent for primary actions
- **secondary**: Purple accent for secondary actions
- **info**: Teal accent for informational content
- **warning**: Orange accent for warnings and cautions
- **success**: Green accent for success messages
- **error**: Red accent for errors and critical alerts
- **nested**: Auto-darkening based on nesting depth
- **transparent**: Invisible panel (no background or border)

### 2. Automatic Nesting Detection

Panels automatically detect when they're nested inside other ReactivePanel or ReactivePanelContainer instances:

- Calculates nesting depth (0 = top-level, 1 = first child, etc.)
- Auto-darkens background based on depth (for "nested" variant)
- Auto-indents based on depth for visual hierarchy

### 3. Centralized Color Palette

Consistent dark theme color palette:

#### Background Colors
- `bg_darker`: #121215 (deepest nested)
- `bg_dark`: #1a1a1f (dark panels)
- `bg_medium`: #252530 (standard)
- `bg_light`: #33333d (light)

#### Border Colors
- `border_subtle`: #3a3a45
- `border_medium`: #4a4a59
- `border_accent`: #4a6a9a

#### Semantic Colors
- `primary`: #2a4a7a (blue)
- `secondary`: #4a3a6a (purple)
- `info`: #2a5a6a (teal)
- `warning`: #7a5a2a (orange)
- `success`: #2a6030 (green)
- `error`: #7a1f1f (red)

### 4. Consistent Spacing

Standard spacing constants:

- `xs`: 4px
- `sm`: 8px
- `md`: 12px (default)
- `lg`: 16px
- `xl`: 24px

### 5. Dynamic Theme Support

The panel system integrates with **ThemeManager** for dynamic dark/light theme switching:

- All colors pulled from ThemeManager automatically
- Supports both dark and light themes
- Theme switching via `ThemeManager.set_theme("light")` or `ThemeManager.toggle_theme()`
- Panels using `PanelStyles.get_color()` automatically use active theme colors
- StatQueries rating colors also support theme switching

#### Theme Colors

Both dark and light themes include:
- Background progression colors (bg_darker → bg_lighter)
- Border colors (subtle → accent)
- Text colors (primary, secondary, disabled)
- Semantic colors (primary, secondary, info, warning, success, error)
- Rating colors (elite → poor, green → red scale)

---

## Implementation Details

### Files Created

1. **`autoloads/ThemeManager.gd`**
   - Global theme manager autoload
   - Dark and light theme definitions
   - Theme switching logic
   - Signal emission on theme changes
   - Registered as autoload in project.godot

2. **`scripts/ui/base/PanelStyles.gd`**
   - Centralized style configuration class
   - Integrates with ThemeManager for colors
   - Spacing constants
   - Style creation utilities
   - Legacy COLORS constant for backward compatibility

3. **`scripts/ui/base/ExampleNestedPanels.gd`**
   - Complete demonstration scene
   - Shows all style variants
   - Demonstrates nesting behavior
   - Interactive style changes

4. **`tests/ui/test_panel_styles.gd`**
   - Comprehensive unit tests
   - Tests all style variants
   - Tests nesting detection
   - Integration tests

5. **`tests/ui/test_theme_manager.gd`**
   - ThemeManager unit tests
   - Theme switching tests
   - Color retrieval tests
   - Signal emission tests
   - Integration tests with PanelStyles and StatQueries

### Files Modified

1. **`scripts/ui/base/ReactivePanel.gd`**
   - Added style configuration exports
   - Added `apply_style()` method
   - Added `set_style_variant()` method
   - Added nesting detection methods
   - Auto-applies style on `_ready()`

2. **`scripts/ui/base/ReactivePanelContainer.gd`**
   - Added style configuration exports
   - Added `apply_style()` method
   - Added `set_style_variant()` method
   - Added nesting detection methods
   - Full StyleBox support (better than ReactivePanel)

3. **`scripts/ui/world_explorer/queries/StatQueries.gd`**
   - Updated to use ThemeManager for rating colors
   - Deprecated legacy COLOR_* constants
   - `get_stat_color_hex()` now pulls from active theme
   - Falls back to legacy constants if ThemeManager unavailable

4. **`project.godot`**
   - Added ThemeManager as autoload singleton

5. **`docs/ui/REACTIVE_PANEL_GUIDE.md`**
   - Added comprehensive style system documentation
   - Added nesting examples
   - Added color palette reference
   - Added style best practices
   - Added style troubleshooting

---

## Usage Examples

### Basic Usage

```gdscript
extends ReactivePanelContainer
class_name MyPanel

func _ready() -> void:
    super._ready()

    # Style is automatically applied with default variant
    # To change the variant:
    set_style_variant("primary")
```

### Nested Panels

```gdscript
# Parent panel
var parent := ReactivePanelContainer.new()
parent.style_variant = "default"
add_child(parent)

# Child panel (auto-detects nesting)
var child := ReactivePanelContainer.new()
child.style_variant = "nested"  # Auto-darkens
child.auto_indent_nested = true  # Adds 8px left margin
parent.add_child(child)

# Grandchild (even darker, more indented)
var grandchild := ReactivePanelContainer.new()
grandchild.style_variant = "nested"  # Darker still
child.add_child(grandchild)  # 16px left margin
```

### Using PanelStyles Directly

```gdscript
# Create a custom style (uses active theme colors)
var style := PanelStyles.create_style("warning", 0, {
    "padding": 16,
    "corner_radius": 8
})

# Access colors from active theme
var bg_color := PanelStyles.get_color("bg_dark")
var text_color := PanelStyles.get_color("text_primary")

# Access spacing
var padding := PanelStyles.get_spacing("md")
```

### Theme Switching

```gdscript
# Switch to light theme
ThemeManager.set_theme("light")

# Switch to dark theme
ThemeManager.set_theme("dark")

# Toggle between dark and light
ThemeManager.toggle_theme()

# Check active theme
if ThemeManager.is_dark_theme():
    print("Dark mode active")

# Get a color from the active theme
var bg_color := ThemeManager.get_color("bg_dark")

# React to theme changes
func _ready() -> void:
    ThemeManager.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(theme_name: String) -> void:
    print("Theme changed to: ", theme_name)
    # Refresh UI elements that need manual updates
    apply_style()  # For ReactivePanel/ReactivePanelContainer
```

### Using Rating Colors

```gdscript
# Get rating color for a stat value (auto-uses active theme)
var rating := 85.0
var color_hex := StatQueries.get_stat_color_hex(rating)  # Returns "#66ff66"
var color := StatQueries.get_stat_color(rating)  # Returns Color object

# Use in BBCode
var bbcode := "[color=%s]%d[/color]" % [color_hex, rating]
```

---

## Exported Properties

### ReactivePanel & ReactivePanelContainer

Both classes expose the following configuration:

```gdscript
## Style variant
@export_enum("default", "primary", "secondary", "info", "warning", "success", "error", "nested", "transparent")
var style_variant: String = "default"

## Auto-indent nested panels
@export var auto_indent_nested: bool = true

## Indent amount per nesting level (pixels)
@export_range(0, 32, 1) var nest_indent: int = 8

## Apply style automatically on ready
@export var auto_apply_style: bool = true
```

---

## Public API

### ReactivePanel / ReactivePanelContainer

```gdscript
## Apply the current style variant
func apply_style() -> void

## Change variant and apply
func set_style_variant(variant: String) -> void

## Check if nested (private but documented)
func _is_nested() -> bool

## Get nesting depth (private but documented)
func _get_nesting_depth() -> int
```

### PanelStyles (Static Class)

```gdscript
## Create a style for a variant (uses active theme colors)
static func create_style(
    variant: String,
    nesting_depth: int = 0,
    custom_config: Dictionary = {}
) -> StyleBoxFlat

## Get a color from the active theme
static func get_color(color_name: String, fallback: Color = Color.WHITE) -> Color

## Get a spacing value
static func get_spacing(spacing_name: String, fallback: int = 8) -> int

## Get a corner radius value
static func get_corner_radius(radius_name: String, fallback: int = 4) -> int
```

### ThemeManager (Autoload Singleton)

```gdscript
## Set the active theme ("dark" or "light")
func set_theme(theme_name: String) -> void

## Toggle between dark and light themes
func toggle_theme() -> void

## Get a color from the active theme
func get_color(color_name: String, fallback: Color = Color.MAGENTA) -> Color

## Get all colors from the active theme
func get_all_colors() -> Dictionary

## Check if dark theme is active
func is_dark_theme() -> bool

## Check if light theme is active
func is_light_theme() -> bool

## Signal emitted when theme changes
signal theme_changed(theme_name: String)
```

### StatQueries (Static Class)

```gdscript
## Get color for stat value (uses active theme, returns Color)
static func get_stat_color(value: float) -> Color

## Get color for stat value (uses active theme, returns hex string)
static func get_stat_color_hex(value: float) -> String
```

---

## Design Decisions

### 1. Why ReactivePanelContainer over ReactivePanel?

**ReactivePanelContainer** extends `PanelContainer`, which has built-in support for `StyleBoxFlat`. This means:
- Full border rendering
- Corner radius support
- Better visual fidelity

**ReactivePanel** extends `Control`, which doesn't have built-in panel styling. It uses a `ColorRect` background as a fallback, which only supports background color (no borders or corners).

**Recommendation:** Use `ReactivePanelContainer` for all new panels.

### 2. Why Auto-Apply Style?

By default, `auto_apply_style` is `true`, which means styles are applied automatically in `_ready()`. This provides:
- Zero-configuration styling
- Consistent behavior across panels
- No manual `apply_style()` calls needed

You can disable it for manual control:
```gdscript
panel.auto_apply_style = false
panel.style_variant = "warning"
panel.apply_style()  # Manual control
```

### 3. Why Nesting Detection?

Nesting detection enables:
- Visual hierarchy (darker = more nested)
- Auto-indenting for layout clarity
- Automatic depth calculation

This creates clear parent-child relationships without manual configuration.

### 4. Why Centralized PanelStyles Class?

The `PanelStyles` utility class provides:
- Single source of truth for styling logic
- Consistent spacing across UI
- Easy integration with ThemeManager
- Reusable across non-ReactivePanel widgets

### 5. Why ThemeManager Autoload?

ThemeManager is implemented as an autoload singleton because:
- **Global access:** All UI components can access theme colors without dependency injection
- **Signal propagation:** Centralized theme_changed signal reaches all connected components
- **State management:** Single source of truth for active theme
- **Performance:** Theme colors are cached in dictionaries, no file I/O needed
- **Simplicity:** No need to pass theme references through constructors

**Architecture benefits:**
- PanelStyles delegates color retrieval to ThemeManager
- StatQueries uses ThemeManager for rating colors
- Future UI components can easily integrate by calling `ThemeManager.get_color()`
- Theme switching is a single function call that affects all UI instantly

**Alternative considered:** Resource-based themes (.tres files) were considered but rejected because:
- Dictionary-based approach is simpler and more maintainable
- No need for resource loading/unloading
- Easier to extend with new colors
- Better performance (no disk I/O)

---

## Testing

The style and theme system is fully tested with:
- Unit tests for `ThemeManager` (theme switching, color retrieval, signals)
- Unit tests for `PanelStyles` utility
- Unit tests for `ReactivePanel` styling
- Unit tests for `ReactivePanelContainer` styling
- Integration tests for nesting behavior
- Integration tests for ThemeManager with PanelStyles and StatQueries
- Tests for all 9 style variants
- Tests for dark and light theme color differences

Run tests with:
```bash
# Test ThemeManager
godot --path . --script addons/gut/gut_cmdln.gd -gtest=res://tests/ui/test_theme_manager.gd

# Test PanelStyles
godot --path . --script addons/gut/gut_cmdln.gd -gtest=res://tests/ui/test_panel_styles.gd

# Run all UI tests
godot --path . --script addons/gut/gut_cmdln.gd -gdir=res://tests/ui/
```

---

## Migration Guide

### Converting Existing Panels

If you have existing ReactivePanel or ReactivePanelContainer instances:

1. **No changes required** - Style system is opt-in via `auto_apply_style`
2. **Colors automatically use ThemeManager** - All PanelStyles colors now pull from active theme
3. **To use styles** - Set `style_variant` property:
   ```gdscript
   # In editor: Set "Style Variant" property
   # Or in code:
   panel.set_style_variant("primary")
   ```

4. **For full style support** - Use ReactivePanelContainer:
   ```gdscript
   # Before
   extends ReactivePanel

   # After (for full StyleBox support)
   extends ReactivePanelContainer
   ```

### Migrating Hardcoded Colors

If you have hardcoded colors in your UI code:

**Before:**
```gdscript
var bg_color := Color(0.15, 0.15, 0.18)  # Hardcoded dark gray
var text_color := Color(0.9, 0.9, 0.92)  # Hardcoded light gray
```

**After:**
```gdscript
var bg_color := ThemeManager.get_color("bg_medium")
var text_color := ThemeManager.get_color("text_primary")
```

**Benefits:**
- Automatically supports dark/light theme switching
- Consistent colors across the entire UI
- Single place to update colors (ThemeManager)

### Migrating StatQueries Rating Colors

**Before:**
```gdscript
# Hardcoded colors
const COLOR_ELITE = "#00ff00"
var color_hex := COLOR_ELITE
```

**After:**
```gdscript
# Use ThemeManager colors (automatic)
var color_hex := StatQueries.get_stat_color_hex(rating)
# No changes needed! StatQueries now uses ThemeManager internally
```

---

## Future Enhancements

Completed enhancements:
- ✅ **Theme system** - ThemeManager with dark/light themes
- ✅ **Dynamic colors** - Colors pulled from active theme
- ✅ **Theme switching** - Runtime theme switching with signals

Potential future improvements:

1. **User preference persistence** - Save/load theme preference from config
2. **Additional themes** - High contrast, custom color schemes
3. **Theme loading from files** - Load custom themes from JSON/tres files
4. **Animation support** - Smooth transitions when switching themes
5. **Additional variants** - Add more semantic variants (e.g., "critical", "highlight")
6. **Border customization** - Per-side border width configuration
7. **Automatic theme refresh** - Auto-refresh all panels when theme changes
8. **Theme preview** - Live preview of theme changes before applying

---

## See Also

- **[REACTIVE_PANEL_GUIDE.md](./REACTIVE_PANEL_GUIDE.md)** - Complete ReactivePanel documentation
- **[autoloads/ThemeManager.gd](/home/user/gridiron-dynasty/autoloads/ThemeManager.gd)** - Theme manager implementation
- **[scripts/ui/base/PanelStyles.gd](/home/user/gridiron-dynasty/scripts/ui/base/PanelStyles.gd)** - Style utility implementation
- **[scripts/ui/world_explorer/queries/StatQueries.gd](/home/user/gridiron-dynasty/scripts/ui/world_explorer/queries/StatQueries.gd)** - Rating color utilities
- **[scripts/ui/base/ExampleNestedPanels.gd](/home/user/gridiron-dynasty/scripts/ui/base/ExampleNestedPanels.gd)** - Live examples
- **[tests/ui/test_theme_manager.gd](/home/user/gridiron-dynasty/tests/ui/test_theme_manager.gd)** - ThemeManager test suite
- **[tests/ui/test_panel_styles.gd](/home/user/gridiron-dynasty/tests/ui/test_panel_styles.gd)** - PanelStyles test suite

---

**END OF PANEL STYLE SYSTEM DOCUMENTATION**
