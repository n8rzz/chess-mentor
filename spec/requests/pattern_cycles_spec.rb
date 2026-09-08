# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PatternCycles", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /pattern_cycles" do
    it "lists the current user's pattern cycles" do
      cycle = create(:pattern_cycle, :active, user: user, pattern: :missed_tactics, current_severity: 0.85)
      create(:pattern_cycle, :active, user: other_user, pattern: :hanging_pieces)

      sign_in user
      get pattern_cycles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include(cycle.id)
      expect(response.body).not_to include("Hanging pieces")
    end

    it "shows an empty state when no patterns exist" do
      sign_in user
      get pattern_cycles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No recurring patterns detected yet")
    end
  end

  describe "GET /pattern_cycles/:id" do
    it "shows linked games and moves for a pattern cycle" do
      cycle = create(:pattern_cycle, :active, user: user, pattern: :missed_tactics)
      game = create(:game, user: user, opponent_username: "rival_one")
      move = create(:move, game: game, san: "Qh5", played_by_user: true, ply: 5, move_number: 3, color: :white)
      create(
        :pattern_occurrence,
        user: user,
        game: game,
        move: move,
        pattern_cycle: cycle,
        primary_pattern: :missed_tactics,
        confidence: 0.86
      )

      sign_in user
      get pattern_cycle_path(cycle)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include("rival_one")
      expect(response.body).to include("Qh5")
      expect(response.body).to include("Confidence")
      expect(response.body).to include("0.86")
      expect(response.body).to include(game_path(game, ply: move.ply))
    end

    it "does not allow access to another user's pattern cycle" do
      cycle = create(:pattern_cycle, :active, user: other_user)

      sign_in user
      get pattern_cycle_path(cycle)

      expect(response).to have_http_status(:not_found)
    end
  end
end
