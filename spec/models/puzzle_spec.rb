# frozen_string_literal: true

# == Schema Information
#
# Table name: puzzles
#
#  id         :string           not null, primary key
#  difficulty :integer          default("easy"), not null
#  fen        :string           not null
#  metadata   :jsonb            not null
#  motif      :integer          not null
#  rating     :integer
#  solution   :text             not null
#  source     :integer          default("curated"), not null
#  theme      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "rails_helper"

RSpec.describe Puzzle, type: :model do
  subject(:puzzle) { build(:puzzle) }

  describe "associations" do
    it { is_expected.to have_many(:training_assignments).dependent(:nullify) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:source).with_values(curated: 0, user_generated: 1).backed_by_column_of_type(:integer) }
    it { is_expected.to define_enum_for(:difficulty).with_values(easy: 0, medium: 1, hard: 2).backed_by_column_of_type(:integer) }
    it do
      expect(puzzle).to define_enum_for(:theme)
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
      expect(puzzle).to define_enum_for(:motif)
        .with_values(PuzzleMotifable::MOTIFS)
        .backed_by_column_of_type(:integer)
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:fen) }
    it { is_expected.to validate_presence_of(:solution) }
    it { is_expected.to validate_presence_of(:motif) }

    it "rejects invalid motif values" do
      puzzle[:motif] = 99

      expect(puzzle).not_to be_valid
      expect(puzzle.errors[:motif]).to be_present
    end
  end

  describe "ULID primary key" do
    it "assigns a ULID on create" do
      puzzle.save!

      expect(puzzle.id).to match(/\A[0-9A-HJKMNP-TV-Z]{26}\z/)
    end
  end
end
