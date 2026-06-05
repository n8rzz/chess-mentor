# frozen_string_literal: true

class CreateTrainingAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :training_assignments, id: :string do |t|
      t.references :training_plan, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :assignment_type, null: false
      t.integer :status, null: false, default: 0
      t.date :due_on
      t.datetime :completed_at
      t.references :source_game, foreign_key: { to_table: :games, on_delete: :nullify }, type: :string, index: true
      t.references :source_move, foreign_key: { to_table: :moves, on_delete: :nullify }, type: :string, index: true
      t.references :puzzle, foreign_key: { on_delete: :nullify }, type: :string, index: true
      t.text :prompt
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :training_assignments, %i[training_plan_id status]
    add_index :training_assignments, %i[training_plan_id due_on]
  end
end
