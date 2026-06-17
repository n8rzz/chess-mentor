# frozen_string_literal: true

class TrainingAssignmentsController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_assignment

  def show
    @source_evaluation = source_move_evaluation if @assignment.personal_position_review?
  end

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
    @assignment = @training_plan.training_assignments
      .includes(:puzzle, source_game: :analysis_runs, source_move: :move_evaluation)
      .find(params[:id])
  end

  def source_move_evaluation
    return unless @assignment.source_move && @assignment.source_game

    succeeded_run = @assignment.source_game.analysis_runs.succeeded.order(created_at: :desc).first
    return unless succeeded_run

    succeeded_run.move_evaluations.find_by(move_id: @assignment.source_move_id)
  end
end
