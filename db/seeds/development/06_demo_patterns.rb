# frozen_string_literal: true

# Weakness cycles and events for local weaknesses UI dev (no Stockfish required).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

def find_demo_game(user:, provider_game_id:)
  Game.find_by!(user: user, provider: :lichess, provider_game_id: provider_game_id)
end

def upsert_pattern_cycle(user:, seed_key:, pattern:, status:, games_affected:, window_games: 3, **attrs)
  cycle = PatternCycle.find_or_initialize_by(user: user, pattern: pattern)
  return cycle if cycle.persisted? && cycle.metadata["seed_key"] == seed_key

  frequency = games_affected.to_f / window_games
  cycle.assign_attributes(
    status: status,
    cycle_number: attrs.fetch(:cycle_number, 1),
    baseline_occurrences: games_affected,
    current_occurrences: games_affected,
    baseline_severity: attrs.fetch(:severity, 0.7),
    current_severity: attrs.fetch(:severity, 0.7),
    detection_window_games: window_games,
    detection_window_days: 30,
    started_at: attrs.fetch(:started_at, 2.days.ago),
    metadata: { "seed_key" => seed_key, "frequency" => frequency.round(4) }
  )
  cycle.save!
  cycle
end

def upsert_pattern_occurrence(cycle:, game:, move:, primary_pattern:, **attrs)
  event = PatternOccurrence.find_or_initialize_by(
    pattern_cycle: cycle,
    game: game,
    move: move,
    primary_pattern: primary_pattern
  )
  event.assign_attributes(
    user: cycle.user,
    secondary_pattern: nil,
    severity: attrs.fetch(:severity, 0.7),
    confidence: attrs.fetch(:confidence, 0.85),
    phase: attrs.fetch(:phase, :middlegame),
    occurred_under_time_pressure: attrs.fetch(:occurred_under_time_pressure, false),
    explanation_key: attrs.fetch(:explanation_key, "#{primary_pattern}.v1"),
    classifier: attrs.fetch(:classifier, AnalysisVersions::PATTERN_CLASSIFIER_NAME),
    classifier_version: attrs.fetch(:classifier_version, AnalysisVersions::PATTERN_CLASSIFIER_VERSION),
    pattern_taxonomy_version: attrs.fetch(
      :pattern_taxonomy_version,
      AnalysisVersions::PATTERN_TAXONOMY_VERSION
    ),
    metadata: attrs.fetch(:metadata, { "seed_key" => "demo_pattern_occurrence" })
  )
  event.save!
  event
end

def evidence_for(detection_reason:, played_move:, best_move: nil, **extra)
  {
    "evidence" => {
      "detection_reason" => detection_reason,
      "played_move" => played_move,
      "best_move" => best_move,
      "eval_before_cp" => extra[:eval_before_cp],
      "eval_after_cp" => extra[:eval_after_cp],
      "centipawn_loss" => extra[:centipawn_loss],
      "classification" => extra[:classification],
      "clock_before" => extra[:clock_before],
      "clock_after" => extra[:clock_after],
      "think_time_seconds" => extra[:think_time_seconds],
      "seed_key" => "demo_pattern_occurrence"
    }.compact.merge(extra.fetch(:theme_evidence, {}))
  }
end

def ensure_user_move(game:, ply:, move_number:, san:, uci:, phase: :middlegame, clock_before: nil, clock_after: nil)
  move = Move.find_or_initialize_by(game: game, ply: ply)
  move.assign_attributes(
    move_number: move_number,
    color: game.white? ? 0 : 1,
    san: san,
    uci: uci,
    played_by_user: true,
    phase: phase,
    clock_before: clock_before,
    clock_after: clock_after,
    fen_before: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    fen_after: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  )
  move.save!
  move
end

blitz_game = find_demo_game(user: user, provider_game_id: "demo-blitz-win")
rapid_game = find_demo_game(user: user, provider_game_id: "demo-rapid-loss")
classical_game = find_demo_game(user: user, provider_game_id: "demo-classical-draw")

