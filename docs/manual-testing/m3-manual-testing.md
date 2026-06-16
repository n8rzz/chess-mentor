---
title: M3 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - import
  - milestone-3
---

# M3 manual testing checklist

Use this checklist for **Milestone 3: Provider accounts & game import** — connect Lichess, request imports, track batch status, and verify worker execution.

Prerequisites: [m1-manual-testing.md](m1-manual-testing.md) (auth + OAuth).

Related docs:

- [system-job-contract.md](../planning/system-job-contract.md)
- [make-commands.md](../development/make-commands.md)

**PRD checkpoint:** User can connect a provider and import games.

---

## Prerequisites

```bash
cp .env.example .env
docker compose up -d db redis
make stack-up
bin/rails db:seed
bin/dev
```

Sign in as **`starship@example.com`** / **`skyd!ve`**. Seeds `03`–`04` create demo games and import batches when Lichess is linked.

For a **live import**, connect a real Lichess account with recent blitz/rapid games.

---

## 1. Automated suite (CI gate)

```bash
make test
```

M3-relevant specs:

- `spec/requests/settings/providers_spec.rb`
- `spec/requests/import_batches_spec.rb`
- `spec/services/import_batches/create_spec.rb`
- `spec/services/provider_accounts/disconnect_spec.rb`
- `analysis/tests/test_import_*.py` (API parsing, handler)

---

## 2. Provider settings (demo seed / offline)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | Open **Settings → Providers** (`/settings/providers`) | Page loads |
| 2.2 | If Lichess connected (seed `03`) | Shows **@username** and **Disconnect** |
| 2.3 | If not connected | **Connect Lichess** button |

---

## 3. Import UI — demo batches (offline)

Seeds in `04_import_scenarios.rb` provide succeeded, failed, partial, and running batches.

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | Open **Imports** (`/import_batches`) | List of batches with statuses and counts |
| 3.2 | Open a **succeeded** batch | Status, game counts, link to games |
| 3.3 | Open a **failed** batch | Error message visible |
| 3.4 | Open a **partially_succeeded** batch | Imported + failed counts |
| 3.5 | Open **New import** without Lichess | Redirect to providers with alert |

---

## 4. Start import (form)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | With Lichess connected, open **New import** | Form: days (7/14/30), time controls, max games (≤30) |
| 4.2 | Submit valid import | Redirect to batch show; status **pending** or **running** |
| 4.3 | Submit while import already running | Alert; no duplicate batch |

---

## 5. Live worker path

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | Start import (step 4.2) with worker running | Batch progresses to **running** → **succeeded** (or partial/failed with message) |
| 5.2 | Check `system_jobs` | `import_games` job reaches **succeeded** |
| 5.3 | Open **Games** (`/games`) | New games listed with opponent, date, result |
| 5.4 | Return to import batch show | Counts match imported games |
| 5.5 | After success | `analyze_game` jobs enqueued (M4 — games may show “queued for analysis”) |

**If import stalls:** `docker compose logs worker`, verify Lichess token valid, Redis/DB up.

---

## 6. Disconnect provider

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | **Disconnect** when no import running | Account removed; connect prompt returns |
| 6.2 | **Disconnect** during running import | Alert; account remains |

---

## 7. Authorization

| Step | Action | Expected |
| ---- | ------ | -------- |
| 7.1 | Second user opens another user's import URL | **404** |
| 7.2 | Unauthenticated `/import_batches` | Redirect to sign-in |

---

## Minimum bar before merge

1. `make test` green
2. Demo seed: import list + batch detail pages render
3. Live: connect Lichess → start import → worker completes → games appear
4. Cannot disconnect during active import

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| Providers connect/disconnect | Yes | Request + service specs |
| Import form + create | Yes | Request + `ImportBatches::Create` |
| Duplicate import guard | Yes | Request spec |
| Import status page | Yes | Request spec |
| Lichess API parsing | Yes | Python unit tests |
| Live Lichess API import | **No** | Manual with real token |
| Worker drains `import_games` via Docker | Partial | Python handler tests; not full compose E2E |
| Analysis enqueue after import | Partial | `BulkEnqueueForImport` specs |

---

## Out of scope (M3)

- Chess.com import
- Scheduled/automatic imports
- Analysis results UI (M4)
