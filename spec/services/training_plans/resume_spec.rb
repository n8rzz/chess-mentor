# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Resume do
  let(:plan) { create(:training_plan, user: create(:user), status: :paused) }

  it "resumes a paused plan" do
    described_class.call(plan: plan)

    expect(plan.reload).to be_active
  end

  it "rejects resuming a non-paused plan" do
    plan.update!(status: :active)

    expect {
      described_class.call(plan: plan)
    }.to raise_error(TrainingPlans::Resume::Error, "Only paused plans can be resumed")
  end
end
