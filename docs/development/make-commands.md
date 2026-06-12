---
title: Make commands
last_modified: 2026-06-08
tags:
  - development
  - make
  - docker
  - testing
---

# Make commands

The project `Makefile` wraps common test and Docker worker tasks. It reads optional variables from the repo root `.env` file (see `.env.example`).

## Environment variables

| Variable               | Default                       | Used by                   |
| ---------------------- | ----------------------------- | ------------------------- |
| `WORKER_REPLICAS`      | `1`                           | `workers-up`              |
| `PYTHON_TEST_DATABASE` | `chess_mentor_python_test`    | Python test targets       |
| `DATABASE_HOST`        | `localhost`                   | Python test DB setup      |
| `DATABASE_PORT`        | `5432`                        | Python test DB setup      |
| `DATABASE_USERNAME`    | `chess_mentor`                | Python test DB setup      |
| `DATABASE_PASSWORD`    | `chess_mentor`                | Python test DB setup      |
| `STOCKFISH_PATH`       | `/opt/homebrew/bin/stockfish` | `test-python` (host only) |

Override any variable on the command line:

```bash
make workers-up WORKER_REPLICAS=3
```

## Testing

| Command               | What it does                                              |
| --------------------- | --------------------------------------------------------- |
| `make test`           | Full suite: prepare both test DBs, run RSpec, then pytest |
| `make test-rails`     | RSpec only                                                |
| `make test-python`    | Prepare Python test DB, then pytest                       |
| `make test-db-rails`  | `rails db:test:prepare`                                   |
| `make test-db-python` | Create/load schema for the Python test database           |

**Prerequisites:** Postgres and Redis running (`docker compose up -d db redis`). Stockfish on the host for full Python test coverage (`brew install stockfish`).

```bash
# Run everything (CI-equivalent locally)
make test

# Rails only
make test-rails

# Python only
make test-python
```

## Python analysis workers

These targets manage only the Python worker service in `docker-compose.yml`. Postgres and Redis must already be running. `workers-up` and `stack-up` run `rails db:prepare` on the host first; `docker compose up` with workers also runs a one-shot `migrate` service before workers start.

| Command              | What it does                                                        |
| -------------------- | ------------------------------------------------------------------- |
| `make workers-up`    | Prepare dev DB, then start `WORKER_REPLICAS` worker containers (detached) |
| `make stack-up`      | Prepare dev DB, then start db, redis, migrate, and workers                 |
| `make workers-down`  | Stop worker containers                                              |
| `make workers-build` | Rebuild the worker image after `analysis/` code changes             |

```bash
# One worker (default)
make workers-up

# Four workers for faster game analysis
make workers-up WORKER_REPLICAS=4

# Scale back down
make workers-up WORKER_REPLICAS=1

# After pulling worker code
make workers-build && make workers-up
```

Each Docker worker gets a unique ID from its container hostname. For a worker running on your machine (not in Docker), set `WORKER_ID` in `.env.worker` (see `.env.worker.example`).

## Typical local dev stack

Analysis needs Rails, Sidekiq, and at least one Python worker:

```bash
# Terminal 1 — Postgres and Redis
docker compose up -d db redis

# Terminal 2 — Python workers
make workers-up

# Terminal 3 — Rails, Tailwind, Sidekiq
bin/dev
```

Copy env files before first run:

```bash
cp .env.example .env
cp .env.worker.example .env.worker
```
