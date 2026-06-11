# frozen_string_literal: true

# == Schema Information
#
# Table name: weakness_events
#
#  id                           :string           not null, primary key
#  explanation_key              :string
#  metadata                     :jsonb            not null
#  occurred_under_time_pressure :boolean          default(FALSE), not null
#  phase                        :integer          not null
#  primary_theme                :integer          not null
#  secondary_theme              :integer
#  severity                     :decimal(5, 2)    not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  game_id                      :string           not null
#  move_id                      :string           not null
#  user_id                      :string           not null
#  weakness_cycle_id            :string           not null
#
# Indexes
#
#  index_weakness_events_on_game_id            (game_id)
#  index_weakness_events_on_move_id            (move_id)
#  index_weakness_events_on_user_id            (user_id)
#  index_weakness_events_on_weakness_cycle_id  (weakness_cycle_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (weakness_cycle_id => weakness_cycles.id) ON DELETE => cascade
#
class WeaknessEvent < ApplicationRecord
  include GamePhaseable

  belongs_to :user
  belongs_to :game
  belongs_to :move
  belongs_to :weakness_cycle

  enum :primary_theme, WeaknessThemeable::THEMES, validate: true
  enum :secondary_theme, WeaknessThemeable::THEMES, validate: { allow_nil: true }, prefix: :secondary

  validates :severity, :phase, presence: true
  validates :severity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def primary_theme_label
    WeaknessThemeable::THEME_LABELS.fetch(primary_theme.to_sym)
  end

  def secondary_theme_label
    return if secondary_theme.blank?

    WeaknessThemeable::THEME_LABELS.fetch(secondary_theme.to_sym)
  end
end
