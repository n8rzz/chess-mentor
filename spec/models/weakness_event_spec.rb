# frozen_string_literal: true

# == Schema Information
#
# Table name: weakness_events
#
#  id                           :string           not null, primary key
#  explanation_key              :string
#  metadata                     :jsonb            not null
#  occurred_under_time_pressure :boolean          default(FALSE), not null
#  phase                        :integer          not null
#  primary_theme                :integer          not null
#  secondary_theme              :integer
#  severity                     :decimal(5, 2)    not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  game_id                      :string           not null
#  move_id                      :string           not null
#  user_id                      :string           not null
#  weakness_cycle_id            :string           not null
#
# Indexes
#
#  index_weakness_events_on_game_id            (game_id)
#  index_weakness_events_on_move_id            (move_id)
#  index_weakness_events_on_user_id            (user_id)
#  index_weakness_events_on_weakness_cycle_id  (weakness_cycle_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#  fk_rails_...  (move_id => moves.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#  fk_rails_...  (weakness_cycle_id => weakness_cycles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe WeaknessEvent, type: :model do
  subject(:weakness_event) { build(:weakness_event) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:game) }
    it { is_expected.to belong_to(:move) }
    it { is_expected.to belong_to(:weakness_cycle) }
  end

  describe "enums" do
    it do
      expect(weakness_event).to define_enum_for(:primary_theme)
        .with_values(
          hanging_pieces: 0,
          missed_tactics: 1,
          ignored_threats: 2,
          opening_development: 3,
          king_safety: 4,
          bad_trades: 5,
          pawn_structure: 6,
          endgame_technique: 7,
          time_pressure: 8
        )
        .backed_by_column_of_type(:integer)
    end

    it do
      expect(weakness_event).to define_enum_for(:phase)
        .with_values(opening: 0, middlegame: 1, endgame: 2)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:severity) }
    it { is_expected.to validate_presence_of(:phase) }
    it { is_expected.to validate_numericality_of(:severity).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(1) }

    it "rejects invalid phase values" do
      weakness_event[:phase] = 99

      expect(weakness_event).not_to be_valid
      expect(weakness_event.errors[:phase]).to be_present
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      weakness_event.save!

      expect(weakness_event.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
