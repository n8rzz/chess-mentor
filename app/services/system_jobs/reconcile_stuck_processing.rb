# frozen_string_literal: true

module SystemJobs
  # Marks orphaned claimed/processing jobs as failed when their lease expires,
  # then retries when attempts remain. Lease age uses updated_at so worker
  # heartbeats keep live long jobs alive.
  class ReconcileStuckProcessing
    IN_PROGRESS_STATUSES = %i[claimed processing].freeze

    # Seconds without a heartbeat (updated_at) before a job is considered stuck.
    DEFAULT_TIMEOUTS = {
      "import_games" => 20 * 60,
      "analyze_game" => 30 * 60,
      "classify_patterns" => 15 * 60,
      "generate_training_plan" => 15 * 60,
      "update_progress_snapshots" => 15 * 60,
      "refresh_review_period_metrics" => 15 * 60
    }.freeze

    FALLBACK_TIMEOUT_SECONDS = 15 * 60

    def self.call
      new.call
    end

    def call
      SystemJob.where(status: IN_PROGRESS_STATUSES).find_each do |job|
        next unless stuck?(job)

        fail_stuck_job!(job)
        maybe_retry!(job)
        maybe_fail_analysis_run!(job)
      end
    end

    private

    def stuck?(job)
      anchor = job.updated_at || job.started_at || job.created_at
      anchor < timeout_for(job).seconds.ago
    end

    def timeout_for(job)
      env_key = "SYSTEM_JOB_STUCK_TIMEOUT_#{job.job_type.upcase}_SECONDS"
      if ENV[env_key].present?
        Integer(ENV[env_key])
      else
        DEFAULT_TIMEOUTS.fetch(job.job_type, FALLBACK_TIMEOUT_SECONDS)
      end
    end

    def fail_stuck_job!(job)
      timeout = timeout_for(job)
      previous_status = job.status
      Rails.logger.info(
        "system_jobs.stuck_processing job_id=#{job.id} job_type=#{job.job_type} " \
        "status=#{previous_status} timeout_seconds=#{timeout} claimed_by=#{job.claimed_by}"
      )

      job.update!(
        status: :failed,
        error_message: "job stuck in #{previous_status} beyond #{timeout}s lease timeout",
        error_details: {
          "code" => "stuck_processing",
          "previous_status" => previous_status,
          "timeout_seconds" => timeout,
          "claimed_by" => job.claimed_by,
          "started_at" => job.started_at&.iso8601,
          "updated_at" => job.updated_at&.iso8601
        },
        finished_at: Time.current
      )
    end
    def maybe_retry!(job)
      return unless job.reload.retryable?

      Retry.call(job: job)
      Rails.logger.info("system_jobs.stuck_processing_retried job_id=#{job.id}")
    end

    def maybe_fail_analysis_run!(job)
      return unless job.analyze_game?
      return if job.reload.retryable? || job.pending?

      run = AnalysisRun.find_by(id: job.payload["analysis_run_id"])
      return if run.nil?
      return unless run.pending? || run.running?

      run.update!(
        status: :failed,
        error_message: "analysis job exhausted retries after becoming stuck",
        error_details: {
          "code" => "stuck_processing",
          "system_job_id" => job.id
        },
        finished_at: Time.current
      )
    end
  end
end
