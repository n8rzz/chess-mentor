# frozen_string_literal: true

require "rails_helper"

RSpec.describe TrainingPlans::Activate do
  let(:user) { create(:user) }
  let(:weakness_cycle) { create(:weakness_cycle, :active, user: user, theme: :missed_tactics, baseline_occurrences: 6, current_occurrences: 6) }

  it "creates an active plan and enqueues generation" do
    expect {
      described_class.call(user: user, weakness_cycle: weakness_cycle)
    }.to change(TrainingPlan, :count).by(1)
      .and change(SystemJob, :count).by(1)

    plan = user.training_plans.active.first
    expect(plan.weakness_cycle).to eq(weakness_cycle)
    expect(plan.theme).to eq("missed_tactics")
    expect(plan.baseline_occurrences).to eq(6)
    expect(plan.improvement_threshold).to eq(0.30)
    expect(plan.managed_threshold).to eq(0.75)

    job = SystemJob.last
    expect(job.job_type).to eq("generate_training_plan")
    expect(job.payload).to eq("training_plan_id" => plan.id)
  end

  it "archives stale recommended plans" do
    stale = create(:training_plan, user: user, status: :recommended)

    described_class.call(user: user, weakness_cycle: weakness_cycle)

    expect(stale.reload).to be_archived
  end

  it "rejects ineligible cycles" do
    archived_cycle = create(:weakness_cycle, :archived, user: user)

    expect {
      described_class.call(user: user, weakness_cycle: archived_cycle)
    }.to raise_error(TrainingPlans::Activate::IneligibleCycleError)
  end

  it "rejects when another active plan exists" do
    create(:training_plan, :active, user: user)

    expect {
      described_class.call(user: user, weakness_cycle: weakness_cycle)
    }.to raise_error(TrainingPlans::Activate::ActivePlanExistsError)
  end
end
