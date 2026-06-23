# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Full workflow pipeline", type: :integration do
  include Devise::Test::IntegrationHelpers

  before { skip_unless_pipeline_ready! }

  it "chains import through analysis, classification, and training plan generation" do
    user = create(:user)
    provider_account = create(:provider_account, user: user, provider_username: "testuser")
    batch = create(:import_batch, user: user, provider_account: provider_account, status: :pending)
    SystemJobs::Create.call(
      user: user,
      job_type: :import_games,
      payload: { "import_batch_id" => batch.id }
    )

    workflow_driver.drain_pending_jobs!
    batch.reload
    expect(batch).to be_succeeded

    game = batch.games.first
    expect(game).to be_present
    expect(game.pgn).to include("1. e4")

    AnalysisRuns::ReconcileAll.call
    workflow_driver.drain_pending_jobs!

    analysis_run = game.analysis_runs.succeeded.first
    expect(analysis_run).to be_present
    expect(game.moves.count).to eq(17)

    sign_in user
    get weaknesses_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recurring weaknesses")

    cycle = user.weakness_cycles.first
    expect(cycle).to be_present
    create_list(:puzzle, 5, theme: cycle.theme) if Puzzle.where(theme: cycle.theme).count < 5

    plan = TrainingPlans::Activate.call(user: user, weakness_cycle: cycle)
    workflow_driver.drain_pending_jobs!

    expect(plan.training_assignments.count).to eq(112)

    get training_plans_path
    expect(response.body).to include(plan.theme_label)

    get today_training_plan_path(plan)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Today's assignments")
    expect(response.body).to include("Complete")
  end
end
