# Game Saves Implementation Plan
**Feature**: Game Save System for Gridiron Dynasty
**Status**: Planning Phase
**Created**: 2026-01-16
**Target**: Post-Phase 3 (Database Persistence Complete)

---

## Executive Summary

Implement a complete game save system that allows players to:
- Generate new worlds with custom seeds
- Save world state after generation
- Load saved games from a save selection menu
- View save metadata (date, year, team counts)

**Key Insight**: Much of the backend infrastructure already exists. This plan focuses on:
1. Adding a main menu UI layer
2. Implementing save metadata tracking
3. Integrating save/load into the existing flow
4. Ensuring RNG state persistence for determinism

**Estimated Total Effort**: 24-32 hours over 1-2 weeks

---

## Current System Analysis

### What Exists (Phase 3 Complete)

✅ **Persistence Backend** (`/home/user/gridiron-dynasty/autoloads/PersistenceLayer.gd`)
- Abstraction layer supporting JSON and SQLite backends
- `save_world_state()` and `load_world_state()` methods
- `list_saves()` and `delete_save()` utilities
- Transaction support for SQLite

✅ **Database Layer** (`/home/user/gridiron-dynasty/scripts/persistence/`)
- `DatabasePersistence.gd`: SQLite save/load implementation
- `PlayerDAO.gd` and `TeamDAO.gd`: Entity-level persistence
- Full schema in `schema.sql` with player/team/roster tables
- Migration tool for JSON → SQLite conversion

✅ **World Generation** (`/home/user/gridiron-dynasty/scripts/pipelines/`)
- `BootstrapGameWorld.gd`: Multi-year world orchestrator
- `AdvanceWorldYear.gd`: Year-by-year simulation with phases
- Deterministic RNG via `Rand.splitmix64()`
- Produces comprehensive `world_state` dictionary

✅ **Entry Point** (`/home/user/gridiron-dynasty/scenes/main/world_explorer_main.tscn`)
- `WorldExplorerMain.gd`: Runs bootstrap, shows loading screen, launches WorldExplorer UI
- Currently auto-generates world on startup (no menu)

✅ **World State Structure**
```gdscript
{
  "current_year": 2025,
  "nfl_teams": [Team, ...],
  "nfl_rosters": {team_id: {players: [Player, ...], starters: {}, depth_chart: {}}},
  "nfl_players": [Player, ...],
  "colleges": [College, ...],
  "college_rosters": {college_id: {players: [Player, ...]}},
  "college_players": [Player, ...],
  "hs_schools": [School, ...],
  "hs_players": [Player, ...],
  "retired_players": [Player, ...],
  "draft_pool": {year: [Player, ...]},
  "free_agents": [Player, ...]
}
```

### What's Missing

❌ **Main Menu Scene**
- No UI for New Game / Continue Game selection
- No seed input field for deterministic world generation
- No settings configuration (years to bootstrap, etc.)

❌ **Save Metadata System**
- No tracking of save creation date/time
- No world state "snippet" (summary stats) for save preview
- No RNG base_seed persistence for replay

❌ **Continue Game UI**
- No scene to list available saves
- No display of save metadata (date, year, team counts)
- No save selection/deletion interface

❌ **Save Lifecycle Integration**
- No auto-save after world generation
- No "Save Game" option in WorldExplorer
- No save/load error handling UX

---

## Implementation Plan

### Phase 1: Save Metadata System (8-10 hours)

**Goal**: Track metadata alongside save files for preview in Continue Game UI

#### 1.1: Design Save Metadata Schema
**File**: New - `scripts/persistence/SaveMetadata.gd`

