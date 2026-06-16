---
title: Product Requirements Document (MVP)
last_modified: 2026-06-01
tags:
  - mvp
  - product
  - requirements
  - planning
---

# Product Requirements Document (MVP)

# 1. Vision

Chess Coach helps players improve by automatically analyzing their online chess games, identifying recurring weaknesses, generating personalized training plans, and measuring improvement over time.

The application focuses on helping players eliminate repeated mistakes rather than providing engine-style move recommendations.

The primary outcome is measurable improvement in player performance and rating.

---

# 2. Goals

## Primary Goals

- Connect online chess accounts
- Import recent games
- Analyze games with Stockfish
- Identify recurring weakness patterns
- Generate personalized training plans
- Track improvement over time
- Visualize progress through charts and reports

## Non-Goals

### MVP

- Live game assistance
- Real-time move recommendations
- Opening preparation tools
- Mobile applications
- Multiplayer coaching
- AI chat coaching
- Tournament management

---

# 3. Users

## Registered User

Can:

- Create account
- Connect providers
- Import games
- View analysis
- Complete training plans
- Track progress

## Future Premium User

May receive:

- Multiple active training plans
- Longer analysis history
- Advanced reports
- Additional providers
- Coach sharing

---

# 4. Architecture

## Rails Application

Responsibilities:

- Authentication
- User management
- Provider management
- Dashboard
- Training plans
- Reporting
- Billing (future)

## Python Analysis Service

Responsibilities:

- Game import
- PGN parsing
- Stockfish analysis
- Weakness detection
- Recommendation generation
- Puzzle assignment

## Database

Shared PostgreSQL database.

Stores:

- Users
- Providers
- Games
- Moves
- Evaluations
- Weakness events
- Training plans
- Puzzle assignments
- Progress snapshots

---

# 5. Authentication

## Supported Methods

### Email / Password

Devise

### Google OAuth

OmniAuth

### Lichess OAuth

Supported in MVP.

### Chess.com

MVP:

Username-based import.

Future:

OAuth if supported.

---

# 6. Provider Accounts

Users may connect:

- Lichess
- Chess.com
- Both

Provider source must not affect downstream analysis.

Games become provider-agnostic after import.

---

# 7. Game Import

## Supported Filters

Date Range:

- Last 7 Days
- Last 14 Days
- Last 30 Days

Maximum Import:

- 30 games

Time Controls:

- Bullet
- Blitz
- Rapid
- Classical

## Stored Data

Game:

- Provider
- Provider Game ID
- PGN
- Opening
- Played At
- Result
- Color
- Opponent Rating
- Time Control

---

# 8. Analysis Engine

## Engine

Stockfish

## Analysis Depth

Depth 15

Future:

Configurable.

## Analysis Scope

Analyze:

- Every user move

Ignore:

- Opponent moves for weakness detection

## Time Control Weighting

Classical:

- Weight 1.0

Rapid:

- Weight 1.0

Blitz:

- Weight 0.75

Bullet:

- Weight 0.25

## Stored Evaluation Data

For each user move:

- Position before move
- Position after move
- Best engine move
- Engine evaluation before move
- Engine evaluation after move
- Centipawn loss
- Classification

Classifications:

- Good
- Inaccuracy
- Mistake
- Blunder

---

# 9. Weakness Detection

## Philosophy

A weakness is a recurring pattern across multiple games.

A single mistake does not automatically become a weakness.

## Initial Weakness Themes

1. Hanging Pieces
2. Missed Tactics
3. Ignored Threats
4. Opening Development
5. King Safety
6. Bad Trades
7. Pawn Structure
8. Endgame Technique
9. Time Pressure

## Theme Assignment

Each event may contain:

- Primary Theme
- Secondary Theme

## Weakness Events

Store:

- User
- Game
- Move
- Theme
- Severity
- Explanation
- Phase of game
- Timestamp

---

# 10. Training Plans

## Active Plans

Users may have:

- One active training plan

Future:

- Multiple plans via subscription

## Plan Duration

Default:

- 14 days

Extendable.

## Plan Selection

System recommends:

- Top 3 plans

User selects one.

## Plan Sources

### Personal Positions

Positions extracted from user games.

### Theme Puzzles

Positions pulled from curated puzzle database.

Training plans use both.

## Daily Assignment

- Review 1 personal position
- Solve 5 puzzles
- Play 1 game

## Completion

Manual completion tracking in MVP.

---

# 11. Puzzle System

## Puzzle Sources

### MVP

Curated puzzle database.

### Future

Automatically generated puzzles from user mistakes.

## Puzzle Metadata

- FEN
- Theme
- Difficulty
- Solution
- Source

## Sources

- User Position
- Theme Puzzle

---

# 12. Progress Tracking

## Primary Metric

Rating

Tracked separately for:

- Bullet
- Blitz
- Rapid
- Classical

## Secondary Metrics

- Weakness frequency
- Average centipawn loss
- Blunders per game
- Training completion percentage

## Historical Tracking

Retain all imported games and analysis.

## Analysis Versioning

Store:

- Engine version
- Analysis version

Analysis is immutable.

Historical games are not re-analyzed.

---

# 13. Dashboard

## Summary

Displays:

- Current ratings
- Active training plan
- Recent analysis

## Weakness Report

Displays:

- Top weaknesses
- Severity
- Trend

## Training Plan

Displays:

- Current objective
- Daily assignments
- Progress

## Charts

Rendered with **Chart.js** (importmap + Stimulus `chart_controller`).

### Rating History

By time control.

### Weakness Trend

Occurrences over time.

### Blunders Per Game

Trend over time.

### Average Centipawn Loss

Trend over time.

---

# 14. Chess Board Requirements

Users must be able to:

- View positions
- Step through moves
- Compare played move vs engine move
- Review mistakes
- Solve puzzles

Preferred Stack:

- Rails
- Turbo
- Stimulus
- chess.js
- cm-chessboard

React not required for MVP.

---

# 15. Background Processing

## Job coordination (MVP)

Long-running work (import, analysis, classification, plan generation) is tracked in PostgreSQL as `SystemJob` records. Rails enqueues by inserting rows; the Python worker polls Postgres, claims jobs, and updates status/result/errors. Rails and the UI read job state from the database only—not from Python internals.

Redis is used in MVP for **Sidekiq** (Rails-only async) and **Action Cable**, not as the cross-language work queue.

## Import Job

Imports games.

## Analysis Job

Runs Stockfish.

## Weakness Detection Job

Generates weakness events.

## Training Plan Job

Generates recommendations and assignments.

## Future

- Scheduled imports and automatic analysis
- **Hybrid Redis signaling (optional):** after creating a `SystemJob`, push the job id to Redis so workers wake without tight Postgres polling; claim and lifecycle updates still happen in Postgres (`system_jobs` remains source of truth). Add when scaling workers or reducing DB poll load—not required for Phase 1 MVP

---

# 16. Testing Strategy

## Rails

RSpec

### Unit

- Models
- Services

### Request

- Controllers
- APIs

### System

- User workflows

## Python

Pytest

### Unit

- PGN parser
- Evaluation pipeline
- Weakness classifier

### Integration

- Stockfish

### End-to-End

- PGN → Analysis → Weakness → Training Plan

---

# 17. MVP Success Criteria

A user can:

1. Connect a provider.
2. Import games.
3. Analyze games.
4. View recurring weaknesses.
5. Select a training plan.
6. Complete exercises.
7. Track progress.
8. Demonstrate measurable reduction in targeted weaknesses.

Success is defined as measurable improvement in weakness frequency and rating performance over time.
