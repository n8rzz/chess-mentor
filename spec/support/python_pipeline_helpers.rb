# frozen_string_literal: true

module PythonPipelineHelpers
  DEMO_BLITZ_PGN = <<~PGN.strip
    [Event "Demo Blitz"]
    [Site "lichess.org"]
    [Date "2026.06.01"]
    [White "starship_lichess"]
    [Black "opponent_blitz"]
    [Result "1-0"]
    [TimeControl "180+0"]

    1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. d3 Be7 5. O-O O-O 6. Nc3 d6 7. Bg5 h6 8. Bxf6 Bxf6 9. Nd5 1-0
  PGN

  module_function

  def stockfish_available?
    path = ENV.fetch("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
    File.executable?(path)
  end

  def python_available?
    system("python3 --version", out: File::NULL, err: File::NULL)
  end

  def python_import_ready?
    python_module_ready?("from worker.import_package.handler import run_import")
  end

  def python_analysis_ready?
    python_module_ready?("from worker.eval_package.handler import run_analysis")
  end

  def python_classification_ready?
    python_module_ready?("from worker.weakness_package.handler import run_classification")
  end

  def python_training_ready?
    python_module_ready?("from worker.training_package.handler import run_plan_generation")
  end

  def python_progress_ready?
    python_module_ready?("from worker.progress_package.handler import run_snapshot_update")
  end

  def python_metrics_ready?
    python_module_ready?("from worker.metrics_package.repository import persist_game_metrics")
  end

  def python_pipeline_ready?
    python_available? &&
      python_import_ready? &&
      python_analysis_ready? &&
      python_classification_ready? &&
      python_training_ready? &&
      stockfish_available?
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

  def run_python_script(script)
    success = false
    Dir.chdir(Rails.root.join("analysis")) do
      success = system(python_env, "python3", "-c", script)
    end
    raise "Python script failed" unless success

    true
  end

  def run_python_import(import_batch_id:, use_fixture: true)
    batch = ImportBatch.includes(:provider_account).find(import_batch_id)
    access_token_literal = batch.provider_account.access_token.to_json

    fixture_setup = if use_fixture
      <<~PY
        from unittest.mock import patch
        from worker.import_package.lichess_client import LichessGame
        from db_helpers import DEMO_BLITZ_PGN, sample_lichess_game_raw

        raw = sample_lichess_game_raw()
        raw["id"] = "mvp-e2e-game-1"
        raw["pgn"] = DEMO_BLITZ_PGN
        raw["players"]["white"]["user"]["name"] = "testuser"
        games = [LichessGame(raw=raw)]
        patch_target = patch("worker.import_package.handler.LichessClient")
        patch_target.return_value.fetch_games.return_value = games
        patch_ctx = patch_target
      PY
    else
      <<~PY
        from contextlib import nullcontext
        patch_ctx = nullcontext()
      PY
    end

    script = <<~PY
      from worker.config import load_config
      from worker.import_package.handler import run_import
      import psycopg

      #{fixture_setup}

      config = load_config()
      with patch_ctx:
          with psycopg.connect(config.database_url) as conn:
              run_import(conn, "#{import_batch_id}", access_token=#{access_token_literal})
    PY

    run_python_script(script)
  end

  def run_python_analysis(analysis_run_id:, game_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.eval_package.handler import run_analysis
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_analysis(conn, "#{analysis_run_id}", "#{game_id}")
    PY

    run_python_script(script)
  end

  def run_python_classification(user_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.weakness_package.handler import run_classification
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_classification(conn, "#{user_id}")
    PY

    run_python_script(script)
  end

  def run_python_plan_generation(training_plan_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.training_package.handler import run_plan_generation
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_plan_generation(conn, "#{training_plan_id}")
    PY

    run_python_script(script)
  end

  def run_python_progress_snapshots(user_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.progress_package.handler import run_snapshot_update
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_snapshot_update(conn, "#{user_id}")
    PY

    run_python_script(script)
  end

  def run_python_review_period_metrics(user_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.metrics_package.handler import run_period_metrics_refresh
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_period_metrics_refresh(conn, "#{user_id}")
    PY

    run_python_script(script)
  end

  def run_python_persist_game_metrics(analysis_run_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.metrics_package.repository import persist_game_metrics
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          with conn.transaction():
              result = persist_game_metrics(conn, "#{analysis_run_id}")
              if result is None:
                  raise SystemExit("persist_game_metrics returned None")
    PY

    run_python_script(script)
  end

  def skip_unless_pipeline_ready!
    skip "Stockfish not available" unless stockfish_available?
    skip "Python pipeline dependencies not available" unless python_pipeline_ready?
  end

  def skip_unless_metrics_ready!
    skip "Python metrics dependencies not available" unless python_available? && python_metrics_ready?
  end

  def python_module_ready?(import_script)
    return false unless python_available?

    Dir.chdir(Rails.root.join("analysis")) do
      system(python_env, "python3", "-c", "import psycopg; #{import_script}", out: File::NULL, err: File::NULL)
    end
  end
  private_class_method :python_module_ready?
end

RSpec.configure do |config|
  config.include PythonPipelineHelpers
end
