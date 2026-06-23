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
        next unless import_batch_recoverable?(job)

        SystemJobs::Retry.call(job: job)
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
          payload: { "import_batch_id" => batch.id }
        )
      end
    end

    def import_batch_recoverable?(job)
      batch = ImportBatch.includes(:provider_account).find_by(id: job.payload["import_batch_id"])
      return false unless batch
      return false unless importable?(batch)

      batch.pending? || batch.running?
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
