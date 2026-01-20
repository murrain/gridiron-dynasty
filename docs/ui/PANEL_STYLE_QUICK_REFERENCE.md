# ReactivePanel Style System - Quick Reference

---

## Style Variants Cheat Sheet

```gdscript
panel.style_variant = "default"      # Standard dark panel
panel.style_variant = "primary"      # Blue accent
panel.style_variant = "secondary"    # Purple accent
panel.style_variant = "info"         # Teal accent
panel.style_variant = "warning"      # Orange accent
panel.style_variant = "success"      # Green accent
panel.style_variant = "error"        # Red accent
panel.style_variant = "nested"       # Auto-darkening by depth
panel.style_variant = "transparent"  # Invisible
```

---

## Color Palette Cheat Sheet

```gdscript
# Backgrounds (dark theme)
PanelStyles.COLORS["bg_darker"]   # #121215 (deepest)
PanelStyles.COLORS["bg_dark"]     # #1a1a1f
PanelStyles.COLORS["bg_medium"]   # #252530 (default)
PanelStyles.COLORS["bg_light"]    # #33333d

# Borders
PanelStyles.COLORS["border_subtle"]  # #3a3a45
PanelStyles.COLORS["border_accent"]  # #4a6a9a

# Semantic colors
PanelStyles.COLORS["primary"]     # #2a4a7a (blue)
PanelStyles.COLORS["secondary"]   # #4a3a6a (purple)
PanelStyles.COLORS["info"]        # #2a5a6a (teal)
PanelStyles.COLORS["warning"]     # #7a5a2a (orange)
PanelStyles.COLORS["success"]     # #2a6030 (green)
PanelStyles.COLORS["error"]       # #7a1f1f (red)
```

---

## Spacing Cheat Sheet

```gdscript
PanelStyles.SPACING["xs"]  # 4px
PanelStyles.SPACING["sm"]  # 8px
PanelStyles.SPACING["md"]  # 12px (default)
PanelStyles.SPACING["lg"]  # 16px
PanelStyles.SPACING["xl"]  # 24px
```

---

## Common Patterns

### Basic Styled Panel

```gdscript
var panel := ReactivePanelContainer.new()
panel.style_variant = "primary"
add_child(panel)
# Style auto-applies on ready
```

### Nested Panels

```gdscript
var parent := ReactivePanelContainer.new()
parent.style_variant = "default"
add_child(parent)

var child := ReactivePanelContainer.new()
child.style_variant = "nested"  # Auto-darkens
parent.add_child(child)
```

### Dynamic Style Change

```gdscript
panel.set_style_variant("warning")  # Changes and reapplies
```

### Custom Style

```gdscript
var style := PanelStyles.create_style("primary", 0, {
    "padding": 16,
    "corner_radius": 8,
    "border_width": 2
})
panel.add_theme_stylebox_override("panel", style)
```

### Disable Auto-Indent

```gdscript
panel.auto_indent_nested = false  # No left margin
```

### Manual Style Control

```gdscript
panel.auto_apply_style = false
panel.style_variant = "error"
panel.apply_style()  # Apply manually
```

---

## Configuration Properties

```gdscript
@export_enum(...) var style_variant: String = "default"
@export var auto_indent_nested: bool = true
@export_range(0, 32, 1) var nest_indent: int = 8
@export var auto_apply_style: bool = true
```

---

## Public Methods

```gdscript
panel.apply_style()                    # Apply current style
panel.set_style_variant("warning")     # Change and apply
panel._is_nested()                     # Check if nested
panel._get_nesting_depth()             # Get depth (0 = top-level)
```

---

## PanelStyles Static Methods

```gdscript
PanelStyles.create_style(variant, depth, config)
PanelStyles.get_color(name, fallback)
PanelStyles.get_spacing(name, fallback)
PanelStyles.get_corner_radius(name, fallback)
```

---

## Best Practices

✅ **DO:**
- Use `ReactivePanelContainer` for full StyleBox support
- Use semantic variants (`warning`, `error`, `success`)
- Use "nested" variant for hierarchical layouts
- Disable auto-indent for horizontal layouts
- Use `PanelStyles` constants for consistency

❌ **DON'T:**
- Don't hardcode colors
- Don't nest too deeply (> 3 levels)
- Don't forget to call `apply_style()` when `auto_apply_style = false`
- Don't use large `nest_indent` values (> 16px)

---

## Common Issues

**Style not showing?**
- Check `auto_apply_style` is `true`
- Or call `apply_style()` manually

**No borders/corners on ReactivePanel?**
- Use `ReactivePanelContainer` instead

**Panels not indenting?**
- Check `auto_indent_nested = true`
- Verify panel is actually nested

**Indent too much?**
- Reduce `nest_indent` value
- Or disable: `auto_indent_nested = false`

---

**See full documentation:** [REACTIVE_PANEL_GUIDE.md](./REACTIVE_PANEL_GUIDE.md)
