---
title: M0 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - foundation
  - milestone-0
---

# M0 manual testing checklist

Use this checklist when validating **Milestone 0: Foundation & shared infrastructure** — Rails bootstrap, Docker, Redis, Sidekiq, Devise, RSpec stack, ULIDs, and the Python worker loop.

Related docs:

- [system-job-contract.md](../planning/system-job-contract.md) — job status enums and worker contract
- [make-commands.md](../development/make-commands.md) — `make test`, `make stack-up`

**Checkpoint:** App boots locally; Postgres-backed `SystemJob` queue is claimable by Python workers.

---

## Prerequisites

```bash
cp .env.example .env
cp .env.worker.example .env.worker
docker compose up -d db redis
bundle install
cd analysis && pip install -r requirements.txt   # if not already
bin/rails db:prepare
```

---

## 1. Automated suite (CI gate)

```bash
make test
```

**Pass:** 0 failures (Stockfish integration specs may be pending without a local binary).

M0-relevant specs:

- `spec/requests/health_check_spec.rb`
- `spec/models/system_job_spec.rb`
- `spec/integration/system_job_worker_contract_spec.rb`
- `spec/models/application_record_spec.rb` (ULID)
- `spec/models/user_spec.rb`
- `spec/lib/active_job_adapter_spec.rb`
- `spec/system/user_authentication_spec.rb`
- `spec/system/health_check_spec.rb`

---

## 2. App boot and health

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | `bin/dev` (or `bin/rails server`) | Rails starts without errors |
| 2.2 | `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/up` | `200` |
| 2.3 | Visit `/` while signed out | Public landing page loads |
| 2.4 | Visit `/dashboard` while signed out | Redirect to sign-in |

---

## 3. Devise and email auth

| Step | Action | Expected |
| ---- | ------ | -------- |
| 3.1 | **Sign up** with new email/username/password | Lands on `/dashboard`; header shows signed-in user |
| 3.2 | Check letter_opener (dev) or mail delivery | Confirmation email sent |
| 3.3 | Click **Confirm my account** in email | Account confirmed |
| 3.4 | **Sign out** | Returns to public `/`; dashboard requires sign-in |
| 3.5 | **Sign in** with confirmed account | Dashboard loads |

Demo shortcut: `starship@example.com` / `skyd!ve` after `bin/rails db:seed`.

---

## 4. Docker infrastructure

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | `docker compose ps` | `db` and `redis` healthy |
| 4.2 | `bin/rails runner "puts Redis.new.ping"` | `PONG` (Sidekiq/Action Cable) |
| 4.3 | `bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"` | Connection succeeds |

---

## 5. Python worker loop

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | `make stack-up` | `migrate` exits OK; worker container(s) running |
| 5.2 | `docker compose logs worker --tail 50` | Worker polling / claiming jobs; no crash loop |
| 5.3 | Enqueue a job from Rails console: `SystemJobs::Create.call(user: User.first, job_type: :import_games, payload: { "dry_run" => true })` | Worker claims and completes or fails gracefully; row reaches terminal status |

---

## 6. Sidekiq (Rails jobs)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 6.1 | Run `bin/dev` (includes Sidekiq) | Sidekiq process starts |
| 6.2 | Visit Sidekiq Web UI (if mounted in dev) | UI loads for admin user, or job runs without error in logs |

---

## Minimum bar before merge

1. `make test` green
2. `/up` returns 200
3. Sign up → dashboard → sign out → sign in
4. `docker compose up -d db redis` + worker claims a test `SystemJob`

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| Health endpoint | Yes | `spec/requests/health_check_spec.rb` |
| ULID on create | Yes | `spec/models/application_record_spec.rb` |
| SystemJob enums + claim path | Yes | `spec/integration/system_job_worker_contract_spec.rb` |
| Email sign-up flow | Yes | `spec/system/user_authentication_spec.rb` |
| Worker Docker migrate + multi-worker | **No** | Manual only (see M6 doc §7) |
| Live worker processing real import | **No** | Covered in M3 |

---

## Out of scope (M0)

- Lichess OAuth (M1)
- Game import and analysis (M3–M4)
- Redis wake-up for workers (deferred per todo)
