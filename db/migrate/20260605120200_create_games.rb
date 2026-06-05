# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :provider_account, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :import_batch, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :provider, null: false
      t.string :provider_game_id, null: false
      t.text :pgn, null: false
      t.datetime :played_at, null: false
      t.integer :user_color, null: false
      t.integer :result, null: false
      t.string :time_control
      t.integer :time_class, null: false, default: 0
      t.string :opening_name
      t.string :opening_eco
      t.integer :user_rating
      t.integer :opponent_rating
      t.string :opponent_username
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :games, %i[user_id played_at]
    add_index :games, %i[user_id provider provider_game_id], unique: true
  end
end
