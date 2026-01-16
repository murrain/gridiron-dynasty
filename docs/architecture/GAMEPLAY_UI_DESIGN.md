# Gameplay UI Architecture - Email Client Inspired Design

## Vision

An elegant, productivity-focused interface inspired by email clients like Superhuman, Spark, and Apple Mail. The UI emphasizes **information density without clutter**, **quick navigation**, and **actionable items front and center**.

## Layout Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TEAM INFO BAR                                                 [ Advance > ]│
│  Eagles | Week 4 | 3-1 | Cap: $12.4M | Injuries: 2                         │
├────────────────────┬────────────────────────────────────────────────────────┤
│                    │                                                        │
│  MESSAGE INBOX     │  DETAIL PANEL                                          │
│                    │                                                        │
│  ┌──────────────┐  │  ┌──────────────────────────────────────────────────┐  │
│  │ [!] Injury   │  │  │                                                  │  │
│  │ QB Smith out │◄─┼──│  Context-sensitive detail view                   │  │
│  └──────────────┘  │  │                                                  │  │
│  ┌──────────────┐  │  │  • Message details                               │  │
│  │ Contract     │  │  │  • Player profiles                               │  │
│  │ Offer recv'd │  │  │  • Team management                               │  │
│  └──────────────┘  │  │  • Trade negotiations                            │  │
│  ┌──────────────┐  │  │  • Draft board                                   │  │
│  │ Scout Report │  │  │  • Game results                                  │  │
│  │ 3 new eval   │  │  │                                                  │  │
│  └──────────────┘  │  │                                                  │  │
│                    │  │                                                  │  │
│  ───────────────   │  │                                                  │  │
│  QUICK ACTIONS     │  │                                                  │  │
│  ┌──────────────┐  │  │                                                  │  │
│  │ Roster       │  │  │                                                  │  │
│  │ Depth Chart  │  │  │                                                  │  │
│  │ Cap Mgmt     │  │  │                                                  │  │
│  │ Scouting     │  │  │                                                  │  │
│  └──────────────┘  │  └──────────────────────────────────────────────────┘  │
│                    │                                                        │
└────────────────────┴────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Team Info Bar (`TeamInfoBar`)

**Purpose**: At-a-glance team status with primary game advancement action.

**Structure**:
```
scenes/ui/gameplay/
└── team_info_bar/
    ├── team_info_bar.tscn
    └── TeamInfoBar.gd
```

**Display Elements**:
| Element | Source | Format |
|---------|--------|--------|
| Team Name | `player_team.name` | "Eagles" |
| Current Period | `game_state.period` | "Week 4" / "Offseason Day 12" |
| Record | `team_stats.record` | "3-1" |
| Cap Space | `team.cap_space` | "$12.4M" (color-coded) |
| Injury Count | `roster.injuries.size()` | Badge with count |
| Unread Messages | `inbox.unread_count` | Badge with count |

**Primary Action**:
- `[Advance >]` button - Advances simulation by one tick
- Shows confirmation for critical pending decisions
- Keyboard shortcut: `Space` or `Enter`

**Signals**:
```gdscript
signal advance_requested()
signal team_summary_clicked()
signal period_info_clicked()
```

---

### 2. Message Inbox (`MessageInbox`)

**Purpose**: Unified queue of items requiring player attention, sorted by priority.

**Structure**:
```
scenes/ui/gameplay/
└── message_inbox/
    ├── message_inbox.tscn
    ├── MessageInbox.gd
    ├── message_item.tscn
    └── MessageItem.gd
```

**Message Categories** (with icons and colors):

| Category | Icon | Priority | Examples |
|----------|------|----------|----------|
| `CRITICAL` | `!` | 1 | Game day decisions, trade deadlines |
| `INJURY` | `+` | 2 | Player injuries, returns from IR |
| `CONTRACT` | `$` | 3 | Offers, expirations, negotiations |
| `PERSONNEL` | `👤` | 4 | Free agent signings, releases |
| `SCOUT` | `🔍` | 5 | Scouting reports, evaluations |
| `DRAFT` | `📋` | 6 | Draft picks, board updates |
| `NEWS` | `📰` | 7 | League news, standings |
| `ACHIEVEMENT` | `★` | 8 | Awards, milestones |

**Message Model**:
```gdscript
class_name GameMessage extends RefCounted

enum Category { CRITICAL, INJURY, CONTRACT, PERSONNEL, SCOUT, DRAFT, NEWS, ACHIEVEMENT }
enum Status { UNREAD, READ, ACTIONED, ARCHIVED }

var id: String
var category: Category
var status: Status
var timestamp: int  # Game tick when created
var title: String
var preview: String
var payload: Dictionary  # Category-specific data
var actions: Array[MessageAction]  # Available responses
var expires_at: int  # Optional expiration tick (-1 = never)
```

