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
  let!(:analysis_event) { create(:analysis_event, analysis_run: analysis_run, game: game, move: move) }
  let(:pattern_cycle) { create(:pattern_cycle, :active, user: user) }
  let!(:pattern_occurrence) do
    create(:pattern_occurrence, user: user, game: game, move: move, pattern_cycle: pattern_cycle)
  end
  let(:training_plan) { create(:training_plan, :active, user: user, pattern_cycle: pattern_cycle) }
  let!(:due_assignment) do
    create(:training_assignment, training_plan: training_plan, due_on: Date.current, status: :pending)
  end
  let!(:older_snapshot) do
    create(
      :progress_snapshot,
      user: user,
      training_plan: training_plan,
      pattern_cycle: pattern_cycle,
      snapshot_at: 2.days.ago,
      pattern_frequency: 0.6
    )
  end
  let!(:newer_snapshot) do
    create(
      :progress_snapshot,
      user: user,
      training_plan: training_plan,
      pattern_cycle: pattern_cycle,
      snapshot_at: 1.day.ago,
      pattern_frequency: 0.4
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
    expect(analysis_run.analysis_events).to contain_exactly(analysis_event)
  end

  it "answers what weaknesses were detected" do
    expect(user.pattern_cycles).to include(pattern_cycle)
    expect(pattern_cycle.pattern_occurrences).to contain_exactly(pattern_occurrence)
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
    expect(snapshots.last.pattern_frequency).to be < snapshots.first.pattern_frequency
  end
end
