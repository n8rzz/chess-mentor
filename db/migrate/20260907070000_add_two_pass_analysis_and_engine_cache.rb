# frozen_string_literal: true

class AddTwoPassAnalysisAndEngineCache < ActiveRecord::Migration[8.1]
  def change
    add_column :analysis_runs, :depth_critical, :integer, null: false, default: 20
    add_column :analysis_runs, :multipv, :integer, null: false, default: 3

    add_column :move_evaluations, :candidates, :jsonb, null: false, default: []
    add_column :move_evaluations, :critical_position, :boolean, null: false, default: false
    add_column :move_evaluations, :criticality_score, :decimal, precision: 5, scale: 2, null: false, default: 0

    create_table :engine_position_evals, id: :string do |t|
      t.string :position_key, null: false
      t.string :engine_name, null: false
      t.string :engine_version, null: false
      t.integer :depth, null: false
      t.integer :multipv, null: false
      t.string :analysis_version, null: false
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end

    add_index :engine_position_evals,
              %i[position_key engine_name engine_version depth multipv analysis_version],
              unique: true,
              name: "index_engine_position_evals_on_cache_key"
  end
end
