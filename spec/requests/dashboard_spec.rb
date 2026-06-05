# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  describe "GET /dashboard" do
    it "redirects unauthenticated users to sign in" do
      get dashboard_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders for signed-in users" do
      sign_in create(:user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Dashboard")
    end
  end
end
