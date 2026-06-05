# frozen_string_literal: true

class CreateAnalysisRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :analysis_runs, id: :string do |t|
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :status, null: false, default: 0
      t.string :engine_name, null: false
      t.string :engine_version, null: false
      t.string :analysis_version, null: false
      t.integer :depth, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :analysis_runs, %i[user_id status]
  end
end
