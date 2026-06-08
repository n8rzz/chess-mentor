.PHONY: test test-rails test-python test-db-python test-db-rails workers-up workers-down workers-build

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

workers-up:
	docker compose up -d --scale worker=$(WORKER_REPLICAS) worker

workers-down:
	docker compose stop worker

workers-build:
	docker compose build worker
