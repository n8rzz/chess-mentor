# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users::OmniauthCallbacks", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "GET /users/auth/lichess/callback" do
    before { mock_lichess_auth }

    it "creates a user, signs them in, and redirects to the dashboard" do
      expect do
        get user_lichess_omniauth_callback_path
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.body).to include("Lichess connected as")
    end

    it "links Lichess to the signed-in user without creating a new user" do
      user = create(:user)
      sign_in user

      expect do
        get user_lichess_omniauth_callback_path
      end.to change(ProviderAccount, :count).by(1)
        .and change(User, :count).by(0)

      expect(user.reload.lichess_account).to be_present
      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.body).to include("Lichess account connected successfully.")
    end

    it "redirects with an alert when the Lichess account is already linked elsewhere" do
      other_user = create(:user)
      create(:provider_account, user: other_user, provider_user_id: "lichess-user-1")
      sign_in create(:user)

      get user_lichess_omniauth_callback_path

      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.body).to include("already linked to another user")
    end
  end

  describe "OAuth failure" do
    it "redirects signed-in users to the dashboard with an alert" do
      user = create(:user)
      sign_in user

      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:lichess] = :invalid_credentials

      get user_lichess_omniauth_callback_path

      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response.body).to include('role="alert"')
      expect(response.body).to include("Invalid credentials")
    end

    it "redirects signed-out users to the sign-in page with an alert" do
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:lichess] = :invalid_credentials

      get user_lichess_omniauth_callback_path

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include('role="alert"')
      expect(response.body).to include("Invalid credentials")
    end
  end
end
