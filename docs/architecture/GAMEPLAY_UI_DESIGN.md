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
| `LEAGUE` | `📡` | 7 | Around the league news (actionable) |
| `NEWS` | `📰` | 8 | General league news, standings |
| `ACHIEVEMENT` | `★` | 9 | Awards, milestones |

### Around the League Messages

The `LEAGUE` category surfaces actionable intelligence from around the league - opportunities the player-coach can act on:

**Free Agency Intel**:
- "WR Marcus Johnson released by Cowboys" → [View Player] [Make Offer]
- "CB depth available: 3 veterans cut this week" → [View All]
- "Star LB hitting free agency in 2 weeks" → [Add to Watchlist]

**Trade Rumors**:
- "Bears shopping disgruntled DE Williams" → [Inquire] [Scout]
- "Jets looking to move up in draft" → [View Their Picks]

**Injury Reports**:
- "Rival's QB questionable for Week 6 matchup" → [View Matchup]
- "Division rival loses starting CB for season" → [View Team]

**Transactions**:
- "Packers sign FA RB to 3-year deal" → [View Contract]
- "Trade: WR moved from Giants to 49ers" → [View Details]

**Draft Intel** (during draft season):
- "Prospect X stock rising after combine" → [View on Board] [Scout]
- "Team Y expected to take QB at #3" → [Run Mock Draft]

```gdscript
# League message subtypes for filtering
enum LeagueMessageType {
    FREE_AGENT_AVAILABLE,
    FREE_AGENT_SIGNED,
    TRADE_RUMOR,
    TRADE_COMPLETED,
    INJURY_REPORT,
    ROSTER_MOVE,
    DRAFT_INTEL,
    STANDINGS_UPDATE,
}

# Example league message payload
var example_fa_message = {
    "subtype": LeagueMessageType.FREE_AGENT_AVAILABLE,
    "player_id": "player_123",
    "former_team_id": "team_456",
    "release_reason": "cap_casualty",  # or "performance", "conduct", etc.
    "market_interest": "high",  # "low", "medium", "high"
    "fits_need": true,  # Auto-calculated from TeamNeeds
    "position": "WR",
    "overall_rating": 78,
}
```

**Actionable Message Pattern**:

Messages show inline action buttons with window-like controls (expand to detail, dismiss):

```
┌─────────────────────────────────────────────────────┐
│ 📡 WR Marcus Johnson released by Cowboys    [⤢] [×] │
│    78 OVR • Cap casualty • High interest            │
│    [SIGN $2.1M]                                     │
└─────────────────────────────────────────────────────┘

[⤢] = Expand to detail panel (view full player profile)
[×] = Dismiss message (pass on this player)
```

**Filtering League Messages**:
```gdscript
# User preferences for league message filtering
var league_message_filters = {
    "show_fa_at_needs": true,      # Only show FAs at positions of need
    "min_fa_overall": 70,          # Minimum rating for FA alerts
    "show_rival_news": true,       # News about division rivals
    "show_trade_rumors": true,     # Trade availability rumors
    "show_all_transactions": false, # Or just relevant ones
}
```

---

## Inline Actions Design

**Core Principle**: Every actionable message has its primary action available directly in the inbox - no extra clicks to navigate, then find the action, then click again.

### Message Item Layout

Each message has a consistent layout with window-like controls:

```
┌─────────────────────────────────────────────────────┐
│ [icon] Title/Summary                        [⤢] [×] │
│        Secondary info line                          │
│        [PRIMARY ACTION]  [Secondary]                │
└─────────────────────────────────────────────────────┘

[⤢] = Expand to detail panel (like maximize)
[×] = Dismiss/archive message (close)
```

### Message Inline Actions by Category

```
CRITICAL - Game day decision
┌─────────────────────────────────────────────────────┐
│ ! Set starting lineup for Week 6            [⤢] [×] │
│   vs Cowboys • Kickoff in 2 days                    │
│   [SET LINEUP]                                      │
└─────────────────────────────────────────────────────┘

INJURY - Player injured
┌─────────────────────────────────────────────────────┐
│ + QB Smith out 4-6 weeks (ACL sprain)       [⤢] [×] │
│   Backup: J. Wilson (72 OVR)                        │
│   [MOVE TO IR]  [View Depth Chart]                  │
└─────────────────────────────────────────────────────┘

CONTRACT - Offer received
┌─────────────────────────────────────────────────────┐
│ $ Contract offer from Ravens for WR Lee     [⤢] [×] │
│   3yr/$24M • $12M guaranteed                        │
│   [ACCEPT]  [COUNTER]  [DECLINE]                    │
└─────────────────────────────────────────────────────┘

CONTRACT - Expiring soon
┌─────────────────────────────────────────────────────┐
│ $ CB Davis contract expires in 3 days       [⤢] [×] │
│   Current: 2yr/$8M • Asking: 3yr/$15M               │
│   [EXTEND $15M]  [Let Walk]  [Negotiate]            │
└─────────────────────────────────────────────────────┘

SCOUT - Report ready
┌─────────────────────────────────────────────────────┐
│ 🔍 Scout report: Marcus Hall, CB            [⤢] [×] │
│   Alabama • Projected: Round 1                      │
│   [ADD TO BOARD]                                    │
└─────────────────────────────────────────────────────┘

DRAFT - Your pick approaching
┌─────────────────────────────────────────────────────┐
│ 📋 Pick #14 coming up (3 picks away)        [⤢] [×] │
│   Best available: Hall CB, Porter OT                │
│   [OPEN DRAFT ROOM]  [Ask Coach]                    │
└─────────────────────────────────────────────────────┘

LEAGUE - Free agent available
┌─────────────────────────────────────────────────────┐
│ 📡 WR Marcus Johnson released by Cowboys    [⤢] [×] │
│   78 OVR • Cap casualty • High interest             │
│   [SIGN $2.1M]                                      │
└─────────────────────────────────────────────────────┘

LEAGUE - Trade rumor
┌─────────────────────────────────────────────────────┐
│ 📡 Bears shopping DE Williams               [⤢] [×] │
│   85 OVR • 2yr/$12M remaining                       │
│   [MAKE OFFER]                                      │
└─────────────────────────────────────────────────────┘

PERSONNEL - Waiver claim available
┌─────────────────────────────────────────────────────┐
│ 👤 RB Thompson on waivers (Waiver #8)       [⤢] [×] │
│   76 OVR • $1.2M salary                             │
│   [CLAIM]  [Pass]                                   │
└─────────────────────────────────────────────────────┘
```

### Window Control Icons

| Icon | Action | Keyboard |
|------|--------|----------|
| `⤢` | Expand to detail panel | `Enter` |
| `×` | Dismiss/archive message | `Backspace` or `D` |

**Expand (⤢)**: Opens the full context in the detail panel - player profile, contract details, game preview, etc. Use when you need more information before deciding.

**Dismiss (×)**: Archives the message. For informational messages, removes from inbox. For actionable messages, confirms you've seen it but chose not to act (e.g., passing on a free agent).

### MessageItem Component

