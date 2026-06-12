# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo training seed" do
  before do
    load Rails.root.join("db/seeds/02_puzzles.rb")

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
      baseline_occurrences: 4,
      current_occurrences: 4,
      baseline_severity: 0.8,
      current_severity: 0.8,
      detection_window_games: 3,
      detection_window_days: 30,
      started_at: 2.days.ago,
      metadata: { "seed_key" => "demo_missed_tactics" }
    )

    allow(Rails.env).to receive(:development?).and_return(true)
    load Rails.root.join("db/seeds/07_demo_training.rb")
  end

  it "creates a demo plan with 112 assignments for the demo user" do
    plan = TrainingPlan.find_by("metadata->>'seed_key' = ?", "demo_training_plan")

    expect(plan).to be_present
    expect(plan.user).to eq(@user)
    expect(plan.weakness_cycle).to eq(@cycle)
    expect(plan.theme).to eq("missed_tactics")
    expect(plan.training_assignments.count).to eq(112)
  end

  it "is idempotent when reloaded" do
    load Rails.root.join("db/seeds/07_demo_training.rb")

    plan = TrainingPlan.find_by("metadata->>'seed_key' = ?", "demo_training_plan")

    expect(TrainingPlan.where(user: @user).count).to eq(1)
    expect(plan.training_assignments.count).to eq(112)
  end
end
