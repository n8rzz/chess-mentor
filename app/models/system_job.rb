# frozen_string_literal: true

# Cross-language work queue: Rails enqueues rows; Python worker claims and updates them.
# Sidekiq handles Rails-only async — not Python job execution.
# == Schema Information
#
# Table name: system_jobs
#
#  id             :string           not null, primary key
#  attempts_count :integer          default(0), not null
#  claimed_by     :string
#  error_details  :jsonb
#  error_message  :text
#  finished_at    :datetime
#  job_type       :integer          not null
#  payload        :jsonb            not null
#  result         :jsonb
#  started_at     :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :string           not null
#
# Indexes
#
#  index_system_jobs_on_status_and_created_at   (status,created_at)
#  index_system_jobs_on_user_id                 (user_id)
#  index_system_jobs_on_user_id_and_created_at  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class SystemJob < ApplicationRecord
  MAX_ATTEMPTS = 3

  belongs_to :user

  enum :job_type, {
    import_games: 0,
    analyze_game: 1,
    classify_weaknesses: 2,
    generate_training_plan: 3,
    update_progress_snapshots: 4
  }, validate: true

  enum :status, {
    pending: 0,
    claimed: 1,
    processing: 2,
    succeeded: 3,
    failed: 4,
    cancelled: 5
  }, default: :pending, validate: true

  validate :payload_must_be_hash
  validate :immutable_when_terminal, on: :update

  scope :in_progress, -> { where(status: %i[claimed processing]) }
  scope :terminal, -> { where(status: %i[succeeded failed cancelled]) }

  def cancel!
    raise ArgumentError, "only pending jobs can be cancelled" unless pending?

    update!(status: :cancelled, finished_at: Time.current)
  end

  def retryable?
    failed? && attempts_count < MAX_ATTEMPTS
  end

  private

  def payload_must_be_hash
    if payload.nil?
      errors.add(:payload, "must be present")
    elsif !payload.is_a?(Hash)
      errors.add(:payload, "must be a hash")
    end
  end

  def immutable_when_terminal
    return if new_record?
    return unless status_was.in?(%w[succeeded failed cancelled])

    errors.add(:base, "terminal jobs cannot be modified")
  end
end
