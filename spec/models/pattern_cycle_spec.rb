# frozen_string_literal: true

# == Schema Information
#
# Table name: pattern_cycles
#
#  id                     :string           not null, primary key
#  baseline_occurrences   :integer          default(0), not null
#  baseline_severity      :decimal(5, 2)
#  current_occurrences    :integer          default(0), not null
#  current_severity       :decimal(5, 2)
#  cycle_number           :integer          default(1), not null
#  detection_window_days  :integer
#  detection_window_games :integer
#  ended_at               :datetime
#  improvement_percentage :decimal(5, 2)
#  metadata               :jsonb            not null
#  pattern                :integer          not null
#  started_at             :datetime
#  status                 :integer          default("detected"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :string           not null
#
# Indexes
#
#  index_pattern_cycles_on_user_id              (user_id)
#  index_pattern_cycles_on_user_id_and_pattern  (user_id,pattern)
#  index_pattern_cycles_on_user_id_and_status   (user_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe PatternCycle, type: :model do
  subject(:pattern_cycle) { build(:pattern_cycle) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:pattern_occurrences).dependent(:destroy) }
    it { is_expected.to have_many(:training_plans).dependent(:destroy) }
  end

  describe "enums" do
    it do
      expect(pattern_cycle).to define_enum_for(:status)
        .with_values(detected: 0, active: 1, improving: 2, managed: 3, archived: 4)
        .backed_by_column_of_type(:integer)
        .with_default(:detected)
    end

    it do
      expect(pattern_cycle).to define_enum_for(:pattern)
        .with_values(
          hanging_pieces: 0,
          missed_tactics: 1,
          ignored_threats: 2,
          opening_development: 3,
          king_safety: 4,
          bad_trades: 5,
          pawn_structure: 6,
          endgame_technique: 7,
          time_pressure: 8,
          moving_too_quickly: 9,
          lost_winning_positions: 10
        )
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:cycle_number).is_greater_than(0) }
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      pattern_cycle.save!

      expect(pattern_cycle.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end

  describe "#frequency" do
    it "returns games affected divided by detection window games" do
      cycle = build(:pattern_cycle, current_occurrences: 6, detection_window_games: 30)

      expect(cycle.frequency).to eq(0.2)
    end

    it "prefers the stored metadata frequency when present" do
      cycle = build(:pattern_cycle, current_occurrences: 99, detection_window_games: 12, metadata: { "frequency" => 0.5 })

      expect(cycle.frequency).to eq(0.5)
    end
  end

  describe "#severity_trend" do
    it "returns improving when current severity is below baseline" do
      cycle = build(:pattern_cycle, baseline_severity: 0.8, current_severity: 0.5)

      expect(cycle.severity_trend).to eq(:improving)
    end
  end
end
