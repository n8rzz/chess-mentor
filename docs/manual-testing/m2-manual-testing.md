---
title: M2 manual testing checklist
last_modified: 2026-06-16
tags:
  - development
  - testing
  - domain-models
  - milestone-2
---

# M2 manual testing checklist

Use this checklist for **Milestone 2: Domain schema** — migrations, models, associations, lifecycle enums, constraints, and seeds. **Milestone 2.5** (motif/phase enums) is included in §2.5 below.

Prerequisite: [m0-manual-testing.md](m0-manual-testing.md).

Related docs:

- [domain-models.md](../planning/domain-models.md) — entity definitions and §25 checkpoint questions
- [puzzle-motif-contract.md](../planning/puzzle-motif-contract.md)

**Checkpoint:** Database can answer the 12 domain-model questions (automated in `domain_model_checkpoint_spec`).

---

## Prerequisites

```bash
bin/rails db:prepare
bin/rails db:seed
```

---

## 1. Automated suite (CI gate)

```bash
make test
```

M2-relevant specs:

- `spec/models/**/*_spec.rb` (all domain models)
- `spec/integration/domain_model_checkpoint_spec.rb`
- `spec/db/seeds/puzzles_spec.rb`

---

## 2. Schema and migrations

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.1 | `bin/rails db:drop db:create db:migrate` | All migrations apply cleanly |
| 2.2 | `bin/rails db:seed` | Seeds complete without error |
| 2.3 | Re-run `bin/rails db:seed` | Idempotent (no duplicate key errors) |

---

## 3. Domain checkpoint (console smoke)

Run the integration spec, or spot-check in console:

```bash
bundle exec rspec spec/integration/domain_model_checkpoint_spec.rb
```

Optional manual console checks:

```ruby
user = User.first
user.provider_accounts.any?
user.import_batches.in_progress.exists?
TrainingPlan.where(user: user, status: :active).count <= 1  # one-active constraint
Puzzle.curated.count >= 45
```

---

## 4. ULID primary keys

| Step | Action | Expected |
| ---- | ------ | -------- |
| 4.1 | `bin/rails runner "puts Game.create!(...).id"` via factory in console | 26-character ULID string |
| 4.2 | Create two records | IDs are unique and sortable by time |

---

## 2.5. Puzzle motifs and game phase enums (M2.5)

| Step | Action | Expected |
| ---- | ------ | -------- |
| 2.5.1 | `bin/rails db:seed` | Puzzle seeds load with symbol motif values |
| 2.5.2 | `Puzzle.curated.first.motif` in console | Symbol enum (e.g. `:fork`), not free-form string |
| 2.5.3 | `WeaknessEvent.first.phase` (after M5 seeds) | `:opening`, `:middlegame`, or `:endgame` |
| 2.5.4 | `bundle exec rspec spec/models/puzzle_spec.rb spec/models/weakness_event_spec.rb` | Enum definitions pass |

---

## 5. Puzzle seed content

| Step | Action | Expected |
| ---- | ------ | -------- |
| 5.1 | `bundle exec rspec spec/db/seeds/puzzles_spec.rb` | ≥5 puzzles per weakness theme; unique `seed_key`s |
| 5.2 | `bin/rails runner "Puzzle.curated.group(:theme).count"` | All nine themes represented |

---

## Minimum bar before merge

1. `make test` green (model + domain checkpoint specs)
2. Fresh `db:migrate` + `db:seed` succeeds twice (idempotent)
3. `domain_model_checkpoint_spec` passes

---

## Automated test coverage map

| Scenario | Automated coverage | Spec / notes |
| -------- | ------------------- | ------------ |
| All model associations/validations | Yes | `spec/models/*` |
| Domain §25 questions | Yes | `spec/integration/domain_model_checkpoint_spec.rb` |
| One active plan per user | Yes | `spec/models/training_plan_spec.rb` |
| Puzzle seed completeness | Yes | `spec/db/seeds/puzzles_spec.rb` |
| Motif/phase enums | Yes | Model specs |
| Fresh migrate on empty DB | Partial | CI runs `db:test:prepare` |
| Visual UI for domain data | **No** | M3+ |

---

## Out of scope (M2)

- Provider import UI (M3)
- Stockfish analysis (M4)
- Weakness classifier (M5)
