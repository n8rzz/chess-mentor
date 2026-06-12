# frozen_string_literal: true

module TrainingPlans
  class Complete
    class Error < StandardError; end

    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      raise Error, "Plan is already completed or archived" if @plan.completed? || @plan.archived?

      @plan.update!(status: :completed, completed_at: Time.current)
      @plan
    end
  end
end
