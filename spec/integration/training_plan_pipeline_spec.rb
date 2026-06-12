# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Training plan pipeline", type: :request, skip_database_cleaner: true do
  include Devise::Test::IntegrationHelpers

  def python_training_ready?
    return false unless system("python3 --version", out: File::NULL, err: File::NULL)

    script = "import psycopg; from worker.training_package.handler import run_plan_generation"
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

  def run_python_plan_generation(training_plan_id:)
    script = <<~PY
      import os
      import psycopg
      from worker.training_package.handler import run_plan_generation

      db_url = (
          f"postgresql://{os.environ['DATABASE_USERNAME']}:{os.environ['DATABASE_PASSWORD']}"
          f"@{os.environ['DATABASE_HOST']}:{os.environ['DATABASE_PORT']}/{os.environ['DATABASE_NAME']}"
      )
      with psycopg.connect(db_url) as conn:
          run_plan_generation(conn, "#{training_plan_id}")
    PY

    Dir.chdir(Rails.root.join("analysis")) do
      success = system(python_env, "python3", "-c", script)
      raise "Python training plan generation failed" unless success
    end
  end

  before do
    skip "Python training dependencies not available" unless python_training_ready?
  end

  it "creates assignments queryable from Rails after activation and generation" do
    user = create(:user)
    provider_account = create(:provider_account, user: user)
    import_batch = create(:import_batch, :succeeded, user: user, provider_account: provider_account)
    game = create(:game, user: user, provider_account: provider_account, import_batch: import_batch)
    move = create(:move, game: game, played_by_user: true)
    cycle = create(:weakness_cycle, :active, user: user, theme: :missed_tactics, baseline_occurrences: 4, current_occurrences: 4)
    create(:weakness_event, user: user, game: game, move: move, weakness_cycle: cycle, primary_theme: :missed_tactics)
    create_list(:puzzle, 5, theme: :missed_tactics)

    plan = TrainingPlans::Activate.call(user: user, weakness_cycle: cycle)

    expect {
      run_python_plan_generation(training_plan_id: plan.id)
    }.to change { plan.training_assignments.count }.from(0).to(112)

    sign_in user
    get today_training_plan_path(plan)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Today's assignments")
    expect(response.body).to include("Complete")
  end
end
