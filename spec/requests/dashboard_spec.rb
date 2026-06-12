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

    it "summarizes top weakness cycles when present" do
      user = create(:user)
      cycle = create(
        :weakness_cycle,
        :active,
        user: user,
        theme: :missed_tactics,
        current_occurrences: 2,
        detection_window_games: 3,
        metadata: { "frequency" => 0.667 }
      )

      sign_in user
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recurring weaknesses")
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include(weakness_path(cycle))
      expect(response.body).to include("View all weaknesses")
    end

    it "shows an empty weaknesses state when none exist" do
      sign_in create(:user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Analyze games to surface recurring patterns")
    end

    it "shows the active training plan when one exists" do
      user = create(:user)
      plan = create(:training_plan, :active, user: user, theme: :king_safety, progress_percentage: 25.0)

      sign_in user
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("King safety")
      expect(response.body).to include("25%")
      expect(response.body).to include(training_plan_path(plan))
      expect(response.body).to include(today_training_plan_path(plan))
    end

    it "shows browse recommendations when no active plan exists" do
      sign_in create(:user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No active plan")
      expect(response.body).to include("Browse recommendations")
    end
  end
end
