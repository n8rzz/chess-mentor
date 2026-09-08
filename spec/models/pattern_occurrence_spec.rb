# frozen_string_literal: true

# == Schema Information
#
# Table name: pattern_occurrences
#
#  id                           :string           not null, primary key
#  classifier                   :string
#  classifier_version           :string
#  confidence                   :decimal(5, 2)    default(0.75), not null
#  explanation_key              :string
#  metadata                     :jsonb            not null
#  occurred_under_time_pressure :boolean          default(FALSE), not null
#  pattern_taxonomy_version     :string
#  phase                        :integer          not null
#  primary_pattern              :integer          not null
#  secondary_pattern            :integer
#  severity                     :decimal(5, 2)    not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  game_id                      :string           not null
#  move_id                      :string           not null
#  pattern_cycle_id             :string           not null
#  user_id                      :string           not null
#
# Indexes
#
#  index_pattern_occurrences_on_game_id           (game_id)
#  index_pattern_occurrences_on_move_id           (move_id)
#  index_pattern_occurrences_on_pattern_cycle_id  (pattern_cycle_id)
#  index_pattern_occurrences_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#  fk_rails_...  (pattern_cycle_id => pattern_cycles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe PatternOccurrence, type: :model do
  subject(:pattern_occurrence) { build(:pattern_occurrence) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:move) }
    it { is_expected.to belong_to(:pattern_cycle) }
  end

  describe "enums" do
    it do
      expect(pattern_occurrence).to define_enum_for(:primary_pattern)
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

    it do
      expect(pattern_occurrence).to define_enum_for(:phase)
        .with_values(opening: 0, middlegame: 1, endgame: 2)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:confidence) }
    it { is_expected.to validate_presence_of(:phase) }
    it { is_expected.to validate_numericality_of(:severity).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }
    it { is_expected.to validate_numericality_of(:confidence).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }

    it "rejects invalid phase values" do
      pattern_occurrence[:phase] = 99

      expect(pattern_occurrence).not_to be_valid
      expect(pattern_occurrence.errors[:phase]).to be_present
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      pattern_occurrence.save!

      expect(pattern_occurrence.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end

  describe "theme labels" do
    it "returns human-readable primary and secondary theme labels" do
      event = build(:pattern_occurrence, primary_pattern: :missed_tactics, secondary_pattern: :time_pressure)

      expect(event.primary_pattern_label).to eq("Missed tactics")
      expect(event.secondary_pattern_label).to eq("Time pressure")
    end
  end
end
