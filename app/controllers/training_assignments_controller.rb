# frozen_string_literal: true

class TrainingAssignmentsController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_assignment

  def complete
    @assignment.update!(status: :completed, completed_at: Time.current)
    ProgressSnapshots::Enqueue.call(user: current_user)
    redirect_to today_training_plan_path(@training_plan), notice: "Assignment marked complete."
  end

  def skip
    @assignment.update!(status: :skipped, completed_at: Time.current)
    redirect_to today_training_plan_path(@training_plan), notice: "Assignment skipped."
  end

  private

  def set_assignment
    @training_plan = current_user.training_plans.find(params[:training_plan_id])
    @assignment = @training_plan.training_assignments.find(params[:id])
  end
end
