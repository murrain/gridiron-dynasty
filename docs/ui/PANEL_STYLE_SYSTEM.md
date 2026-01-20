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

---

## Implementation Details

### Files Created

1. **`scripts/ui/base/PanelStyles.gd`**
   - Centralized style configuration class
   - Color palette constants
   - Spacing constants
   - Style creation utilities

2. **`scripts/ui/base/ExampleNestedPanels.gd`**
   - Complete demonstration scene
   - Shows all style variants
   - Demonstrates nesting behavior
   - Interactive style changes

3. **`tests/ui/test_panel_styles.gd`**
   - Comprehensive unit tests
   - Tests all style variants
   - Tests nesting detection
   - Integration tests

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

3. **`docs/ui/REACTIVE_PANEL_GUIDE.md`**
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
# Create a custom style
var style := PanelStyles.create_style("warning", 0, {
    "padding": 16,
    "corner_radius": 8
})

# Access colors
var bg_color := PanelStyles.get_color("bg_dark")

# Access spacing
var padding := PanelStyles.get_spacing("md")
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
## Create a style for a variant
static func create_style(
    variant: String,
    nesting_depth: int = 0,
    custom_config: Dictionary = {}
) -> StyleBoxFlat

## Get a color from the palette
static func get_color(color_name: String, fallback: Color = Color.WHITE) -> Color

## Get a spacing value
static func get_spacing(spacing_name: String, fallback: int = 8) -> int

## Get a corner radius value
static func get_corner_radius(radius_name: String, fallback: int = 4) -> int
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
- Single source of truth for colors
- Consistent spacing across UI
- Easy theme customization (change colors in one place)
- Reusable across non-ReactivePanel widgets

---

## Testing

The style system is fully tested with:
- Unit tests for `PanelStyles` utility
- Unit tests for `ReactivePanel` styling
- Unit tests for `ReactivePanelContainer` styling
- Integration tests for nesting behavior
- Tests for all 9 style variants

Run tests with:
```bash
godot --path . --script addons/gut/gut_cmdln.gd -gtest=res://tests/ui/test_panel_styles.gd
```

---

## Migration Guide

### Converting Existing Panels

If you have existing ReactivePanel or ReactivePanelContainer instances:

1. **No changes required** - Style system is opt-in via `auto_apply_style`
2. **To use styles** - Set `style_variant` property:
   ```gdscript
   # In editor: Set "Style Variant" property
   # Or in code:
   panel.set_style_variant("primary")
   ```

3. **For full style support** - Use ReactivePanelContainer:
   ```gdscript
   # Before
   extends ReactivePanel

   # After (for full StyleBox support)
   extends ReactivePanelContainer
   ```

---

## Future Enhancements

Potential improvements:

1. **Custom theme files** - Load themes from `.tres` files
2. **Dynamic palette** - Hot-reload colors from config
3. **Animation support** - Smooth transitions between variants
4. **Additional variants** - Add more semantic variants (e.g., "critical", "highlight")
5. **Border customization** - Per-side border width configuration

---

## See Also

- **[REACTIVE_PANEL_GUIDE.md](./REACTIVE_PANEL_GUIDE.md)** - Complete ReactivePanel documentation
- **[scripts/ui/base/PanelStyles.gd](/home/user/gridiron-dynasty/scripts/ui/base/PanelStyles.gd)** - Style utility implementation
- **[scripts/ui/base/ExampleNestedPanels.gd](/home/user/gridiron-dynasty/scripts/ui/base/ExampleNestedPanels.gd)** - Live examples
- **[tests/ui/test_panel_styles.gd](/home/user/gridiron-dynasty/tests/ui/test_panel_styles.gd)** - Test suite

---

**END OF PANEL STYLE SYSTEM DOCUMENTATION**
