# frozen_string_literal: true

# Production seed — curated puzzles required for training plan generation in all environments.
# At least 5 puzzles per weakness theme; the generator assigns 5 theme puzzles per day
# for 14 days (70 slots) and reuses puzzles deterministically when the pool is smaller.
puzzles = [
  {
    key: "hanging_pieces_01",
    theme: :hanging_pieces,
    difficulty: :easy,
    motif: :undefended_piece,
    rating: 900,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    solution: "c4f7"
  },
  {
    key: "hanging_pieces_02",
    theme: :hanging_pieces,
    difficulty: :medium,
    motif: :fork,
    rating: 1100,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "f3g5"
  },
  {
    key: "hanging_pieces_03",
    theme: :hanging_pieces,
    difficulty: :easy,
    motif: :undefended_piece,
    rating: 950,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6e4"
  },
  {
    key: "hanging_pieces_04",
    theme: :hanging_pieces,
    difficulty: :medium,
    motif: :skewer,
    rating: 1150,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7"
  },
  {
    key: "hanging_pieces_05",
    theme: :hanging_pieces,
    difficulty: :hard,
    motif: :removal_of_defender,
    rating: 1300,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "c4f7 e8f7 f3g5"
  },
  {
    key: "missed_tactics_01",
    theme: :missed_tactics,
    difficulty: :easy,
    motif: :undefended_piece,
    rating: 1000,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6e4"
  },
  {
    key: "missed_tactics_02",
    theme: :missed_tactics,
    difficulty: :medium,
    motif: :discovered_attack,
    rating: 1200,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7"
  },
  {
    key: "missed_tactics_03",
    theme: :missed_tactics,
    difficulty: :hard,
    motif: :sacrifice,
    rating: 1500,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "c4f7 e8f7 f3g5"
  },
  {
    key: "missed_tactics_04",
    theme: :missed_tactics,
    difficulty: :easy,
    motif: :fork,
    rating: 900,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    solution: "c4f7"
  },
  {
    key: "missed_tactics_05",
    theme: :missed_tactics,
    difficulty: :medium,
    motif: :discovered_check,
    rating: 1250,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "f3g5"
  },
  {
    key: "ignored_threats_01",
    theme: :ignored_threats,
    difficulty: :easy,
    motif: :back_rank_mate,
    rating: 950,
    fen: "6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1",
    solution: "f1f8"
  },
  {
    key: "ignored_threats_02",
    theme: :ignored_threats,
    difficulty: :medium,
    motif: :mate_threat,
    rating: 1150,
    fen: "r3k2r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7 h8h7 d1h5"
  },
  {
    key: "ignored_threats_03",
    theme: :ignored_threats,
    difficulty: :easy,
    motif: :deflection,
    rating: 900,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6g4 h5f7"
  },
  {
    key: "ignored_threats_04",
    theme: :ignored_threats,
    difficulty: :medium,
    motif: :decoy,
    rating: 1100,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "c4f7"
  },
  {
    key: "ignored_threats_05",
    theme: :ignored_threats,
    difficulty: :hard,
    motif: :overloaded_piece,
    rating: 1300,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7 h8h7 d1h5 f1f7"
  },
  {
    key: "opening_development_01",
    theme: :opening_development,
    difficulty: :easy,
    motif: :piece_activity,
    rating: 800,
    fen: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 4",
    solution: "f3g5"
  },
  {
    key: "opening_development_02",
    theme: :opening_development,
    difficulty: :medium,
    motif: :center_control,
    rating: 1050,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "e4d5"
  },
  {
    key: "opening_development_03",
    theme: :opening_development,
    difficulty: :easy,
    motif: :center_control,
    rating: 850,
    fen: "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 4",
    solution: "e4d5"
  },
  {
    key: "opening_development_04",
    theme: :opening_development,
    difficulty: :medium,
    motif: :piece_activity,
    rating: 1000,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "f3g5"
  },
  {
    key: "opening_development_05",
    theme: :opening_development,
    difficulty: :hard,
    motif: :center_control,
    rating: 1200,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d4d5 c6d5"
  },
  {
    key: "king_safety_01",
    theme: :king_safety,
    difficulty: :medium,
    motif: :exposed_king,
    rating: 1100,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6g4 h5g4"
  },
  {
    key: "king_safety_02",
    theme: :king_safety,
    difficulty: :hard,
    motif: :castling_break,
    rating: 1400,
    fen: "r3k2r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7 h8h7 d1h5"
  },
  {
    key: "king_safety_03",
    theme: :king_safety,
    difficulty: :easy,
    motif: :exposed_king,
    rating: 950,
    fen: "6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1",
    solution: "f1f8"
  },
  {
    key: "king_safety_04",
    theme: :king_safety,
    difficulty: :medium,
    motif: :mate_threat,
    rating: 1150,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6g4 h5g4"
  },
  {
    key: "king_safety_05",
    theme: :king_safety,
    difficulty: :hard,
    motif: :castling_break,
    rating: 1350,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "c4f7 e8f7 f3g5"
  },
  {
    key: "bad_trades_01",
    theme: :bad_trades,
    difficulty: :easy,
    motif: :material_loss,
    rating: 900,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    solution: "c4f7"
  },
  {
    key: "bad_trades_02",
    theme: :bad_trades,
    difficulty: :medium,
    motif: :material_loss,
    rating: 1100,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "e4d5 c6d5"
  },
  {
    key: "bad_trades_03",
    theme: :bad_trades,
    difficulty: :easy,
    motif: :undefended_piece,
    rating: 950,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6e4"
  },
  {
    key: "bad_trades_04",
    theme: :bad_trades,
    difficulty: :medium,
    motif: :skewer,
    rating: 1150,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7"
  },
  {
    key: "bad_trades_05",
    theme: :bad_trades,
    difficulty: :hard,
    motif: :sacrifice,
    rating: 1400,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "c4f7 e8f7 f3g5"
  },
  {
    key: "pawn_structure_01",
    theme: :pawn_structure,
    difficulty: :medium,
    motif: :isolated_pawn,
    rating: 1200,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "e4d5 c6d5"
  },
  {
    key: "pawn_structure_02",
    theme: :pawn_structure,
    difficulty: :hard,
    motif: :passed_pawn,
    rating: 1450,
    fen: "8/8/8/4P3/8/8/8/4K3 w - - 0 1",
    solution: "e5e6 e7e5 e6e7"
  },
  {
    key: "pawn_structure_03",
    theme: :pawn_structure,
    difficulty: :easy,
    motif: :isolated_pawn,
    rating: 900,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    solution: "e4d5"
  },
  {
    key: "pawn_structure_04",
    theme: :pawn_structure,
    difficulty: :medium,
    motif: :passed_pawn,
    rating: 1100,
    fen: "8/8/8/4P3/8/8/8/4K3 w - - 0 1",
    solution: "e5e6"
  },
  {
    key: "pawn_structure_05",
    theme: :pawn_structure,
    difficulty: :hard,
    motif: :isolated_pawn,
    rating: 1350,
    fen: "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5",
    solution: "e4d5 c6d5 d1h5"
  },
  {
    key: "endgame_technique_01",
    theme: :endgame_technique,
    difficulty: :easy,
    motif: :king_and_pawn,
    rating: 850,
    fen: "8/8/8/4P3/8/8/8/4K3 w - - 0 1",
    solution: "e5e6"
  },
  {
    key: "endgame_technique_02",
    theme: :endgame_technique,
    difficulty: :medium,
    motif: :opposition,
    rating: 1100,
    fen: "8/8/8/3KP3/8/8/8/3k4 w - - 0 1",
    solution: "e5e6"
  },
  {
    key: "endgame_technique_03",
    theme: :endgame_technique,
    difficulty: :easy,
    motif: :king_and_pawn,
    rating: 800,
    fen: "8/8/8/4P3/8/8/8/4K3 w - - 0 1",
    solution: "e5e6 e7e5 e6e7"
  },
  {
    key: "endgame_technique_04",
    theme: :endgame_technique,
    difficulty: :medium,
    motif: :opposition,
    rating: 1050,
    fen: "8/8/8/3KP3/8/8/8/3k4 w - - 0 1",
    solution: "d5d6"
  },
  {
    key: "endgame_technique_05",
    theme: :endgame_technique,
    difficulty: :hard,
    motif: :king_and_pawn,
    rating: 1250,
    fen: "8/4k3/8/4P3/8/8/8/4K3 w - - 0 1",
    solution: "e5e6"
  },
  {
    key: "time_pressure_01",
    theme: :time_pressure,
    difficulty: :medium,
    motif: :one_move_win,
    rating: 1000,
    fen: "6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1",
    solution: "f1f8"
  },
  {
    key: "time_pressure_02",
    theme: :time_pressure,
    difficulty: :hard,
    motif: :forcing_line,
    rating: 1350,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6g4 h5f7"
  },
  {
    key: "time_pressure_03",
    theme: :time_pressure,
    difficulty: :easy,
    motif: :one_move_win,
    rating: 850,
    fen: "6k1/5ppp/8/8/8/8/5PPP/5RK1 w - - 0 1",
    solution: "f1f8"
  },
  {
    key: "time_pressure_04",
    theme: :time_pressure,
    difficulty: :medium,
    motif: :forcing_line,
    rating: 1050,
    fen: "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 1 4",
    solution: "f6g4"
  },
  {
    key: "time_pressure_05",
    theme: :time_pressure,
    difficulty: :hard,
    motif: :zwischenzug,
    rating: 1300,
    fen: "r2qkb1r/ppp2ppp/2n1n3/3p4/3P4/2NBPN2/PPP3PP/R1BQ1RK1 w - - 0 9",
    solution: "d3h7"
  }
]

puzzles.each do |attrs|
  key = attrs.delete(:key)
  puzzle = Puzzle.find_by("metadata->>'seed_key' = ?", key) || Puzzle.new(source: :curated)
  puzzle.assign_attributes(attrs.merge(metadata: { "seed_key" => key }))
  puzzle.save!
end

puts "Seeded #{puzzles.size} curated puzzles"