```gdscript
extends Resource
class_name SaveMetadata

@export var save_name: String = ""
@export var created_at: int = 0  # Unix timestamp
@export var updated_at: int = 0  # Unix timestamp
@export var current_year: int = 2025
@export var base_seed: int = 0  # RNG seed for determinism
@export var years_simulated: int = 0
@export var persistence_backend: String = "sqlite"  # "json" or "sqlite"

# World state summary (for preview)
@export var nfl_team_count: int = 0
@export var nfl_player_count: int = 0
@export var college_count: int = 0
@export var college_player_count: int = 0
@export var retired_player_count: int = 0

# User-facing
@export var display_name: String = ""  # Optional custom name

func from_world_state(world_state: Dictionary, save_name: String, base_seed: int) -> void:
	self.save_name = save_name
	self.created_at = Time.get_unix_time_from_system()
	self.updated_at = self.created_at
	self.current_year = int(world_state.get("current_year", 2025))
	self.base_seed = base_seed
	self.persistence_backend = "sqlite"  # Default

	# Extract counts for preview
	self.nfl_team_count = (world_state.get("nfl_teams", []) as Array).size()
	self.nfl_player_count = _count_nfl_players(world_state)
	self.college_count = (world_state.get("colleges", []) as Array).size()
	self.college_player_count = _count_college_players(world_state)
	self.retired_player_count = (world_state.get("retired_players", []) as Array).size()

	# Generate display name if not set
	if display_name.is_empty():
		display_name = "Year %d - %s" % [current_year, Time.get_datetime_string_from_unix_time(created_at)]

func get_formatted_date() -> String:
	var dt = Time.get_datetime_dict_from_unix_time(created_at)
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func get_world_summary() -> String:
	return "%d NFL Teams | %d Players | %d Colleges | %d Retired" % \
		[nfl_team_count, nfl_player_count, college_count, retired_player_count]

func to_dict() -> Dictionary:
	return {
		"save_name": save_name,
		"created_at": created_at,
		"updated_at": updated_at,
		"current_year": current_year,
		"base_seed": base_seed,
		"years_simulated": years_simulated,
		"persistence_backend": persistence_backend,
		"nfl_team_count": nfl_team_count,
		"nfl_player_count": nfl_player_count,
		"college_count": college_count,
		"college_player_count": college_player_count,
		"retired_player_count": retired_player_count,
		"display_name": display_name
	}

func from_dict(d: Dictionary) -> void:
	save_name = String(d.get("save_name", ""))
	created_at = int(d.get("created_at", 0))
	updated_at = int(d.get("updated_at", 0))
	current_year = int(d.get("current_year", 2025))
	base_seed = int(d.get("base_seed", 0))
	years_simulated = int(d.get("years_simulated", 0))
	persistence_backend = String(d.get("persistence_backend", "sqlite"))
	nfl_team_count = int(d.get("nfl_team_count", 0))
	nfl_player_count = int(d.get("nfl_player_count", 0))
	college_count = int(d.get("college_count", 0))
	college_player_count = int(d.get("college_player_count", 0))
	retired_player_count = int(d.get("retired_player_count", 0))
	display_name = String(d.get("display_name", ""))

func _count_nfl_players(world_state: Dictionary) -> int:
	var rosters: Dictionary = world_state.get("nfl_rosters", {})
	var total := 0
	for team_id in rosters.keys():
		var roster_data = rosters[team_id]
		if roster_data is Dictionary:
			total += (roster_data.get("players", []) as Array).size()
	return total

func _count_college_players(world_state: Dictionary) -> int:
	var rosters: Dictionary = world_state.get("college_rosters", {})
	var total := 0
	for college_id in rosters.keys():
		var roster: Dictionary = rosters[college_id]
		total += (roster.get("players", []) as Array).size()
	return total
```

**Acceptance Criteria**:
- [ ] SaveMetadata resource created with all fields
- [ ] Extracts world_state summary statistics correctly
- [ ] Provides formatted date/time strings for UI
- [ ] Serializes to/from Dictionary for JSON storage
- [ ] Unit tests verify count extraction logic

#### 1.2: Extend PersistenceLayer for Metadata
**File**: Modify - `/home/user/gridiron-dynasty/autoloads/PersistenceLayer.gd`

Add methods:
```gdscript
const SaveMetadata = preload("res://scripts/persistence/SaveMetadata.gd")

## Save world state with metadata
## @param world_state: Full game state dictionary
## @param save_name: Save identifier
## @param metadata: SaveMetadata resource
## @return: true on success
func save_world_state_with_metadata(world_state: Dictionary, save_name: String, metadata: SaveMetadata) -> bool:
	# Save metadata to separate JSON file (even if using SQLite for world_state)
	# This allows fast loading of save list without opening databases
	var meta_path = "user://saves/%s_meta.json" % save_name
	var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
	if not meta_file:
		push_error("PersistenceLayer: Failed to write metadata for %s" % save_name)
		return false

	meta_file.store_string(JSON.stringify(metadata.to_dict(), "\t"))
	meta_file.close()

	# Save world state via active backend
	return save_world_state(world_state, save_name)

## Load metadata for a save
## @param save_name: Save identifier
## @return: SaveMetadata resource, or null if not found
func load_save_metadata(save_name: String) -> SaveMetadata:
	var meta_path = "user://saves/%s_meta.json" % save_name
	if not FileAccess.file_exists(meta_path):
		push_warning("PersistenceLayer: No metadata found for %s" % save_name)
		return null

	var meta_file = FileAccess.open(meta_path, FileAccess.READ)
	if not meta_file:
		push_error("PersistenceLayer: Failed to read metadata for %s" % save_name)
		return null

	var json_str = meta_file.get_as_text()
	meta_file.close()

	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("PersistenceLayer: Failed to parse metadata JSON for %s" % save_name)
		return null

	var metadata = SaveMetadata.new()
	metadata.from_dict(json.data)
	return metadata

## List all saves with metadata
## @return: Array of SaveMetadata resources
func list_saves_with_metadata() -> Array[SaveMetadata]:
	var saves = list_saves()
	var result: Array[SaveMetadata] = []

	for save_name in saves:
		var metadata = load_save_metadata(save_name)
		if metadata:
			result.append(metadata)

	# Sort by updated_at descending (most recent first)
	result.sort_custom(func(a, b): return a.updated_at > b.updated_at)

	return result
```

