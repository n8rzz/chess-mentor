# frozen_string_literal: true

# Analysis runs, moves, evaluations, and candidate events for local games UI dev.
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

import_batch = ImportBatch.find_by("metadata->>'seed_key' = ?", "demo_import_batch")
return unless import_batch

def find_demo_game(user:, provider_game_id:)
  Game.find_by!(user: user, provider: :lichess, provider_game_id: provider_game_id)
end

def upsert_analysis_run(game:, seed_key:, status:, **attrs)
  existing = AnalysisRun.find_by("metadata->>'seed_key' = ?", seed_key)
  return existing if existing

  extra_metadata = attrs.delete(:metadata) || {}
  AnalysisRun.create!(
    game: game,
    user: game.user,
    status: status,
    engine_name: AnalysisRuns::BulkEnqueueForImport::DEFAULT_ENGINE_NAME,
    engine_version: AnalysisRuns::BulkEnqueueForImport::DEFAULT_ENGINE_VERSION,
    analysis_version: AnalysisRuns::BulkEnqueueForImport::DEFAULT_ANALYSIS_VERSION,
    depth: AnalysisRuns::BulkEnqueueForImport::DEFAULT_DEPTH,
    depth_critical: AnalysisRuns::BulkEnqueueForImport::DEFAULT_DEPTH_CRITICAL,
    multipv: AnalysisRuns::BulkEnqueueForImport::DEFAULT_MULTIPV,
    metadata: {
      "seed_key" => seed_key,
      "import_batch_id" => game.import_batch_id
    }.merge(extra_metadata.deep_stringify_keys),
    **attrs
  )
end

def upsert_move(game:, ply:, move_number:, color:, san:, uci:, played_by_user:, phase: nil)
  move = Move.find_or_initialize_by(game: game, ply: ply)
  move.assign_attributes(
    move_number: move_number,
    color: color,
    san: san,
    uci: uci,
    played_by_user: played_by_user,
    phase: phase || demo_phase_for(move_number),
    fen_before: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    fen_after: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  )
  move.save!
  move
end

def demo_phase_for(move_number)
  return :opening if move_number <= 6
  return :middlegame if move_number <= 20

  :endgame
end


def upsert_move_evaluation(analysis_run:, move:, classification:, centipawn_loss:, **attrs)
  evaluation = MoveEvaluation.find_or_initialize_by(analysis_run: analysis_run, move: move)
  evaluation.assign_attributes(
    game: analysis_run.game,
    classification: classification,
    centipawn_loss: centipawn_loss,
    depth: attrs.fetch(:depth, analysis_run.depth),
    eval_before_cp: attrs.fetch(:eval_before_cp, 20),
    eval_after_cp: attrs.fetch(:eval_after_cp, 20 - centipawn_loss),
    best_move_san: attrs[:best_move_san],
    best_move_uci: attrs[:best_move_uci],
    principal_variation: attrs[:principal_variation],
    candidates: attrs.fetch(:candidates, []),
    critical_position: attrs.fetch(:critical_position, false),
    criticality_score: attrs.fetch(:criticality_score, 0),
    metadata: attrs.fetch(:metadata, {})
  )
  evaluation.save!
  evaluation
end

blitz_game = find_demo_game(user: user, provider_game_id: "demo-blitz-win")
succeeded_run = upsert_analysis_run(
  game: blitz_game,
  seed_key: "demo_blitz_analysis_succeeded",
  status: :succeeded,
  started_at: 8.minutes.ago,
  finished_at: 5.minutes.ago,
  metadata: {
    "phase" => "complete",
    "phase_classifier_version" => AnalysisVersions::PHASE_CLASSIFIER_VERSION
  }
)

