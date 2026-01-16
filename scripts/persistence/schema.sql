-- Gridiron Dynasty - SQLite Database Schema
-- Version: 1
-- Generated: 2026-01-15
-- Purpose: Normalized storage for Phase 2 decomposed Player/Team models
--
-- This schema supports efficient querying of player attributes, career history,
-- and team rosters while maintaining referential integrity.

-- =========================
-- Schema Metadata
-- =========================

CREATE TABLE IF NOT EXISTS schema_metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO schema_metadata (key, value) VALUES ('schema_version', '1');
INSERT OR REPLACE INTO schema_metadata (key, value) VALUES ('created_at', datetime('now'));
INSERT OR REPLACE INTO schema_metadata (key, value) VALUES ('description', 'Gridiron Dynasty normalized schema for Player/Team entities');

-- =========================
-- Player Tables
-- =========================

-- Main player entity (extends Person: id, first_name, last_name)
CREATE TABLE IF NOT EXISTS player (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    position TEXT NOT NULL,                -- QB, RB, WR, TE, OL, DL, LB, CB, S, K, P
    age INTEGER NOT NULL,
    stage INTEGER NOT NULL,                -- PlayerStage enum: 0-6
    class_tag TEXT DEFAULT '',             -- e.g., "CLASS_OF_2033"
    jersey_number INTEGER DEFAULT 0,       -- 0 = unassigned
    gen_mode TEXT DEFAULT '',              -- "quota", "gauss", "chaos", etc.
    school_tag TEXT DEFAULT '',            -- Current school identifier
    notes TEXT DEFAULT '',                 -- Debug/scout notes
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_player_position ON player(position);
CREATE INDEX IF NOT EXISTS idx_player_age ON player(age);
CREATE INDEX IF NOT EXISTS idx_player_stage ON player(stage);
CREATE INDEX IF NOT EXISTS idx_player_school ON player(school_tag);
CREATE INDEX IF NOT EXISTS idx_player_class ON player(class_tag);
CREATE INDEX IF NOT EXISTS idx_player_name ON player(last_name, first_name);

-- =========================
-- Player Component Tables
-- =========================

-- PlayerPhysicals component: Physical measurements
CREATE TABLE IF NOT EXISTS player_physicals (
    player_id TEXT PRIMARY KEY,
    height_in REAL NOT NULL DEFAULT 72.0,       -- Height in inches
    weight_lb REAL NOT NULL DEFAULT 200.0,      -- Weight in pounds
    hand_size_in REAL DEFAULT 9.5,              -- Hand size in inches
    arm_length_in REAL DEFAULT 32.0,            -- Arm length in inches
    wingspan_in REAL DEFAULT 78.0,              -- Wingspan in inches
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- CombineResults component: NFL Combine metrics (nullable - player may not have done combine)
CREATE TABLE IF NOT EXISTS player_combine (
    player_id TEXT PRIMARY KEY,
    forty_sec REAL,                         -- 40-yard dash time
    shuttle20_sec REAL,                     -- 20-yard shuttle time
    cone3_sec REAL,                         -- 3-cone drill time
    vertical_in REAL,                       -- Vertical jump height
    broad_in REAL,                          -- Broad jump distance
    bench_225_reps INTEGER,                 -- Bench press reps at 225lb
    wonderlic INTEGER,                      -- Wonderlic test score
    cybex_index REAL,                       -- Injury risk index
    injury_eval TEXT,                       -- Medical evaluation result
    drug_screen TEXT,                       -- Drug screening result
    combine_year INTEGER,                   -- Year combine was performed
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- StatsProfile component: Player ratings (stored as JSON for flexibility)
-- Uses JSON columns to accommodate config-driven stat systems (20-40 stats per player)
CREATE TABLE IF NOT EXISTS player_stats (
    player_id TEXT PRIMARY KEY,
    current_stats TEXT NOT NULL DEFAULT '{}',   -- JSON: {"speed": 85, "strength": 72, ...}
    potential_stats TEXT NOT NULL DEFAULT '{}', -- JSON: {"speed": 92, "strength": 80, ...}
    derived_stats TEXT NOT NULL DEFAULT '{}',   -- JSON: {"overall": 78, "pass_rating": 83, ...}
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- TraitSet component: Player traits (visible and hidden)
CREATE TABLE IF NOT EXISTS player_trait (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL,
    trait_name TEXT NOT NULL,
    is_hidden INTEGER DEFAULT 0,            -- 0=visible, 1=hidden
    UNIQUE(player_id, trait_name),
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_trait_player ON player_trait(player_id);
CREATE INDEX IF NOT EXISTS idx_trait_name ON player_trait(trait_name);

-- Contract component: Player contract details
CREATE TABLE IF NOT EXISTS player_contract (
    player_id TEXT PRIMARY KEY,
    current_year INTEGER DEFAULT 0,
    total_years INTEGER DEFAULT 0,
    annual_value REAL DEFAULT 0.0,
    guaranteed REAL DEFAULT 0.0,
    range_min REAL DEFAULT 0.0,
    range_max REAL DEFAULT 0.0,
    valuation_source TEXT DEFAULT '',
    valuation_seed INTEGER DEFAULT 0,
    source_eval_id TEXT DEFAULT '',
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- Index for finding players with active contracts
CREATE INDEX IF NOT EXISTS idx_contract_active ON player_contract(total_years, current_year);

-- CareerRecord component: Awards, wear, development history (JSON columns)
CREATE TABLE IF NOT EXISTS player_career (
    player_id TEXT PRIMARY KEY,
    awards TEXT NOT NULL DEFAULT '{}',          -- JSON: {"mvp": 0, "opoy": 1, "all_pro_first": 2, ...}
    wear TEXT NOT NULL DEFAULT '{}',            -- JSON: {"snaps": 1500, "collisions": 200, "injury_count": 0}
    development_history TEXT DEFAULT '[]',      -- JSON: [{year: 2025, stat: "speed", gain: 3}, ...]
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

-- HealthStatus component: Injury history
CREATE TABLE IF NOT EXISTS player_injury (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL,
    injury_type TEXT NOT NULL,
    severity REAL NOT NULL,
    week_occurred INTEGER,
    season_year INTEGER,
    is_active INTEGER DEFAULT 1,            -- 0=healed, 1=active injury
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_injury_player ON player_injury(player_id);
CREATE INDEX IF NOT EXISTS idx_injury_active ON player_injury(is_active, player_id);
CREATE INDEX IF NOT EXISTS idx_injury_season ON player_injury(season_year);

-- =========================
-- League Tables
-- =========================

-- League entity (must be defined before team table due to foreign key constraint)
CREATE TABLE IF NOT EXISTS league (
    id TEXT PRIMARY KEY,                    -- "nfl", "college", "high_school"
    name TEXT NOT NULL,
    level INTEGER NOT NULL,                 -- Hierarchy level (0=pro, 1=college, 2=hs)
    salary_cap_enabled INTEGER DEFAULT 0
);

-- Insert default leagues
INSERT OR IGNORE INTO league (id, name, level, salary_cap_enabled) VALUES ('nfl', 'National Football League', 0, 1);
INSERT OR IGNORE INTO league (id, name, level, salary_cap_enabled) VALUES ('college', 'College Football', 1, 0);
INSERT OR IGNORE INTO league (id, name, level, salary_cap_enabled) VALUES ('high_school', 'High School Football', 2, 0);

-- =========================
-- Team Tables
-- =========================

-- Team entity
CREATE TABLE IF NOT EXISTS team (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    abbreviation TEXT DEFAULT '',
    league_level TEXT DEFAULT 'nfl',        -- "nfl", "college", "high_school"
    conference TEXT DEFAULT '',             -- Conference affiliation
    division TEXT DEFAULT '',               -- Division within conference
    offensive_scheme TEXT DEFAULT '',
    defensive_scheme TEXT DEFAULT '',
    cap_limit REAL DEFAULT 0.0,             -- Salary cap limit
    is_user_controlled INTEGER DEFAULT 0,   -- 0=CPU, 1=user-controlled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (league_level) REFERENCES league(id) ON DELETE SET DEFAULT
);

CREATE INDEX IF NOT EXISTS idx_team_league ON team(league_level);
CREATE INDEX IF NOT EXISTS idx_team_user ON team(is_user_controlled);

-- =========================
-- Roster Tables
-- =========================

-- RosterEntry: Team-Player membership (many-to-many join table)
CREATE TABLE IF NOT EXISTS roster_entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    team_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    status INTEGER NOT NULL DEFAULT 0,      -- RosterStatus enum: 0=ACTIVE, 1=PRACTICE_SQUAD, 2=IR, 3=SUSPENDED
    cap_exempt INTEGER DEFAULT 0,           -- 0=counts against cap, 1=cap-exempt
    cap_exempt_reason TEXT DEFAULT '',      -- Reason for cap exemption (e.g., "IR exception")
    ir_eligible_week INTEGER DEFAULT 0,     -- Week when player can return from IR (0=not on IR)
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(team_id, player_id),
    FOREIGN KEY (team_id) REFERENCES team(id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_roster_team ON roster_entry(team_id);
CREATE INDEX IF NOT EXISTS idx_roster_player ON roster_entry(player_id);
CREATE INDEX IF NOT EXISTS idx_roster_status ON roster_entry(status);

-- RosterContract: Cap accounting for rostered players
CREATE TABLE IF NOT EXISTS roster_contract (
    roster_entry_id INTEGER PRIMARY KEY,
    base_salary REAL DEFAULT 0.0,
    signing_bonus_proration REAL DEFAULT 0.0,
    guaranteed REAL DEFAULT 0.0,
    incentives REAL DEFAULT 0.0,
    dead_money REAL DEFAULT 0.0,            -- Dead cap charge (excluded from active cap)
    FOREIGN KEY (roster_entry_id) REFERENCES roster_entry(id) ON DELETE CASCADE
);

-- =========================
-- Historical Data Tables (Future)
-- =========================

-- Player career statistics by season (for historical tracking)
CREATE TABLE IF NOT EXISTS player_season_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    player_id TEXT NOT NULL,
    season_year INTEGER NOT NULL,
    team_id TEXT,
    games_played INTEGER DEFAULT 0,
    stats_json TEXT DEFAULT '{}',           -- JSON: Position-specific stats
    UNIQUE(player_id, season_year),
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE,
    FOREIGN KEY (team_id) REFERENCES team(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_season_stats_player ON player_season_stats(player_id);
CREATE INDEX IF NOT EXISTS idx_season_stats_year ON player_season_stats(season_year);

-- =========================
-- Draft History (Future)
-- =========================

CREATE TABLE IF NOT EXISTS draft_pick (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    draft_year INTEGER NOT NULL,
    round INTEGER NOT NULL,
    pick INTEGER NOT NULL,
    team_id TEXT NOT NULL,
    player_id TEXT,                         -- NULL if pick not yet used
    traded_from_team TEXT,                  -- Original team if pick was traded
    UNIQUE(draft_year, round, pick),
    FOREIGN KEY (team_id) REFERENCES team(id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_draft_year ON draft_pick(draft_year);
CREATE INDEX IF NOT EXISTS idx_draft_team ON draft_pick(team_id);
CREATE INDEX IF NOT EXISTS idx_draft_player ON draft_pick(player_id);

-- =========================
-- Performance Indexes (ARCH-022)
-- =========================
-- Additional composite and filtered indexes for common query patterns
-- Designed to optimize the queries documented in DATABASE_SCHEMA.md

-- Composite index for position + age queries (draft scouting, roster building)
-- Example: Find all QBs aged 21-25
CREATE INDEX IF NOT EXISTS idx_player_position_age ON player(position, age);

-- Composite index for position + stage queries (find NFL veterans by position)
-- Example: Find all active NFL QBs
CREATE INDEX IF NOT EXISTS idx_player_position_stage ON player(position, stage);

-- Composite index for stage + age (draft pool queries, retirement candidates)
-- Example: Find draft-eligible players by age, find aging veterans
CREATE INDEX IF NOT EXISTS idx_player_stage_age ON player(stage, age);

-- Filtered index for free agent queries (NFL_FREE_AGENT = stage 5)
-- SQLite doesn't support true partial indexes in CREATE INDEX,
-- but we can use a covering index that benefits free agent lookups
CREATE INDEX IF NOT EXISTS idx_player_free_agent ON player(stage, position, age) WHERE stage = 5;

-- Composite index for team roster with position (depth chart queries)
-- Example: Load all WRs on a specific team
CREATE INDEX IF NOT EXISTS idx_roster_team_status ON roster_entry(team_id, status);

-- Index for finding expiring contracts (contract year queries)
-- Example: Find players in final year of contract
CREATE INDEX IF NOT EXISTS idx_contract_expiring ON player_contract(current_year, total_years);

-- Index for contract value queries (cap management, free agent market)
CREATE INDEX IF NOT EXISTS idx_contract_value ON player_contract(annual_value);

-- Index for combine queries (draft evaluation, athleticism filtering)
CREATE INDEX IF NOT EXISTS idx_combine_forty ON player_combine(forty_sec);
CREATE INDEX IF NOT EXISTS idx_combine_year ON player_combine(combine_year);

-- Team indexes for division/conference queries (standings, schedules)
CREATE INDEX IF NOT EXISTS idx_team_conference ON team(conference);
CREATE INDEX IF NOT EXISTS idx_team_division ON team(division);
CREATE INDEX IF NOT EXISTS idx_team_conf_div ON team(conference, division);

-- =========================
-- Schema Validation Queries
-- =========================

-- Query to verify schema version
-- SELECT value FROM schema_metadata WHERE key = 'schema_version';

-- Query to count all tables
-- SELECT COUNT(*) FROM sqlite_master WHERE type='table';

-- Query to verify referential integrity
-- PRAGMA foreign_keys = ON;
-- PRAGMA foreign_key_check;
