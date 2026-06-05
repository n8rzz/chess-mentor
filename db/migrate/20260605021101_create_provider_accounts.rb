# frozen_string_literal: true

class CreateProviderAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_accounts, id: :string do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :string, index: true
      t.integer :provider, null: false, default: 0
      t.string :provider_username, null: false
      t.string :provider_user_id, null: false
      t.text :access_token
      t.datetime :token_expires_at

      t.timestamps
    end

    add_index :provider_accounts, %i[provider provider_user_id], unique: true
    add_index :provider_accounts, %i[user_id provider], unique: true
  end
end
