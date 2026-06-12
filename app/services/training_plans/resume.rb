# frozen_string_literal: true

module TrainingPlans
  class Resume
    class Error < StandardError; end

    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      raise Error, "Only paused plans can be resumed" unless @plan.paused?

      @plan.update!(status: :active)
      @plan
    end
  end
end
