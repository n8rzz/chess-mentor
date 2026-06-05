# frozen_string_literal: true

class CreateTrainingPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :training_plans, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.references :weakness_cycle, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :theme, null: false
      t.integer :status, null: false, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :completed_at
      t.decimal :improvement_threshold, precision: 5, scale: 2
      t.decimal :managed_threshold, precision: 5, scale: 2
      t.integer :baseline_occurrences, null: false, default: 0
      t.integer :current_occurrences, null: false, default: 0
      t.decimal :progress_percentage, precision: 5, scale: 2
      t.jsonb :metadata, null: false, default: {}

      t.timestamps null: false
    end

    add_index :training_plans, %i[user_id status]
    add_index :training_plans, :user_id,
              unique: true,
              where: "status = 1",
              name: "index_training_plans_one_active_per_user"
  end
end
