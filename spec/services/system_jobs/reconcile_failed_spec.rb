# frozen_string_literal: true

require "rails_helper"

RSpec.describe SystemJobs::ReconcileFailed do
  let(:user) { create(:user) }

  it "retries a failed classify_weaknesses job when no active job exists" do
    job = create(:system_job, :classify_weaknesses, :failed, user: user, attempts_count: 1)

    described_class.call

    expect(job.reload).to be_pending
  end

  it "retries a failed generate_training_plan job when assignments are still pending" do
    plan = create(:training_plan, user: user)
    job = create(
      :system_job,
      :generate_training_plan,
      :failed,
      user: user,
      payload: { "training_plan_id" => plan.id },
      attempts_count: 1
    )

    described_class.call

    expect(job.reload).to be_pending
  end

  it "does not retry generate_training_plan when assignments already exist" do
    plan = create(:training_plan, user: user)
    create(:training_assignment, training_plan: plan)
    job = create(
      :system_job,
      :generate_training_plan,
      :failed,
      user: user,
      payload: { "training_plan_id" => plan.id },
      attempts_count: 1
    )

    described_class.call

    expect(job.reload).to be_failed
  end
end
