# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weakness pipeline", type: :integration do
  include Devise::Test::IntegrationHelpers

  before { skip_unless_pipeline_ready! }

  it "creates weakness cycles queryable from Rails after analysis and classification" do
    user = create(:user)
    provider_account = create(:provider_account, user: user)
    import_batch = create(:import_batch, :succeeded, user: user, provider_account: provider_account)
    game = create(
      :game,
      user: user,
      provider_account: provider_account,
      import_batch: import_batch,
      pgn: PythonPipelineHelpers::DEMO_BLITZ_PGN,
      user_color: :white,
      time_class: :blitz
    )
    analysis_run = create(:analysis_run, :pending, game: game, user: user)

    run_python_analysis(analysis_run_id: analysis_run.id, game_id: game.id)
    expect(analysis_run.reload).to be_succeeded

    expect do
      run_python_classification(user_id: user.id)
    end.to change(PatternCycle, :count).by_at_least(0)
      .and change(PatternOccurrence, :count).by_at_least(0)

    sign_in user
    get pattern_cycles_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Recurring patterns")
  end
end
