# frozen_string_literal: true

class CreateSystemJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :system_jobs, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string
      t.integer :job_type, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result
      t.text :error_message
      t.jsonb :error_details
      t.string :claimed_by
      t.integer :attempts_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps null: false
    end

    add_index :system_jobs, %i[status created_at]
    add_index :system_jobs, %i[user_id created_at]
  end
end
