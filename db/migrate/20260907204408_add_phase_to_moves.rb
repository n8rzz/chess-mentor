# frozen_string_literal: true

class AddPhaseToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :phase, :integer
  end
end