blitz_moves = [
  { ply: 1, move_number: 1, color: :white, san: "e4", uci: "e2e4", played_by_user: true },
  { ply: 2, move_number: 1, color: :black, san: "e5", uci: "e7e5", played_by_user: false },
  { ply: 3, move_number: 2, color: :white, san: "Nf3", uci: "g1f3", played_by_user: true },
  { ply: 4, move_number: 2, color: :black, san: "Nc6", uci: "b8c6", played_by_user: false },
  { ply: 5, move_number: 3, color: :white, san: "Bc4", uci: "f1c4", played_by_user: true },
  { ply: 6, move_number: 3, color: :black, san: "Nf6", uci: "g8f6", played_by_user: false },
  { ply: 7, move_number: 4, color: :white, san: "d3", uci: "d2d3", played_by_user: true },
  { ply: 8, move_number: 4, color: :black, san: "Be7", uci: "f8e7", played_by_user: false },
  { ply: 9, move_number: 5, color: :white, san: "O-O", uci: "e1g1", played_by_user: true },
  { ply: 10, move_number: 5, color: :black, san: "O-O", uci: "e8g8", played_by_user: false },
  { ply: 11, move_number: 6, color: :white, san: "Nc3", uci: "b1c3", played_by_user: true },
  { ply: 12, move_number: 6, color: :black, san: "d6", uci: "d7d6", played_by_user: false },
  { ply: 13, move_number: 7, color: :white, san: "Bg5", uci: "c1g5", played_by_user: true },
  { ply: 14, move_number: 7, color: :black, san: "h6", uci: "h7h6", played_by_user: false },
  { ply: 15, move_number: 8, color: :white, san: "Bxf6", uci: "g5f6", played_by_user: true },
  { ply: 16, move_number: 8, color: :black, san: "Bxf6", uci: "e7f6", played_by_user: false },
  { ply: 17, move_number: 9, color: :white, san: "Nd5", uci: "f3d5", played_by_user: true },
  # Illustrative late plies so local UI can show all three game phases.
  { ply: 18, move_number: 35, color: :black, san: "Kf8", uci: "g8f8", played_by_user: false, phase: :endgame },
  { ply: 19, move_number: 36, color: :white, san: "Ke2", uci: "g1e2", played_by_user: true, phase: :endgame }
]

seeded_moves = blitz_moves.map { |attrs| upsert_move(game: blitz_game, **attrs) }
user_moves = seeded_moves.select(&:played_by_user?)

evaluation_specs = [
  { classification: :good, centipawn_loss: 8 },
  { classification: :good, centipawn_loss: 12 },
  { classification: :inaccuracy, centipawn_loss: 45, best_move_san: "Bb5", best_move_uci: "c4b5" },
  { classification: :good, centipawn_loss: 10 },
  { classification: :mistake, centipawn_loss: 95, best_move_san: "Re1", best_move_uci: "f1e1" },
  { classification: :good, centipawn_loss: 6 },
  {
    classification: :blunder,
    centipawn_loss: 220,
    best_move_san: "Bxf7+",
    best_move_uci: "c4f7",
    depth: AnalysisVersions::DEPTH_CRITICAL,
    critical_position: true,
    criticality_score: 0.8,
    candidates: [
      {
        "rank" => 1,
        "move_uci" => "c4f7",
        "move_san" => "Bxf7+",
        "eval_cp" => 210,
        "mate" => nil,
        "pv_san" => "Bxf7+ Kxf7"
      },
      {
        "rank" => 2,
        "move_uci" => "c1g5",
        "move_san" => "Bg5",
        "eval_cp" => 20,
        "mate" => nil,
        "pv_san" => "Bg5 h6"
      }
    ],
    metadata: {
      "pass" => 2,
      "critical_reasons" => %w[blunder_cpl candidate_dispersion],
      "candidate_gap_cp" => 190,
      "played_is_best" => false,
      "scan_depth" => AnalysisVersions::DEPTH_SCAN
    }
  },
  { classification: :good, centipawn_loss: 14 },
  { classification: :good, centipawn_loss: 5 },
  {
    classification: :mistake,
    centipawn_loss: 120,
    best_move_san: "Kd2",
    best_move_uci: "e1d2",
    metadata: { "seed_key" => "demo_endgame_mistake" }
  }
]

