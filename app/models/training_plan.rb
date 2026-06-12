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
class TrainingPlan < ApplicationRecord
  include WeaknessThemeable

  DEFAULT_IMPROVEMENT_THRESHOLD = 0.30
  DEFAULT_MANAGED_THRESHOLD = 0.75
  PLAN_DURATION_DAYS = 14

  belongs_to :user
  belongs_to :weakness_cycle
  has_many :training_assignments, dependent: :destroy
  has_many :progress_snapshots, dependent: :nullify

  enum :status, {
    recommended: 0,
    active: 1,
    paused: 2,
    improving: 3,
    managed: 4,
    completed: 5,
    archived: 6
  }, default: :recommended, validate: true

  scope :active_for, -> { where(status: :active) }
  scope :current_for, -> { where(status: %i[active paused improving managed]) }

  before_validation :apply_default_thresholds, on: :create

  validate :only_one_active_plan_per_user, on: :create

  def reduction_percentage
    progress_percentage.to_f
  end

  def days_remaining
    return nil if ends_at.blank?

    (ends_at.to_date - Date.current).to_i
  end

  def due_assignments
    training_assignments.pending.where(due_on: ..Date.current)
  end

  def assignments_for_today
    training_assignments.where(due_on: Date.current)
  end

  def generation_pending?
    training_assignments.none?
  end

  def eligible_for_extension?
    ends_at.present? &&
      ends_at.to_date < Date.current &&
      !managed? &&
      !completed? &&
      !archived? &&
      (active? || improving?)
  end

  private

  def apply_default_thresholds
    self.improvement_threshold ||= DEFAULT_IMPROVEMENT_THRESHOLD
    self.managed_threshold ||= DEFAULT_MANAGED_THRESHOLD
  end

  def only_one_active_plan_per_user
    return unless active?
    return unless self.class.where(user_id: user_id, status: :active).exists?

    errors.add(:status, "only one active training plan allowed per user")
  end
end
