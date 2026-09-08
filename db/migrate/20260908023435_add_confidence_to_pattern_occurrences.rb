# frozen_string_literal: true

class AddConfidenceToPatternOccurrences < ActiveRecord::Migration[8.0]
  def change
    add_column :pattern_occurrences, :confidence, :decimal, precision: 5, scale: 2, null: false, default: 0.75
  end
end
