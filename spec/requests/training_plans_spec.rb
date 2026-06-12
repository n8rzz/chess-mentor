# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Training plans", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /training_plans" do
    it "lists recommendations when no active plan exists" do
      create(:weakness_cycle, :active, user: user, theme: :king_safety, current_severity: 0.9)

      sign_in user
      get training_plans_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("King safety")
      expect(response.body).to include("Start plan")
    end

    it "shows the current plan when one is active" do
      plan = create(:training_plan, :active, user: user, theme: :missed_tactics)

      sign_in user
      get training_plans_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Current plan")
      expect(response.body).to include("Missed tactics")
      expect(response.body).not_to include("Start plan")
    end
  end

  describe "POST /training_plans" do
    before { sign_in user }

    it "creates a plan from a recommended weakness cycle" do
      cycle = create(:weakness_cycle, :active, user: user, theme: :hanging_pieces)

      expect {
        post training_plans_path, params: { weakness_cycle_id: cycle.id }
      }.to change(TrainingPlan, :count).by(1)
        .and change(SystemJob, :count).by(1)

      plan = TrainingPlan.last
      expect(response).to redirect_to(training_plan_path(plan))
      expect(plan).to be_active
    end

    it "redirects with an alert when the cycle is ineligible" do
      cycle = create(:weakness_cycle, :archived, user: user)

      expect {
        post training_plans_path, params: { weakness_cycle_id: cycle.id }
      }.not_to change(TrainingPlan, :count)

      expect(response).to redirect_to(training_plans_path)
      expect(flash[:alert]).to include("not eligible")
    end

    it "redirects with an alert when the user already has an active plan" do
      create(:training_plan, :active, user: user)
      cycle = create(:weakness_cycle, :active, user: user, theme: :king_safety)

      expect {
        post training_plans_path, params: { weakness_cycle_id: cycle.id }
      }.not_to change(TrainingPlan, :count)

      expect(response).to redirect_to(training_plans_path)
      expect(flash[:alert]).to include("already has")
    end
  end

  describe "GET /training_plans/:id" do
    it "shows plan details and assignments" do
      plan = create(:training_plan, :active, user: user, theme: :missed_tactics)
      create(:training_assignment, training_plan: plan, due_on: Date.current, assignment_type: :theme_puzzle)

      sign_in user
      get training_plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Missed tactics")
      expect(response.body).to include("Theme puzzle")
    end

    it "shows a generation pending banner when assignments have not been created yet" do
      plan = create(:training_plan, :active, user: user)

      sign_in user
      get training_plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Assignments are still being generated")
    end

    it "does not allow access to another user's plan" do
      plan = create(:training_plan, :active, user: other_user)

      sign_in user
      get training_plan_path(plan)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /training_plans/:id/today" do
    it "lists today's assignments" do
      plan = create(:training_plan, :active, user: user)
      assignment = create(:training_assignment, training_plan: plan, due_on: Date.current, prompt: "Play one rapid game")

      sign_in user
      get today_training_plan_path(plan)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Today's assignments")
      expect(response.body).to include("Play one rapid game")
      expect(response.body).to include("Complete")
    end

    it "excludes assignments due on other days" do
      plan = create(:training_plan, :active, user: user)
      create(:training_assignment, training_plan: plan, due_on: Date.current, prompt: "Due today")
      create(:training_assignment, training_plan: plan, due_on: Date.current + 1.day, prompt: "Due tomorrow")

      sign_in user
      get today_training_plan_path(plan)

      expect(response.body).to include("Due today")
      expect(response.body).not_to include("Due tomorrow")
    end
  end

  describe "plan lifecycle" do
    let(:plan) { create(:training_plan, :active, user: user) }

    before { sign_in user }

    it "pauses and resumes the plan" do
      post pause_training_plan_path(plan)
      expect(plan.reload).to be_paused

      post resume_training_plan_path(plan)
      expect(plan.reload).to be_active
    end

    it "completes the plan" do
      post complete_training_plan_path(plan)

      expect(plan.reload).to be_completed
      expect(response).to redirect_to(training_plans_path)
    end

    it "archives the plan" do
      post archive_training_plan_path(plan)

      expect(plan.reload).to be_archived
      expect(response).to redirect_to(training_plans_path)
    end

    it "extends an eligible plan and enqueues generation" do
      plan.update!(starts_at: 20.days.ago, ends_at: 2.days.ago)

      expect {
        post extend_training_plan_path(plan)
      }.to change(SystemJob, :count).by(1)

      expect(plan.reload.ends_at).to be > 2.days.ago
      expect(response).to redirect_to(training_plan_path(plan))
      expect(flash[:notice]).to include("extended")
    end

    it "redirects with an alert when extension is not eligible" do
      plan.update!(progress_percentage: 80.0, status: :managed, ends_at: 2.days.ago)

      expect {
        post extend_training_plan_path(plan)
      }.not_to change(SystemJob, :count)

      expect(response).to redirect_to(training_plan_path(plan))
      expect(flash[:alert]).to be_present
    end

    it "rejects pausing a plan that is not active" do
      plan.update!(status: :paused)

      post pause_training_plan_path(plan)

      expect(response).to redirect_to(training_plan_path(plan))
      expect(flash[:alert]).to include("Only active plans can be paused")
    end
  end
end
