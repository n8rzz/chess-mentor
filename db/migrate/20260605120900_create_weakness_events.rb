# frozen_string_literal: true

class CreateWeaknessEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :weakness_events, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :move, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :weakness_cycle, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :primary_theme, null: false
      t.integer :secondary_theme
      t.decimal :severity, precision: 5, scale: 2, null: false
      t.string :phase
      t.boolean :occurred_under_time_pressure, null: false, default: false
      t.string :explanation_key
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end
  end
end
