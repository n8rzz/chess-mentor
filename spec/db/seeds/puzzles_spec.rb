# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Puzzle seeds" do
  before do
    load Rails.root.join("db/seeds/production/01_puzzles.rb")
  end

  it "seeds at least five curated puzzles per weakness theme" do
    WeaknessThemeable::THEMES.each_key do |theme|
      count = Puzzle.curated.where(theme: theme).count
      expect(count).to be >= 5, "expected at least 5 puzzles for #{theme}, got #{count}"
    end
  end

  it "expects Nxe4 for the Italian Qh5 hanging pawn puzzle" do
    puzzle = Puzzle.find_by("metadata->>'seed_key' = ?", "hanging_pieces_03")

    expect(puzzle.solution).to eq("f6e4")
    expect(puzzle.motif).to eq("undefended_piece")
  end

  it "assigns unique seed keys and required metadata" do
    puzzles = Puzzle.curated.where("metadata ? 'seed_key'")

    expect(puzzles.count).to be >= 45

    seed_keys = puzzles.pluck(Arel.sql("metadata->>'seed_key'"))
    expect(seed_keys.uniq.size).to eq(seed_keys.size)

    puzzles.find_each do |puzzle|
      expect(puzzle.fen).to be_present
      expect(puzzle.solution).to be_present
      expect(puzzle.motif).to be_present
      expect(puzzle.difficulty).to be_present
    end
  end

  it "uses valid UCI solution lines aligned with each puzzle FEN" do
    Puzzle.curated.where("metadata ? 'seed_key'").find_each do |puzzle|
      assert_valid_puzzle_solution!(puzzle)
    end
  end
end
