# frozen_string_literal: true

# Mirrors analysis/worker/jobs.py status integers (docs/planning/system-job-contract.md).
module SystemJobWorkerContract
  STATUS_PENDING = 0
  STATUS_CLAIMED = 1
  STATUS_PROCESSING = 2
  STATUS_SUCCEEDED = 3
  STATUS_FAILED = 4

  module_function

  def claim_next_job(worker_id:)
    ApplicationRecord.connection.transaction do
      job = SystemJob.pending.order(:created_at).limit(1).lock("FOR UPDATE SKIP LOCKED").first
      return nil unless job

      job.update!(
        status: STATUS_CLAIMED,
        claimed_by: worker_id,
        attempts_count: job.attempts_count + 1,
        started_at: Time.current
      )
      job.update!(status: STATUS_PROCESSING)
      job
    end
  end

  def mark_succeeded(job, result)
    job.update!(
      status: STATUS_SUCCEEDED,
      result: result,
      finished_at: Time.current
    )
  end

  def mark_failed(job, message, details: {})
    job.update!(
      status: STATUS_FAILED,
      error_message: message,
      error_details: details,
      finished_at: Time.current
    )
  end
end