user_moves.zip(evaluation_specs).each do |move, spec|
  upsert_move_evaluation(analysis_run: succeeded_run, move: move, **spec)
end

mistake_move = user_moves[4]
AnalysisEvent.find_or_initialize_by(
  analysis_run: succeeded_run,
  move: mistake_move,
  event_type: :king_safety
).tap do |event|
  event.assign_attributes(
    game: blitz_game,
    severity: 0.72,
    confidence: 0.81,
    metadata: { "seed_key" => "demo_king_safety_event", "signal" => "king_exposed_after_castling" }
  )
  event.save!
end

critical_move = user_moves[6]
AnalysisEvent.find_or_initialize_by(
  analysis_run: succeeded_run,
  move: critical_move,
  event_type: :critical_position
).tap do |event|
  event.assign_attributes(
    game: blitz_game,
    severity: 0.8,
    confidence: 0.9,
    metadata: {
      "seed_key" => "demo_critical_position_event",
      "criticality_score" => 0.8,
      "reasons" => %w[blunder_cpl candidate_dispersion],
      "candidate_gap_cp" => 190
    }
  )
  event.save!
end

partial_game = find_demo_game(user: user, provider_game_id: "demo-blitz-win")
partial_run = upsert_analysis_run(
  game: partial_game,
  seed_key: "demo_blitz_analysis_partial",
  status: :running,
  started_at: 3.minutes.ago
)

partial_moves = blitz_moves.map { |attrs| upsert_move(game: partial_game, **attrs) }
partial_user_moves = partial_moves.select(&:played_by_user?)

partial_user_moves.first(3).zip(evaluation_specs.first(3)).each do |move, spec|
  upsert_move_evaluation(analysis_run: partial_run, move: move, **spec)
end

partial_user_moves.first(2).each do |move|
  AnalysisEvent.find_or_initialize_by(
    analysis_run: partial_run,
    move: move,
    event_type: :tactical
  ).tap do |event|
    event.assign_attributes(
      game: partial_game,
      severity: 0.55,
      confidence: 0.75,
      metadata: { "seed_key" => "demo_partial_tactical_event" }
    )
    event.save!
  end
end

unless SystemJob.analyze_game.exists?([ "payload->>'analysis_run_id' = ?", partial_run.id ])
  SystemJobs::Create.call(
    user: user,
    job_type: :analyze_game,
    payload: {
      "analysis_run_id" => partial_run.id,
      "game_id" => partial_game.id
    }
  )
end

rapid_game = find_demo_game(user: user, provider_game_id: "demo-rapid-loss")
pending_run = upsert_analysis_run(
  game: rapid_game,
  seed_key: "demo_rapid_analysis_pending",
  status: :pending
)

unless SystemJob.analyze_game.exists?([ "payload->>'analysis_run_id' = ?", pending_run.id ])
  SystemJobs::Create.call(
    user: user,
    job_type: :analyze_game,
    payload: {
      "analysis_run_id" => pending_run.id,
      "game_id" => rapid_game.id
    }
  )
end

classical_game = find_demo_game(user: user, provider_game_id: "demo-classical-draw")
upsert_analysis_run(
  game: classical_game,
  seed_key: "demo_classical_analysis_failed",
  status: :failed,
  started_at: 12.minutes.ago,
  finished_at: 10.minutes.ago,
  error_message: "Stockfish engine timed out after 120 seconds",
  error_details: { "code" => "engine_timeout", "timeout_seconds" => 120 }
)

import_batch.update!(
  metadata: import_batch.metadata.merge("analysis_enqueued_at" => 15.minutes.ago.iso8601)
)

puts "Seeded demo analysis for #{user.email}: succeeded (blitz), partial/running (blitz retry), pending (rapid), failed (classical)"
