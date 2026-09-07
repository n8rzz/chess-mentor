# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weakness improvement", type: :integration do
  let(:user) { create(:user) }
  let(:pattern_cycle) do
    create(
      :pattern_cycle,
      :active,
      user: user,
      baseline_occurrences: 8,
      current_occurrences: 8,
      detection_window_games: 10
    )
  end
  let(:plan) do
    create(
      :training_plan,
      :active,
      user: user,
      pattern_cycle: pattern_cycle,
      baseline_occurrences: 8,
      current_occurrences: 8,
      progress_percentage: 0.0,
      improvement_threshold: TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD,
      managed_threshold: TrainingPlan::DEFAULT_MANAGED_THRESHOLD
    )
  end

  it "demonstrates measurable weakness reduction through plan progress" do
    pattern_cycle.update!(current_occurrences: 5)
    TrainingPlans::SyncProgress.call(plan: plan)

    expect(plan.reload).to be_improving
    expect(plan.progress_percentage).to eq(37.5)

    pattern_cycle.update!(current_occurrences: 1)
    TrainingPlans::SyncProgress.call(plan: plan)

    expect(plan.reload).to be_managed
    expect(plan.progress_percentage).to eq(87.5)
  end

  it "shows decreasing weakness frequency in progress snapshots" do
    older = create(
      :progress_snapshot,
      user: user,
      pattern_cycle: pattern_cycle,
      training_plan: plan,
      pattern_frequency: 0.8,
      snapshot_at: 2.weeks.ago,
      metadata: { "kind" => "weakness" }
    )
    newer = create(
      :progress_snapshot,
      user: user,
      pattern_cycle: pattern_cycle,
      training_plan: plan,
      pattern_frequency: 0.3,
      snapshot_at: 1.week.ago,
      metadata: { "kind" => "weakness" }
    )

    snapshots = user.progress_snapshots.order(:snapshot_at)

    expect(snapshots).to eq([ older, newer ])
    expect(snapshots.last.pattern_frequency).to be < snapshots.first.pattern_frequency
  end
end
