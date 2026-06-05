# frozen_string_literal: true

class CreateCandidateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :candidate_events, id: :string do |t|
      t.references :analysis_run, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :move, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :event_type, null: false
      t.decimal :severity, precision: 5, scale: 2, null: false
      t.decimal :confidence, precision: 5, scale: 2, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end
  end
end
