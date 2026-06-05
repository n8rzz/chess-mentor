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
class CandidateEvent < ApplicationRecord
  belongs_to :analysis_run
  belongs_to :game
  belongs_to :move

  enum :event_type, {
    material: 0,
    tactical: 1,
    threat: 2,
    king_safety: 3,
    pawn_structure: 4,
    endgame_phase: 5,
    time_pressure: 6
  }, validate: true

  validates :severity, :confidence, presence: true
  validates :severity, :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
end
