# frozen_string_literal: true

module ChessBoardHelper
  STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  module_function

  def game_review_data(moves, evaluations_by_move_id)
    {
      starting_fen: moves.first&.fen_before || STARTING_FEN,
      moves: moves.map { |move| move_review_entry(move, evaluations_by_move_id[move.id]) }
    }
  end

  def personal_review_data(move, evaluation)
    {
      starting_fen: move.fen_before,
      moves: [ move_review_entry(move, evaluation) ]
    }
  end

  def personal_review_challenge_data(move, evaluation)
    {
      fen: move.fen_before,
      solution: [ evaluation&.best_move_uci ].compact,
      hint: personal_review_hint(move, evaluation),
      reveal: personal_review_reveal(move, evaluation)
    }
  end

  def puzzle_data(puzzle)
    solution = puzzle.solution.split

    {
      fen: puzzle.fen,
      solution: solution,
      hint: puzzle_hint(puzzle, solution)
    }
  end

  def puzzle_hint(puzzle, solution = puzzle.solution.split)
    {
      text: puzzle_hint_text(puzzle),
      square: solution.first&.slice(0, 2)
    }
  end

  def puzzle_hint_text(puzzle)
    puzzle.metadata["hint"].presence || "Look for a #{puzzle.motif.humanize.downcase}."
  end

  def side_to_move_from_fen(fen)
    fen.split[1] == "b" ? "black" : "white"
  end

  def personal_review_hint(move, evaluation)
    text =
      if evaluation&.classification.present?
        "In the game you played #{move.san} (#{evaluation.classification}). Find a better move."
      else
        "Find the best move from this position."
      end

    { text: text, square: nil }
  end

  def personal_review_reveal(move, evaluation)
    {
      played_san: move.san,
      played_uci: move.uci,
      best_move_uci: evaluation&.best_move_uci,
      best_move_san: evaluation&.best_move_san,
      classification: evaluation&.classification,
      centipawn_loss: evaluation&.centipawn_loss
    }
  end

  def move_review_entry(move, evaluation)
    {
      ply: move.ply,
      san: move.san,
      uci: move.uci,
      fen_before: move.fen_before,
      fen_after: move.fen_after,
      played_by_user: move.played_by_user,
      classification: evaluation&.classification,
      best_move_uci: evaluation&.best_move_uci,
      best_move_san: evaluation&.best_move_san,
      centipawn_loss: evaluation&.centipawn_loss
    }
  end
end
