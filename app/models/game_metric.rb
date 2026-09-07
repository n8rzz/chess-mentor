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
class GameMetric < ApplicationRecord
  belongs_to :user
  belongs_to :game
  belongs_to :analysis_run

  validates :metric_formula_version, presence: true
  validates :user_move_count, :inaccuracies_count, :mistakes_count, :blunders_count,
            :winning_positions_reached, :winning_positions_converted,
            :time_pressure_moves_count, :time_pressure_mistakes_count,
            :fast_moves_count, :fast_move_mistakes_count,
            :critical_moves_count, :critical_accurate_count,
            numericality: { greater_than_or_equal_to: 0 }
end
