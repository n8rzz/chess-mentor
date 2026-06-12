# frozen_string_literal: true

module TrainingPlans
  class SyncProgress
    def self.call(plan:)
      new(plan:).call
    end

    def initialize(plan:)
      @plan = plan
    end

    def call
      cycle = @plan.weakness_cycle
      baseline = @plan.baseline_occurrences
      current = cycle.current_occurrences
      progress = compute_progress_percentage(baseline, current)

      @plan.update!(
        current_occurrences: current,
        progress_percentage: progress,
        status: next_status(progress)
      )

      @plan
    end

    private

    def compute_progress_percentage(baseline, current)
      return 0.0 if baseline.zero?

      reduction = (baseline - current).to_f / baseline
      [ reduction * 100.0, 0.0 ].max.round(2)
    end

    def next_status(progress)
      return @plan.status if @plan.paused? || @plan.completed? || @plan.archived?

      managed_cutoff = (@plan.managed_threshold || TrainingPlan::DEFAULT_MANAGED_THRESHOLD) * 100
      improving_cutoff = (@plan.improvement_threshold || TrainingPlan::DEFAULT_IMPROVEMENT_THRESHOLD) * 100

      if progress >= managed_cutoff
        :managed
      elsif progress >= improving_cutoff
        :improving
      else
        :active
      end
    end
  end
end
