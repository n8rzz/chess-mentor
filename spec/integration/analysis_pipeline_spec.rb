# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analysis pipeline", type: :integration, skip_database_cleaner: true do
  before { skip_unless_pipeline_ready! }

  it "persists moves, evaluations, candidate events, and game metrics" do
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
      time_class: :blitz,
      time_control: "180+0"
    )
    analysis_run = create(:analysis_run, :pending, game: game, user: user)

    expect do
      run_python_analysis(analysis_run_id: analysis_run.id, game_id: game.id)
    end.to change(Move, :count).by(17)
      .and change(MoveEvaluation, :count).by(9)
      .and change(AnalysisEvent, :count).by(at_least: 0)
      .and change(GameMetric, :count).by(1)
      .and change { user.system_jobs.refresh_review_period_metrics.pending.count }.by(1)

    analysis_run.reload
    expect(analysis_run).to be_succeeded
    expect(analysis_run.metadata).to include("user_moves_evaluated" => 9, "moves_parsed" => 17)

    metric = analysis_run.game_metric
    expect(metric).to be_present
    expect(metric.metric_formula_version).to eq(AnalysisVersions::METRIC_FORMULA_VERSION)
    expect(metric.user_move_count).to eq(9)
    expect(metric.average_centipawn_loss).to be_present
    expect(metric.phase_metrics.keys).to include("opening", "middlegame", "endgame")
  end
end