```gdscript
class_name MessageItem extends Control

signal action_executed(message: GameMessage, action_id: String)
signal message_clicked(message: GameMessage)
signal message_dismissed(message: GameMessage)

var _message: GameMessage

func populate(message: GameMessage) -> void:
    _message = message
    _update_display()
    _create_action_buttons()

func _create_action_buttons() -> void:
    # Clear existing buttons
    for child in _action_container.get_children():
        child.queue_free()

    # Add primary action (highlighted)
    var primary = _message.get_primary_action()
    if primary:
        var btn = _create_action_button(primary, true)
        _action_container.add_child(btn)

    # Add secondary actions
    for action in _message.get_secondary_actions():
        var btn = _create_action_button(action, false)
        _action_container.add_child(btn)

func _create_action_button(action: MessageAction, is_primary: bool) -> Button:
    var btn = Button.new()
    btn.text = action.label
    btn.pressed.connect(_on_action_pressed.bind(action))
    if is_primary:
        btn.add_theme_stylebox_override("normal", _primary_style)
    return btn

func _on_action_pressed(action: MessageAction) -> void:
    if action.requires_confirmation:
        _show_confirmation_dialog(action)
    else:
        action_executed.emit(_message, action.id)
```

### Action Definitions per Message Type

```gdscript
# MessageAction factory methods
class_name MessageActionFactory

static func create_injury_actions(player: Player, injury: Dictionary) -> Array[MessageAction]:
    return [
        MessageAction.new({
            "id": "move_to_ir",
            "label": "MOVE TO IR",
            "is_primary": true,
            "action_type": "roster_move",
            "action_data": { "player_id": player.id, "destination": "IR" }
        }),
        MessageAction.new({
            "id": "view_depth",
            "label": "View Depth",
            "action_type": "navigate",
            "action_data": { "view": "depth_chart", "position": player.position }
        }),
        MessageAction.new({
            "id": "dismiss",
            "label": "Dismiss",
            "action_type": "dismiss"
        }),
    ]

static func create_contract_offer_actions(offer: Dictionary) -> Array[MessageAction]:
    return [
        MessageAction.new({
            "id": "accept",
            "label": "ACCEPT",
            "is_primary": true,
            "requires_confirmation": true,
            "action_type": "contract_respond",
            "action_data": { "response": "accept", "offer_id": offer.id }
        }),
        MessageAction.new({
            "id": "counter",
            "label": "COUNTER",
            "action_type": "navigate",
            "action_data": { "view": "contract_negotiation", "offer_id": offer.id }
        }),
        MessageAction.new({
            "id": "decline",
            "label": "DECLINE",
            "requires_confirmation": true,
            "action_type": "contract_respond",
            "action_data": { "response": "decline", "offer_id": offer.id }
        }),
    ]

static func create_free_agent_actions(player: Player, estimated_cost: int) -> Array[MessageAction]:
    var cost_str = "$%.1fM" % (estimated_cost / 1000000.0)
    return [
        MessageAction.new({
            "id": "sign",
            "label": "SIGN %s" % cost_str,
            "is_primary": true,
            "action_type": "sign_player",
            "action_data": { "player_id": player.id, "offer_amount": estimated_cost }
        }),
        MessageAction.new({
            "id": "view",
            "label": "View Player",
            "action_type": "navigate",
            "action_data": { "view": "player_detail", "player_id": player.id }
        }),
        MessageAction.new({
            "id": "dismiss",
            "label": "Dismiss",
            "action_type": "dismiss"
        }),
    ]
```

### Confirmation for Destructive Actions

Some actions show a quick inline confirmation rather than a modal dialog:

```
Before clicking DECLINE:
┌─────────────────────────────────────────┐
│ $ Contract offer from Ravens for WR Lee │
│   3yr/$24M • $12M guaranteed            │
│   [ACCEPT]  [COUNTER]  [DECLINE]        │
└─────────────────────────────────────────┘

After clicking DECLINE (inline confirmation):
┌─────────────────────────────────────────┐
│ $ Contract offer from Ravens for WR Lee │
│   ⚠️ Decline this offer?                │
│   [YES, DECLINE]  [Cancel]              │
└─────────────────────────────────────────┘
```

```gdscript
func _show_inline_confirmation(action: MessageAction) -> void:
    _normal_content.visible = false
    _confirmation_content.visible = true
    _confirm_label.text = action.confirmation_text
    _confirm_button.text = "YES, %s" % action.label
    _confirm_button.pressed.connect(_on_confirm.bind(action), CONNECT_ONE_SHOT)
    _cancel_button.pressed.connect(_cancel_confirmation, CONNECT_ONE_SHOT)
```

**Message Model**:
```gdscript
class_name GameMessage extends RefCounted

enum Category { CRITICAL, INJURY, CONTRACT, PERSONNEL, SCOUT, DRAFT, LEAGUE, NEWS, ACHIEVEMENT }
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
| LeagueNewsService | Player released | `LEAGUE` |
| LeagueNewsService | Trade completed | `LEAGUE` |
| LeagueNewsService | Trade rumor | `LEAGUE` |
| LeagueNewsService | Rival injury | `LEAGUE` |
| LeagueNewsService | FA signed elsewhere | `LEAGUE` |

### LeagueNewsService

**Purpose**: Monitors league-wide events and generates actionable intelligence for the player.

```gdscript
class_name LeagueNewsService extends RefCounted

signal league_event_occurred(event: Dictionary)

# Configuration
var _player_team_id: String
var _filters: Dictionary  # User preferences for what news to surface

# Event monitoring
func process_tick(world_state: Dictionary, events: Array[Dictionary]) -> Array[GameMessage]:
    var messages: Array[GameMessage] = []
    for event in events:
        if _is_relevant_to_player(event):
            messages.append(_create_league_message(event))
    return messages

func _is_relevant_to_player(event: Dictionary) -> bool:
    # Relevance criteria:
    # - Player released at position of need
    # - Division rival transaction
    # - High-profile signing/trade
    # - Upcoming opponent injury
    # - Draft prospect news (during draft season)
    pass

func _create_league_message(event: Dictionary) -> GameMessage:
    # Convert raw event to actionable message with context
    pass

