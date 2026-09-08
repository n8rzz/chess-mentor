.PHONY: test test-rails test-python test-db-python test-db-rails db-prepare workers-up workers-down workers-build workers-restart stack-up

-include .env

PYTHON_TEST_DATABASE ?= chess_mentor_python_test
WORKER_REPLICAS ?= 1
DATABASE_HOST ?= localhost
DATABASE_PORT ?= 5432
DATABASE_USERNAME ?= chess_mentor
DATABASE_PASSWORD ?= chess_mentor

export DATABASE_HOST DATABASE_PORT DATABASE_USERNAME DATABASE_PASSWORD

test: test-db-rails test-db-python test-rails test-python

test-rails:
	bundle exec rspec

test-db-rails:
	bundle exec rails db:test:prepare

test-db-python:
	DATABASE_NAME=$(PYTHON_TEST_DATABASE) bundle exec rails db:create 2>/dev/null || true
	DATABASE_NAME=$(PYTHON_TEST_DATABASE) bundle exec rails db:schema:load

test-python: test-db-python
	cd analysis && \
		DATABASE_NAME=$(PYTHON_TEST_DATABASE) \
		REDIS_URL=redis://localhost:6379/0 \
		STOCKFISH_PATH=$${STOCKFISH_PATH:-/opt/homebrew/bin/stockfish} \
		PYTHONPATH=worker \
		python -m pytest tests/ -q

db-prepare:
	bundle exec rails db:prepare

workers-up: db-prepare
	docker compose up -d --scale worker=$(WORKER_REPLICAS) worker

stack-up: db-prepare
	docker compose up -d --scale worker=$(WORKER_REPLICAS)

workers-down:
	docker compose stop worker

workers-build:
	docker compose build worker

# Bounce active Python worker containers. Rebuilds the image first so analysis/
# code changes are picked up; use WORKER_REPLICAS to set count.
# 
# example: make workers-restart WORKER_REPLICAS=4
workers-restart: workers-build
	@ids=$$(docker compose ps -q worker 2>/dev/null); \
	if [ -z "$$ids" ]; then \
		echo "No active workers — starting $(WORKER_REPLICAS)"; \
		$(MAKE) workers-up; \
	else \
		echo "Recreating $$(echo $$ids | wc -w | tr -d ' ') worker(s) with rebuilt image"; \
		docker compose up -d --force-recreate --no-deps --scale worker=$(WORKER_REPLICAS) worker; \
	fi
