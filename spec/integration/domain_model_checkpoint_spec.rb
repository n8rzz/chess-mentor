# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Domain model checkpoint", type: :integration do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }
  let(:import_batch) { create(:import_batch, :succeeded, user: user, provider_account: provider_account) }
  let(:game) { create(:game, user: user, provider_account: provider_account, import_batch: import_batch) }
  let(:move) { create(:move, game: game, played_by_user: true) }
  let(:analysis_run) { create(:analysis_run, :succeeded, game: game, user: user) }
  let!(:move_evaluation) { create(:move_evaluation, analysis_run: analysis_run, game: game, move: move) }
  let!(:candidate_event) { create(:candidate_event, analysis_run: analysis_run, game: game, move: move) }
  let(:weakness_cycle) { create(:weakness_cycle, :active, user: user) }
  let!(:weakness_event) do
    create(:weakness_event, user: user, game: game, move: move, weakness_cycle: weakness_cycle)
  end
  let(:training_plan) { create(:training_plan, :active, user: user, weakness_cycle: weakness_cycle) }
  let!(:due_assignment) do
    create(:training_assignment, training_plan: training_plan, due_on: Date.current, status: :pending)
  end
  let!(:older_snapshot) do
    create(
      :progress_snapshot,
      user: user,
      training_plan: training_plan,
      weakness_cycle: weakness_cycle,
      snapshot_at: 2.days.ago,
      weakness_frequency: 0.6
    )
  end
  let!(:newer_snapshot) do
    create(
      :progress_snapshot,
      user: user,
      training_plan: training_plan,
      weakness_cycle: weakness_cycle,
      snapshot_at: 1.day.ago,
      weakness_frequency: 0.4
    )
  end

  before do
    import_batch
    game
    analysis_run
    training_plan
  end

  it "answers who the user is" do
    expect(User.find(user.id)).to eq(user)
  end

  it "answers which providers are connected" do
    expect(user.provider_accounts).to contain_exactly(provider_account)
  end

  it "answers what imports have happened" do
    expect(user.import_batches.order(created_at: :desc)).to eq([ import_batch ])
  end

  it "answers whether an import is currently running" do
    expect(user.import_batches.in_progress.exists?).to be(false)

    create(:import_batch, :running, user: user, provider_account: provider_account)

    expect(user.import_batches.in_progress.exists?).to be(true)
  end

  it "answers whether an import succeeded or failed" do
    expect(import_batch).to be_succeeded
  end

  it "answers which games were imported" do
    expect(user.games).to contain_exactly(game)
    expect(import_batch.games).to contain_exactly(game)
  end

  it "answers which games were analyzed" do
    analyzed_game_ids = AnalysisRun.succeeded.where(user: user).pluck(:game_id)

    expect(analyzed_game_ids).to eq([ game.id ])
  end

  it "answers what Stockfish found" do
    expect(analysis_run.move_evaluations).to contain_exactly(move_evaluation)
    expect(analysis_run.candidate_events).to contain_exactly(candidate_event)
  end

  it "answers what weaknesses were detected" do
    expect(user.weakness_cycles).to include(weakness_cycle)
    expect(weakness_cycle.weakness_events).to contain_exactly(weakness_event)
  end

  it "answers which weakness is being trained" do
    expect(user.training_plans.active).to contain_exactly(training_plan)
  end

  it "answers which assignments are due" do
    due = training_plan.training_assignments.pending.where(due_on: ..Date.current)

    expect(due).to contain_exactly(due_assignment)
  end

  it "answers whether the user is improving" do
    snapshots = user.progress_snapshots.order(:snapshot_at)

    expect(snapshots).to eq([ older_snapshot, newer_snapshot ])
    expect(snapshots.last.weakness_frequency).to be < snapshots.first.weakness_frequency
  end
end