**MessageAction Model**:
```gdscript
class_name MessageAction extends RefCounted

var id: String
var label: String
var action_type: String  # "navigate", "execute", "dismiss"
var action_data: Dictionary
var is_primary: bool
```

**Inbox Behavior**:
- Messages sorted by: `status` (unread first) → `priority` → `timestamp` (newest)
- Unread indicator (bold text, accent dot)
- Swipe/click actions: Archive, Mark Read, Quick Action
- Keyboard navigation: `↑/↓` to select, `Enter` to open, `A` to archive

**Signals**:
```gdscript
signal message_selected(message: GameMessage)
signal message_actioned(message: GameMessage, action: MessageAction)
signal quick_action_selected(action_id: String)
```

---

### 3. Quick Actions Panel (`QuickActionsPanel`)

**Purpose**: Direct access to management functions without waiting for messages.

**Structure**:
```
scenes/ui/gameplay/
└── quick_actions/
    ├── quick_actions_panel.tscn
    └── QuickActionsPanel.gd
```

**Action Items**:
```gdscript
const QUICK_ACTIONS = [
    { id = "roster", label = "Roster", icon = "👥", shortcut = "R" },
    { id = "depth_chart", label = "Depth Chart", icon = "📊", shortcut = "D" },
    { id = "cap_management", label = "Cap & Contracts", icon = "$", shortcut = "C" },
    { id = "scouting", label = "Scouting", icon = "🔍", shortcut = "S" },
    { id = "draft_board", label = "Draft Board", icon = "📋", shortcut = "B" },
    { id = "schedule", label = "Schedule", icon = "📅", shortcut = "H" },
    { id = "standings", label = "Standings", icon = "🏆", shortcut = "T" },
    { id = "world_explorer", label = "World Explorer", icon = "🌍", shortcut = "W" },
]
```

**Signals**:
```gdscript
signal action_selected(action_id: String)
```

---

### 4. Detail Panel (`DetailPanel`)

**Purpose**: Context-sensitive view showing full details of selected item.

**Structure**:
```
scenes/ui/gameplay/
└── detail_panel/
    ├── detail_panel.tscn
    ├── DetailPanel.gd
    └── views/
        ├── message_detail_view.tscn
        ├── player_detail_view.tscn
        ├── team_detail_view.tscn
        ├── roster_view.tscn
        ├── depth_chart_view.tscn
        ├── cap_management_view.tscn
        ├── scouting_view.tscn
        ├── draft_board_view.tscn
        ├── schedule_view.tscn
        ├── standings_view.tscn
        └── trade_view.tscn
```

**View Registry Pattern**:
```gdscript
class_name DetailPanel extends Control

var _current_view: Control = null
var _view_cache: Dictionary = {}  # view_id -> Control instance

const VIEW_SCENES = {
    "message": "res://scenes/ui/gameplay/detail_panel/views/message_detail_view.tscn",
    "player": "res://scenes/ui/gameplay/detail_panel/views/player_detail_view.tscn",
    "roster": "res://scenes/ui/gameplay/detail_panel/views/roster_view.tscn",
    # ... etc
}

func show_view(view_id: String, context: Dictionary = {}) -> void:
    # Lazy-load and cache views
    # Hide current, show requested
    # Pass context to view.populate(context)
```

**View Contract**:
```gdscript
# All detail views implement:
func populate(context: Dictionary) -> void
func clear() -> void
func get_view_id() -> String

# Optional:
signal navigation_requested(view_id: String, context: Dictionary)
signal action_completed(action_id: String, result: Dictionary)
```

---

### 5. Main Gameplay Controller (`GameplayUI`)

**Purpose**: Orchestrates all panels, handles navigation, manages game state display.

**Structure**:
```
scenes/ui/gameplay/
├── gameplay_ui.tscn
└── GameplayUI.gd
```

**Scene Tree**:
```
GameplayUI (Control)
├── Background (ColorRect)
├── MainLayout (VBoxContainer)
│   ├── TeamInfoBar (team_info_bar.tscn)
│   └── ContentArea (HSplitContainer)
│       ├── LeftPanel (VBoxContainer)
│       │   ├── MessageInbox (message_inbox.tscn)
│       │   └── QuickActionsPanel (quick_actions_panel.tscn)
│       └── DetailPanel (detail_panel.tscn)
└── OverlayContainer (CanvasLayer)
    └── ModalContainer (Control) - for dialogs
```