# Manual queries
func get_recent_transactions(days: int = 7) -> Array[Dictionary]
func get_available_free_agents(filters: Dictionary = {}) -> Array[Dictionary]
func get_trade_block_players() -> Array[Dictionary]
```

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
- [ ] Left panel mode switching (Inbox/League/Draft tabs)

### Phase 2: Inbox System
- [ ] Create `MessageInbox` component
- [ ] Create `MessageItem` component
- [ ] Implement inbox sorting and filtering
- [ ] Keyboard navigation for inbox
- [ ] Unread/read state management
- [ ] Implement `LeagueNewsService` for around-the-league messages
- [ ] League message filtering preferences

### Phase 3: Detail Views
- [ ] Create `DetailPanel` with view registry
- [ ] Implement `MessageDetailView`
- [ ] Port existing `PlayerDetailFormatter` to view
- [ ] Create `RosterView` with editing capability
- [ ] Create `DepthChartView`

### Phase 4: League Explorer
- [ ] Create `LeagueExplorerPanel` with tree navigation
- [ ] Implement `LeagueTree` component (NFL/College/HS hierarchy)
- [ ] Create `LeagueSearchBar` with filters
- [ ] Create `TeamProfileView` for viewing other teams
- [ ] Create `DivisionStandingsView`
- [ ] Create `LeagueLeadersView`
- [ ] Create `PlayerComparisonView`

### Phase 5: Draft Board (Pre-Draft Planning)
- [ ] Create `DraftBoard` and `DraftBoardEntry` models
- [ ] Create `TeamNeeds` model with auto-calculation
- [ ] Create `DraftBoardView` with tier display
- [ ] Create `DraftBoardSidebar` (picks, needs, filters)
- [ ] Create `ProspectCard` component
- [ ] Implement drag-and-drop reordering
- [ ] Create `MockDraftSimulator` for projections

### Phase 6: Draft Day UI
- [ ] Create `DraftDayUI` main scene with layout
- [ ] Create `DraftTicker` component (live pick feed)
- [ ] Create `ProspectTable` with sorting/filtering
- [ ] Create `ProspectDetailCard` component
- [ ] Implement League Board vs Your Rankings toggle
- [ ] Create `AssistantCoach` recommendation engine
- [ ] Create `AssistantCoachPanel` UI
- [ ] Implement `DraftRecommendation` model with rationale generation
- [ ] Add coach style settings (Balanced/Need-Focused/BPA/Trade-Happy)
- [ ] Wire up draft pick confirmation flow

### Phase 7: Quick Actions & Navigation
- [ ] Create `QuickActionsPanel`
- [ ] Implement keyboard shortcuts
- [ ] Navigation stack for back functionality
- [ ] Create remaining detail views (schedule, cap management, etc.)

### Phase 8: Integration
- [ ] Connect to game simulation loop
- [ ] Implement advance tick with blocking decisions
- [ ] Message creation from game events
- [ ] League event monitoring and news generation
- [ ] Persistence (save/load messages, draft board, coach settings)

---

## File Structure Summary

```
scenes/ui/gameplay/
├── gameplay_ui.tscn
├── GameplayUI.gd
├── team_info_bar/
│   ├── team_info_bar.tscn
│   └── TeamInfoBar.gd
├── left_panel/
│   ├── left_panel.tscn              # Container with mode tabs
│   ├── LeftPanel.gd
│   ├── message_inbox/
│   │   ├── message_inbox.tscn
│   │   ├── MessageInbox.gd
│   │   ├── message_item.tscn
│   │   └── MessageItem.gd
│   ├── league_explorer/
│   │   ├── league_explorer_panel.tscn
│   │   ├── LeagueExplorerPanel.gd
│   │   ├── league_tree.tscn
│   │   ├── LeagueTree.gd
│   │   ├── search_bar.tscn
│   │   └── LeagueSearchBar.gd
│   ├── draft_board_sidebar/
│   │   ├── draft_board_sidebar.tscn
│   │   └── DraftBoardSidebar.gd
│   └── quick_actions/
│       ├── quick_actions_panel.tscn
│       └── QuickActionsPanel.gd
├── draft_board/
│   ├── draft_board_view.tscn
│   ├── DraftBoardView.gd
│   ├── tier_container.tscn
│   ├── TierContainer.gd
│   ├── prospect_card.tscn
│   └── ProspectCard.gd
├── draft_day/
│   ├── draft_day_ui.tscn
│   ├── DraftDayUI.gd
│   ├── draft_ticker.tscn
│   ├── DraftTicker.gd
│   ├── prospect_table.tscn
│   ├── ProspectTable.gd
│   ├── prospect_detail_card.tscn
│   ├── ProspectDetailCard.gd
│   ├── assistant_coach_panel.tscn
│   └── AssistantCoachPanel.gd
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
        ├── schedule_view.tscn
        ├── trade_view.tscn
        ├── team_profile_view.tscn       # Other teams
        ├── team_roster_view.tscn        # Other team's roster
        ├── team_schedule_view.tscn      # Team's season schedule
        ├── division_standings_view.tscn
        ├── league_leaders_view.tscn
        ├── player_comparison_view.tscn
        └── matchup_view.tscn

scripts/services/
├── message_manager/
│   ├── MessageManager.gd
│   ├── GameMessage.gd
│   └── MessageAction.gd
├── league_news/
│   └── LeagueNewsService.gd
├── draft_board/
│   ├── DraftBoard.gd
│   ├── DraftBoardEntry.gd
│   ├── TeamNeeds.gd
│   └── MockDraftSimulator.gd
└── assistant_coach/
    ├── AssistantCoach.gd
    ├── DraftRecommendation.gd
    └── AssistantCoachSettings.gd
```

---

## League Explorer System

The League Explorer provides comprehensive browsing of the entire football world - all teams, players, and statistics across NFL, College, and High School levels.

### Explorer Modes

The left panel transforms based on context, similar to how email clients switch between Inbox/Folders/Search views:

```
┌────────────────────┬────────────────────────────────────────────────────────┐
│  [Inbox] [League]  │                                                        │
├────────────────────┤  DETAIL PANEL                                          │
│                    │                                                        │
│  LEAGUE BROWSER    │  Shows selected entity details:                        │
│                    │  • Team roster, cap situation, schedule                │
│  ┌──────────────┐  │  • Player profile, stats, contract                     │
│  │ 🔍 Search... │  │  • Division standings                                  │
│  └──────────────┘  │  • Matchup history                                     │
│                    │                                                        │
│  NFL              │                                                        │
│  ├─ AFC           │                                                        │
│  │  ├─ East       │                                                        │
│  │  │  ├─ Bills   │                                                        │
│  │  │  ├─ Dolphins│                                                        │
│  │  │  ├─ Patriots│                                                        │
│  │  │  └─ Jets    │                                                        │
│  │  ├─ North      │                                                        │
│  │  └─ ...        │                                                        │
│  └─ NFC           │                                                        │
│                    │                                                        │
│  COLLEGE           │                                                        │
│  ├─ SEC           │                                                        │
│  ├─ Big Ten       │                                                        │
│  └─ ...           │                                                        │
│                    │                                                        │
│  HIGH SCHOOL       │                                                        │
│  └─ By State      │                                                        │
└────────────────────┴────────────────────────────────────────────────────────┘
```

### League Explorer Structure

```
scenes/ui/gameplay/
└── league_explorer/
    ├── league_explorer_panel.tscn
    ├── LeagueExplorerPanel.gd
    ├── league_tree.tscn
    ├── LeagueTree.gd
    └── search_bar.tscn
```

### LeagueTree Component

**Purpose**: Hierarchical navigation of all football entities.

```gdscript
class_name LeagueTree extends Tree

enum NodeType { ROOT, LEVEL, CONFERENCE, DIVISION, TEAM, POSITION_GROUP, PLAYER }

# Tree structure mirrors data hierarchy
# NFL → Conference → Division → Team → Position Group → Player
# College → Conference → School → Position Group → Player
# HS → State → School → Player

signal entity_selected(entity_type: NodeType, entity_id: String, metadata: Dictionary)
signal entity_double_clicked(entity_type: NodeType, entity_id: String)

