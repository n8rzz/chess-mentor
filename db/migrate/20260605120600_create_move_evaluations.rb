# frozen_string_literal: true

class CreateMoveEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :move_evaluations, id: :string do |t|
      t.references :analysis_run, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :move, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :eval_before_cp
      t.integer :eval_after_cp
      t.integer :centipawn_loss, null: false
      t.string :best_move_uci
      t.string :best_move_san
      t.text :principal_variation
      t.integer :classification, null: false
      t.integer :mate_before
      t.integer :mate_after
      t.integer :depth, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :move_evaluations, %i[analysis_run_id move_id], unique: true
  end
end
