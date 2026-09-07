# frozen_string_literal: true

class CreateReviewPeriods < ActiveRecord::Migration[8.1]
  def change
    create_table :review_periods, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.string :label, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :status, null: false, default: 0
      t.integer :time_class
      t.integer :max_games
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :review_periods, %i[user_id starts_at ends_at]

    create_table :review_period_games, id: :string do |t|
      t.references :review_period, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :game, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true

      t.timestamps null: false
    end

    add_index :review_period_games, %i[review_period_id game_id], unique: true
  end
end
