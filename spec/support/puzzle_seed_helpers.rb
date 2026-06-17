# frozen_string_literal: true

module PuzzleSeedHelpers
  UCI_TOKEN = /\A[a-h][1-8][a-h][1-8][qrbn]?\z/

  module_function

  def side_to_move_from_fen(fen)
    fen.split[1] == "b" ? :black : :white
  end

  def piece_color_on_square(fen, square)
    file_index = "abcdefgh".index(square[0])
    rank_index = square[1].to_i - 1
    ranks = fen.split.first.split("/").reverse

    file_pos = 0
    ranks[rank_index].each_char do |char|
      if char.match?(/\d/)
        file_pos += char.to_i
      else
        return char == char.upcase ? :white : :black if file_pos == file_index

        file_pos += 1
      end
    end

    nil
  end

  def solution_tokens(puzzle)
    puzzle.solution.split
  end

  def assert_valid_puzzle_solution!(puzzle)
    tokens = solution_tokens(puzzle)
    expect(tokens).not_to be_empty

    tokens.each do |token|
      expect(token).to match(UCI_TOKEN), "invalid UCI token #{token.inspect} in #{puzzle.metadata['seed_key']}"
    end

    first_from = tokens.first.slice(0, 2)
    first_mover = piece_color_on_square(puzzle.fen, first_from)
    side_to_move = side_to_move_from_fen(puzzle.fen)

    expect(first_mover).to eq(side_to_move),
      "#{puzzle.metadata['seed_key']}: first move #{tokens.first} does not match FEN side to move (#{side_to_move})"
  end
end

RSpec.configure do |config|
  config.include PuzzleSeedHelpers
end
