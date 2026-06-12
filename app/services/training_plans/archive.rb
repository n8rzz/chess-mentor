# frozen_string_literal: true

module TrainingPlans
  class Archive
    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      @plan.update!(status: :archived)
      @plan
    end
  end
end
