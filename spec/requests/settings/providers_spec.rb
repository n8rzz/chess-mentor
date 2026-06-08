# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings providers", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  describe "GET /settings/providers" do
    it "redirects unauthenticated users" do
      get settings_providers_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders for signed-in users" do
      sign_in user

      get settings_providers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Connect Lichess")
    end

    it "shows connected Lichess account" do
      create(:provider_account, user: user, provider_username: "lichessplayer")
      sign_in user

      get settings_providers_path

      expect(response.body).to include("@lichessplayer")
      expect(response.body).to include("Disconnect")
    end
  end

  describe "DELETE /settings/providers/disconnect" do
    it "disconnects the provider account" do
      account = create(:provider_account, user: user)
      sign_in user

      expect do
        delete disconnect_settings_providers_path(provider_account_id: account.id)
      end.to change(ProviderAccount, :count).by(-1)

      expect(response).to redirect_to(settings_providers_path)
    end

    it "does not disconnect when an import is in progress" do
      account = create(:provider_account, user: user)
      create(:import_batch, :running, user: user, provider_account: account)
      sign_in user

      expect do
        delete disconnect_settings_providers_path(provider_account_id: account.id)
      end.not_to change(ProviderAccount, :count)

      expect(response).to redirect_to(settings_providers_path)
      expect(flash[:alert]).to include("import is in progress")
    end
  end
end
