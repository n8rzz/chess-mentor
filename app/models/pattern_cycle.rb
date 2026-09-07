# frozen_string_literal: true

# == Schema Information
#
# Table name: pattern_cycles
#
#  id                     :string           not null, primary key
#  baseline_occurrences   :integer          default(0), not null
#  baseline_severity      :decimal(5, 2)
#  current_occurrences    :integer          default(0), not null
#  current_severity       :decimal(5, 2)
#  cycle_number           :integer          default(1), not null
#  detection_window_days  :integer
#  detection_window_games :integer
#  ended_at               :datetime
#  improvement_percentage :decimal(5, 2)
#  metadata               :jsonb            not null
#  pattern                :integer          not null
#  started_at             :datetime
#  status                 :integer          default("detected"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :string           not null
#
# Indexes
#
#  index_pattern_cycles_on_user_id              (user_id)
#  index_pattern_cycles_on_user_id_and_pattern  (user_id,pattern)
#  index_pattern_cycles_on_user_id_and_status   (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class PatternCycle < ApplicationRecord
  include Patternable

  belongs_to :user
  has_many :pattern_occurrences, dependent: :destroy
  has_many :training_plans, dependent: :destroy
  has_many :progress_snapshots, dependent: :nullify

  enum :status, {
    detected: 0,
    active: 1,
    improving: 2,
    managed: 3,
    archived: 4
  }, default: :detected, validate: true

  validates :cycle_number, numericality: { greater_than: 0 }

  def frequency
    stored = metadata["frequency"]
    return stored.to_f if stored.present?

    return 0.0 if detection_window_games.blank? || detection_window_games.zero?

    current_occurrences.to_f / detection_window_games
  end

  def games_affected
    current_occurrences
  end

  def severity_trend
    return :stable if baseline_severity.blank? || current_severity.blank?

    if current_severity < baseline_severity
      :improving
    elsif current_severity > baseline_severity
      :worsening
    else
      :stable
    end
  end
end
