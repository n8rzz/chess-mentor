# frozen_string_literal: true

# == Schema Information
#
# Table name: game_metrics
#
#  id                           :string           not null, primary key
#  average_centipawn_loss       :decimal(8, 2)
#  blunders_count               :integer          default(0), not null
#  critical_accurate_count      :integer          default(0), not null
#  critical_moves_count         :integer          default(0), not null
#  critical_position_accuracy   :decimal(8, 4)
#  fast_move_error_rate         :decimal(8, 4)
#  fast_move_mistakes_count     :integer          default(0), not null
#  fast_moves_count             :integer          default(0), not null
#  inaccuracies_count           :integer          default(0), not null
#  metadata                     :jsonb            not null
#  metric_formula_version       :string           default("1.0.0"), not null
#  mistakes_count               :integer          default(0), not null
#  phase_metrics                :jsonb            not null
#  time_pressure_error_rate     :decimal(8, 4)
#  time_pressure_mistakes_count :integer          default(0), not null
#  time_pressure_moves_count    :integer          default(0), not null
#  user_move_count              :integer          default(0), not null
#  winning_positions_converted  :integer          default(0), not null
#  winning_positions_reached    :integer          default(0), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  analysis_run_id              :string           not null
#  game_id                      :string           not null
#  user_id                      :string           not null
#
# Indexes
#
#  index_game_metrics_on_analysis_run_id                     (analysis_run_id) UNIQUE
#  index_game_metrics_on_game_id                             (game_id)
#  index_game_metrics_on_user_id                             (user_id)
#  index_game_metrics_on_user_id_and_game_id                 (user_id,game_id)
#  index_game_metrics_on_user_id_and_metric_formula_version  (user_id,metric_formula_version)
#
# Foreign Keys
#
#  fk_rails_...  (analysis_run_id => analysis_runs.id) ON DELETE => cascade
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :game_metric do
    user
    game { association :game, user: user }
    analysis_run { association :analysis_run, :succeeded, user: user, game: game }
    metric_formula_version { AnalysisVersions::METRIC_FORMULA_VERSION }
    average_centipawn_loss { 42.5 }
    user_move_count { 20 }
    inaccuracies_count { 3 }
    mistakes_count { 2 }
    blunders_count { 1 }
    phase_metrics do
      {
        "opening" => { "moves" => 8, "acpl" => 20.0, "mistakes" => 0, "blunders" => 0 },
        "middlegame" => { "moves" => 10, "acpl" => 50.0, "mistakes" => 2, "blunders" => 1 },
        "endgame" => { "moves" => 2, "acpl" => 30.0, "mistakes" => 0, "blunders" => 0 }
      }
    end
    winning_positions_reached { 1 }
    winning_positions_converted { 1 }
    time_pressure_moves_count { 4 }
    time_pressure_mistakes_count { 1 }
    time_pressure_error_rate { 0.25 }
    fast_moves_count { 5 }
    fast_move_mistakes_count { 1 }
    fast_move_error_rate { 0.2 }
    critical_moves_count { 3 }
    critical_accurate_count { 2 }
    critical_position_accuracy { 0.6667 }
    metadata { {} }
  end

  factory :review_period_metric do
    user
    review_period { association :review_period, user: user }
    metric_formula_version { AnalysisVersions::METRIC_FORMULA_VERSION }
    games_count { 10 }
    analyzed_games_count { 8 }
    user_move_count { 160 }
    win_rate { 0.5 }
    draw_rate { 0.2 }
    loss_rate { 0.3 }
    average_centipawn_loss { 45.0 }
    mistakes_per_game { 2.5 }
    blunders_per_game { 1.1 }
    phase_metrics { {} }
    winning_positions_reached { 4 }
    winning_positions_converted { 3 }
    conversion_rate { 0.75 }
    time_pressure_moves_count { 20 }
    time_pressure_mistakes_count { 5 }
    time_pressure_error_rate { 0.25 }
    fast_moves_count { 15 }
    fast_move_mistakes_count { 3 }
    fast_move_error_rate { 0.2 }
    critical_moves_count { 12 }
    critical_accurate_count { 8 }
    critical_position_accuracy { 0.6667 }
    metadata { {} }
  end
end
