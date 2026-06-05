# frozen_string_literal: true

module PuzzleMotifable
  extend ActiveSupport::Concern

  MOTIFS = {
    fork: 0,
    pin: 1,
    skewer: 2,
    double_attack: 3,
    discovered_attack: 4,
    discovered_check: 5,
    back_rank_mate: 6,
    removal_of_defender: 7,
    deflection: 8,
    decoy: 9,
    overloaded_piece: 10,
    zwischenzug: 11,
    mate_threat: 12,
    undefended_piece: 13,
    sacrifice: 14,
    piece_activity: 15,
    center_control: 16,
    exposed_king: 17,
    castling_break: 18,
    material_loss: 19,
    isolated_pawn: 20,
    passed_pawn: 21,
    king_and_pawn: 22,
    opposition: 23,
    one_move_win: 24,
    forcing_line: 25
  }.freeze

  included do
    enum :motif, MOTIFS, validate: true
  end
end
