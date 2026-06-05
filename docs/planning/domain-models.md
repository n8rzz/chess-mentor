---
title: Domain Models
last_modified: 2026-06-01
tags:
  - architecture
  - domain
  - data-model
  - planning
---

# 1. Overview

This document defines the core domain objects for Chess Coach.

The application is Rails-managed. Rails owns:

- Database schema
- Migrations
- Seeds
- Authentication
- UI
- Job orchestration
- Workflow state

Python services consume work from the shared database and write structured results back.

Python owns:

- PGN parsing
- Stockfish evaluation
- Candidate event generation
- Weakness classification
- Training plan generation logic, where applicable

Python does not own schema migrations.

---

# 2. Core Domains

The product is organized around these domains:

1. Users and Provider Accounts
2. Imports
3. Games and Moves
4. Evaluation
5. Weaknesses
6. Training Plans
7. Puzzles
8. Progress Tracking
9. Jobs and Workflow State

---

# 3. User

Represents an application account.

## Responsibilities

- Own connected provider accounts
- Own imported games
- Own weaknesses
- Own training plans
- Own progress history

## Relationships

- Has many provider accounts
- Has many import batches
- Has many games
- Has many weakness cycles
- Has many training plans

---

# 4. ProviderAccount

Represents a connected chess identity.

Examples:

- Lichess account
- Chess.com username

## Responsibilities

- Store provider identity
- Store OAuth tokens when applicable
- Track provider import status
- Prevent duplicate connections

## Fields

- user_id
- provider
- provider_username
- provider_user_id
- access_token
- refresh_token
- token_expires_at
- last_imported_at
- status

## Notes

Chess.com may initially be username-only.

Lichess supports OAuth.

---

# 5. ImportBatch

Represents a single import attempt.

This is required so the system can answer:

- What imports have happened?
- Is an import currently running?
- Did the import succeed?
- Did it partially fail?
- What errors occurred?

## Responsibilities

- Track import lifecycle
- Store import filters
- Store progress
- Store summary results
- Store error details

## States

- pending
- running
- succeeded
- partially_succeeded
- failed
- cancelled

## Fields

- user_id
- provider_account_id
- provider
- status
- requested_since
- requested_until
- max_games
- time_controls
- started_at
- finished_at
- games_found_count
- games_imported_count
- games_skipped_count
- games_failed_count
- error_message
- error_details
- metadata

## Relationships

- Belongs to user
- Belongs to provider account
- Has many import records
- Has many games

---

# 6. ImportRecord

Represents the import result for a single provider game.

## Responsibilities

- Track per-game import status
- Prevent duplicate imports
- Capture per-game errors

## States

- pending
- imported
- skipped
- failed

## Fields

- import_batch_id
- provider
- provider_game_id
- status
- game_id
- error_message
- metadata

## Relationships

- Belongs to import batch
- Optionally belongs to game

---

# 7. Game

Represents a normalized chess game.

After import, games are provider-agnostic.

## Responsibilities

- Store game metadata
- Store PGN
- Connect provider source to normalized analysis
- Serve as root object for moves and evaluations

## Fields

- user_id
- provider_account_id
- import_batch_id
- provider
- provider_game_id
- pgn
- played_at
- user_color
- result
- time_control
- time_class
- opening_name
- opening_eco
- user_rating
- opponent_rating
- opponent_username
- metadata

## Relationships

- Belongs to user
- Belongs to provider account
- Belongs to import batch
- Has many moves
- Has many analysis runs
- Has many weakness events

---

# 8. Move

Represents a move in a game.

## Responsibilities

- Store move notation
- Store board positions before and after
- Identify whether move was made by the user

## Fields

- game_id
- ply
- move_number
- color
- san
- uci
- fen_before
- fen_after
- played_by_user
- clock_before
- clock_after

## Relationships

- Belongs to game
- Has one move evaluation
- Has many candidate events
- Has many weakness events

---

# 9. AnalysisRun

Represents a full evaluation pass for a game.

## Responsibilities

