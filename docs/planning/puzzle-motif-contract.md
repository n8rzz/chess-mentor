---
title: Puzzle Motif & Game Phase — Database Contract
last_modified: 2026-06-05
tags:
  - puzzle
  - weakness
  - contract
  - planning
---

# Puzzle Motif & Game Phase — Database Contract

Rails and Python workers read/write integer-backed enums on `puzzles.motif` and `weakness_events.phase`. Use the string keys below in application code; persist integers in SQL.

## Puzzle motif enum (`puzzles.motif`)

| Integer | String                 |
| ------- | ---------------------- |
| 0       | `fork`                 |
| 1       | `pin`                  |
| 2       | `skewer`               |
| 3       | `double_attack`        |
| 4       | `discovered_attack`    |
| 5       | `discovered_check`     |
| 6       | `back_rank_mate`       |
| 7       | `removal_of_defender`  |
| 8       | `deflection`           |
| 9       | `decoy`                |
| 10      | `overloaded_piece`     |
| 11      | `zwischenzug`          |
| 12      | `mate_threat`          |
| 13      | `undefended_piece`     |
| 14      | `sacrifice`            |
| 15      | `piece_activity`       |
| 16      | `center_control`       |
| 17      | `exposed_king`         |
| 18      | `castling_break`       |
| 19      | `material_loss`        |
| 20      | `isolated_pawn`        |
| 21      | `passed_pawn`          |
| 22      | `king_and_pawn`        |
| 23      | `opposition`           |
| 24      | `one_move_win`         |
| 25      | `forcing_line`         |

Source of truth: `PuzzleMotifable::MOTIFS` in [`app/models/concerns/puzzle_motifable.rb`](../../app/models/concerns/puzzle_motifable.rb).

## Game phase enum (`weakness_events.phase`)

| Integer | String        |
| ------- | ------------- |
| 0       | `opening`     |
| 1       | `middlegame`  |
| 2       | `endgame`     |

Source of truth: `GamePhaseable::PHASES` in [`app/models/concerns/game_phaseable.rb`](../../app/models/concerns/game_phaseable.rb).

## Notes

- `WeaknessEvent#explanation_key` remains a free-form string (versioned i18n key).
- Align tactical motifs with [evaluation-engine §11](evaluation-engine.md); game phases with [evaluation-engine §15](evaluation-engine.md).
