# frozen_string_literal: true

# == Schema Information
#
# Table name: move_evaluations
#
#  id                  :string           not null, primary key
#  best_move_san       :string
#  best_move_uci       :string
#  candidates          :jsonb            not null
#  centipawn_loss      :integer          not null
#  classification      :integer          not null
#  critical_position   :boolean          default(FALSE), not null
#  criticality_score   :decimal(5, 2)    default(0.0), not null
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
FactoryBot.define do
  factory :move_evaluation do
    analysis_run
    game { analysis_run.game }
    move { association :move, game: game }
    eval_before_cp { 20 }
    eval_after_cp { 15 }
    centipawn_loss { 5 }
    best_move_uci { "e2e4" }
    best_move_san { "e4" }
    principal_variation { "e2e4 e7e5 g1f3" }
    classification { :good }
    depth { AnalysisVersions::DEPTH_SCAN }
    candidates { [] }
    critical_position { false }
    criticality_score { 0 }
    metadata { {} }

    trait :critical do
      critical_position { true }
      criticality_score { 0.75 }
      classification { :mistake }
      centipawn_loss { 120 }
      depth { AnalysisVersions::DEPTH_CRITICAL }
      candidates do
        [
          {
            "rank" => 1,
            "move_uci" => "e2e4",
            "move_san" => "e4",
            "eval_cp" => 40,
            "mate" => nil,
            "pv_san" => "e4 e5"
          },
          {
            "rank" => 2,
            "move_uci" => "d2d4",
            "move_san" => "d4",
            "eval_cp" => -130,
            "mate" => nil,
            "pv_san" => "d4 d5"
          }
        ]
      end
      metadata do
        {
          "pass" => 2,
          "critical_reasons" => %w[candidate_dispersion mistake_cpl],
          "candidate_gap_cp" => 170,
          "played_is_best" => false
        }
      end
    end
  end
end
