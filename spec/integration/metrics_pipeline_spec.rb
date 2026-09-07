# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Metrics pipeline", type: :integration, skip_database_cleaner: true do
  before { skip_unless_metrics_ready! }

  it "persists game metrics and rolls them up into review period metrics" do
    user = create(:user)
    provider_account = create(:provider_account, user: user)
    import_batch = create(:import_batch, :succeeded, user: user, provider_account: provider_account)

    win = create_analyzed_game(
      user:,
      provider_account:,
      import_batch:,
      result: :win,
      played_at: 3.days.ago,
      evals: [
        { ply: 1, phase: :middlegame, before: 220, after: 210, cpl: 10, classification: :good, clock_before: 90, clock_after: 88 },
        { ply: 3, phase: :middlegame, before: 230, after: 200, cpl: 30, classification: :good, clock_before: 88, clock_after: 86 }
      ]
    )
    loss = create_analyzed_game(
      user:,
      provider_account:,
      import_batch:,
      result: :loss,
      played_at: 1.day.ago,
      evals: [
        { ply: 1, phase: :middlegame, before: 40, after: -80, cpl: 120, classification: :mistake, clock_before: 90, clock_after: 88 },
        { ply: 3, phase: :endgame, before: -90, after: -400, cpl: 310, classification: :blunder, clock_before: 10, clock_after: 8 }
      ]
    )

    run_python_persist_game_metrics(analysis_run_id: win[:analysis_run].id)
    run_python_persist_game_metrics(analysis_run_id: loss[:analysis_run].id)

    expect(win[:analysis_run].reload.game_metric).to be_present
    expect(loss[:analysis_run].reload.game_metric).to be_present
    expect(win[:analysis_run].game_metric.winning_positions_reached).to eq(1)
    expect(win[:analysis_run].game_metric.winning_positions_converted).to eq(1)

    period = ReviewPeriods::CreateFromGames.call(
      user: user,
      games: [ win[:game], loss[:game] ],
      label: "Metrics pipeline period"
    )

    workflow_driver.drain_pending_jobs!

    period_metric = period.review_period_metrics.find_by!(
      metric_formula_version: AnalysisVersions::METRIC_FORMULA_VERSION
    )
    expect(period_metric.games_count).to eq(2)
    expect(period_metric.analyzed_games_count).to eq(2)
    expect(period_metric.win_rate).to eq(0.5)
    expect(period_metric.loss_rate).to eq(0.5)
    expect(period_metric.average_centipawn_loss).to eq(117.5)
    expect(period_metric.mistakes_per_game).to eq(1.0)
    expect(period_metric.blunders_per_game).to eq(0.5)
    expect(period_metric.conversion_rate).to eq(1.0)
    expect(period_metric.phase_metrics.dig("endgame", "blunders")).to eq(1)
  end

  def create_analyzed_game(user:, provider_account:, import_batch:, result:, played_at:, evals:)
    game = create(
      :game,
      user:,
      provider_account:,
      import_batch:,
      result:,
      played_at:,
      time_class: :blitz,
      time_control: "180+0",
      user_color: :white
    )
    analysis_run = create(:analysis_run, :succeeded, user:, game:)

    evals.each do |spec|
      move = create(
        :move,
        game:,
        ply: spec[:ply],
        move_number: (spec[:ply] + 1) / 2,
        color: :white,
        phase: spec[:phase],
        played_by_user: true,
        clock_before: spec[:clock_before],
        clock_after: spec[:clock_after]
      )
      create(
        :move_evaluation,
        analysis_run:,
        game:,
        move:,
        eval_before_cp: spec[:before],
        eval_after_cp: spec[:after],
        centipawn_loss: spec[:cpl],
        classification: spec[:classification]
      )
    end

    { game:, analysis_run: }
  end
end