blitz_mistake = Move.find_by(game: blitz_game, san: "O-O") ||
  ensure_user_move(game: blitz_game, ply: 9, move_number: 5, san: "O-O", uci: "e1g1", phase: :opening)
blitz_blunder = Move.find_by(game: blitz_game, san: "Bg5") ||
  ensure_user_move(
    game: blitz_game, ply: 13, move_number: 7, san: "Bg5", uci: "c1g5", phase: :middlegame,
    clock_before: 95, clock_after: 94
  )
blitz_blunder.update!(clock_before: 95, clock_after: 94) if blitz_blunder.clock_before.blank?
blitz_endgame = Move.find_by(game: blitz_game, san: "Ke2") ||
  ensure_user_move(game: blitz_game, ply: 19, move_number: 36, san: "Ke2", uci: "g1e2", phase: :endgame)
rapid_mistake = ensure_user_move(
  game: rapid_game, ply: 15, move_number: 8, san: "Bxc5", uci: "e3c5", phase: :middlegame,
  clock_before: 240, clock_after: 210
)
classical_inaccuracy = ensure_user_move(
  game: classical_game, ply: 7, move_number: 4, san: "Bh4", uci: "g5h4", phase: :opening
)
conversion_blunder = ensure_user_move(
  game: rapid_game, ply: 31, move_number: 16, san: "Qb4", uci: "a5b4", phase: :middlegame,
  clock_before: 180, clock_after: 150
)

missed_tactics_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_missed_tactics_cycle",
  pattern: :missed_tactics,
  status: :active,
  games_affected: 2,
  severity: 0.73
)
upsert_pattern_occurrence(
  cycle: missed_tactics_cycle,
  game: blitz_game,
  move: blitz_blunder,
  primary_pattern: :missed_tactics,
  severity: 0.78,
  confidence: 0.88,
  phase: :middlegame,
  metadata: evidence_for(
    detection_reason: "missed_tactics.tactical_candidate",
    played_move: "Bg5",
    best_move: "Nd5",
    eval_before_cp: 40,
    eval_after_cp: -120,
    centipawn_loss: 160,
    classification: 2,
    theme_evidence: { "missed_tactic" => true }
  )
)
upsert_pattern_occurrence(
  cycle: missed_tactics_cycle,
  game: rapid_game,
  move: rapid_mistake,
  primary_pattern: :missed_tactics,
  severity: 0.68,
  confidence: 0.82,
  phase: :middlegame,
  metadata: evidence_for(
    detection_reason: "missed_tactics.tactical_candidate",
    played_move: "Bxc5",
    best_move: "Qd4",
    eval_before_cp: 20,
    eval_after_cp: -90,
    centipawn_loss: 110,
    classification: 2
  )
)

# Multi-label: same Bg5 also diagnosed as hanging pieces + moving too quickly.
hanging_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_hanging_pieces_cycle",
  pattern: :hanging_pieces,
  status: :active,
  games_affected: 1,
  severity: 0.72
)
upsert_pattern_occurrence(
  cycle: hanging_cycle,
  game: blitz_game,
  move: blitz_blunder,
  primary_pattern: :hanging_pieces,
  severity: 0.72,
  confidence: 0.91,
  phase: :middlegame,
  occurred_under_time_pressure: false,
  metadata: evidence_for(
    detection_reason: "hanging_pieces.material_or_ignored",
    played_move: "Bg5",
    best_move: "Nd5",
    eval_before_cp: 40,
    eval_after_cp: -120,
    centipawn_loss: 160,
    classification: 2,
    clock_before: 95,
    clock_after: 94,
    think_time_seconds: 1,
    theme_evidence: { "material_lost" => 3 }
  )
)

