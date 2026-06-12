# frozen_string_literal: true

module TrainingPlans
  class Extend
    class Error < StandardError; end
    class NotEligibleError < Error; end

    PLAN_DURATION_DAYS = 14

    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      validate!

      ActiveRecord::Base.transaction do
        @plan.update!(
          ends_at: (@plan.ends_at || Time.current) + PLAN_DURATION_DAYS.days,
          metadata: @plan.metadata.merge("extension" => true)
        )

        SystemJobs::Create.call(
          user: @plan.user,
          job_type: :generate_training_plan,
          payload: {
            "training_plan_id" => @plan.id,
            "extension" => true
          }
        )
      end

      @plan
    end

    private

    def validate!
      raise NotEligibleError, "Plan has not ended yet" unless @plan.ends_at.present? && @plan.ends_at.to_date < Date.current
      raise NotEligibleError, "Plan already reached managed threshold" if managed?

      return if @plan.active? || @plan.improving?

      raise NotEligibleError, "Plan is not eligible for extension"
    end

    def managed?
      managed_cutoff = (@plan.managed_threshold || TrainingPlan::DEFAULT_MANAGED_THRESHOLD) * 100
      (@plan.progress_percentage || 0) >= managed_cutoff
    end
  end
end
