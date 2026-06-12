# frozen_string_literal: true

module TrainingPlans
  class Recommend
    ELIGIBLE_CYCLE_STATUSES = %i[detected active improving].freeze
    BLOCKING_PLAN_STATUSES = %i[active paused].freeze
    LIMIT = 3

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      return WeaknessCycle.none if blocking_plan?

      @user.weakness_cycles
        .where(status: ELIGIBLE_CYCLE_STATUSES)
        .order(current_severity: :desc, current_occurrences: :desc)
        .limit(LIMIT)
    end

    private

    def blocking_plan?
      @user.training_plans.where(status: BLOCKING_PLAN_STATUSES).exists?
    end
  end
end
