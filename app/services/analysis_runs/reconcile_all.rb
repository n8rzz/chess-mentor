# frozen_string_literal: true

module AnalysisRuns
  # System-wide reconciler: ensures imported games have analysis runs and jobs.
  #
  # Enqueues when:
  # - Import batch succeeded but analysis was never enqueued (e.g. user left import page)
  # - AnalysisRun is pending with no active analyze_game job (stuck/stub leftovers)
  # - Game exists without any AnalysisRun
  #
  # Does NOT enqueue when:
  # - AnalysisRun is succeeded, failed, cancelled, or running with an active job
  class ReconcileAll
    ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze

    def self.call
      new.call
    end

    def call
      enqueue_pending_import_batches
      enqueue_stuck_pending_runs
      enqueue_games_without_runs
    end

    private

    def enqueue_pending_import_batches
      ImportBatch
        .where(status: %i[succeeded partially_succeeded])
        .where("metadata->>'analysis_enqueued_at' IS NULL OR metadata->>'analysis_enqueued_at' = ''")
        .find_each { |batch| BulkEnqueueForImport.call(import_batch: batch) }
    end

    def enqueue_stuck_pending_runs
      AnalysisRun.pending.includes(:user, :game).find_each do |run|
        next if active_analyze_job?(run)

        create_analyze_job(run)
      end
    end

    def enqueue_games_without_runs
      Game.where.missing(:analysis_runs).includes(:user).find_each do |game|
        run = create_analysis_run(game)
        create_analyze_job(run)
      end
    end

    def create_analysis_run(game)
      AnalysisRun.create!(
        game: game,
        user: game.user,
        engine_name: BulkEnqueueForImport::DEFAULT_ENGINE_NAME,
        engine_version: BulkEnqueueForImport::DEFAULT_ENGINE_VERSION,
        analysis_version: BulkEnqueueForImport::DEFAULT_ANALYSIS_VERSION,
        depth: BulkEnqueueForImport::DEFAULT_DEPTH,
        metadata: { "import_batch_id" => game.import_batch_id }
      )
    end

    def create_analyze_job(run)
      SystemJobs::Create.call(
        user: run.user,
        job_type: :analyze_game,
        payload: {
          "analysis_run_id" => run.id,
          "game_id" => run.game_id
        }
      )
    end

    def active_analyze_job?(run)
      SystemJob.analyze_game
        .where(status: ACTIVE_JOB_STATUSES)
        .exists?([ "payload->>'analysis_run_id' = ?", run.id ])
    end
  end
end
