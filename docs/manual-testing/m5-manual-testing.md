---
title: M5 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - weaknesses
  - classifier
  - milestone-5
---

# M5 manual testing checklist

Use this checklist for **Milestone 5: Weakness classifier** — recurring weakness cycles, severity/trend, linked games and moves.

Prerequisites: [m4-manual-testing.md](m4-manual-testing.md) (analyzed games with candidate events).

Related docs:

- [weakness-classifier-engine.md](../weakness-classifier-engine.md)
- [make-commands.md](../development/make-commands.md)

**PRD checkpoint:** User can view recurring weaknesses.

---

## Prerequisites

```bash
docker compose up -d db redis
make stack-up
bin/rails db:seed
bin/dev
```

Sign in as **`starship@example.com`** / **`skyd!ve`**.

Demo weakness data from `06_demo_weaknesses.rb` (no classifier run required for §2). Live path requires successful `analyze_game` then `classify_weaknesses`.

---

## 1. Automated suite (CI gate)

```bash
make test
```

M5-relevant specs:

- `spec/requests/weaknesses_spec.rb`
- `spec/requests/dashboard_spec.rb` (weaknesses card)
- `spec/integration/weakness_pipeline_spec.rb` (pending without Stockfish)
- `analysis/tests/test_weakness_*.py`, `test_classify_*.py`

---

## 2. Weaknesses index (demo seed, offline)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | Open **Weaknesses** (`/weaknesses`) | Multiple cycles with theme labels (e.g. Missed tactics, King safety) |
| 2.2 | Each row | Severity, games affected / window, status |
| 2.3 | Dashboard **Recurring weaknesses** card | Top cycles with links to detail |

---

## 3. Weakness detail (demo seed, offline)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | Open a weakness cycle | Theme, status, severity, frequency/trend |
| 3.2 | Linked events | Games (opponent username), moves (SAN), phase |
| 3.3 | Click through to game | Game detail loads (M4) |

---

## 4. Empty state

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | Sign in as **new user** with no analysis | Weaknesses index: _“No recurring weaknesses detected yet”_ |
| 4.2 | Dashboard | Weaknesses empty-state copy |

---

## 5. Live worker path — classify after analysis

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | Import + analyze a game (M3–M4) | `classify_weaknesses` job enqueued after analysis succeeds (deduped) |
| 5.2 | Wait for worker | Job **succeeded** |
| 5.3 | Refresh **Weaknesses** | New or updated `WeaknessCycle` rows |
| 5.4 | Open cycle detail | `WeaknessEvent`s linked to game/move |

**If cycles never appear:** confirm candidate events exist; check classifier logs; detection window may need multiple games with same theme.

---

## 6. Authorization

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | Second user opens another user's weakness URL | **404** |
| 6.2 | Weaknesses list | Only current user's cycles |

---

## Minimum bar before merge

1. `make test` green
2. Demo seed: weaknesses index + detail with linked games/moves
3. Dashboard shows top weaknesses for starship
4. Live: analyze game → classify → weakness appears (optional if demo seed sufficient)
5. Empty user sees empty state

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| Weaknesses index + detail | Yes | `spec/requests/weaknesses_spec.rb` |
| Dashboard weaknesses card | Yes | `spec/requests/dashboard_spec.rb` |
| Per-theme classifier rules | Yes | Python unit tests |
| Determinism | Yes | Python tests |
| Analysis → classify integration | Partial | `weakness_pipeline_spec` (skips without Stockfish) |
| Worker queue `classify_weaknesses` E2E | **No** | Manual / pipeline subprocess |
| Severity trend visual accuracy | **No** | Manual spot-check |

---

## Out of scope (M5)

- Training plan recommendations (M6)
- Opening family performance in plans
- Board UI for mistake positions (M8)
