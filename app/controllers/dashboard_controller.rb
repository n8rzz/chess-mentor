# frozen_string_literal: true

class DashboardController < ApplicationController
  layout "dashboard"

  before_action :authenticate_user!

  WEAKNESS_SUMMARY_STATUSES = %i[detected active improving managed].freeze

  def show
    @provider_accounts = current_user.provider_accounts
    @lichess_account = current_user.lichess_account
    @latest_import_batch = current_user.import_batches.order(created_at: :desc).first
    @top_weakness_cycles = current_user.weakness_cycles
      .where(status: WEAKNESS_SUMMARY_STATUSES)
      .order(current_severity: :desc, current_occurrences: :desc)
      .limit(3)
    @active_training_plan = current_user.training_plans.current_for.order(updated_at: :desc).first
    if @active_training_plan
      TrainingPlans::SyncProgress.call(plan: @active_training_plan)
      @active_training_plan.reload
    end
    @dashboard_summary = Dashboard::Summary.call(user: current_user, active_plan: @active_training_plan)
    @dashboard_progress = Dashboard::ProgressData.call(user: current_user, active_plan: @active_training_plan)
  end
end
