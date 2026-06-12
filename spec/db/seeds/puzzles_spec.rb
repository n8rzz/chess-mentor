# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Puzzle seeds" do
  before do
    load Rails.root.join("db/seeds/02_puzzles.rb")
  end

  it "seeds at least five curated puzzles per weakness theme" do
    WeaknessThemeable::THEMES.each_key do |theme|
      count = Puzzle.curated.where(theme: theme).count
      expect(count).to be >= 5, "expected at least 5 puzzles for #{theme}, got #{count}"
    end
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
end