**Acceptance Criteria**:
- [ ] Metadata saved/loaded independently of world_state
- [ ] `list_saves_with_metadata()` returns sorted array
- [ ] Metadata persists across sessions
- [ ] Error handling for missing/corrupt metadata files
- [ ] Unit tests for all new methods

#### 1.3: Store RNG Seed in World State
**Files**: Modify - `BootstrapGameWorld.gd` and `WorldExplorerMain.gd`

Ensure `base_seed` is stored in `world_state` for deterministic replay:

```gdscript
# In BootstrapGameWorld.run()
var result := {
	"years_simulated": years_to_simulate,
	"start_year": start_year,
	"first_year": first_year,
	"world_state": world_state,
	"summary": _build_summary(world_state),
	"base_seed": seed  # NEW: Store seed for persistence
}
```

**Acceptance Criteria**:
- [ ] `base_seed` added to bootstrap result
- [ ] `base_seed` stored in `world_state` dictionary
- [ ] Seed can be retrieved when loading save
- [ ] Determinism tests verify seed persistence

---

### Phase 2: Main Menu UI (8-10 hours)

**Goal**: Create main menu scene with New Game / Continue Game / Settings options

#### 2.1: Create Main Menu Scene
**File**: New - `scenes/ui/main_menu/main_menu.tscn` and `scripts/ui/main_menu/MainMenu.gd`

**Scene Structure**:
```
MainMenu (Control)
├── Background (ColorRect) - Dark background
├── TitleContainer (VBoxContainer)
│   ├── GameTitle (Label) - "GRIDIRON DYNASTY"
│   ├── Version (Label) - "v0.1.0-alpha"
├── MenuContainer (VBoxContainer)
│   ├── NewGameButton (Button) - "New Game"
│   ├── ContinueButton (Button) - "Continue Game"
│   ├── SettingsButton (Button) - "Settings" [Future]
│   └── ExitButton (Button) - "Exit"
└── FooterLabel (Label) - Copyright notice
```

**Script** (`scripts/ui/main_menu/MainMenu.gd`):
```gdscript
extends Control
class_name MainMenu

@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var continue_button: Button = $MenuContainer/ContinueButton
@onready var settings_button: Button = $MenuContainer/SettingsButton
@onready var exit_button: Button = $MenuContainer/ExitButton

const NEW_GAME_SCENE = "res://scenes/ui/main_menu/new_game_config.tscn"
const CONTINUE_GAME_SCENE = "res://scenes/ui/main_menu/continue_game.tscn"

func _ready() -> void:
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_game_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Disable continue button if no saves exist
	_update_continue_button()

func _update_continue_button() -> void:
	var saves = PersistenceLayer.list_saves()
	continue_button.disabled = saves.is_empty()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(NEW_GAME_SCENE)

func _on_continue_game_pressed() -> void:
	get_tree().change_scene_to_file(CONTINUE_GAME_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()
```

**Acceptance Criteria**:
- [ ] Main menu scene created with proper node hierarchy
- [ ] Buttons styled consistently with game theme
- [ ] Continue button disabled when no saves exist
- [ ] Navigation to New Game and Continue Game scenes works
- [ ] Exit button quits application

#### 2.2: Create New Game Configuration Scene
**File**: New - `scenes/ui/main_menu/new_game_config.tscn` and `scripts/ui/main_menu/NewGameConfig.gd`

**Scene Structure**:
```
NewGameConfig (Control)
├── Background (ColorRect)
├── ConfigPanel (PanelContainer)
│   ├── VBoxContainer
│   │   ├── Title (Label) - "New Game Configuration"
│   │   ├── SaveNameLabel (Label) - "Save Name:"
│   │   ├── SaveNameInput (LineEdit) - Default: "save_YYYYMMDD_HHMMSS"
│   │   ├── SeedLabel (Label) - "Random Seed (0 = random):"
│   │   ├── SeedInput (SpinBox) - Range: 0-2147483647
│   │   ├── YearsLabel (Label) - "Years to Simulate:"
│   │   ├── YearsSlider (HSlider) - Range: 10-50, Default: 20
│   │   ├── YearsValue (Label) - Shows current value
│   │   ├── ButtonsContainer (HBoxContainer)
│   │   │   ├── BackButton (Button) - "Back"
│   │   │   └── StartButton (Button) - "Start Game"
```

