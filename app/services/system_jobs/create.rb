# frozen_string_literal: true

module SystemJobs
  # Enqueues Python-executed work by inserting a +system_jobs+ row (Postgres polling in MVP).
  # Does not use Sidekiq or Redis for cross-language dispatch.
  class Create
    def self.call(user:, job_type:, payload: {})
      new(user:, job_type:, payload:).call
    end

    def initialize(user:, job_type:, payload: {})
      @user = user
      @job_type = job_type
      @payload = payload
    end

    def call
      SystemJob.create!(
        user: @user,
        job_type: @job_type,
        status: :pending,
        payload: normalize_payload(@payload),
        attempts_count: 0
      )
    end

    private

    def normalize_payload(payload)
      unless payload.is_a?(Hash)
        raise ArgumentError, "payload must be a Hash"
      end

      payload.stringify_keys
    end
  end
end