func populate_from_world_state(world_state: Dictionary) -> void
func expand_to_entity(entity_type: NodeType, entity_id: String) -> void
func filter_by_search(query: String) -> void
func set_view_mode(mode: ViewMode) -> void  # HIERARCHY, FLAT_LIST, SEARCH_RESULTS
```

### Search Functionality

```gdscript
class_name LeagueSearchBar extends HBoxContainer

signal search_submitted(query: String, filters: Dictionary)
signal filter_changed(filters: Dictionary)

var _filters: Dictionary = {
    "levels": ["NFL", "COLLEGE", "HS"],  # Which levels to search
    "entity_types": ["TEAM", "PLAYER"],   # What to find
    "positions": [],                       # Position filter (empty = all)
    "min_overall": 0,                      # Rating threshold
}

func get_search_results(world_state: Dictionary, query: String) -> Array[Dictionary]
```

### Explorer Detail Views

Additional views for league exploration:

```
scenes/ui/gameplay/detail_panel/views/
├── team_profile_view.tscn      # Full team details (not your team)
├── team_roster_view.tscn       # Other team's roster
├── team_schedule_view.tscn     # Team's season schedule
├── division_standings_view.tscn # Division/Conference standings
├── league_leaders_view.tscn    # Statistical leaders
├── player_comparison_view.tscn # Side-by-side player comparison
└── matchup_view.tscn           # Head-to-head team comparison
```

### Team Profile View

**Purpose**: Comprehensive view of any team in the league.

```gdscript
class_name TeamProfileView extends Control

# Sections:
# 1. Header: Team name, logo, record, division standing
# 2. Quick Stats: Points for/against, cap situation, draft picks
# 3. Roster Summary: Starters by position with ratings
# 4. Recent Results: Last 5 games
# 5. Upcoming Schedule: Next 3 games
# 6. Action Bar: Scout Team, Propose Trade, View Full Roster

func populate(context: Dictionary) -> void:
    var team_id = context.get("team_id")
    var team = TeamQueries.get_team_by_id(_world_state, team_id)
    # ... build display

signal action_requested(action: String, context: Dictionary)
# Actions: "scout_team", "propose_trade", "view_roster", "view_schedule"
```

---

## Draft Board Planning System

The Draft Board is the user's personal ranking and organization tool for upcoming drafts. Unlike scouting (which discovers information), the draft board is for strategic planning.

### Draft Board Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  DRAFT BOARD - 2025 Draft                          [By Position] [By Tier] │
├────────────────────┬────────────────────────────────────────────────────────┤
│  YOUR PICKS        │  BOARD VIEW                                            │
│  ┌──────────────┐  │  ┌──────────────────────────────────────────────────┐  │
│  │ Rd 1, #14    │  │  │  TIER 1 - Elite Prospects                       │  │
│  │ Rd 2, #46    │  │  │  ┌─────┬─────┬─────┬─────┬─────┐                │  │
│  │ Rd 3, #78    │  │  │  │ #1  │ #2  │ #3  │ #4  │ #5  │                │  │
│  │ Rd 4, #110   │  │  │  │Smith│Jones│Brown│Davis│Wilson                │  │
│  │ Rd 5, #142   │  │  │  │ QB  │ DE  │ OT  │ CB  │ WR  │                │  │
│  └──────────────┘  │  │  │ 95  │ 93  │ 92  │ 91  │ 90  │                │  │
│                    │  │  └─────┴─────┴─────┴─────┴─────┘                │  │
│  TEAM NEEDS        │  │                                                  │  │
│  ┌──────────────┐  │  │  TIER 2 - Day 1 Starters                        │  │
│  │ 1. CB  ████  │  │  │  ┌─────┬─────┬─────┬─────┬─────┬─────┐          │  │
│  │ 2. OT  ███   │  │  │  │ #6  │ #7  │ #8  │ #9  │ #10 │ ... │          │  │
│  │ 3. WR  ██    │  │  │  └─────┴─────┴─────┴─────┴─────┴─────┘          │  │
│  │ 4. LB  █     │  │  │                                                  │  │
│  └──────────────┘  │  │  TIER 3 - Quality Depth                         │  │
│                    │  │  ...                                             │  │
│  POSITION FILTER   │  │                                                  │  │
│  [All] QB OT CB WR │  │  ─────────────────────────────────────────────   │  │
│                    │  │  DO NOT DRAFT (crossed off)                      │  │
│  [+ Add to Board]  │  │  ┌─────┬─────┐                                   │  │
│                    │  │  │ X   │ X   │                                   │  │
│                    │  └──┴─────┴─────┴──────────────────────────────────┘  │
└────────────────────┴────────────────────────────────────────────────────────┘
```

### Draft Board Structure

```
scenes/ui/gameplay/
└── draft_board/
    ├── draft_board_view.tscn
    ├── DraftBoardView.gd
    ├── draft_board_sidebar.tscn
    ├── DraftBoardSidebar.gd
    ├── tier_container.tscn
    ├── TierContainer.gd
    ├── prospect_card.tscn
    └── ProspectCard.gd

scripts/services/
└── draft_board/
    ├── DraftBoard.gd
    ├── DraftBoardEntry.gd
    └── TeamNeeds.gd
```

### DraftBoard Model

```gdscript
class_name DraftBoard extends RefCounted

signal board_updated()
signal prospect_moved(player_id: String, from_tier: int, to_tier: int, new_rank: int)
signal prospect_removed(player_id: String)

var draft_year: int
var entries: Array[DraftBoardEntry] = []
var team_needs: TeamNeeds
var do_not_draft: Array[String] = []  # Player IDs to avoid

# Tier Management
const TIER_ELITE = 1        # Blue chip, franchise players
const TIER_DAY1_STARTER = 2 # Immediate impact starters
const TIER_QUALITY_DEPTH = 3 # Year 1-2 contributors
const TIER_DEVELOPMENTAL = 4 # Project players
const TIER_CAMP_BODY = 5    # Long shots

func add_prospect(player_id: String, tier: int, rank_in_tier: int = -1) -> void
func move_prospect(player_id: String, new_tier: int, new_rank: int) -> void
func remove_prospect(player_id: String) -> void
func add_to_do_not_draft(player_id: String, reason: String) -> void

func get_by_tier(tier: int) -> Array[DraftBoardEntry]
func get_by_position(position: String) -> Array[DraftBoardEntry]
func get_best_available(exclude_positions: Array[String] = []) -> DraftBoardEntry
func get_best_at_position(position: String) -> DraftBoardEntry

# Auto-suggestions based on scouting
func suggest_tier_for_prospect(player_id: String, world_state: Dictionary) -> int

# Persistence
func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> DraftBoard
```

### DraftBoardEntry Model

```gdscript
class_name DraftBoardEntry extends RefCounted

var player_id: String
var tier: int
var rank_in_tier: int  # Position within tier (1 = top of tier)
var notes: String      # User's personal notes
var tags: Array[String]  # User-defined tags like "sleeper", "risky", "trade up"
var fits_need: bool    # Auto-calculated based on TeamNeeds
var scouted: bool      # Has full scouting report
var interest_level: int  # 1-5 stars user rating

func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> DraftBoardEntry
```

