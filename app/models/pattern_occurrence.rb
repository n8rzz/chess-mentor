# frozen_string_literal: true

# == Schema Information
#
# Table name: pattern_occurrences
#
#  id                           :string           not null, primary key
#  classifier                   :string
#  classifier_version           :string
#  confidence                   :decimal(5, 2)    default(0.75), not null
#  explanation_key              :string
#  metadata                     :jsonb            not null
#  occurred_under_time_pressure :boolean          default(FALSE), not null
#  pattern_taxonomy_version     :string
#  phase                        :integer          not null
#  primary_pattern              :integer          not null
#  secondary_pattern            :integer
#  severity                     :decimal(5, 2)    not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  game_id                      :string           not null
#  move_id                      :string           not null
#  pattern_cycle_id             :string           not null
#  user_id                      :string           not null
#
# Indexes
#
#  index_pattern_occurrences_on_game_id           (game_id)
#  index_pattern_occurrences_on_move_id           (move_id)
#  index_pattern_occurrences_on_pattern_cycle_id  (pattern_cycle_id)
#  index_pattern_occurrences_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#  fk_rails_...  (pattern_cycle_id => pattern_cycles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class PatternOccurrence < ApplicationRecord
  include GamePhaseable

  belongs_to :user
  belongs_to :game
  belongs_to :move
  belongs_to :pattern_cycle

  enum :primary_pattern, Patternable::PATTERNS, validate: true
  enum :secondary_pattern, Patternable::PATTERNS, validate: { allow_nil: true }, prefix: :secondary

  validates :severity, :confidence, :phase, presence: true
  validates :severity, :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def primary_pattern_label
    Patternable::PATTERN_LABELS.fetch(primary_pattern.to_sym)
  end

  def secondary_pattern_label
    return if secondary_pattern.blank?

    Patternable::PATTERN_LABELS.fetch(secondary_pattern.to_sym)
  end
end
