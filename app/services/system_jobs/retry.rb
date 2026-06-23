# frozen_string_literal: true

module SystemJobs
  class Retry
    class NotRetryableError < StandardError; end

    def self.call(job:)
      new(job:).call
    end

    def initialize(job:)
      @job = job
    end

    def call
      raise NotRetryableError, "job is not retryable" unless @job.retryable?

      @job.update!(
        status: :pending,
        error_message: nil,
        error_details: {},
        finished_at: nil,
        claimed_by: nil,
        started_at: nil
      )

      @job
    end
  end
end