### TeamNeeds Model

```gdscript
class_name TeamNeeds extends RefCounted

signal needs_updated()

# Position -> Priority (1 = critical, 5 = luxury)
var needs: Dictionary = {}  # { "CB": 1, "OT": 2, "WR": 3, ... }

func set_need(position: String, priority: int) -> void
func remove_need(position: String) -> void
func get_priority(position: String) -> int  # Returns 0 if not a need
func get_critical_needs() -> Array[String]  # Priority 1-2
func get_all_needs_sorted() -> Array[Dictionary]  # [{position, priority}]

# Auto-calculate from roster
func calculate_from_roster(roster: Roster, depth_chart: DepthChart) -> void

func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> TeamNeeds
```

### Draft Board Interactions

**Drag and Drop**:
- Drag prospects between tiers
- Reorder within tiers
- Drag to "Do Not Draft" zone

**Context Menu** (right-click on prospect):
- View Full Profile
- Add/Edit Notes
- Add Tags
- Move to Tier →
- Scout This Player
- Add to Do Not Draft
- Remove from Board

**Keyboard Shortcuts**:
| Key | Action |
|-----|--------|
| `1-5` | Move selected prospect to tier 1-5 |
| `N` | Add/edit notes on selected prospect |
| `X` | Add to Do Not Draft |
| `Delete` | Remove from board |
| `/` | Focus search to add prospect |
| `Tab` | Cycle through tiers |

### Draft Board Views

```gdscript
enum BoardViewMode {
    BY_TIER,      # Default: Prospects grouped by tier
    BY_POSITION,  # Grouped by position, sorted by tier within
    BY_NEED,      # Grouped by team need priority
    COMPARISON,   # Side-by-side prospect comparison
}
```

### Mock Draft Integration

```gdscript
class_name MockDraftSimulator extends RefCounted

# Simulates draft based on:
# - Other teams' needs (estimated)
# - Prospect rankings (consensus or custom)
# - Your draft board

func simulate_to_pick(pick_number: int, board: DraftBoard) -> Array[Dictionary]
# Returns [{pick: 1, team: "Chiefs", player_id: "...", position: "QB"}, ...]

func get_projected_available_at_pick(pick: int, board: DraftBoard) -> Array[DraftBoardEntry]
# Who might still be available when you pick?

func get_reach_probability(player_id: String, pick: int) -> float
# Probability this player is still available at pick
```

---

## Draft Day UI

When the draft begins, the UI transforms into a dedicated **Draft Day Experience** - a focused, high-stakes interface for making picks in real-time.

### Draft Day Layout

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  🏈 2025 NFL DRAFT - ROUND 1                              Pick 14 • Your Turn!  │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
├───────────────────────────────┬─────────────────────────────────────────────────┤
│                               │                                                 │
│  DRAFT TICKER                 │  [League Board]  [Your Rankings]                │
│  ┌─────────────────────────┐  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│  │ 1. Chiefs    QB Smith   │  │                                                 │
│  │ 2. Bears     DE Jones   │  │  AVAILABLE PROSPECTS                            │
│  │ 3. Patriots  OT Brown   │  │  ┌─────────────────────────────────────────────┐│
│  │ 4. Titans    CB Davis   │  │  │ Rank │ Player        │ Pos │ OVR │ Fit    ││
│  │ 5. Jets      WR Wilson  │  │  ├─────────────────────────────────────────────┤│
│  │ ...                     │  │  │  #6  │ Marcus Hall   │ CB  │ 91  │ ★★★★★  ││
│  │ 13. Browns   LB Thomas  │  │  │  #8  │ James Porter  │ OT  │ 89  │ ★★★★   ││
│  │ ──────────────────────  │  │  │  #9  │ DeShawn Miles │ WR  │ 88  │ ★★★    ││
│  │ ▶ 14. EAGLES  YOUR PICK │  │  │ #11  │ Tyler Jackson │ LB  │ 87  │ ★★     ││
│  │ ──────────────────────  │  │  │ #12  │ Chris Adams   │ S   │ 86  │ ★      ││
│  │ 15. Colts    (waiting)  │  │  └─────────────────────────────────────────────┘│
│  │ 16. Seahawks (waiting)  │  │                                                 │
│  └─────────────────────────┘  │  ─────────────────────────────────────────────  │
│                               │                                                 │
│  YOUR PICKS                   │  SELECTED: Marcus Hall, CB                      │
│  ┌─────────────────────────┐  │  ┌─────────────────────────────────────────────┐│
│  │ Rd 1, #14 ◀ NOW         │  │  │  Height: 6'1" | Weight: 195 lbs             ││
│  │ Rd 2, #46               │  │  │  College: Alabama | Age: 22                 ││
│  │ Rd 3, #78               │  │  │  Strengths: Ball skills, Recovery speed     ││
│  │ Rd 4, #110              │  │  │  Scout Grade: 91 | Your Tier: 1 (Elite)     ││
│  └─────────────────────────┘  │  │                                             ││
│                               │  │  [DRAFT HIM]         [Compare]              ││
│  ┌─────────────────────────┐  │  └─────────────────────────────────────────────┘│
│  │ [TRADE UP] [TRADE DOWN] │  │                                                 │
│  └─────────────────────────┘  │                                                 │
│  ┌─────────────────────────┐  │                                                 │
│  │  🧠 Ask Assistant Coach │  │                                                 │
│  └─────────────────────────┘  │                                                 │
│                               │                                                 │
│  INCOMING OFFERS (1)          │                                                 │
│  ┌─────────────────────────┐  │                                                 │
│  │ 🔔 Broncos want #14     │  │                                                 │
│  │    Offer: #18 + #50     │  │                                                 │
│  │    [ACCEPT] [COUNTER]   │  │                                                 │
│  └─────────────────────────┘  │                                                 │
└───────────────────────────────┴─────────────────────────────────────────────────┘
```

### Draft Day Components

```
scenes/ui/gameplay/
└── draft_day/
    ├── draft_day_ui.tscn
    ├── DraftDayUI.gd
    ├── draft_ticker.tscn
    ├── DraftTicker.gd
    ├── prospect_table.tscn
    ├── ProspectTable.gd
    ├── prospect_detail_card.tscn
    ├── ProspectDetailCard.gd
    ├── assistant_coach_panel.tscn
    ├── AssistantCoachPanel.gd
    ├── trade_panel.tscn
    ├── TradePanel.gd
    ├── trade_offer_item.tscn
    └── TradeOfferItem.gd
