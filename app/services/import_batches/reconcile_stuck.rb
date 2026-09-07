# frozen_string_literal: true

module ImportBatches
  # Recovers import batches left in pending/running without an active worker job.
  class ReconcileStuck
    ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze
    STUCK_THRESHOLD = 30.minutes

    def self.call
      new.call
    end

    def call
      retry_failed_import_jobs
      enqueue_stuck_batches
    end

    private

    def retry_failed_import_jobs
      SystemJob.import_games.failed.find_each do |job|
        next unless job.retryable?

        batch = recoverable_batch_for(job)
        next unless batch

        # Refresh decrypted token — older jobs may lack it or hold a stale copy.
        SystemJobs::Retry.call(job: job, payload: JobPayload.for(batch: batch))
      end
    end

    def enqueue_stuck_batches
      ImportBatch.where(status: %i[pending running]).includes(:provider_account).find_each do |batch|
        next unless importable?(batch)
        next if active_import_job?(batch)
        next if recently_running?(batch)

        SystemJobs::Create.call(
          user: batch.user,
          job_type: :import_games,
          payload: JobPayload.for(batch: batch)
        )
      end
    end

    def recoverable_batch_for(job)
      batch = ImportBatch.includes(:provider_account).find_by(id: job.payload["import_batch_id"])
      return unless batch
      return unless importable?(batch)
      return unless batch.pending? || batch.running?

      batch
    end

    def importable?(batch)
      batch.provider_account.access_token.present?
    end

    def active_import_job?(batch)
      SystemJob.import_games
        .where(status: ACTIVE_JOB_STATUSES)
        .exists?([ "payload->>'import_batch_id' = ?", batch.id ])
    end

    def recently_running?(batch)
      batch.running? && batch.started_at.present? && batch.started_at > STUCK_THRESHOLD.ago
    end
  end
end