**Script** (`scripts/ui/main_menu/NewGameConfig.gd`):
```gdscript
extends Control
class_name NewGameConfig

@onready var save_name_input: LineEdit = $ConfigPanel/VBoxContainer/SaveNameInput
@onready var seed_input: SpinBox = $ConfigPanel/VBoxContainer/SeedInput
@onready var years_slider: HSlider = $ConfigPanel/VBoxContainer/YearsSlider
@onready var years_value: Label = $ConfigPanel/VBoxContainer/YearsValue
@onready var back_button: Button = $ConfigPanel/VBoxContainer/ButtonsContainer/BackButton
@onready var start_button: Button = $ConfigPanel/VBoxContainer/ButtonsContainer/StartButton

const WORLD_EXPLORER_MAIN = "res://scenes/main/world_explorer_main.tscn"
const MAIN_MENU = "res://scenes/ui/main_menu/main_menu.tscn"

func _ready() -> void:
	# Generate default save name
	var dt = Time.get_datetime_dict_from_system()
	save_name_input.text = "save_%04d%02d%02d_%02d%02d%02d" % \
		[dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

	# Connect signals
	years_slider.value_changed.connect(_on_years_changed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)

	# Initialize UI
	_on_years_changed(years_slider.value)

func _on_years_changed(value: float) -> void:
	years_value.text = "%d years" % int(value)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

func _on_start_pressed() -> void:
	var save_name = save_name_input.text.strip_edges()
	var base_seed = int(seed_input.value)
	var years = int(years_slider.value)

	# Validate save name
	if save_name.is_empty():
		push_error("NewGameConfig: Save name cannot be empty")
		return

	# Check if save already exists
	if PersistenceLayer.save_exists(save_name):
		push_error("NewGameConfig: Save '%s' already exists" % save_name)
		# TODO: Show confirmation dialog to overwrite
		return

	# Store config in global state for WorldExplorerMain to read
	var config = {
		"save_name": save_name,
		"base_seed": base_seed,
		"years_to_simulate": years,
		"auto_save_on_complete": true
	}

	# Use RngBox or a new autoload to pass config between scenes
	# For now, use a simple global dictionary approach
	get_tree().root.set_meta("new_game_config", config)

	# Navigate to world generation
	get_tree().change_scene_to_file(WORLD_EXPLORER_MAIN)
```

**Acceptance Criteria**:
- [ ] New game config UI created with all input fields
- [ ] Default save name generated from timestamp
- [ ] Seed input validates numeric input
- [ ] Years slider updates label in real-time
- [ ] Config passed to WorldExplorerMain for bootstrap
- [ ] Back button returns to main menu

#### 2.3: Create Continue Game UI
**File**: New - `scenes/ui/main_menu/continue_game.tscn` and `scripts/ui/main_menu/ContinueGame.gd`

**Scene Structure**:
```
ContinueGame (Control)
├── Background (ColorRect)
├── SaveListPanel (PanelContainer)
│   ├── VBoxContainer
│   │   ├── Title (Label) - "Continue Game"
│   │   ├── SaveList (ScrollContainer)
│   │   │   └── SaveListContainer (VBoxContainer) - Populated dynamically
│   │   ├── ButtonsContainer (HBoxContainer)
│   │   │   ├── BackButton (Button) - "Back"
│   │   │   ├── DeleteButton (Button) - "Delete Save"
│   │   │   └── LoadButton (Button) - "Load Game"
```

**Save Entry Prefab** (`scenes/ui/main_menu/save_entry.tscn`):
```
SaveEntry (PanelContainer)
└── HBoxContainer
    ├── SelectionBox (CheckBox) - For selection
    ├── InfoContainer (VBoxContainer)
    │   ├── SaveNameLabel (Label) - Display name
    │   ├── DateLabel (Label) - Created/updated date
    │   └── SummaryLabel (Label) - World stats snippet
    └── ExpandButton (Button) - "Details" [Future]
```

**Script** (`scripts/ui/main_menu/ContinueGame.gd`):
```gdscript
extends Control
class_name ContinueGame

@onready var save_list_container: VBoxContainer = $SaveListPanel/VBoxContainer/SaveList/SaveListContainer
@onready var back_button: Button = $SaveListPanel/VBoxContainer/ButtonsContainer/BackButton
@onready var delete_button: Button = $SaveListPanel/VBoxContainer/ButtonsContainer/DeleteButton
@onready var load_button: Button = $SaveListPanel/VBoxContainer/ButtonsContainer/LoadButton

const SAVE_ENTRY_PREFAB = preload("res://scenes/ui/main_menu/save_entry.tscn")
const WORLD_EXPLORER_MAIN = "res://scenes/main/world_explorer_main.tscn"
const MAIN_MENU = "res://scenes/ui/main_menu/main_menu.tscn"

var save_entries: Array = []  # Array of SaveEntry nodes
var selected_save: SaveMetadata = null

func _ready() -> void:
	# Connect signals
	back_button.pressed.connect(_on_back_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	load_button.pressed.connect(_on_load_pressed)

	# Load and display saves
	_populate_save_list()

	# Disable action buttons initially
	delete_button.disabled = true
	load_button.disabled = true

func _populate_save_list() -> void:
	# Clear existing entries
	for child in save_list_container.get_children():
		child.queue_free()
	save_entries.clear()

	# Load saves with metadata
	var saves = PersistenceLayer.list_saves_with_metadata()

	if saves.is_empty():
		var label = Label.new()
		label.text = "No saved games found."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		save_list_container.add_child(label)
		return

	# Create entry for each save
	for metadata in saves:
		var entry = SAVE_ENTRY_PREFAB.instantiate()
		entry.set_save_metadata(metadata)
		entry.selection_changed.connect(_on_save_selected.bind(metadata))
		save_list_container.add_child(entry)
		save_entries.append(entry)

func _on_save_selected(metadata: SaveMetadata) -> void:
	selected_save = metadata

	# Deselect other entries
	for entry in save_entries:
		if entry.get_save_metadata() != metadata:
			entry.deselect()

	# Enable action buttons
	delete_button.disabled = false
	load_button.disabled = false

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)

func _on_delete_pressed() -> void:
	if not selected_save:
		return

	# TODO: Show confirmation dialog
	var success = PersistenceLayer.delete_save(selected_save.save_name)
	if success:
		print("ContinueGame: Deleted save '%s'" % selected_save.save_name)
		selected_save = null
		_populate_save_list()

func _on_load_pressed() -> void:
	if not selected_save:
		return

	# Store selected save name in meta for WorldExplorerMain
	get_tree().root.set_meta("load_save_name", selected_save.save_name)

	# Navigate to world explorer (will load save instead of generating)
	get_tree().change_scene_to_file(WORLD_EXPLORER_MAIN)
```