```

---

## Draft Day Trading

### Trade Up/Down Buttons

The left panel includes trade buttons that open a trade panel:

```
┌─────────────────────────┐
│ [TRADE UP] [TRADE DOWN] │
└─────────────────────────┘
```

**TRADE UP**: Opens panel to offer a package for an earlier pick
**TRADE DOWN**: Shows teams interested in your current/upcoming picks

### Trade Up Panel

```
┌─────────────────────────────────────────────────────────────────┐
│  📞 TRADE UP - Acquire Earlier Pick                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TARGET PICK                                                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Pick #10 (Broncos)  ◀ ▶  Pick #11 (Giants)               │  │
│  │  2 picks until selection                                  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  YOUR OFFER                        TRADE VALUE                  │
│  ┌─────────────────────────┐      ┌─────────────────────────┐  │
│  │ ☑ Rd 1, #14 (1100 pts)  │      │  Your offer:  1400 pts  │  │
│  │ ☑ Rd 3, #78 (200 pts)   │      │  Target pick: 1300 pts  │  │
│  │ ☐ Rd 4, #110 (80 pts)   │      │  ─────────────────────  │  │
│  │ ☐ WR T.Smith (150 pts)  │      │  ✓ Fair trade (+100)    │  │
│  └─────────────────────────┘      └─────────────────────────┘  │
│                                                                 │
│  Broncos interest: HIGH (they want to trade back)               │
│                                                                 │
│  [SEND OFFER]                              [Cancel]             │
└─────────────────────────────────────────────────────────────────┘
```

### Trade Down Panel

```
┌─────────────────────────────────────────────────────────────────┐
│  📞 TRADE DOWN - Move Back for Compensation                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INTERESTED TEAMS                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Broncos want #14 → Offering #18 + #82         [DETAILS]  │  │
│  │  Jets want #14    → Offering #17 + 2025 3rd    [DETAILS]  │  │
│  │  Raiders want #14 → Offering #20 + #52         [DETAILS]  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Or propose your own trade:                                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Trade #14 to: [Select Team ▼]                            │  │
│  │  Request:      [Build Package...]                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [Close]                                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Incoming Trade Offers (Left Panel)

Trade offers appear in the left panel with inline actions:

```
INCOMING OFFERS (2)
┌─────────────────────────────────────┐
│ 🔔 Broncos want #14                 │
│    Offer: #18 + #82                 │
│    Value: +150 pts                  │
│    [ACCEPT]  [COUNTER]  [DECLINE]   │
├─────────────────────────────────────┤
│ 🔔 Jets want #46                    │
│    Offer: #52 + 2025 4th            │
│    Value: +80 pts                   │
│    [ACCEPT]  [COUNTER]  [DECLINE]   │
└─────────────────────────────────────┘
```

### TradeOffer Model

```gdscript
class_name DraftTradeOffer extends RefCounted

var id: String
var offering_team_id: String
var created_at_pick: int      # When offer was generated
var expires_at_pick: int      # Auto-expire if not responded

# What they want
var requested_picks: Array[DraftPick]
var requested_players: Array[String]  # Player IDs

# What they're offering
var offered_picks: Array[DraftPick]
var offered_players: Array[String]

# Computed
var value_delta: int          # Positive = good for user
var is_fair: bool             # Within acceptable range

func get_summary() -> String:
    # "Broncos want #14 → Offering #18 + #82"
    pass

func is_still_valid(current_pick: int, ownership: Dictionary) -> bool:
    if current_pick > expires_at_pick:
        return false
    # Validate picks haven't been traded/executed
    for pick in requested_picks:
        if pick.pick_number <= current_pick:
            return false
    return true

func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> DraftTradeOffer
```

### Trade Value Chart

```gdscript
class_name DraftPickValueChart extends RefCounted

# Standard NFL draft value chart (simplified)
const PICK_VALUES = {
    1: 3000, 2: 2600, 3: 2200, 4: 1800, 5: 1700,
    6: 1600, 7: 1500, 8: 1400, 9: 1350, 10: 1300,
    11: 1250, 12: 1200, 13: 1150, 14: 1100, 15: 1050,
    16: 1000, 17: 950, 18: 900, 19: 875, 20: 850,
    # ... continues through pick 256
    32: 590,   # End of round 1
    64: 270,   # End of round 2
    96: 116,   # End of round 3
    128: 54,   # End of round 4
    160: 29,   # End of round 5
    192: 15,   # End of round 6
    224: 5,    # End of round 7
}

static func get_value(pick_number: int) -> int:
    if pick_number in PICK_VALUES:
        return PICK_VALUES[pick_number]
    # Interpolate for missing values
    return _interpolate_value(pick_number)

static func get_player_trade_value(player: Player) -> int:
    # Based on overall rating, age, contract
    var base = player.overall * 15
    var age_modifier = max(0, 30 - player.age) * 10
    return base + age_modifier

static func evaluate_trade(give: Array, receive: Array) -> Dictionary:
    var give_value = _sum_values(give)
    var receive_value = _sum_values(receive)
    return {
        "give_value": give_value,
        "receive_value": receive_value,
        "delta": receive_value - give_value,
        "is_fair": abs(receive_value - give_value) < 200,
    }
```

---

## Draft Day Action Taxonomy

### Blocking Actions (Draft Waits for User)

| Action | Trigger | Resolution |
|--------|---------|------------|
| **Make Pick** | Your turn starts | Select player and confirm |
| **Accept Trade** | Trade offer for current pick | Execute trade, skip turn |
| **Auto-Pick** | Timeout (60s) or user request | System selects from board |

### Non-Blocking Actions (Parallel to Draft)

| Action | When Available | Effect |
|--------|----------------|--------|
| Reorder Draft Board | Anytime | Update rankings |
| View Player Detail | Anytime | Modal overlay |
| Compare Prospects | Anytime | Side-by-side view |
| Filter/Sort Table | Anytime | UI state only |
| Consult Coach | Anytime | Show recommendations |
| Respond to Trade Offer | Anytime (unless for current pick) | Queue response |

### Action State Machine

```gdscript
enum DraftActionState {
    WAITING_FOR_TURN,      # AI picks happening, non-blocking only
    ON_CLOCK_DECIDING,     # Your pick, all actions available
    ON_CLOCK_TRADING,      # Negotiating trade, pick paused
    PICK_CONFIRMED,        # Executing pick
    TRADE_CONFIRMED,       # Executing trade
}

# State transitions
# WAITING → ON_CLOCK_DECIDING (your pick starts)
# ON_CLOCK_DECIDING → ON_CLOCK_TRADING (open trade panel)
# ON_CLOCK_DECIDING → PICK_CONFIRMED (click Draft)
# ON_CLOCK_TRADING → TRADE_CONFIRMED (accept trade)
# ON_CLOCK_TRADING → ON_CLOCK_DECIDING (cancel trade)
# PICK_CONFIRMED → WAITING (pick executes, next team)
# TRADE_CONFIRMED → WAITING (trade executes, other team picks)
```

### Incoming Events During Draft

| Event | Trigger | User Response Required? |
|-------|---------|------------------------|
| Pick Approaching | 3 picks before your turn | No (advisory) |
| Your Pick Started | Clock starts | **Yes** - must act or timeout |
| Trade Offer Received | AI team wants your pick | No (can respond later) |
| Target Player Drafted | AI takes player you wanted | No (adjust strategy) |
| Trade Offer Expired | Pick passed or target drafted | No (informational) |
| Round Complete | Last pick of round | No (natural break) |

### View Toggle: League Board vs Your Rankings

**League Board View**: Shows prospects ranked by consensus/media rankings
- What the "experts" think
- Helps gauge if a player is a reach or value pick
- Shows where players are expected to go