**Controller Responsibilities**:
```gdscript
class_name GameplayUI extends Control

# Core references
var _game_state: GameState
var _player_team: Team
var _message_manager: MessageManager

# Panel references
@onready var _team_info_bar: TeamInfoBar = $MainLayout/TeamInfoBar
@onready var _message_inbox: MessageInbox = $MainLayout/ContentArea/LeftPanel/MessageInbox
@onready var _quick_actions: QuickActionsPanel = $MainLayout/ContentArea/LeftPanel/QuickActionsPanel
@onready var _detail_panel: DetailPanel = $MainLayout/ContentArea/DetailPanel

func _ready() -> void:
    _connect_signals()
    _setup_keyboard_shortcuts()

func initialize(game_state: GameState, player_team: Team) -> void:
    _game_state = game_state
    _player_team = player_team
    _team_info_bar.update(player_team, game_state)
    _message_inbox.populate(_message_manager.get_messages())
    _detail_panel.show_view("welcome")

func _on_message_selected(message: GameMessage) -> void:
    _detail_panel.show_view("message", { "message": message })

func _on_quick_action_selected(action_id: String) -> void:
    _detail_panel.show_view(action_id)

func _on_advance_requested() -> void:
    if _has_blocking_decisions():
        _show_blocking_decision_dialog()
        return
    advance_tick.emit()
```

---

## Message System Architecture

### MessageManager

**Purpose**: Central service for creating, querying, and managing game messages.

**Structure**:
```
scripts/services/
└── message_manager/
    ├── MessageManager.gd
    ├── GameMessage.gd
    └── MessageAction.gd
```

**API**:
```gdscript
class_name MessageManager extends RefCounted

signal message_added(message: GameMessage)
signal message_updated(message: GameMessage)
signal messages_cleared()

var _messages: Array[GameMessage] = []

# Creation
func create_message(category: GameMessage.Category, title: String, preview: String, payload: Dictionary = {}) -> GameMessage
func create_injury_message(player: Player, injury_type: String, duration: int) -> GameMessage
func create_contract_message(player: Player, offer: Contract, team: Team) -> GameMessage
func create_scout_report_message(player: Player, evaluation: Dictionary) -> GameMessage

# Queries
func get_messages(filter: Dictionary = {}) -> Array[GameMessage]
func get_unread_count() -> int
func get_messages_by_category(category: GameMessage.Category) -> Array[GameMessage]
func get_blocking_messages() -> Array[GameMessage]  # Must be resolved before advance

# State changes
func mark_read(message_id: String) -> void
func mark_actioned(message_id: String) -> void
func archive(message_id: String) -> void
func expire_old_messages(current_tick: int) -> void

# Persistence
func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> MessageManager
```

### Message Creation Points

Messages are created by game systems at appropriate moments:

| System | Event | Message Type |
|--------|-------|--------------|
| InjurySystem | Player injured | `INJURY` |
| ContractSystem | Offer received | `CONTRACT` |
| ContractSystem | Contract expiring | `CONTRACT` |
| ScoutingSystem | Evaluation complete | `SCOUT` |
| DraftSystem | Pick approaching | `DRAFT` |
| SimulationEngine | Game complete | `NEWS` |
| AchievementSystem | Milestone reached | `ACHIEVEMENT` |

---

## Navigation Flow

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` / `Enter` | Advance tick (when no modal) |
| `↑` / `↓` | Navigate inbox |
| `←` / `→` | Switch panels |
| `Enter` | Open selected message |
| `A` | Archive message |
| `M` | Mark read/unread |
| `R` | Open Roster |
| `D` | Open Depth Chart |
| `C` | Open Cap Management |
| `S` | Open Scouting |
| `B` | Open Draft Board |
| `Esc` | Close detail / Back |

### Navigation Stack

```gdscript
class_name NavigationStack extends RefCounted

var _stack: Array[Dictionary] = []  # [{view_id, context}]

func push(view_id: String, context: Dictionary) -> void
func pop() -> Dictionary  # Returns previous state
func clear() -> void
func can_go_back() -> bool
func current() -> Dictionary
```

---

## Styling Guidelines

### Color Palette

```gdscript
# Primary
const COLOR_BACKGROUND = Color("#1a1a2e")      # Deep navy
const COLOR_SURFACE = Color("#16213e")         # Slightly lighter
const COLOR_SURFACE_ELEVATED = Color("#0f3460") # Card/panel bg

# Text
const COLOR_TEXT_PRIMARY = Color("#eaeaea")    # Main text
const COLOR_TEXT_SECONDARY = Color("#a0a0a0")  # Subdued
const COLOR_TEXT_MUTED = Color("#606060")      # Very subdued

