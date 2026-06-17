# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo progress seed" do
  before do
    @user = User.create!(
      email: "starship@example.com",
      password: "password123",
      username: "starship123"
    )
    @cycle = WeaknessCycle.create!(
      user: @user,
      theme: :missed_tactics,
      status: :active,
      cycle_number: 1,
      baseline_occurrences: 8,
      current_occurrences: 8,
      baseline_severity: 0.8,
      current_severity: 0.8,
      detection_window_games: 10,
      detection_window_days: 30,
      started_at: 2.months.ago,
      metadata: { "seed_key" => "demo_missed_tactics" }
    )
    @plan = TrainingPlan.create!(
      user: @user,
      weakness_cycle: @cycle,
      theme: :missed_tactics,
      status: :active,
      starts_at: 2.weeks.ago,
      ends_at: 2.weeks.from_now,
      baseline_occurrences: 8,
      current_occurrences: 8,
      improvement_threshold: TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD,
      managed_threshold: TrainingPlan::DEFAULT_MANAGED_THRESHOLD,
      metadata: { "seed_key" => "demo_training_plan" }
    )

    allow(Rails.env).to receive(:development?).and_return(true)
    load Rails.root.join("db/seeds/development/08_demo_progress.rb")
  end

  it "creates weekly demo progress snapshots for chart development" do
    snapshots = ProgressSnapshot.where(user: @user)

    expect(snapshots.count).to eq(32)
    expect(snapshots.where("metadata->>'kind' = ?", "rating").count).to eq(8)
    expect(snapshots.where("metadata->>'kind' = ?", "performance").count).to eq(8)
    expect(snapshots.where("metadata->>'kind' = ?", "weakness").count).to eq(8)
    expect(snapshots.where("metadata->>'kind' = ?", "training").count).to eq(8)
  end

  it "is idempotent when reloaded" do
    load Rails.root.join("db/seeds/development/08_demo_progress.rb")

    expect(ProgressSnapshot.where(user: @user).count).to eq(32)
  end
end
