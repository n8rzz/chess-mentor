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
require "rails_helper"

RSpec.describe GameMetric, type: :model do
  subject(:game_metric) { build(:game_metric) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:analysis_run) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:metric_formula_version) }
    it { is_expected.to validate_numericality_of(:user_move_count).is_greater_than_or_equal_to(0) }
  end

  it "persists with factory defaults" do
    expect(create(:game_metric)).to be_persisted
  end
end
