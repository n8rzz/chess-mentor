# frozen_string_literal: true

module AnalysisRuns
  # System-wide reconciler: ensures imported games have analysis runs and jobs.
  #
  # Enqueues when:
  # - Import batch succeeded but analysis was never enqueued (e.g. user left import page)
  # - AnalysisRun is pending with no active analyze_game job (stuck/stub leftovers)
  # - Game exists without any AnalysisRun
  # - Game only has outdated succeeded runs (different analysis settings/version)
  #
  # Does NOT enqueue when:
  # - Matching succeeded run already exists for current analysis settings
  # - AnalysisRun is failed, cancelled, or running with an active job
  class ReconcileAll
    ACTIVE_JOB_STATUSES = %i[pending claimed processing].freeze

    def self.call
      new.call
    end

    def call
      enqueue_pending_import_batches
      enqueue_stuck_pending_runs
      enqueue_games_needing_analysis
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

    def enqueue_games_needing_analysis
      Game.includes(:user).find_each do |game|
        next if AnalysisRun.in_progress.exists?(game_id: game.id)
        next if matching_succeeded_run?(game.id)

        has_runs = AnalysisRun.exists?(game_id: game.id)
        has_succeeded = AnalysisRun.succeeded.exists?(game_id: game.id)
        # Skip failed/cancelled-only games; enqueue missing games and outdated succeeded settings.
        next if has_runs && !has_succeeded

        run = create_analysis_run(game)
        Rails.logger.info(
          "analysis.enqueue reason=#{has_runs ? 'outdated_settings' : 'missing_run'} " \
          "game_id=#{game.id} analysis_run_id=#{run.id}"
        )
        create_analyze_job(run)
      end
    end

    def matching_succeeded_run?(game_id)
      AnalysisRun.succeeded.exists?(
        game_id: game_id,
        analysis_version: BulkEnqueueForImport::DEFAULT_ANALYSIS_VERSION,
        engine_name: BulkEnqueueForImport::DEFAULT_ENGINE_NAME,
        engine_version: BulkEnqueueForImport::DEFAULT_ENGINE_VERSION,
        depth: BulkEnqueueForImport::DEFAULT_DEPTH,
        depth_critical: BulkEnqueueForImport::DEFAULT_DEPTH_CRITICAL,
        multipv: BulkEnqueueForImport::DEFAULT_MULTIPV
      )
    end

    def create_analysis_run(game)
      AnalysisRun.create!(
        game: game,
        user: game.user,
        engine_name: BulkEnqueueForImport::DEFAULT_ENGINE_NAME,
        engine_version: BulkEnqueueForImport::DEFAULT_ENGINE_VERSION,
        analysis_version: BulkEnqueueForImport::DEFAULT_ANALYSIS_VERSION,
        metric_formula_version: BulkEnqueueForImport::DEFAULT_METRIC_FORMULA_VERSION,
        depth: BulkEnqueueForImport::DEFAULT_DEPTH,
        depth_critical: BulkEnqueueForImport::DEFAULT_DEPTH_CRITICAL,
        multipv: BulkEnqueueForImport::DEFAULT_MULTIPV,
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