# Accent
const COLOR_ACCENT = Color("#e94560")          # Primary action
const COLOR_ACCENT_HOVER = Color("#ff6b6b")    # Hover state
const COLOR_SUCCESS = Color("#4ecca3")         # Positive
const COLOR_WARNING = Color("#ffc93c")         # Caution
const COLOR_ERROR = Color("#ff4757")           # Negative/Critical

# Message Categories
const CATEGORY_COLORS = {
    GameMessage.Category.CRITICAL: Color("#ff4757"),
    GameMessage.Category.INJURY: Color("#ff6b6b"),
    GameMessage.Category.CONTRACT: Color("#4ecca3"),
    GameMessage.Category.PERSONNEL: Color("#45aaf2"),
    GameMessage.Category.SCOUT: Color("#a55eea"),
    GameMessage.Category.DRAFT: Color("#ffc93c"),
    GameMessage.Category.NEWS: Color("#a0a0a0"),
    GameMessage.Category.ACHIEVEMENT: Color("#f7d794"),
}
```

### Typography

```gdscript
# Font sizes
const FONT_SIZE_H1 = 24
const FONT_SIZE_H2 = 20
const FONT_SIZE_H3 = 16
const FONT_SIZE_BODY = 14
const FONT_SIZE_SMALL = 12
const FONT_SIZE_TINY = 10

# Line heights
const LINE_HEIGHT_TIGHT = 1.2
const LINE_HEIGHT_NORMAL = 1.5
const LINE_HEIGHT_RELAXED = 1.8
```

### Spacing

```gdscript
# Margins and padding
const SPACING_XS = 4
const SPACING_SM = 8
const SPACING_MD = 16
const SPACING_LG = 24
const SPACING_XL = 32

# Panel dimensions
const LEFT_PANEL_WIDTH = 320
const LEFT_PANEL_MIN_WIDTH = 280
const INFO_BAR_HEIGHT = 56
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Create `GameMessage` and `MessageAction` models
- [ ] Implement `MessageManager` service
- [ ] Create `GameplayUI` main scene with layout
- [ ] Implement `TeamInfoBar` component
- [ ] Basic styling and color system

### Phase 2: Inbox System
- [ ] Create `MessageInbox` component
- [ ] Create `MessageItem` component
- [ ] Implement inbox sorting and filtering
- [ ] Keyboard navigation for inbox
- [ ] Unread/read state management

### Phase 3: Detail Views
- [ ] Create `DetailPanel` with view registry
- [ ] Implement `MessageDetailView`
- [ ] Port existing `PlayerDetailFormatter` to view
- [ ] Create `RosterView` with editing capability
- [ ] Create `DepthChartView`

### Phase 4: Quick Actions
- [ ] Create `QuickActionsPanel`
- [ ] Implement keyboard shortcuts
- [ ] Navigation stack for back functionality
- [ ] Create remaining detail views

### Phase 5: Integration
- [ ] Connect to game simulation loop
- [ ] Implement advance tick with blocking decisions
- [ ] Message creation from game events
- [ ] Persistence (save/load messages)

---

## File Structure Summary

```
scenes/ui/gameplay/
├── gameplay_ui.tscn
├── GameplayUI.gd
├── team_info_bar/
│   ├── team_info_bar.tscn
│   └── TeamInfoBar.gd
├── message_inbox/
│   ├── message_inbox.tscn
│   ├── MessageInbox.gd
│   ├── message_item.tscn
│   └── MessageItem.gd
├── quick_actions/
│   ├── quick_actions_panel.tscn
│   └── QuickActionsPanel.gd
└── detail_panel/
    ├── detail_panel.tscn
    ├── DetailPanel.gd
    └── views/
        ├── message_detail_view.tscn
        ├── player_detail_view.tscn
        ├── roster_view.tscn
        ├── depth_chart_view.tscn
        ├── cap_management_view.tscn
        ├── scouting_view.tscn
        ├── draft_board_view.tscn
        ├── schedule_view.tscn
        ├── standings_view.tscn
        └── trade_view.tscn

scripts/services/
└── message_manager/
    ├── MessageManager.gd
    ├── GameMessage.gd
    └── MessageAction.gd
```

---

## Design Principles

1. **Information Density**: Show maximum relevant info without clutter
2. **Keyboard-First**: Every action accessible via keyboard
3. **Context Preservation**: Navigation stack remembers where you came from
4. **Actionable Items First**: Critical decisions surface to the top
5. **Progressive Disclosure**: Summary in inbox, details on selection
6. **Consistent Patterns**: Same interaction model across all views
7. **Non-Blocking Flow**: Only truly required decisions block advancement
