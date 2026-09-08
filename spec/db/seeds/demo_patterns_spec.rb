# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Demo patterns seed" do
  before do
    allow(Rails.env).to receive(:development?).and_return(true)
    load Rails.root.join("db/seeds/development/01_users.rb")
    load Rails.root.join("db/seeds/development/03_demo_games.rb")
    load Rails.root.join("db/seeds/development/06_demo_patterns.rb")
  end

  it "seeds the new theme cycles with evidence-shaped metadata" do
    user = User.find_by!(email: "starship@example.com")

    expect(PatternCycle.where(user: user).pluck(:pattern)).to include(
      "missed_tactics",
      "hanging_pieces",
      "moving_too_quickly",
      "lost_winning_positions",
      "king_safety",
      "opening_development",
      "endgame_technique"
    )

    moving = PatternOccurrence.find_by!(primary_pattern: :moving_too_quickly, user: user)
    expect(moving.confidence).to be >= 0.65
    expect(moving.secondary_pattern).to be_nil
    expect(moving.metadata.dig("evidence", "detection_reason")).to eq("moving_too_quickly.fast_mistake")
    expect(moving.metadata.dig("evidence", "think_time_seconds")).to eq(1)

    lost = PatternOccurrence.find_by!(primary_pattern: :lost_winning_positions, user: user)
    expect(lost.metadata.dig("evidence", "outcome")).to eq("winning_to_equal")
    expect(lost.metadata.dig("evidence", "episode_start_ply")).to be_present
  end

  it "attaches multiple themes to the same demo blunder move" do
    user = User.find_by!(email: "starship@example.com")
    blitz = Game.find_by!(user: user, provider_game_id: "demo-blitz-win")
    blunder = Move.find_by!(game: blitz, san: "Bg5")

    patterns = PatternOccurrence.where(user: user, move: blunder).pluck(:primary_pattern)
    expect(patterns).to include("missed_tactics", "hanging_pieces", "moving_too_quickly")
  end

  it "is idempotent when reloaded" do
    user = User.find_by!(email: "starship@example.com")
    load Rails.root.join("db/seeds/development/06_demo_patterns.rb")

    expect(PatternCycle.where(user: user, pattern: :moving_too_quickly).count).to eq(1)
    expect(PatternOccurrence.where(user: user, primary_pattern: :moving_too_quickly).count).to eq(1)
  end
end