**SaveEntry Script** (`scripts/ui/main_menu/SaveEntry.gd`):
```gdscript
extends PanelContainer
class_name SaveEntry

signal selection_changed()

@onready var selection_box: CheckBox = $HBoxContainer/SelectionBox
@onready var save_name_label: Label = $HBoxContainer/InfoContainer/SaveNameLabel
@onready var date_label: Label = $HBoxContainer/InfoContainer/DateLabel
@onready var summary_label: Label = $HBoxContainer/InfoContainer/SummaryLabel

var _metadata: SaveMetadata = null

func _ready() -> void:
	selection_box.toggled.connect(_on_selection_toggled)

func set_save_metadata(metadata: SaveMetadata) -> void:
	_metadata = metadata

	save_name_label.text = metadata.display_name
	date_label.text = "Created: %s | Updated: %s | Year: %d" % \
		[metadata.get_formatted_date(),
		 Time.get_datetime_string_from_unix_time(metadata.updated_at).substr(0, 16),
		 metadata.current_year]
	summary_label.text = metadata.get_world_summary()

func get_save_metadata() -> SaveMetadata:
	return _metadata

func deselect() -> void:
	selection_box.button_pressed = false

func _on_selection_toggled(pressed: bool) -> void:
	if pressed:
		selection_changed.emit()
```

**Acceptance Criteria**:
- [ ] Continue game UI displays list of all saves
- [ ] Each entry shows save name, date, and world stats
- [ ] Single-selection mode (radio button behavior)
- [ ] Delete button removes save and refreshes list
- [ ] Load button navigates to WorldExplorer with selected save
- [ ] Empty state message when no saves exist

---

### Phase 3: Save/Load Integration (6-8 hours)

**Goal**: Integrate save/load into WorldExplorerMain and add save button to WorldExplorer

#### 3.1: Modify WorldExplorerMain for Save/Load
**File**: Modify - `/home/user/gridiron-dynasty/scripts/main/WorldExplorerMain.gd`

Add logic to check for new game config or load save name:

