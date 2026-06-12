# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Pause do
  let(:plan) { create(:training_plan, :active) }

  it "pauses an active plan" do
    described_class.call(plan: plan)

    expect(plan.reload).to be_paused
  end

  it "rejects pausing a non-active plan" do
    plan.update!(status: :paused)

    expect {
      described_class.call(plan: plan)
    }.to raise_error(TrainingPlans::Pause::Error, "Only active plans can be paused")
  end
end