- Track analysis lifecycle
- Store engine configuration
- Store versioning
- Track errors

## States

- pending
- running
- succeeded
- partially_succeeded
- failed
- cancelled

## Fields

- game_id
- user_id
- status
- engine_name
- engine_version
- analysis_version
- depth
- started_at
- finished_at
- error_message
- error_details
- metadata

## Relationships

- Belongs to game
- Has many move evaluations
- Has many candidate events

---

# 10. MoveEvaluation

Represents Stockfish evaluation for a user move.

## Responsibilities

- Store objective engine analysis
- Store centipawn loss
- Store best move
- Store classification

## Fields

- analysis_run_id
- game_id
- move_id
- eval_before_cp
- eval_after_cp
- centipawn_loss
- best_move_uci
- best_move_san
- principal_variation
- classification
- mate_before
- mate_after
- depth
- metadata

## Classifications

- good
- inaccuracy
- mistake
- blunder

---

# 11. CandidateEvent

Represents objective evidence produced by the Evaluation Engine.

Candidate events are not weaknesses yet.

## Examples

- Material loss
- Tactical opportunity
- Threat present
- King exposure
- Pawn structure signal
- Time pressure signal

## Fields

- analysis_run_id
- game_id
- move_id
- event_type
- severity
- confidence
- metadata

## Relationships

- Belongs to analysis run
- Belongs to game
- Belongs to move

---

# 12. WeaknessEvent

Represents a classified weakness occurrence.

## Responsibilities

- Convert candidate evidence into player-facing weakness signals
- Store theme and severity
- Connect weaknesses to specific game positions

## Fields

- user_id
- game_id
- move_id
- weakness_cycle_id
- primary_theme
- secondary_theme
- severity
- phase (enum: `opening`, `middlegame`, `endgame`)
- occurred_under_time_pressure
- explanation_key (string — versioned i18n key, not an enum)
- metadata

## Phases

- opening
- middlegame
- endgame

## Themes

- hanging_pieces
- missed_tactics
- ignored_threats
- opening_development
- king_safety
- bad_trades
- pawn_structure
- endgame_technique
- time_pressure

# 13. WeaknessCycle

Represents an active or historical period of a weakness.

A weakness may recur across multiple cycles.

## Responsibilities

- Track weakness lifecycle
- Store baseline and current metrics
- Support reappearing weaknesses

## States

- detected
- active
- improving
- managed
- archived

## Fields

- user_id
- theme
- status
- cycle_number
- baseline_occurrences
- current_occurrences
- baseline_severity
- current_severity
- improvement_percentage
- detection_window_games
- detection_window_days
- started_at
- ended_at
- metadata

## Relationships

- Belongs to user
- Has many weakness events
- Has many training plans

---

# 14. TrainingPlan

Represents a focused improvement plan.

## Responsibilities

- Target one weakness cycle
- Track progress
- Group assignments
- Support one active plan per user in MVP

## States

- recommended
- active
- paused
- improving
- managed
- completed
- archived

## Fields

- user_id
- weakness_cycle_id
- theme
- status
- starts_at
- ends_at
- completed_at
- improvement_threshold
- managed_threshold
- baseline_occurrences
- current_occurrences
- progress_percentage
- metadata

## Relationships

- Belongs to user
- Belongs to weakness cycle
- Has many training assignments

---

# 15. TrainingAssignment

Represents a task inside a training plan.

## Assignment Types

- personal_position_review
- theme_puzzle
- play_game
- habit_exercise

## States

- pending
- completed
- skipped

## Fields

- training_plan_id
- assignment_type
- status
- due_on
- completed_at
- source_game_id
- source_move_id
- puzzle_id
- prompt
- metadata

---

# 16. Puzzle

Represents a curated or generated puzzle.

## Sources

- curated
- user_generated

## Fields

- source
- fen
- solution
- theme
- motif (enum — see [puzzle-motif-contract.md](puzzle-motif-contract.md))
- rating
- difficulty
- metadata

## Motifs

