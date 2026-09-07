# frozen_string_literal: true

module ReviewPeriodMetrics
  class Enqueue
    ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      return false if pending_job_exists?

      SystemJobs::Create.call(user: @user, job_type: :refresh_review_period_metrics)
      true
    end

    private

    def pending_job_exists?
      @user.system_jobs
        .where(job_type: :refresh_review_period_metrics, status: ACTIVE_JOB_STATUSES)
        .exists?
    end
  end
end
