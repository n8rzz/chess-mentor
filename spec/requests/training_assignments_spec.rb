# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TrainingAssignments", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:training_plan) { create(:training_plan, user: user) }

  describe "GET /training_plans/:training_plan_id/training_assignments/:id" do
    it "renders the puzzle solve board for theme puzzles" do
      assignment = create(:training_assignment, training_plan: training_plan)

      sign_in user
      get training_plan_training_assignment_path(training_plan, assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="puzzle-solve"')
      expect(response.body).to include('data-controller="chess-board"')
      expect(response.body).to include("data-puzzle-solve-fen-value")
      expect(response.body).to include("data-puzzle-solve-solution-line-value")
      expect(response.body).to include("data-puzzle-solve-hint-text-value")
      expect(response.body).to include("data-puzzle-solve-skip-url-value")
      expect(response.body).to include("data-puzzle-solve-complete-url-value")
      expect(response.body).to include("Find the best move.")
      expect(response.body).to include("puzzle-solve#showHint")
    end

    it "renders the position review board for personal assignments" do
      assignment = create(:training_assignment, :personal_review, training_plan: training_plan)
      analysis_run = create(:analysis_run, :succeeded, game: assignment.source_game, user: user)
      create(
        :move_evaluation,
        analysis_run: analysis_run,
        game: assignment.source_game,
        move: assignment.source_move,
        classification: :mistake,
        best_move_uci: "d2d4",
        best_move_san: "d4"
      )

      sign_in user
      get training_plan_training_assignment_path(training_plan, assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="puzzle-solve"')
      expect(response.body).to include("data-puzzle-solve-fen-value")
      expect(response.body).to include('data-puzzle-solve-solution-line-value="d2d4"')
      expect(response.body).to include("data-puzzle-solve-reveal-value")
      expect(response.body).not_to include('data-controller="game-review"')
      expect(response.body).to include("Find the best move.")
      expect(response.body).to include("View full game at this move")
    end

    it "renders a fallback when a theme puzzle assignment has no linked puzzle" do
      assignment = create(:training_assignment, training_plan: training_plan, puzzle: nil)

      sign_in user
      get training_plan_training_assignment_path(training_plan, assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("This puzzle is no longer available.")
      expect(response.body).not_to include('data-controller="chess-board"')
    end

    it "renders text-only assignments without a board" do
      assignment = create(
        :training_assignment,
        training_plan: training_plan,
        assignment_type: :play_game,
        puzzle: nil,
        prompt: "Play a rapid game on Lichess."
      )

      sign_in user
      get training_plan_training_assignment_path(training_plan, assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Play a rapid game on Lichess.")
      expect(response.body).not_to include('data-controller="chess-board"')
    end

    it "does not allow access to another user's assignment" do
      other_plan = create(:training_plan)
      assignment = create(:training_assignment, training_plan: other_plan)

      sign_in user
      get training_plan_training_assignment_path(other_plan, assignment)

      expect(response).to have_http_status(:not_found)
    end
  end
end
