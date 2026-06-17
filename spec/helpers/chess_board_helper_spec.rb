# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChessBoardHelper, type: :helper do
  describe ".game_review_data" do
    it "builds a review payload with evaluation details" do
      game = create(:game)
      analysis_run = create(:analysis_run, :succeeded, game: game)
      move = create(:move, game: game, san: "Nf3", uci: "g1f3", ply: 3, played_by_user: true)
      evaluation = create(
        :move_evaluation,
        analysis_run: analysis_run,
        game: game,
        move: move,
        classification: :mistake,
        best_move_uci: "d2d4",
        best_move_san: "d4",
        centipawn_loss: 120
      )

      payload = described_class.game_review_data([ move ], { move.id => evaluation })

      expect(payload[:starting_fen]).to eq(move.fen_before)
      expect(payload[:moves].length).to eq(1)
      expect(payload[:moves].first).to include(
        ply: 3,
        san: "Nf3",
        uci: "g1f3",
        played_by_user: true,
        classification: "mistake",
        best_move_uci: "d2d4",
        best_move_san: "d4",
        centipawn_loss: 120
      )
    end

    it "uses the standard starting position when there are no moves" do
      payload = described_class.game_review_data([], {})

      expect(payload[:starting_fen]).to eq(described_class::STARTING_FEN)
      expect(payload[:moves]).to eq([])
    end
  end

  describe ".personal_review_challenge_data" do
    it "builds an interactive challenge payload without revealing the answer in the hint" do
      game = create(:game)
      analysis_run = create(:analysis_run, :succeeded, game: game)
      move = create(:move, game: game, san: "Nf3", uci: "g1f3", ply: 3, played_by_user: true)
      evaluation = create(
        :move_evaluation,
        analysis_run: analysis_run,
        game: game,
        move: move,
        classification: :mistake,
        best_move_uci: "d2d4",
        best_move_san: "d4",
        centipawn_loss: 120
      )

      payload = described_class.personal_review_challenge_data(move, evaluation)

      expect(payload[:fen]).to eq(move.fen_before)
      expect(payload[:solution]).to eq(%w[d2d4])
      expect(payload[:hint]).to eq(
        text: "In the game you played Nf3 (mistake). Find a better move.",
        square: nil
      )
      expect(payload[:reveal]).to include(
        played_san: "Nf3",
        played_uci: "g1f3",
        best_move_uci: "d2d4",
        best_move_san: "d4",
        classification: "mistake",
        centipawn_loss: 120
      )
    end
  end

  describe ".puzzle_data" do
    it "splits the solution into UCI tokens and builds a hint" do
      puzzle = build(:puzzle, solution: "c4f7 e8f7 f3g5", motif: :fork)

      expect(described_class.puzzle_data(puzzle)).to eq(
        fen: puzzle.fen,
        solution: %w[c4f7 e8f7 f3g5],
        hint: {
          text: "Look for a fork.",
          square: "c4"
        }
      )
    end

    it "uses a curated hint from puzzle metadata when present" do
      puzzle = build(
        :puzzle,
        motif: :pin,
        metadata: { "hint" => "The bishop on c4 is pinned." }
      )

      expect(described_class.puzzle_hint_text(puzzle)).to eq("The bishop on c4 is pinned.")
    end
  end
end
