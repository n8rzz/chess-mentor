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
      cycle = create(
        :weakness_cycle,
        :active,
        user: user,
        theme: :king_safety,
        baseline_occurrences: 4,
        current_occurrences: 3
      )
      plan = create(
        :training_plan,
        :active,
        user: user,
        weakness_cycle: cycle,
        theme: :king_safety,
        baseline_occurrences: 4,
        current_occurrences: 3,
        improvement_threshold: 0.30,
        managed_threshold: 0.75
      )

      sign_in user
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("King safety")
      expect(response.body).to include("25%")
      expect(response.body).to include("Objective")
      expect(response.body).to include("Today's tasks")
      expect(response.body).to include(training_plan_path(plan))
      expect(response.body).to include(today_training_plan_path(plan))
    end

    it "shows summary ratings and analysis status" do
      user = create(:user)
      provider_account = create(:provider_account, user:)
      import_batch = create(:import_batch, user:, provider_account:)
      game = create(:game, user:, provider_account:, import_batch:, time_class: :blitz, user_rating: 1540)
      create(:analysis_run, user:, game:, status: :succeeded)

      sign_in user
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Current ratings")
      expect(response.body).to include("1540")
      expect(response.body).to include("1 analyzed")
    end

    it "shows browse recommendations when no active plan exists" do
      sign_in create(:user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No active plan")
      expect(response.body).to include("Browse recommendations")
    end

    it "renders progress charts when snapshot history exists" do
      user = create(:user)
      plan = create(:training_plan, :active, user: user)
      cycle = plan.weakness_cycle
      2.times do |index|
        snapshot_at = (index + 1).days.ago
        create(
          :progress_snapshot,
          user:,
          time_class: :blitz,
          rating: 1500 + (index * 20),
          snapshot_at:,
          metadata: { "kind" => "rating" }
        )
        create(
          :progress_snapshot,
          user:,
          weakness_cycle: cycle,
          weakness_frequency: 0.5,
          snapshot_at:,
          metadata: { "kind" => "weakness", "current_occurrences" => 4 - index }
        )
        create(
          :progress_snapshot,
          user:,
          blunders_per_game: 1.0 - (index * 0.1),
          average_centipawn_loss: 40.0 - index,
          games_analyzed_count: 10,
          snapshot_at:,
          metadata: { "kind" => "performance" }
        )
      end

      sign_in user
      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Progress charts")
      expect(response.body).to include('data-controller="chart"')
      expect(response.body).to include("Rating history")
      expect(response.body).to include("Weakness trend")
    end
  end
end
