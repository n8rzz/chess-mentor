# frozen_string_literal: true

class CreateMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :moves, id: :string do |t|
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :ply, null: false
      t.integer :move_number, null: false
      t.integer :color, null: false
      t.string :san, null: false
      t.string :uci, null: false
      t.string :fen_before, null: false
      t.string :fen_after, null: false
      t.boolean :played_by_user, null: false, default: false
      t.integer :clock_before
      t.integer :clock_after

      t.timestamps null: false
    end

    add_index :moves, %i[game_id ply], unique: true
  end
end