Tactical and positional motifs for curated puzzles. Integer-backed enum; full list in [puzzle-motif-contract.md](puzzle-motif-contract.md). Examples: `fork`, `pin`, `discovered_attack`, `back_rank_mate`, `passed_pawn`, `opposition`.

## Relationships

- Has many training assignments

---

# 17. ProgressSnapshot

Represents a point-in-time progress measurement.

## Responsibilities

- Track rating
- Track weakness frequency
- Track plan progress
- Support charts

## Fields

- user_id
- training_plan_id
- weakness_cycle_id
- time_class
- rating
- weakness_frequency
- weakness_severity
- blunders_per_game
- average_centipawn_loss
- games_analyzed_count
- snapshot_at
- metadata

---

# 18. SystemJob

Optional Rails-managed work queue abstraction.

This may wrap Active Job, Sidekiq, or Python worker coordination. MVP uses Postgres polling; optional Redis wake-up (job id signal only) is post–Phase 1—see PRD §15 and [todo.md](../todo.md) out-of-scope list.

## Responsibilities

- Track work assigned to Python
- Track status
- Track retry/error state
- Provide UI visibility into processing

## Job Types

- import_games
- analyze_game
- classify_weaknesses
- generate_training_plan
- update_progress_snapshots

## States

- pending
- claimed
- processing
- succeeded
- failed
- cancelled

## Fields

- user_id
- job_type
- status
- payload
- result
- error_message
- error_details
- claimed_by
- attempts_count
- started_at
- finished_at

---

# 19. Workflow: Import Games

1. User requests import.
2. Rails creates ImportBatch.
3. Rails creates SystemJob with job_type import_games.
4. Python worker claims job.
5. Python imports provider games.
6. Python creates ImportRecords.
7. Python creates or skips Games.
8. Python updates ImportBatch counts and status.
9. Rails UI shows result.

---

# 20. Workflow: Analyze Games

1. Rails creates AnalysisRun for each imported game.
2. Rails creates SystemJob with job_type analyze_game.
3. Python worker claims job.
4. Python parses PGN.
5. Python creates Moves.
6. Python creates MoveEvaluations.
7. Python creates CandidateEvents.
8. Python marks AnalysisRun succeeded or failed.
9. Rails UI displays analysis status.

---

# 21. Workflow: Classify Weaknesses

1. Rails or Python creates classification job.
2. Python reads CandidateEvents and MoveEvaluations.
3. Python creates WeaknessEvents.
4. Python updates or creates WeaknessCycles.
5. Python stores severity and lifecycle status.
6. Rails UI displays weakness report.

---

# 22. Workflow: Generate Training Plan

1. User chooses from recommended weakness cycles.
2. Rails creates TrainingPlan.
3. Rails creates SystemJob with job_type generate_training_plan.
4. Python selects personal positions and theme puzzles.
5. Python creates TrainingAssignments.
6. Rails UI displays active plan.

---

# 23. Workflow Ownership

## Rails Owns

- Schema
- Migrations
- Seeds
- Authentication
- UI
- User actions
- Workflow state
- Job creation
- Billing
- Admin tools

## Python Owns

- Provider import execution
- PGN parsing
- Stockfish calls
- Evaluation
- Candidate event generation
- Weakness classification
- Training assignment selection

## Shared Responsibility

- Database contract
- Status transitions
- Error structures
- Versioning

---

# 24. Key Design Principle

Python services should be replaceable.

Rails should not depend on Python internals.

Rails depends only on:

- Database records
- Status fields
- Result artifacts
- Error messages

This keeps the product manageable and makes testing easier.

---

# 25. MVP Domain Success Criteria

The domain model succeeds if the system can answer:

1. Who is the user?
2. Which providers are connected?
3. What imports have happened?
4. Is an import currently running?
5. Did an import succeed or fail?
6. Which games were imported?
7. Which games were analyzed?
8. What did Stockfish find?
9. What weaknesses were detected?
10. Which weakness is being trained?
11. What assignments are due?
12. Is the user improving?
