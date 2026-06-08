# frozen_string_literal: true

# Additional import batch states for local UI and worker dev (status page, history, errors).
return unless Rails.env.development?

user = User.find_by(email: "starship@example.com")
return unless user

provider_account = user.provider_accounts.find_by(provider: :lichess)
return unless provider_account

def upsert_import_batch(user:, provider_account:, seed_key:, **attrs)
  batch = ImportBatch.find_by("metadata->>'seed_key' = ?", seed_key) || ImportBatch.new(
    user: user,
    provider_account: provider_account,
    provider: :lichess,
    metadata: { "seed_key" => seed_key }
  )
  batch.assign_attributes(
    requested_since: 7.days.ago,
    requested_until: Time.current,
    max_games: 10,
    time_controls: %w[blitz rapid],
    **attrs
  )
  batch.metadata = batch.metadata.merge("seed_key" => seed_key)
  batch.save!
  batch
end

failed_batch = upsert_import_batch(
  user: user,
  provider_account: provider_account,
  seed_key: "demo_import_batch_failed",
  status: :failed,
  started_at: 20.minutes.ago,
  finished_at: 15.minutes.ago,
  games_found_count: 0,
  games_imported_count: 0,
  games_skipped_count: 0,
  games_failed_count: 0,
  error_message: "Lichess access token is invalid or expired"
)

partial_batch = upsert_import_batch(
  user: user,
  provider_account: provider_account,
  seed_key: "demo_import_batch_partial",
  status: :partially_succeeded,
  started_at: 30.minutes.ago,
  finished_at: 25.minutes.ago,
  games_found_count: 3,
  games_imported_count: 1,
  games_skipped_count: 1,
  games_failed_count: 1
)

partial_imported_game = Game.find_or_initialize_by(
  user: user,
  provider: :lichess,
  provider_game_id: "demo-partial-imported"
)
partial_imported_game.assign_attributes(
  provider_account: provider_account,
  import_batch: partial_batch,
  pgn: <<~PGN.strip,
    [Event "Demo Partial Import"]
    [White "starship_lichess"]
    [Black "opponent_partial"]
    [Result "1-0"]

    1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 1-0
  PGN
  played_at: 4.days.ago,
  user_color: :white,
  result: :win,
  time_control: "180+0",
  time_class: :blitz,
  opening_name: "Ruy Lopez",
  opening_eco: "C60",
  user_rating: 1515,
  opponent_rating: 1490,
  opponent_username: "opponent_partial"
)
partial_imported_game.save!

[
  {
    provider_game_id: "demo-partial-imported",
    status: :imported,
    game: partial_imported_game,
    error_message: nil
  },
  {
    provider_game_id: "demo-partial-skipped",
    status: :skipped,
    game: nil,
    error_message: nil
  },
  {
    provider_game_id: "demo-partial-failed",
    status: :failed,
    game: nil,
    error_message: "missing pgn"
  }
].each do |attrs|
  record = ImportRecord.find_or_initialize_by(
    provider: :lichess,
    provider_game_id: attrs[:provider_game_id]
  )
  record.assign_attributes(
    import_batch: partial_batch,
    status: attrs[:status],
    game: attrs[:game],
    error_message: attrs[:error_message]
  )
  record.save!
end

pending_batch = upsert_import_batch(
  user: user,
  provider_account: provider_account,
  seed_key: "demo_import_batch_pending",
  status: :pending,
  games_found_count: 0,
  games_imported_count: 0,
  games_skipped_count: 0,
  games_failed_count: 0
)

unless SystemJob.exists?([ "payload->>'import_batch_id' = ?", pending_batch.id ])
  SystemJobs::Create.call(
    user: user,
    job_type: :import_games,
    payload: { "import_batch_id" => pending_batch.id }
  )
end

puts "Seeded import scenarios for #{user.email}: failed, partial, pending (+ system job)"