```gdscript
extends Node
class_name WorldExplorerMain

# ... existing fields ...

var _new_game_config: Dictionary = {}
var _load_save_name: String = ""

func _ready() -> void:
	# Check if we're loading a save or starting new game
	_load_save_name = String(get_tree().root.get_meta("load_save_name", ""))
	_new_game_config = get_tree().root.get_meta("new_game_config", {})

	# Clear meta after reading
	get_tree().root.remove_meta("load_save_name")
	get_tree().root.remove_meta("new_game_config")

	# Show loading screen
	loading_panel.visible = true
	explorer.visible = false
	loading_progress.value = 0

	# Defer to next frame
	call_deferred("_run_setup")

func _run_setup() -> void:
	if not _load_save_name.is_empty():
		_load_existing_save()
	elif not _new_game_config.is_empty():
		_start_new_game()
	else:
		# Fallback: generate default world (legacy behavior)
		_run_bootstrap()

func _load_existing_save() -> void:
	print("[WorldExplorerMain] Loading save: %s" % _load_save_name)
	loading_label.text = "Loading saved game..."

	var start_time := Time.get_ticks_usec()
	var loaded_state = PersistenceLayer.load_world_state(_load_save_name)
	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000

	if loaded_state.is_empty():
		_show_error("Failed to load save: %s" % _load_save_name)
		return

	world_state = loaded_state
	print("[WorldExplorerMain] Save loaded in %.2fs" % (elapsed_ms / 1000.0))

	# Load metadata to display year
	var metadata = PersistenceLayer.load_save_metadata(_load_save_name)
	if metadata:
		print("[WorldExplorerMain] Loaded Year %d world" % metadata.current_year)

	_finalize_world_setup()

func _start_new_game() -> void:
	var save_name = String(_new_game_config.get("save_name", ""))
	var base_seed = int(_new_game_config.get("base_seed", 0))
	var years = int(_new_game_config.get("years_to_simulate", 20))
	var auto_save = bool(_new_game_config.get("auto_save_on_complete", true))

	print("[WorldExplorerMain] Starting new game: %s (seed=%d, years=%d)" % [save_name, base_seed, years])
	loading_label.text = "Generating %d-year world..." % years

	# Configure bootstrap
	bootstrap.years_to_simulate = years

	# Run bootstrap
	var start_time := Time.get_ticks_usec()
	var result: Dictionary = bootstrap.run(base_seed)
	var elapsed_ms := (Time.get_ticks_usec() - start_time) / 1000

	if result.is_empty() or not result.has("world_state"):
		_show_error("Bootstrap failed - check console for details")
		return

	world_state = result["world_state"]
	print("[WorldExplorerMain] Bootstrap complete in %.2fs" % (elapsed_ms / 1000.0))

	# Auto-save if enabled
	if auto_save:
		_auto_save_world(save_name, base_seed, years)

	_finalize_world_setup()

func _auto_save_world(save_name: String, base_seed: int, years: int) -> void:
	loading_label.text = "Saving world..."
	loading_progress.value = 75

	print("[WorldExplorerMain] Auto-saving world as '%s'" % save_name)

	# Create metadata
	var metadata = SaveMetadata.new()
	metadata.from_world_state(world_state, save_name, base_seed)
	metadata.years_simulated = years

	# Save with metadata
	var success = PersistenceLayer.save_world_state_with_metadata(world_state, save_name, metadata)

	if success:
		print("[WorldExplorerMain] World saved successfully")
	else:
		push_error("[WorldExplorerMain] Failed to save world")

func _finalize_world_setup() -> void:
	# Update loading screen
	loading_label.text = "Integrating panels..."
	loading_progress.value = 80

	# Wire panels into WorldExplorer
	_integrate_panels()

	# Update loading screen
	loading_label.text = "Loading world state..."
	loading_progress.value = 90

	# Load world state into explorer
	explorer.load_world_state(world_state)

	# Show explorer
	loading_progress.value = 100
	loading_panel.visible = false
	explorer.visible = true

	print("[WorldExplorerMain] World Explorer ready!")

func _run_bootstrap() -> void:
	# Legacy default behavior
	print("[WorldExplorerMain] Starting %d-year bootstrap with seed %d..." % [bootstrap_years, base_seed])
	# ... existing bootstrap logic ...
```

**Acceptance Criteria**:
- [ ] WorldExplorerMain checks for load_save_name meta
- [ ] WorldExplorerMain checks for new_game_config meta
- [ ] Load path loads world_state via PersistenceLayer
- [ ] New game path runs bootstrap and auto-saves
- [ ] Loading screen shows appropriate messages for each path
- [ ] Error handling for missing/corrupt saves

#### 3.2: Add Save Button to WorldExplorer
**File**: Modify - `/home/user/gridiron-dynasty/scripts/ui/world_explorer/WorldExplorer.gd`

Add a "Save Game" button to the WorldExplorer toolbar:

```gdscript
# Add to existing WorldExplorer scene
@onready var save_button: Button = $Toolbar/SaveButton

func _ready() -> void:
	# ... existing code ...
	save_button.pressed.connect(_on_save_pressed)

func _on_save_pressed() -> void:
	# TODO: Show save dialog to enter save name
	# For now, use a simple implementation
	var save_name = "quicksave_%d" % Time.get_unix_time_from_system()

	var metadata = SaveMetadata.new()
	metadata.from_world_state(world_state, save_name, 0)  # TODO: Track base_seed
	metadata.display_name = "Quick Save - Year %d" % metadata.current_year

	var success = PersistenceLayer.save_world_state_with_metadata(world_state, save_name, metadata)

	if success:
		print("WorldExplorer: Game saved as '%s'" % save_name)
		# TODO: Show notification to user
	else:
		push_error("WorldExplorer: Failed to save game")
		# TODO: Show error dialog
```

**Acceptance Criteria**:
- [ ] Save button added to WorldExplorer UI
- [ ] Clicking button saves current world_state
- [ ] Metadata updated with current timestamp
- [ ] Success/error feedback shown to user
- [ ] Save name validation (no duplicates without confirmation)

#### 3.3: Update project.godot Main Scene
**File**: Modify - `/home/user/gridiron-dynasty/project.godot`

Change main scene to new main menu:

```ini
[application]
run/main_scene="res://scenes/ui/main_menu/main_menu.tscn"
```

**Acceptance Criteria**:
- [ ] Game launches to main menu instead of directly to WorldExplorer
- [ ] All navigation flows work (Main Menu → New Game → WorldExplorer)
- [ ] Continue Game flow works (Main Menu → Continue → Select → WorldExplorer)

---

### Phase 4: RNG State Persistence (4-6 hours)

**Goal**: Ensure deterministic replay by persisting RNG state

#### 4.1: Add RNG State to SaveMetadata
**Files**: Modify - `SaveMetadata.gd`

