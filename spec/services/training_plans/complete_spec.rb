# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Complete do
  let(:plan) { create(:training_plan, :active) }

  it "completes an active plan and sets completed_at" do
    described_class.call(plan: plan)

    expect(plan.reload).to be_completed
    expect(plan.completed_at).to be_within(2.seconds).of(Time.current)
  end

  it "rejects completing an already completed plan" do
    plan.update!(status: :completed, completed_at: 1.day.ago)

    expect {
      described_class.call(plan: plan)
    }.to raise_error(TrainingPlans::Complete::Error, "Plan is already completed or archived")
  end

  it "rejects completing an archived plan" do
    plan.update!(status: :archived)

    expect {
      described_class.call(plan: plan)
    }.to raise_error(TrainingPlans::Complete::Error, "Plan is already completed or archived")
  end
end
