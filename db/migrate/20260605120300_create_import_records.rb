# frozen_string_literal: true

class CreateImportRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :import_records, id: :string do |t|
      t.references :import_batch, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :provider, null: false
      t.string :provider_game_id, null: false
      t.integer :status, null: false, default: 0
      t.references :game, foreign_key: { on_delete: :nullify }, type: :string, index: true
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :import_records, %i[provider provider_game_id], unique: true
  end
end
