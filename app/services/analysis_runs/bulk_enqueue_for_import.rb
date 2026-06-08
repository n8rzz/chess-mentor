# frozen_string_literal: true

module AnalysisRuns
  class BulkEnqueueForImport
    DEFAULT_ENGINE_NAME = "Stockfish"
    DEFAULT_ENGINE_VERSION = "16.1"
    DEFAULT_ANALYSIS_VERSION = "1.0.0"
    DEFAULT_DEPTH = 15

    def self.call(import_batch:)
      new(import_batch:).call
    end

    def initialize(import_batch:)
      @import_batch = import_batch
    end

    def call
      return @import_batch if analysis_already_enqueued?
      return @import_batch unless terminal_success?

      ActiveRecord::Base.transaction do
        imported_records.find_each do |record|
          next if record.game_id.blank?
          next if existing_run?(record.game_id)

          analysis_run = AnalysisRun.create!(
            game_id: record.game_id,
            user_id: @import_batch.user_id,
            engine_name: DEFAULT_ENGINE_NAME,
            engine_version: DEFAULT_ENGINE_VERSION,
            analysis_version: DEFAULT_ANALYSIS_VERSION,
            depth: DEFAULT_DEPTH,
            metadata: { "import_batch_id" => @import_batch.id }
          )

          SystemJobs::Create.call(
            user: @import_batch.user,
            job_type: :analyze_game,
            payload: {
              "analysis_run_id" => analysis_run.id,
              "game_id" => record.game_id
            }
          )
        end

        @import_batch.update!(
          metadata: @import_batch.metadata.merge("analysis_enqueued_at" => Time.current.iso8601)
        )
      end

      @import_batch
    end

    private

    def analysis_already_enqueued?
      @import_batch.metadata["analysis_enqueued_at"].present?
    end

    def terminal_success?
      @import_batch.succeeded? || @import_batch.partially_succeeded?
    end

    def imported_records
      @import_batch.import_records.imported.includes(:game)
    end

    def existing_run?(game_id)
      AnalysisRun.in_progress.exists?(game_id: game_id)
    end
  end
end
