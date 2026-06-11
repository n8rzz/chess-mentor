# frozen_string_literal: true

# Weakness cycles and events for local weaknesses UI dev (no Stockfish required).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

def find_demo_game(user:, provider_game_id:)
  Game.find_by!(user: user, provider: :lichess, provider_game_id: provider_game_id)
end

def upsert_weakness_cycle(user:, seed_key:, theme:, status:, games_affected:, window_games: 3, **attrs)
  cycle = WeaknessCycle.find_or_initialize_by(user: user, theme: theme)
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

def upsert_weakness_event(cycle:, game:, move:, primary_theme:, **attrs)
  event = WeaknessEvent.find_or_initialize_by(
    weakness_cycle: cycle,
    game: game,
    move: move,
    primary_theme: primary_theme
  )
  event.assign_attributes(
    user: cycle.user,
    secondary_theme: attrs[:secondary_theme],
    severity: attrs.fetch(:severity, 0.7),
    phase: attrs.fetch(:phase, :middlegame),
    occurred_under_time_pressure: attrs.fetch(:occurred_under_time_pressure, false),
    explanation_key: attrs.fetch(:explanation_key, "#{primary_theme}.v1"),
    metadata: attrs.fetch(:metadata, { "seed_key" => "demo_weakness_event" })
  )
  event.save!
  event
end

def ensure_user_move(game:, ply:, move_number:, san:, uci:)
  move = Move.find_or_initialize_by(game: game, ply: ply)
  move.assign_attributes(
    move_number: move_number,
    color: game.white? ? 0 : 1,
    san: san,
    uci: uci,
    played_by_user: true,
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
  ensure_user_move(game: blitz_game, ply: 9, move_number: 5, san: "O-O", uci: "e1g1")
blitz_blunder = Move.find_by(game: blitz_game, san: "Bg5") ||
  ensure_user_move(game: blitz_game, ply: 13, move_number: 7, san: "Bg5", uci: "c1g5")
rapid_mistake = ensure_user_move(game: rapid_game, ply: 15, move_number: 8, san: "Bxc5", uci: "e3c5")
classical_inaccuracy = ensure_user_move(game: classical_game, ply: 7, move_number: 4, san: "Bh4", uci: "g5h4")

missed_tactics_cycle = upsert_weakness_cycle(
  user: user,
  seed_key: "demo_missed_tactics_cycle",
  theme: :missed_tactics,
  status: :active,
  games_affected: 2,
  severity: 0.73
)
upsert_weakness_event(
  cycle: missed_tactics_cycle,
  game: blitz_game,
  move: blitz_blunder,
  primary_theme: :missed_tactics,
  severity: 0.78,
  phase: :middlegame
)
upsert_weakness_event(
  cycle: missed_tactics_cycle,
  game: rapid_game,
  move: rapid_mistake,
  primary_theme: :missed_tactics,
  severity: 0.68,
  phase: :middlegame
)

king_safety_cycle = upsert_weakness_cycle(
  user: user,
  seed_key: "demo_king_safety_cycle",
  theme: :king_safety,
  status: :active,
  games_affected: 1,
  severity: 0.65
)
upsert_weakness_event(
  cycle: king_safety_cycle,
  game: blitz_game,
  move: blitz_mistake,
  primary_theme: :king_safety,
  severity: 0.65,
  phase: :opening
)

opening_cycle = upsert_weakness_cycle(
  user: user,
  seed_key: "demo_opening_development_cycle",
  theme: :opening_development,
  status: :detected,
  games_affected: 1,
  severity: 0.42
)
upsert_weakness_event(
  cycle: opening_cycle,
  game: classical_game,
  move: classical_inaccuracy,
  primary_theme: :opening_development,
  severity: 0.42,
  phase: :opening
)

puts "Seeded demo weakness cycles for #{user.email}: missed tactics (2/3), king safety (1/3), opening development (1/3)"
