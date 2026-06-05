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
FactoryBot.define do
  factory :weakness_event do
    user
    game { association :game, user: user }
    move { association :move, game: game }
    weakness_cycle { association :weakness_cycle, user: user, theme: primary_theme }
    primary_theme { :missed_tactics }
    secondary_theme { :ignored_threats }
    severity { 0.75 }
    phase { :middlegame }
    occurred_under_time_pressure { false }
    explanation_key { "missed_tactics.v1" }
    metadata { {} }
  end
end
