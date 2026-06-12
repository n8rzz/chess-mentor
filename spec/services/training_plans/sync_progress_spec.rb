# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::SyncProgress do
  let(:user) { create(:user) }
  let(:weakness_cycle) { create(:weakness_cycle, :active, user: user, baseline_occurrences: 10, current_occurrences: 10) }
  let(:plan) do
    create(
      :training_plan,
      :active,
      user: user,
      weakness_cycle: weakness_cycle,
      baseline_occurrences: 10,
      current_occurrences: 10,
      progress_percentage: 0.0,
      improvement_threshold: 0.30,
      managed_threshold: 0.75
    )
  end

  it "marks the plan improving at the 30% threshold" do
    weakness_cycle.update!(current_occurrences: 7)

    described_class.call(plan: plan)

    expect(plan.reload).to be_improving
    expect(plan.progress_percentage).to eq(30.0)
    expect(plan.current_occurrences).to eq(7)
  end

  it "marks the plan managed at the 75% threshold" do
    weakness_cycle.update!(current_occurrences: 2)

    described_class.call(plan: plan)

    expect(plan.reload).to be_managed
    expect(plan.progress_percentage).to eq(80.0)
  end

  it "keeps paused plans paused" do
    plan.update!(status: :paused)
    weakness_cycle.update!(current_occurrences: 2)

    described_class.call(plan: plan)

    expect(plan.reload).to be_paused
    expect(plan.progress_percentage).to eq(80.0)
  end
end
