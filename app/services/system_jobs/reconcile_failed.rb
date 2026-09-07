# frozen_string_literal: true

module SystemJobs
  # Re-queues retryable failed jobs when the parent workflow entity is still pending.
  class ReconcileFailed
    ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze
    RETRYABLE_TYPES = %i[classify_patterns generate_training_plan].freeze

    def self.call
      new.call
    end

    def call
      RETRYABLE_TYPES.each { |job_type| reconcile_job_type(job_type) }
    end

    private

    def reconcile_job_type(job_type)
      SystemJob.public_send(job_type).failed.find_each do |job|
        next unless job.retryable?
        next if active_job?(job_type, job)
        next unless parent_still_pending?(job)

        Retry.call(job: job)
      end
    end

    def active_job?(job_type, job)
      scope = SystemJob.public_send(job_type).where(status: ACTIVE_JOB_STATUSES)
      case job_type
      when :classify_patterns
        scope.exists?([ "user_id = ?", job.user_id ])
      when :generate_training_plan
        plan_id = job.payload["training_plan_id"]
        scope.exists?([ "payload->>'training_plan_id' = ?", plan_id ])
      else
        false
      end
    end

    def parent_still_pending?(job)
      case job.job_type
      when "classify_patterns"
        true
      when "generate_training_plan"
        plan = TrainingPlan.find_by(id: job.payload["training_plan_id"])
        plan&.generation_pending?
      else
        false
      end
    end
  end
end
