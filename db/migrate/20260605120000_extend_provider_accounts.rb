# frozen_string_literal: true

class ExtendProviderAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :provider_accounts, bulk: true do |t|
      t.text :refresh_token
      t.datetime :last_imported_at
    end
  end
end
