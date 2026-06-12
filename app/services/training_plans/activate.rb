# frozen_string_literal: true

module TrainingPlans
  class Activate
    class Error < StandardError; end
    class IneligibleCycleError < Error; end
    class ActivePlanExistsError < Error; end

    ELIGIBLE_CYCLE_STATUSES = Recommend::ELIGIBLE_CYCLE_STATUSES

    def self.call(user:, weakness_cycle:)
      new(user:, weakness_cycle:).call
    end

    def initialize(user:, weakness_cycle:)
      @user = user
      @weakness_cycle = weakness_cycle
    end

    def call
      validate!

      plan = nil
      ActiveRecord::Base.transaction do
        archive_stale_recommendations!
        plan = create_plan!
        enqueue_generation!(plan)
      end

      plan
    end

    private

    def validate!
      raise ActiveRecord::RecordNotFound unless @weakness_cycle.user_id == @user.id
      raise IneligibleCycleError, "Weakness cycle is not eligible for a training plan" unless eligible_cycle?
      raise ActivePlanExistsError, "User already has an active or paused training plan" if blocking_plan?
    end

    def eligible_cycle?
      ELIGIBLE_CYCLE_STATUSES.include?(@weakness_cycle.status.to_sym)
    end

    def blocking_plan?
      @user.training_plans.where(status: %i[active paused]).exists?
    end

    def archive_stale_recommendations!
      @user.training_plans.where(status: :recommended).find_each do |plan|
        plan.update!(status: :archived)
      end
    end

    def create_plan!
      TrainingPlan.create!(
        user: @user,
        weakness_cycle: @weakness_cycle,
        theme: @weakness_cycle.theme,
        status: :active,
        starts_at: Time.current,
        baseline_occurrences: @weakness_cycle.baseline_occurrences,
        current_occurrences: @weakness_cycle.current_occurrences,
        improvement_threshold: TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD,
        managed_threshold: TrainingPlan::DEFAULT_MANAGED_THRESHOLD,
        progress_percentage: 0.0,
        metadata: {}
      )
    end

    def enqueue_generation!(plan)
      SystemJobs::Create.call(
        user: @user,
        job_type: :generate_training_plan,
        payload: { "training_plan_id" => plan.id }
      )
    end
  end
end
