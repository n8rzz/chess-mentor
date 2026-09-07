# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProviderAccount, type: :model do
  it "encrypts access and refresh tokens at rest" do
    account = create(:provider_account, access_token: "plain-access", refresh_token: "plain-refresh")

    raw = ActiveRecord::Base.connection.select_one(
      "SELECT access_token, refresh_token FROM provider_accounts WHERE id = #{ActiveRecord::Base.connection.quote(account.id)}"
    )

    expect(raw["access_token"]).not_to eq("plain-access")
    expect(raw["refresh_token"]).not_to eq("plain-refresh")
    expect(account.reload.access_token).to eq("plain-access")
    expect(account.refresh_token).to eq("plain-refresh")
  end
end
