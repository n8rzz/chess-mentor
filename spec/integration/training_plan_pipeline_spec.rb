# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Training plan pipeline", type: :request, skip_database_cleaner: true do
  include Devise::Test::IntegrationHelpers

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
