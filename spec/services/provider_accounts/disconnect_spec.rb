# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProviderAccounts::Disconnect do
  let(:user) { create(:user) }
  let(:provider_account) { create(:provider_account, user: user) }

  describe ".call" do
    it "destroys the provider account" do
      provider_account

      expect do
        described_class.call(user: user, provider_account: provider_account)
      end.to change(ProviderAccount, :count).by(-1)
    end

    it "raises when the account belongs to another user" do
      other_user = create(:user)

      expect do
        described_class.call(user: other_user, provider_account: provider_account)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises when an import is in progress" do
      create(:import_batch, :running, user: user, provider_account: provider_account)

      expect do
        described_class.call(user: user, provider_account: provider_account)
      end.to raise_error(described_class::ImportInProgressError)
    end
  end
end
