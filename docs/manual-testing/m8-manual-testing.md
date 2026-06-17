---
title: M8 manual testing checklist
last_modified: 2026-06-17
tags:
  - development
  - testing
  - chess-board
  - milestone-8
---

# M8 manual testing checklist

Use this checklist for final confirmation before merging **Milestone 8: Chess board UI**. It complements automated tests (`make test`) with browser checks for cm-chessboard rendering, move stepping, puzzle input, and training assignment play flows.

Related docs:

- [make-commands.md](../development/make-commands.md) — `make test`, `make stack-up`, worker scaling
- [README.md](README.md) — index of all milestone checklists
- [m6-manual-testing.md](m6-manual-testing.md) — training plans (prerequisite)
- [m7-manual-testing.md](m7-manual-testing.md) — dashboard and progress tracking

**PRD checkpoint:** User can view positions, step through games, compare played vs engine moves, review mistakes, and solve puzzles.

---

## Prerequisites

```bash
cp .env.example .env          # if not done already
bin/rails db:seed             # development only
bin/dev                         # Rails + Tailwind + Sidekiq
```

Sign in as **`starship@example.com`** / **`skyd!ve`** (from `db/seeds/01_users.rb`).

---

## 1. Automated suite (CI gate)

```bash
make test
```

**Pass:** 0 failures.

---

## 2. Game review board

| #   | Step                                                   | Expected                                                           |
| --- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| 2.1 | Open **Games** → select a game with completed analysis | Game detail loads with board on the left                           |
| 2.2 | Click **Next →** through several moves                 | Board updates to match each position                               |
| 2.3 | Click a row in the move table                          | Board jumps to that move                                           |
| 2.4 | On a classified user move                              | Comparison panel shows played move, best move, classification, CPL |
| 2.5 | On a classified user move                              | Red arrow = played move, green arrow = engine best                 |
| 2.6 | Click **Mistake** filter, then **Next mistake →**      | Board jumps between user inaccuracies/mistakes/blunders            |
| 2.7 | Use keyboard **←** / **→**                             | Board steps backward/forward                                       |

---

## 3. Weakness deep links

| #   | Step                                                 | Expected                                                      |
| --- | ---------------------------------------------------- | ------------------------------------------------------------- |
| 3.1 | Open **Weaknesses** → pick a cycle with linked moves | Weakness detail loads                                         |
| 3.2 | Click a linked move                                  | Game detail opens at that ply with board positioned correctly |

---

## 4. Puzzle assignments

| #   | Step                                                        | Expected                                                                           |
| --- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| 4.1 | Open **Training** → **Today** → **Start** on a theme puzzle | Puzzle play page with interactive board                                            |
| 4.2 | Click **Hint**                                              | Hint text appears; starting square is highlighted on the board; **Hint** disables  |
| 4.3 | Play the wrong move                                         | Wrong move stays on board; status shows incorrect message; **Try again** appears   |
| 4.4 | Click **Try again**                                         | Board resets to start; hint clears and **Hint** is available again                 |
| 4.5 | Play the correct first move                                 | Opponent reply auto-plays (if multi-move solution)                                 |
| 4.6 | Complete the full solution line                             | Status shows green "Puzzle solved!"; **Skip** becomes **Complete** (filled button) |
| 4.7 | Click **Complete**                                          | Assignment marked complete; returns to today view                                  |

---

## 5. Personal position review

| #   | Step                                            | Expected                                         |
| --- | ----------------------------------------------- | ------------------------------------------------ |
| 5.1 | **Start** a personal position review assignment | Board shows the position before your mistake; no played/best arrows or comparison panel yet |
| 5.2 | Play the wrong move                               | Status shows incorrect message; **Try again** appears; answer still hidden                 |
| 5.3 | Click **Try again**                               | Board resets to the starting position                                                      |
| 5.4 | Click **Hint**                                    | Hint mentions your in-game move and classification; no best-move arrow                      |
| 5.5 | Play the engine best move                         | Status shows **Correct!**; your move stays on the board; comparison panel appears |
| 5.6 | Click **Complete**                                | Assignment marked complete; returns to today view                                          |
| 5.7 | Click **View full game at this move**             | Game detail opens at the correct ply                                                       |

---

## 6. Regression checks

| #   | Step                                                  | Expected                                                                         |
| --- | ----------------------------------------------------- | -------------------------------------------------------------------------------- |
| 6.1 | Open a **play game** or **habit exercise** assignment | Text prompt only; no chess board                                                 |
| 6.2 | Open dashboard charts                                 | Charts still render (no JS errors from new imports)                              |
| 6.3 | Hard-refresh a game page                              | Board pieces and squares render (sprites/CSS load from `/cm-chessboard/assets/`) |

---

## Sign-off

- [ ] Game review: step moves, mistake jump, played vs best
- [ ] Weakness move links open game at ply
- [ ] Puzzle solve with auto-replies and completion
- [ ] Personal position review
- [ ] Non-board assignments unchanged
- [ ] `make test` green