```gdscript
# Add field
@export var rng_state: int = 0  # Current RNG state for deterministic replay

func from_world_state(world_state: Dictionary, save_name: String, base_seed: int, rng: RandomNumberGenerator = null) -> void:
	# ... existing code ...
	self.base_seed = base_seed

	# Capture RNG state if provided
	if rng:
		self.rng_state = rng.state
```

#### 4.2: Restore RNG State on Load
**Files**: Modify - `WorldExplorerMain.gd`

```gdscript
func _load_existing_save() -> void:
	# ... existing load code ...

	# Restore RNG state for deterministic simulation
	var metadata = PersistenceLayer.load_save_metadata(_load_save_name)
	if metadata and metadata.rng_state != 0:
		Rand.restore_state(metadata.rng_state)
		print("[WorldExplorerMain] RNG state restored for deterministic replay")
```

**Acceptance Criteria**:
- [ ] RNG state captured during save
- [ ] RNG state restored during load
- [ ] Determinism tests verify identical outcomes with loaded saves
- [ ] Unit tests for RNG save/restore

---

## Testing Strategy

### Unit Tests

**SaveMetadata Tests** (`test/test_save_metadata.gd`):
- [ ] from_world_state() extracts correct counts
- [ ] to_dict() / from_dict() round-trip preserves all fields
- [ ] get_formatted_date() returns correct format
- [ ] get_world_summary() constructs correct string

**PersistenceLayer Tests** (`test/test_persistence_layer.gd`):
- [ ] save_world_state_with_metadata() creates both files
- [ ] load_save_metadata() returns correct metadata
- [ ] list_saves_with_metadata() returns sorted array
- [ ] Metadata survives across save/load cycles

### Integration Tests

**Save/Load Flow Test** (`test/integration/test_save_load_flow.gd`):
```gdscript
func test_full_save_load_cycle():
	# 1. Generate world
	var bootstrap = BootstrapGameWorld.new()
	var result = bootstrap.run(1234, false)
	var world_state = result["world_state"]

	# 2. Save with metadata
	var metadata = SaveMetadata.new()
	metadata.from_world_state(world_state, "test_save", 1234)
	var saved = PersistenceLayer.save_world_state_with_metadata(world_state, "test_save", metadata)
	assert_true(saved)

	# 3. Load metadata
	var loaded_meta = PersistenceLayer.load_save_metadata("test_save")
	assert_that(loaded_meta.save_name).is_equal("test_save")
	assert_that(loaded_meta.base_seed).is_equal(1234)

	# 4. Load world state
	var loaded_state = PersistenceLayer.load_world_state("test_save")
	assert_false(loaded_state.is_empty())
	assert_that(loaded_state["current_year"]).is_equal(world_state["current_year"])

	# 5. Verify determinism: Advance both worlds by 1 year with same seed
	var year_seed = Rand.splitmix64(1234 ^ 2026)
	var advance = AdvanceWorldYear.new()
	var result1 = advance.run(world_state.duplicate(true), 2026, year_seed)
	var result2 = advance.run(loaded_state.duplicate(true), 2026, year_seed)

	# Both should produce identical results
	assert_that(result1["world_state"]["current_year"]).is_equal(result2["world_state"]["current_year"])
```

### Manual Testing Checklist

**New Game Flow**:
- [ ] Launch game → Main menu appears
- [ ] Click "New Game" → Config screen appears
- [ ] Enter save name, seed, years → Click "Start Game"
- [ ] Loading screen shows progress
- [ ] World generates successfully
- [ ] WorldExplorer UI loads with generated world
- [ ] Save exists in save list

**Continue Game Flow**:
- [ ] Main menu → Click "Continue Game"
- [ ] Save list displays with correct metadata
- [ ] Select save → Load button enabled
- [ ] Click "Load Game" → Loading screen appears
- [ ] World loads successfully
- [ ] Loaded world shows correct year/data

**Delete Save**:
- [ ] Continue game screen → Select save
- [ ] Click "Delete Save" → Confirmation appears (future)
- [ ] Confirm → Save removed from list
- [ ] Save file deleted from disk

**Save During Play**:
- [ ] In WorldExplorer → Click "Save Game"
- [ ] Enter save name (or use quick save)
- [ ] Save completes successfully
- [ ] Notification shows success

---

## File Structure

```
gridiron-dynasty/
├── autoloads/
│   ├── PersistenceLayer.gd (MODIFIED)
│   └── ... existing autoloads ...
│
├── scenes/
│   ├── main/
│   │   └── world_explorer_main.tscn (MODIFIED)
│   └── ui/
│       ├── main_menu/ (NEW)
│       │   ├── main_menu.tscn
│       │   ├── new_game_config.tscn
│       │   ├── continue_game.tscn
│       │   └── save_entry.tscn
│       └── world_explorer/
│           └── world_explorer.tscn (MODIFIED)
│
├── scripts/
│   ├── main/
│   │   └── WorldExplorerMain.gd (MODIFIED)
│   ├── persistence/
│   │   └── SaveMetadata.gd (NEW)
│   └── ui/
│       ├── main_menu/ (NEW)
│       │   ├── MainMenu.gd
│       │   ├── NewGameConfig.gd
│       │   ├── ContinueGame.gd
│       │   └── SaveEntry.gd
│       └── world_explorer/
│           └── WorldExplorer.gd (MODIFIED)
│
└── project.godot (MODIFIED - update run/main_scene)
```

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Save corruption breaks game | HIGH | Implement save validation, backup system, error recovery |
| RNG state mismatch causes desync | MEDIUM | Unit tests for determinism, log RNG state on save/load |
| Metadata out of sync with save | MEDIUM | Atomic save operations, validate on load |
| UI navigation breaks existing flow | LOW | Thorough integration testing, keep legacy path as fallback |
| Performance regression on large saves | LOW | SQLite backend already optimized, benchmark with 20-year worlds |

