# frozen_string_literal: true

class TrainingPlansController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!
  before_action :set_training_plan, only: %i[show today pause resume complete archive extend]

  def index
    @current_plan = current_user.training_plans.current_for.order(updated_at: :desc).first
    @recommendations = TrainingPlans::Recommend.call(user: current_user)
  end

  def show
    TrainingPlans::SyncProgress.call(plan: @training_plan)
    @training_plan.reload
    @assignments_by_day = @training_plan.training_assignments.order(:due_on, :assignment_type).group_by(&:due_on)
    @generation_pending = @training_plan.generation_pending?
  end

  def create
    weakness_cycle = current_user.weakness_cycles.find(params[:weakness_cycle_id])
    plan = TrainingPlans::Activate.call(user: current_user, weakness_cycle: weakness_cycle)

    redirect_to training_plan_path(plan), notice: "Training plan started. Assignments will appear shortly."
  rescue TrainingPlans::Activate::Error => error
    redirect_to training_plans_path, alert: error.message
  end

  def today
    TrainingPlans::SyncProgress.call(plan: @training_plan)
    @training_plan.reload
    @assignments = @training_plan.assignments_for_today.order(:assignment_type)
  end

  def pause
    TrainingPlans::Pause.call(plan: @training_plan)
    redirect_to training_plan_path(@training_plan), notice: "Training plan paused."
  rescue TrainingPlans::Pause::Error => error
    redirect_to training_plan_path(@training_plan), alert: error.message
  end

  def resume
    TrainingPlans::Resume.call(plan: @training_plan)
    redirect_to training_plan_path(@training_plan), notice: "Training plan resumed."
  rescue TrainingPlans::Resume::Error => error
    redirect_to training_plan_path(@training_plan), alert: error.message
  end

  def complete
    TrainingPlans::Complete.call(plan: @training_plan)
    redirect_to training_plans_path, notice: "Training plan completed."
  rescue TrainingPlans::Complete::Error => error
    redirect_to training_plan_path(@training_plan), alert: error.message
  end

  def archive
    TrainingPlans::Archive.call(plan: @training_plan)
    redirect_to training_plans_path, notice: "Training plan archived."
  end

  def extend
    TrainingPlans::Extend.call(plan: @training_plan)
    redirect_to training_plan_path(@training_plan), notice: "Training plan extended by 14 days."
  rescue TrainingPlans::Extend::NotEligibleError => error
    redirect_to training_plan_path(@training_plan), alert: error.message
  end

  private

  def set_training_plan
    @training_plan = current_user.training_plans.find(params[:id])
  end
end