moving_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_moving_too_quickly_cycle",
  pattern: :moving_too_quickly,
  status: :active,
  games_affected: 1,
  severity: 0.7
)
upsert_pattern_occurrence(
  cycle: moving_cycle,
  game: blitz_game,
  move: blitz_blunder,
  primary_pattern: :moving_too_quickly,
  severity: 0.7,
  confidence: 0.8,
  phase: :middlegame,
  metadata: evidence_for(
    detection_reason: "moving_too_quickly.fast_mistake",
    played_move: "Bg5",
    best_move: "Nd5",
    eval_before_cp: 40,
    eval_after_cp: -120,
    centipawn_loss: 160,
    classification: 2,
    clock_before: 95,
    clock_after: 94,
    think_time_seconds: 1,
    theme_evidence: {
      "increment_seconds" => 0,
      "fast_think_limit_seconds" => 2
    }
  )
)

lost_winning_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_lost_winning_positions_cycle",
  pattern: :lost_winning_positions,
  status: :detected,
  games_affected: 1,
  severity: 0.75
)
upsert_pattern_occurrence(
  cycle: lost_winning_cycle,
  game: rapid_game,
  move: conversion_blunder,
  primary_pattern: :lost_winning_positions,
  severity: 0.75,
  confidence: 0.9,
  phase: :middlegame,
  metadata: evidence_for(
    detection_reason: "lost_winning_positions.winning_to_equal",
    played_move: "Qb4",
    best_move: "Qb6",
    eval_before_cp: 320,
    eval_after_cp: 40,
    centipawn_loss: 280,
    classification: 2,
    theme_evidence: {
      "episode_start_ply" => 27,
      "episode_end_ply" => 31,
      "peak_eval_cp" => 340,
      "final_eval_cp" => 40,
      "eval_drop_cp" => 300,
      "outcome" => "winning_to_equal"
    }
  )
)

king_safety_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_king_safety_cycle",
  pattern: :king_safety,
  status: :active,
  games_affected: 1,
  severity: 0.65
)
upsert_pattern_occurrence(
  cycle: king_safety_cycle,
  game: blitz_game,
  move: blitz_mistake,
  primary_pattern: :king_safety,
  severity: 0.65,
  confidence: 0.7,
  phase: :opening,
  metadata: evidence_for(
    detection_reason: "king_safety.king_safety_event",
    played_move: "O-O",
    theme_evidence: { "signals" => [ "open_king_file" ] }
  )
)

opening_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_opening_development_cycle",
  pattern: :opening_development,
  status: :detected,
  games_affected: 1,
  severity: 0.42
)
upsert_pattern_occurrence(
  cycle: opening_cycle,
  game: classical_game,
  move: classical_inaccuracy,
  primary_pattern: :opening_development,
  severity: 0.42,
  confidence: 0.72,
  phase: :opening,
  metadata: evidence_for(
    detection_reason: "opening_development.delayed_castling",
    played_move: "Bh4",
    theme_evidence: { "signals" => [ "delayed_castling" ] }
  )
)

endgame_cycle = upsert_pattern_cycle(
  user: user,
  seed_key: "demo_endgame_technique_cycle",
  pattern: :endgame_technique,
  status: :detected,
  games_affected: 1,
  severity: 0.58
)
upsert_pattern_occurrence(
  cycle: endgame_cycle,
  game: blitz_game,
  move: blitz_endgame,
  primary_pattern: :endgame_technique,
  severity: 0.58,
  confidence: 0.78,
  phase: :endgame,
  metadata: evidence_for(
    detection_reason: "endgame_technique.phase_mistake",
    played_move: "Ke2",
    eval_before_cp: -20,
    eval_after_cp: -170,
    centipawn_loss: 150,
    classification: 2
  )
)

puts "Seeded demo weakness cycles for #{user.email}: missed tactics, hanging pieces, moving too quickly, " \
     "lost winning positions, king safety, opening development, endgame technique " \
     "(multi-label on Bg5: hanging + moving too quickly + missed tactics)"
