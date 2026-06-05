# frozen_string_literal: true

# == Schema Information
#
# Table name: move_evaluations
#
#  id                  :string           not null, primary key
#  best_move_san       :string
#  best_move_uci       :string
#  centipawn_loss      :integer          not null
#  classification      :integer          not null
#  depth               :integer          not null
#  eval_after_cp       :integer
#  eval_before_cp      :integer
#  mate_after          :integer
#  mate_before         :integer
#  metadata            :jsonb            not null
#  principal_variation :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  analysis_run_id     :string           not null
#  game_id             :string           not null
#  move_id             :string           not null
#
# Indexes
#
#  index_move_evaluations_on_analysis_run_id              (analysis_run_id)
#  index_move_evaluations_on_analysis_run_id_and_move_id  (analysis_run_id,move_id) UNIQUE
#  index_move_evaluations_on_game_id                      (game_id)
#  index_move_evaluations_on_move_id                      (move_id)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id) ON DELETE => cascade
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#
class MoveEvaluation < ApplicationRecord
  belongs_to :analysis_run
  belongs_to :game
  belongs_to :move

  enum :classification, {
    good: 0,
    inaccuracy: 1,
    mistake: 2,
    blunder: 3
  }, validate: true

  validates :centipawn_loss, :depth, presence: true
  validates :move_id, uniqueness: { scope: :analysis_run_id }
end
