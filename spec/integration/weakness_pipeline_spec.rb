# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weakness pipeline", type: :integration do
  include Devise::Test::IntegrationHelpers
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

  def stockfish_available?
    path = ENV.fetch("STOCKFISH_PATH", "/opt/homebrew/bin/stockfish")
    File.executable?(path)
  end

  def python_analysis_ready?
    return false unless system("python3 --version", out: File::NULL, err: File::NULL)

    script = "import psycopg; from worker.weakness_package.handler import run_classification"
    env = python_env
    Dir.chdir(Rails.root.join("analysis")) do
      system(env, "python3", "-c", script, out: File::NULL, err: File::NULL)
    end
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

  def run_python_analysis(analysis_run_id:, game_id:)
    script = <<~PY
      from worker.config import load_config
      from worker.eval_package.handler import run_analysis
      import psycopg

      config = load_config()
      with psycopg.connect(config.database_url) as conn:
          run_analysis(conn, "#{analysis_run_id}", "#{game_id}")
    PY

    Dir.chdir(Rails.root.join("analysis")) do
      system(python_env, "python3", "-c", script) || raise("Python analysis failed")
    end
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

    Dir.chdir(Rails.root.join("analysis")) do
      system(python_env, "python3", "-c", script) || raise("Python classification failed")
    end
  end

  before do
    skip "Stockfish not available" unless stockfish_available?
    skip "Python analysis dependencies not available" unless python_analysis_ready?
  end

  it "creates weakness cycles queryable from Rails after analysis and classification" do
    user = create(:user)
    provider_account = create(:provider_account, user: user)
    import_batch = create(:import_batch, :succeeded, user: user, provider_account: provider_account)
    game = create(
      :game,
      user: user,
      provider_account: provider_account,
      import_batch: import_batch,
      pgn: DEMO_BLITZ_PGN,
      user_color: :white,
      time_class: :blitz
    )
    analysis_run = create(:analysis_run, :pending, game: game, user: user)

    run_python_analysis(analysis_run_id: analysis_run.id, game_id: game.id)
    expect(analysis_run.reload).to be_succeeded

    expect do
      run_python_classification(user_id: user.id)
    end.to change(WeaknessCycle, :count).by(at_least: 0)
      .and change(WeaknessEvent, :count).by(at_least: 0)

    sign_in user
    get weaknesses_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recurring weaknesses")
  end
end
