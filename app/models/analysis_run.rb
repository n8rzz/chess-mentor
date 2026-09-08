# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_runs
#
#  id                     :string           not null, primary key
#  analysis_version       :string           not null
#  depth                  :integer          not null
#  depth_critical         :integer          default(20), not null
#  engine_name            :string           not null
#  engine_version         :string           not null
#  error_details          :jsonb
#  error_message          :text
#  finished_at            :datetime
#  metadata               :jsonb            not null
#  metric_formula_version :string           default("1.0.0"), not null
#  multipv                :integer          default(3), not null
#  started_at             :datetime
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  game_id                :string           not null
#  user_id                :string           not null
#
# Indexes
#
#  index_analysis_runs_on_game_id             (game_id)
#  index_analysis_runs_on_user_id             (user_id)
#  index_analysis_runs_on_user_id_and_status  (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class AnalysisRun < ApplicationRecord
  TERMINAL_STATUSES = %w[succeeded partially_succeeded failed cancelled].freeze
  RECENTLY_FINISHED_WINDOW = 5.minutes
  PHASE_LABELS = {
    "scan" => "Scan",
    "deepen" => "Critical deepen",
    "detect" => "Detect",
    "complete" => "Complete"
  }.freeze

  belongs_to :game
  belongs_to :user
  has_many :move_evaluations, dependent: :destroy
  has_many :analysis_events, dependent: :destroy
  has_one :game_metric, dependent: :destroy

  enum :status, {
    pending: 0,
    running: 1,
    succeeded: 2,
    partially_succeeded: 3,
    failed: 4,
    cancelled: 5
  }, default: :pending, validate: true

  validates :engine_name, :engine_version, :analysis_version, :depth, :depth_critical, :multipv, presence: true

  validate :immutable_when_terminal, on: :update

  scope :in_progress, -> { where(status: %i[pending running]) }
  scope :terminal, -> { where(status: TERMINAL_STATUSES.map(&:to_sym)) }
  scope :succeeded, -> { where(status: :succeeded) }
  scope :recently_finished, lambda { |within: RECENTLY_FINISHED_WINDOW|
    where(status: %i[succeeded partially_succeeded])
      .where(finished_at: within.ago..)
  }

  def phase
    metadata["phase"].presence
  end

  def phase_label
    PHASE_LABELS[phase]
  end

  def status_label
    return "Queued" if pending?
    return "Failed" if failed?
    return "Cancelled" if cancelled?
    return "Succeeded" if succeeded? || partially_succeeded?

    detail = progress_detail
    return "#{phase_label} #{detail}" if phase_label.present? && detail.present?

    phase_label.presence || status.to_s.tr("_", " ").capitalize
  end

  def in_progress?
    pending? || running?
  end

  def progress_percent
    return 100 if succeeded? || partially_succeeded?
    return 0 if failed? || cancelled?
    return 5 if pending?
    return running_progress_percent if running?

    0
  end

  def progress_detail
    case phase
    when "scan"
      fraction_label(metadata["moves_done"], metadata["moves_total"])
    when "deepen"
      fraction_label(metadata["pass2_done"], metadata["pass2_total"])
    end
  end

  def recently_finished?(within: RECENTLY_FINISHED_WINDOW)
    return false unless succeeded? || partially_succeeded?
    return false if finished_at.blank?

    finished_at >= within.ago
  end

  private

  def running_progress_percent
    case phase
    when "scan", nil
      scan_progress_percent
    when "deepen"
      deepen_progress_percent
    when "detect"
      92
    when "complete"
      100
    else
      15
    end
  end

  def scan_progress_percent
    done = metadata["moves_done"].to_i
    total = metadata["moves_total"].to_i
    return 20 if total <= 0

    (15 + (done.to_f / total) * 60).round.clamp(15, 75)
  end

  def deepen_progress_percent
    done = metadata["pass2_done"].to_i
    total = metadata["pass2_total"].to_i
    return 80 if total <= 0

    (75 + (done.to_f / total) * 12).round.clamp(75, 88)
  end

  def fraction_label(done, total)
    total_i = total.to_i
    return if total_i <= 0

    "#{done.to_i}/#{total_i}"
  end

  def immutable_when_terminal
    return if new_record?
    return unless status_was.in?(TERMINAL_STATUSES)

    errors.add(:base, "terminal analysis runs cannot be modified")
  end
end
