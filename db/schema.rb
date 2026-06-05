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

ActiveRecord::Schema[8.1].define(version: 2026_06_05_021101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "provider_accounts", id: :string, force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.integer "provider", default: 0, null: false
    t.string "provider_user_id", null: false
    t.string "provider_username", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["provider", "provider_user_id"], name: "index_provider_accounts_on_provider_and_provider_user_id", unique: true
    t.index ["user_id", "provider"], name: "index_provider_accounts_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_provider_accounts_on_user_id"
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

  add_foreign_key "provider_accounts", "users", on_delete: :cascade
  add_foreign_key "system_jobs", "users", on_delete: :cascade
end