---

## Dependencies

### External
- GodotSQLite addon (already installed)
- Godot 4.5+ for UI features

### Internal (Must Be Complete)
- [x] Phase 3: Database Persistence (ARCH-017 to ARCH-022)
- [x] PersistenceLayer autoload
- [x] PlayerDAO and TeamDAO
- [x] BootstrapGameWorld pipeline

---

## Success Metrics

- [ ] Players can start new games with custom seeds
- [ ] Players can save/load games with metadata
- [ ] Continue Game UI shows all saves with correct info
- [ ] Save/load preserves world state with 100% fidelity
- [ ] RNG determinism maintained across save/load
- [ ] No data corruption or loss in 100 save/load cycles
- [ ] Save time < 30 seconds for 20-year world (SQLite backend)
- [ ] Load time < 10 seconds for 20-year world (SQLite backend)

---

## Future Enhancements (Out of Scope)

- [ ] Autosave every N years during simulation
- [ ] Cloud save support
- [ ] Save file compression
- [ ] Export/import saves for sharing
- [ ] Save file versioning and migration
- [ ] Undo/redo system using save snapshots
- [ ] Multiple save slots UI (current implementation supports unlimited saves)
- [ ] Save preview screenshots
- [ ] Achievement tracking per save
- [ ] Ironman mode (single save, no reloading)

---

## Appendix: World State Serialization Example

```json
{
  "current_year": 2025,
  "base_seed": 1234567890,
  "nfl_teams": [
    {
      "id": "team-123",
      "name": "San Francisco 49ers",
      "offensive_scheme": "west_coast",
      "defensive_scheme": "cover_3",
      "cap": {
        "league_cap": 200000000,
        "cap_used": 180000000,
        "cap_space": 20000000
      },
      "roster": {
        "entries": [
          {
            "player_id": "player-456",
            "status": "active",
            "cap_exempt": false
          }
        ]
      }
    }
  ],
  "nfl_rosters": {
    "team-123": {
      "players": [
        {
          "id": "player-456",
          "first_name": "John",
          "last_name": "Doe",
          "position": "QB",
          "age": 25,
          "stage": 4,
          "contract": {
            "current_year": 2,
            "total_years": 4,
            "annual_value": 5000000
          }
        }
      ],
      "starters": {},
      "depth_chart": {}
    }
  },
  "nfl_players": [],
  "retired_players": []
}
```

**SaveMetadata JSON** (`user://saves/test_save_meta.json`):
```json
{
  "save_name": "test_save",
  "created_at": 1705420800,
  "updated_at": 1705420800,
  "current_year": 2025,
  "base_seed": 1234567890,
  "years_simulated": 20,
  "persistence_backend": "sqlite",
  "nfl_team_count": 32,
  "nfl_player_count": 2688,
  "college_count": 130,
  "college_player_count": 6500,
  "retired_player_count": 1250,
  "display_name": "Year 2025 - 2026-01-16 14:00",
  "rng_state": 9876543210
}
```

---

## Implementation Timeline

| Phase | Duration | Deliverables |
|-------|----------|--------------|
| Phase 1: Save Metadata System | 8-10 hours | SaveMetadata.gd, PersistenceLayer updates, RNG persistence |
| Phase 2: Main Menu UI | 8-10 hours | MainMenu, NewGameConfig, ContinueGame scenes |
| Phase 3: Save/Load Integration | 6-8 hours | WorldExplorerMain updates, Save button |
| Phase 4: RNG State Persistence | 4-6 hours | RNG save/restore, determinism tests |
| **Total** | **26-34 hours** | **Fully functional game save system** |

**Recommended Schedule** (assuming 6-8 hours/day):
- Week 1: Phase 1 + Phase 2 (16-20 hours)
- Week 2: Phase 3 + Phase 4 + Testing (10-14 hours)

---

## Conclusion

This implementation plan leverages existing infrastructure (PersistenceLayer, DatabasePersistence, DAOs) to build a complete game save system with minimal new code. The focus is on:

1. **Metadata tracking** for rich save previews
2. **UI layer** for user-friendly save/load experience
3. **Integration** with existing world generation pipeline
4. **Determinism** via RNG state persistence

The system is designed to be extensible, allowing future enhancements like autosave, cloud saves, and achievement tracking without major refactoring.
