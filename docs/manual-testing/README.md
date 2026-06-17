---
title: Manual testing checklists
last_modified: 2026-06-16
tags:
  - development
  - testing
  - manual-testing
---

# Manual testing checklists

Pre-merge smoke tests for completed Phase 1 milestones. Each doc complements `make test` with checks that are hard to automate: OAuth flows, Docker workers, async jobs, and full UI composition.

Shared setup: [make-commands.md](../development/make-commands.md).

| Milestone           | Doc                                                                                | PRD checkpoint                    |
| ------------------- | ---------------------------------------------------------------------------------- | --------------------------------- |
| M0 — Foundation     | [m0-manual-testing.md](m0-manual-testing.md)                                       | App boots; workers claim jobs     |
| M1 — Auth & OAuth   | [m1-manual-testing.md](m1-manual-testing.md)                                       | Sign in; connect Lichess          |
| M2 — Domain schema  | [m2-manual-testing.md](m2-manual-testing.md)                                       | DB answers domain-model questions |
| M2.5 — Motif enums  | [m2-manual-testing.md](m2-manual-testing.md#25-puzzle-motifs-and-game-phase-enums) | (section in M2 doc)               |
| M3 — Import         | [m3-manual-testing.md](m3-manual-testing.md)                                       | Connect provider; import games    |
| M4 — Evaluation     | [m4-manual-testing.md](m4-manual-testing.md)                                       | Analyze imported games            |
| M5 — Classifier     | [m5-manual-testing.md](m5-manual-testing.md)                                       | View recurring weaknesses         |
| M6 — Training plans | [m6-manual-testing.md](m6-manual-testing.md)                                       | Select plan; complete exercises   |
| M7 — Dashboard      | [m7-manual-testing.md](m7-manual-testing.md)                                       | Track progress over time          |
| M8 — Chess board UI | [m8-manual-testing.md](m8-manual-testing.md)                                       | Interactive board in review/training |
