# frozen_string_literal: true

# == Schema Information
#
# Table name: candidate_events
#
#  id              :string           not null, primary key
#  confidence      :decimal(5, 2)    not null
#  event_type      :integer          not null
#  metadata        :jsonb            not null
#  severity        :decimal(5, 2)    not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  analysis_run_id :string           not null
#  game_id         :string           not null
#  move_id         :string           not null
#
# Indexes
#
#  index_candidate_events_on_analysis_run_id  (analysis_run_id)
#  index_candidate_events_on_game_id          (game_id)
#  index_candidate_events_on_move_id          (move_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id) ON DELETE => cascade
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :candidate_event do
    analysis_run
    game { analysis_run.game }
    move { association :move, game: game }
    event_type { :tactical }
    severity { 0.75 }
    confidence { 0.85 }
    metadata { {} }
  end
end
