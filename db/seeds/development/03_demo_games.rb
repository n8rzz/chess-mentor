# frozen_string_literal: true

# Demo games for local import/analysis dev without provider APIs.
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

provider_account = ProviderAccount.find_or_create_by!(user: user, provider: :lichess) do |account|
  account.provider_username = "starship_lichess"
  account.provider_user_id = "seed-starship-lichess"
end

import_batch = ImportBatch.find_by("metadata->>'seed_key' = ?", "demo_import_batch") || ImportBatch.new(
  user: user,
  provider_account: provider_account,
  provider: :lichess
)
import_batch.assign_attributes(
  requested_since: 30.days.ago,
  requested_until: Time.current,
  status: :succeeded,
  max_games: 3,
  time_controls: %w[blitz rapid],
  started_at: 10.minutes.ago,
  finished_at: Time.current,
  games_found_count: 3,
  games_imported_count: 3,
  metadata: { "seed_key" => "demo_import_batch" }
)
import_batch.save!

demo_games = [
  {
    provider_game_id: "demo-blitz-win",
    pgn: <<~PGN.strip,
      [Event "Demo Blitz"]
      [Site "lichess.org"]
      [Date "2026.06.01"]
      [White "starship_lichess"]
      [Black "opponent_blitz"]
      [Result "1-0"]
      [TimeControl "180+0"]
      [ECO "C20"]
      [Opening "King's Pawn Game"]

      1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. d3 Be7 5. O-O O-O 6. Nc3 d6 7. Bg5 h6 8. Bxf6 Bxf6 9. Nd5 1-0
    PGN
    played_at: 3.days.ago,
    user_color: :white,
    result: :win,
    time_control: "180+0",
    time_class: :blitz,
    opening_name: "King's Pawn Game",
    opening_eco: "C20",
    user_rating: 1520,
    opponent_rating: 1485,
    opponent_username: "opponent_blitz"
  },
  {
    provider_game_id: "demo-rapid-loss",
    pgn: <<~PGN.strip,
      [Event "Demo Rapid"]
      [Site "lichess.org"]
      [Date "2026.06.02"]
      [White "opponent_rapid"]
      [Black "starship_lichess"]
      [Result "1-0"]
      [TimeControl "600+0"]
      [ECO "B01"]
      [Opening "Scandinavian Defense"]

      1. e4 d5 2. exd5 Qxd5 3. Nc3 Qa5 4. d4 Nf6 5. Nf3 Bg4 6. Be2 Nc6 7. O-O O-O-O 8. h3 Bh5 9. g4 Bg6 10. Ne5 Nxe5 11. dxe5 Qb4 12. a3 Qb6 13. Bc4 e6 14. Be3 Bc5 15. Bxc5 Qxc5 16. Qd4 Qxd4 17. Nxd4 Ne4 18. Nxe6 fxe6 19. Bxa8 1-0
    PGN
    played_at: 2.days.ago,
    user_color: :black,
    result: :loss,
    time_control: "600+0",
    time_class: :rapid,
    opening_name: "Scandinavian Defense",
    opening_eco: "B01",
    user_rating: 1510,
    opponent_rating: 1550,
    opponent_username: "opponent_rapid"
  },
  {
    provider_game_id: "demo-classical-draw",
    pgn: <<~PGN.strip,
      [Event "Demo Classical"]
      [Site "lichess.org"]
      [Date "2026.06.03"]
      [White "starship_lichess"]
      [Black "opponent_classical"]
      [Result "1/2-1/2"]
      [TimeControl "1800+0"]
      [ECO "D02"]
      [Opening "Queen's Pawn Game"]

      1. d4 d5 2. Nf3 Nf6 3. c4 e6 4. Nc3 Be7 5. Bg5 O-O 6. e3 h6 7. Bh4 b6 8. cxd5 Nxd5 9. Bxe7 Qxe7 10. Nxd5 exd5 11. Bd3 c5 12. O-O Nc6 13. dxc5 bxc5 14. Rc1 Bb7 15. Qe2 Rfd8 16. Rfd1 Rac8 17. Bb5 Ne7 18. Bxe7 Qxe7 19. Qxe7 1/2-1/2
    PGN
    played_at: 1.day.ago,
    user_color: :white,
    result: :draw,
    time_control: "1800+0",
    time_class: :classical,
    opening_name: "Queen's Pawn Game",
    opening_eco: "D02",
    user_rating: 1530,
    opponent_rating: 1540,
    opponent_username: "opponent_classical"
  }
]

demo_games.each do |attrs|
  game = Game.find_or_initialize_by(
    user: user,
    provider: :lichess,
    provider_game_id: attrs[:provider_game_id]
  )
  game.assign_attributes(
    provider_account: provider_account,
    import_batch: import_batch,
    **attrs
  )
  game.save!

  ImportRecord.find_or_create_by!(provider: :lichess, provider_game_id: attrs[:provider_game_id]) do |record|
    record.import_batch = import_batch
    record.status = :imported
    record.game = game
  end
end

puts "Seeded #{demo_games.size} demo games for #{user.email}"
