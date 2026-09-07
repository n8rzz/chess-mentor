# frozen_string_literal: true

module SystemJobs
  class Retry
    class NotRetryableError < StandardError; end

    def self.call(job:, payload: nil)
      new(job:, payload:).call
    end

    def initialize(job:, payload: nil)
      @job = job
      @payload = payload
    end

    def call
      raise NotRetryableError, "job is not retryable" unless @job.retryable?

      attrs = {
        status: :pending,
        error_message: nil,
        error_details: {},
        finished_at: nil,
        claimed_by: nil,
        started_at: nil
      }
      attrs[:payload] = @payload.stringify_keys if @payload

      @job.update!(attrs)

      @job
    end
  end
end
