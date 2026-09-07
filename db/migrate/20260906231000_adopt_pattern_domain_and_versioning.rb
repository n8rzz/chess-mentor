# frozen_string_literal: true

class AdoptPatternDomainAndVersioning < ActiveRecord::Migration[8.1]
  def change
    rename_table :weakness_cycles, :pattern_cycles
    rename_column :pattern_cycles, :theme, :pattern

    rename_table :weakness_events, :pattern_occurrences
    rename_column :pattern_occurrences, :weakness_cycle_id, :pattern_cycle_id
    rename_column :pattern_occurrences, :primary_theme, :primary_pattern
    rename_column :pattern_occurrences, :secondary_theme, :secondary_pattern
    add_column :pattern_occurrences, :classifier, :string
    add_column :pattern_occurrences, :classifier_version, :string
    add_column :pattern_occurrences, :pattern_taxonomy_version, :string

    rename_column :training_plans, :weakness_cycle_id, :pattern_cycle_id
    rename_column :training_plans, :theme, :pattern

    rename_column :progress_snapshots, :weakness_cycle_id, :pattern_cycle_id
    rename_column :progress_snapshots, :weakness_frequency, :pattern_frequency
    rename_column :progress_snapshots, :weakness_severity, :pattern_severity

    rename_column :puzzles, :theme, :pattern

    add_column :analysis_runs, :metric_formula_version, :string, null: false, default: "1.0.0"
  end
end
