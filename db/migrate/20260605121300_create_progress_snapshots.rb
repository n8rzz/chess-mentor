# frozen_string_literal: true

class CreateProgressSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :progress_snapshots, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :training_plan, foreign_key: { on_delete: :nullify }, type: :string, index: true
      t.references :weakness_cycle, foreign_key: { on_delete: :nullify }, type: :string, index: true
      t.integer :time_class, null: false, default: 4
      t.integer :rating
      t.decimal :weakness_frequency, precision: 5, scale: 2
      t.decimal :weakness_severity, precision: 5, scale: 2
      t.decimal :blunders_per_game, precision: 5, scale: 2
      t.decimal :average_centipawn_loss, precision: 8, scale: 2
      t.integer :games_analyzed_count, null: false, default: 0
      t.datetime :snapshot_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :progress_snapshots, %i[user_id snapshot_at]
  end
end
