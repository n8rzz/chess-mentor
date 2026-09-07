# frozen_string_literal: true

require "open3"

module Metrics
  # Thin bridge so development seeds can invoke the Python metrics package
  # against the current Rails database without going through SystemJob workers.
  class PythonRunner
    class Error < StandardError; end

    def self.persist_game_metrics!(analysis_run_id:)
      new.persist_game_metrics!(analysis_run_id:)
    end

    def self.refresh_review_period_metrics!(user_id:)
      new.refresh_review_period_metrics!(user_id:)
    end

    def persist_game_metrics!(analysis_run_id:)
      run!(<<~PY)
        from worker.config import load_config
        from worker.metrics_package.repository import persist_game_metrics
        import psycopg

        config = load_config()
        with psycopg.connect(config.database_url) as conn:
            with conn.transaction():
                result = persist_game_metrics(conn, #{analysis_run_id.to_json})
                if result is None:
                    raise SystemExit("persist_game_metrics returned None")
      PY
    end

    def refresh_review_period_metrics!(user_id:)
      run!(<<~PY)
        from worker.config import load_config
        from worker.metrics_package.handler import run_period_metrics_refresh
        import psycopg

        config = load_config()
        with psycopg.connect(config.database_url) as conn:
            run_period_metrics_refresh(conn, #{user_id.to_json})
      PY
    end

    private

    def run!(script)
      env = python_env
      success = false
      stderr = +""

      Dir.chdir(Rails.root.join("analysis")) do
        _stdout, stderr, status = Open3.capture3(env, "python3", "-c", script)
        success = status.success?
      end

      raise Error, "Python metrics script failed: #{stderr.presence || 'unknown error'}" unless success

      true
    end

    def python_env
      db_config = ActiveRecord::Base.connection_db_config.configuration_hash
      {
        "DATABASE_HOST" => db_config[:host] || ENV.fetch("DATABASE_HOST", "localhost"),
        "DATABASE_PORT" => (db_config[:port] || ENV.fetch("DATABASE_PORT", 5432)).to_s,
        "DATABASE_USERNAME" => db_config[:username] || ENV.fetch("DATABASE_USERNAME", "chess_mentor"),
        "DATABASE_PASSWORD" => db_config[:password] || ENV.fetch("DATABASE_PASSWORD", "chess_mentor"),
        "DATABASE_NAME" => db_config[:database],
        "REDIS_URL" => ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
        "STOCKFISH_PATH" => ENV.fetch("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish"),
        "PYTHONPATH" => Rails.root.join("analysis/worker").to_s
      }
    end
  end
end
