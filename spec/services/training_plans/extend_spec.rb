# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Extend do
  let(:user) { create(:user) }
  let(:weakness_cycle) { create(:weakness_cycle, :active, user: user) }
  let(:plan) do
    create(
      :training_plan,
      :active,
      user: user,
      weakness_cycle: weakness_cycle,
      starts_at: 20.days.ago,
      ends_at: 2.days.ago,
      progress_percentage: 20.0,
      managed_threshold: 0.75
    )
  end

  it "extends the plan and enqueues another generation job" do
    original_ends_at = plan.ends_at

    expect {
      described_class.call(plan: plan)
    }.to change(SystemJob, :count).by(1)

    expect(plan.reload.ends_at).to be > original_ends_at
    expect(SystemJob.last.payload).to include(
      "training_plan_id" => plan.id,
      "extension" => true
    )
  end

  it "rejects extension when the plan already reached managed threshold" do
    plan.update!(progress_percentage: 80.0, status: :managed)

    expect {
      described_class.call(plan: plan)
    }.to raise_error(TrainingPlans::Extend::NotEligibleError)
  end
end
