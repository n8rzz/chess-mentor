# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Archive do
  it "archives an active plan" do
    plan = create(:training_plan, :active)

    described_class.call(plan: plan)

    expect(plan.reload).to be_archived
  end

  it "archives a paused plan" do
    plan = create(:training_plan, user: create(:user), status: :paused)

    described_class.call(plan: plan)

    expect(plan.reload).to be_archived
  end
end
