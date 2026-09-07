# frozen_string_literal: true

# == Schema Information
#
# Table name: review_period_metrics
#
#  id                           :string           not null, primary key
#  analyzed_games_count         :integer          default(0), not null
#  average_centipawn_loss       :decimal(8, 2)
#  blunders_per_game            :decimal(8, 4)
#  conversion_rate              :decimal(8, 4)
#  critical_accurate_count      :integer          default(0), not null
#  critical_moves_count         :integer          default(0), not null
#  critical_position_accuracy   :decimal(8, 4)
#  draw_rate                    :decimal(8, 4)
#  fast_move_error_rate         :decimal(8, 4)
#  fast_move_mistakes_count     :integer          default(0), not null
#  fast_moves_count             :integer          default(0), not null
#  games_count                  :integer          default(0), not null
#  loss_rate                    :decimal(8, 4)
#  metadata                     :jsonb            not null
#  metric_formula_version       :string           default("1.0.0"), not null
#  mistakes_per_game            :decimal(8, 4)
#  phase_metrics                :jsonb            not null
#  time_pressure_error_rate     :decimal(8, 4)
#  time_pressure_mistakes_count :integer          default(0), not null
#  time_pressure_moves_count    :integer          default(0), not null
#  user_move_count              :integer          default(0), not null
#  win_rate                     :decimal(8, 4)
#  winning_positions_converted  :integer          default(0), not null
#  winning_positions_reached    :integer          default(0), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  review_period_id             :string           not null
#  user_id                      :string           not null
#
# Indexes
#
#  index_review_period_metrics_on_period_and_formula  (review_period_id,metric_formula_version) UNIQUE
#  index_review_period_metrics_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (review_period_id => review_periods.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe ReviewPeriodMetric, type: :model do
  subject(:review_period_metric) { build(:review_period_metric) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:review_period) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:metric_formula_version) }
    it { is_expected.to validate_numericality_of(:games_count).is_greater_than_or_equal_to(0) }
  end

  it "persists with factory defaults" do
    expect(create(:review_period_metric)).to be_persisted
  end
end