**Your Rankings View**: Shows prospects by your personal draft board
- Your tier assignments and rankings
- Highlights fits for your team needs
- Shows your notes and tags

```gdscript
enum DraftViewMode {
    LEAGUE_BOARD,   # Consensus rankings
    YOUR_RANKINGS,  # Personal draft board
}
```

### Draft Ticker

Live feed of picks as they happen:

```gdscript
class_name DraftTicker extends Control

signal pick_selected(pick_number: int)

var _picks: Array[DraftPick] = []
var _current_pick: int = 0
var _user_pick_numbers: Array[int] = []  # Highlight user's picks

func add_pick(pick: DraftPick) -> void
func scroll_to_current() -> void
func highlight_user_picks() -> void

# Visual states for each pick row:
# - Completed (team + player shown)
# - Current (highlighted, "YOUR PICK" if user's turn)
# - Upcoming (team only, waiting)
```

### Prospect Table

Sortable, filterable list of available players:

```gdscript
class_name ProspectTable extends Control

signal prospect_selected(player_id: String)
signal prospect_drafted(player_id: String)

enum SortColumn { RANK, NAME, POSITION, OVERALL, FIT }

var _sort_by: SortColumn = SortColumn.RANK
var _filter_position: String = ""  # Empty = all positions
var _show_only_board: bool = false  # Only show players on your board

func populate(available_players: Array[Dictionary], board: DraftBoard, needs: TeamNeeds) -> void
func sort_by(column: SortColumn) -> void
func filter_by_position(position: String) -> void
func remove_player(player_id: String) -> void  # When drafted by another team

# Fit rating calculation (★ system)
func _calculate_fit(player: Dictionary, needs: TeamNeeds) -> int:
    var position = player.get("position")
    var need_priority = needs.get_priority(position)
    if need_priority == 0:
        return 1  # Not a need
    return 6 - need_priority  # Priority 1 = ★★★★★, Priority 5 = ★
```

### Prospect Detail Card

Quick-reference card for selected prospect:

```gdscript
class_name ProspectDetailCard extends Control

signal draft_requested(player_id: String)
signal compare_requested(player_id: String)

func populate(player: Dictionary, scout_report: Dictionary, board_entry: DraftBoardEntry) -> void

# Sections:
# - Header: Name, position, college, age
# - Physical: Height, weight, arm length, etc.
# - Ratings: Key stats for position
# - Analysis: Strengths/concerns from scouting
# - Board Info: Your tier, notes, tags
# - Actions: Draft, Compare, Pass
```

---

## Assistant Coach System

The **Assistant Coach** is an algorithmic advisor that analyzes your team's needs, available prospects, and draft position to provide the top 3 recommendations. Rationale text is generated from templates based on scoring factors - no external AI required.

### Assistant Coach Panel

Each recommendation card has a **DRAFT** button that immediately makes the pick - no confirmation dialog, no extra clicks.

```
┌─────────────────────────────────────────────────────────────────┐
│  🧠 ASSISTANT COACH - Pick #14                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  #1  Marcus Hall, CB                         [DRAFT HIM]  │  │
│  │      Alabama | OVR: 91 | Tier: Elite | Fit: ★★★★★         │  │
│  │      ✓ Critical need  ✓ Best available  ✓ Great value     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  #2  James Porter, OT                        [DRAFT HIM]  │  │
│  │      Ohio State | OVR: 89 | Tier: Day 1 | Fit: ★★★★       │  │
│  │      ✓ Key need  ○ Slight reach  ✓ Premium position       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  #3  DeShawn Miles, WR                       [DRAFT HIM]  │  │
│  │      Georgia | OVR: 88 | Tier: Day 1 | Fit: ★★★           │  │
│  │      ✓ Best talent  ○ Not critical need  ✓ Good value     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [Close - I'll pick myself]                                     │
└─────────────────────────────────────────────────────────────────┘
```

### AssistantCoach Model

```gdscript
class_name AssistantCoach extends RefCounted

signal recommendations_ready(recommendations: Array[DraftRecommendation])

# Configurable weighting for scoring
enum CoachStyle {
    BALANCED,       # 40% talent, 40% need, 20% value
    NEED_FOCUSED,   # 25% talent, 55% need, 20% value
    BPA_FOCUSED,    # 60% talent, 20% need, 20% value
}

var coach_style: CoachStyle = CoachStyle.BALANCED
var _team_needs: TeamNeeds
var _draft_board: DraftBoard

# Weights per style
const STYLE_WEIGHTS = {
    CoachStyle.BALANCED: { "talent": 0.4, "need": 0.4, "value": 0.2 },
    CoachStyle.NEED_FOCUSED: { "talent": 0.25, "need": 0.55, "value": 0.2 },
    CoachStyle.BPA_FOCUSED: { "talent": 0.6, "need": 0.2, "value": 0.2 },
}

func generate_recommendations(
    pick_number: int,
    available_players: Array[Dictionary]
) -> Array[DraftRecommendation]:
    var scored = _score_all_players(available_players, pick_number)
    return _build_top_3_recommendations(scored, pick_number)

func _score_all_players(players: Array[Dictionary], pick: int) -> Array[Dictionary]:
    var weights = STYLE_WEIGHTS[coach_style]
    var scored = []

    for player in players:
        var talent_score = player.get("overall", 50) / 100.0  # 0-1
        var need_score = _calculate_need_score(player.get("position"))  # 0-1
        var value_score = _calculate_value_score(player, pick)  # 0-1

        var total = (
            talent_score * weights.talent +
            need_score * weights.need +
            value_score * weights.value
        )

        scored.append({
            "player": player,
            "total_score": total,
            "talent_score": talent_score,
            "need_score": need_score,
            "value_score": value_score,
            "need_priority": _team_needs.get_priority(player.get("position")),
        })

    scored.sort_custom(func(a, b): return a.total_score > b.total_score)
    return scored

func _calculate_need_score(position: String) -> float:
    var priority = _team_needs.get_priority(position)
    if priority == 0:
        return 0.1  # Not a need at all
    # Priority 1 = 1.0, Priority 5 = 0.2
    return 1.0 - (priority - 1) * 0.2

func _calculate_value_score(player: Dictionary, pick: int) -> float:
    var player_id = player.get("id", "")
    var tier = 3  # Default to middle tier
    if _draft_board.has_player(player_id):
        tier = _draft_board.get_entry(player_id).tier

    # Expected pick ranges by tier
    var expected_pick = _tier_to_expected_pick(tier)
    var value_delta = expected_pick - pick

    # Normalize: getting a Tier 1 at pick 20 is great value (+1.0)
    # Taking a Tier 3 at pick 5 is a reach (-0.5)
    return clampf((value_delta / 20.0) + 0.5, 0.0, 1.0)

func _tier_to_expected_pick(tier: int) -> int:
    match tier:
        1: return 10   # Elite: expected top 10
        2: return 32   # Day 1 Starter: expected round 1
        3: return 64   # Quality Depth: expected round 2
        4: return 128  # Developmental: expected rounds 3-4
        _: return 200  # Camp Body: late rounds
```

