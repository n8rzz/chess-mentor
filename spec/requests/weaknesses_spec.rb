# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Weaknesses", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /weaknesses" do
    it "lists the current user's weakness cycles" do
      cycle = create(:weakness_cycle, :active, user: user, theme: :missed_tactics, current_severity: 0.85)
      create(:weakness_cycle, :active, user: other_user, theme: :hanging_pieces)

      sign_in user
      get weaknesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include(cycle.id)
      expect(response.body).not_to include("Hanging pieces")
    end

    it "shows an empty state when no weaknesses exist" do
      sign_in user
      get weaknesses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No recurring weaknesses detected yet")
    end
  end

  describe "GET /weaknesses/:id" do
    it "shows linked games and moves for a weakness cycle" do
      cycle = create(:weakness_cycle, :active, user: user, theme: :missed_tactics)
      game = create(:game, user: user, opponent_username: "rival_one")
      move = create(:move, game: game, san: "Qh5", played_by_user: true, ply: 5, move_number: 3, color: :white)
      create(:weakness_event, user: user, game: game, move: move, weakness_cycle: cycle, primary_theme: :missed_tactics)

      sign_in user
      get weakness_path(cycle)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include("rival_one")
      expect(response.body).to include("Qh5")
      expect(response.body).to include(game_path(game, ply: move.ply))
    end

    it "does not allow access to another user's weakness cycle" do
      cycle = create(:weakness_cycle, :active, user: other_user)

      sign_in user
      get weakness_path(cycle)

      expect(response).to have_http_status(:not_found)
    end
  end
end
