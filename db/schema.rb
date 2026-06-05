# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_05_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "analysis_runs", id: :string, force: :cascade do |t|
    t.string "analysis_version", null: false
    t.datetime "created_at", null: false
    t.integer "depth", null: false
    t.string "engine_name", null: false
    t.string "engine_version", null: false
    t.jsonb "error_details", default: {}
    t.text "error_message"
    t.datetime "finished_at"
    t.string "game_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["game_id"], name: "index_analysis_runs_on_game_id"
    t.index ["user_id", "status"], name: "index_analysis_runs_on_user_id_and_status"
    t.index ["user_id"], name: "index_analysis_runs_on_user_id"
  end

  create_table "candidate_events", id: :string, force: :cascade do |t|
    t.string "analysis_run_id", null: false
    t.decimal "confidence", precision: 5, scale: 2, null: false
    t.datetime "created_at", null: false
    t.integer "event_type", null: false
    t.string "game_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "move_id", null: false
    t.decimal "severity", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_run_id"], name: "index_candidate_events_on_analysis_run_id"
    t.index ["game_id"], name: "index_candidate_events_on_game_id"
    t.index ["move_id"], name: "index_candidate_events_on_move_id"
  end

  create_table "games", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "import_batch_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "opening_eco"
    t.string "opening_name"
    t.integer "opponent_rating"
    t.string "opponent_username"
    t.text "pgn", null: false
    t.datetime "played_at", null: false
    t.integer "provider", null: false
    t.string "provider_account_id", null: false
    t.string "provider_game_id", null: false
    t.integer "result", null: false
    t.integer "time_class", default: 0, null: false
    t.string "time_control"
    t.datetime "updated_at", null: false
    t.integer "user_color", null: false
    t.string "user_id", null: false
    t.integer "user_rating"
    t.index ["import_batch_id"], name: "index_games_on_import_batch_id"
    t.index ["provider_account_id"], name: "index_games_on_provider_account_id"
    t.index ["user_id", "played_at"], name: "index_games_on_user_id_and_played_at"
    t.index ["user_id", "provider", "provider_game_id"], name: "index_games_on_user_id_and_provider_and_provider_game_id", unique: true
    t.index ["user_id"], name: "index_games_on_user_id"
  end

  create_table "import_batches", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "error_details", default: {}
    t.text "error_message"
    t.datetime "finished_at"
    t.integer "games_failed_count", default: 0, null: false
    t.integer "games_found_count", default: 0, null: false
    t.integer "games_imported_count", default: 0, null: false
    t.integer "games_skipped_count", default: 0, null: false
    t.integer "max_games", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "provider", null: false
    t.string "provider_account_id", null: false
    t.datetime "requested_since", null: false
    t.datetime "requested_until", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.jsonb "time_controls", default: [], null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["provider_account_id"], name: "index_import_batches_on_provider_account_id"
    t.index ["user_id", "created_at"], name: "index_import_batches_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_import_batches_on_user_id_and_status"
    t.index ["user_id"], name: "index_import_batches_on_user_id"
  end

  create_table "import_records", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "game_id"
    t.string "import_batch_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "provider", null: false
    t.string "provider_game_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_import_records_on_game_id"
    t.index ["import_batch_id"], name: "index_import_records_on_import_batch_id"
    t.index ["provider", "provider_game_id"], name: "index_import_records_on_provider_and_provider_game_id", unique: true
  end

  create_table "move_evaluations", id: :string, force: :cascade do |t|
    t.string "analysis_run_id", null: false
    t.string "best_move_san"
    t.string "best_move_uci"
    t.integer "centipawn_loss", null: false
    t.integer "classification", null: false
    t.datetime "created_at", null: false
    t.integer "depth", null: false
    t.integer "eval_after_cp"
    t.integer "eval_before_cp"
    t.string "game_id", null: false
    t.integer "mate_after"
    t.integer "mate_before"
    t.jsonb "metadata", default: {}, null: false
    t.string "move_id", null: false
    t.text "principal_variation"
    t.datetime "updated_at", null: false
    t.index ["analysis_run_id", "move_id"], name: "index_move_evaluations_on_analysis_run_id_and_move_id", unique: true
    t.index ["analysis_run_id"], name: "index_move_evaluations_on_analysis_run_id"
    t.index ["game_id"], name: "index_move_evaluations_on_game_id"
    t.index ["move_id"], name: "index_move_evaluations_on_move_id"
  end

  create_table "moves", id: :string, force: :cascade do |t|
    t.integer "clock_after"
    t.integer "clock_before"
    t.integer "color", null: false
    t.datetime "created_at", null: false
    t.string "fen_after", null: false
    t.string "fen_before", null: false
    t.string "game_id", null: false
    t.integer "move_number", null: false
    t.boolean "played_by_user", default: false, null: false
    t.integer "ply", null: false
    t.string "san", null: false
    t.string "uci", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "ply"], name: "index_moves_on_game_id_and_ply", unique: true
    t.index ["game_id"], name: "index_moves_on_game_id"
  end

  create_table "progress_snapshots", id: :string, force: :cascade do |t|
    t.decimal "average_centipawn_loss", precision: 8, scale: 2
    t.decimal "blunders_per_game", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.integer "games_analyzed_count", default: 0, null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "rating"
    t.datetime "snapshot_at", null: false
    t.integer "time_class", default: 4, null: false
    t.string "training_plan_id"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.string "weakness_cycle_id"
    t.decimal "weakness_frequency", precision: 5, scale: 2
    t.decimal "weakness_severity", precision: 5, scale: 2
    t.index ["training_plan_id"], name: "index_progress_snapshots_on_training_plan_id"
    t.index ["user_id", "snapshot_at"], name: "index_progress_snapshots_on_user_id_and_snapshot_at"
    t.index ["user_id"], name: "index_progress_snapshots_on_user_id"
    t.index ["weakness_cycle_id"], name: "index_progress_snapshots_on_weakness_cycle_id"
  end

  create_table "provider_accounts", id: :string, force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.datetime "last_imported_at"
    t.integer "provider", default: 0, null: false
    t.string "provider_user_id", null: false
    t.string "provider_username", null: false
    t.text "refresh_token"
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["provider", "provider_user_id"], name: "index_provider_accounts_on_provider_and_provider_user_id", unique: true
    t.index ["user_id", "provider"], name: "index_provider_accounts_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_provider_accounts_on_user_id"
  end

  create_table "puzzles", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "difficulty", default: 0, null: false
    t.string "fen", null: false
    t.jsonb "metadata", default: {}, null: false
    t.integer "motif", null: false
    t.integer "rating"
    t.text "solution", null: false
    t.integer "source", default: 0, null: false
    t.integer "theme", null: false
    t.datetime "updated_at", null: false
  end

  create_table "system_jobs", id: :string, force: :cascade do |t|
    t.integer "attempts_count", default: 0, null: false
    t.string "claimed_by"
    t.datetime "created_at", null: false
    t.jsonb "error_details"
    t.text "error_message"
    t.datetime "finished_at"
    t.integer "job_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.jsonb "result"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["status", "created_at"], name: "index_system_jobs_on_status_and_created_at"
    t.index ["user_id", "created_at"], name: "index_system_jobs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_system_jobs_on_user_id"
  end

  create_table "training_assignments", id: :string, force: :cascade do |t|
    t.integer "assignment_type", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on"
    t.jsonb "metadata", default: {}, null: false
    t.text "prompt"
    t.string "puzzle_id"
    t.string "source_game_id"
    t.string "source_move_id"
    t.integer "status", default: 0, null: false
    t.string "training_plan_id", null: false
    t.datetime "updated_at", null: false
    t.index ["puzzle_id"], name: "index_training_assignments_on_puzzle_id"
    t.index ["source_game_id"], name: "index_training_assignments_on_source_game_id"
    t.index ["source_move_id"], name: "index_training_assignments_on_source_move_id"
    t.index ["training_plan_id", "due_on"], name: "index_training_assignments_on_training_plan_id_and_due_on"
    t.index ["training_plan_id", "status"], name: "index_training_assignments_on_training_plan_id_and_status"
    t.index ["training_plan_id"], name: "index_training_assignments_on_training_plan_id"
  end

  create_table "training_plans", id: :string, force: :cascade do |t|
    t.integer "baseline_occurrences", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "current_occurrences", default: 0, null: false
    t.datetime "ends_at"
    t.decimal "improvement_threshold", precision: 5, scale: 2
    t.decimal "managed_threshold", precision: 5, scale: 2
    t.jsonb "metadata", default: {}, null: false
    t.decimal "progress_percentage", precision: 5, scale: 2
    t.datetime "starts_at"
    t.integer "status", default: 0, null: false
    t.integer "theme", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.string "weakness_cycle_id", null: false
    t.index ["user_id", "status"], name: "index_training_plans_on_user_id_and_status"
    t.index ["user_id"], name: "index_training_plans_on_user_id"
    t.index ["user_id"], name: "index_training_plans_one_active_per_user", unique: true, where: "(status = 1)"
    t.index ["weakness_cycle_id"], name: "index_training_plans_on_weakness_cycle_id"
  end

  create_table "users", id: :string, force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "weakness_cycles", id: :string, force: :cascade do |t|
    t.integer "baseline_occurrences", default: 0, null: false
    t.decimal "baseline_severity", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.integer "current_occurrences", default: 0, null: false
    t.decimal "current_severity", precision: 5, scale: 2
    t.integer "cycle_number", default: 1, null: false
    t.integer "detection_window_days"
    t.integer "detection_window_games"
    t.datetime "ended_at"
    t.decimal "improvement_percentage", precision: 5, scale: 2
    t.jsonb "metadata", default: {}, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "theme", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "status"], name: "index_weakness_cycles_on_user_id_and_status"
    t.index ["user_id", "theme"], name: "index_weakness_cycles_on_user_id_and_theme"
    t.index ["user_id"], name: "index_weakness_cycles_on_user_id"
  end

  create_table "weakness_events", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "explanation_key"
    t.string "game_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "move_id", null: false
    t.boolean "occurred_under_time_pressure", default: false, null: false
    t.integer "phase", null: false
    t.integer "primary_theme", null: false
    t.integer "secondary_theme"
    t.decimal "severity", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.string "weakness_cycle_id", null: false
    t.index ["game_id"], name: "index_weakness_events_on_game_id"
    t.index ["move_id"], name: "index_weakness_events_on_move_id"
    t.index ["user_id"], name: "index_weakness_events_on_user_id"
    t.index ["weakness_cycle_id"], name: "index_weakness_events_on_weakness_cycle_id"
  end

  add_foreign_key "analysis_runs", "games", on_delete: :cascade
  add_foreign_key "analysis_runs", "users", on_delete: :cascade
  add_foreign_key "candidate_events", "analysis_runs", on_delete: :cascade
  add_foreign_key "candidate_events", "games", on_delete: :cascade
  add_foreign_key "candidate_events", "moves", on_delete: :cascade
  add_foreign_key "games", "import_batches", on_delete: :cascade
  add_foreign_key "games", "provider_accounts", on_delete: :cascade
  add_foreign_key "games", "users", on_delete: :cascade
  add_foreign_key "import_batches", "provider_accounts", on_delete: :cascade
  add_foreign_key "import_batches", "users", on_delete: :cascade
  add_foreign_key "import_records", "games", on_delete: :nullify
  add_foreign_key "import_records", "import_batches", on_delete: :cascade
  add_foreign_key "move_evaluations", "analysis_runs", on_delete: :cascade
  add_foreign_key "move_evaluations", "games", on_delete: :cascade
  add_foreign_key "move_evaluations", "moves", on_delete: :cascade
  add_foreign_key "moves", "games", on_delete: :cascade
  add_foreign_key "progress_snapshots", "training_plans", on_delete: :nullify
  add_foreign_key "progress_snapshots", "users", on_delete: :cascade
  add_foreign_key "progress_snapshots", "weakness_cycles", on_delete: :nullify
  add_foreign_key "provider_accounts", "users", on_delete: :cascade
  add_foreign_key "system_jobs", "users", on_delete: :cascade
  add_foreign_key "training_assignments", "games", column: "source_game_id", on_delete: :nullify
  add_foreign_key "training_assignments", "moves", column: "source_move_id", on_delete: :nullify
  add_foreign_key "training_assignments", "puzzles", on_delete: :nullify
  add_foreign_key "training_assignments", "training_plans", on_delete: :cascade
  add_foreign_key "training_plans", "users", on_delete: :cascade
  add_foreign_key "training_plans", "weakness_cycles", on_delete: :cascade
  add_foreign_key "weakness_cycles", "users", on_delete: :cascade
  add_foreign_key "weakness_events", "games", on_delete: :cascade
  add_foreign_key "weakness_events", "moves", on_delete: :cascade
  add_foreign_key "weakness_events", "users", on_delete: :cascade
  add_foreign_key "weakness_events", "weakness_cycles", on_delete: :cascade
end
