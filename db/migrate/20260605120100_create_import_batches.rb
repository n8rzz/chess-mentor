# frozen_string_literal: true

class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :provider_account, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :provider, null: false
      t.integer :status, null: false, default: 0
      t.datetime :requested_since, null: false
      t.datetime :requested_until, null: false
      t.integer :max_games, null: false
      t.jsonb :time_controls, null: false, default: []
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :games_found_count, null: false, default: 0
      t.integer :games_imported_count, null: false, default: 0
      t.integer :games_skipped_count, null: false, default: 0
      t.integer :games_failed_count, null: false, default: 0
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :import_batches, %i[user_id created_at]
    add_index :import_batches, %i[user_id status]
  end
end