### DraftRecommendation Model

```gdscript
class_name DraftRecommendation extends RefCounted

var player_id: String
var player_name: String
var position: String
var college: String
var overall: int
var tier: int
var tier_label: String  # "Elite", "Day 1 Starter", etc.
var fit_stars: int      # 1-5 based on need priority

# Scoring breakdown
var total_score: float
var talent_score: float
var need_score: float
var value_score: float
var need_priority: int  # 0 = not a need, 1 = critical, 5 = luxury

# Generated bullet points (deterministic from scores)
var pros: Array[String]
var cons: Array[String]

static func from_scored_player(data: Dictionary, board: DraftBoard, pick: int) -> DraftRecommendation:
    var rec = DraftRecommendation.new()
    var player = data.player

    rec.player_id = player.get("id", "")
    rec.player_name = "%s %s" % [player.get("first_name", ""), player.get("last_name", "")]
    rec.position = player.get("position", "")
    rec.college = player.get("college", "")
    rec.overall = player.get("overall", 0)

    # Tier info
    if board.has_player(rec.player_id):
        var entry = board.get_entry(rec.player_id)
        rec.tier = entry.tier
    else:
        rec.tier = 3  # Unranked = assume middle tier
    rec.tier_label = _get_tier_label(rec.tier)

    # Scores
    rec.total_score = data.total_score
    rec.talent_score = data.talent_score
    rec.need_score = data.need_score
    rec.value_score = data.value_score
    rec.need_priority = data.need_priority

    # Fit stars (inverse of priority, 0 priority = 1 star)
    rec.fit_stars = 1 if rec.need_priority == 0 else 6 - rec.need_priority

    # Generate pros/cons from scores
    rec.pros = _generate_pros(rec, pick)
    rec.cons = _generate_cons(rec, pick)

    return rec

static func _get_tier_label(tier: int) -> String:
    match tier:
        1: return "Elite"
        2: return "Day 1 Starter"
        3: return "Quality Depth"
        4: return "Developmental"
        _: return "Camp Body"

static func _generate_pros(rec: DraftRecommendation, pick: int) -> Array[String]:
    var pros: Array[String] = []

    # Talent-based pros
    if rec.overall >= 90:
        pros.append("Elite talent (OVR %d)" % rec.overall)
    elif rec.overall >= 85:
        pros.append("High-end starter potential")
    elif rec.talent_score > 0.75:
        pros.append("Best pure talent available")

    # Need-based pros
    if rec.need_priority == 1:
        pros.append("Fills critical need (%s - Priority 1)" % rec.position)
    elif rec.need_priority == 2:
        pros.append("Fills key need (%s - Priority 2)" % rec.position)
    elif rec.need_priority > 0 and rec.need_priority <= 3:
        pros.append("Addresses team need (%s)" % rec.position)

    # Value-based pros
    if rec.value_score > 0.7:
        pros.append("Great value (%s at pick #%d)" % [rec.tier_label, pick])
    elif rec.value_score > 0.5:
        pros.append("Good value")

    # Position premium
    if rec.position in ["QB", "OT", "EDGE", "CB"]:
        pros.append("Premium position")

    return pros

static func _generate_cons(rec: DraftRecommendation, pick: int) -> Array[String]:
    var cons: Array[String] = []

    # Value concerns
    if rec.value_score < 0.3:
        cons.append("Significant reach at #%d" % pick)
    elif rec.value_score < 0.45:
        cons.append("Slight reach (%s at pick #%d)" % [rec.tier_label, pick])

    # Need concerns
    if rec.need_priority == 0:
        cons.append("Not a team need (%s)" % rec.position)
    elif rec.need_priority >= 4:
        cons.append("Low priority need (%s - Priority %d)" % [rec.position, rec.need_priority])

    # Talent concerns
    if rec.overall < 75:
        cons.append("Below-average prospect (OVR %d)" % rec.overall)

    return cons

func to_dict() -> Dictionary
```

### Assistant Coach Settings

```gdscript
class_name AssistantCoachSettings extends Resource

@export var coach_style: AssistantCoach.CoachStyle = AssistantCoach.CoachStyle.BALANCED
@export var auto_show_on_pick: bool = true  # Automatically show when it's your turn
@export var enabled: bool = true  # Show the "Ask Coach" button

func to_dict() -> Dictionary
static func from_dict(data: Dictionary) -> AssistantCoachSettings
```

### Integration with Draft Day UI

```gdscript
class_name DraftDayUI extends Control

var _assistant_coach: AssistantCoach
var _coach_panel: AssistantCoachPanel
var _settings: AssistantCoachSettings

func _on_your_pick_started(pick_number: int) -> void:
    _draft_ticker.highlight_current_pick()
    _show_pick_notification()

    if _settings.auto_show_on_pick and _settings.enabled:
        _show_assistant_coach()

func _on_ask_coach_pressed() -> void:
    _show_assistant_coach()

func _show_assistant_coach() -> void:
    var available = _get_available_players()
    var recommendations = _assistant_coach.generate_recommendations(
        _current_pick,
        available
    )
    _coach_panel.show_recommendations(recommendations)
    _coach_panel.visible = true

func _on_coach_recommendation_selected(rec: DraftRecommendation) -> void:
    _prospect_table.select_player(rec.player_id)
    _prospect_detail.populate_from_id(rec.player_id)
    _coach_panel.visible = false

func _on_draft_player_confirmed(player_id: String) -> void:
    draft_pick_made.emit(_current_pick, player_id)
    _draft_ticker.add_pick(DraftPick.new(_current_pick, _player_team, player_id))
    _prospect_table.remove_player(player_id)
    _advance_to_next_pick()
```

---

## Mode Switching

The left panel supports multiple modes, similar to email client folder/label switching:

```gdscript
enum LeftPanelMode {
    INBOX,          # Default: Messages + Quick Actions
    LEAGUE,         # League Explorer tree
    DRAFT_BOARD,    # Draft board sidebar (picks, needs, filters)
}
```

**Mode Switching UI**:
```
┌─────────────────────────┐
│ [Inbox] [League] [Draft]│  ← Tab bar at top of left panel
├─────────────────────────┤
│                         │
│  Content changes based  │
│  on selected mode       │
│                         │
└─────────────────────────┘
```

**Keyboard Shortcuts**:
| Key | Mode |
|-----|------|
| `I` | Switch to Inbox |
| `L` | Switch to League Explorer |
| `G` | Switch to Draft Board |

---

## Design Principles

1. **Information Density**: Show maximum relevant info without clutter
2. **Keyboard-First**: Every action accessible via keyboard
3. **Context Preservation**: Navigation stack remembers where you came from
4. **Actionable Items First**: Critical decisions surface to the top
5. **Progressive Disclosure**: Summary in inbox, details on selection
6. **Consistent Patterns**: Same interaction model across all views
7. **Non-Blocking Flow**: Only truly required decisions block advancement
8. **Exploration Freedom**: Browse any team/player without leaving main UI
9. **Planning Tools**: Draft board as active workspace, not just a list
10. **Data Relationships**: Easy navigation between related entities (team → player → stats)
