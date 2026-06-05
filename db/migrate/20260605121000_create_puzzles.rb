# frozen_string_literal: true

class CreatePuzzles < ActiveRecord::Migration[8.1]
  def change
    create_table :puzzles, id: :string do |t|
      t.integer :source, null: false, default: 0
      t.string :fen, null: false
      t.text :solution, null: false
      t.integer :theme, null: false
      t.string :motif
      t.integer :rating
      t.integer :difficulty, null: false, default: 0
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end
  end
end
