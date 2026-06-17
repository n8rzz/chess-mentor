# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Games", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /games" do
    it "lists the current user's games" do
      game = create(:game, user: user, opponent_username: "rival_one")
      other_game = create(:game, user: other_user, opponent_username: "rival_two")

      sign_in user
      get games_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("rival_one")
      expect(response.body).not_to include("rival_two")
      expect(response.body).to include(game.id)
    end

    it "shows a hint when games are queued for analysis" do
      game = create(:game, user: user)
      create(:analysis_run, game: game, user: user, status: :pending)

      sign_in user
      get games_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1 game queued for analysis")
      expect(response.body).to include("bin/dev")
      expect(response.body).to include("docker compose up worker")
    end

    it "does not show the analysis hint when no games are pending" do
      game = create(:game, user: user)
      create(:analysis_run, :succeeded, game: game, user: user)

      sign_in user
      get games_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("queued for analysis")
    end
  end

  describe "GET /games/:id" do
    it "shows move classifications from the latest succeeded analysis run" do
      game = create(:game, user: user)
      analysis_run = create(:analysis_run, :succeeded, game: game, user: user)
      move = create(:move, game: game, san: "Nf3", played_by_user: true, ply: 3, move_number: 2, color: :white)
      create(
        :move_evaluation,
        analysis_run: analysis_run,
        game: game,
        move: move,
        classification: :mistake,
        centipawn_loss: 150
      )

      sign_in user
      get game_path(game)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nf3")
      expect(response.body).to include("mistake")
      expect(response.body).to include("150")
    end

    it "renders the interactive game review board" do
      game = create(:game, user: user)
      analysis_run = create(:analysis_run, :succeeded, game: game, user: user)
      move = create(:move, game: game, san: "e4", played_by_user: true, ply: 1, move_number: 1, color: :white)
      create(:move_evaluation, analysis_run: analysis_run, game: game, move: move, classification: :good)

      sign_in user
      get game_path(game, ply: move.ply)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="game-review"')
      expect(response.body).to include('data-controller="chess-board"')
      expect(response.body).to include("data-game-review-review-value")
      expect(response.body).to include('data-game-review-initial-ply-value="1"')
      expect(response.body).to include('data-ply="1"')
      expect(response.body).to include("Mistake review")
    end

    it "does not allow access to another user's game" do
      game = create(:game, user: other_user)

      sign_in user
      get game_path(game)

      expect(response).to have_http_status(:not_found)
    end

    it "shows a progress hint when analysis is pending" do
      game = create(:game, user: user)
      create(:analysis_run, game: game, user: user, status: :pending)

      sign_in user
      get game_path(game)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("pending")
      expect(response.body).to include("Analysis is queued or in progress")
    end

    it "shows a progress hint when analysis is running" do
      game = create(:game, user: user)
      create(:analysis_run, :running, game: game, user: user)

      sign_in user
      get game_path(game)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("running")
      expect(response.body).to include("Analysis is queued or in progress")
    end

    it "does not show the progress hint when analysis has succeeded" do
      game = create(:game, user: user)
      create(:analysis_run, :succeeded, game: game, user: user)

      sign_in user
      get game_path(game)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("succeeded")
      expect(response.body).not_to include("Analysis is queued or in progress")
    end
  end
end
