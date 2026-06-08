# frozen_string_literal: true

module AnalysisRuns
  # Periodically reconciles analysis runs and system jobs.
  # Started on Sidekiq boot and reschedules itself — no page-view triggers required.
  class ReconcileJob
    include Sidekiq::Job

    sidekiq_options queue: :default, retry: 1

    INTERVAL_SECONDS = 30

    def perform(reschedule = true)
      AnalysisRuns::ReconcileAll.call
      self.class.perform_in(INTERVAL_SECONDS) if reschedule
    end
  end
end
