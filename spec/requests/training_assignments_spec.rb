# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Training assignments", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:plan) { create(:training_plan, :active, user: user) }
  let!(:assignment) do
    create(:training_assignment, training_plan: plan, due_on: Date.current, status: :pending)
  end

  before { sign_in user }

  describe "PATCH complete" do
    it "marks an assignment complete" do
      patch complete_training_plan_training_assignment_path(plan, assignment)

      expect(assignment.reload).to be_completed
      expect(assignment.completed_at).to be_within(2.seconds).of(Time.current)
      expect(response).to redirect_to(today_training_plan_path(plan))
    end
  end

  describe "PATCH skip" do
    it "marks an assignment skipped" do
      patch skip_training_plan_training_assignment_path(plan, assignment)

      expect(assignment.reload).to be_skipped
      expect(response).to redirect_to(today_training_plan_path(plan))
    end
  end

  it "does not allow modifying another user's assignment" do
    other_plan = create(:training_plan, :active, user: other_user)
    other_assignment = create(:training_assignment, training_plan: other_plan, due_on: Date.current)

    patch complete_training_plan_training_assignment_path(other_plan, other_assignment)

    expect(response).to have_http_status(:not_found)
    expect(other_assignment.reload).to be_pending
  end
end
