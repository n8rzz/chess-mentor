# frozen_string_literal: true

# == Schema Information
#
# Table name: training_plans
#
#  id                    :string           not null, primary key
#  baseline_occurrences  :integer          default(0), not null
#  completed_at          :datetime
#  current_occurrences   :integer          default(0), not null
#  ends_at               :datetime
#  improvement_threshold :decimal(5, 2)
#  managed_threshold     :decimal(5, 2)
#  metadata              :jsonb            not null
#  progress_percentage   :decimal(5, 2)
#  starts_at             :datetime
#  status                :integer          default("recommended"), not null
#  theme                 :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :string           not null
#  weakness_cycle_id     :string           not null
#
# Indexes
#
#  index_training_plans_on_user_id             (user_id)
#  index_training_plans_on_user_id_and_status  (user_id,status)
#  index_training_plans_on_weakness_cycle_id   (weakness_cycle_id)
#  index_training_plans_one_active_per_user    (user_id) UNIQUE WHERE (status = 1)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (weakness_cycle_id => weakness_cycles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe TrainingPlan, type: :model do
  subject(:training_plan) { build(:training_plan) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:weakness_cycle) }
    it { is_expected.to have_many(:training_assignments).dependent(:destroy) }
  end

  describe "enums" do
    it do
      expect(training_plan).to define_enum_for(:status)
        .with_values(
          recommended: 0,
          active: 1,
          paused: 2,
          improving: 3,
          managed: 4,
          completed: 5,
          archived: 6
        )
        .backed_by_column_of_type(:integer)
        .with_default(:recommended)
    end
  end

  describe "validations" do
    it "allows only one active plan per user" do
      user = create(:user)
      create(:training_plan, :active, user: user)
      duplicate = build(:training_plan, :active, user: user)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:status]).to include("only one active training plan allowed per user")
    end

    it "allows multiple recommended plans per user" do
      user = create(:user)
      create(:training_plan, user: user, status: :recommended)
      second = build(:training_plan, user: user, status: :recommended)

      expect(second).to be_valid
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      training_plan.save!

      expect(training_plan.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end

  describe "defaults and helpers" do
    it "applies default thresholds on create" do
      plan = create(:training_plan, improvement_threshold: nil, managed_threshold: nil)

      expect(plan.improvement_threshold).to eq(0.30)
      expect(plan.managed_threshold).to eq(0.75)
    end

    it "computes days remaining and due assignments" do
      plan = create(:training_plan, :active, ends_at: 3.days.from_now)
      create(:training_assignment, training_plan: plan, due_on: Date.current, status: :pending)
      create(:training_assignment, training_plan: plan, due_on: 2.days.from_now, status: :pending)

      expect(plan.days_remaining).to eq(3)
      expect(plan.due_assignments.count).to eq(1)
      expect(plan.generation_pending?).to be(false)
    end

    it "detects extension eligibility" do
      eligible = build(:training_plan, :active, ends_at: 1.day.ago, progress_percentage: 20.0)
      managed = build(:training_plan, status: :managed, ends_at: 1.day.ago, progress_percentage: 80.0)

      expect(eligible.eligible_for_extension?).to be(true)
      expect(managed.eligible_for_extension?).to be(false)
    end
  end
end
