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
FactoryBot.define do
  factory :pattern_occurrence do
    user
    game { association :game, user: user }
    move { association :move, game: game }
    pattern_cycle { association :pattern_cycle, user: user, pattern: primary_pattern }
    primary_pattern { :missed_tactics }
    secondary_pattern { nil }
    severity { 0.75 }
    confidence { 0.85 }
    phase { :middlegame }
    occurred_under_time_pressure { false }
    explanation_key { "missed_tactics.v1" }
    metadata { {} }
  end
end
