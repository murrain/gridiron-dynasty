## DataBus.gd
## Event-driven UI update system for Gridiron Dynasty.
##
## Provides a central event bus for UI components to subscribe to data changes
## instead of polling or requiring manual refresh calls. This decouples UI from
## simulation logic and enables reactive UI patterns.
##
## Usage:
##   # Subscribe to signals in UI components:
##   DataBus.players_changed.connect(_on_players_changed)
##   DataBus.world_state_loaded.connect(_refresh_all_data)
##
##   # Emit from simulation or data modification code:
##   DataBus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, new_count)
##   DataBus.notify_collection_changed("teams", "insert")
##
extends Node

const Player = preload("res://scripts/core/models/Player.gd")

# ============================================================================
# SIGNALS - Emitted when data changes occur
# ============================================================================

## Emitted when player data changes for a specific stage.
## [br]stage: Player.PlayerStage enum value indicating which player group changed
## [br]count: Number of players affected by the change (optional context)
signal players_changed(stage: Player.PlayerStage, count: int)

## Emitted when a world_state collection changes.
## [br]collection_name: Name of the collection that changed (e.g., "teams", "players", "contracts")
## [br]operation: Type of operation performed ("insert", "update", "delete", "bulk_update")
signal collection_changed(collection_name: String, operation: String)

## Emitted when a simulation phase completes.
## [br]phase_id: Identifier for the completed phase (e.g., "hs_gen", "recruiting", "draft")
## [br]year: The year in which the phase completed
signal phase_completed(phase_id: String, year: int)

## Emitted when world state is loaded or initialized.
## UI components should use this to refresh all their data displays.
signal world_state_loaded()

# ============================================================================
# PUBLIC API - Helper methods to emit signals
# ============================================================================

## Notify subscribers that player data has changed for a specific stage.
## Use this after player generation, progression, retirement, or stage transitions.
##
## Example:
## [codeblock]
## DataBus.notify_players_changed(Player.PlayerStage.HIGH_SCHOOL, 500)
## [/codeblock]
func notify_players_changed(stage: Player.PlayerStage, count: int = 0) -> void:
	players_changed.emit(stage, count)

## Notify subscribers that a world_state collection has been modified.
## Use this after inserts, updates, deletes, or bulk operations.
##
## Example:
## [codeblock]
## DataBus.notify_collection_changed("teams", "insert")
## DataBus.notify_collection_changed("players", "bulk_update")
## [/codeblock]
func notify_collection_changed(collection_name: String, operation: String) -> void:
	collection_changed.emit(collection_name, operation)

## Notify subscribers that a simulation phase has completed.
## Use this at the end of each phase to trigger UI updates or analytics.
##
## Example:
## [codeblock]
## DataBus.notify_phase_completed("hs_gen", 2033)
## DataBus.notify_phase_completed("draft", 2033)
## [/codeblock]
func notify_phase_completed(phase_id: String, year: int) -> void:
	phase_completed.emit(phase_id, year)

## Notify subscribers that world state has been loaded or initialized.
## Use this after loading a save file or creating a new game.
## UI components should refresh all their data displays in response.
##
## Example:
## [codeblock]
## DataBus.notify_world_state_loaded()
## [/codeblock]
func notify_world_state_loaded() -> void:
	world_state_loaded.emit()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# DataBus is purely signal-based, no initialization needed
	pass
