# frozen_string_literal: true

# == Schema Information
#
# Table name: moves
#
#  id             :string           not null, primary key
#  clock_after    :integer
#  clock_before   :integer
#  color          :integer          not null
#  fen_after      :string           not null
#  fen_before     :string           not null
#  move_number    :integer          not null
#  played_by_user :boolean          default(FALSE), not null
#  ply            :integer          not null
#  san            :string           not null
#  uci            :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_id        :string           not null
#
# Indexes
#
#  index_moves_on_game_id          (game_id)
#  index_moves_on_game_id_and_ply  (game_id,ply) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Move, type: :model do
  subject(:move) { build(:move) }

  describe "associations" do
    it { is_expected.to belong_to(:game) }
    it { is_expected.to have_one(:move_evaluation).dependent(:destroy) }
    it { is_expected.to have_many(:candidate_events).dependent(:destroy) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:color).with_values(white: 0, black: 1).backed_by_column_of_type(:integer) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:ply) }
    it { is_expected.to validate_presence_of(:move_number) }
    it { is_expected.to validate_presence_of(:san) }
    it { is_expected.to validate_presence_of(:uci) }
    it { is_expected.to validate_presence_of(:fen_before) }
    it { is_expected.to validate_presence_of(:fen_after) }

    it "requires a unique ply per game" do
      existing = create(:move, ply: 3)
      duplicate = build(:move, game: existing.game, ply: 3)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:ply]).to include("has already been taken")
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      move.save!

      expect(move.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
