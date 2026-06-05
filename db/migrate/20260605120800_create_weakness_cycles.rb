# frozen_string_literal: true

class CreateWeaknessCycles < ActiveRecord::Migration[8.1]
  def change
    create_table :weakness_cycles, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :theme, null: false
      t.integer :status, null: false, default: 0
      t.integer :cycle_number, null: false, default: 1
      t.integer :baseline_occurrences, null: false, default: 0
      t.integer :current_occurrences, null: false, default: 0
      t.decimal :baseline_severity, precision: 5, scale: 2
      t.decimal :current_severity, precision: 5, scale: 2
      t.decimal :improvement_percentage, precision: 5, scale: 2
      t.integer :detection_window_games
      t.integer :detection_window_days
      t.datetime :started_at
      t.datetime :ended_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :weakness_cycles, %i[user_id status]
    add_index :weakness_cycles, %i[user_id theme]
  end
end
