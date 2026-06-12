# frozen_string_literal: true

module TrainingPlans
  class Pause
    class Error < StandardError; end

    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      raise Error, "Only active plans can be paused" unless @plan.active?

      @plan.update!(status: :paused)
      @plan
    end
  end
end
