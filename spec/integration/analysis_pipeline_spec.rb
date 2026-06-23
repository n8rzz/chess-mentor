# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analysis pipeline", type: :integration do
  before { skip_unless_pipeline_ready! }

  it "persists moves, evaluations, and candidate events for an imported game" do
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

    expect do
      run_python_analysis(analysis_run_id: analysis_run.id, game_id: game.id)
    end.to change(Move, :count).by(17)
      .and change(MoveEvaluation, :count).by(9)
      .and change(CandidateEvent, :count).by(at_least: 0)

    analysis_run.reload
    expect(analysis_run).to be_succeeded
    expect(analysis_run.metadata).to include("user_moves_evaluated" => 9, "moves_parsed" => 17)
  end
end
