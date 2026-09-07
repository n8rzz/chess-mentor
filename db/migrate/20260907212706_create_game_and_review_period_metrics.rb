# frozen_string_literal: true

class CreateGameAndReviewPeriodMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :game_metrics, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :analysis_run, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: false
      t.string :metric_formula_version, null: false, default: "1.0.0"
      t.decimal :average_centipawn_loss, precision: 8, scale: 2
      t.integer :user_move_count, null: false, default: 0
      t.integer :inaccuracies_count, null: false, default: 0
      t.integer :mistakes_count, null: false, default: 0
      t.integer :blunders_count, null: false, default: 0
      t.jsonb :phase_metrics, null: false, default: {}
      t.integer :winning_positions_reached, null: false, default: 0
      t.integer :winning_positions_converted, null: false, default: 0
      t.integer :time_pressure_moves_count, null: false, default: 0
      t.integer :time_pressure_mistakes_count, null: false, default: 0
      t.decimal :time_pressure_error_rate, precision: 8, scale: 4
      t.integer :fast_moves_count, null: false, default: 0
      t.integer :fast_move_mistakes_count, null: false, default: 0
      t.decimal :fast_move_error_rate, precision: 8, scale: 4
      t.integer :critical_moves_count, null: false, default: 0
      t.integer :critical_accurate_count, null: false, default: 0
      t.decimal :critical_position_accuracy, precision: 8, scale: 4
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :game_metrics, :analysis_run_id, unique: true
    add_index :game_metrics, %i[user_id game_id]
    add_index :game_metrics, %i[user_id metric_formula_version]

    create_table :review_period_metrics, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :review_period, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: false
      t.string :metric_formula_version, null: false, default: "1.0.0"
      t.integer :games_count, null: false, default: 0
      t.integer :analyzed_games_count, null: false, default: 0
      t.integer :user_move_count, null: false, default: 0
      t.decimal :win_rate, precision: 8, scale: 4
      t.decimal :draw_rate, precision: 8, scale: 4
      t.decimal :loss_rate, precision: 8, scale: 4
      t.decimal :average_centipawn_loss, precision: 8, scale: 2
      t.decimal :mistakes_per_game, precision: 8, scale: 4
      t.decimal :blunders_per_game, precision: 8, scale: 4
      t.jsonb :phase_metrics, null: false, default: {}
      t.integer :winning_positions_reached, null: false, default: 0
      t.integer :winning_positions_converted, null: false, default: 0
      t.decimal :conversion_rate, precision: 8, scale: 4
      t.integer :time_pressure_moves_count, null: false, default: 0
      t.integer :time_pressure_mistakes_count, null: false, default: 0
      t.decimal :time_pressure_error_rate, precision: 8, scale: 4
      t.integer :fast_moves_count, null: false, default: 0
      t.integer :fast_move_mistakes_count, null: false, default: 0
      t.decimal :fast_move_error_rate, precision: 8, scale: 4
      t.integer :critical_moves_count, null: false, default: 0
      t.integer :critical_accurate_count, null: false, default: 0
      t.decimal :critical_position_accuracy, precision: 8, scale: 4
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :review_period_metrics, %i[review_period_id metric_formula_version], unique: true,
      name: "index_review_period_metrics_on_period_and_formula"
  end
end
